-- Dev console (Season 2): log calls (WS2 lines) to the gameplay globals that matter for the mod:
-- choices, actions (QTEs), struggles, swipes, drags, peeking, close-ups, death, modes, the reticle
-- and navigation. Each function is logged at most WS2_MAX times (default 40). Stays on for the
-- whole Lua state (until the next scene change).
local max = rawget(_G, "WS2_MAX") or 40
local prefixes = { "Dialog_On", "Dialog_Activate", "Action", "Struggle_", "Swipe_", "Drag_", "Peek_", "CloseUp_",
  "Death", "Inventory_", "Reticle_Enable", "Reticle_Select", "ChoredMovement_", "ButtonMash_", "PanicMeter_",
  "Game_PushMode", "Game_PopMode", "Navigate_Enable", "Navigate_PathTo", "Game_UseAgent", "DirectControl_",
  "Timer", "QTE", "Look_SetFocus", "Callback_" }
local skip = { Dialog_OnAllNodeBegin = true, Dialog_OnAllNodeEnd = true, Dialog_OnRollOn = true, Dialog_OnRollOff = true,
  Action_OnMouseMove = true }
local function brief(v)
  if type(v) == "table" then
    local n = TWDA.agentName(v)
    if n ~= "" then return n end
    return "{table}"
  end
  if type(v) == "string" then return '"' .. v:sub(1, 60) .. '"' end
  return tostring(v)
end
local count, wrapped = {}, 0
local names = {}
for k, v in pairs(_G) do
  if type(k) == "string" and type(v) == "function" and not skip[k] then
    for _, p in ipairs(prefixes) do
      if k:sub(1, #p) == p and not k:find("Node", 1, true) then names[#names + 1] = k break end
    end
  end
end
for _, k in ipairs(names) do
  local original = rawget(_G, k)
  if not TWDA.wrappers[original] or true then
    local wrapper = function(...)
      count[k] = (count[k] or 0) + 1
      if count[k] <= max then
        local args = table.pack(...)
        local parts = {}
        for i = 1, math.min(args.n, 5) do parts[#parts + 1] = brief(args[i]) end
        TWDA.log(("WS2 %s(%s)"):format(k, table.concat(parts, ", ")))
      end
      return original(...)
    end
    rawset(_G, k, wrapper)
    wrapped = wrapped + 1
  end
end

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
