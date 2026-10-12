-- Development probe (gate bug): walk to a hotspot by name with AgentPathToAgent and log what it
-- returns, how long it took and how far Lee moved. Set PROBE_TARGET first.
local lee = Game_GetPlayer()
local target = AgentFind(PROBE_TARGET or "obj_Treehouse")
local from = AgentGetWorldPos(lee)
local t0 = GetTotalTime()
ThreadStart(function()
  local samples = {}
  ThreadStart(function()
    for i = 1, 6 do
      local okR, reach = pcall(PathAgentDoesPathReachDestination, lee)
      local okL, left = pcall(PathAgentGetPathDistanceRemaining, lee)
      local okP, pathing = pcall(PathAgentIsPathing, lee)
      samples[#samples + 1] = ("%d: reach %s %s, left %s %s, pathing %s"):format(i, tostring(okR), tostring(reach),
        tostring(okL), tostring(left), tostring(pathing))
      WaitForNextFrame()
    end
  end)
  local ok, result = pcall(AgentPathToAgent, lee, rawget(target, "usePosAgent") or target)
  local to = AgentGetWorldPos(lee)
  TWDA.log(("PROBEWALK %s: %s %s after %.2f s, moved %.2f m"):format(TWDA.agentName(target), tostring(ok),
    tostring(result), GetTotalTime() - t0, VectorDistance(from, to)))
  TWDA.log("PROBEWALK " .. table.concat(samples, " | "))
end)
return "started"
