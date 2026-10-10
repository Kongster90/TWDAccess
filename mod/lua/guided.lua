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

local function controller()
  local ok, ctrl = pcall(ChoredMovement_GetController)
  return ok and ctrl or nil
end

local function percent()
  local ok, pct = pcall(ChoredMovement_GetTimePercent)
  if ok and type(pct) == "number" then return math.floor(pct * 100 + 0.5) end
  return nil
end

local active, startedAt, told = false, 0, false

-- Which key moves Lee on is not always W: up the dairy farmhouse's stairs it is S. The mod learns
-- it from the player's own key: whichever is held while the path moves forward or back.
local KEYS = { { 0x57, "W", "S" }, { 0x53, "S", "W" }, { 0x41, "A", "D" }, { 0x44, "D", "A" },
  { 0x26, "Up arrow", "Down arrow" }, { 0x28, "Down arrow", "Up arrow" },
  { 0x25, "Left arrow", "Right arrow" }, { 0x27, "Right arrow", "Left arrow" } }
local lastPct, forwardKey, toldBack, toldHalf = nil, nil, false, false
local stuck = nil -- { key, since, told }: a key held that moves nothing
local keyName, keySince = nil, 0 -- the key held now, and since when

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

TWDA.onFrame("guided", function()
  local now = TWDA.now()
  local on = controller() ~= nil
  if on ~= active then
    active, startedAt, told = on, now, false
    lastPct, forwardKey, toldBack, toldHalf, stuck = nil, nil, false, false, nil
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
  local okPct, pct = pcall(ChoredMovement_GetTimePercent)
  pct = okPct and type(pct) == "number" and pct or nil
  local key = heldKey()
  -- (Only a key held a moment counts: a path can creep on by itself as it starts.)
  if key and keyName ~= key[2] then keyName, keySince = key[2], now end
  if not key then keyName = nil end
  if key and now - keySince < 0.25 then key = nil end
  -- A key held for a while that moves nothing (W at the foot of those stairs).
  if key and not forwardKey and pct and lastPct and math.abs(pct - lastPct) <= 0.001 then
    stuck = stuck and stuck.key == key[2] and stuck or { key = key[2], since = now }
    if not stuck.told and now - stuck.since > 1.2 then
      stuck.told = true
      TWDA.say(key[2] .. " does not move Lee here. Try " .. key[3], { interrupt = true })
    end
  elseif not key then
    stuck = nil
  end
  if pct and lastPct and key and math.abs(pct - lastPct) > 0.001 then
    if pct > lastPct then
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
  end
  lastPct = pct
  if told or now - startedAt < HINT_WAIT then return end
  told = true
  if forwardKey then return end -- already said which key goes on
  -- The game's own hint, shown around the start, already says which key.
  if (TWDA.lastHintAt or -10) > startedAt - 3 then return end
  TWDA.say("Guided path. Hold W or S to move along it")
end)
