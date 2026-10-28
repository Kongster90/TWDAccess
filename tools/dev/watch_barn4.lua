-- Dev console (The Final Season, Episode 4, ForestBarn.lua: the stall doors and the wheelbarrow).
-- Logs (WB lines) the player agent, mode and position on change, every Death, dialog and trigger
-- call, and ChoredMovement_Start's arguments; Game_RunDialog of cs_holdDoor also logs who called it.
-- Copy to <game>\TWDAccess\autorun.lua (no byte-order mark) to have it in every Lua state.
local G = _G
local function call(name, ...)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return nil end
  local ok, r = pcall(fn, ...)
  if ok then return r end
  return nil
end
local function str(v)
  if type(v) == "table" then
    local ok, n = pcall(TWDA.agentName, v)
    if ok and n and n ~= "" then return n end
  end
  return tostring(v)
end
for _, name in ipairs({ "Death", "Game_RunDialog", "Dialog_Run", "Game_RunSceneDialog", "Trigger_OnEnterDialog",
    "Trigger_OnExitDialog", "Trigger_OnEnter", "ChoredMovement_Start", "ChoredMovement_Stop", "Game_SetPlayer",
    "Game_SetMode", "TriggerEnable", "Useable_OnButtonUse" }) do
  local original = rawget(G, name)
  if type(original) == "function" then
    rawset(G, name, function(...)
      local args = table.pack(...)
      local parts = {}
      for i = 1, math.min(args.n, 5) do parts[#parts + 1] = str(args[i]) end
      TWDA.log(("WB call %s(%s)"):format(name, table.concat(parts, ", ")))
      if name == "Game_RunDialog" and tostring(args[1]):find("holdDoor") then
        TWDA.log("WB traceback " .. debug.traceback("", 2):gsub("\n", " | "))
      end
      return original(...)
    end)
  end
end
local last = {}
local function note(key, value)
  value = tostring(value)
  if last[key] ~= value then
    last[key] = value
    TWDA.log(("WB %s = %s"):format(key, value))
  end
end
ThreadStart(function()
  while true do
    local player = TWDA.player()
    note("player", player and str(player) or "-")
    local ok, pos = pcall(AgentGetWorldPos, player)
    if ok and pos then note("pos", ("%.1f %.1f"):format(pos.x, pos.z)) end
    local mode = call("Game_GetMode")
    note("mode", type(mode) == "table" and (rawget(mode, "name") or "?") or tostring(mode))
    local t = GetTotalTime()
    while GetTotalTime() - t < 0.25 do WaitForNextFrame() end
  end
end)
return "watching the barn"
