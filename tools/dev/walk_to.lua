-- Development: walk Lee into an agent by name (WALK_TO) with the game's path-finding, logging
-- what AgentPathToAgent returns and where he ends up (WALKTO lines).
local lee = Game_GetPlayer()
local target = AgentFind(WALK_TO)
local from = AgentGetWorldPos(lee)
ThreadStart(function()
  local ok, result = pcall(AgentPathToAgent, lee, target)
  local to = AgentGetWorldPos(lee)
  TWDA.log(("WALKTO %s: %s %s, from %.1f %.1f %.1f to %.1f %.1f %.1f"):format(WALK_TO, tostring(ok), tostring(result),
    from.x, from.y, from.z, to.x, to.y, to.z))
end)
return "walking"
