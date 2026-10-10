-- Development: for 60 seconds, while the rifle scope is up (mode_sniper; the Motor Inn shootout,
-- Episode 3), log (lines "SN", only on change) what is under the middle of the screen, where the
-- shootout bandits are on screen, and the aim chores' times. Written 2026-10-08.
--   .\console.ps1 -File tools\dev\watch_sniper.lua
ThreadStart(function()
  local t0 = TWDA.now()
  local function call(fn, ...)
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
  end
  local function f(v) return v and ("%.2f,%.2f"):format(v.x, v.y) or "nil" end
  local start = TWDA.unwrap(mode_sniper.OnStart)
  local h, v = TWDA.upvalue(start, "h_chore"), TWDA.upvalue(start, "v_chore")
  local lastLine
  while TWDA.now() - t0 < 60 do
    if call(InputMapperIsActive, "mode_sniper.imap") == true then
      local parts = { "mid=" .. tostring(TWDA.agentName(call(AgentAtScreenPos, Vector(0.5, 0.5, 0)))) }
      for _, name in ipairs({ "ShootoutBandit1", "ShootoutBandit2", "ShootoutBandit3" }) do
        local a = call(AgentFind, name)
        if a then
          parts[#parts + 1] = name:sub(-7) .. "=" .. f(call(AgentGetScreenPos, a))
            .. (call(AgentIsHidden, a) and "H" or "") .. (call(AgentIsOnScreen, a) and "" or "off")
        end
      end
      parts[#parts + 1] = "h=" .. tostring(call(ControllerGetTime, h)) .. " v=" .. tostring(call(ControllerGetTime, v))
      local line = table.concat(parts, " ")
      if line ~= lastLine then
        lastLine = line
        TWDA.log(("SN %.1f %s"):format(TWDA.now() - t0, line))
        TWDA.flushLog()
      end
    end
    for i = 1, 4 do WaitForNextFrame() end
  end
  TWDA.log("SN end")
end)
return "watching the scope"
