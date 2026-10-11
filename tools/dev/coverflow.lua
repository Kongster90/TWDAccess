-- Dev console: describe the active coverflow (Season 2's carousels: chapters, save files, stats)
-- and its centre panel.
local cf = TWDA.upvalue(CoverFlow_ButtonEnter, "mActiveCoverFlow")
if not cf then return "no active coverflow" end
local out = { "menu " .. TWDA.agentName(rawget(cf, "agent") or cf) }
local center = CoverFlow_GetCenterPanel(cf)
for i, p in ipairs(rawget(cf, "panels") or {}) do
  local fields = {}
  for k, v in pairs(p) do
    if type(v) ~= "function" and type(v) ~= "table" then fields[#fields + 1] = tostring(k) .. "=" .. tostring(v) end
  end
  table.sort(fields)
  local agent = rawget(p, "agent") or p
  out[#out + 1] = ("%s%d %s %s | %s"):format(p == center and "*" or " ", i, agent and TWDA.agentName(agent) or "?",
    agent and tostring(TWDA.visibleText and TWDA.visibleText(agent)) or "", table.concat(fields, " "))
end
TWDA.log("CF\n" .. table.concat(out, "\n"))
return #out
