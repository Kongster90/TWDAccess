-- Development: for WATCH_TIMERS_SECONDS (default 600), log every timer agent in Lee's scene (TM
-- lines in twda.log): progress (every quarter second while it moves), length, speed, enabled, the
-- scene's time scale and the completion node. How the "about 1 second" of the Savannah alley chase
-- was looked into (Episode 4).
--   .\console.ps1 -File watch_timers.lua
local seconds = rawget(_G, "WATCH_TIMERS_SECONDS") or 600
local function prop(agent, key)
  local ok, value = pcall(AgentGetProperty, agent, key)
  if ok then return value end
end
local last = {}
local agents, scanAt = {}, -10
local function step()
  local now = TWDA.now()
  if now - scanAt > 3 then
    scanAt, agents = now, {}
    local okScene, scene = pcall(AgentGetScene, Game_GetPlayer())
    local ok, list = pcall(SceneGetAgents, okScene and scene or nil)
    for _, agent in ipairs(ok and type(list) == "table" and list or {}) do
      if prop(agent, "Timer Length") ~= nil then agents[#agents + 1] = agent end
    end
  end
  for _, agent in ipairs(agents) do
    local name = TWDA.agentName(agent)
    local p = prop(agent, "Timer Progress")
    local key = tostring(prop(agent, "Timer Enabled")) .. "|" .. tostring(prop(agent, "Timer Length"))
    local seen = last[name] or {}
    -- (Each change of switch or length; a moving progress every quarter second.)
    if seen.key ~= key or (p ~= seen.p and now - (seen.at or -10) > 0.25) then
      last[name] = { key = key, p = p, at = now }
      local okScale, scale = pcall(function() return SceneGetTimeScale(AgentGetScene(agent)) end)
      local okGame, game = pcall(GetTimeScale)
      TWDA.log(("TM %s progress %s length %s speed %s enabled %s looping %s pauseDlg %s scale %s game %s end %s"):format(name,
        tostring(p), tostring(prop(agent, "Timer Length")), tostring(prop(agent, "Timer Speed Multiplier")),
        tostring(prop(agent, "Timer Enabled")), tostring(prop(agent, "Timer Looping")),
        tostring(prop(agent, "Timer Pause During Dialog")), tostring(okScale and scale), tostring(okGame and game),
        tostring(prop(agent, "Timer Dialog on completion"))))
    end
  end
end
ThreadStart(function()
  local t0 = TWDA.now()
  while TWDA.now() - t0 < seconds do
    local ok, err = pcall(step)
    if not ok then
      TWDA.log("TM error: " .. tostring(err))
      return
    end
    WaitForNextFrame()
  end
  TWDA.log("TM done")
end)
return "watching timers"
