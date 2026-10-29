-- Prints the selected widget's agent tree in a widget menu: names, hidden or not, and texts.
local menu = Menu_GetCurrentMenu and Menu_GetCurrentMenu()
if not menu then return "no menu" end
local out = {}
local function walk(agent, depth)
  if agent == nil or depth > 5 then return end
  local okH, hidden = pcall(AgentIsHidden, agent)
  local okT, s = pcall(AgentGetProperty, agent, "Text String")
  out[#out + 1] = ("%s%s hidden=%s text=%s agentText=%s"):format(string.rep("  ", depth), TWDA.agentName(agent),
    tostring(okH and hidden), tostring(okT and s), tostring(TWDA.agentText(agent)))
  local ok, kids = pcall(AgentGetChildren, agent)
  if ok and type(kids) == "table" then for _, k in pairs(kids) do walk(k, depth + 1) end end
end
local sel = rawget(menu, "selectedWidget") or (menu.GetSelectedWidget and menu:GetSelectedWidget())
if type(sel) == "table" then
  walk(rawget(sel, "agent"), 0)
else
  for i, w in ipairs(rawget(menu, "widgets") or {}) do
    out[#out + 1] = "w" .. i
    walk(rawget(w, "agent"), 1)
  end
end
return table.concat(out, "\n")
