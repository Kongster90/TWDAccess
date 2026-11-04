-- Development probe (nineteenth session): where Lee is, and the dairy picket gate's position and
-- use position, and the walk boxes near the gate.
local lee = Game_GetPlayer()
local here = AgentGetWorldPos(lee)
local gate = AgentFind("obj_doorPicketFenceDairyFarm")
local g = AgentGetWorldPos(gate)
local use = rawget(gate, "usePosAgent")
local u = use and AgentGetWorldPos(use)
local out = { ("lee %.1f %.1f %.1f; gate %.1f %.1f %.1f; use pos %s"):format(here.x, here.y, here.z, g.x, g.y, g.z,
  u and ("%.1f %.1f %.1f (%s)"):format(u.x, u.y, u.z, AgentGetName(use)) or "none") }
for _, k in ipairs({ "WD Should Path", "WDUseable - Far Use", "WDUseable - Action Use Dialog Start Node", "Useable - Path To", "Useable - Use Agent" }) do
  out[#out + 1] = k .. " = " .. tostring(gate.mProps[k])
end
local okWB, wb = pcall(PathAgentGetWalkBoxes, lee)
for _, dz in ipairs({ -3, -1, 1, 3 }) do
  local p = Vector(g.x, g.y, g.z + dz)
  local okG, ground = pcall(WalkBoxesPosOnWalkBoxes, p, wb)
  out[#out + 1] = ("gate z%+d -> %s"):format(dz, okG and ground and ("%.1f %.1f %.1f"):format(ground.x, ground.y, ground.z) or tostring(ground))
end
TWDA.log("GATE " .. table.concat(out, "\nGATE "))
return #out
