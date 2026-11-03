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
  -- A shown check mark (the save file in use) is said last as "checked" (Michonne's has the text
  -- "check Mark Current Save").
  if name:find("checkmark$") then
    seen[""] = true
    return
  end
  local text = TWDA.normalCaps(TWDA.agentText(agent))
  if text and not seen[text] then
    seen[text] = true
    out[#out + 1] = text
  end
  local ok, children = pcall(AgentGetChildren, agent)
  if ok and type(children) == "table" then
    for _, child in pairs(children) do visibleTexts(child, out, seen, depth + 1) end
  end
  if depth == 0 and seen[""] and #out > 0 then out[#out + 1] = "checked" end
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
  -- (Michonne's Your Choices has a tab per episode holding that episode's rows; the rows are read
  -- with the screen, menus.stats, so a tab is just its episode.)
  local widgetName = TWDA.agentName(rawget(widget, "agent"))
  local tab = widgetName:match("^ui_stats_tabsParent_tabEpisode(%d+)$")
  if tab then return "Episode " .. tab end
  -- (A row: its question, then how many chose the same.)
  if widgetName:find("^ui_stats_episode%d+_stat%d+$") then
    local row = {}
    for _, suffix in ipairs({ "_question", "_label" }) do
      local okF, part = pcall(AgentFind, widgetName .. suffix)
      row[#row + 1] = okF and part and TWDA.agentText(part) or nil
    end
    if #row > 0 then return TWDA.joinSentences(row) end
  end
  local parts = {}
  -- Carousel elements (seasons, episodes) describe themselves.
  for _, method in ipairs({ "GetDisplayTitle", "GetDisplaySubtitle", "GetDisplayStatus", "GetDisplayAction",
    "GetDisplayDescription" }) do
    local text = TWDA.normalCaps(TWDA.keyOrText(call(widget, method)))
    if text and TWDA.isPlaceholder and TWDA.isPlaceholder(text) then text = nil end
    if text then
      -- "Episode 1 Ties That Bind PART ONE" (A New Frontier): a run of capitals words reads as
      -- words (a lone "AJ" stays).
      text = TWDA.capitalRuns(text)
      -- Its subtitle repeats "Episode 1" from the title.
      local repeated = false
      for _, part in ipairs(parts) do
        if part:find(text, 1, true) then repeated = true end
      end
      if not repeated then parts[#parts + 1] = text end
    end
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
-- (A New Frontier's Episodes screen, near the end: the one that has settled.)
local episodesMenu, episodesSeenAt, episodesKeys, episodesStartAt = nil, nil, {}, nil

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
  -- (Not for a mouse arrow, which has no label: Season Select's arrows sit at the top of the menu,
  -- so their siblings are the whole screen, "Escape Previous Menu" first.)
  if TWDA.agentName(button):lower():find("arrow", 1, true) then return nil end
  local okP, parent = pcall(AgentGetParent, button)
  if not okP or parent == nil then return nil end
  -- (Nor for a button straight under a widget menu's own agent, whose siblings are the whole
  -- screen: The Final Season's Episodes screen has a blank "ui_menuEpisodes_buttonReference".)
  local okM, menu = pcall(function() return Menu_GetCurrentMenu and Menu_GetCurrentMenu() end)
  if okM and type(menu) == "table" and TWDA.agentName(rawget(menu, "agent")) == TWDA.agentName(parent) then return nil end
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

-- Season 2's carousels (uiz_coverflow.lua: Chapter Select, the save files, the end-of-episode
-- choice statistics): Left and Right slide the panels, and Enter takes the one in the centre
-- (CoverFlow_GetCenterPanel). The buttons on the panels are selected out of step with it (the
-- arrows also move button.imap's selection), so the centre panel is read instead of them.
local function activeCoverflow()
  local enter = rawget(G, "CoverFlow_ButtonEnter")
  if type(enter) ~= "function" then return nil end
  local cf = TWDA.upvalue(enter, "mActiveCoverFlow")
  if type(cf) ~= "table" then return nil end
  local okA, root = pcall(UIZ_GetActiveMenu)
  if not okA or root == nil or TWDA.agentName(root) ~= TWDA.agentName(cf) then return nil end
  return cf
end

local function inCoverflowPanel(cf, agent)
  local panels = rawget(cf, "panels") or {}
  for _ = 1, 6 do
    for _, panel in ipairs(panels) do
      if panel == agent then return true end
    end
    local ok, parent = pcall(AgentGetParent, agent)
    if not ok or parent == nil then return false end
    agent = parent
  end
  return false
end

-- The texts under a Season 2 menu's header: Chapter Select's "Episode 1: All That Remains".
local function season2Subheader(root)
  local okC, kids = pcall(AgentGetChildren, root)
  for _, k in ipairs(okC and type(kids) == "table" and kids or {}) do
    if TWDA.agentName(k):find("^ui_header_reference") then
      local okH, heads = pcall(AgentGetChildren, k)
      for _, h in ipairs(okH and type(heads) == "table" and heads or {}) do
        if TWDA.agentName(h):find("^ui_subheader_%d+$") and not isHidden(h) then
          return TWDA.normalCaps(TWDA.agentText(h))
        end
      end
    end
  end
  return nil
end

-- The end-of-episode statistics ("My Choices"): one panel per episode, its rows in agents
-- ui_coverflow_stat_category3_1, ..._name3_1 and ..._description3_1 (row 3 of panel 1).
local function statsPanelText(panel)
  local n = TWDA.agentName(panel):match("^ui_coverflow_stat_reference_(%d+)$")
  if not n then return nil end
  local rows = {}
  local okS, agents = pcall(SceneGetAgents, AgentGetScene(panel))
  for _, a in ipairs(okS and type(agents) == "table" and agents or {}) do
    local field, row, p = TWDA.agentName(a):match("^ui_coverflow_stat_(%a+)(%d+)_(%d+)$")
    if field and p == n and not isHidden(a) then
      local r = tonumber(row)
      rows[r] = rows[r] or {}
      rows[r][field] = TWDA.normalCaps(TWDA.agentText(a))
    end
  end
  local parts = {}
  for r = 1, 20 do
    local row = rows[r]
    if row and (row.name or row.description) then
      local bits = {}
      if row.category then bits[#bits + 1] = row.category .. ":" end
      if row.name then bits[#bits + 1] = row.name end
      if row.description then bits[#bits + 1] = row.description end
      parts[#parts + 1] = TWDA.joinSentences(bits)
    end
  end
  if #parts == 0 then return nil end
  return TWDA.joinSentences(parts)
end

local function coverflowPanelText(cf, panel)
  local stats = statsPanelText(panel)
  if stats then
    local sub = season2Subheader(cf)
    -- (Continue is a button under the panel that the Down arrow selects; Enter alone does nothing.)
    local keys = "Down arrow to Continue, then Enter"
    return sub and TWDA.joinSentences({ sub, stats, keys }) or TWDA.joinSentences({ stats, keys })
  end
  local text = TWDA.visibleText(panel)
  if rawget(panel, "isDiorama") then
    -- (The diorama's own text is its button, "Start Episode 2"; which episode it is, with its
    -- name, is in the header.)
    local sub = season2Subheader(cf)
    if sub then text = text and TWDA.joinSentences({ sub, text }) or sub end
  end
  return text
end

-- A Season 2 menu's title and size, once per menu. The menu is a root agent ("ui_menu_settings",
-- "ui_coverflow_saveSlots") whose rows ("..._reference_N") are its children or one level down;
-- the title is its shown "ui_header_N" (none on the main menu). Carousels go left and right.
local lastSeason2Root, season2WasEmpty = nil, false
local function season2TitleOf(root)
  local rootName = root ~= nil and TWDA.agentName(root) or ""
  if rootName == "" then return nil end
  local cf = activeCoverflow()
  if cf then
    local title
    local okC, kids = pcall(AgentGetChildren, root)
    for _, k in ipairs(okC and type(kids) == "table" and kids or {}) do
      if TWDA.agentName(k):find("^ui_header_reference") then
        local okH, heads = pcall(AgentGetChildren, k)
        for _, h in ipairs(okH and type(heads) == "table" and heads or {}) do
          if TWDA.agentName(h):find("^ui_header_%d+$") and not isHidden(h) then title = TWDA.normalCaps(TWDA.agentText(h)) end
        end
      end
    end
    local count = #(rawget(cf, "panels") or {})
    if not title or count == 0 then return nil end
    if count == 1 then return title end -- (one panel, the episode's statistics: it says the rest)
    local lower = title:lower()
    local noun = (lower:find("menu$") or lower:find("^select") or lower:find("^choose")) and "" or " menu"
    return ("%s%s, %d %s. Left and right arrows to choose, Enter to select"):format(title, noun, count,
      count == 1 and "item" or "items")
  end
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
  -- (The main menu and the pause menu have no header.)
  title = title or ({ ui_menu_main = "Main", ui_menu_pause = "Pause" })[rootName]
  -- Screens with a message of their own instead of a header ("ui_menu_importSave_search" shows
  -- ui_importSave_messageHeader and ui_importSave_messageBody, outside the menu's own agents).
  local notes = {}
  local token = rootName:match("^ui_menu_([^_]+)")
  if not title and token then
    local found = {}
    local okS, agents = pcall(SceneGetAgents, AgentGetScene(root))
    for _, a in ipairs(okS and type(agents) == "table" and agents or {}) do
      local name = TWDA.agentName(a)
      if name:sub(1, #token + 4) == "ui_" .. token .. "_" and not isHidden(a) then
        local text = TWDA.normalCaps(TWDA.agentText(a))
        local okPos, pos = pcall(AgentGetScreenPos, a)
        if text and text ~= "" then found[#found + 1] = { text = text, y = okPos and pos and pos.y or 0 } end
      end
    end
    table.sort(found, function(a, b) return a.y < b.y end)
    for i, f in ipairs(found) do
      if i == 1 then title = f.text else notes[#notes + 1] = f.text end
    end
  end
  if not title then return nil end
  -- (A screen with nothing to choose, Controls' picture of the keys; the frame check waits longer
  -- for these, since a menu has no rows either just after it is pushed.)
  if count == 0 then return title .. ". Nothing to choose here, only a picture. Escape goes back", true end
  local keys = rootName:find("coverflow", 1, true) and "Left and right arrows to choose" or "Up and down arrows to choose"
  if #notes > 0 then
    -- (A message with its buttons: say the message, then how to answer.)
    notes[#notes + 1] = count == 1 and "Enter to select" or (keys .. ", Enter to select")
    return TWDA.joinSentences({ title, table.unpack(notes) })
  end
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

-- The centre panel of a Season 2 carousel, read once it has stopped there (the header's subheader
-- follows the panel a moment later).
local cfCenter, cfCenterSince, cfSpoken = nil, 0, nil
TWDA.onFrame("menus.coverflow", function()
  local cf = activeCoverflow()
  if not cf then
    cfCenter, cfSpoken = nil, nil
    return
  end
  if TWDA.agentName(lastSeason2Root) ~= TWDA.agentName(cf) then return end -- (after the title)
  local okM, moving = pcall(CoverFlow_IsMoving, cf)
  local okC, center = pcall(CoverFlow_GetCenterPanel, cf)
  if (okM and moving) or not okC or type(center) ~= "table" then return end
  local now = TWDA.now()
  if center ~= cfCenter then
    cfCenter, cfCenterSince = center, now
    return
  end
  if center == cfSpoken or now - cfCenterSince < 0.2 then return end
  local text = coverflowPanelText(cf, center)
  if not text then return end
  cfSpoken = center
  current = { button = nil, widget = nil, text = text, time = now }
  TWDA.lastMenuItem = text
  queue("item", text)
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
  -- (A button whose widget is the whole menu reads its own words: The Final Season's "Start
  -- Episode 4" on the Episodes screen, not the screen.)
  local okM, menu = pcall(function() return Menu_GetCurrentMenu and Menu_GetCurrentMenu() end)
  local whole = okM and type(menu) == "table" and type(widget) == "table" and rawget(widget, "agent") ~= nil
    and TWDA.agentName(rawget(widget, "agent")) == TWDA.agentName(rawget(menu, "agent"))
  local base
  if whole then
    base = TWDA.agentText(button) -- (and a blank one there is not read)
  else
    base = describeWidget(widget) or TWDA.agentText(button) or siblingText(button)
  end
  if not base and TWDA.agentName(button):find("[Cc]loseButton$") then base = "Close" end
  if base and type(rawget(G, "UIZ_GetActiveMenu")) == "function" then
    base = TWDA.normalCaps(base)
    local value = season2RowValue(button)
    if value then base = base .. ", " .. value end
  end
  local raw = base
  if base and TWDA.agentName(button):find("legendButton", 1, true) then base = legendButtonText(base) end
  local text = base
  if text and TWDA.settings.tooltips ~= false and not whole then
    local tip = tooltipOf(widget)
    if tip and tip ~= text and tip ~= raw then text = text .. ". " .. tip end
  end
  -- (Its value is not watched either: the whole screen would be read as a changed value.)
  if whole then widget = nil end
  return text, widget, base, raw
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

-- When the player last pressed an arrow key or Tab, and last moved the mouse.
local navKeyAt, mouseMovedAt, lastCursor = -10, -10, nil
TWDA.onFrame("menus.input", function()
  local now = TWDA.now()
  for _, vk in ipairs({ 0x09, 0x25, 0x26, 0x27, 0x28, 0x31, 0x32, 0x33, 0x34 }) do
    local ok, down = pcall(InputPCIsVKeyPressed, vk)
    if ok and down == true then navKeyAt = now end
  end
  local ok, cursor = pcall(CursorGetDevicePos)
  if ok and cursor then
    if lastCursor and (math.abs(cursor.x - lastCursor.x) > 2 or math.abs(cursor.y - lastCursor.y) > 2) then mouseMovedAt = now end
    lastCursor = { x = cursor.x, y = cursor.y }
  end
end)

local function onSelect(button)
  if mouseDepth == 0 and isArrowButton(button) then
    local target = redirectTarget(button)
    if target and target ~= button then
      redirectTo = { button = target, quiet = TWDA.agentName(button):find("^ui_seasons_arrow") ~= nil }
      return
    end
  end
  local cf = activeCoverflow()
  if cf and inCoverflowPanel(cf, button) then return end -- (the centre panel is read instead)
  -- A button the resting mouse pointer happens to be over as a carousel comes up ("Change Save
  -- File" at the bottom of Season 2's Chapter Select) is not the player's choice; Enter still takes
  -- the centre panel.
  local now = TWDA.now()
  if cf and now - navKeyAt > 0.5 and now - mouseMovedAt > 1 then
    TWDA.log("menus: " .. TWDA.agentName(button) .. " selected under the resting mouse; not read")
    return
  end
  -- (Nor a legend button there, as a menu opens: A New Frontier's "Copy" under the Save Files list.)
  if TWDA.agentName(button):find("legendButton", 1, true) and now - navKeyAt > 0.5 and now - mouseMovedAt > 1 then
    TWDA.log("menus: " .. TWDA.agentName(button) .. " (legend) selected under the resting mouse; not read")
    return
  end
  -- (Nor a caption of The Final Season's story recap there as its question comes up: it cut the
  -- question off.)
  if TWDA.agentName(button):find("^ui_configurator_button") and ((now - navKeyAt > 0.5 and now - mouseMovedAt > 1)
      or not (TWDA.configuratorOpen and TWDA.configuratorOpen())) then
    TWDA.log("menus: " .. TWDA.agentName(button) .. " (recap) selected under the resting mouse; not read")
    return
  end
  -- (A New Frontier's Episodes screen selects each episode in turn as it fills in; it is read once
  -- it has settled, below.)
  local okMenu, menuNow = pcall(Menu_GetCurrentMenu)
  if okMenu and type(menuNow) == "table" and TWDA.agentName(rawget(menuNow, "agent")) == "ui_menuEpisodes"
      and episodesMenu ~= menuNow then
    return
  end
  local text, widget, base, raw = describeButton(button)
  local s2title = season2Title(button)
  if s2title then
    menuTitle = s2title
    queue("title", s2title)
  end
  if quietButton == button then
    quietButton = nil
    current = { button = button, widget = widget, text = base, raw = raw, time = now }
    if text then TWDA.lastMenuItem = text end
    return
  end
  if current and current.button == button and not pending.title and now - current.time < 0.5 then return end
  current = { button = button, widget = widget, text = base, raw = raw, time = now }
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
  -- (raw: before a legend button's label was put first.)
  local old = current.raw or current.text
  if text and text ~= old then
    local changed = changedPart(old, text)
    current.text, current.raw = text, text
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

-- Keys in the legend other than the usual Select, Previous menu and Close, which every menu has.
local function unusualKeys(menu)
  local keys = {}
  for _, entry in ipairs(TWDA.menuLegendFor and TWDA.menuLegendFor(menu) or {}) do
    local label = entry:match(":%s*(.*)$") or ""
    local l = label:lower()
    if l ~= "select" and l ~= "previous menu" and l ~= "close" then keys[#keys + 1] = entry end
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
      -- (A New Frontier keeps the text one level down: ui_menuSettings_header_header.)
      local text = TWDA.agentText(agent) or TWDA.visibleText(agent)
      if text then return text end
    end
  end
  -- A header that is not a widget (A New Frontier's Save Files popup: ui_popupSave_header; its
  -- story setup moves its header into a group, ui_saveFileConfig_leftGroup).
  local function find(agent, depth)
    local ok, children = pcall(AgentGetChildren, agent)
    for _, child in ipairs(ok and type(children) == "table" and children or {}) do
      local name = TWDA.agentName(child)
      if not isHidden(child) then
        if name:find("_header$") or name:find("_title$") then
          local text = TWDA.agentText(child) or TWDA.visibleText(child)
          if text then return text end
        elseif depth < 2 then
          local text = find(child, depth + 1)
          if text then return text end
        end
      end
    end
    return nil
  end
  return find(rawget(menu, "agent"), 1) or MENU_NAMES[agentName]
end


local function buttonCount(widget)
  local names = rawget(widget, "buttonNames")
  return type(names) == "table" and #names or 0
end

-- Shown buttons of a widget that are not mouse arrows: a group of choices (A New Frontier's
-- "Start New Story" and "Continue Your Story" are one widget) counts each.
local function shownChoices(widget)
  local count = 0
  for _, name in ipairs(rawget(widget, "buttonNames") or {}) do
    local ok, agent = pcall(AgentFind, name)
    if ok and agent and not isHidden(agent) and not tostring(name):lower():find("arrow", 1, true) then
      count = count + 1
    end
  end
  return count
end

-- A grid (Michonne's save files, 2 by 2) holds its buttons in widgets of its own.
local function gridButtons(widget)
  local count = 0
  for _, inner in ipairs(type(rawget(widget, "nCols")) == "number" and rawget(widget, "widgets") or {}) do
    if type(inner) == "table" and buttonCount(inner) > 0 then count = count + 1 end
  end
  return count
end

-- Things to choose: widgets with at least one button, apart from the header and legend.
local function itemCount(menu)
  local count = 0
  for _, widget in ipairs(rawget(menu, "widgets") or {}) do
    local name = TWDA.agentName(rawget(widget, "agent"))
    if not isChrome(name) and buttonCount(widget) > 0 then count = count + math.max(1, shownChoices(widget)) end
    if not isChrome(name) then count = count + gridButtons(widget) end
  end
  return count
end

-- "A grid, 2 across: arrow keys move." for a menu laid out in rows and columns.
local function gridNote(menu)
  for _, widget in ipairs(rawget(menu, "widgets") or {}) do
    local cols = rawget(widget, "nCols")
    if type(cols) == "number" and cols > 1 and gridButtons(widget) > cols then
      return ("A grid, %d across: arrow keys move"):format(cols)
    end
  end
  return nil
end

-- Static text in a menu (the About page's body, for instance): widgets without buttons.
local function contentTexts(menu)
  local texts = {}
  for _, widget in ipairs(rawget(menu, "widgets") or {}) do
    local agent = rawget(widget, "agent")
    local name = TWDA.agentName(agent)
    if not isChrome(name) and buttonCount(widget) == 0 and gridButtons(widget) == 0 and not isHidden(agent) then
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
local announcedMenu, announcedTitle = nil, nil -- the menu whose title was read last, and that title
TWDA.onFrame("menus.title", function()
  if not shownMenu then return end
  local menu = shownMenu
  local title = titleOf(menu)
  local rawTitle = title
  -- A capitals heading run together with a sentence under it (A New Frontier's "CHOOSE HOW TO
  -- BEGIN YOUR STORY The Walking Dead: A New Frontier can be started ...").
  local heading, description = (title or ""):match("^([%u%d][%u%d%p ]+) (%u%l.*)$")
  if heading then title = heading end
  title = TWDA.normalCaps(title)
  if title == "Paused" then title = "Pause menu" end -- (A New Frontier's pause menu header)
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
  announcedMenu, announcedTitle = menu, rawTitle
  if not title then return end
  local short = select(2, title:gsub("%S+", "")) <= 3
  local text = title .. ((title:lower():find("menu$") or not short) and "" or " menu")
  local items = count > 0 and (count .. (count == 1 and " item" or " items")) or nil
  -- (A sentence for a heading, such as the imported story's summary, keeps its count apart.)
  if items and not title:find("[%.%?!]$") then text, items = text .. ", " .. items, nil end
  local sentences = { text, items }
  if description then sentences[#sentences + 1] = description end
  sentences[#sentences + 1] = gridNote(menu)
  for _, note in ipairs(contentTexts(menu)) do sentences[#sentences + 1] = note end
  for _, note in ipairs(sceneNotes(menu)) do sentences[#sentences + 1] = note end
  for _, key in ipairs(unusualKeys(menu)) do sentences[#sentences + 1] = key end
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
TWDA.menuLegendFor = function(menu) return legendFor(menu) end

-- A screen that changes its heading in place is read again as a new menu (A New Frontier's story
-- setup goes from "Choose how to begin your story" to "Your story so far" on the same menu).
local retitleAt = 0
TWDA.onFrame("menus.retitle", function()
  local now = TWDA.now()
  if shownMenu or now - retitleAt < 0.25 then return end
  retitleAt = now
  local menu = currentMenu()
  if not menu or menu ~= announcedMenu then return end
  local title = titleOf(menu)
  if title and title ~= announcedTitle then
    announcedTitle = title
    shownMenu, shownAt = menu, now
  end
end)

-- Help text that a screen shows for its selected item in an agent of its own (A New Frontier:
-- ui_saveFileconfig_tooltip, "Continue this story: Clem is on the road with AJ."), said after the
-- item.
local lastTip, tipAt = nil, 0
local function tooltipAgent(menu)
  local ok, children = pcall(AgentGetChildren, rawget(menu, "agent"))
  for _, child in ipairs(ok and type(children) == "table" and children or {}) do
    if TWDA.agentName(child):lower():find("tooltip$") and not isHidden(child) then return child end
  end
  return nil
end
TWDA.onFrame("menus.tooltip", function()
  local now = TWDA.now()
  if now - tipAt < 0.15 then return end
  tipAt = now
  local menu = currentMenu()
  local agent = menu and tooltipAgent(menu)
  local tip = agent and TWDA.agentText(agent) -- (visibleText leaves tooltips out)
  if tip == lastTip then return end
  lastTip = tip
  if not tip or TWDA.settings.tooltips == false then return end
  if TWDA.lastMenuItem and TWDA.lastMenuItem:find(tip, 1, true) then return end
  if pending.item then
    pending.item = pending.item .. ". " .. tip
  else
    TWDA.say(tip)
  end
end)

-- The menu a legend belongs to: the one just shown, if any (a popup builds its legend before it
-- becomes the current menu: A New Frontier's Save Files popup over Settings), else the current one.
local function legendMenu()
  if shownMenu and TWDA.now() - shownAt < 1 then return shownMenu end
  return currentMenu()
end

TWDA.hookBefore("Legend_Clear", function()
  local menu = legendMenu()
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
  local menu = legendMenu()
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
  local list = legendFor(menu)
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
    -- (Back in Season Select after playing a season, focus is still on the carousel's left arrow,
    -- where Enter slid one season left and played that: The Final Season instead of Michonne.)
    if okSel and (selected == nil or isArrowButton(selected)) then
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
    -- (While A New Frontier's Episodes screen fills in, each episode is selected in turn.)
    if TWDA.agentName(rawget(self, "agent")) == "ui_menuEpisodes" and episodesMenu ~= self then return end
    local widget = call(self, "GetSelectedElementWidget")
    -- (The Final Season's Episodes screen hands back the whole screen here; its buttons are read
    -- as they are selected.)
    if type(widget) == "table" and TWDA.agentName(rawget(widget, "agent")) == TWDA.agentName(rawget(self, "agent")) then return end
    local text = describeWidget(widget)
    -- (Already read when SelectElement selected the element's own button, as A New Frontier's
    -- does before its move animation ends.)
    if text and current and current.text == text and TWDA.now() - current.time < 2 then return end
    if text then
      current = { button = nil, widget = widget, text = text, time = TWDA.now() }
      TWDA.lastMenuItem = text
      queue("item", text)
    end
  end)
end
TWDA.onFrame("menus.carousel", attachCarousel)

-- A New Frontier's choice statistics after an episode (menu_stats.lua, ui_stats_reference): one
-- page per choice, the one showing in upvalue mVisibleWidget (mCurrentPageIndex of mStatPages);
-- a page says "Did you stay the night at the junkyard?" (its _question) and "You and 45.4% of
-- players chose to ..." (its _label), with the bars' percentages beside. Read as each page shows.
-- The Final Season's pages are in pieces named after the page: "You and" (_headerText), "39%"
-- (_massiveText), "of players turned to Louis for help against Marlon." (_secondaryHeaderText),
-- then the other choices or the reasons (_bodyText01, _text01...; the season's summary page:
-- HeaderText, Text01...). The game's own "15%left AJ feeling PRAGMATIC." is put right.
local STAT_PIECES = { question = 1, headerText = 2, HeaderText = 2, massiveText = 3, secondaryHeaderText = 4,
  label = 5, text = 10, Text = 10, bodyText = 10 }
local function finalSeasonStatPage(agent, name)
  local okS, agents = pcall(function() return SceneGetAgents(AgentGetScene(agent)) end)
  local pieces = {}
  for _, other in ipairs(okS and type(agents) == "table" and agents or {}) do
    local suffix = TWDA.agentName(other):sub(#name + 1)
    local kind, number = suffix:match("^_?(%a+)(%d*)$")
    local rank = TWDA.agentName(other):sub(1, #name) == name and kind and STAT_PIECES[kind]
    local text = rank and TWDA.agentText(other)
    if text then pieces[#pieces + 1] = { rank = rank + (tonumber(number) or 0) / 100, text = text } end
  end
  table.sort(pieces, function(a, b) return a.rank < b.rank end)
  local head, parts = {}, {}
  for _, piece in ipairs(pieces) do
    local text = piece.text:gsub("(%d%%)(%a)", "%1 %2"):gsub("%f[%a](%u)(%u%u%u+)%f[%A]", function(first, rest)
      return first .. rest:lower()
    end)
    if piece.rank >= 2 and piece.rank < 5 then head[#head + 1] = text else parts[#parts + 1] = text end
  end
  if #head > 0 then table.insert(parts, 1, table.concat(head, " ")) end
  return parts
end

-- Michonne's choices after an episode (its own menu_stats, no pages): one episode's questions at
-- once, "Did you try to end it?" (ui_stats_episode1_stat1_question) and "You and 32.5% of players
-- pulled the trigger." (..._label), under ui_stats_episodeTitle ("Episode 1: In Too Deep").
local function michonneStats(menu)
  local okS, agents = pcall(function() return SceneGetAgents(AgentGetScene(rawget(menu, "agent"))) end)
  local rows = {}
  for _, agent in ipairs(okS and type(agents) == "table" and agents or {}) do
    local episode, stat, field = TWDA.agentName(agent):match("^ui_stats_episode(%d+)_stat(%d+)_(%a+)$")
    local text = episode and not isHidden(agent) and TWDA.agentText(agent) or nil
    if text then
      local n = tonumber(episode) * 100 + tonumber(stat)
      rows[n] = rows[n] or {}
      rows[n][field] = text
    end
  end
  local order = {}
  for n in pairs(rows) do order[#order + 1] = n end
  table.sort(order)
  if #order == 0 then return nil end
  local okT, title = pcall(AgentFind, "ui_stats_episodeTitle")
  local parts = { "Your choices", okT and title and TWDA.agentText(title) or nil }
  for i, n in ipairs(order) do
    local row = rows[n]
    parts[#parts + 1] = ("%d: %s"):format(i, TWDA.joinSentences({ row.question, row.label }))
  end
  -- (After an episode: Continue, selected only once an arrow key is pressed. From the main menu's
  -- Your Choices: Previous Menu, Escape.)
  local okB, back = pcall(AgentFind, "ui_stats_legendMenu_legendButton_back")
  local backText = okB and back and TWDA.agentText(back) or ""
  if backText:lower():find("continue", 1, true) then
    parts[#parts + 1] = "Down arrow, then Enter to continue"
  else
    parts[#parts + 1] = "Escape goes back"
  end
  local text = TWDA.joinSentences(parts)
  return text
end

local statsWidget = nil
local statsPending, statsPendingAt = nil, 0
local statsEnterDown = false
TWDA.onFrame("menus.stats", function()
  local menu = currentMenu()
  if not menu or TWDA.agentName(rawget(menu, "agent")) ~= "ui_stats_reference" then
    statsWidget = nil
    return
  end
  -- (The Final Season's Continue under the stats, upvalue mCallToActionButton of
  -- Menu_Stats_UpdateActionButtons, takes only the mouse: Enter presses it here.)
  local okE, enter = pcall(InputPCIsVKeyPressed, 0x0D)
  enter = okE and enter == true
  if enter and not statsEnterDown then
    local button = TWDA.upvalue(rawget(G, "Menu_Stats_UpdateActionButtons"), "mCallToActionButton")
    local okC, cursorOnly = pcall(function() return button:IsCursorOnly() end)
    local okH, hidden = pcall(AgentIsHidden, "ui_stats_buttonCTA")
    if okC and cursorOnly == true and okH and hidden == false then
      TWDA.log("menus: stats Continue")
      pcall(ThreadStart, function() button:Execute() end)
    end
  end
  statsEnterDown = enter
  local transition = rawget(G, "Menu_Stats_TransitionToPage")
  if type(transition) ~= "function" then
    -- (The rows come in one by one: read once they have held still for 0.8 s.)
    local text = michonneStats(menu)
    local now = TWDA.now()
    if text ~= statsPending then statsPending, statsPendingAt = text, now end
    if text and text ~= statsWidget and now - statsPendingAt >= 0.8 then
      statsWidget = text
      current = { button = nil, widget = nil, text = text, time = now }
      queue("title", text)
    end
    return
  end
  local widget = TWDA.upvalue(transition, "mVisibleWidget")
  if type(widget) ~= "table" or widget == statsWidget then return end
  statsWidget = widget
  local agent = rawget(widget, "agent")
  local name = TWDA.agentName(agent)
  local parts = {}
  for _, suffix in ipairs({ "_question", "_label" }) do
    local okF, part = pcall(AgentFind, name .. suffix)
    local text = okF and part and not isHidden(part) and TWDA.agentText(part) or nil
    if text then parts[#parts + 1] = text end
  end
  if #parts == 0 then parts = finalSeasonStatPage(agent, name) end
  if #parts == 0 then
    local text = TWDA.visibleText(agent)
    if text then parts[#parts + 1] = text end
  end
  local pages = TWDA.upvalue(transition, "mStatPages") -- (per episode)
  pages = type(pages) == "table" and pages[TWDA.upvalue(transition, "mCurrentEpisode") or 1] or nil
  local index = TWDA.upvalue(transition, "mCurrentPageIndex")
  if type(pages) == "table" and type(index) == "number" and #pages > 1 then
    if index == #pages then
      -- (The last page lists every choice again, with "Enter Continue" under it.)
      if #parts == 0 then parts[#parts + 1] = "All the choices again" end
      parts[#parts + 1] = "Enter continues. Left arrow goes back"
    else
      parts[#parts + 1] = ("Choice %d of %d. Left and right arrows for the others"):format(index, #pages)
    end
  end
  -- ("Your experience with David was:, Dysfunctional, ..." from the season summary's texts.)
  local text = TWDA.joinSentences(parts):gsub(":, ", ": ")
  current = { button = nil, widget = widget, text = text, time = TWDA.now() }
  TWDA.lastMenuItem = text
  queue("item", text)
end)

-- A New Frontier's Episodes screen (ui_menuEpisodes, a Carousel). On PC its arrow keys move focus
-- to an episode thumbnail without changing the episode shown, and Enter there does nothing; only
-- the mouse arrows switch episodes. So here Left and Right switch episodes with the carousel's own
-- SelectElement and focus stays on the action button ("Start Episode 2"): Enter plays the episode
-- just read. The thumbnails are taken out of keyboard navigation.
TWDA.onFrame("menus.episodes", function()
  local menu = currentMenu()
  if not menu or TWDA.agentName(rawget(menu, "agent")) ~= "ui_menuEpisodes" or rawget(menu, "shown") ~= true then
    episodesMenu, episodesSeenAt, episodesStartAt = nil, nil, nil
    return
  end
  local list = rawget(menu, "elementList")
  local elements = type(list) == "table" and list[rawget(menu, "currentTab")] or nil
  if type(elements) ~= "table" or #elements == 0 then
    -- (The Final Season's Episodes screen is a plain list instead, Up and Down, with "Start
    -- Episode 2" above it: read as any other menu; each episode's button reads its title and the
    -- start button's words too.)
    local okT, title = pcall(AgentFind, "ui_menuEpisodes_titleBacking")
    if not okT or title == nil then return end
    if episodesMenu ~= menu then
      episodesMenu = menu
      queue("title", "Episodes. Up and down arrows choose an episode, Enter on Start plays it")
      episodesStartAt = TWDA.now() + 0.5
    end
    -- (It opens with the focus on the episode's own button, where Enter does nothing; the game
    -- moves it to Start only after Up or Down. So it is put on Start, as the game would, once the
    -- game has selected the episode itself: done sooner, the game's own selection came after it.)
    if episodesStartAt and TWDA.now() >= episodesStartAt and rawget(menu, "bTransitioning") ~= true then
      local widget = current and current.widget
      local okA, agent = pcall(function() return rawget(widget, "agent") end)
      local onEpisode = okA and TWDA.agentName(agent):find("_list_element", 1, true) ~= nil
      if onEpisode and TWDA.now() - (current.time or 0) > 0.3 then
        episodesStartAt = nil
        local okB, button = pcall(Clone_Find, rawget(menu, "agent"), "_startButton")
        if okB and type(button) == "table" then pcall(ThreadStart, function() button:Select(true) end) end
      elseif TWDA.now() > episodesStartAt + 5 then
        episodesStartAt = nil
      end
    end
    return
  end
  local function actionButton()
    local ok, button = pcall(Clone_Find, rawget(menu, "agent"), "_actionButton")
    return ok and type(button) == "table" and button or nil
  end
  local function focusAction()
    local button = actionButton()
    if button then
      quietButton = button
      pcall(button.Select, button, true)
    end
  end
  if episodesMenu ~= menu then
    -- (Once it has settled: while it fills in, the episodes are read one after another, the last
    -- one heard not being the one chosen.)
    episodesSeenAt = episodesSeenAt or TWDA.now()
    if TWDA.now() - episodesSeenAt < 0.6 or rawget(menu, "bTransitioning") == true then return end
    episodesMenu, episodesSeenAt = menu, nil
    for _, element in ipairs(elements) do
      pcall(function() AgentSetProperty(element:GetButtonAgent(), "Game Selectable", false) end)
    end
    pcall(ThreadStart, focusAction)
    local widget = call(menu, "GetSelectedElementWidget")
    local text = describeWidget(widget)
    if text then
      current = { button = nil, widget = widget, text = text, time = TWDA.now() }
      TWDA.lastMenuItem = text
      queue("item", text)
    end
    queue("value", "Left and right arrows choose an episode, Enter plays it")
  end
  for vk, step in pairs({ [0x25] = -1, [0x27] = 1 }) do
    local ok, down = pcall(InputPCIsVKeyPressed, vk)
    down = ok and down == true
    if down and not episodesKeys[vk] and rawget(menu, "bTransitioning") ~= true then
      local index = ((rawget(menu, "currentElementIndex") or 1) - 1 + step) % #elements + 1
      pcall(ThreadStart, function()
        pcall(menu.SelectElement, menu, index)
        focusAction()
      end)
    end
    episodesKeys[vk] = down
  end
end)

-- Michonne's Episodes screen (menu_episodeselect.lua, menu agent ui_episodeSelect) has one
-- button, ui_episodeSelect_episodeStatus ("START EPISODE 1"), and draws the episode's name as a
-- picture; Left and Right slide to the next episode, ending in Menu_EpisodeSelect_SlideComplete
-- (also run when the screen opens), which sets the button's words a frame later.
local MICHONNE_EPISODES = { "In Too Deep", "Give No Shelter", "What We Deserve" }
local slidEpisode, slideReadAt, slideScreen = nil, nil, nil
TWDA.hookBefore("Menu_EpisodeSelect_SlideComplete", function(episode)
  slidEpisode, slideReadAt = tonumber(episode), TWDA.now() + 0.3
end)
TWDA.onFrame("menus.episodesM", function()
  if not slideReadAt or TWDA.now() < slideReadAt then return end
  slideReadAt = nil
  local menu = currentMenu()
  if not menu or TWDA.agentName(rawget(menu, "agent")) ~= "ui_episodeSelect" then return end
  local okS, status = pcall(AgentFind, "ui_episodeSelect_episodeStatus")
  local action = okS and status and TWDA.normalCaps(TWDA.agentText(status)) or nil
  local parts = {}
  if slideScreen ~= menu then
    slideScreen = menu
    parts[#parts + 1] = "Episodes"
  end
  local name = slidEpisode and MICHONNE_EPISODES[slidEpisode]
  if slidEpisode then parts[#parts + 1] = ("Episode %d%s"):format(slidEpisode, name and (": " .. name) or "") end
  if action then parts[#parts + 1] = action end
  if #parts == 0 then return end
  local text = TWDA.joinSentences(parts)
  current = { button = nil, widget = nil, text = text, time = TWDA.now() }
  TWDA.lastMenuItem = text
  queue("item", text)
  queue("value", "Left and right arrows choose an episode, Enter plays it")
  -- (After the mouse was used, the button is left unselected and Enter does nothing until an
  -- arrow key selects it: the game's OnWidgetInputChange. Select it now.)
  if okS and status and type(status.Select) == "function" and rawget(status, "mbSelected") ~= true then
    quietButton = status
    pcall(ThreadStart, function() pcall(status.Select, status, true) end)
  end
end)

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

-- An agent's text as written, line breaks and all: its dialog node's, else its "Text String".
local function rawText(agent)
  local okNode, node = pcall(AgentGetProperty, agent, "Text Dialog 2.0 Node Name")
  if okNode and type(node) == "string" and node ~= "" then
    local _, file = pcall(AgentGetProperty, agent, "Text Dialog 2.0 File")
    local ok, text = pcall(function() return DlgEvaluateToNode(file or "ui_menu.dlog", node, "text", false):GetText() end)
    if ok and type(text) == "string" and text ~= "" and text ~= node then return text end
  end
  local ok, raw = pcall(AgentGetProperty, agent, "Text String")
  return ok and type(raw) == "string" and raw ~= "" and raw or nil
end

-- The hub's credits (ui_creditsClosing_*), and Season 2's (credits.lua: ui_credits_text, from the
-- dialog node "text_credits"), both from the menu and after an episode.
function TWDA.creditsText()
  if not creditsActive then return nil end
  local parts = {}
  for _, name in ipairs({ "ui_creditsClosing_textTitle", "ui_creditsClosing_text", "ui_credits_text" }) do
    local okFind, agent = pcall(AgentFind, name)
    if okFind and agent then
      local raw = rawText(agent)
      local text = raw and raw:find("\n") and formatCredits(raw) or TWDA.normalCaps(TWDA.agentText(agent))
      if text and text ~= "" then parts[#parts + 1] = text end
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
