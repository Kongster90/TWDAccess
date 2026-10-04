-- Season 1's menus (and its in-game pause menu): the older "pane" framework.
--
-- The current mode is mode_MainMenu; it keeps the visible pane in a local (mCurrentPane) and passes
-- controller input to it. Its input map binds the controller's D-pad and the keyboard's Left,
-- Right, A, D and Escape, but not Up, Down or Enter, so on keyboard these menus only work with the
-- mouse. We supply those keys: Up and Down go to the mode's own OnUp and OnDown, Enter activates
-- the selected control the way a click does, and Backspace goes back. And we read it all out.
--
-- Settings panes (Gameplay, Audio, ...) keep Apply and Cancel outside the up/down list (a
-- controller applies with A on any row); we add them to the end of the list so the keyboard can
-- reach them. With the mouse, clicking a setting's value moves it to the next value, so Enter does
-- the same.
local TWDA = ...
local G = _G

local VK_BACK, VK_ENTER, VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN = 0x08, 0x0D, 0x25, 0x26, 0x27, 0x28

-- The modes that show panes: Season 1's menu, and its pause menu during play.
local PANE_MODES = { "mode_MainMenu", "mode_PauseMenu" }

-- The pane menu's mode, if one is the current mode.
local function activeMode()
  local ok, current = pcall(Mode_GetCurrent)
  if not ok or type(current) ~= "table" then return nil end
  for _, name in ipairs(PANE_MODES) do
    if rawget(G, name) == current then return current end
  end
  return nil
end

local function currentPane(mode)
  local pane = TWDA.upvalue(rawget(mode, "OnUp"), "mCurrentPane")
  if type(pane) == "table" then return pane end
  return nil
end

local function inputLocked()
  local ok, locked = pcall(Menu_InputLocked)
  return ok and locked == true
end

local function event(code)
  return { type = 0, code = code, x = 0, y = 0, agentName = "", controller = 0 }
end

local function prop(agent, name)
  local ok, value = pcall(AgentGetProperty, agent, name)
  if ok then return value end
  return nil
end

local function hidden(agent)
  local ok, value = pcall(AgentIsHidden, agent)
  return ok and value == true
end

-- Runs a menu action in its own script thread: they wait for animations, and our frame thread
-- must keep running meanwhile. Until it finishes (or a few seconds pass, in case the engine kills
-- the thread) the menu counts as busy and further keys wait.
local running, runningSince = 0, 0
local BUSY_SECONDS = 3

-- Set TWDA.panesDebug = true from the dev console to log every decision.
local function debug(text)
  if TWDA.panesDebug then TWDA.log("panes: " .. text) end
end

local function act(name, fn)
  -- Busy from now, not from when the thread first runs.
  running, runningSince = running + 1, TWDA.now()
  debug("act " .. name)
  local ok, err = pcall(ThreadStart, function()
    local okRun, errRun = pcall(fn)
    running = math.max(0, running - 1)
    if not okRun then TWDA.log("panes " .. name .. ": " .. tostring(errRun)) end
  end)
  if not ok then
    running = math.max(0, running - 1)
    TWDA.log("panes " .. name .. " (thread): " .. tostring(err))
  end
end

local function busy()
  if running > 0 and TWDA.now() - runningSince > BUSY_SECONDS then running = 0 end
  return running > 0
end

local function selectable(control)
  if control == nil or hidden(control) then return false end
  return prop(control, "Game Selectable") ~= false
end

local function sameAgent(a, b)
  if a == nil or b == nil then return false end
  return a == b or TWDA.agentName(a) == TWDA.agentName(b)
end

