-- Prints the current widget menu's fields (all types), its class methods, and the shown texts in
-- its agent's scene (agent name: text).
local menu = Menu_GetCurrentMenu and Menu_GetCurrentMenu()
if not menu then return "no menu" end
local out = {}
local fields = {}
for k, v in pairs(menu) do
  local s = type(v) == "table" and ("table#" .. #v) or tostring(v)
  fields[#fields + 1] = tostring(k) .. "=" .. s:sub(1, 50)
end
table.sort(fields)
out[#out + 1] = "fields: " .. table.concat(fields, " | ")
local seen, chain = {}, getmetatable(menu)
while chain and type(chain.__index) == "table" and not seen[chain] do
  seen[chain] = true
  local m = {}
  for k, v in pairs(chain.__index) do if type(v) == "function" then m[#m + 1] = tostring(k) end end
  table.sort(m)
  out[#out + 1] = "methods: " .. table.concat(m, " ")
  chain = getmetatable(chain.__index)
end
local okS, agents = pcall(SceneGetAgents, AgentGetScene(rawget(menu, "agent")))
local texts = {}
for _, a in ipairs(okS and type(agents) == "table" and agents or {}) do
  local t = TWDA.agentText(a)
  if t then
    local okH, hidden = pcall(AgentIsHidden, a)
    texts[#texts + 1] = TWDA.agentName(a) .. (okH and hidden and " (hidden)" or "") .. ": " .. t:sub(1, 80)
  end
end
table.sort(texts)
out[#out + 1] = "texts:\n  " .. table.concat(texts, "\n  ")
return table.concat(out, "\n")
