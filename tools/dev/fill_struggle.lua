-- Dev: fill a Michonne waggle struggle with its stroke callback (Struggle_OnSwipe), log when the
-- finishing move is ready (FS lines), then finish it with Struggle_OnDeathBlowB as E would.
ThreadStart(function()
  local t0 = GetTotalTime()
  local function ready()
    return TWDA.upvalue(Struggle_OnDeathBlowB, "mDeathBlowReadyStart") ~= nil
      or TWDA.upvalue(Struggle_OnSwipeLeft, "mDeathBlowReadyStart") ~= nil
  end
  for i = 1, 40 do
    if ready() then break end
    Struggle_OnSwipe()
    Sleep(0.08)
  end
  TWDA.log(("FS ready=%s after %.2f s"):format(tostring(ready()), GetTotalTime() - t0))
  Sleep(0.2)
  local ok, err = pcall(Struggle_OnDeathBlowB, {})
  TWDA.log("FS deathblow " .. tostring(ok) .. " " .. tostring(err))
end)
return "filling"
