-- Drags (the game's mode_drag.lua): pulling something by holding the mouse button and pushing the
-- mouse one way, such as the rebar Bonnie must loosen in 400 Days' cornfield. With the mouse the
-- drag only lasts while the left button is held (mode_drag.OnActivate pops it at once otherwise),
-- so a key press could never hold it. The game's controller way takes the arrow keys and A, D, W,
-- S as the direction instead (mode_drag.imap: OnButtonLeft and friends) while button A is held.
-- So, just while a drag starts, the mod has the game take that way (Input_UseCursor false, and
-- button A down), and the drag then stays until it is done; the player holds the arrow key the
-- drag wants ("Drag - Direction" on logic_mode_drag), which the mod says.
local TWDA = ...
local G = _G

local forcing = false

TWDA.hookGlobal("Input_UseCursor", function(original)
  return function(...)
    if forcing then return false end
    return original(...)
  end
end)
TWDA.hookGlobal("Input_IsButtonPressed", function(original)
  return function(code, ...)
    if forcing and code ~= nil and code == rawget(G, "kEventCodeButtonA") then return true end
    return original(code, ...)
  end
end)

-- Input_GetJoystickDir's directions (eUp 1, eDown 2, eLeft 3, eRight 4, as the cornfield uses).
local KEYS = { [1] = "Up arrow", [2] = "Down arrow", [3] = "Left arrow", [4] = "Right arrow" }

local function direction()
  local ok, dir = pcall(AgentGetProperty, "logic_mode_drag", "Drag - Direction")
  return ok and dir or nil
end

local function describe()
  local key = KEYS[direction()]
  return key and ("Hold " .. key .. " to pull") or "Hold an arrow key to pull"
end

local function onActivate()
  forcing = true
end
local function afterActivate()
  forcing = false
  local text = describe()
  TWDA.log("drag: " .. text .. " (direction " .. tostring(direction()) .. ")")
  TWDA.say(text .. ".", { interrupt = true })
end

local attached = setmetatable({}, { __mode = "k" })
TWDA.onFrame("drag", function()
  local mode = rawget(G, "mode_drag")
  if type(mode) ~= "table" then return end
  local current = rawget(mode, "OnActivate")
  if attached[mode] == current then return end
  if TWDA.hookMethod(mode, "OnActivate", "mode_drag.OnActivate", onActivate, afterActivate) then
    attached[mode] = rawget(mode, "OnActivate")
  end
end)

function TWDA.dragActive()
  local mode = rawget(G, "mode_drag")
  local ok, on = pcall(function() return type(mode) == "table" and Mode_IsActive(mode) end)
  return ok and on == true
end

-- For F6.
function TWDA.describeDrag()
  if not TWDA.dragActive() then return nil end
  return describe()
end
