-- Dev console: list agents in the player's scene whose names look like triggers or walk targets,
-- with their distance from the player and trigger properties.
local player = Game_GetPlayer()
local scene = AgentGetScene(player)
local from = AgentGetWorldPos(player)
local out = {}
local keys = { "Trigger Enabled", "Trigger Enter Dialog", "Trigger Exit Dialog", "Trigger Dialog File",
  "Trigger - Enter Dialog", "Trigger - Dialog", "Trigger Enter Dialog Node" }
for _, a in ipairs(SceneGetAgents(scene) or {}) do
  local name = TWDA.agentName(a)
  local lower = name:lower()
  if lower:find("trigger") or lower:find("walk") or lower:find("path") or lower:find("exit") then
    local ok, pos = pcall(AgentGetWorldPos, a)
    local d = ok and pos and VectorDistance(from, pos) or -1
    local props = {}
    local okK, pkeys = pcall(PropertyGetKeys, AgentGetProperties(a))
    for _, k in ipairs(okK and pkeys or {}) do
      local ks = tostring(k)
      if ks:lower():find("trigger") or ks:lower():find("dialog") then
        local okV, v = pcall(AgentGetProperty, a, k)
        props[#props + 1] = ks .. "=" .. tostring(okV and v)
      end
    end
    out[#out + 1] = ("%s %.1fm hidden=%s | %s"):format(name, d, tostring(AgentIsHidden(a)), table.concat(props, "; "))
  end
end
table.sort(out)
TWDA.log("TRIG " .. #out .. "\n" .. table.concat(out, "\n"))
return #out
