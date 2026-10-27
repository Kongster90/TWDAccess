-- Dev console (The Final Season, Episode 4 opening): when an objective notice comes, and every
-- second for 12 seconds after it, logs (WW lines) Clementine's and every AI walker's position.
local function dump(tag)
  local okP, p = pcall(AgentGetWorldPos, TWDA.player())
  local parts = { tag, okP and p and ("clem %.1f %.1f"):format(p.x, p.z) or "clem ?" }
  for _, agent in ipairs(SceneGetAgents(TWDA.playerScene())) do
    local ok, on = pcall(AgentGetProperty, agent, "AI Agent - AI Agent Enable")
    if ok and on == true and agent ~= TWDA.player() then
      local okW, w = pcall(AgentGetWorldPos, agent)
      if okW and w then parts[#parts + 1] = ("%s %.1f %.1f"):format(TWDA.agentName(agent), w.x, w.z) end
    end
  end
  TWDA.log("WW " .. table.concat(parts, " | "))
end
local original = rawget(_G, "Notification_ShowObjective")
if type(original) == "function" then
  rawset(_G, "Notification_ShowObjective", function(...)
    ThreadStart(function()
      for i = 0, 12 do
        dump("t" .. i)
        local t = GetTotalTime()
        while GetTotalTime() - t < 1 do WaitForNextFrame() end
      end
    end)
    return original(...)
  end)
end
return "watching the walkers at the objective"
