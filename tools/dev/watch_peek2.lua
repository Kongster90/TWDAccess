-- Dev console (Season 2): for PEEK2_SECONDS (default 20), log (WP lines) whenever the set of
-- usables with a shown dot changes, whether Clementine is peeking, the mode, and walker distances.
local seconds = rawget(_G, "PEEK2_SECONDS") or 20
ThreadStart(function()
  local t0 = GetTotalTime()
  local last = nil
  while GetTotalTime() - t0 < seconds do
    local shown = {}
    for _, a in ipairs(ReticleSelection_GetUsables() or {}) do
      local name = TWDA.agentName(a)
      local dot = AgentFind("ui_dot_" .. name)
      local dotShown = dot and not AgentIsHidden(dot)
      local ok, pos = pcall(AgentGetScreenPos, a)
      if dotShown then
        shown[#shown + 1] = ("%s(%.2f,%.2f)"):format(name, ok and pos and pos.x or -1, ok and pos and pos.y or -1)
      end
    end
    local okP, peeking = pcall(Peek_IsPeeking)
    local m = Game_GetMode()
    local line = ("peek=%s mode=%s shown=%s"):format(tostring(okP and peeking), tostring(m and m.name), table.concat(shown, " "))
    if line ~= last then
      last = line
      local p = AgentGetWorldPos(Game_GetPlayer())
      local d = {}
      for i = 1, 6 do
        local z = AgentFind("obj_zombieHead" .. i)
        if z then d[#d + 1] = ("%d:%.1f"):format(i, VectorDistance(p, AgentGetWorldPos(z))) end
      end
      TWDA.log(("WP t=%.1f %s walkers %s"):format(GetTotalTime() - t0, line, table.concat(d, " ")))
    end
    Yield()
  end
  TWDA.log("WP done")
end)
