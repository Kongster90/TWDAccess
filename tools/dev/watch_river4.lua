-- Dev console (The Final Season, Episode 3, RiverShorelineNight.lua: walking with the herd to the
-- pier, hiding behind walkers from the raiders' flashlights). Logs (WR lines) every quarter second
-- what changes: Clementine's position, what she is attached to, the flashlight, the running
-- dialogs, and the walker she is behind; and every Death, Game_RunDialog and Dialog_Play call.
-- Copy to <game>\TWDAccess\autorun.lua to have it in every Lua state (delete it afterwards).
local G = _G
local function call(name, ...)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return nil end
  local ok, r = pcall(fn, ...)
  if ok then return r end
  return nil
end
for _, name in ipairs({ "Death", "Game_RunDialog", "Dialog_Play", "Dialog_Run", "Game_RunSceneDialog", "AgentAttach",
    "AgentDetach", "RiverShorelineNight_EnableFlashlightTracking", "Trigger_OnEnterDialog", "AI_Player_Q", "AI_Player_E" }) do
  local original = rawget(G, name)
  if type(original) == "function" then
    rawset(G, name, function(...)
      local args = table.pack(...)
      local parts = {}
      for i = 1, math.min(args.n, 4) do
        local v = args[i]
        parts[#parts + 1] = type(v) == "table" and TWDA.agentName(v) or tostring(v)
      end
      TWDA.log(("WR call %s(%s)"):format(name, table.concat(parts, ", ")))
      return original(...)
    end)
  end
end
local last = {}
local function note(key, value)
  value = tostring(value)
  if last[key] ~= value then
    last[key] = value
    TWDA.log(("WR %s = %s"):format(key, value))
  end
end
ThreadStart(function()
  while true do
    local player = TWDA.player()
    local ok, pos = pcall(AgentGetWorldPos, player)
    if ok and pos then note("pos", ("%.0f %.0f"):format(pos.x, pos.z)) end
    note("parent", player and TWDA.agentName(call("AgentGetParent", player) or {}) or "-")
    note("flashlight", call("RiverShorelineNight_FlashlightChoreIsPlaying"))
    local exec = TWDA.upvalue(rawget(G, "AI_Player_E"), "ExecuteInteraction")
    local p = exec and TWDA.upvalue(exec, "mPlayer")
    local okP, props = pcall(function() return p.mProps end)
    if okP and props then
      local okT, target = pcall(function() return props["AI Player - Interaction Current Target"] end)
      note("target", okT and target and TWDA.agentName(target) or "-")
      local okI, enabled = pcall(function() return props["AI Player - Interaction Enable"] end)
      note("interaction", okI and enabled)
    end
    local mode = call("Game_GetMode")
    note("mode", type(mode) == "table" and (rawget(mode, "name") or "?") or tostring(mode))
    note("dlg", call("DlgGetCurrentDialog") and TWDA.agentName(call("DlgGetCurrentDialog")) or "-")
    local t = GetTotalTime()
    while GetTotalTime() - t < 0.25 do WaitForNextFrame() end
  end
end)
return "watching the river"
