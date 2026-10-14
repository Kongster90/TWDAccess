-- Dev console (Season 2): log (WW lines) ChoredMovement_Start's agent and its chores, Dialog_Play
-- nodes, Game_UseAgent, and, every 0.2 s while anything changes, all usables (dot shown or not),
-- the reticle's selection and focus, and the player's position. WW_SECONDS long (default 60).
local seconds = rawget(_G, "WW_SECONDS") or 60
local t0 = GetTotalTime()
local function on() return GetTotalTime() - t0 < seconds end
TWDA.hookBefore("ChoredMovement_Start", function(agent)
  if not on() then return end
  local props = {}
  for _, k in ipairs({ "Chored Movement - Forward Chore", "Chored Movement - Backward Chore", "Chored Movement - Start Time" }) do
    local ok, v = pcall(AgentGetProperty, agent, k)
    props[#props + 1] = k .. "=" .. tostring(ok and v)
  end
  TWDA.log(("WW t=%.1f ChoredMovement_Start(%s) %s"):format(GetTotalTime() - t0, TWDA.agentName(agent), table.concat(props, "; ")))
end)
TWDA.hookBefore("Dialog_Play", function(a, b)
  if on() then TWDA.log(("WW t=%.1f Dialog_Play(%s, %s)"):format(GetTotalTime() - t0, tostring(a), tostring(b))) end
end)
TWDA.hookBefore("Game_UseAgent", function(a)
  if on() then TWDA.log(("WW t=%.1f Game_UseAgent(%s)"):format(GetTotalTime() - t0, TWDA.agentName(a))) end
end)
ThreadStart(function()
  local last, lastAt = nil, 0
  while on() do
    if GetTotalTime() - lastAt >= 0.2 then
      lastAt = GetTotalTime()
      local us = {}
      for _, a in ipairs(ReticleSelection_GetUsables() or {}) do
        local name = TWDA.agentName(a)
        local dot = AgentFind("ui_dot_" .. name)
        us[#us + 1] = name .. ((dot and not AgentIsHidden(dot)) and "*" or "")
      end
      local line = ("usables=%s sel=%s focus=%s"):format(table.concat(us, " "), TWDA.agentName(Reticle_GetSelectedAgent()),
        TWDA.agentName(ReticleSelection_GetFocus()))
      if line ~= last then
        last = line
        TWDA.log(("WW t=%.1f %s"):format(GetTotalTime() - t0, line))
      end
    end
    Yield()
  end
end)
