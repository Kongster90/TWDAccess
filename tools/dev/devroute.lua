-- Development: DEV.route({ "obj_rvDoorSide", "obj_trainEngineLadder" }) walks Lee to each hotspot
-- agent in turn (path-finding) and uses it through the reticle with its first action that is not
-- looking, waiting for each use to finish (the reticle back, or 15 seconds). Logs "DEVROUTE"
-- lines. For crossing scenes split by doors and ladders (the train in Episode 3).
--   .\console.ps1 -File tools\dev\devroute.lua      (once per Lua state)
DEV = DEV or {}
function DEV.route(names)
  ThreadStart(function()
    for _, name in ipairs(names) do
      local agent = AgentFind(name)
      if not agent then TWDA.log("DEVROUTE no " .. name) TWDA.flushLog() return end
      local okWalk = pcall(InputMapperIsActive, "Navigate.imap") and InputMapperIsActive("Navigate.imap")
      if okWalk then AgentPathToAgent(Game_GetPlayer(), rawget(agent, "usePosAgent") or agent) end
      for i = 1, 30 do WaitForNextFrame() end
      TWDA.useWithReticle(agent)
      local t0 = TWDA.now()
      -- The use starts (reticle off) and ends (reticle back).
      while TWDA.reticleReady() and TWDA.now() - t0 < 4 do WaitForNextFrame() end
      while not TWDA.reticleReady() and TWDA.now() - t0 < 15 do WaitForNextFrame() end
      for i = 1, 20 do WaitForNextFrame() end
      TWDA.log("DEVROUTE done " .. name .. " at " .. tostring(AgentGetWorldPos(Game_GetPlayer())))
      TWDA.flushLog()
    end
    TWDA.log("DEVROUTE end")
    TWDA.flushLog()
  end)
  return "routing"
end
return "DEV.route ready"
