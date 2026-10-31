-- Peeking in Season 1 (the game's mode_peek.lua): in the stealth at the Motor Inn (Episode 1) Lee
-- hides behind cover and W, A, S or D (or the arrows) leans out that way; he stays out until the
-- opposite key brings him back. Peeking too long gets him seen. Things to use can show up while he
-- leans out.
--
-- What the game does: Peek_Start(up, down, left, right) sets one chore per direction on the logic
-- agent "logic_mode_peek" (upvalue kLogicAgentName of Peek_AddDirectionChore; property names in its
-- upvalue kChores, such as "Peek - Chore Left"); no chore means nothing that way. mode_peek's
-- OnDirection marks a direction held on key down and released on key up. The chore names say
-- little ("stealthmission_station1_peekleft.chore"), so the mod names the directions and keys.
-- The game's own hints (on screen, read by uitext.lua) say what a direction is for ("Peek over the
-- wall (W)").
local TWDA = ...
local G = _G

local DIRECTIONS = { { "eUp", "W up", "Up arrow", 1 }, { "eLeft", "A left", "Left arrow", 3 },
  { "eRight", "D right", "Right arrow", 4 }, { "eDown", "S down", "Down arrow", 2 } }

-- Season 2 (projectseason2's peek.lua): Peek_Enter and Peek_Activate, the logic agent "logic_peek"
-- with the same "Peek - Chore Up/Down/Left/Right" (kChores, in that order), and the "Peek" input
-- map (W A S D and the arrows). Besides hiding, it makes some choices: at the river at the end of
-- Episode 1, leaning left or right chooses whom to help, Pete or Nick (camera cam_choice_peteOrNick).
local function season2()
  return type(rawget(G, "Peek_Enter")) == "function" and type(rawget(G, "Peek_AddDirectionChore")) ~= "function"
end

local function active()
  if season2() then
    for _, name in ipairs({ "Peek.imap", "Peek" }) do
      local ok, on = pcall(InputMapperIsActive, name)
      if ok and on == true then return true end
    end
    return false
  end
  local ok, on = pcall(InputMapperIsActive, "mode_peek.imap")
  return ok and on == true
end
TWDA.peekActive = active

local function directions()
  local logic, keys
  if season2() then
    local ui = TWDA.upvalue(rawget(G, "Peek_Activate"), "ActivateUI")
    logic, keys = TWDA.upvalue(ui, "kLogicAgent"), TWDA.upvalue(ui, "kChores")
  else
    local add = TWDA.unwrap(rawget(G, "Peek_AddDirectionChore"))
    logic, keys = TWDA.upvalue(add, "kLogicAgentName"), TWDA.upvalue(add, "kChores")
  end
  if type(logic) ~= "string" or type(keys) ~= "table" then return nil end
  local parts, ways = {}, {}
  for _, d in ipairs(DIRECTIONS) do
    local key = season2() and keys[d[4]] or keys[rawget(G, d[1])]
    local ok, chore = pcall(AgentGetProperty, logic, key)
    if key and ok and chore ~= nil and chore ~= "" then
      parts[#parts + 1] = d[2]
      ways[#ways + 1] = d
    end
  end
  return parts, ways
end

-- For a choice made by leaning (Season 2): the person on each side of the screen. People are named
-- agents in view that are not props (no "obj_", no underscores) and not the player.
local function peopleBySide()
  local player = TWDA.player()
  local okS, agents = pcall(SceneGetAgents, TWDA.playerScene and TWDA.playerScene() or Game_GetScene())
  local left, right
  for _, a in ipairs(okS and type(agents) == "table" and agents or {}) do
    local name = TWDA.agentName(a)
    if a ~= player and name:find("^%u%l+$") and not (pcall(AgentIsHidden, a) and AgentIsHidden(a)) then
      local ok, pos = pcall(AgentGetScreenPos, a)
      if ok and pos and (pos.z or 1) > 0 and pos.x >= 0 and pos.x <= 1 then
        if pos.x < 0.5 and (not left or pos.x < left.x) then left = { name = name, x = pos.x } end
        if pos.x >= 0.5 and (not right or pos.x > right.x) then right = { name = name, x = pos.x } end
      end
    end
  end
  return left and left.name, right and right.name
end

local function choiceCamera()
  local okCam, camera = pcall(function() return SceneGetCamera(TWDA.playerScene and TWDA.playerScene() or Game_GetScene()) end)
  return okCam and camera ~= nil and TWDA.agentName(camera):lower():find("choice", 1, true) ~= nil
end

TWDA.peekDirections = function() return active() and directions() or nil end

TWDA.describePeek = function()
  if not active() then return nil end
  local parts = directions()
  if not parts or #parts == 0 then return nil end
  return "Hiding. To lean out: " .. table.concat(parts, ", ")
end

-- Things that come into view, usable, while Lee leans out (the pillow round the corner) are read out.
local usable, lastCheck = nil, 0
local function announceNewlyUsable()
  local now = TWDA.now()
  if now - lastCheck < 0.3 then return end
  lastCheck = now
  if not (TWDA.hotspots and TWDA.reticleReady and TWDA.reticleReady()) then return end
  local current, fresh = {}, {}
  -- (What is usable from cover the first time counts too: the pharmacy shelves in Macon,
  -- Episode 3, are emptied against the clock from a hiding position.)
  local first = usable == nil
  for _, entry in ipairs(TWDA.hotspots()) do
    -- (Not people to talk to: in the bandit attack at the Motor Inn, Episode 3, Clementine, Duck
    -- and Katjaa are in view from cover, and talking is not what the hiding is for.)
    local verb = tostring(TWDA.hotspotVerb and TWDA.hotspotVerb(entry.agent) or ""):lower()
    if entry.clickable and entry.side == nil and not verb:find("talk", 1, true) then
      current[entry.name] = true
      if first or not usable[entry.name] then fresh[#fresh + 1] = entry end
    end
  end
  usable = current
  if #fresh == 0 then return end
  if TWDA.orderByUrgency then fresh = TWDA.orderByUrgency(fresh) end
  -- What the reticle has landed on goes first, new or not: at the tractor at the dairy, leaning
  -- right lands on the plow lever, which already counted as usable from cover, while the gear
  -- shift that "came into view" cannot be reached.
  local okFocus, focused = pcall(Reticle_GetAgentFocused)
  local focusedName = okFocus and focused ~= nil and TWDA.agentName(focused) or nil
  if focusedName and current[focusedName] then
    for i, entry in ipairs(fresh) do
      if entry.name == focusedName then table.remove(fresh, i) break end
    end
    for _, entry in ipairs(TWDA.hotspots()) do
      if entry.name == focusedName then table.insert(fresh, 1, entry) break end
    end
  end
  local parts = TWDA.offerTexts(fresh, false)
  parts[#parts + 1] = #fresh == 1 and "Enter!" or "Tab to choose, Enter."
  -- (Queued after "Leaning out ..." when that was just said.)
  local recent = TWDA.now() - (TWDA.lastSpokenAt or -10) < 1
  TWDA.say(table.concat(parts, ". "), { interrupt = not recent })
  if TWDA.preferNextTab then TWDA.preferNextTab(fresh[1].name) end
end

-- Leaning out sticks after the key is let go (a tap of W keeps Lee up); the opposite key brings
-- him back. Peek_IsPeeking says whether he is out; the last direction key pressed says which way.
local KEYS = { { 0x57, "up", "S" }, { 0x26, "up", "S" }, { 0x41, "left", "D" }, { 0x25, "left", "D" },
  { 0x44, "right", "A" }, { 0x27, "right", "A" }, { 0x53, "down", "W" }, { 0x28, "down", "W" } }
local held, lastDirection, wasPeeking = {}, nil, false
-- Leaning out can start a hidden timer (the dialog timer_ZombiesSeeLee at the Motor Inn: over the
-- wall at the first cover, to the left at the RV): about five or six seconds later Lee is seen and
-- dies. The game only says "Peek for too long and you will be seen", once, so after RISKY_SECONDS
-- of any lean the mod says to get back.
local RISKY_SECONDS = 3
local peekSince, warned, peekDirection = 0, false, nil

local function trackPeeking()
  for _, k in ipairs(KEYS) do
    local ok, down = pcall(InputPCIsVKeyPressed, k[1])
    down = ok and down == true
    if down and not held[k[1]] then
      lastDirection = k
      -- (A new way out, straight from another, starts the count again.)
      peekSince, warned, peekDirection = TWDA.now(), false, k
    end
    held[k[1]] = down
  end
  local okPeek, peeking = pcall(Peek_IsPeeking)
  peeking = okPeek and peeking == true
  -- (Not with the rifle scope up, sniper.lua: it lowers by itself when its time is up.)
  local scope = TWDA.sniperActive and TWDA.sniperActive()
  if peeking and not warned and not scope and TWDA.now() - peekSince > RISKY_SECONDS then
    warned = true
    local d = lastDirection
    TWDA.say("Get back now" .. (d and (", " .. d[3]) or "") .. "!", { interrupt = true })
  end
  if peeking == wasPeeking then return end
  wasPeeking = peeking
  peekSince, warned = TWDA.now(), false
  if not peeking then peekDirection = nil end
  -- (Moving to the other side with the rifle, sniper.lua, leans out and back by itself.)
  if TWDA.sniperSwitchingSides and TWDA.sniperSwitchingSides() then return end
  if peeking then
    local d = lastDirection
    TWDA.say(d and ("Leaning out " .. d[2] .. ". " .. d[3] .. " to get back") or "Leaning out", { interrupt = true })
  else
    -- (In The Final Season leaning out can lead into a close-up, the stranger in the woods in
    -- Episode 2: she is not back in cover, and lookaround4.lua says what is offered.)
    local okM, mode = pcall(Game_GetMode)
    if okM and type(mode) == "table" and mode.name == "Station" then return end
    TWDA.say("Back in cover", { interrupt = true })
  end
end

local lastKey, inactiveSince = nil, nil
TWDA.onFrame("peek", function()
  if not active() then
    -- (Only a real end of the hiding starts afresh, not a moment's gap while Lee moves.)
    inactiveSince = inactiveSince or TWDA.now()
    if TWDA.now() - inactiveSince > 3 then lastKey, usable, wasPeeking = nil, nil, false end
    return
  end
  inactiveSince = nil
  if season2() then
    -- (Season 2: what comes into view is announced by lookaround2.lua. Leaning sticks after a tap
    -- here too, and peeking too long gets Clementine seen: behind the chair when Carver's people
    -- search the lodge, Episode 2.)
    if not choiceCamera() then trackPeeking() end
    local parts, ways = directions()
    if not parts or #parts == 0 then return end
    local key = table.concat(parts, ", ")
    if key == lastKey then return end
    lastKey = key
    TWDA.log("peek (season 2): " .. key)
    if choiceCamera() then
      local left, right = peopleBySide()
      local said = {}
      for _, d in ipairs(ways) do
        local who = (d[4] == 3 and left) or (d[4] == 4 and right) or nil
        said[#said + 1] = d[3] .. (who and (" towards " .. who) or "")
      end
      TWDA.say("Choose: " .. table.concat(said, ", "), { interrupt = true })
    else
      TWDA.say("To lean out: " .. key)
    end
    return
  end
  trackPeeking()
  announceNewlyUsable()
  local parts = directions()
  if not parts or #parts == 0 then return end
  local key = table.concat(parts, ", ")
  if key == lastKey then return end
  lastKey = key
  TWDA.log("peek: " .. key)
  -- (Moving to the other side with the rifle passes through hiding for a second: "To lean out: A
  -- left" then sent the player, and the test tool, straight back to the first side. sniper.lua
  -- says "Other side." once there.)
  if TWDA.sniperSwitchingSides and TWDA.sniperSwitchingSides() then return end
  -- Queued, so it follows the game's own hint rather than cutting it off.
  TWDA.say("Hiding. To lean out: " .. key)
end)
