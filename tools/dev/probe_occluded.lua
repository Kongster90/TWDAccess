-- Dev (Season 1): for the hotspot named PROBE_NAME, log (PO lines) its dot's screen position, what is
-- under it, and every point of a grid around it (steps of 0.02, out to 0.2) where the hotspot itself
-- is what lies under the point.
local wanted = rawget(_G, "PROBE_NAME") or "Gate"
local entry
for _, h in ipairs(TWDA.hotspots() or {}) do
  if h.name == wanted or TWDA.hotspotName(h.agent) == wanted then entry = h end
end
if not entry then return "no hotspot " .. wanted end
local agent = entry.agent
local dot = rawget(agent, "dot")
local ok, pos = pcall(AgentGetLogicalScreenPos, dot or agent)
if not ok or not pos then return "no position" end
local under = AgentAtScreenPos(Vector(pos.x, pos.y, 0))
local hits = {}
for ix = -10, 10 do
  for iy = -10, 10 do
    local x, y = pos.x + ix * 0.02, pos.y + iy * 0.02
    local okH, hit = pcall(AgentAtScreenPos, Vector(x, y, 0))
    if okH and hit == agent then hits[#hits + 1] = ("%d,%d"):format(ix, iy) end
  end
end
TWDA.log(("PO %s agent=%s dot=%.3f,%.3f under=%s hits(%d)=%s"):format(wanted, TWDA.agentName(agent), pos.x, pos.y,
  TWDA.agentName(under), #hits, table.concat(hits, " ")))
return #hits .. " hits"
