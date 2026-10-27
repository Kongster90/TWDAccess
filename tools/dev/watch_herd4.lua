-- Dev console (The Final Season, Episode 4 opening, RiverShorelineNight.lua: Clementine on the
-- shore without her knife, "You cannot fight the herd", "Escape"). Logs (WH lines) on change, every
-- quarter second for two minutes: her position and every trigger's enabled state and box.
local last = {}
local function note(key, value)
  value = tostring(value)
  if last[key] ~= value then
    last[key] = value
    TWDA.log(("WH %s = %s"):format(key, value))
  end
end
local function box(agent)
  local okA, a = pcall(AgentGetProperty, agent, "Extents Min")
  local okB, b = pcall(AgentGetProperty, agent, "Extents Max")
  if not (okA and okB and a and b) then return "?" end
  local p, q = AgentLocalToWorld(agent, a), AgentLocalToWorld(agent, b)
  return ("%.1f %.1f .. %.1f %.1f"):format(p.x, p.z, q.x, q.z)
end
ThreadStart(function()
  local start = GetTotalTime()
  while GetTotalTime() - start < 120 do
    local okP, p = pcall(AgentGetWorldPos, TWDA.player())
    if okP and p then note("clem", ("%.1f %.1f"):format(p.x, p.z)) end
    for _, agent in ipairs(SceneGetAgents(TWDA.playerScene())) do
      local n = TWDA.agentName(agent)
      if n:find("^trigger") then
        local okE, e = pcall(AgentGetProperty, agent, "Trigger Enabled")
        note(n, tostring(okE and e) .. " " .. box(agent))
      end
    end
    local t = GetTotalTime()
    while GetTotalTime() - t < 0.25 do WaitForNextFrame() end
  end
end)
return "watching the herd"
