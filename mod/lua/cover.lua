-- Walking in moving cover in Season 1. At the dairy fence in Episode 2 ("Get to the gate using
-- the tractor as cover!") the tractor rolls towards the gate at about 0.6 meters a second and Lee,
-- walking freely, has to stay beside it while the bandits shoot. The game marks the covered
-- stretch (about 3.4 meters) with two trigger volumes that move with the tractor; reaching either
-- edge starts a one-second timer and Lee is shot (cs_rollingDeathRear1). A sighted player watches
-- the wheel; the mod says "Walk: A" when Lee falls back, "Run: Shift and A" when well back, and
-- "Stop" once he is well forward, from where he is between the two edges. The key comes from the
-- direction the cover moves on screen (walking is relative to the camera), and is said again when
-- a camera cut changes it.
local TWDA = ...
local G = _G

-- Scene script -> the cover's edges.
local ZONES = {
  ["env_dairyexteriorfence.lua"] = { rear = "trigger_tractorRearEdge", front = "trigger_tractorFrontEdge",
    name = "the tractor" },
}
-- Where Lee is between the rear (0) and front (1) edges decides what is said. Walking (about 0.6
-- meters a second) keeps up with the tractor at first; on the last stretch it speeds up to 0.9,
-- so well back he has to run (Shift) until he is past the middle again.
local RUN_BELOW, RUN_UNTIL, WALK_BELOW, STOP_ABOVE, TOO_FAR = 0.25, 0.5, 0.45, 0.7, 0.88
local CHECK_SECONDS = 0.15

local function sceneScript()
  local name = rawget(G, "TWDA_firstScript")
  return type(name) == "string" and name:lower() or ""
end

local function call(fn, ...)
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

-- The keys for a direction on screen (y downwards), as runto.lua: "A", "W and A"...
local function keysFor(dx, dy)
  local keys = {}
  if math.abs(dy) >= math.abs(dx) * 0.5 then keys[#keys + 1] = dy < 0 and "W" or "S" end
  if math.abs(dx) >= math.abs(dy) * 0.5 then keys[#keys + 1] = dx > 0 and "D" or "A" end
  return table.concat(keys, " and ")
end

local OPPOSITE = { W = "S", S = "W", A = "D", D = "A" }
local function opposite(keys)
  return (keys:gsub("[WASD]", OPPOSITE))
end

local state = nil -- { zone, phase = "walk" | "run" | "stop" | "back", keys, lastCheck, since }

-- Where Lee is in the cover (0 rear, 1 front) and the keys that move him forward, or nil.
local function measure(zone)
  local rear, front = call(AgentFind, zone.rear), call(AgentFind, zone.front)
  local lee = TWDA.player()
  if not rear or not front or not lee then return nil end
  local r, f, p = call(AgentGetWorldPos, rear), call(AgentGetWorldPos, front), call(AgentGetWorldPos, lee)
  if not r or not f or not p then return nil end
  local vx, vz = f.x - r.x, f.z - r.z
  local length = vx * vx + vz * vz
  if length < 0.01 then return nil end
  local t = ((p.x - r.x) * vx + (p.z - r.z) * vz) / length
  -- The way forward on screen, from Lee to a point a meter further along the cover's path through
  -- the camera in use (the two edges are at other depths, and perspective bends a line between
  -- them: it gave "W and A" where A alone kept up).
  local keys = "W"
  local camera = call(SceneGetCamera, call(AgentGetScene, lee))
  local scale = 1 / math.sqrt(length)
  local ahead = call(Vector, p.x + vx * scale, p.y, p.z + vz * scale)
  local s0 = camera and call(CameraGetScreenPosFromWorldPos, camera, p)
  local s1 = camera and ahead and call(CameraGetScreenPosFromWorldPos, camera, ahead)
  if s0 and s1 then keys = keysFor(s1.x - s0.x, s1.y - s0.y) end
  return t, keys
end

local function walking()
  local ok, on = pcall(InputMapperIsActive, "Navigate.imap")
  return ok and on == true
end

function TWDA.coverWalkActive()
  return state ~= nil
end

TWDA.onFrame("cover", function()
  local zone = ZONES[sceneScript()]
  if not zone or not walking() then
    state = nil
    return
  end
  local now = TWDA.now()
  if state and now - state.lastCheck < CHECK_SECONDS then return end
  local t, keys = measure(zone)
  if not t then
    state = nil
    return
  end
  local first = state == nil or state.phase == nil
  state = state or { phase = nil, keys = nil, zone = zone, since = now }
  state.lastCheck = now
  -- (A moment for Lee to be in place when walking starts after a cutscene.)
  if now - state.since < 0.4 then return end
  local phase = state.phase
  if t > TOO_FAR then
    phase = "back"
  elseif t < RUN_BELOW then
    phase = "run"
  elseif phase == "run" then
    phase = t > RUN_UNTIL and "walk" or "run"
  elseif t < WALK_BELOW then
    phase = "walk"
  elseif t > STOP_ABOVE or phase == "back" or phase == nil then
    phase = "stop"
  end
  local moving = phase == "walk" or phase == "run"
  if phase == state.phase and (not moving or keys == state.keys) then return end
  state.phase, state.keys = phase, keys
  local text = phase == "walk" and ("Walk: " .. keys) or phase == "run" and ("Run: Shift and " .. keys)
    or phase == "back" and ("Too far! Back: " .. opposite(keys)) or "Stop"
  if first then text = "Stay beside " .. zone.name .. ". " .. text end
  TWDA.log(("cover: %.2f %s"):format(t, text))
  TWDA.say(text, { interrupt = true })
end)

-- F6.
function TWDA.describeCover()
  if not state then return nil end
  local doing = state.phase == "walk" and ("Walk: " .. state.keys)
    or state.phase == "run" and ("Run: Shift and " .. state.keys) or "Stop"
  return "Stay beside " .. state.zone.name .. ". " .. doing
end
