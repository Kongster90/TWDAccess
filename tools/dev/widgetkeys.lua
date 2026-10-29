-- Prints each widget of the current widget menu: its agent and its fields (tables by size).
local menu = Menu_GetCurrentMenu and Menu_GetCurrentMenu()
if not menu then return "no menu" end
local out = {}
for i, w in ipairs(rawget(menu, "widgets") or {}) do
  local fields = {}
  for k, v in pairs(w) do
    local s = type(v) == "table" and ("table#" .. #v) or tostring(v)
    fields[#fields + 1] = tostring(k) .. "=" .. s:sub(1, 40)
  end
  table.sort(fields)
  out[#out + 1] = ("w%d %s: %s"):format(i, TWDA.agentName(rawget(w, "agent")), table.concat(fields, " "))
  local mt = getmetatable(w)
  if mt and type(mt.__index) == "table" then
    local m = {}
    for k in pairs(mt.__index) do m[#m + 1] = tostring(k) end
    table.sort(m)
    out[#out + 1] = "   methods: " .. table.concat(m, " ")
  end
end
return table.concat(out, "\n")
