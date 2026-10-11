-- Dev console: print the active UIZ menu's agent tree (name, hidden, text, screen position).
-- Set TREE_ROOT to an agent name first to dump another agent.
local root = rawget(_G, "TREE_ROOT") and AgentFind(TREE_ROOT) or UIZ_GetActiveMenu()
local lines = {}
local function walk(agent, depth)
  if depth > 6 then return end
  local name = TWDA.agentName(agent)
  local hidden = AgentIsHidden(agent) and " H" or ""
  local text = TWDA.agentText(agent)
  local ok, pos = pcall(AgentGetScreenPos, agent)
  local where = ok and pos and ("%.2f,%.2f"):format(pos.x, pos.y) or ""
  lines[#lines + 1] = ("%s%s%s %s %s"):format(("  "):rep(depth), name, hidden, where, text and ("'" .. text .. "'") or "")
  local okC, kids = pcall(AgentGetChildren, agent)
  for _, k in ipairs(okC and type(kids) == "table" and kids or {}) do walk(k, depth + 1) end
end
walk(root, 0)
TWDA.log("TREE\n" .. table.concat(lines, "\n"))
return #lines
