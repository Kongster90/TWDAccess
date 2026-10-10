-- Development: 400 Days' cornfield (Chapter4B_Cornfield.lua). For 60 seconds, every quarter
-- second, log (WC2 lines) the player's position, the guided path's progress, the panic meter,
-- Dying, and the pursuers' trigger and flashlight positions, to learn what the rows expect.
--   .\console.ps1 -File watch_corn.lua
local names = { "trigger_pursuer1", "trigger_PanicMeter_pursuer1", "FlashlightDee", "Flashlight1", "obj_sneakyFlashlight",
  "trigger_CloseCall", "trigger_PursuerDeeReachesTractor" }
ThreadStart(function()
  local t0 = TWDA.now()
  local lastAt = -10
  while TWDA.now() - t0 < 60 do
    local now = TWDA.now()
    if now - lastAt >= 0.25 then
      lastAt = now
      local ok, err = pcall(function()
        local p = AgentGetWorldPos(TWDA.player())
        local okC, ctl = pcall(ChoredMovement_GetController)
        local okP, pct = pcall(ChoredMovement_GetTimePercent)
        local okH, hidden = pcall(SceneIsHidden, "ui_panicmeter.scene")
        local parts = { ("WC2 %.2f bonnie %.1f %.1f %.1f path %s %.2f panic %s dying %s"):format(now - t0, p.x, p.y, p.z,
          tostring(okC and ctl ~= nil), okP and pct or -1, tostring(okH and not hidden), tostring(Logic["Dying"])) }
        for _, n in ipairs(names) do
          local okA, a = pcall(AgentFind, n)
          if okA and a then
            local q = AgentGetWorldPos(a)
            local okE, en = pcall(AgentGetProperty, a, "Trigger Enabled")
            parts[#parts + 1] = ("%s %.1f,%.1f%s"):format(n:gsub("trigger_", "t_"), q.x, q.z, (okE and en == false) and " off" or "")
          end
        end
        TWDA.log(table.concat(parts, " | "))
      end)
      if not ok then TWDA.log("WC2 error " .. tostring(err)) return end
    end
    WaitForNextFrame()
  end
end)
return "watching the cornfield"