-- The pane's control whose name ends with the given text, if it is showing.
local function shownControl(pane, suffix)
  for _, agent in ipairs(pane.mControls or {}) do
    local name = TWDA.agentName(agent)
    if name:sub(-#suffix) == suffix and not hidden(agent) then return agent end
  end
  return nil
end

-- The Episode pane shows one episode at a time: Left and Right (the game's own keys) switch, Play
-- (or Continue) starts it, and once it has been played Rewind and Stats are on the controller's X
-- and Y (F9 and F10).
local function isEpisodePane(pane)
  return pane.name == "Episode" and shownControl(pane, "_labelEpisodeTitle") ~= nil
end

---------------------------------------------------------------------------------------------------
-- The extra buttons (Apply, Cancel) a settings pane leaves out of its up/down list.
---------------------------------------------------------------------------------------------------

local function indexed(pane, agent)
  for _, control in ipairs(pane.mIndexedControls or {}) do
    if sameAgent(control, agent) then return true end
  end
  return false
end

local function extrasOf(pane)
  local list = {}
  -- Panes with their own A action (Save Slots) act on the highlighted item instead; their bottom
  -- buttons stand for controller buttons, which F9 and F10 provide.
  if type(pane.OnA) == "function" then return list end
  for position, agent in ipairs(pane.mControls or {}) do
    if prop(agent, "Menu Control - Role") == "Button" and selectable(agent) and not indexed(pane, agent)
      and TWDA.visibleText(agent) then
      local okActive, active = pcall(pane.IsActiveControl, pane, agent)
      if not okActive or active then
        local okPos, pos = pcall(AgentGetScreenPos, agent)
        list[#list + 1] = { agent = agent, x = okPos and pos and pos.x or position, position = position }
      end
    end
  end
  -- Left to right, as on screen (Apply, Cancel).
  table.sort(list, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    return a.position < b.position
  end)
  for i, entry in ipairs(list) do list[i] = entry.agent end
  return list
end

local function extraIndex(extras, agent)
  for i, extra in ipairs(extras) do
    if sameAgent(extra, agent) then return i end
  end
  return nil
end

-- Whether the pane's own Up/Down can move from the current control (they stop at the ends).
local function hasNeighbor(pane, delta)
  local controls = pane.mIndexedControls or {}
  local index = (pane.mSelectedIndex or 1) + delta
  while controls[index] ~= nil do
    if selectable(controls[index]) then return true end
    index = index + delta
  end
  return false
end

local function lastSelectable(pane)
  local controls = pane.mIndexedControls or {}
  local remembered = controls[pane.mSelectedIndex or 1]
  if selectable(remembered) then return remembered end
  for i = #controls, 1, -1 do
    if selectable(controls[i]) then
      pane.mSelectedIndex = i
      return controls[i]
    end
  end
  return nil
end

local hasSettings -- defined with the reading code below

-- A settings pane's Left and Right adjust the selected row and fail when there is none (nothing
-- selected yet, or one of the extra buttons), which would leave menu input locked; they do nothing
-- there instead.
local function guardArrows(pane)
  for _, key in ipairs({ "OnLeft", "OnRight" }) do
    local original = rawget(pane, key)
    if type(original) == "function" and not TWDA.wrappers[original] then
      local wrapper = function(self, ...)
        local current = self.mCurrentSelected
        if current == nil and hasSettings(self) then return end
        if current ~= nil and extraIndex(extrasOf(self), current) then return end
        return original(self, ...)
      end
      TWDA.wrappers[wrapper] = true
      rawset(pane, key, wrapper)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Keys.
---------------------------------------------------------------------------------------------------

local repeatCurrent = false

local function selectControl(pane, target, quiet)
  local current = pane.mCurrentSelected
  act("select", function()
    pane:UpdateSelection(current, target)
    if not quiet then pcall(Menu_SoundPlay, prop(target, "Menu Button - Sound Select")) end
  end)
end

local function firstSelectable(pane)
  for i, control in ipairs(pane.mIndexedControls or {}) do
    if selectable(control) then
      pane.mSelectedIndex = i
      return control
    end
  end
  return nil
end

-- In mouse mode nothing is selected, and the pane's own Up/Down need a current selection, so the
-- first key press selects the remembered (or first) control.
local function ensureSelection(pane)
  if pane.mCurrentSelected ~= nil then return false end
  local controls = pane.mIndexedControls or {}
  local target = controls[pane.mSelectedIndex or 1]
  if not selectable(target) then
    target = nil
    for i, control in ipairs(controls) do
      if selectable(control) then
        target, pane.mSelectedIndex = control, i
        break
      end
    end
  end
  if target == nil then
    target = extrasOf(pane)[1]
    if target == nil then return false end
  end
  act("select", function() pane:UpdateSelection(nil, target) end)
  return true
end

local function move(mode, pane, delta)
  debug(("move %d: current %s, index %s"):format(delta, TWDA.agentName(pane.mCurrentSelected),
    tostring(pane.mSelectedIndex)))
  if isEpisodePane(pane) then
    repeatCurrent = true
    return
  end
  if ensureSelection(pane) then return end
  local extras = extrasOf(pane)
  local onExtra = extraIndex(extras, pane.mCurrentSelected)
  if onExtra then
    local target = extras[onExtra + delta]
    if target == nil and delta < 0 then target = lastSelectable(pane) end
    if target ~= nil then selectControl(pane, target) else repeatCurrent = true end
  elseif not indexed(pane, pane.mCurrentSelected) then
    -- Something outside the list is highlighted; the pane's own Up and Down would not move.
    local target = lastSelectable(pane)
    if target ~= nil then selectControl(pane, target) end
  elseif hasNeighbor(pane, delta) then
    if delta > 0 then
      act("down", function() mode:OnDown(event(525)) end)
    else
      act("up", function() mode:OnUp(event(524)) end)
    end
  elseif delta > 0 and extras[1] ~= nil then
    selectControl(pane, extras[1])
  else
    repeatCurrent = true
  end
end

-- Save Slots. The game plays "the selected slot", which only a click on a slot sets, while the
-- arrows move "the current slot" (which Delete and Copy use); Enter plays the highlighted slot, so
-- both are set to it first. In copy mode (after F10), Enter on a slot copies to it, as a click does.
local function slotNumber(agent)
  local group = prop(agent, "Menu Control - Group")
  return type(group) == "string" and tonumber(group:match("^Slot (%d+)$")) or nil
end

local function inCopyMode(pane)
  return TWDA.upvalue(rawget(pane, "OnMouseLUp"), "mbInCopyMode") == true
end

local function syncSlot(pane, both)
  local slot = slotNumber(pane.mCurrentSelected)
  if slot == nil or inCopyMode(pane) then return end
  rawset(G, "mCurrentSlot", slot)
  if both then rawset(G, "mSelectedSlot", slot) end
end

local function click(pane, agent)
  return { type = 0, code = 768, x = 0, y = 0, agentName = TWDA.agentName(agent), agent = agent, controller = 0 }
end

local function episodeStep(mode, pane, method, arrow)
  if not isEpisodePane(pane) then return end
  if shownControl(pane, arrow) == nil then
    repeatCurrent = true -- first or last episode
    return
  end
  act(method, function() mode[method](mode, event(0)) end)
end

local actions = {
  [VK_UP] = function(mode, pane) move(mode, pane, -1) end,
  [VK_DOWN] = function(mode, pane) move(mode, pane, 1) end,
  [VK_ENTER] = function(mode, pane)
    if isEpisodePane(pane) then
      local play = shownControl(pane, "_buttonPlay")
      if play then act("play", function() pane:OnMouseLUp(click(pane, play)) end) end
      return
    end
    if pane.mCurrentSelected == nil then
      ensureSelection(pane)
      return
    end
    if slotNumber(pane.mCurrentSelected) and inCopyMode(pane) then
      local target = pane.mCurrentSelected
      act("copy", function() pane:OnMouseLUp(click(pane, target)) end)
    elseif type(pane.OnA) == "function" and type(mode.OnA) == "function" then
      syncSlot(pane, true)
      act("activate", function() mode:OnA(event(512)) end)
    else
      act("activate", function() pane:OnMouseLUp(event(768)) end)
    end
  end,
  [VK_BACK] = function(mode, pane)
    act("back", function() mode:OnBackButton() end)
  end,
  -- Left and Right only switch episodes on one console; on PC the arrows on screen are for the
  -- mouse. (Elsewhere the game handles these keys itself.)
  [VK_LEFT] = function(mode, pane) episodeStep(mode, pane, "OnLB", "_buttonEpisodePrevious") end,
  [VK_RIGHT] = function(mode, pane) episodeStep(mode, pane, "OnRB", "_buttonEpisodeNext") end,
}

-- F9, F10, Page Up and Page Down (hotkeys.lua): the controller's X, Y and bumpers, for panes that
-- use them. Returns false when the pane has no such action.
local BUTTON_CODES = { OnX = 514, OnY = 515, OnLB = 516, OnRB = 517 }

function TWDA.paneButton(method)
  local mode = activeMode()
  local pane = mode and currentPane(mode)
  if not pane or type(pane[method]) ~= "function" or type(mode[method]) ~= "function" then return false end
  if busy() or inputLocked() then return true end
  syncSlot(pane, false)
  act(method, function()
    mode[method](mode, event(BUTTON_CODES[method] or 0))
    if method == "OnY" and inCopyMode(pane) then
      TWDA.say("Copy. Choose the slot to copy to and press Enter, or Backspace to cancel.", { interrupt = true })
    end
  end)
  return true
end

---------------------------------------------------------------------------------------------------
-- Reading: the pane's title when it changes, each newly selected control, and changes to its value
-- (Left and Right change settings; the game handles those keys itself).
---------------------------------------------------------------------------------------------------

-- A settings row keeps its name in a sibling agent ("ui_menu_gameplay_subtitlesLabel") next to
-- the value button.
local function labelOf(control)
  local ok, parent = pcall(AgentGetParent, control)
  if not ok or parent == nil then return nil end
  local okChildren, children = pcall(AgentGetChildren, parent)
  if not okChildren or type(children) ~= "table" then return nil end
  for _, child in pairs(children) do
    if not sameAgent(child, control) and TWDA.agentName(child):lower():find("label$") and not hidden(child) then
      local text = TWDA.normalCaps(TWDA.agentText(child))
      if text then return text end
    end
  end
  return nil
end

-- All visible text of a control and its children in reading order (top to bottom, then left to
-- right), so a save slot reads "Game 1, Episode 1, date".
local function collectTexts(agent, out, depth)
  if agent == nil or depth > 4 or hidden(agent) then return end
  local text = TWDA.normalCaps(TWDA.agentText(agent))
  if text then
    local ok, pos = pcall(AgentGetScreenPos, agent)
    local x, y = 0, 0
    if ok and pos then x, y = pos.x or 0, pos.y or 0 end
    out[#out + 1] = { text = text, row = math.floor(y / 0.02), x = x, n = #out }
  end
  local okChildren, children = pcall(AgentGetChildren, agent)
  if okChildren and type(children) == "table" then
    for _, child in pairs(children) do collectTexts(child, out, depth + 1) end
  end
end

local function valueOf(control)
  local items = {}
  collectTexts(control, items, 0)
  table.sort(items, function(a, b)
    if a.row ~= b.row then return a.row < b.row end
    if a.x ~= b.x then return a.x < b.x end
    return a.n < b.n
  end)
  local parts, seen = {}, {}
  for _, item in ipairs(items) do
    if not seen[item.text] then
      seen[item.text] = true
      parts[#parts + 1] = item.text
    end
  end
  return #parts > 0 and table.concat(parts, ", ") or nil
end

local function describe(control)
  local label, value = labelOf(control), valueOf(control)
  if label and value and label ~= value then return label .. ", " .. value end
  return label or value
end

-- The pane's heading ("Gameplay Settings"), else its name.
local function titleOf(pane)
  for _, agent in ipairs(pane.mControls or {}) do
    if TWDA.agentName(agent):lower():find("heading", 1, true) and not hidden(agent) then
      local text = TWDA.normalCaps(TWDA.agentText(agent))
      if text then return text end
    end
  end
  local name = type(pane.name) == "string" and pane.name or "Menu"
  return name .. (name:lower():find("menu$") and "" or " menu")
end

-- Panes that are only a labelled picture. The controls chart's labels read badly in agent order,
-- so it is described by hand.
local INFO = {
  Controls = "Move character: W, A, S and D. Choose dialog option: 1 to 4. Actions: left mouse button. "
    .. "Scroll dialog options: mouse wheel",
}

local function infoOf(pane)
  if #(pane.mIndexedControls or {}) > 0 or extrasOf(pane)[1] ~= nil or isEpisodePane(pane) then return nil end
  return INFO[pane.name] or TWDA.visibleText(pane.agent)
end

function hasSettings(pane)
  for _, control in ipairs(pane.mIndexedControls or {}) do
    if labelOf(control) then return true end
  end
  return false
end

local function episodeText(pane)
  local title = TWDA.normalCaps(TWDA.agentText(shownControl(pane, "_labelEpisodeTitle")))
  local play = shownControl(pane, "_buttonPlay")
  return TWDA.joinSentences({ title, play and valueOf(play) })
end

-- Longer labels that are not part of any row, such as "Settings can be changed later under the
-- Gameplay category."
local function notesOf(pane)
  local notes = {}
  for _, agent in ipairs(pane.mControls or {}) do
    if prop(agent, "Menu Control - Role") == "Label" and not hidden(agent) then
      local text = TWDA.agentText(agent)
      local _, words = (text or ""):gsub("%S+", "")
      if words >= 5 then notes[#notes + 1] = TWDA.normalCaps(text) end
    end
  end
  return #notes > 0 and TWDA.joinSentences(notes) or nil
end

local function withBack(pane, text)
  if pane.NoBackButton then return text end
  return text .. ", Backspace to go back"
end

local function keyHelp(pane)
  if isEpisodePane(pane) then
    local keys = { "Left and right arrows for other episodes", "Enter to play" }
    if shownControl(pane, "_buttonRewind") then keys[#keys + 1] = "F9 to rewind to a chapter" end
    if shownControl(pane, "_buttonStats") then keys[#keys + 1] = "F10 for your choice statistics" end
    keys[#keys + 1] = "Backspace to go back"
    return table.concat(keys, ", ")
  end
  if infoOf(pane) then return withBack(pane, "No items") end
  if pane.name == "Save Slots" then
    return withBack(pane, "Up and down arrows to choose a slot, Enter to play it, F9 to delete it, F10 to copy it")
  end
  if hasSettings(pane) then
    return "Up and down arrows to choose, Left and right to change, Enter on Apply to save, Backspace to cancel"
  end
  return withBack(pane, "Up and down arrows to choose, Enter to select")
end

local lastPane, lastControl, lastValue = nil, nil, nil
local held = {}
local lastPoll = 0
-- Keys pressed while the menu is busy (our last action still running, or input locked during a
-- pane's animation) run in order once it is ready, unless that takes too long.
local queue = {}
local QUEUE_SECONDS = 3
local QUEUE_MAX = 4

TWDA.onFrame("panes", function()
  local mode = activeMode()
  if not mode then
    lastPane, lastControl, lastValue = nil, nil, nil
    queue = {}
    return
  end
  local pane = currentPane(mode)
  if not pane then return end
  guardArrows(pane)

  -- Keys we supply.
  local locked = busy() or inputLocked()
  for vk in pairs(actions) do
    local ok, pressed = pcall(InputPCIsVKeyPressed, vk)
    pressed = ok and pressed == true
    if pressed and not held[vk] and #queue < QUEUE_MAX then queue[#queue + 1] = { vk = vk, time = TWDA.now() } end
    held[vk] = pressed
  end
  if queue[1] ~= nil and TWDA.now() - queue[1].time > QUEUE_SECONDS then queue = {} end
  if queue[1] ~= nil and not locked then
    local action = actions[table.remove(queue, 1).vk]
    local okAction, err = pcall(action, mode, pane)
    if not okAction then TWDA.log("panes key: " .. tostring(err)) end
  end

  local now = TWDA.now()
  if now - lastPoll < 0.1 and not repeatCurrent then return end
  lastPoll = now

  local parts = {}
  if isEpisodePane(pane) then
    local text = episodeText(pane)
    if pane ~= lastPane then
      lastPane, lastControl, lastValue = pane, nil, text
      TWDA.paneTitle = "Episodes"
      parts = { text, keyHelp(pane) }
    elseif text ~= lastValue or repeatCurrent then
      lastValue = text
      parts = { text }
    end
    repeatCurrent = false
    TWDA.lastMenuItem = text
    if #parts > 0 and TWDA.settings.menus ~= false then
      TWDA.say(TWDA.joinSentences(parts), { interrupt = true })
    end
    return
  end
  local control = pane.mCurrentSelected
  if pane ~= lastPane then
    lastPane, lastControl, lastValue = pane, nil, nil
    TWDA.paneTitle = titleOf(pane)
    parts[#parts + 1] = TWDA.paneTitle
    -- After Apply or Cancel the game leaves that button selected; reopening the pane should start
    -- at the top instead.
    if control ~= nil and extraIndex(extrasOf(pane), control) then
      local first = firstSelectable(pane)
      if first ~= nil then
        selectControl(pane, first, true)
        control = first
      end
    end
    if control ~= nil then
      -- Say the item first, then any note; key help stays on F6.
      local item = describe(control)
      lastControl, lastValue = control, valueOf(control)
      parts[#parts + 1] = item
      parts[#parts + 1] = notesOf(pane)
    end
  end
  if control ~= nil then
    local value = valueOf(control)
    if not sameAgent(control, lastControl) or repeatCurrent then
      debug(("read %s (was %s, repeat %s)"):format(TWDA.agentName(control), TWDA.agentName(lastControl),
        tostring(repeatCurrent)))
      lastControl, lastValue = control, value
      parts[#parts + 1] = describe(control)
    elseif value and value ~= lastValue then
      -- Only the value changed: say just that.
      lastValue = value
      parts[#parts + 1] = value
    end
    TWDA.lastMenuItem = describe(control) or TWDA.lastMenuItem
  elseif #parts > 0 then
    parts[#parts + 1] = infoOf(pane)
    parts[#parts + 1] = notesOf(pane)
    parts[#parts + 1] = keyHelp(pane)
  end
  repeatCurrent = false
  if #parts > 0 and TWDA.settings.menus ~= false then
    TWDA.say(TWDA.joinSentences(parts), { interrupt = true })
  end
end)

-- For F6.
function TWDA.describePane()
  local mode = activeMode()
  local pane = mode and currentPane(mode)
  if not pane then return nil end
  if isEpisodePane(pane) then return TWDA.joinSentences({ "Episodes", episodeText(pane), keyHelp(pane) }) end
  local parts = { TWDA.paneTitle or titleOf(pane) }
  local control = pane.mCurrentSelected
  if control ~= nil then parts[#parts + 1] = describe(control) else parts[#parts + 1] = infoOf(pane) end
  parts[#parts + 1] = notesOf(pane)
  parts[#parts + 1] = keyHelp(pane)
  return TWDA.joinSentences(parts)
end
