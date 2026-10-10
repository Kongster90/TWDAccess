-- Running for it in Season 1: some action scenes hand Lee back to free walking with only "Run!"
-- on screen and a few seconds to reach a spot (the drugstore at the end of Episode 1: from
-- Clementine to Larry at the office door, about 7 meters in 3 seconds). A sighted player sees
-- where to go; the mod knows these spots from a table (below) and says which keys head there.
--
-- Keys: the game's walking is relative to the camera (W away from it, S towards it, A and D to
-- the sides; Shift runs). So the key comes from where the target is on screen relative to Lee
-- (AgentGetScreenPos, y downwards), worked out again as Lee moves and the camera cuts.
local TWDA = ...
local G = _G

-- Scene script -> hint text -> { target agent, name to say }.
local TARGETS = {
  ["env_drugstoreinteriorprologue.lua"] = { ["Run!"] = { "trigger_LarryPunch", "Larry" } },
}

local SECONDS = 12      -- how long after the hint to keep guiding
local REPEAT = 0.8      -- seconds between checks of the direction

local function sceneScript()
  local name = rawget(G, "TWDA_firstScript")
  return type(name) == "string" and name:lower() or ""
end

local function screenPos(agent)
  local ok, pos = pcall(AgentGetScreenPos, agent)
  if ok and pos then return pos end
  return nil
end

-- "W", "W and D"... towards the target, or nil.
local function keysTowards(target)
  local lee = screenPos(Game_GetPlayer())
  local to = screenPos(target)
  if not lee or not to then return nil end
  if (to.z or 1) <= 0 then return "S" end -- behind the camera
  local dx, dy = to.x - lee.x, to.y - lee.y
  local keys = {}
  if math.abs(dy) >= math.abs(dx) * 0.5 then keys[#keys + 1] = dy < 0 and "W" or "S" end
  if math.abs(dx) >= math.abs(dy) * 0.5 then keys[#keys + 1] = dx > 0 and "D" or "A" end
  return table.concat(keys, " and ")
end

local guide = nil -- { agent, name, since, keys, lastCheck }

TWDA.onTextProperty = TWDA.onTextProperty or {}
TWDA.onTextProperty.runto = function(_, text)
  local targets = TARGETS[sceneScript()]
  local entry = targets and targets[TWDA.cleanText(text or "")]
  if not entry then return end
  local okAgent, agent = pcall(AgentFind, entry[1])
  if not okAgent or agent == nil then return end
  guide = { agent = agent, name = entry[2], since = TWDA.now(), lastCheck = 0 }
  local keys = keysTowards(agent)
  guide.keys = keys
  TWDA.log("runto: " .. entry[2] .. " " .. tostring(keys))
  TWDA.say(("Run to %s! Hold Shift and %s"):format(entry[2], keys or "W"), { interrupt = true })
end

TWDA.onFrame("runto", function()
  local g = guide
  if not g then return end
  local now = TWDA.now()
  local okWalk, walking = pcall(InputMapperIsActive, "Navigate.imap")
  if now - g.since > SECONDS or not (okWalk and walking) then
    guide = nil
    return
  end
  if now - g.lastCheck < REPEAT then return end
  g.lastCheck = now
  local keys = keysTowards(g.agent)
  if keys and keys ~= g.keys then
    g.keys = keys
    TWDA.say(keys, { interrupt = true })
  end
end)
