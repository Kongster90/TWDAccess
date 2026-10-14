-- Dev console (Season 2): for AFTER2_SECONDS (default 40), log (WA lines) changes in the mode, the
-- input maps, usables with a shown dot (with their verbs), action agents and the reticle.
local seconds = rawget(_G, "AFTER2_SECONDS") or 40
ThreadStart(function()
  local t0 = GetTotalTime()
  local last = nil
  while GetTotalTime() - t0 < seconds do
    local shown = {}
    for _, a in ipairs(ReticleSelection_GetUsables() or {}) do
      local name = TWDA.agentName(a)
      local dot = AgentFind("ui_dot_" .. name)
      if dot and not AgentIsHidden(dot) then shown[#shown + 1] = name end
    end
    local maps = {}
    for _, n in ipairs(InputMapperGetActiveMapperNames() or {}) do maps[#maps + 1] = tostring(n) end
    local acts = {}
    local okA, list = pcall(Action_GetActiveActions)
    for _, a in ipairs(okA and type(list) == "table" and list or {}) do acts[#acts + 1] = TWDA.agentName(a) end
    local m = Game_GetMode()
    local line = ("mode=%s maps=%s shown=%s actions=%s reticle=%s"):format(tostring(m and m.name), table.concat(maps, ","),
      table.concat(shown, " "), table.concat(acts, " "), tostring(Reticle_IsEnabled and Reticle_IsEnabled()))
    if line ~= last then
      last = line
      TWDA.log(("WA t=%.1f %s"):format(GetTotalTime() - t0, line))
    end
    Yield()
  end
  TWDA.log("WA done")
end)
