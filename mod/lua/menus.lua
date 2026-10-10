-- Menus built on the game's widget framework: the hub menu and everything under it (settings,
-- seasons, episodes, extras), the in-game pause menu, and popups.
--
-- Every selectable thing is a Button (button.lua); the global Button(agent) constructor gives each
-- one a Select(self, bSelect) method. We wrap Select on every new button, so any change of focus,
-- by keyboard, controller or mouse, tells us what is now selected. Each button's .widget is the
-- menu widget it belongs to, and its visible text agents say what it is and what it is set to.
local TWDA = ...
local G = _G

---------------------------------------------------------------------------------------------------
-- Announcements. Everything that happens in one frame is spoken together, in reading order, so a
-- new menu's title comes before its first item and a popup's message before its buttons.
---------------------------------------------------------------------------------------------------

local SLOTS = { "title", "popup", "item", "value" }
local pending = {}
local holdUntil = 0

local function queue(slot, text)
  if text and text ~= "" then pending[slot] = text end
end

local popup -- the popup being built: { texts = {}, buttons = {}, skip = {} }
local shownMenu, shownAt = nil, 0 -- a menu that has just been shown, until its title is read

---------------------------------------------------------------------------------------------------
-- Describing a widget from what it shows.
---------------------------------------------------------------------------------------------------

local function isHidden(agent)
  local ok, hidden = pcall(AgentIsHidden, agent)
  return ok and hidden == true
end

