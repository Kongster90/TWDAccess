-- Prints the current widget menu: its agent, widgets (agent names, buttons) and texts.
local out = {}
local menu = Menu_GetCurrentMenu and Menu_GetCurrentMenu()
if not menu then return "no menu" end
out[#out + 1] = "menu agent " .. tostring(TWDA.agentName(rawget(menu, "agent")))
for k, v in pairs(menu) do
  if type(v) ~= "function" and type(v) ~= "table" then out[#out + 1] = "  ." .. tostring(k) .. " = " .. tostring(v) end
end
for i, widget in ipairs(rawget(menu, "widgets") or {}) do
  local agent = rawget(widget, "agent")
  local names = rawget(widget, "buttonNames")
  out[#out + 1] = ("  w%d %s buttons=%s text=%s"):format(i, TWDA.agentName(agent),
    type(names) == "table" and #names or "-", tostring(TWDA.visibleText(agent)))
end
return table.concat(out, "\n")
