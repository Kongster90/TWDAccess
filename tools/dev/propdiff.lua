-- Development: find which of an agent's properties change when something happens to it.
--   DEV.snap("obj_trainEngineConsoleSwitch1")   -- remember every property value
--   ...toggle the switch...
--   DEV.diff("obj_trainEngineConsoleSwitch1")   -- the keys (symbols) whose values changed
-- Property keys are symbols (hashes of the names), so this finds the key, not its name.
DEV = DEV or {}
DEV.snaps = DEV.snaps or {}
local function values(name)
  local agent = AgentFind(name)
  local props = AgentGetProperties(agent)
  local out = {}
  for _, key in ipairs(PropertyGetKeys(props)) do
    local ok, v = pcall(AgentGetProperty, agent, key)
    out[tostring(key)] = ok and tostring(v) or "?"
  end
  return out
end
function DEV.snap(name)
  DEV.snaps[name] = values(name)
  local n = 0
  for _ in pairs(DEV.snaps[name]) do n = n + 1 end
  return "snapped " .. n
end
function DEV.diff(name)
  local before, now = DEV.snaps[name] or {}, values(name)
  local out = {}
  for k, v in pairs(now) do
    if before[k] ~= v then out[#out + 1] = k .. ": " .. tostring(before[k]) .. " -> " .. v end
  end
  return #out == 0 and "no change" or table.concat(out, " | ")
end
return "propdiff ready"