-- Texts of an agent and its visible children, top to bottom as the engine lists them.
local function visibleTexts(agent, out, seen, depth)
  if agent == nil or depth > 4 or isHidden(agent) then return end
  local name = TWDA.agentName(agent):lower()
  if name:find("infobutton", 1, true) or name:find("tooltip", 1, true) then return end
  local text = TWDA.normalCaps(TWDA.agentText(agent))
  if text and not seen[text] then
    seen[text] = true
    out[#out + 1] = text
  end
  local ok, children = pcall(AgentGetChildren, agent)
  if ok and type(children) == "table" then
    for _, child in pairs(children) do visibleTexts(child, out, seen, depth + 1) end
  end
end

-- All visible text of an agent and its children, joined (used by other menu modules too).
function TWDA.visibleText(agent)
  local parts = {}
  visibleTexts(agent, parts, {}, 0)
  return #parts > 0 and table.concat(parts, ", ") or nil
end

local function call(widget, method)
  local f = widget[method]
  if type(f) ~= "function" then return nil end
  local ok, value = pcall(f, widget)
  if ok then return value end
  return nil
end

local function roleOf(widget, text)
  if rawget(widget, "minValue") ~= nil and rawget(widget, "maxValue") ~= nil then return "slider" end
  if text and text:find(" : ") and type(widget.SetValue) == "function" then return "slider" end
  local prefValues = rawget(widget, "prefValues")
  if type(prefValues) == "table" then
    return #prefValues == 2 and "toggle" or "choice, left and right to change"
  end
  if type(rawget(widget, "values")) == "table" and rawget(widget, "index") ~= nil then
    return "choice, left and right to change"
  end
  return nil
end

local function describeWidget(widget)
  if type(widget) ~= "table" then return nil end
  local parts = {}
  -- Carousel elements (seasons, episodes) describe themselves.
  for _, method in ipairs({ "GetDisplayTitle", "GetDisplaySubtitle", "GetDisplayStatus", "GetDisplayAction",
    "GetDisplayDescription" }) do
    local text = TWDA.normalCaps(TWDA.keyOrText(call(widget, method)))
    if text then parts[#parts + 1] = text end
  end
  if #parts == 0 then visibleTexts(rawget(widget, "agent"), parts, {}, 0) end
  if #parts == 0 then
    -- An unlabelled slider (brightness): say where the handle is.
    local value, low, high = rawget(widget, "value"), rawget(widget, "minValue"), rawget(widget, "maxValue")
    if type(value) == "number" and type(low) == "number" and type(high) == "number" and high > low then
      return ("slider, %d percent"):format(math.floor((value - low) / (high - low) * 100 + 0.5))
    end
    return nil
  end
  local role = roleOf(widget, parts[1])
  if role then parts[#parts + 1] = role end
  if call(widget, "GetIsLocked") == true or rawget(widget, "bIsLocked") == true then parts[#parts + 1] = "locked" end
  if call(widget, "GetIsNew") == true then parts[#parts + 1] = "new" end
  return table.concat(parts, ", ")
end
TWDA.describeWidget = describeWidget

local function tooltipOf(widget)
  if type(widget) ~= "table" then return nil end
  return TWDA.keyOrText(rawget(widget, "tooltip"))
end

---------------------------------------------------------------------------------------------------
-- Focus.
---------------------------------------------------------------------------------------------------

local current = nil  -- { button, widget, text, time }
local menuTitle = nil

-- The widget a button belongs to: settings rows select a child "_button" agent, so walk up.
local function widgetOf(button)
  local widget = rawget(button, "widget")
  if type(widget) == "table" then return widget end
  local agent = button
  for _ = 1, 3 do
    local ok, found = pcall(WidgetInitializer_GetWidgetFromAgent, agent)
    if ok and type(found) == "table" then return found end
    local okParent, parent = pcall(AgentGetParent, agent)
    if not okParent or parent == nil then break end
    agent = parent
  end
  return nil
end

-- Returns what to say, the widget, and the bare description (without the tooltip) for spotting
-- value changes later.
local KEY_WORDS = { "Enter", "Escape", "F9", "F10", "Page Up", "Page Down" }

-- Legend buttons show a key icon before their label; say the label first.
local function legendButtonText(text)
  for _, key in ipairs(KEY_WORDS) do
    local label = text:match("^" .. key .. " (.+)$")
    if label then
      return label .. ", " .. key .. " key"
    end
  end
  return text
end

-- Season 2's menus (projectseason2's button.lua): the button agent has no text; its label is a
-- sibling under the same parent (ui_list_button_label_1 beside ui_list_button_button_1), and a
-- shown "..._lock_N" marks a locked item (My Choices before an episode is played).
-- (Also the texts under the label: a save file's "Empty" or its date, in the save carousel.)
local function siblingText(button)
  local okP, parent = pcall(AgentGetParent, button)
  if not okP or parent == nil then return nil end
  local okC, kids = pcall(AgentGetChildren, parent)
  local texts, locked = {}, false
  local function add(agent, depth)
    if depth > 2 or isHidden(agent) then return end
    local text = TWDA.normalCaps(TWDA.agentText(agent))
    if text and text ~= "" then texts[#texts + 1] = text end
    local okK, grand = pcall(AgentGetChildren, agent)
    for _, g in ipairs(okK and type(grand) == "table" and grand or {}) do add(g, depth + 1) end
  end
  for _, kid in ipairs(okC and type(kids) == "table" and kids or {}) do
    if kid ~= button and not isHidden(kid) then
      if TWDA.agentName(kid):lower():find("lock", 1, true) then locked = true else add(kid, 1) end
    end
  end
  if #texts == 0 then return nil end
  if locked then texts[#texts + 1] = "locked" end
  return table.concat(texts, ", ")
end

-- A Season 2 menu's title and size, once per menu. The menu is a root agent ("ui_menu_settings",
-- "ui_coverflow_saveSlots") whose rows ("..._reference_N") are its children or one level down;
-- the title is its shown "ui_header_N" (none on the main menu). Carousels go left and right.
local lastSeason2Root, season2WasEmpty = nil, false
local function season2TitleOf(root)
  local rootName = root ~= nil and TWDA.agentName(root) or ""
  if rootName == "" then return nil end
  local count, title = 0, nil
  local function scan(agent, depth)
    if depth > 3 or isHidden(agent) then return end
    local name = TWDA.agentName(agent)
    if name:find("^ui_header_%d+$") then
      title = title or TWDA.normalCaps(TWDA.agentText(agent))
      return
    end
    if name:find("_reference_%d+$") and not name:find("header", 1, true) and not name:lower():find("backbutton", 1, true) then
      count = count + 1
      return
    end
    local okC, kids = pcall(AgentGetChildren, agent)
    for _, k in ipairs(okC and type(kids) == "table" and kids or {}) do scan(k, depth + 1) end
  end
  local okC, kids = pcall(AgentGetChildren, root)
  for _, k in ipairs(okC and type(kids) == "table" and kids or {}) do
    -- (The header's parent is itself hidden while the header shows.)
    if TWDA.agentName(k):find("^ui_header_reference") then
      local okH, heads = pcall(AgentGetChildren, k)
      for _, h in ipairs(okH and type(heads) == "table" and heads or {}) do
        if TWDA.agentName(h):find("^ui_header_%d+$") and not isHidden(h) then title = title or TWDA.normalCaps(TWDA.agentText(h)) end
      end
    else
      scan(k, 1)
    end
  end
  title = title or (rootName == "ui_menu_main" and "Main" or nil)
  if not title then return nil end
  -- (A screen with nothing to choose, Controls' picture of the keys; the frame check waits longer
  -- for these, since a menu has no rows either just after it is pushed.)
  if count == 0 then return title .. ". Nothing to choose here, only a picture. Escape goes back", true end
  local keys = rootName:find("coverflow", 1, true) and "Left and right arrows to choose" or "Up and down arrows to choose"
  local lower = title:lower()
  local noun = (lower:find("menu$") or lower:find("^select") or lower:find("^choose")) and "" or " menu"
  return ("%s%s, %d %s. %s, Enter to select"):format(title, noun, count, count == 1 and "item" or "items", keys)
end
local function season2Title(button)
  -- (Only in Season 2's menus, the UIZ framework; the hub's widget menus have titles of their own.)
  if type(rawget(G, "UIZ_GetActiveMenu")) ~= "function" then return nil end
  local okA, root = pcall(UIZ_GetActiveMenu)
  if not okA or root == nil or (root == lastSeason2Root and not season2WasEmpty) then return nil end
  local text, empty = season2TitleOf(root)
  if not text or empty then return nil end
  lastSeason2Root, season2WasEmpty = root, false
  return text
end

-- Season 2's popups (popup.lua's Popup(headerNode, messageNode, ...) pushes a UIZ menu of its
-- own): everything it shows, header, message and buttons, read when it becomes the active menu.
local function season2PopupText(root)
  if not TWDA.agentName(root):lower():find("popup", 1, true) then return nil end
  local texts = {}
  local okS, agents = pcall(SceneGetAgents, AgentGetScene(root))
  for _, a in ipairs(okS and type(agents) == "table" and agents or {}) do
    local name = TWDA.agentName(a)
    if not isHidden(a) and (name:find("^ui_popup_header") or name:find("^ui_popup_message")
      or name:find("^ui_popup_button_label_%d+$")) then
      local text = TWDA.normalCaps(TWDA.agentText(a))
      local okPos, pos = pcall(AgentGetScreenPos, a)
      if text and text ~= "" then texts[#texts + 1] = { text = text, y = okPos and pos and pos.y or 0 } end
    end
  end
  if #texts == 0 then return nil end
  table.sort(texts, function(a, b) return a.y < b.y end)
  local parts = {}
  for _, t in ipairs(texts) do parts[#parts + 1] = t.text end
  parts[#parts + 1] = "Up and down arrows to choose, Enter to confirm"
  return TWDA.joinSentences(parts)
end

-- A Season 2 menu that has just come up, before anything is selected (the game selects nothing
-- until an arrow is pressed): its title, read at once. The UIZ framework knows the active menu
-- (UIZ_GetActiveMenu: the menu's root agent; the menus left behind stay "shown").
local season2CheckAt, season2Pending, season2PendingSince = 0, nil, 0
TWDA.onFrame("menus.season2", function()
  if type(rawget(G, "UIZ_GetActiveMenu")) ~= "function" then return end
  local now = TWDA.now()
  if now - season2CheckAt < 0.3 then return end
  season2CheckAt = now
  local ok, root = pcall(UIZ_GetActiveMenu)
  if not ok or root == nil or (root == lastSeason2Root and not season2WasEmpty) then return end
  local popupText = root ~= lastSeason2Root and season2PopupText(root)
  if popupText then
    lastSeason2Root, season2WasEmpty = root, false
    TWDA.lastPopup = popupText
    queue("popup", popupText)
    return
  end
  -- (Only once the same text has come twice in a row: the rows are added over several frames. A
  -- menu gone back to can show no rows for a while, so one read as empty is read again if rows come.)
  local text, empty = season2TitleOf(root)
  if root == lastSeason2Root and empty then return end
  if text and text == season2Pending and (not empty or now - season2PendingSince > 2) then
    lastSeason2Root, season2Pending, season2WasEmpty = root, nil, empty and true or false
    menuTitle = text
    queue("title", text)
  elseif text ~= season2Pending then
    season2Pending, season2PendingSince = text, now
  end
end)

-- Season 2's settings rows: the selected agent is the row's label (ui_list_slider_label_2); its
-- parent is the row (ui_list_slider_reference_2), which the menu registers as a widget with value,
-- minVal and maxVal when it is a slider; a toggle shows its value on ui_list_toggle_var_N.
local function season2RowValue(button)
  if button == nil or type(rawget(G, "UIZ_GetActiveMenu")) ~= "function" then return nil end
  local okP, row = pcall(AgentGetParent, button)
  if not okP or row == nil then return nil end
  local rowName = TWDA.agentName(row)
  local n = rowName:match("_(%d+)$")
  if rowName:find("^ui_list_toggle_reference") and n then
    local okV, var = pcall(AgentFind, "ui_list_toggle_var_" .. n)
    return okV and var ~= nil and TWDA.normalCaps(TWDA.agentText(var)) or nil
  elseif rowName:find("^ui_list_slider_reference") then
    local okM, menu = pcall(UIZ_GetActiveMenu)
    for _, w in pairs(okM and menu and rawget(menu, "registeredWidgets") or {}) do
      if type(w) == "table" and rawget(w, "isSlider") and TWDA.agentName(w) == rowName then
        local min, max, value = rawget(w, "minVal") or 0, rawget(w, "maxVal") or 1, rawget(w, "value") or 0
        if max == min then return nil end
        return math.floor((value - min) / (max - min) * 100 + 0.5) .. " percent"
      end
    end
  end
  return nil
end

local function describeButton(button)
  local widget = widgetOf(button)
  local base = describeWidget(widget) or TWDA.agentText(button) or siblingText(button)
  if base and type(rawget(G, "UIZ_GetActiveMenu")) == "function" then
    base = TWDA.normalCaps(base)
    local value = season2RowValue(button)
    if value then base = base .. ", " .. value end
  end
  if base and TWDA.agentName(button):find("legendButton", 1, true) then base = legendButtonText(base) end
  local text = base
  if text and TWDA.settings.tooltips ~= false then
    local tip = tooltipOf(widget)
    if tip and tip ~= text then text = text .. ". " .. tip end
  end
  return text, widget, base
end

-- Widgets that are part of the menu's frame rather than things to choose.
local function isChrome(name)
  return name:find("_header$") or name:find("_title$") or name:find("_legend") or name:find("[Bb]ack$")
end

-- Arrow buttons (beside a settings row, or scroll arrows on long lists) are for the mouse. When a
-- menu opens the game sometimes gives keyboard focus to one of them, and then the arrow keys cannot
-- move off it, for sighted players too. When that happens without the mouse being involved, we move
-- focus on the next frame: to the row's centre button, or to the first real item in the menu.
local redirectTo = nil
local mouseDepth = 0 -- inside the game's mouse-hover handlers

for _, name in ipairs({ "WidgetInputHandler_OnRollOn", "WidgetInputHandler_OnMouseMove", "WidgetInputHandler_OnMouseLDown",
  "WidgetInputHandler_OnMouseLUp", "DialogBox_OnRollOn" }) do
  TWDA.hookGlobal(name, function(original)
    return function(...)
      mouseDepth = mouseDepth + 1
      local results = table.pack(pcall(original, ...))
      mouseDepth = mouseDepth - 1
      if not results[1] then error(results[2], 0) end
      return table.unpack(results, 2, results.n)
    end
  end)
end

local function sceneButtons()
  local menu = Menu_GetCurrentMenu and Menu_GetCurrentMenu()
  local scene = menu and menu.GetScene and menu:GetScene()
  return (scene and rawget(scene, "mButtons")) or {}, menu
end

local function isArrowButton(button)
  return TWDA.agentName(button):lower():find("arrow", 1, true) ~= nil
end

-- Season Select keeps the seasons' widgets (mButtonList, an upvalue of Menu_Seasons_OnLeft) and the
-- index of the one showing. That season's Play button is the scene button with its widget.
-- (Selecting the widget itself only highlights it; the game's focus, Buttons_GetSelected, stays
-- where it was.)
local function seasonPlayButton(buttons)
  local onLeft = rawget(G, "Menu_Seasons_OnLeft")
  local list, index = TWDA.upvalue(onLeft, "mButtonList"), TWDA.upvalue(onLeft, "mCurrentIndex")
  local item = type(list) == "table" and index ~= nil and list[index] or nil
  if item == nil then return nil end
  for _, candidate in ipairs(buttons or sceneButtons()) do
    if rawget(candidate, "widget") == item then return candidate end
  end
  return nil
end

local function redirectTarget(button)
  local name = TWDA.agentName(button)
  local buttons, menu = sceneButtons()
  -- Season Select: after Left or Right (and on Down) the game leaves focus on the carousel's left
  -- arrow, where Down and Enter do nothing; the keyboard's item is the Play button of the season
  -- showing.
  if name:find("^ui_seasons_arrow") then
    local play = seasonPlayButton(buttons)
    if play then return play end
  end
  local base = name:match("^(.*)_arrowLeft$") or name:match("^(.*)_arrowRight$")
  if base then
    for _, candidate in ipairs(buttons) do
      if TWDA.agentName(candidate) == base .. "_button" then return candidate end
    end
  end
  -- First button, in menu order, that belongs to a real item.
  for _, widget in ipairs((menu and rawget(menu, "widgets")) or {}) do
    local widgetName = TWDA.agentName(rawget(widget, "agent"))
    if not isChrome(widgetName) then
      for _, candidate in ipairs(buttons) do
        if not isArrowButton(candidate) and widgetOf(candidate) == widget then return candidate end
      end
    end
  end
  return nil
end

-- redirectTo = { button, quiet }. Quiet: do not speak the button (the Season Select text already
-- ends with "Enter to play"; saying "Play" would cut it off).
local quietButton = nil

TWDA.onFrame("menus.redirect", function()
  if not redirectTo then return end
  local r = redirectTo
  redirectTo = nil
  if r.quiet then quietButton = r.button end
  -- In a thread of its own: selecting a season's Play button runs Menu_Seasons_Select, which
  -- waits for a transition chore.
  local ok, err = pcall(ThreadStart, function()
    local okSel, errSel = pcall(function() r.button:Select(true) end)
    if not okSel then TWDA.log("menus redirect: " .. tostring(errSel)) end
  end)
  if not ok then TWDA.log("menus redirect: " .. tostring(err)) end
end)

local function onSelect(button)
  if mouseDepth == 0 and isArrowButton(button) then
    local target = redirectTarget(button)
    if target and target ~= button then
      redirectTo = { button = target, quiet = TWDA.agentName(button):find("^ui_seasons_arrow") ~= nil }
      return
    end
  end
  local text, widget, base = describeButton(button)
  local now = TWDA.now()
  local s2title = season2Title(button)
  if s2title then
    menuTitle = s2title
    queue("title", s2title)
  end
  if quietButton == button then
    quietButton = nil
    current = { button = button, widget = widget, text = base, time = now }
    if text then TWDA.lastMenuItem = text end
    return
  end
  if current and current.button == button and not pending.title and now - current.time < 0.5 then return end
  current = { button = button, widget = widget, text = base, time = now }
  if not text then
    TWDA.log("menus: no text for " .. TWDA.agentName(button))
    return
  end
  TWDA.lastMenuItem = text
  if TWDA.settings.menus ~= false then queue("item", text) end
end

local function wrapSelect(button)
  local select = rawget(button, "Select")
  if type(select) ~= "function" or TWDA.wrappers[select] then return end
  local wrapper = function(self, bSelect, ...)
    local results = table.pack(select(self, bSelect, ...))
    if bSelect then
      local ok, err = pcall(onSelect, self)
      if not ok then TWDA.log("menus select: " .. tostring(err)) end
    end
    return table.unpack(results, 1, results.n)
  end
  TWDA.wrappers[wrapper] = true
  rawset(button, "Select", wrapper)
end

TWDA.hookGlobal("Button", function(original)
  return function(button, ...)
    local results = table.pack(original(button, ...))
    if type(button) == "table" then pcall(wrapSelect, button) end
    return table.unpack(results, 1, results.n)
  end
end)

-- Left and right change a setting without moving focus; speak only what changed.
local function changedPart(old, new)
  local oldParts, newParts = {}, {}
  for part in (old or ""):gmatch("[^,]+") do oldParts[#oldParts + 1] = part end
  for part in new:gmatch("[^,]+") do newParts[#newParts + 1] = part end
  local changed = {}
  for i, part in ipairs(newParts) do
    if part ~= oldParts[i] then
      -- "Volume : 7" -> "7"
      changed[#changed + 1] = part:match(":%s*(.-)%s*$") or part
    end
  end
  return #changed > 0 and table.concat(changed, ", ") or new
end

local lastPoll = 0
TWDA.onFrame("menus.value", function()
  if not current or not current.widget then return end
  local now = TWDA.now()
  if now - lastPoll < 0.1 then return end
  lastPoll = now
  local okSel, selected = pcall(function() return rawget(current.button, "mbSelected") end)
  if not okSel or selected ~= true then return end
  local text = describeWidget(current.widget)
  if text and text ~= current.text then
    local changed = changedPart(current.text, text)
    current.text = text
    TWDA.lastMenuItem = text
    queue("value", changed)
  end
end)

-- Season 2's rows change with Left and Right (or Enter on a toggle): say the new value.
local season2Value, season2ValueButton, season2ValueAt = nil, nil, 0
TWDA.onFrame("menus.season2value", function()
  if not current or not current.button or type(rawget(G, "UIZ_GetActiveMenu")) ~= "function" then return end
  local now = TWDA.now()
  if now - season2ValueAt < 0.12 then return end
  season2ValueAt = now
  local value = season2RowValue(current.button)
  if current.button ~= season2ValueButton then
    season2ValueButton, season2Value = current.button, value
  elseif value and value ~= season2Value then
    season2Value = value
    queue("value", value)
  end
end)

---------------------------------------------------------------------------------------------------
-- Menu titles, the legend, popups, and the season and episode carousels.
---------------------------------------------------------------------------------------------------

-- Menus that have no header widget.
local MENU_NAMES = { ui_menuMain = "Main menu", ui_gamma_reference = "Brightness" }

-- Instructions shown on a screen as plain scene text rather than as a widget.
local function sceneNotes(menu)
  local notes = {}
  -- Only the menu's own agents: "ui_gamma_reference" owns "ui_gamma_description".
  local menuName = TWDA.agentName(rawget(menu, "agent"))
  local prefix = menuName:match("^(ui_[^_]+_)") or (menuName .. "_")
  local okScene, scene = pcall(AgentGetScene, rawget(menu, "agent"))
  if not okScene or not scene then return notes end
  local okAgents, agents = pcall(SceneGetAgents, scene)
  if not okAgents or type(agents) ~= "table" then return notes end
  for _, agent in pairs(agents) do
    local name = TWDA.agentName(agent)
    if name:sub(1, #prefix) == prefix and (name:find("_description$") or name:find("_message$")
        or name:find("_instructions?$")) and not isHidden(agent) then
      local text = TWDA.agentText(agent)
      if text then notes[#notes + 1] = text end
    end
  end
  return notes
end

-- Keys in the legend other than the usual Select and Previous menu, which every menu has.
local function unusualKeys()
  local keys = {}
  for _, entry in ipairs(TWDA.menuLegend and TWDA.menuLegend() or {}) do
    local label = entry:match(":%s*(.*)$") or ""
    if label ~= "Select" and label ~= "Previous menu" then keys[#keys + 1] = entry end
  end
  return keys
end

local function titleOf(menu)
  if type(menu) ~= "table" then return nil end
  local agentName = TWDA.agentName(rawget(menu, "agent"))
  for _, widget in ipairs(rawget(menu, "widgets") or {}) do
    local agent = rawget(widget, "agent")
    local name = TWDA.agentName(agent)
    if name:find("_header$") or name:find("_title$") then
      local text = TWDA.agentText(agent)
      if text then return text end
    end
  end
  return MENU_NAMES[agentName]
end


local function buttonCount(widget)
  local names = rawget(widget, "buttonNames")
  return type(names) == "table" and #names or 0
end

-- Things to choose: widgets with at least one button, apart from the header and legend.
local function itemCount(menu)
  local count = 0
  for _, widget in ipairs(rawget(menu, "widgets") or {}) do
    local name = TWDA.agentName(rawget(widget, "agent"))
    if not isChrome(name) and buttonCount(widget) > 0 then count = count + 1 end
  end
  return count
end

-- Static text in a menu (the About page's body, for instance): widgets without buttons.
local function contentTexts(menu)
  local texts = {}
  for _, widget in ipairs(rawget(menu, "widgets") or {}) do
    local agent = rawget(widget, "agent")
    local name = TWDA.agentName(agent)
    if not isChrome(name) and buttonCount(widget) == 0 and not isHidden(agent) then
      local parts = {}
      visibleTexts(agent, parts, {}, 0)
      if #parts > 0 then texts[#texts + 1] = TWDA.joinSentences(parts) end
    end
  end
  return texts
end

-- Menu_Show fills the menu in after it starts, so the title is read a moment later.
TWDA.hookBefore("Menu_Show", function(menu)
  if type(menu) ~= "table" then return end
  shownMenu, shownAt = menu, TWDA.now()
  current = nil -- the previous menu's selection no longer applies
  holdUntil = TWDA.now() + 0.2
end)

-- Menus add their widgets over several frames; wait until the count has held still for a few.
local lastCount, steadyFrames = -1, 0
TWDA.onFrame("menus.title", function()
  if not shownMenu then return end
  local menu = shownMenu
  local title = TWDA.normalCaps(titleOf(menu))
  local count = itemCount(menu)
  if count == lastCount then
    steadyFrames = steadyFrames + 1
  else
    lastCount, steadyFrames = count, 0
  end
  local waited = TWDA.now() - shownAt
  if waited < 0.9 and (count == 0 or steadyFrames < 4) then return end -- still being built
  shownMenu, lastCount, steadyFrames = nil, -1, 0
  menuTitle = title
  if not title then return end
  local text = title .. (title:lower():find("menu$") and "" or " menu")
  if count > 0 then text = text .. ", " .. count .. (count == 1 and " item" or " items") end
  local sentences = { text }
  for _, note in ipairs(contentTexts(menu)) do sentences[#sentences + 1] = note end
  for _, note in ipairs(sceneNotes(menu)) do sentences[#sentences + 1] = note end
  for _, key in ipairs(unusualKeys()) do sentences[#sentences + 1] = key end
  queue("title", TWDA.joinSentences(sentences))
end)

-- Legend entries whose screen maps them to keyboard keys of its own: the character viewer rotates
-- and zooms with A, D, W and S (CharacterZoo.imap).
local KEYBOARD_FOR_LABEL = {
  ["stickRight|Rotate"] = "A and D",
  ["triggerButtonLeft|Zoom In"] = "W",
  ["triggerButtonRight|Zoom Out"] = "S",
}

-- Each menu builds its legend once, when first shown, so remember it per menu, along with the
-- command behind each legend button (so the mod's hotkeys can run it).
local legends = setmetatable({}, { __mode = "k" })
local legendCommands = setmetatable({}, { __mode = "k" })
local legendLabels = setmetatable({}, { __mode = "k" })

local function currentMenu()
  local ok, menu = pcall(Menu_GetCurrentMenu)
  return ok and menu or nil
end

local function legendFor(menu)
  if not menu then return {} end
  legends[menu] = legends[menu] or {}
  return legends[menu]
end

TWDA.menuLegend = function() return legendFor(currentMenu()) end

TWDA.hookBefore("Legend_Clear", function()
  local menu = currentMenu()
  if menu then
    legends[menu] = {}
    legendCommands[menu] = {}
    legendLabels[menu] = {}
  end
end)
-- Runs the current menu's legend command for a controller button. Returns its label (or true),
-- or false if the legend has nothing on that button.
function TWDA.runLegendCommand(buttonNames)
  local menu = currentMenu()
  local commands = legendCommands[menu] or {}
  local labels = legendLabels[menu] or {}
  for _, buttonName in ipairs(buttonNames) do
    local command = commands[buttonName]
    if command ~= nil and labels[buttonName] then TWDA.say(labels[buttonName], { interrupt = true }) end
    if type(command) == "function" then
      local ok, err = pcall(command)
      if not ok then TWDA.log("legend command: " .. tostring(err)) end
      return true
    elseif type(command) == "string" and command ~= "" then
      local chunk, compileErr = load(command, "=legend", "t")
      if chunk then
        local ok, err = pcall(chunk)
        if not ok then TWDA.log("legend command: " .. tostring(err)) end
      else
        TWDA.log("legend command: " .. tostring(compileErr))
      end
      return true
    end
  end
  return false
end

TWDA.hookBefore("Legend_Add", function(buttonName, text, command)
  local menu = currentMenu()
  if menu and type(buttonName) == "string" and command ~= nil then
    legendCommands[menu] = legendCommands[menu] or {}
    legendCommands[menu][buttonName] = command
  end
  local label = TWDA.keyOrText(text)
  if not label then return end
  if menu and type(buttonName) == "string" then
    legendLabels[menu] = legendLabels[menu] or {}
    legendLabels[menu][buttonName] = label
  end
  local key = TWDA.glyphNames[buttonName] or buttonName
  -- Controller-only legend entries that have keyboard keys on their own screen.
  key = KEYBOARD_FOR_LABEL[buttonName .. "|" .. label] or key
  local list = legendFor(currentMenu())
  for _, entry in ipairs(list) do
    if entry == key .. ": " .. label then return end
  end
  list[#list + 1] = key .. ": " .. label
end)

-- Popups. Header, message and button labels are all fetched with Dialog_GetText while the box is
-- built (over a few frames); the button labels are recognised by the node names DialogBox was given.
local popupWasOpen = false
local beforePopup = nil -- what was selected in the menu underneath, to repeat when the popup closes

local function beginPopup(skipNodes)
  if not popupWasOpen then beforePopup = current end
  popupWasOpen = true
  popup = { texts = {}, buttons = {}, skip = skipNodes or {} }
  holdUntil = TWDA.now() + 0.4
end

TWDA.hookBefore("DialogBox", function(message, header, button1Node, button1Result, button2Node, button2Result, dlogFile)
  local skip = {}
  if type(button1Node) == "string" then skip[button1Node] = true end
  if type(button2Node) == "string" then skip[button2Node] = true end
  beginPopup(skip)
  -- Header and message may be literal text rather than dialog nodes; take them straight away.
  for _, value in ipairs({ header, message }) do
    local text = TWDA.keyOrText(value, type(dlogFile) == "string" and dlogFile or nil)
    if text then popup.texts[#popup.texts + 1] = text end
  end
end)
TWDA.hookBefore("MessageBox_Display", function(dialogFile, nodeMsg, nodeChoice1, nodeChoice2)
  -- Season 1's own message box mode is read by messagebox.lua.
  if type(rawget(G, "mode_UI_MessageBox")) == "table" then return end
  local skip = {}
  if type(nodeChoice1) == "string" then skip[nodeChoice1] = true end
  if type(nodeChoice2) == "string" then skip[nodeChoice2] = true end
  beginPopup(skip)
end)
TWDA.hookAfter("Dialog_GetText", function(args, results)
  if not popup or type(results[1]) ~= "string" then return end
  local text = TWDA.cleanText(results[1])
  if text == "" then return end
  local key = args[2]
  if popup.skip[key] then
    popup.buttons[#popup.buttons + 1] = text
  else
    for _, existing in ipairs(popup.texts) do
      if existing == text then return end
    end
    popup.texts[#popup.texts + 1] = text
  end
end)

-- Season Select: a carousel of seasons, each with a Play button. When the screen opens nothing has
-- keyboard focus; the mod gives it to the Play button of the season showing, so Enter plays it.
-- Selecting a season's button also calls Menu_Seasons_Select, so the same text could come twice
-- in a row; it is only spoken once.
local lastSeasonText, lastSeasonAt = nil, -10
TWDA.hookAfter("Menu_Seasons_Select", function(args)
  local label = TWDA.normalCaps(TWDA.agentText(AgentFind("ui_seasons_textLabel"))) or tostring(args[1])
  local description = TWDA.agentText(AgentFind("ui_seasons_textDescription"))
  local text = TWDA.joinSentences({ label, description })
  TWDA.lastMenuItem = text
  if mouseDepth == 0 and not redirectTo then
    local okSel, selected = pcall(Buttons_GetSelected)
    if okSel and selected == nil then
      local play = seasonPlayButton()
      if play then redirectTo = { button = play, quiet = true } end
    end
  end
  local now = TWDA.now()
  if text == lastSeasonText and now - lastSeasonAt < 1.5 then return end
  lastSeasonText, lastSeasonAt = text, now
  queue("item", TWDA.joinSentences({ text, "Left and right for other seasons, Enter to play" }))
end)

-- Episode lists and other carousels.
local function attachCarousel()
  local carousel = rawget(G, "Carousel")
  if type(carousel) ~= "table" or rawget(carousel, "TWDA_attached") then return end
  rawset(carousel, "TWDA_attached", true)
  TWDA.hookMethod(carousel, "SelectElement", "Carousel.SelectElement", nil, function(args)
    local self = args[1]
    local widget = call(self, "GetSelectedElementWidget")
    local text = describeWidget(widget)
    if text then
      current = { button = nil, widget = widget, text = text, time = TWDA.now() }
      TWDA.lastMenuItem = text
      queue("item", text)
    end
  end)
end
TWDA.onFrame("menus.carousel", attachCarousel)

-- When a popup closes, say where focus went back to.
local function attachModal()
  local menuClass = rawget(G, "Menu")
  if type(menuClass) ~= "table" or rawget(menuClass, "TWDA_modal") then return end
  if type(rawget(menuClass, "onModalPopped")) ~= "function" then return end
  rawset(menuClass, "TWDA_modal", true)
  TWDA.hookMethod(menuClass, "onModalPopped", "Menu.onModalPopped", nil, function()
    if not popupWasOpen then return end
    popupWasOpen = false
    local parts = {}
    if menuTitle then parts[#parts + 1] = menuTitle end
    if beforePopup and beforePopup.text then
      parts[#parts + 1] = beforePopup.text
      current = beforePopup
    end
    beforePopup = nil
    if #parts > 0 then queue("title", table.concat(parts, ", ")) end
  end)
end
TWDA.onFrame("menus.modal", attachModal)

---------------------------------------------------------------------------------------------------
-- F6: describe the current screen.
---------------------------------------------------------------------------------------------------

function TWDA.describeMenu()
  local parts = {}
  if menuTitle then parts[#parts + 1] = menuTitle end
  if current and current.text then parts[#parts + 1] = current.text end
  local tip = current and tooltipOf(current.widget)
  if tip then parts[#parts + 1] = tip end
  local keys = TWDA.menuLegend and TWDA.menuLegend() or {}
  if #keys > 0 then parts[#parts + 1] = "Keys: " .. table.concat(keys, ". ") end
  if #parts == 0 then return nil end
  return TWDA.joinSentences(parts)
end

---------------------------------------------------------------------------------------------------
-- Speaking, once per frame after the title and value checks above have had their turn.
---------------------------------------------------------------------------------------------------

TWDA.onFrame("menus.speak", function()
  if TWDA.now() < holdUntil then return end
  if shownMenu and TWDA.now() - shownAt < 1 then return end
  if popup and #popup.texts > 0 then
    local sentences = { table.concat(popup.texts, ". ") }
    if #popup.buttons > 0 then sentences[#sentences + 1] = table.concat(popup.buttons, ", ") end
    sentences[#sentences + 1] = "Up and down arrows to choose, Enter to confirm"
    local text = TWDA.joinSentences(sentences)
    TWDA.lastPopup = text
    queue("popup", text)
  end
  popup = nil
  local parts = {}
  for _, slot in ipairs(SLOTS) do
    if pending[slot] then
      parts[#parts + 1] = pending[slot]
      pending[slot] = nil
    end
  end
  if #parts > 0 then TWDA.say(TWDA.joinSentences(parts), { interrupt = true }) end
end)

---------------------------------------------------------------------------------------------------
-- Credits: one long block of text that scrolls past. Announce them, and let F6 read them out.
---------------------------------------------------------------------------------------------------

local creditsActive = false

-- "CREATIVE DIRECTOR\nKent Mudle\n\nART DIRECTOR\n..." -> "Creative Director: Kent Mudle. Art Director: ..."
local function formatCredits(raw)
  local out, heading, names = {}, nil, {}
  local function flush()
    if heading and #names > 0 then
      out[#out + 1] = heading .. ": " .. table.concat(names, ", ")
    elseif heading then
      out[#out + 1] = heading
    elseif #names > 0 then
      out[#out + 1] = table.concat(names, ", ")
    end
    heading, names = nil, {}
  end
  for line in (raw .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
    line = TWDA.cleanText(line)
    if line == "" then
      flush()
    elseif not line:find("%l") and line:find("%u%u") then
      flush()
      heading = TWDA.normalCaps(line)
    else
      names[#names + 1] = line
    end
  end
  flush()
  return TWDA.joinSentences(out)
end

function TWDA.creditsText()
  if not creditsActive then return nil end
  local parts = {}
  for _, name in ipairs({ "ui_creditsClosing_textTitle", "ui_creditsClosing_text" }) do
    local okFind, agent = pcall(AgentFind, name)
    local okNode, node = pcall(AgentGetProperty, agent, kTextNode)
    if okFind and agent and okNode and type(node) == "string" and node ~= "" then
      parts[#parts + 1] = TWDA.normalCaps(TWDA.agentText(agent))
    elseif okFind and agent then
      local ok, raw = pcall(AgentGetProperty, agent, "Text String")
      if ok and type(raw) == "string" and raw ~= "" then
        parts[#parts + 1] = formatCredits(raw)
      else
        parts[#parts + 1] = TWDA.agentText(agent)
      end
    end
  end
  return #parts > 0 and TWDA.joinSentences(parts) or nil
end

TWDA.hookGlobal("Credits", function(original)
  return function(...)
    creditsActive = true
    queue("title", "Credits. F6 reads them, Escape goes back")
    local results = table.pack(pcall(original, ...))
    creditsActive = false
    if not results[1] then error(results[2], 0) end
    return table.unpack(results, 2, results.n)
  end
end)
