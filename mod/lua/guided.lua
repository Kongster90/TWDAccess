-- Guided walking in Season 1 (the game's ChoredMovement_*): Lee follows a set path, such as up the
-- Motor Inn's stairs and along its walkway to Irene's door, moved on by holding a movement key.
-- The game usually shows a hint naming the key ("Use the S (back) key to get away!", read by
-- uitext.lua); where it shows none, the mod says how to move. F6 gives how far along Lee is.
--
-- What the game does: ChoredMovement_Start(forwardChore, backwardChore, startTime) starts a path;
-- ChoredMovement_GetController() is nil when none is running; ChoredMovement_GetTimePercent() is
-- how far along it Lee is (0 to 1).
local TWDA = ...

local HINT_WAIT = 1.5 -- seconds to wait for the game's own hint

-- (Season 2's choredmovement.lua has no ChoredMovement_GetController; ChoredMovement_IsActive
-- says the same.)
local function controller()
  if type(rawget(_G, "ChoredMovement_GetController")) ~= "function" then
    local ok, on = pcall(ChoredMovement_IsActive)
    return (ok and on == true) and true or nil
  end
  local ok, ctrl = pcall(ChoredMovement_GetController)
  return ok and ctrl or nil
end

-- How far along, 0 to 1. (A New Frontier has no ChoredMovement_GetTimePercent: its path is the
-- controller ChoredMovement_GetController returns.)
local function fraction()
  local fn = rawget(_G, "ChoredMovement_GetTimePercent")
  if type(fn) == "function" then
    local ok, pct = pcall(fn)
    return ok and type(pct) == "number" and pct or nil
  end
  local okC, ctrl = pcall(ChoredMovement_GetController)
  if not okC or not ctrl then return nil end
  local okT, t = pcall(ControllerGetTime, ctrl)
  local okL, len = pcall(ControllerGetLength, ctrl)
  if okT and okL and type(t) == "number" and type(len) == "number" and len > 0 then return t / len end
  return nil
end

local function percent()
  local pct = fraction()
  if pct then return math.floor(pct * 100 + 0.5) end
  return nil
end

local active, startedAt, told = false, 0, false

-- The Final Season says which way only with an arrow on screen ("HOLD W A S D in the direction of
-- the arrow", pulling buckshot from James's arm, Episode 2). Its choredmovement.lua moves on when
-- the key's direction, seen from the camera, is the path's axis (GetRelativeDirection, an upvalue of
-- OnPostUpdate under ChoredMovement_Start's Activate: 1 for on, -1 for back), so the mod asks it
-- which key that is. It can change with the camera.
local function relativeForward()
  local activate = TWDA.upvalue(rawget(_G, "ChoredMovement_Start"), "Activate")
  local update = activate and TWDA.upvalue(activate, "OnPostUpdate")
  local relative = update and TWDA.upvalue(update, "GetRelativeDirection")
  if type(relative) ~= "function" then return nil end
  -- (A scene can turn the controls round at a stop on the way: dragging Omar from the gate during
  -- the raid, Episode 2, wants D, then A, then D... The move agent's "Chored Movement - Reverse
  -- Controls" says so, and the game's key picture lights the other key.)
  local mover = TWDA.upvalue(rawget(_G, "ChoredMovement_Start"), "mMoveAgent") or TWDA.player()
  local okR, reversed = pcall(AgentGetProperty, mover, "Chored Movement - Reverse Controls")
  local want = (okR and reversed == true) and -1 or 1
  for _, k in ipairs({ { "W", 0, 1 }, { "S", 0, -1 }, { "A", -1, 0 }, { "D", 1, 0 } }) do
    local ok, dir = pcall(relative, Vector(k[2], k[3], 0))
    if ok and dir == want then return k[1] end
  end
  return nil
end
local toldForward, fwdSeen, fwdSince = nil, nil, 0

-- Which key moves Lee on is not always W: up the dairy farmhouse's stairs it is S. The mod learns
-- it from the player's own key: whichever is held while the path moves forward or back.
local KEYS = { { 0x57, "W", "S" }, { 0x53, "S", "W" }, { 0x41, "A", "D" }, { 0x44, "D", "A" },
  { 0x26, "Up arrow", "Down arrow" }, { 0x28, "Down arrow", "Up arrow" },
  { 0x25, "Left arrow", "Right arrow" }, { 0x27, "Right arrow", "Left arrow" } }
local forwardKey, toldBack = nil, false
-- (nil until the path's first position is known: one that starts past halfway, such as the way
-- back down that tower, has no halfway to say.)
local toldHalf = nil
local stuck = false -- a key held that moves nothing, said once per hold
local keyName, keySince = nil, 0 -- the key held now, and since when
-- Where the path was when the held key started to count. Movement is measured from there, not
-- frame to frame: a slow path (the ladder up the chairlift tower in Season 2's Episode 2 takes
-- 30 s) moves less than a hundredth of a percent a frame.
local moveRef = nil -- { key, pct, at }
-- A key already held when the path started: the game moves on key presses (mode_Chored_Move.imap's
-- OnMoveForward), so one held from before moves nothing until it is pressed again (Russell running
-- to the truck in 400 Days, with W still down from walking).
local heldAtStart = nil

-- Whether a hint says which key to use: a key's letter on its own, or a word for one.
local function namesKey(text)
  if text:find("%f[%w][WASDQE]%f[%W]") then return true end
  local lower = text:lower()
  for _, word in ipairs({ "key", "arrow", "shift", "space", "stick" }) do
    if lower:find("%f[%a]" .. word) then return true end
  end
  return false
end

local function heldKey()
  for _, k in ipairs(KEYS) do
    local ok, down = pcall(InputPCIsVKeyPressed, k[1])
    if ok and down == true then return k end
  end
  return nil
end

-- Someone telling Lee to stop while he is on a path: Brenda in the farmhouse kitchen shoots if he
-- is still moving a second after "Stop right there! I mean it!" (the dialog checks
-- ChoredMovement_GetMoveDir). A sighted player sees her aim; with subtitles off (or speaker names
-- only) the line itself is not heard, so the mod says to stop.
local STOP_WORDS = { "stop right there", "don't move", "another step", "freeze", "stop!", "stay back",
  "stay where", "hold it", "don't come", "back off" }
-- After a stop: { talked, since }. Brenda wants talking to (a dialog choice); once that is over and
-- the reticle is back, the mod says to go on.
local halted = nil
local function stop(why)
  -- (One warning can come as a dialog and a line together.)
  if halted and TWDA.now() - halted.since < 2 then return end
  TWDA.log("guided: told to stop (" .. why .. ")")
  TWDA.say("Stop! Let go of " .. (forwardKey or "the keys") .. ".", { interrupt = true })
  halted = { talked = false, since = TWDA.now() }
end

TWDA.onSubtitle = TWDA.onSubtitle or {}
TWDA.onSubtitle.guided = function(_, text)
  -- (Only while Lee is moving: "Just stop!" in the talk that follows is no warning.)
  if not active or not heldKey() then return end
  local lower = text:lower()
  for _, words in ipairs(STOP_WORDS) do
    if lower:find(words, 1, true) then return stop(words) end
  end
end

-- Each of Brenda's warnings starts with this dialog (as the game spells it), whatever she says.
TWDA.hookBefore("Dialog_Play", function(node)
  if active and type(node) == "string" and node:lower():find("showdowntrigger", 1, true) then stop(node) end
end)

TWDA.describeGuided = function()
  if not active then return nil end
  local pct = percent()
  return "Guided path" .. (pct and (", " .. pct .. " percent along") or "")
    .. (forwardKey and (". Hold " .. forwardKey .. " to go on") or ". Hold W or S to move along it")
end

-- Season 2 moves along a path only on the game's own key-down events (Navigate's key handlers call
-- ChoredMovement_SetJoystickDirection), so a key already held when the path starts does nothing.
-- Yet the game says to hold it beforehand: "Hold A to escape!" comes about four seconds before the
-- squeeze between the shelves in the shoe store (Episode 3), and that path is lost after 1.3 s. So
-- while the game has no direction (upvalue mMove is 0) and a movement key is down, the mod passes
-- the key on, and takes it back when the key is let go.
local DIRECTION_OF = { W = { 0, 1 }, ["Up arrow"] = { 0, 1 }, S = { 0, -1 }, ["Down arrow"] = { 0, -1 },
  A = { -1, 0 }, ["Left arrow"] = { -1, 0 }, D = { 1, 0 }, ["Right arrow"] = { 1, 0 } }
local pushed = nil -- the key name the mod passed on
local function pushHeldKey(key)
  local set = rawget(_G, "ChoredMovement_SetJoystickDirection")
  if type(set) ~= "function" then return end -- (Season 1)
  local move = TWDA.upvalue(set, "mMove")
  if move == nil then return end -- (not Season 2's script)
  if key and (move == 0 or move == nil) then
    local d = DIRECTION_OF[key[2]]
    if d and pcall(set, Vector(d[1], d[2], 0)) then
      if pushed ~= key[2] then TWDA.log("guided: passed " .. key[2] .. " on to the path") end
      pushed = key[2]
    end
  elseif not key and pushed then
    pushed = nil
    pcall(set, Vector(0, 0, 0))
  end
end

TWDA.onFrame("guided", function()
  local now = TWDA.now()
  local on = controller() ~= nil
  if on ~= active then
    active, startedAt, told = on, now, false
    local held = on and heldKey()
    heldAtStart = held and held[2] or nil
    forwardKey, toldBack, toldHalf, stuck, moveRef, toldForward = nil, false, nil, false, nil, nil
    TWDA.log("guided: " .. (on and "path started" or "path ended"))
  end
  -- (The path can drop out for a moment when Lee is halted; the stop is kept a while.)
  if halted and not active and now - halted.since > 30 then halted = nil end
  -- A conversation on the path (Lee talking Brenda down): after it, say to go on.
  if active and not halted and TWDA.hasChoices and TWDA.hasChoices() then
    halted = { talked = true, since = now }
  end
  if halted then
    local ready = TWDA.reticleReady and TWDA.reticleReady()
    if TWDA.hasChoices and TWDA.hasChoices() then
      halted.talked, halted.since = true, now
    elseif halted.talked and now - halted.since > 2 and ready then
      -- (Only if the path is still there to go on along.)
      if active then TWDA.say("Go on: hold " .. (forwardKey or "W") .. ".") end
      halted = nil
    elseif not halted.talked and not halted.offered and now - halted.since > 2.5 and ready and TWDA.hotspots then
      -- What can be done standing still (Brenda: Talk To), said again even if said before; looked
      -- for until there is something.
      local here = {}
      for _, entry in ipairs(TWDA.hotspots()) do
        if entry.clickable and entry.side == nil then here[#here + 1] = entry end
      end
      if #here > 0 and TWDA.offerTexts then
        halted.offered = true
        local parts = TWDA.offerTexts(here, false)
        parts[#parts + 1] = #here == 1 and "Enter to do it." or "Tab to choose, Enter."
        TWDA.say(table.concat(parts, ". "))
        if TWDA.preferNextTab then TWDA.preferNextTab(here[1].name) end
      end
    end
  end
  if not active then return end
  -- (400 Days' cornfield runs on a path too; cornfield.lua says what the keys do there.)
  if TWDA.cornfieldRunning and TWDA.cornfieldRunning() then return end
  -- (Said once it has held for half a second outside a cut scene: the camera cuts about while
  -- people talk on the way, the greenhouse roof in Episode 2.)
  local fwd = relativeForward()
  if fwd ~= fwdSeen then fwdSeen, fwdSince = fwd, now end
  local okM, gameMode = pcall(Game_GetMode)
  local cutscene = okM and type(gameMode) == "table" and gameMode.name == "Cutscene"
  if fwd and fwd ~= toldForward and now - fwdSince > 0.5 and not cutscene then
    toldForward, told = fwd, true
    TWDA.log("guided: forward is " .. fwd)
    TWDA.say("Hold " .. fwd .. " to go on", { interrupt = true })
  end
  local pct = fraction()
  if toldHalf == nil and pct then toldHalf = pct >= 0.5 end
  local key = heldKey()
  pushHeldKey(key)
  -- (Only a key held a moment counts: a path can creep on by itself as it starts.)
  if key and keyName ~= key[2] then keyName, keySince = key[2], now end
  if not key then keyName, heldAtStart = nil, nil end
  if key and now - keySince < 0.25 then key = nil end
  if not (key and pct) then
    moveRef, stuck = nil, false
  elseif not moveRef or moveRef.key ~= key[2] then
    moveRef, stuck = { key = key[2], pct = pct, at = now }, false
  end
  local moved = moveRef and (pct - moveRef.pct) or 0
  -- A key held for a while that moves nothing (W at the foot of those stairs).
  if moveRef and not forwardKey and not stuck and math.abs(moved) <= 0.0005 and now - moveRef.at > 1.2 then
    stuck = true
    if heldAtStart == key[2] then
      TWDA.say("Let go of " .. key[2] .. ", then hold it again", { interrupt = true })
    else
      -- (The Final Season knows the way: "Hold S" after a camera cut, not the opposite of the key.)
      local way = relativeForward()
      TWDA.say(key[2] .. " does not move " .. TWDA.playerName() .. " here. " .. (way and ("Hold " .. way) or ("Try " .. key[3])),
        { interrupt = true })
    end
  end
  if moveRef and math.abs(moved) > 0.002 then
    if moved > 0 then
      if not forwardKey then
        forwardKey = key[2]
        -- (Only worth saying where it is not W, or nothing has said it.)
        if key[2] ~= "W" or toldBack then TWDA.say(key[2] .. " goes on along the path") end
      end
      if not toldHalf and pct >= 0.5 then
        toldHalf = true
        TWDA.say("Halfway")
      end
    elseif not toldBack and not forwardKey then
      toldBack = true
      TWDA.say(key[2] .. " goes back. " .. key[3] .. " goes on", { interrupt = true })
    end
    moveRef.pct = pct
  end
  if told then return end
  -- The game's own hint, shown around the start, usually says which key ("Use the S (back) key to
  -- get away!", "Hold A to escape!"). One that names none ("Don't fall behind!" following Jane
  -- through the herd, Episode 4: about seven seconds before she is gone) means the path is
  -- urgent, so the mod says how to move at once.
  local hint = (TWDA.lastHintAt or -10) > startedAt - 5 and TWDA.lastHint or nil
  if type(hint) == "string" and namesKey(hint) then
    told = true
    return
  end
  if not hint and now - startedAt < HINT_WAIT then return end
  told = true
  if forwardKey then return end -- already said which key goes on
  TWDA.say("Guided path. Hold W or S to move along it", { interrupt = hint ~= nil })
end)
