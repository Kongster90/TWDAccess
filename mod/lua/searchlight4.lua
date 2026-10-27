-- Sneaking past a searchlight in The Final Season (the dock at night, Episode 3,
-- RiverShorelineNight.lua: "Move between cover while avoiding the searchlight"). The dock is crossed
-- by thin trigger lines, "trigger_dialog_dockStealth01" and "02" (2 m by 0.3 m, about 4 m apart),
-- each enabled while the boat's searchlight sweeps over it, three to six seconds at a time; crossing
-- a line while it is on gets her seen. Crossed while it is off, it is safe, and between the lines
-- she is in cover. Only the light on screen tells which.
--
-- The mod: the next line ahead of her (along the line from the first to the last) is said when she
-- comes near it, and again each time its light goes on or off: "Light on the crossing ahead. Wait."
-- and "Crossing ahead is dark. Go!"; "Past the last crossing." at the end. F6 says it too.
-- (Untested by ear: written from the logged lines after the dock was crossed by a test script.)
local TWDA = ...

local NEAR = 6 -- meters: the next line's light is said within this

local function prop(agent, key)
  local ok, value = pcall(AgentGetProperty, agent, key)
  if ok then return value end
  return nil
end

-- The lines, by their number: { agent, number, point }. (Looked for once a second: a scene has
-- hundreds of agents.)
local cached, cachedAt = {}, -10
local function lines()
  local now = TWDA.now()
  if now - cachedAt < 1 then return cached end
  cachedAt = now
  local list = {}
  cached = list
  local okS, agents = pcall(SceneGetAgents, TWDA.playerScene())
  for _, agent in ipairs(okS and type(agents) == "table" and agents or {}) do
    local number = TWDA.agentName(agent):match("^trigger_dialog_%a*[Ss]tealth(%d+)$")
    local okP, point = pcall(AgentGetWorldPos, agent)
    if number and okP and point then list[#list + 1] = { agent = agent, number = tonumber(number), point = point } end
  end
  table.sort(list, function(a, b) return a.number < b.number end)
  return list
end

-- The first line not yet crossed, and how far it is; nil when all are behind her.
local function nextLine(list, here)
  local first, last = list[1].point, list[#list].point
  local ax, az = last.x - first.x, last.z - first.z
  local length = math.sqrt(ax * ax + az * az)
  if length < 0.5 then return nil end
  ax, az = ax / length, az / length
  local function along(p) return (p.x - first.x) * ax + (p.z - first.z) * az end
  local mine = along(here)
  for _, line in ipairs(list) do
    if along(line.point) > mine + 0.15 then
      local dx, dz = line.point.x - here.x, line.point.z - here.z
      return line, math.sqrt(dx * dx + dz * dz)
    end
  end
  return nil
end

local state = { line = nil, lit = nil, near = false, done = false }

local function lightText(lit)
  return lit and "Light on the crossing ahead. Wait." or "Crossing ahead is dark. Go!"
end

TWDA.onFrame("searchlight4", function()
  if type(rawget(_G, "Useable_GetCount")) ~= "function" then return end
  local list = lines()
  if #list < 2 then
    state.line, state.done = nil, false
    return
  end
  local okH, here = pcall(AgentGetWorldPos, TWDA.player())
  if not okH or not here then return end
  local line, d = nextLine(list, here)
  if not line then
    if state.line and not state.done then
      state.done = true
      TWDA.say("Past the last crossing.", { interrupt = true })
    end
    state.line = nil
    return
  end
  state.done = false
  local lit = prop(line.agent, "Trigger Enabled") == true
  local near = d <= NEAR
  if line.agent ~= state.line then
    state.line, state.lit, state.near = line.agent, lit, near
    if near then TWDA.say(("Crossing ahead, %d meters. %s"):format(math.floor(d + 0.5), lightText(lit)), { interrupt = true }) end
    return
  end
  if near and (lit ~= state.lit or not state.near) then
    TWDA.say(lightText(lit), { interrupt = true })
  end
  state.lit, state.near = lit, near
end)

local previous = TWDA.describeLookaround
TWDA.describeLookaround = function()
  local rest = previous and previous() or nil
  local list = type(rawget(_G, "Useable_GetCount")) == "function" and lines() or {}
  if #list < 2 then return rest end
  local okH, here = pcall(AgentGetWorldPos, TWDA.player())
  local line, d = nil, nil
  if okH and here then line, d = nextLine(list, here) end
  local text = line and ("Crossing ahead, %d meters, %s"):format(math.floor(d + 0.5),
    prop(line.agent, "Trigger Enabled") == true and "in the light" or "dark") or "Past the last crossing"
  return rest and (text .. ". " .. rest) or text
end
