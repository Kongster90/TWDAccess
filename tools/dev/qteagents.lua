-- Michonne / Season 2 style QTEs: the QTE agents (QTE_GetAgents) with their QTE-ish properties
-- (names readable through PropertyGetKeyName when available, else the raw key and value).
local out = {}
local ok, agents = pcall(QTE_GetAgents)
if not ok or type(agents) ~= "table" then return "no agents: " .. tostring(agents) end
for _, agent in pairs(agents) do
  local okH, hidden = pcall(AgentIsHidden, agent)
  out[#out + 1] = TWDA.agentName(agent) .. " hidden=" .. tostring(okH and hidden)
  local props = AgentGetProperties(agent)
  for _, key in ipairs(PropertyGetKeys(props) or {}) do
    local okV, v = pcall(AgentGetProperty, agent, key)
    local name = tostring(key)
    if rawget(_G, "SymbolToString") then
      local okN, n = pcall(SymbolToString, key)
      if okN and n then name = n end
    end
    if name:find("QTE") or name:find("Swipe") or name:find("Prompt") or name:find("Action") then
      out[#out + 1] = "  " .. name .. " = " .. tostring(okV and v)
    end
  end
end
return table.concat(out, "\n")
