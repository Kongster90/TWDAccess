-- Dev console (Season 2): wait (up to 120 s) for a guided path, say "PATHSTART" (for onsay.ps1 to
-- press a key), then log (CM3 lines) the path's percent, move direction and the joystick upvalue
-- every 0.1 s until it ends, plus calls to ChoredMovement_* functions meanwhile.
local set = DEV.unwrap(ChoredMovement_SetJoystickDirection)
ThreadStart(function()
  local t0 = GetTotalTime()
  while not ChoredMovement_IsActive() and GetTotalTime() - t0 < 120 do Yield() end
  if not ChoredMovement_IsActive() then TWDA.log("CM3 no path") return end
  TWDA.say("PATHSTART")
  local s = GetTotalTime()
  local last = -1
  while ChoredMovement_IsActive() and GetTotalTime() - s < 10 do
    if GetTotalTime() - last >= 0.1 then
      last = GetTotalTime()
      local okD, dir = pcall(ChoredMovement_GetMoveDir)
      local okC, ctl = pcall(ChoredMovement_GetForwardController)
      TWDA.log(("CM3 t=%.2f pct=%s dir=%s move=%s pathing=%s A=%s mode=%s ctl=%s"):format(GetTotalTime() - s,
        tostring(ChoredMovement_GetTimePercent()), tostring(okD and dir), tostring(TWDA.upvalue(set, "mMove")),
        tostring(ChoredMovement_IsPathing()), tostring(InputPCIsVKeyPressed(0x41)), tostring(Game_GetMode().name), tostring(okC and ctl)))
    end
    Yield()
  end
  TWDA.log(("CM3 ended after %.2f"):format(GetTotalTime() - s))
end)
