-- Development: for 40 seconds, log (lines "WT") Lee's position and the tractor's cover zone at the
-- dairy fence (Episode 2): the world and screen positions of Lee, trigger_tractorRearEdge and
-- trigger_tractorFrontEdge, and whether free walking is on. Written 2026-10-08.
--   .\console.ps1 -File tools\dev\watch_tractor.lua
ThreadStart(function()
  local t0 = TWDA.now()
  local function f(v) return v and ("%.2f,%.2f,%.2f"):format(v.x, v.y, v.z) or "nil" end
  local rear, front = AgentFind("trigger_tractorRearEdge"), AgentFind("trigger_tractorFrontEdge")
  local tractor = AgentFind("obj_tractor102")
  local last = -1
  while TWDA.now() - t0 < 40 do
    if TWDA.now() - last >= 0.25 then
      last = TWDA.now()
      local lee = Game_GetPlayer()
      local okW, walking = pcall(InputMapperIsActive, "Navigate.imap")
      TWDA.log(("WT %.2f walk=%s lee %s | rear %s | front %s | tractor %s || screen lee %s rear %s front %s"):format(
        TWDA.now() - t0, tostring(okW and walking), f(AgentGetWorldPos(lee)), f(AgentGetWorldPos(rear)), f(AgentGetWorldPos(front)),
        f(AgentGetWorldPos(tractor)), f(AgentGetScreenPos(lee)), f(AgentGetScreenPos(rear)), f(AgentGetScreenPos(front))))
      TWDA.flushLog()
    end
    WaitForNextFrame()
  end
end)
return "watching"
