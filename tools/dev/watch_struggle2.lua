-- Dev console (Season 2): while a struggle runs, log (WS2S lines) its agent's properties every
-- 0.3 s: the mash meter, the scrubber, left/right parts, and the death-blow state.
local keys = { "Button Mash - Current Percentage", "Chore Scrubber - Percentage Current", "Button Mash - Enabled",
  "Button Mash - Rate of Decay", "Button Mash - Increment", "Struggle - Enable Left", "Struggle - Enable Right",
  "Struggle - Paused", "Struggle - Lose", "Struggle - Complete", "Struggle - Won", "Struggle - Death Blow Required",
  "Button Mash - Max Time Between Mashes" }
ThreadStart(function()
  local t0 = TWDA.now()
  local seenAgent = nil
  while TWDA.now() - t0 < (rawget(_G, "WS2S_SECONDS") or 300) do
    local enter = TWDA.unwrap(Struggle_Enter)
    local agent = TWDA.upvalue(enter, "mStruggleAgent")
    if agent then
      local parts = { TWDA.agentName(agent) }
      for _, k in ipairs(keys) do
        local ok, v = pcall(AgentGetProperty, agent, k)
        if ok and v ~= nil then parts[#parts + 1] = k:gsub("Button Mash %- ", "BM "):gsub("Struggle %- ", "S ") .. "=" .. tostring(v) end
      end
      parts[#parts + 1] = "ready=" .. tostring(TWDA.upvalue(enter, "mDeathBlowReadyStart")) .. " btn=" .. tostring(TWDA.upvalue(enter, "mDeathBlowButton"))
        .. " dir=" .. tostring(TWDA.upvalue(enter, "mMoveDirection"))
      TWDA.log("WS2S " .. table.concat(parts, " | "))
      seenAgent = agent
    end
    Sleep(0.3)
  end
end)
return "watching struggles"
