-- Dev console (The Final Season, Episode 3, RiverShorelineNight.lua, the dock after the herd: "Move
-- between cover while avoiding the searchlight"). Logs (WD lines) for 90 seconds, on change: the
-- flashlight and dock-stealth triggers (enabled, and whether Clementine is inside), where the boat's
-- spotlight points, and Clementine's position.
local G = _G
local names = { "trigger_dialog_bg_flashlightOnClem", "trigger_dialog_bg_flashlightOnClem01",
  "trigger_dialog_bg_flashlightOnClem02", "trigger_dialog_bg_flashlightOnClem03", "trigger_dialog_dockStealth01",
  "trigger_dialog_dockStealth02", "trigger_cs_zombiePier" }
local last = {}
local function note(key, value)
  value = tostring(value)
  if last[key] ~= value then
    last[key] = value
    TWDA.log(("WD %s = %s"):format(key, value))
  end
end
local function corners(agent)
  local okA, a = pcall(AgentGetProperty, agent, "Extents Min")
  local okB, b = pcall(AgentGetProperty, agent, "Extents Max")
  if not (okA and okB and a and b) then return nil end
  return AgentLocalToWorld(agent, a), AgentLocalToWorld(agent, b)
end
local function inside(agent, p)
  local a, b = corners(agent)
  if not a then return "?" end
  local x0, x1 = math.min(a.x, b.x), math.max(a.x, b.x)
  local z0, z1 = math.min(a.z, b.z), math.max(a.z, b.z)
  return p.x >= x0 and p.x <= x1 and p.z >= z0 and p.z <= z1
end
for _, n in ipairs(names) do
  local agent = AgentFind(n)
  if agent then
    local a, b = corners(agent)
    TWDA.log(("WD box %s: %s .. %s"):format(n, a and ("%.1f %.1f"):format(a.x, a.z) or "?", b and ("%.1f %.1f"):format(b.x, b.z) or "?"))
  end
end
ThreadStart(function()
  local start = GetTotalTime()
  while GetTotalTime() - start < 90 do
    local okP, p = pcall(AgentGetWorldPos, TWDA.player())
    if okP and p then
      note("clem", ("%.0f %.0f"):format(p.x, p.z))
      for _, n in ipairs(names) do
        local agent = AgentFind(n)
        if agent then
          local okE, e = pcall(AgentGetProperty, agent, "Trigger Enabled")
          note(n, tostring(okE and e) .. (inside(agent, p) == true and " INSIDE" or ""))
        end
      end
    end
    local spot = AgentFind("obj_spotLightRiverBoat")
    if spot then
      local okR, r = pcall(AgentGetWorldRot, spot)
      if okR and r then note("spot", ("%.0f %.0f %.0f"):format(r.x, r.y, r.z)) end
    end
    local t = GetTotalTime()
    while GetTotalTime() - t < 0.25 do WaitForNextFrame() end
  end
  TWDA.log("WD done")
end)
return "watching the dock"
