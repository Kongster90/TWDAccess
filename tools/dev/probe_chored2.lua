-- Dev console (Season 2): for 5 seconds, log what ChoredMovement sees (move direction, percent,
-- pathing, the joystick upvalue) every 0.25 s. Hold a movement key meanwhile.
local set = DEV.unwrap(ChoredMovement_SetJoystickDirection)
ThreadStart(function()
  local t0 = GetTotalTime()
  local last = -1
  while GetTotalTime() - t0 < 5 do
    if GetTotalTime() - last >= 0.25 then
      last = GetTotalTime()
      local okD, dir = pcall(ChoredMovement_GetMoveDir)
      TWDA.log(("CM2 t=%.2f pct=%s dir=%s move=%s old=%s pathing=%s active=%s joyC=%s"):format(GetTotalTime() - t0,
        tostring(ChoredMovement_GetTimePercent()), tostring(okD and dir), tostring(TWDA.upvalue(set, "mMove")),
        tostring(TWDA.upvalue(set, "mOldMove")), tostring(ChoredMovement_IsPathing()), tostring(ChoredMovement_IsActive()),
        tostring(Input_IsJoystickCentered and Input_IsJoystickCentered())))
    end
    Yield()
  end
end)
