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

local cache = {}
local function internals()
  local start = rawget(G, "Struggle_Start")
  if type(start) ~= "function" then return nil end
  start = TWDA.unwrap(start)
  if cache.start ~= start then
    local monitor = TWDA.upvalue(start, "monitor")
    cache = {
      start = start,
      mode = TWDA.upvalue(start, "mode_Struggle"),
      update = type(monitor) == "function" and TWDA.upvalue(monitor, "update") or nil,
    }
  end
  if type(cache.mode) ~= "table" or type(cache.update) ~= "function" then return nil end
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
  local ok, err = pcall(game.mode.Struggle_Mash, game.mode)
  if not ok then TWDA.log("struggle: mash failed: " .. tostring(err)) end
end

local function pressE(game)
  local fn = game.mode.Struggle_DeathBlow_B
  if TWDA.upvalue(fn, "mDeathBlowButton") ~= "B" then
    -- Not the keyboard's button (a controller is in use); finish the way any button would.
    fn = TWDA.upvalue(fn, "doDeathBlow")
  end
  local ok, err = pcall(fn, game.mode)
  if not ok then TWDA.log("struggle: finish failed: " .. tostring(err)) end
end

local state = nil -- while a struggle lasts: { agent, ready, finished, lastMash, qSince, half, low }

local function startText(mode)
  if mode == "auto" then return "Struggle! Fighting back for you." end
  if mode == "slow" then return "Struggle! Press Q over and over, or hold it down. Then E when told." end
  return "Struggle! Press Q over and over. Then E when told."
end

TWDA.struggleActive = function() return state ~= nil and not state.finished end
TWDA.describeStruggle = function()
  if not (state and not state.finished) then return nil end
  if state.ready then return "Struggle. Press E now!" end
  local pct = math.floor((prop(state.agent, "Chore Scrubber - Percentage Current") or 0) * 100 + 0.5)
  return ("Struggle, %d percent. Press Q over and over."):format(pct)
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
    state = { agent = agent, ready = false, finished = false, lastMash = 0,
      half = (prop(agent, "Chore Scrubber - Percentage Current") or 0) >= 0.5 }
    TWDA.log("struggle: started (" .. TWDA.agentName(agent) .. ")")
    TWDA.lastHint = startText(mode)
    TWDA.say(TWDA.lastHint, { interrupt = true })
  end
  if state.finished then return end
  if prop(agent, "Struggle Finished") == true then
    state.finished = true
    TWDA.log("struggle: finished, won " .. tostring(prop(agent, "Struggle Won")))
    return
  end
  if prop(agent, "Struggle Paused") == true then return end

  local ready = finishReady(game)
  if ready and not state.ready then
    TWDA.log("struggle: finishing move ready")
    TWDA.lastHint = "Struggle. Press E now!"
    if mode ~= "auto" then TWDA.say("E now!", { interrupt = true }) end
  elseif state.ready and not ready then
    TWDA.log("struggle: finishing move missed")
    if mode ~= "auto" then TWDA.say("Too late. Q again!", { interrupt = true }) end
    state.half = false
  end
  state.ready = ready

  if mode == "auto" then
    if ready then
      pressE(game)
    elseif now - state.lastMash >= MASH_INTERVAL then
      state.lastMash = now
      pressQ(game)
    end
    return
  end

  -- Progress, said once each way: halfway up, and slipping back down after that.
  local pct = prop(agent, "Chore Scrubber - Percentage Current") or 0
  if not ready then
    if pct >= 0.5 and not state.half then
      state.half = true
      TWDA.say("Halfway", { interrupt = true })
    elseif pct < 0.25 and state.half then
      state.half = false
      TWDA.say("Faster!", { interrupt = true })
    end
  end

  if mode == "slow" and not ready then
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
