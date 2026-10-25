-- Struggles in Season 1 (the game's mode_struggle.lua): a walker has hold of Lee and the player
-- presses Q again and again to fight it off. The first one is the babysitter in Clementine's house
-- (Episode 1); its checkpoint starts in the middle of the struggle.
--
-- What the game does: Struggle_Start(agent) pushes mode_Struggle (input map struggle.imap: Q is
-- Struggle_Mash, E is Struggle_DeathBlow_B). Each press raises the agent's "Button Mash - Current
-- Percentage", which drains away between presses; the agent's "Chore Scrubber - Percentage
-- Current" follows it and drives the animation. Below 1% for 0.75 s the struggle is lost. At 95%
-- the finishing move is ready (upvalue mDeathBlowReadyStart, or mDeathBlowController when the
-- struggle has a death-blow chore) and E must be pressed within about 2 seconds; missing it pushes
-- the meter back and the pressing starts again. With the keyboard the finishing key is always E
-- (mDeathBlowButton "B"). Struggle_Finish marks the win ("Struggle Won"), and the scene's dialog
-- calls Struggle_End, which clears mStruggleAgent.
--
-- Keys during a struggle are the game's own (Q and E). The actionscenes setting (F11) adds:
--   slow  the game runs slowly (actions.lua), and holding Q down keeps pressing it for you
--   auto  the mod presses Q and E itself
local TWDA = ...
local G = _G

local VK_Q = 0x51
local MASH_INTERVAL = 0.07 -- seconds between the mod's own presses
local HOLD_DELAY = 0.25    -- a Q held this long starts repeating (slow mode)

-- Season 2 (projectseason2's struggle.lua) works the same way with other names: Struggle_Enter(agent)
-- (upvalues mStruggleAgent, mDeathBlowReadyStart, mDeathBlowController), struggle.imap with Q and
-- Enter for Struggle_OnMash and E for Struggle_OnDeathBlowB (which, with the mouse and keyboard,
-- finishes whatever button the struggle asks for), and the properties "Struggle - Complete",
-- "Struggle - Won" and "Struggle - Paused" (the update's kPaused).
-- A New Frontier (projectseason3's struggleqte.lua): StruggleQTE_Enter(agent) (upvalues
-- mStruggleAgent and mDeathBlowReadyStart), Struggle.imap with Q for StruggleQTE_OnMash and E for
-- StruggleQTE_OnDeathBlow, and the agent's "Struggle - Type": "Button" is mashing; "Waggle
-- Horizontal" and "Waggle Vertical" go back and forth on the arrows, "Circle Clockwise" and
-- "Circle Counter Clockwise" round them. "Struggle - Enabled" goes false when it is over.
local KIND_TEXT = {
  ["Waggle Horizontal"] = "press Left and Right arrows in turn, over and over",
  ["Waggle Vertical"] = "press Up and Down arrows in turn, over and over",
  ["Circle Clockwise"] = "press the arrows round in a circle, Up, Right, Down, Left, over and over",
  ["Circle Counter Clockwise"] = "press the arrows round in a circle, Up, Left, Down, Right, over and over",
}

local cache = {}
local function internals()
  local start = rawget(G, "Struggle_Start")
  if type(start) == "function" then
    start = TWDA.unwrap(start)
    if cache.start ~= start then
      local monitor = TWDA.upvalue(start, "monitor")
      cache = {
        start = start,
        mode = TWDA.upvalue(start, "mode_Struggle"),
        update = type(monitor) == "function" and TWDA.upvalue(monitor, "update") or nil,
        finishedKey = "Struggle Finished", wonKey = "Struggle Won", pausedKey = "Struggle Paused",
        mashKeys = "Q",
      }
    end
    if type(cache.mode) ~= "table" or type(cache.update) ~= "function" then return nil end
    return cache
  end
  local enter3 = rawget(G, "StruggleQTE_Enter")
  if type(enter3) == "function" then
    enter3 = TWDA.unwrap(enter3)
    if cache.start ~= enter3 then
      local monitor = TWDA.upvalue(enter3, "MonitorStruggle")
      local update = type(monitor) == "function" and TWDA.upvalue(monitor, "Update") or nil
      cache = {
        start = enter3, season2 = true, season3 = true, update = enter3,
        enabledKey = TWDA.upvalue(enter3, "kEnabled") or "Struggle - Enabled",
        wonKey = TWDA.upvalue(enter3, "kWon") or "Struggle - Won",
        pausedKey = update and TWDA.upvalue(update, "kPaused") or "Struggle - Paused",
        typeKey = TWDA.upvalue(enter3, "kType") or "Struggle - Type",
        mashKeys = "Q",
      }
    end
    return cache
  end
  local enter = rawget(G, "Struggle_Enter")
  if type(enter) ~= "function" then return nil end
  enter = TWDA.unwrap(enter)
  if cache.start ~= enter then
    local monitor = TWDA.upvalue(enter, "Monitor")
    local update = type(monitor) == "function" and TWDA.upvalue(monitor, "Update") or nil
    cache = {
      start = enter, season2 = true,
      update = enter, -- (the ready flags are locals that Struggle_Enter resets, shared with the update)
      finishedKey = TWDA.upvalue(enter, "kComplete") or "Struggle - Complete",
      wonKey = TWDA.upvalue(enter, "kWon") or "Struggle - Won",
      pausedKey = update and TWDA.upvalue(update, "kPaused") or "Struggle - Paused",
      mashKeys = "Q or Enter",
    }
  end
  return cache
end

local function prop(agent, key)
  local ok, value = pcall(AgentGetProperty, agent, key)
  if ok then return value end
  return nil
end

local function finishReady(game)
  return TWDA.upvalue(game.update, "mDeathBlowReadyStart") ~= nil
    or TWDA.upvalue(game.update, "mDeathBlowController") ~= nil
end

local function pressQ(game)
  local ok, err
  if game.season3 then
    ok, err = pcall(StruggleQTE_OnMash, { code = VK_Q, type = 0, controller = -1 })
  elseif game.season2 then
    ok, err = pcall(Struggle_OnMash, {})
  else
    ok, err = pcall(game.mode.Struggle_Mash, game.mode)
  end
  if not ok then TWDA.log("struggle: mash failed: " .. tostring(err)) end
end

local function pressE(game)
  if game.season3 then
    local ok, err = pcall(StruggleQTE_OnDeathBlow, { code = 0x45, type = 0, controller = -1 })
    if not ok then TWDA.log("struggle: finish failed: " .. tostring(err)) end
    return
  end
  if game.season2 then
    local ok, err = pcall(Struggle_OnDeathBlowB, {})
    if not ok then TWDA.log("struggle: finish failed: " .. tostring(err)) end
    return
  end
  local fn = game.mode.Struggle_DeathBlow_B
  if TWDA.upvalue(fn, "mDeathBlowButton") ~= "B" then
    -- Not the keyboard's button (a controller is in use); finish the way any button would.
    fn = TWDA.upvalue(fn, "doDeathBlow")
  end
  local ok, err = pcall(fn, game.mode)
  if not ok then TWDA.log("struggle: finish failed: " .. tostring(err)) end
end

local state = nil -- while a struggle lasts: { agent, ready, finished, lastMash, qSince, half, low }

local function startText(mode, keys, kind)
  if mode == "auto" then return "Struggle! Fighting back for you." end
  if KIND_TEXT[kind] then return "Struggle! " .. KIND_TEXT[kind]:gsub("^%l", string.upper) .. "." end
  if mode == "slow" then return "Struggle! Press Q over and over, or hold it down. Then E when told." end
  return ("Struggle! Press %s over and over. Then E when told."):format(keys or "Q")
end

TWDA.struggleActive = function() return state ~= nil and state.started == true and not state.finished end
TWDA.describeStruggle = function()
  if not (state and state.started and not state.finished) then return nil end
  if state.ready then return "Struggle. Press E now!" end
  local pct = math.floor((state.percent and state.percent() or prop(state.agent, "Chore Scrubber - Percentage Current") or 0) * 100 + 0.5)
  if KIND_TEXT[state.kind] then return ("Struggle, %d percent. %s."):format(pct, KIND_TEXT[state.kind]:gsub("^%l", string.upper)) end
  return ("Struggle, %d percent. Press Q over and over."):format(pct)
end

-- How far the meter is, 0 to 1. (A New Frontier's "Struggle - Current Percentage" goes from 0 to
-- 1, or to its "Struggle - Max Percentage" when that is set.)
local function percentOf(agent, game)
  if game.season3 then
    local current = prop(agent, "Struggle - Current Percentage") or 0
    local max = prop(agent, "Struggle - Max Percentage")
    if type(max) ~= "number" or max <= 0 then max = 1 end
    return current / max
  end
  return prop(agent, "Chore Scrubber - Percentage Current") or 0
end

TWDA.onFrame("struggle", function()
  local game = internals()
  local agent = game and TWDA.upvalue(game.start, "mStruggleAgent")
  if agent == nil then
    if state then
      TWDA.log("struggle: over")
      -- (F6 falls back to the last hint; ours is out of date now.)
      if type(TWDA.lastHint) == "string" and TWDA.lastHint:find("^Struggle") then TWDA.lastHint = nil end
    end
    state = nil
    return
  end
  local mode = TWDA.settings.actionscenes or "slow"
  local now = TWDA.now()
  if not state or state.agent ~= agent then
    -- (A struggle that starts with the meter already half up, struggle_clementine in the RV in
    -- Episode 3, is not "Halfway" yet.)
    local kind = game.typeKey and prop(agent, game.typeKey) or nil
    state = { agent = agent, ready = false, finished = false, lastMash = 0, kind = kind,
      percent = function() return percentOf(agent, game) end,
      half = percentOf(agent, game) >= 0.5 }
    TWDA.log("struggle: set up (" .. TWDA.agentName(agent) .. ", " .. tostring(kind) .. ")")
  end
  if state.finished then return end
  -- (The Final Season sets a struggle up with StruggleQTE_Enter a moment before it starts: "Struggle
  -- - Enabled" is false until then. It is said when it starts, and over once it has run.)
  local enabled = not game.enabledKey or prop(agent, game.enabledKey) == true
  if enabled and not state.started then
    state.started = true
    TWDA.log("struggle: started (" .. TWDA.agentName(agent) .. ", " .. tostring(state.kind) .. ")")
    TWDA.lastHint = startText(mode, game.mashKeys, state.kind)
    TWDA.say(TWDA.lastHint, { interrupt = true })
  end
  if (game.finishedKey and prop(agent, game.finishedKey) == true) or (state.started and not enabled) then
    state.finished = true
    TWDA.log("struggle: finished, won " .. tostring(prop(agent, game.wonKey)))
    return
  end
  if not state.started then return end
  if prop(agent, game.pausedKey) == true then return end

  local ready = finishReady(game)
  if ready and not state.ready then
    TWDA.log("struggle: finishing move ready")
    TWDA.lastHint = "Struggle. Press E now!"
    if mode ~= "auto" then TWDA.say("E now!", { interrupt = true }) end
  elseif state.ready and not ready then
    TWDA.log("struggle: finishing move missed")
    if mode ~= "auto" then TWDA.say("Too late. " .. (game.season2 and "Mash" or "Q") .. " again!", { interrupt = true }) end
    state.half = false
  end
  state.ready = ready

  if mode == "auto" and not KIND_TEXT[state.kind] then
    if ready then
      pressE(game)
    elseif now - state.lastMash >= MASH_INTERVAL then
      state.lastMash = now
      pressQ(game)
    end
    return
  end

  -- Progress, said once each way: halfway up, and slipping back down after that.
  local pct = percentOf(agent, game)
  if not ready then
    if pct >= 0.5 and not state.half then
      state.half = true
      TWDA.say("Halfway", { interrupt = true })
    elseif pct < 0.25 and state.half then
      state.half = false
      TWDA.say("Faster!", { interrupt = true })
    end
  end

  if mode == "slow" and not ready and not KIND_TEXT[state.kind] then
    local ok, down = pcall(InputPCIsVKeyPressed, VK_Q)
    if ok and down == true then
      state.qSince = state.qSince or now
      if now - state.qSince >= HOLD_DELAY and now - state.lastMash >= MASH_INTERVAL then
        state.lastMash = now
        pressQ(game)
      end
    else
      state.qSince = nil
    end
  end
end)
