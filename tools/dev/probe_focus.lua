-- Dev (Season 1): hold the reticle at PROBE_X, PROBE_Y for two seconds and log (PF lines) each
-- change of the focused agent and of the action icons shown.
local x, y = rawget(_G, "PROBE_X") or 0.5, rawget(_G, "PROBE_Y") or 0.5
ThreadStart(function()
  local t0, last = GetTotalTime(), nil
  while GetTotalTime() - t0 < 2 do
    pcall(ReticleController_SetScreenPos, x, y, false)
    local focused = TWDA.agentName(Reticle_GetAgentFocused and Reticle_GetAgentFocused())
    local under = TWDA.agentName(AgentAtScreenPos(Vector(x, y, 0)))
    local line = "focused=" .. focused .. " under=" .. under
    if line ~= last then
      last = line
      TWDA.log(("PF %.2f %s"):format(GetTotalTime() - t0, line))
    end
    WaitForNextFrame()
  end
end)
return "probing"
