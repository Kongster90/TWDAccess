-- Dev console: every visible agent with text in the active menu's scene (or SCENETEXT_SCENE),
-- with its screen position.
local root = UIZ_GetActiveMenu()
local scene = rawget(_G, "SCENETEXT_SCENE") or AgentGetScene(root)
local lines = { "scene " .. tostring(scene) }
for _, a in ipairs(SceneGetAgents(scene) or {}) do
  local text = TWDA.agentText(a)
  if text and text ~= "" then
    local ok, pos = pcall(AgentGetScreenPos, a)
    local where = ok and pos and ("%.2f,%.2f"):format(pos.x, pos.y) or ""
    local parent = AgentGetParent(a)
    lines[#lines + 1] = ("%s%s %s [%s] '%s'"):format(TWDA.agentName(a), AgentIsHidden(a) and " H" or "", where,
      parent and TWDA.agentName(parent) or "", text:sub(1, 120))
  end
end
TWDA.log("SCENETEXT\n" .. table.concat(lines, "\n"))
return #lines
