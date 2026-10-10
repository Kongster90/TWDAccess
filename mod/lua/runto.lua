-- Running for it in Season 1: some action scenes hand Lee back to free walking with only "Run!"
-- on screen and a few seconds to reach a spot (the drugstore at the end of Episode 1: from
-- Clementine to Larry at the office door, about 7 meters in 3 seconds). A sighted player sees
-- where to go; the mod knows these spots from a table (below) and says which keys head there.
--
-- Keys: the game's walking is relative to the camera (W away from it, S towards it, A and D to
-- the sides; Shift runs). So the key comes from which way the target lies on screen from Lee,
-- through the camera the scene shows (AgentGetScreenPos can still go by the shot before), worked
-- out again as Lee moves and the camera cuts.
local TWDA = ...
local G = _G

-- Scene script -> hint text -> { agents = spots in the order they are reached, name = what to call
-- them (or nil: just "Run!") }. The guide heads for the first spot that is switched on (a trigger
-- whose "Trigger Enabled" is set, or an agent that is not hidden), and when walking comes back
-- after a short scene, for the next one, saying "Run!" again.
local TARGETS = {
  ["env_drugstoreinteriorprologue.lua"] = { ["Run!"] = { agents = { "trigger_LarryPunch" }, name = "Larry" } },
  -- 400 Days, Bonnie in the woods by the water tower: a light finds them and a few seconds of free
  -- walking follow. Toward the camera and past it to trigger_dialog_bonnieShot (27 meters; she is
  -- shot at and falls), then, with no hint on screen, back the other way to
  -- trigger_dialog_bonnieFalls (28 meters) before the pursuers' trigger_dialog_bonnieDies, which
  -- follows her at about 2.6 meters a second, catches up.
  ["chapter4a_forest.lua"] = { ["Run!"] = { agents = { "trigger_dialog_bonnieShot", "trigger_dialog_bonnieFalls" } } },
}

local SECONDS = 12      -- how long to keep guiding after the hint (or after walking comes back)
local SEQUENCE_SECONDS = 60 -- how long a guide lasts at most, across the short scenes between spots
local REPEAT = 0.8      -- seconds between checks of the direction

local function sceneScript()
  local name = rawget(G, "TWDA_firstScript")
  return type(name) == "string" and name:lower() or ""
end

-- "W", "W and D"... towards the target, or nil. Measured on screen between Lee and a point a meter
-- from him towards it (as cover.lua does): a target behind the camera projects mirrored (Bonnie's
-- run in 400 Days started with "W" where the way was S).
local function keysTowards(target)
  local okLee, here = pcall(AgentGetWorldPos, TWDA.player())
  local okTo, there = pcall(AgentGetWorldPos, target)
  if not (okLee and here and okTo and there) then return nil end
  local mx, mz = there.x - here.x, there.z - here.z
  local length = math.sqrt(mx * mx + mz * mz)
  if length < 0.01 then return nil end
  local okCam, camera = pcall(function() return SceneGetCamera(TWDA.playerScene()) end)
  if not (okCam and camera ~= nil) then return nil end
  local okA, lee = pcall(CameraGetScreenPosFromWorldPos, camera, here)
  local okB, to = pcall(CameraGetScreenPosFromWorldPos, camera, Vector(here.x + mx / length, here.y, here.z + mz / length))
  if not (okA and lee and okB and to) then return nil end
  local dx, dy = to.x - lee.x, to.y - lee.y
  local keys = {}
  if math.abs(dy) >= math.abs(dx) * 0.5 then keys[#keys + 1] = dy < 0 and "W" or "S" end
  if math.abs(dx) >= math.abs(dy) * 0.5 then keys[#keys + 1] = dx > 0 and "D" or "A" end
  return table.concat(keys, " and ")
end

local function switchedOn(agent)
  local ok, enabled = pcall(AgentGetProperty, agent, "Trigger Enabled")
  if ok and enabled ~= nil then return enabled == true end
  local okHidden, hidden = pcall(AgentIsHidden, agent)
  return not (okHidden and hidden)
end

-- The first spot of the guide that is switched on now.
local function currentSpot(g)
  for _, name in ipairs(g.entry.agents) do
    local ok, agent = pcall(AgentFind, name)
    if ok and agent ~= nil and switchedOn(agent) then return agent, name end
  end
  return nil
end

local guide = nil -- { entry, since, segmentSince, spot, keys, lastCheck }

local function announce(g, agent, name)
  g.spot, g.segmentSince, g.lastCheck = name, TWDA.now(), TWDA.now()
  g.keys = keysTowards(agent)
  TWDA.log("runto: " .. name .. " " .. tostring(g.keys))
  TWDA.say(("Run%s! Hold Shift and %s"):format(g.entry.name and (" to " .. g.entry.name) or "", g.keys or "W"),
    { interrupt = true })
end

TWDA.onTextProperty = TWDA.onTextProperty or {}
TWDA.onTextProperty.runto = function(_, text)
  local targets = TARGETS[sceneScript()]
  local entry = targets and targets[TWDA.cleanText(text or "")]
  if not entry then return end
  local g = { entry = entry, since = TWDA.now() }
  local agent, name = currentSpot(g)
  if not agent then return end
  guide = g
  announce(g, agent, name)
end

-- While a guide runs, other announcements wait (actions.lua: "Leland: Yell To. Enter to do it."
-- in the middle of Bonnie's run would have Enter yell instead).
function TWDA.runtoActive()
  return guide ~= nil and not guide.paused
end

TWDA.onFrame("runto", function()
  local g = guide
  if not g then return end
  local now = TWDA.now()
  if now - g.since > SEQUENCE_SECONDS then
    guide = nil
    return
  end
  local okWalk, walking = pcall(InputMapperIsActive, "Navigate.imap")
  if not (okWalk and walking) then
    -- A short scene between two spots (Bonnie is shot at): wait for walking to come back.
    g.paused = true
    return
  end
  local agent, name = currentSpot(g)
  if not agent then
    guide = nil
    return
  end
  if g.paused or name ~= g.spot then
    g.paused = false
    announce(g, agent, name)
    return
  end
  if now - g.segmentSince > SECONDS then
    guide = nil
    return
  end
  -- (Often at first: the camera can cut to the running shot just after the hint.)
  if now - g.lastCheck < (now - g.segmentSince < 2 and 0.2 or REPEAT) then return end
  g.lastCheck = now
  local keys = keysTowards(agent)
  if keys and keys ~= g.keys then
    g.keys = keys
    TWDA.say(keys, { interrupt = true })
  end
end)
