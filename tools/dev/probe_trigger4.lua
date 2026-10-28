-- Dev console (The Final Season): one trigger's box, properties and whether the player is inside.
-- Set PROBE_TRIGGER to its agent name first.
local name = rawget(_G, "PROBE_TRIGGER") or "trigger_dialog_clementimeOut"
local agent = AgentFindInScene(name, TWDA.playerScene())
if not agent then return "no agent " .. name end
local out = {}
local function prop(k)
  local ok, v = pcall(AgentGetProperty, agent, k)
  return ok and v
end
local lo = AgentLocalToWorld(agent, prop(kExtentsMin) or Vector(0, 0, 0))
local hi = AgentLocalToWorld(agent, prop(kExtentsMax) or Vector(0, 0, 0))
out[#out + 1] = ("box x %.1f..%.1f z %.1f..%.1f"):format(math.min(lo.x, hi.x), math.max(lo.x, hi.x), math.min(lo.z, hi.z), math.max(lo.z, hi.z))
local p = AgentGetWorldPos(TWDA.player())
out[#out + 1] = ("player %.1f %.1f"):format(p.x, p.z)
for _, k in ipairs(AgentGetPropertyNames and AgentGetPropertyNames(agent) or {}) do
  local v = prop(k)
  if tostring(k):find("Trigger") or tostring(k):find("Dialog") then out[#out + 1] = tostring(k) .. " = " .. tostring(type(v) == "table" and TWDA.agentName(v) or v) end
end
local okP, play = pcall(Game_IsPlayMode)
out[#out + 1] = "play mode " .. tostring(okP and play)
return table.concat(out, "\n")
