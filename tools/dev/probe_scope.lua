-- Development: the first time the rifle scope comes up (Season 1, mode_sniper), log ("PSC" lines)
-- where the pointer is and where each target is on screen, then nudge the pointer (the scope turns
-- with the pointer's absolute position, like the shotgun) and log again: how far a target moves on
-- screen for a move of the pointer, for aiming by a tone.
--   .\console.ps1 -File tools\dev\probe_scope.lua     (then play to the scope)
ThreadStart(function()
  local t0 = TWDA.now()
  local function active()
    local ok, on = pcall(InputMapperIsActive, "mode_sniper.imap")
    return ok and on == true
  end
  while not active() and TWDA.now() - t0 < 600 do WaitForNextFrame() end
  if not active() then TWDA.log("PSC no scope") TWDA.flushLog() return end
  for i = 1, 10 do WaitForNextFrame() end
  local function f(v) return v and v.x and ("%.3f,%.3f"):format(v.x, v.y) or "nil" end
  local function pointer()
    local ok, p = pcall(function() return ScreenToViewport(CursorGetPos()) end)
    return ok and p or nil
  end
  local function report(label)
    local parts = {}
    for _, entry in ipairs(TWDA.hotspots and TWDA.hotspots() or {}) do
      if entry.clickable then
        local okS, s = pcall(AgentGetScreenPos, entry.agent)
        local dot = rawget(entry.agent, "dot")
        local okD, d = false, nil
        if dot ~= nil then okD, d = pcall(AgentGetLogicalScreenPos, dot) end
        parts[#parts + 1] = ("%s s=%s d=%s"):format(TWDA.agentName(entry.agent), okS and f(s) or "?", okD and f(d) or "-")
      end
    end
    local okM, mid = pcall(AgentAtScreenPos, Vector(0.5, 0.5, 0))
    TWDA.log(("PSC %.2f %s pointer %s mid %s | %s"):format(TWDA.now() - t0, label, f(pointer()),
      okM and TWDA.agentName(mid) or "?", table.concat(parts, " | ")))
    TWDA.flushLog()
  end
  local p0 = pointer()
  report("start")
  for _, d in ipairs({ { 0.02, 0 }, { 0, 0.02 }, { -0.02, -0.02 } }) do
    local p = pointer()
    pcall(function() CursorSetPos(ViewportToScreen(Vector(p.x + d[1], p.y + d[2], 0))) end)
    for i = 1, 2 do WaitForNextFrame() end
    report(("moved %+.2f %+.2f, 2 frames"):format(d[1], d[2]))
    for i = 1, 10 do WaitForNextFrame() end
    report("10 frames later")
  end
  TWDA.log("PSC end")
  TWDA.flushLog()
end)
return "scope probe armed"
