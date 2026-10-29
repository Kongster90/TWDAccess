-- Season 2 / Michonne QTEs: the state behind the key handlers (ExecuteAction's upvalues), each
-- QTE agent's promptsCurrent, promptIndex, timedButtons and the fields of its table.
local function brief(v)
  if type(v) == "table" then
    local n = TWDA.agentName(v)
    if n ~= "" then return n end
    local parts = {}
    for k, x in pairs(v) do
      if #parts < 12 then parts[#parts + 1] = tostring(k) .. "=" .. (type(x) == "table" and (TWDA.agentName(x) ~= "" and TWDA.agentName(x) or "{..}") or tostring(x)) end
    end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  return tostring(v)
end
local exec = TWDA.upvalue(DEV.unwrap(QTE_KeyLeft), "ExecuteAction")
if not exec then return "no ExecuteAction" end
local out = {}
local i = 1
while true do
  local name, value = debug.getupvalue(exec, i)
  if not name then break end
  out[#out + 1] = "up " .. name .. " = " .. brief(value)
  i = i + 1
end
local agents = TWDA.upvalue(exec, "mQuickTimeEventAgents")
for _, q in pairs(type(agents) == "table" and agents or {}) do
  out[#out + 1] = "agent " .. brief(q)
  if type(q) == "table" then
    for k, v in pairs(q) do out[#out + 1] = "   ." .. tostring(k) .. " = " .. brief(v) end
  end
end
return table.concat(out, "\n")
