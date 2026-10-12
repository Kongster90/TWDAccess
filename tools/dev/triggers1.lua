-- Development probe: Season 1 trigger agents in the player's scene, with distance from Lee and
-- whether they are enabled. Logged as TRIG lines.
local lee = Game_GetPlayer()
local here = AgentGetWorldPos(lee)
local out = {}
for _, agent in ipairs(SceneGetAgents(AgentGetScene(lee)) or {}) do
  local name = AgentGetName(agent)
  if name:lower():find("trigger") then
    local p = AgentGetWorldPos(agent)
    local okE, enabled = pcall(AgentGetProperty, agent, "Trigger Enabled")
    local okD, dlg = pcall(AgentGetProperty, agent, "Trigger Enter Dialog")
    local okN, node = pcall(AgentGetProperty, agent, "Trigger Enter Dialog Node")
    out[#out + 1] = ("%s: %.1f m (%.1f, %.1f), enabled %s, hidden %s, enter %s %s"):format(name, VectorDistance(here, p),
      p.x, p.z, tostring(okE and enabled), tostring(AgentIsHidden(agent)), tostring(okD and dlg), tostring(okN and node))
  end
end
table.sort(out)
TWDA.log("TRIG " .. table.concat(out, "\nTRIG "))
return #out
