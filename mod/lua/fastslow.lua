-- Sneaking up or jumping out (the game's mode_fastSlow.lua): "Press and hold the left mouse
-- button, then push the mouse forward. Push slowly to sneak up quietly, or quickly to jump out"
-- (Russell and Nate at the farmhouse, 400 Days; about 12 seconds, then the scene goes on by
-- itself). Its input map takes only the mouse and the controller's left stick (OnLeftStick); its
-- arrow-key handlers work only on one TV platform. The stick way (UpdateJoystickDir): a push the
-- mode's way under about 0.7 of full tilt plays the slow dialog, and once that has played with
-- the stick still pushed, ends the mode; a full push plays the fast one at once. So while the mode
-- is up, the mod feeds the stick handler: the arrow key held is a gentle push, with Shift a full one.
local TWDA = ...
local G = _G

local MAP = "mode_fastSlow.imap"
local VK_SHIFT = 0x10
-- Stick vectors and their keys, tried against the mode's direction.
local WAYS = {
  { x = 0, y = 1, vk = 0x26, key = "Up arrow" }, { x = 0, y = -1, vk = 0x28, key = "Down arrow" },
  { x = -1, y = 0, vk = 0x25, key = "Left arrow" }, { x = 1, y = 0, vk = 0x27, key = "Right arrow" },
}

local function mode()
  local m = rawget(G, "mode_fastSlow")
  return type(m) == "table" and m or nil
end

local function active()
  if not mode() then return false end
  local ok, on = pcall(InputMapperIsActive, MAP)
  return ok and on == true
end
TWDA.fastSlowActive = active

-- The way the mode wants (its logic agent's direction, Input_GetJoystickDir's numbering).
local function wantedWay(m)
  local update = TWDA.upvalue(rawget(m, "OnLeftStick"), "UpdateJoystickDir")
  local agent, key = TWDA.upvalue(update, "kLogicAgent"), TWDA.upvalue(update, "kDirection")
  local ok, dir = pcall(AgentGetProperty, agent, key)
  if ok and type(dir) == "number" and dir > 0 then
    for _, way in ipairs(WAYS) do
      local okD, d = pcall(Input_GetJoystickDir, Vector(way.x * 0.5, way.y * 0.5, 0))
      if okD and d == dir then return way end
    end
  end
  return WAYS[1]
end

local function describe(way)
  return ("Sneak up quietly: hold %s until it is done. Or Shift and %s to jump out"):format(way.key, way.key)
end

local way, toldAt, told, pushing = nil, nil, false, false

local function push(m, scale)
  local ok, err = pcall(m.OnLeftStick, m, { x = way.x * scale, y = way.y * scale })
  if not ok then TWDA.log("fastslow: " .. tostring(err)) end
end

TWDA.onFrame("fastslow", function()
  if not active() then
    way, toldAt, told, pushing = nil, nil, false, false
    return
  end
  local m = mode()
  local now = TWDA.now()
  if not way then
    way, toldAt = wantedWay(m), now + 0.3
    TWDA.log("fastslow: started, " .. way.key)
  end
  -- (A moment after the game's own mouse hint, which the mod reads out.)
  if not told and now >= toldAt then
    told = true
    TWDA.say(describe(way) .. ".", { interrupt = true })
  end
  local okK, held = pcall(InputPCIsVKeyPressed, way.vk)
  if okK and held == true then
    local okS, shift = pcall(InputPCIsVKeyPressed, VK_SHIFT)
    if not pushing then TWDA.log("fastslow: pushing " .. ((okS and shift == true) and "fast" or "slow")) end
    pushing = true
    push(m, (okS and shift == true) and 1 or 0.5)
  elseif pushing then
    pushing = false
    push(m, 0)
  end
end)

-- For F6.
function TWDA.describeFastSlow()
  if not active() then return nil end
  return describe(way or wantedWay(mode()))
end
