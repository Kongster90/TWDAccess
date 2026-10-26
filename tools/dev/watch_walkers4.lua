-- Dev console (The Final Season): for 70 s, log (W5 lines, on change) the player's interaction enable and
-- target and each walker within 8 m: distance, AI on/off, its prompts' dialog nodes, busy.
--   .\console.ps1 -File watch_walkers4.lua
local exec = TWDA.upvalue(AI_Player_E, "ExecuteInteraction")
local mPlayer = TWDA.upvalue(exec, "mPlayer")
local start, last = GetTotalTime(), nil
ThreadStart(function()
  while GetTotalTime() - start < 70 do
    local P = mPlayer.mProps
    local me = AgentGetWorldPos(TWDA.player())
    local r = { string.format("P %s %s", tostring(P["AI Player - Interaction Enable"]), tostring(P["AI Player - Interaction Current Target"])) }
    for _, a in ipairs(SceneGetAgents(TWDA.playerScene())) do
      local ok, e = pcall(AgentGetProperty, a, "AI Agent - AI Agent Enable")
      if ok and e ~= nil and not AgentIsHidden(a) then
        local q = AgentGetWorldPos(a)
        local d = math.sqrt((q.x - me.x) ^ 2 + (q.z - me.z) ^ 2)
        if d < 8 then
          local n1 = tostring(AgentGetProperty(a, "AI Agent - Player Used Interaction Prompt 1 Dialog Node")):gsub("cs_", ""):gsub("Target", "")
          local n2 = tostring(AgentGetProperty(a, "AI Agent - Player Used Interaction Prompt 2 Dialog Node")):gsub("cs_", ""):gsub("Target", "")
          local busy = AgentGetProperty(a, "AI Agent - Busy")
          r[#r + 1] = string.format("%s %.0f %s %s/%s%s", TWDA.agentName(a):gsub("ZombieCombat", "Z"), d, e and "on" or "off", n1, n2, busy and " busy" or "")
        end
      end
    end
    local line = table.concat(r, " | ")
    if line ~= last then TWDA.log("W5 " .. line) last = line end
    local t = GetTotalTime()
    while GetTotalTime() - t < 0.25 do WaitForNextFrame() end
  end
end)
return "watching walkers 5"
