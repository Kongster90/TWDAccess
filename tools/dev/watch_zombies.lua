-- Development: for 40 seconds while the rifle scope is up, log (lines "WZ", twice a second) for
-- each walker head hotspot at the Motor Inn (obj_ZombieHead1..9, Episode 3) where its dot is on
-- screen, what AgentAtScreenPos finds there, and its parent; and log calls to the scene's
-- BanditAttack_ShootZombie / BanditAttack_ShootBandit. Written 2026-10-08.
--   .\console.ps1 -File tools\dev\watch_zombies.lua
for _, name in ipairs({ "BanditAttack_ShootZombie", "BanditAttack_ShootBandit" }) do
  local orig = rawget(_G, name)
  if type(orig) == "function" and not rawget(_G, "WZ_" .. name) then
    rawset(_G, "WZ_" .. name, orig)
    rawset(_G, name, function(...)
      local args = {}
      for i = 1, select("#", ...) do args[#args + 1] = TWDA.agentName((select(i, ...))) or tostring((select(i, ...))) end
      TWDA.log("WZ call " .. name .. "(" .. table.concat(args, ", ") .. ")")
      TWDA.flushLog()
      return orig(...)
    end)
  end
end
ThreadStart(function()
  local t0 = TWDA.now()
  while TWDA.now() - t0 < 40 do
    local ok, scope = pcall(InputMapperIsActive, "mode_sniper.imap")
    if ok and scope then
      local parts = {}
      for i = 1, 9 do
        local head = AgentFind("obj_ZombieHead" .. i)
        if head then
          local dot = rawget(head, "dot")
          local okD, p = pcall(AgentGetLogicalScreenPos, dot)
          if not (okD and p) then p = AgentGetScreenPos(head) end
          local okH, hit = pcall(AgentAtScreenPos, Vector(p.x, p.y, 0))
          local okP, parent = pcall(AgentGetParent, head)
          if p.x > -0.1 and p.x < 1.1 and p.y > -0.1 and p.y < 1.1 then
            parts[#parts + 1] = ("H%d %.2f,%.2f hit=%s par=%s"):format(i, p.x, p.y, okH and TWDA.agentName(hit) or "?",
              okP and TWDA.agentName(parent) or "?")
          end
        end
      end
      TWDA.log("WZ " .. ("%.1f "):format(TWDA.now() - t0) .. table.concat(parts, " | "))
      TWDA.flushLog()
    end
    for i = 1, 15 do WaitForNextFrame() end
  end
  TWDA.log("WZ end")
end)
return "watching walkers"
