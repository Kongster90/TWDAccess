-- Development probe (gate bug, 2026-10-11): for each Season 1 hotspot, how far its use position is
-- from the nearest point on the player's walk boxes, and what the path functions say.
local lee = Game_GetPlayer()
local here = AgentGetWorldPos(lee)
local okWB, walkBoxes = pcall(PathAgentGetWalkBoxes, lee)
local out = { ("walkboxes %s %s; lee %.1f %.1f %.1f"):format(tostring(okWB), tostring(walkBoxes), here.x, here.y, here.z) }
local okV, v = pcall(WalkBoxesValidatePosition, here, walkBoxes)
out[#out + 1] = "validate lee: " .. tostring(okV) .. " " .. tostring(v)
for _, agent in ipairs(TWDA.upvalue(Reticle_Update, "mUseables") or {}) do
  local name = TWDA.agentName(agent)
  local spot = rawget(agent, "usePosAgent") or agent
  local okP, p = pcall(AgentGetWorldPos, spot)
  if okP and p and AgentGetProperty(agent, "Game Selectable") == true then
    local okG, g = pcall(WalkBoxesPosOnWalkBoxes, p, walkBoxes)
    local okVal, val = pcall(WalkBoxesValidatePosition, p, walkBoxes)
    out[#out + 1] = ("%s: use pos %.1f %.1f %.1f, on boxes %s, off by %s, validate %s %s"):format(name, p.x, p.y, p.z,
      okG and g and ("%.1f %.1f %.1f"):format(g.x, g.y, g.z) or tostring(g),
      okG and g and ("%.2f"):format(VectorDistance(p, g)) or "?", tostring(okVal), tostring(val))
  end
end
TWDA.log("PROBE " .. table.concat(out, "\nPROBE "))
return #out
