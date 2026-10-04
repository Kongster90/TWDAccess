-- Development: for the next 60 seconds, log every change in the set of clickable hotspots (and the
-- current mode) to twda.log, to learn what an action scene expects and when.
--   .\console.ps1 -File tools\dev\watch_hotspots.lua
ThreadStart(function()
  local click = TWDA.upvalue(Reticle_Update, "agentIsClickableNoDialog")
  local last = ""
  local t0 = TWDA.now()
  while TWDA.now() - t0 < 60 do
    local names = {}
    local useables = TWDA.upvalue(Reticle_Update, "mUseables") or {}
    for _, agent in ipairs(useables) do
      local ok, sel = pcall(AgentGetProperty, agent, "Game Selectable")
      local okc, c = pcall(click, agent)
      if ok and sel and okc and c and not AgentIsHidden(agent) then names[#names + 1] = TWDA.agentName(agent) end
    end
    local okm, mode = pcall(Mode_GetCurrent)
    local key = table.concat(names, ",") .. " | " .. tostring(okm and mode and mode.name)
    if key ~= last then
      last = key
      TWDA.log(("WATCH %.1f: %s"):format(TWDA.now() - t0, key))
      TWDA.flushLog()
    end
    WaitForNextFrame()
  end
  TWDA.log("WATCH done")
end)
return "watching"
