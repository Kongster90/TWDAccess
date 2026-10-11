-- Drags in Season 2 (projectseason2's drag.lua): flicking a lighter, pulling things free. The game
-- starts one (Drag_Enter) straight after a use, expecting the mouse button (or the controller's A)
-- still to be held from the click; if it is not (upvalue mbDragButtonActive false), the drag ends at
-- once. Once going, drag.imap moves it with the arrows and W A S D (Drag_OnButtonUp/Down/Left/
-- Right). In cursor mode Drag_Activate follows the mouse instead (a virtual stick), so the mod marks
-- the button as held when a drag starts and has Input_UseCursor answer false while Drag_Activate
-- runs; the keys then work as on a controller. The ways to pull are the logic agent's direction
-- chores ("logic_drag": "Drag - Direction Down Chore" and so on; empty means not that way).
local TWDA = ...
local G = _G

local LOGIC = "logic_drag"
local DIRECTIONS = {
  { prop = "Drag - Direction Up Chore", key = "Up arrow" },
  { prop = "Drag - Direction Down Chore", key = "Down arrow" },
  { prop = "Drag - Direction Left Chore", key = "Left arrow" },
  { prop = "Drag - Direction Right Chore", key = "Right arrow" },
}

local function isSeason2Drag()
  return type(rawget(G, "Drag_Enter")) == "function" and TWDA.upvalue(rawget(G, "Drag_Enter"), "mbDragButtonActive") ~= nil
end

-- Sets a local of drag.lua (shared by all its functions) through one of its functions.
local function setUpvalue(fnName, name, value)
  local fn = TWDA.unwrap(rawget(G, fnName))
  if type(fn) ~= "function" then return false end
  for i = 1, 80 do
    local n = debug.getupvalue(fn, i)
    if not n then return false end
    if n == name then
      debug.setupvalue(fn, i, value)
      return true
    end
  end
  return false
end

local function waysText()
  local keys = {}
  for _, d in ipairs(DIRECTIONS) do
    -- (A chore handle, or an empty string or nothing for a way that does nothing.)
    local ok, chore = pcall(AgentGetProperty, LOGIC, d.prop)
    if ok and chore ~= nil and chore ~= "" then keys[#keys + 1] = d.key end
  end
  if #keys == 0 then return "Drag: hold an arrow key the way to pull." end
  if #keys == 1 then return "Drag: hold " .. keys[1] .. "." end
  return "Drag: hold " .. table.concat(keys, " or ") .. "."
end

local active = false
local announceAt = nil

TWDA.hookBefore("Drag_Enter", function()
  if not isSeason2Drag() then return end
  if setUpvalue("Drag_Enter", "mbDragButtonActive", true) then
    active = true
    announceAt = TWDA.now() + 0.3 -- (the direction chores are read from the logic agent first)
    TWDA.log("drag2: drag started, holding the button for the keyboard")
  end
end)

TWDA.hookGlobal("Drag_Activate", function(original)
  return function(...)
    if not active then return original(...) end
    local useCursor = rawget(G, "Input_UseCursor")
    rawset(G, "Input_UseCursor", function() return false end)
    local results = table.pack(pcall(original, ...))
    rawset(G, "Input_UseCursor", useCursor)
    if not results[1] then error(results[2], 0) end
    return table.unpack(results, 2, results.n)
  end
end)

TWDA.hookAfter("Drag_Exit", function()
  if not active then return end
  active, announceAt = false, nil
  setUpvalue("Drag_Enter", "mbDragButtonActive", false)
  TWDA.log("drag2: drag ended")
end)

-- drag.imap is switched on while the reticle is on a drag agent (for the click that starts the
-- drag), and off again when the drag hides the reticle; the keys need it for the whole drag.
local function keepKeys()
  local map = TWDA.upvalue(rawget(G, "Drag_OnHoldRelease"), "kInputMap")
  local okMode, mode = pcall(Game_GetMode)
  if not map or not okMode or mode ~= rawget(G, "eModeDrag") then return end
  local okA, isActive = pcall(InputMapperIsActive, map)
  if okA and not isActive then
    pcall(InputMapperActivate, map)
    TWDA.log("drag2: keys on (" .. tostring(map) .. ")")
  end
end

TWDA.onFrame("drag2", function()
  if active then keepKeys() end
  if announceAt and TWDA.now() >= announceAt then
    announceAt = nil
    TWDA.say(waysText(), { interrupt = true })
  end
end)

local previousDescribe = TWDA.describeDrag
TWDA.describeDrag = function()
  if active then return waysText() end
  return previousDescribe and previousDescribe() or nil
end
