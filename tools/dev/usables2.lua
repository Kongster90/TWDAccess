-- Dev console (Season 2): list the reticle's usables with their names, verbs and screen places.
local out = {}
local usables = ReticleSelection_GetUsables() or {}
local function fields(t)
  local s = {}
  for k, v in pairs(t) do
    if type(v) ~= "function" and k ~= "__ScriptObject" then
      s[#s + 1] = tostring(k) .. "=" .. (type(v) == "table" and (TWDA.agentName(v) ~= "" and TWDA.agentName(v) or "{}") or tostring(v))
    end
  end
  table.sort(s)
  return table.concat(s, " ")
end
local n = 0
for k, u in pairs(usables) do
  n = n + 1
  local agent = type(u) == "table" and (rawget(u, "agent") or u) or u
  local name = TWDA.agentName(agent)
  local okN, noun = pcall(Game_GetNounText, agent)
  local okP, pos = pcall(AgentGetScreenPos, agent)
  local where = okP and pos and ("%.2f,%.2f,%.1f"):format(pos.x, pos.y, pos.z) or "?"
  out[#out + 1] = ("%s %s noun=%s at %s hidden=%s | %s"):format(tostring(k), name, okN and tostring(noun) or "?", where,
    tostring(AgentIsHidden(agent)), type(u) == "table" and fields(u) or tostring(u))
end
out[#out + 1] = "selected " .. TWDA.agentName(Reticle_GetSelectedAgent()) .. " focus " .. TWDA.agentName(ReticleSelection_GetFocus())
for i, v in pairs(ReticleVerbs_GetAvailableVerbs() or {}) do out[#out + 1] = "verb " .. tostring(i) .. ": " .. fields(v) end
TWDA.log("USABLES " .. n .. "\n" .. table.concat(out, "\n"))
return n
