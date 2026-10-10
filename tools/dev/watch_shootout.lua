-- Development: for 90 seconds, log (lines "WS", only when something changes) the state of the
-- Motor Inn shootout (Episode 3, env_motorInnBanditAttack.lua): peeking, the lean directions, the
-- reticle (ready, combat, focus), what is usable in view and to the sides, the active input modes
-- and the countdown. Written 2026-10-08.
--   .\console.ps1 -File tools\dev\watch_shootout.lua
ThreadStart(function()
  local t0 = TWDA.now()
  local IMAPS = { "mode_peek.imap", "mode_sniper.imap", "Navigate.imap", "mode_Reticle.imap", "mode_struggle.imap" }
  local function call(fn, ...)
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
  end
  local lastLine = nil
  while TWDA.now() - t0 < 90 do
    local parts = {}
    parts[#parts + 1] = "peek=" .. tostring(call(Peek_IsPeeking)) .. " " .. tostring(TWDA.describePeek and TWDA.describePeek())
    parts[#parts + 1] = "ready=" .. tostring(TWDA.reticleReady()) .. " combat=" .. tostring(call(ReticleUI_InCombatMode))
      .. " focus=" .. tostring(TWDA.agentName(call(Reticle_GetAgentFocused)))
    local modes = {}
    for _, m in ipairs(IMAPS) do if call(InputMapperIsActive, m) == true then modes[#modes + 1] = m:gsub("%.imap", "") end end
    parts[#parts + 1] = "modes=" .. table.concat(modes, ",")
    local use = {}
    for _, e in ipairs(TWDA.hotspots()) do
      if e.clickable then use[#use + 1] = e.name .. (e.side and ("@" .. e.side) or "") end
    end
    parts[#parts + 1] = "use=" .. table.concat(use, ",")
    parts[#parts + 1] = "cd=" .. tostring(TWDA.describeCountdown and TWDA.describeCountdown())
    local line = table.concat(parts, " | ")
    if line ~= lastLine then
      lastLine = line
      TWDA.log(("WS %.1f %s"):format(TWDA.now() - t0, line))
      TWDA.flushLog()
    end
    for i = 1, 6 do WaitForNextFrame() end
  end
  TWDA.log("WS end")
end)
return "watching"
