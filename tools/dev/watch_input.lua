-- Development: for WATCH_INPUT_SECONDS (default 60), log (WI lines in twda.log) each change in the
-- active input maps, the current mode, whether a guided path runs (and its progress), the
-- player's position and the hint on screen. For moments like 400 Days' "Run!" in the cornfield.
--   .\console.ps1 -File watch_input.lua
local seconds = rawget(_G, "WATCH_INPUT_SECONDS") or 60
ThreadStart(function()
  local t0 = TWDA.now()
  local last, lastPosAt = "", -10
  while TWDA.now() - t0 < seconds do
    local ok, err = pcall(function()
      local maps = table.concat(InputMapperGetActiveMapperNames() or {}, ",")
      local mode = Mode_GetCurrent()
      local okC, ctl = pcall(ChoredMovement_GetController)
      local okP, pct = pcall(ChoredMovement_GetTimePercent)
      local state = ("%s | %s | guided %s"):format(maps, tostring(mode and mode.name), tostring(okC and ctl ~= nil))
      local now = TWDA.now()
      if state ~= last or now - lastPosAt > 1 then
        local player = TWDA.player()
        local okPos, pos = pcall(AgentGetWorldPos, player)
        TWDA.log(("WI %.1f %s pct %s pos %s"):format(now - t0, state, tostring(okP and pct), tostring(okPos and pos)))
        last, lastPosAt = state, now
      end
    end)
    if not ok then TWDA.log("WI error " .. tostring(err)) return end
    WaitForNextFrame()
  end
end)
return "watching input"
