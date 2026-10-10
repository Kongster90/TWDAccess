-- Development: for 40 seconds, while the rifle scope is up, fire at shootout bandits through
-- mode_sniper's sniperFireAtPos, at the point where the bandit itself is under the screen position
-- (AgentAtScreenPos): around the hotspot's dot first, then around the agent's own position. Logs
-- "AF" lines (samples every half second, and each shot). Written 2026-10-08 to learn how the Motor
-- Inn shootout (Episode 3) takes a shot.
--   .\console.ps1 -File tools\dev\sniper_autofire.lua
ThreadStart(function()
  local t0 = TWDA.now()
  local fire = TWDA.upvalue(TWDA.unwrap(mode_sniper.OnRelease), "sniperFire")
  local at = TWDA.upvalue(fire, "sniperFireAtPos")
  local NEAR = { { 0, 0 } }
  for _, r in ipairs({ 0.02, 0.04, 0.06, 0.08 }) do
    for _, d in ipairs({ { 0, -r }, { 0, r }, { r, 0 }, { -r, 0 }, { r, -r }, { -r, -r }, { r, r }, { -r, r } }) do NEAR[#NEAR + 1] = d end
  end
  local function find(name, base)
    for _, d in ipairs(NEAR) do
      local v = Vector(base.x + d[1], base.y + d[2], 0)
      local ok, hit = pcall(AgentAtScreenPos, v)
      if ok and TWDA.agentName(hit) == name then return v end
    end
    return nil
  end
  local shots, lastSample = 0, -1
  while TWDA.now() - t0 < 40 and shots < 3 do
    local okS, scope = pcall(InputMapperIsActive, "mode_sniper.imap")
    if okS and scope then
      local sample = TWDA.now() - lastSample > 0.5
      if sample then lastSample = TWDA.now() end
      for _, name in ipairs({ "ShootoutBandit1", "ShootoutBandit2", "ShootoutBandit3" }) do
        local b = AgentFind(name)
        if b and not AgentIsHidden(b) then
          local dot = rawget(b, "dot")
          local okD, dp = pcall(AgentGetLogicalScreenPos, dot)
          local p = AgentGetScreenPos(b)
          local target = (okD and dp and find(name, dp)) or find(name, p)
          if sample then
            local okC, mid = pcall(AgentAtScreenPos, Vector(0.5, 0.5, 0))
            local okH, h = pcall(AgentAtScreenPos, Vector(p.x, p.y, 0))
            TWDA.log(("AF %.1f %s pos %.2f,%.2f dot %s hit %s mid %s target %s"):format(TWDA.now() - t0, name, p.x, p.y,
              okD and dp and ("%.2f,%.2f"):format(dp.x, dp.y) or "nil", okH and TWDA.agentName(h) or "?",
              okC and TWDA.agentName(mid) or "?", target and ("%.2f,%.2f"):format(target.x, target.y) or "nil"))
          end
          if target then
            local ok, r = pcall(at, target)
            shots = shots + 1
            TWDA.log(("AF %.1f fired at %s (%.2f,%.2f): %s %s"):format(TWDA.now() - t0, name, target.x, target.y, tostring(ok), tostring(r)))
            TWDA.flushLog()
            for i = 1, 60 do WaitForNextFrame() end
            break
          end
        end
      end
      TWDA.flushLog()
    end
    WaitForNextFrame()
  end
  TWDA.log("AF end")
end)
return "autofire armed"
