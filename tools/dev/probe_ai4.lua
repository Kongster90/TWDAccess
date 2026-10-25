-- Dev console (The Final Season): every 0.2 s for PROBE_SECONDS (default 40), log (AI4 lines) the
-- player's AI interaction state (ai_player.lua's mPlayer.mProps: current target, ranged, enable)
-- and the target walker's interaction prompts, distance and busy flag, when any of it changes.
local seconds = rawget(_G, "PROBE_SECONDS") or 40
local exec = TWDA.upvalue(AI_Player_E, "ExecuteInteraction")
local function player() return TWDA.upvalue(exec, "mPlayer") end
local last = nil
local start = GetTotalTime()
ThreadStart(function()
  while GetTotalTime() - start < seconds do
    local p = player()
    local props = p and p.mProps
    local parts = {}
    if props then
      for _, k in ipairs({ "AI Player - Interaction Enable", "AI Player - Interaction Ranged Enable",
          "AI Player - Interaction Current Target", "AI Player - Interaction Current Target Override",
          "AI Player - Interaction Ranged Prompt", "AI Player - Interaction Allow Missed Execute" }) do
        parts[#parts + 1] = k:gsub("AI Player %- Interaction ", "") .. "=" .. tostring(props[k])
      end
      local tname = props["AI Player - Interaction Current Target Override"]
      if not tname or tname == "" then tname = props["AI Player - Interaction Current Target"] end
      local okT, t = pcall(AgentFind, tname or "")
      if okT and t then
        local tp = AgentGetProperties(t)
        for i = 1, 2 do
          local pre = "AI Agent - Player Used Interaction Prompt " .. i
          parts[#parts + 1] = ("P%d=%s/%s/%s"):format(i, tostring(PropertyGet(tp, pre .. " Enable")), tostring(PropertyGet(tp, pre)), tostring(PropertyGet(tp, pre .. " Dialog Node")))
        end
        parts[#parts + 1] = ("d=%.1f busy=%s"):format(VectorDistance(AgentGetWorldPos(t), AgentGetWorldPos(Game_GetPlayer())), tostring(PropertyGet(tp, "AI Agent - Busy")))
      end
    end
    local line = table.concat(parts, " ")
    if line ~= last then
      last = line
      TWDA.log("AI4 " .. line)
    end
    WaitForNextFrame()
    local t0 = GetTotalTime()
    while GetTotalTime() - t0 < 0.2 do WaitForNextFrame() end
  end
  TWDA.log("AI4 done")
end)
return "probing"
