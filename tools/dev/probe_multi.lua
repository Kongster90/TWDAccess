-- Dev: around each MultiQTE_Enable, log (PM lines) the agent's "QTE Prompt - N" values, its type, and
-- the script's own list (upvalue mMultiQTE_Table of MultiQTE_OnE), before and after the call.
local original = MultiQTE_Enable
local function list()
  local t = TWDA.upvalue(MultiQTE_OnE, "mMultiQTE_Table")
  local out = {}
  for i, v in ipairs(type(t) == "table" and t or {}) do out[i] = tostring(v) end
  return table.concat(out, ",")
end
local function props(agent)
  if type(agent) == "string" then agent = AgentFind(agent) end
  local out = {}
  for i = 1, 6 do
    local ok, v = pcall(AgentGetProperty, agent, "QTE Prompt - " .. i)
    out[#out + 1] = tostring(ok and v)
  end
  local okT, kind = pcall(AgentGetProperty, agent, "QTE - Type")
  return table.concat(out, "|") .. " type=" .. tostring(okT and kind)
end
rawset(_G, "MultiQTE_Enable", function(agent, on, ...)
  TWDA.log(("PM before on=%s props=%s list=%s"):format(tostring(on), props(agent), list()))
  local t0 = GetTotalTime()
  local r = table.pack(original(agent, on, ...))
  TWDA.log(("PM after %.2f s props=%s list=%s"):format(GetTotalTime() - t0, props(agent), list()))
  return table.unpack(r, 1, r.n)
end)
return "probing"
