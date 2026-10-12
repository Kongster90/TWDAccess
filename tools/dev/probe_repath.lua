-- Development probe (issue #16): walk Lee to PROBE_TARGET twice in a row with AgentPathToAgent,
-- the way the mod's walk and then the game's PathToAndUseAgent do, and log what each returns.
-- Also logs which useables would make DoAction path first ("WD Should Path").
local lee = Game_GetPlayer()
local agent = AgentFind(PROBE_TARGET or "Kenny")
local spot = rawget(agent, "usePosAgent") or agent
local useAgentName = agent.mProps["Useable - Use Agent"]
local pathTarget = (useAgentName and useAgentName ~= "" and AgentExists(useAgentName)) and AgentFind(useAgentName) or agent
TWDA.log(("PROBEPATH %s: usePosAgent %s, Useable - Path To %s, Use Agent %s, navigating %s"):format(TWDA.agentName(agent),
  TWDA.agentName(rawget(agent, "usePosAgent")), tostring(agent.mProps["Useable - Path To"]), tostring(useAgentName),
  tostring(Navigate_IsPathing())))
ThreadStart(function()
  for i, goal in ipairs({ spot, pathTarget, pathTarget }) do
    local t0, from = GetTotalTime(), AgentGetWorldPos(lee)
    local ok, result = pcall(AgentPathToAgent, lee, goal)
    TWDA.log(("PROBEPATH %d to %s: %s %s after %.2f s, moved %.2f m, navigating %s"):format(i, TWDA.agentName(goal),
      tostring(ok), tostring(result), GetTotalTime() - t0, VectorDistance(from, AgentGetWorldPos(lee)),
      tostring(Navigate_IsPathing())))
  end
end)
return "started"
