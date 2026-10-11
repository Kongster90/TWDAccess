-- Dev console (Season 2): every agent in the player's scene that the game counts as useable
-- (Game_IsUseable) with its noun, selectable flag, hidden flag, distance and verbs, and whether the
-- reticle's usables list has it.
local player = Game_GetPlayer()
local from = AgentGetWorldPos(player)
local inList = {}
for _, a in pairs(ReticleSelection_GetUsables() or {}) do inList[a] = true end
local out = {}
for _, a in ipairs(SceneGetAgents(AgentGetScene(player)) or {}) do
  local okU, useable = pcall(Game_IsUseable, a)
  if okU and useable then
    local okP, pos = pcall(AgentGetWorldPos, a)
    local d = okP and pos and VectorDistance(from, pos) or -1
    local okN, noun = pcall(Game_GetNounText, a)
    local verbs = {}
    if pcall(ReticleVerbs_BuildVerbData, a) then
      for _, v in ipairs(ReticleVerbs_GetAvailableVerbs() or {}) do verbs[#verbs + 1] = tostring(v.Text) end
    end
    out[#out + 1] = ("%5.1f %s noun=%s sel=%s hidden=%s list=%s verbs=%s"):format(d, TWDA.agentName(a), tostring(okN and noun),
      tostring(AgentGetProperty(a, "Game Selectable")), tostring(AgentIsHidden(a)), tostring(inList[a] == true), table.concat(verbs, "/"))
  end
end
table.sort(out)
TWDA.log("SEL " .. #out .. "\n" .. table.concat(out, "\n"))
return #out
