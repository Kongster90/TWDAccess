-- Development: for 60 seconds, log (lines "WW", four times a second) each walker at the Motor Inn
-- (Zombie1..9, Episode 3): its distance from Lee in meters, where its head's dot is on screen,
-- and H if hidden; plus whether the scope is up. Written 2026-10-09 to see what reaches Lee.
--   .\console.ps1 -File tools\dev\watch_walkers.lua
ThreadStart(function()
  local t0 = TWDA.now()
  while TWDA.now() - t0 < 60 do
    local lee = Game_GetPlayer()
    local lp = AgentGetWorldPos(lee)
    local parts = {}
    for i = 1, 9 do
      local z = AgentFind("Zombie" .. i)
      if z then
        local ok, d = pcall(VectorDistance, AgentGetWorldPos(z), lp)
        local head = AgentFind("obj_ZombieHead" .. i)
        local sp = "-"
        if head then
          local okD, p = pcall(AgentGetLogicalScreenPos, rawget(head, "dot"))
          if okD and p then sp = ("%.2f,%.2f"):format(p.x, p.y) end
        end
        parts[#parts + 1] = ("Z%d %.1fm %s%s"):format(i, ok and d or -1, sp, AgentIsHidden(z) and " H" or "")
      end
    end
    local okS, scope = pcall(InputMapperIsActive, "mode_sniper.imap")
    TWDA.log(("WW %.1f %s | %s"):format(TWDA.now() - t0, (okS and scope) and "scope" or "-", table.concat(parts, " | ")))
    TWDA.flushLog()
    for i = 1, 15 do WaitForNextFrame() end
  end
  TWDA.log("WW end")
end)
return "watching walkers"
