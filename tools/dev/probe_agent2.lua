-- Dev console (Season 2): for PA_SECONDS (default 60), every 0.2 s while PA_AGENT exists and is
-- not hidden, log (PA lines) its selectable flag, verbs, screen position, the mode and play flag.
local name = rawget(_G, "PA_AGENT")
local seconds = rawget(_G, "PA_SECONDS") or 60
ThreadStart(function()
  local t0 = GetTotalTime()
  local last, lastAt = nil, 0
  while GetTotalTime() - t0 < seconds do
    if GetTotalTime() - lastAt >= 0.2 then
      lastAt = GetTotalTime()
      local a = AgentFind(name)
      if a and not AgentIsHidden(a) then
        local okS, sel = pcall(AgentGetProperty, a, "Game Selectable")
        local nverbs = -1
        local okV = pcall(function()
          ReticleVerbs_BuildVerbData(a)
          local v = ReticleVerbs_GetAvailableVerbs() or {}
          nverbs = #v
        end)
        local okP, pos = pcall(AgentGetScreenPos, a)
        local m = Game_GetMode()
        local inList = false
        for _, u in ipairs(ReticleSelection_GetUsables() or {}) do if u == a then inList = true end end
        local line = ("sel=%s verbs=%s pos=%s mode=%s play=%s combat=%s inUsables=%s"):format(tostring(okS and sel), tostring(nverbs),
          okP and pos and ("%.2f,%.2f"):format(pos.x, pos.y) or "?", tostring(m and m.name), tostring(m and m.bPlayMode),
          tostring(Reticle_IsCombatMode and Reticle_IsCombatMode()), tostring(inList))
        if line ~= last then last = line TWDA.log(("PA t=%.1f %s"):format(GetTotalTime() - t0, line)) end
      end
    end
    Yield()
  end
end)
