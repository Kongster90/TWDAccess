-- Action scenes in Season 1: danger against the clock, such as the zombie cop crawling at Lee. The
-- game shows its red "panic meter" vignette (ui_panicmeter.scene) for as long as one lasts; fights
-- (the reticle in combat mode), struggles (struggle.lua) and countdowns (timer agents, below) count
-- too.
--
-- Things that become usable are read out as they appear: what can be used from here first, things
-- to do before things to look at, talking last ("Zombie: Hit. Duck: Pull. Kenny: Talk to. Tab to
-- choose, Enter."). The next Tab, or Enter with nothing chosen, goes to the first of them.
--
-- Setting actionscenes (settings.txt, F11 cycles it):
--   normal  the game's own timing.
--   slow    the same, with the game at half speed for the length of the scene. Keys held to move
--           need holding longer in real time; in struggles, holding Q keeps pressing it.
--   auto    the mod uses each thing as it becomes usable, one at a time and through the reticle,
--           with its first action that is not "Look"; it also aims and fires the shotgun
--           (aiming.lua) and fights struggles (struggle.lua). Not while the arrow keys choose a side
--           (turnchoice.lua): whom to help is the player's choice. Holding movement keys is still up
--           to the player. Experimental.
local TWDA = ...

local MODES = { "normal", "slow", "auto" }
local MODE_NAMES = {
  normal = "Action scenes: normal speed",
  slow = "Action scenes: slow motion",
  auto = "Action scenes: automatic",
}
-- An unusual value, so a slow-down left over from before (say, a reload in mid-scene) is
-- recognisable as ours.
local SLOW_SCALE = 0.45
local CHECK_SECONDS = 0.2

-- Countdowns: timed moments run by a timer agent (the game's timer.lua) rather than the panic
-- meter, such as the bear trap in Episode 2 (timer_chop1, 60 s, ends in cs_outOfBullets; then
-- timer_chop2, 30 s, cs_outOfTime). A timer agent counts "Timer Progress" from 0 to 1 over "Timer
-- Length" seconds of game time while "Timer Enabled" (it holds still during dialog choices), then
-- plays its "Timer Dialog on completion". Timers for background chatter have no such scene; a
-- countdown is one whose scene is a cutscene ("cs_..."), or another scene after 5 seconds or more
-- (see below), and whose progress is moving.
local timerAgents, timerScanAt, timerNames = {}, -10, nil
local timerSeen = {} -- agent name -> { progress = last value, movedAt = when it last went up }

local function prop(agent, key)
  local ok, value = pcall(AgentGetProperty, agent, key)
  if ok then return value end
end

local function countdown()
  local now = TWDA.now()
  if now - timerScanAt > 5 then
    timerScanAt, timerAgents = now, {}
    TWDA.trace("countdown scan")
    local okA, agents = pcall(SceneGetAgents, TWDA.playerScene())
    for _, agent in ipairs(okA and type(agents) == "table" and agents or {}) do
      local node = prop(agent, "Timer Dialog on completion")
      local lower = type(node) == "string" and node:lower() or ""
      local length = prop(agent, "Timer Length")
      -- A cutscene ("cs_outOfTime"), or anything else of 5 seconds or more that is no hint or
      -- chatter ("logic_ZombieBeakIntoOffice": the walkers breaking in on the Macon pharmacy; not
      -- timer_KatClemChatter, "idleBanter_katjaa", at Hershel's farm in Episode 1).
      local chatter = false
      for _, word in ipairs({ "hint", "ambient", "chatter", "banter", "idle" }) do
        if lower:find(word, 1, true) or TWDA.agentName(agent):lower():find(word, 1, true) then chatter = true end
      end
      local counts = lower:find("^cs_") or (lower ~= "" and type(length) == "number" and length >= 5 and not chatter)
      -- (A plain logic step counts only when it sounds like danger: "logic_mollyTimerElapsed" at
      -- the auto shop in Crawford, Episode 4, only brings Molly in, and as a countdown it made the
      -- garage door be offered again and again with "Enter!".)
      if counts and lower:find("^logic_") then
        counts = false
        for _, word in ipairs({ "zombie", "walker", "death", "die", "kill", "attack", "break", "eat", "bite", "fail" }) do
          if lower:find(word, 1, true) then counts = true end
        end
      end
      if counts then timerAgents[#timerAgents + 1] = agent end
    end
    local names = {}
    for _, agent in ipairs(timerAgents) do names[#names + 1] = TWDA.agentName(agent) end
    names = table.concat(names, " ")
    if names ~= timerNames then
      timerNames = names
      TWDA.log("countdown timers here: " .. (names ~= "" and names or "none"))
    end
  end
  for _, agent in ipairs(timerAgents) do
    local name = TWDA.agentName(agent)
    local progress = prop(agent, "Timer Progress")
    if type(progress) == "number" then
      local seen = timerSeen[name]
      if not seen or progress ~= seen.progress then
        local moving = seen ~= nil and progress > seen.progress
        local new = { progress = progress, movedAt = moving and now or -10, rate = seen and seen.rate }
        if moving then
          -- How fast it fills, measured over the current run (it holds still between the steps of
          -- the alley chase while Lee pushes the dumpster, opens the manhole ...: a new run).
          new.run = now - seen.movedAt < 0.5 and seen.run or { p = progress, t = now }
          if now - new.run.t >= 0.15 then new.rate = (progress - new.run.p) / (now - new.run.t) end
        end
        timerSeen[name] = new
        seen = new
      end
      local length = prop(agent, "Timer Length")
      if progress > 0 and progress < 1 and now - seen.movedAt < 1 and type(length) == "number"
        and prop(agent, "Timer Enabled") == true and prop(agent, "Timer Looping") ~= true then
        -- The game advances it by frame time times the scene's time scale times "Timer Speed
        -- Multiplier" over the length (timer.lua). But some timers read a length of 0 and still
        -- fill (timer_zombieGroupClosesIn, the alley chase in Savannah, Episode 4: about 29 s in
        -- all, each step announced as "about 1 second"); then the measured rate tells.
        local speed = prop(agent, "Timer Speed Multiplier")
        speed = type(speed) == "number" and speed > 0 and speed or 1
        local okScale, scale = pcall(function() return SceneGetTimeScale(AgentGetScene(agent)) end)
        scale = okScale and type(scale) == "number" and scale > 0 and scale or 1
        local total = length > 0 and length / (speed * scale) or (seen.rate and seen.rate > 0 and 1 / seen.rate) or nil
        return { name = name, left = total and total * (1 - progress), length = total }
      end
    end
  end
  return nil
end
TWDA.countdown = countdown

local function seconds(left)
  -- Rounded to 5 above 10 seconds: "about 60 seconds", not "about 59".
  local n = left > 10 and math.floor(left / 5 + 0.5) * 5 or math.max(1, math.floor(left + 0.5))
  return n == 1 and "1 second" or (n .. " seconds")
end

-- F6.
function TWDA.describeCountdown()
  local current = countdown()
  if current and not current.left then return "Time is running out" end
  return current and ("About " .. seconds(current.left) .. " left") or nil
end

local function inActionScene()
  if TWDA.struggleActive and TWDA.struggleActive() then return true end
  if TWDA.coverWalkActive and TWDA.coverWalkActive() then return true end
  -- Turning towards one side or the other is always against the clock (whom to pull up onto the
  -- train at the end of Episode 3: Omid on the right, "Grab", Christa on the left).
  if TWDA.turnChoiceActive and TWDA.turnChoiceActive() then return true end
  if countdown() then return true end
  -- The reticle in combat mode: a fight, with things to hit.
  local okCombat, combat = pcall(ReticleUI_InCombatMode)
  if okCombat and combat == true then return true end
  -- (The Final Season loads a panic meter scene, never hidden, in its sneaking at the train
  -- station, Episode 1, and slowed Clementine to a crawl; its fights slow down in combat4.lua.)
  if type(rawget(_G, "Useable_GetCount")) == "function" then return false end
  local ok, hidden = pcall(SceneIsHidden, "ui_panicmeter.scene")
  return ok and hidden == false
end
TWDA.inActionScene = inActionScene

local function timeScale()
  local ok, scale = pcall(GetTimeScale)
  if ok and type(scale) == "number" then return scale end
  return 1
end

-- Slow motion is asked for by several modules: action scenes here, and in Season 2 the action
-- prompts (action2.lua) and targets in a fight (lookaround2.lua). The game runs slowly while any of
-- them wants it. (Each module once set the speed itself, and this one put Season 2's back to normal
-- every frame.)
local slowFor = {}
function TWDA.setSlowFor(reason, on)
  slowFor[reason] = on or nil
  local scale = timeScale()
  if next(slowFor) ~= nil and math.abs(scale - 1) < 0.001 then
    pcall(SetTimeScale, SLOW_SCALE)
  elseif next(slowFor) == nil and math.abs(scale - SLOW_SCALE) < 0.001 then
    pcall(SetTimeScale, 1)
  end
end

local function setSlow(on)
  TWDA.setSlowFor("scene", on)
end

local function lookOnly(verb)
  return TWDA.looksOnly and TWDA.looksOnly(verb) or false
end

-- What a hotspot offers now: the actions its use dialog lists, else its verb property. The
-- property can be stale: Danny "Talk To" where the dialog offers "Eviscerate" (the farmhouse barn),
-- the walker in the tractor's way "Pull" where it is now "Kick".
local function currentActions(agent)
  local actions = TWDA.hotspotActions and TWDA.hotspotActions(agent)
  if actions and #actions > 0 then return actions end
  local verb = TWDA.hotspotVerb(agent)
  return verb and { verb } or nil
end

-- A hotspot's one action (the light on the fence at the dairy: "Look At"); nil when it has several.
local function soleVerb(agent)
  local actions = currentActions(agent)
  return actions and #actions == 1 and actions[1] or nil
end

-- What is on offer as words: "Zombie: Examine, Stab", with where it is when sides are wanted, and
-- the same thing twice said once ("Hand, 2 of them: Look At, Chop", the walker on the dairy fence).
function TWDA.offerTexts(entries, withSides)
  local texts, counts = {}, {}
  for _, entry in ipairs(entries) do
    -- (entry.onlyActions: just the actions it has newly gained, the cage door's "Unlock".)
    local actions = entry.onlyActions or currentActions(entry.agent)
    -- With two or more things to do, each with its number key ("Baseball Bat: 1 Look At, 2 Grab,
    -- 3 Kick" at the end of Episode 5), so the choice can be made without Tab.
    if actions and not entry.onlyActions then
      local doing = 0
      for _, action in ipairs(actions) do
        if not lookOnly(action) then doing = doing + 1 end
      end
      if doing >= 2 then
        local numbered = {}
        for i, action in ipairs(actions) do numbered[i] = i .. " " .. tostring(action) end
        actions = numbered
      end
    end
    local name = TWDA.hotspotName(entry.agent)
    local rest = actions and (": " .. table.concat(actions, ", ")) or entry.place and "" or ", several actions"
    -- ("Drive away", not "Away: Drive".)
    if actions and #actions == 1 and TWDA.isAdverbName and TWDA.isAdverbName(name) then
      name, rest = tostring(actions[1]) .. " " .. name:lower(), ""
    end
    if withSides and entry.side then rest = rest .. ", " .. TWDA.sideWords[entry.side] end
    local key = name .. "\0" .. rest
    if counts[key] then
      counts[key].n = counts[key].n + 1
    else
      counts[key] = { name = name, rest = rest, n = 1 }
      texts[#texts + 1] = counts[key]
    end
  end
  local out = {}
  for i, t in ipairs(texts) do
    out[i] = t.n > 1 and (t.name .. ", " .. t.n .. " of them" .. t.rest) or (t.name .. t.rest)
  end
  return out
end

-- What to press for one thing on offer: Enter does its first action that is not looking, which
-- is no help when it offers several (the zombie boy in the attic, Episode 4: "Shoot, Bash,
-- Stomp").
local function enterWords(entry)
  local doing = 0
  for _, action in ipairs(entry.onlyActions or currentActions(entry.agent) or {}) do
    if not lookOnly(action) then doing = doing + 1 end
  end
  return doing > 1 and "A number key to choose, then Enter." or "Enter to do it."
end

-- What was just said aloud, for the order below.
local recentLines = {} -- { text (lower case), at }
TWDA.onSubtitle = TWDA.onSubtitle or {}
TWDA.onSubtitle.actions = function(_, text)
  table.insert(recentLines, 1, { text = tostring(text):lower(), at = TWDA.now() })
  recentLines[6] = nil
end

-- Whether a line said in the last few seconds names it: Lee's "KEYS! NOW!" in the train station
-- (Episode 3), while the cage door is on offer too and only the key from Clementine saves him.
local function mentioned(entry, within)
  local name = TWDA.hotspotName and TWDA.hotspotName(entry.agent) or entry.name
  for _, line in ipairs(recentLines) do
    if TWDA.now() - line.at < (within or 8) then
      for word in tostring(name):lower():gmatch("%a+") do
        if #word >= 3 and line.text:find("%f[%a]" .. word) then return true end
      end
    end
  end
  return false
end

-- Announcement order: what was just named aloud, then what the reticle is already on, then
-- doing things, then moving to another spot ("RV: Move To", the stealth at the Motor Inn), then
-- looking, then talking (Kenny, while Duck needs pulling free). Stable otherwise.
function TWDA.orderByUrgency(entries)
  local okFocus, focused = pcall(Reticle_GetAgentFocused)
  local function rank(entry)
    local verb = soleVerb(entry.agent)
    verb = type(verb) == "string" and verb:lower() or ""
    if verb:find("^talk") then return 3 end
    if lookOnly(verb) then return 2 end
    -- (Only for things to do: people's names are said all the time.)
    if mentioned(entry) then return -2 end
    if okFocus and focused ~= nil and entry.agent == focused then return -1 end
    if verb:find("^move") then return 1 end
    return 0
  end
  local ranked = {}
  for i, entry in ipairs(entries) do ranked[i] = { entry = entry, rank = rank(entry), i = i } end
  table.sort(ranked, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.i < b.i
  end)
  local out = {}
  for i, r in ipairs(ranked) do out[i] = r.entry end
  return out
end

local known = nil -- names of the hotspots usable at the last check, while a scene lasts
local knownSide = nil -- name -> the side it was on at the last check (false: in view)
local lastCheck = 0
local lastCombat = false
local autoQueue = {} -- auto mode: names of hotspots still to use, in the order they appeared
local toldCountdown = nil -- the countdown whose time has been said

TWDA.onFrame("actions", function()
  local mode = TWDA.settings.actionscenes or "slow"
  local active = inActionScene()
  setSlow(active and mode == "slow")
  if not active then
    known, autoQueue, toldCountdown = nil, {}, nil
    return
  end
  local now = TWDA.now()
  if now - lastCheck < CHECK_SECONDS then return end
  lastCheck = now
  if not (TWDA.hotspots and TWDA.reticleReady and TWDA.reticleReady()) then
    -- Whatever is usable once the reticle is back (after a cutscene) is new again: a fight can
    -- offer the same target several times.
    known, autoQueue = nil, {}
    return
  end
  -- (A countdown whose length is still being measured, a fraction of a second: wait for it, so
  -- its time is said with what to do.)
  local measuring = countdown()
  if measuring and not measuring.left and measuring.name ~= toldCountdown then return end

  -- When a fight starts (the reticle goes into combat mode) everything on offer is new again: the
  -- walker just stabbed at the Motor Inn now wants the awl driven in ("Zombie: Stab. Enter!").
  local okCombatNow, combatNow = pcall(ReticleUI_InCombatMode)
  combatNow = okCombatNow and combatNow == true
  if combatNow ~= lastCombat then
    lastCombat = combatNow
    known = nil
  end

  -- New is what was not on offer at the last check, or has just become usable from here.
  local list = TWDA.hotspots()
  local usable, fresh, wasUsable, sideNow = {}, {}, {}, {}
  for _, entry in ipairs(list) do
    usable[entry.name] = entry
    wasUsable[entry.name] = entry.clickable == true
    sideNow[entry.name] = entry.side or false
    -- (Also what has just come into view: turned to with the arrows, the walker on the stairs.)
    local cameIntoView = knownSide and knownSide[entry.name] and entry.side == nil and entry.clickable
      and TWDA.turnChoiceActive and TWDA.turnChoiceActive()
    if known == nil or known[entry.name] == nil or (entry.clickable and not known[entry.name]) or cameIntoView then
      fresh[#fresh + 1] = entry
    end
  end
  known, knownSide = wasUsable, sideNow

  -- What can be used right now comes first and alone (the car in the road to push, not the rest
  -- of the yard). Otherwise things out of view to one side (the shotgun beside Lee at the zombie
  -- cop), and things behind him only when there is nothing else.
  local function pick(test)
    local chosen = {}
    for _, entry in ipairs(fresh) do
      if test(entry) then chosen[#chosen + 1] = entry end
    end
    return chosen
  end
  -- Not places (the stairs: no hotspot, only somewhere to walk to), nor people to talk to who are
  -- out of reach (the whole dining room at the farmhouse, while Lee runs down to Clementine).
  fresh = pick(function(entry)
    if entry.place then return false end
    local verb = soleVerb(entry.agent)
    return entry.clickable or not (type(verb) == "string" and verb:lower():find("^talk"))
  end)
  local first = pick(function(entry) return entry.clickable end)
  -- The game can count things as usable whose marker is just off screen (the tree, the stick and
  -- Ben around the bear trap); with things in view as well, those are left to Tab.
  local inView = pick(function(entry) return entry.clickable and entry.side == nil end)
  if #inView > 0 then first = inView end
  local turning = TWDA.turnChoiceActive and TWDA.turnChoiceActive()
  -- While the arrow keys turn Lee (turnchoice.lua), and in fights, only what is in the current
  -- view counts.
  -- (In a turn choice, something new on a side Lee can turn to comes first, with the arrows to
  -- press: the walker coming down the stairs while Lee pulls at his stuck leg, Crawford, Episode 4.)
  local turnSides = turning and TWDA.turnChoiceSides and TWDA.turnChoiceSides() or {}
  local overThere = turning and pick(function(entry) return entry.side ~= nil and turnSides[entry.side] end) or {}
  if turning or combatNow then fresh = first end
  if #first == 0 then first = pick(function(entry) return entry.side ~= "behind" end) end
  if #first > 0 then fresh = first end
  -- Something to do beats something to look at, and talking comes last (Kenny, while Duck needs
  -- pulling free).
  local doable = pick(function(entry) return not lookOnly(soleVerb(entry.agent)) end)
  if #doable > 0 or combatNow then
    -- (In fights, never anything only to look at.)
    fresh = doable
  else
    -- Only something to look at is new: not worth the time while something to do is still on
    -- offer (zombie David, "Look At", while the walker beside him needs kicking away).
    for _, entry in ipairs(list) do
      if entry.clickable and not lookOnly(soleVerb(entry.agent)) then
        fresh = {}
        break
      end
    end
    -- Nor against the clock: "Hurry ... Chain: Look At. Enter!" once the chain had been pulled and
    -- shot (Vince's bus, 400 Days).
    if measuring then fresh = {} end
  end
  fresh = TWDA.orderByUrgency(fresh)
  if #overThere > 0 then
    for i = #overThere, 1, -1 do table.insert(fresh, 1, overThere[i]) end
  end

  -- While Lee hides behind cover, peek.lua reads out what comes into view (and says when to get
  -- back, so its short timers are not announced either).
  local hiding = TWDA.peekActive and TWDA.peekActive()
  if hiding and mode ~= "auto" then fresh = {} end
  -- A countdown that has just started: how long there is (the game shows no clock).
  local hurry = nil
  local current = not hiding and countdown()
  if current and current.name ~= toldCountdown then
    toldCountdown = current.name
    hurry = current.left and ("Hurry: about " .. seconds(current.left)) or "Hurry"
  end

  -- Walking in moving cover (cover.lua): what is on offer along the way is scenery (the tractor's
  -- gear shift, Mark). When a countdown starts, the nearest thing to do is the news (the walker in
  -- the tractor's way, to kick within 5 seconds; the same hotspot that was pulled a moment ago).
  if TWDA.coverWalkActive and TWDA.coverWalkActive() then
    fresh = {}
    if hurry then
      -- The timer's name often says what it waits for (timer_KickDeath: "Kick"); else nearest.
      local timerName = current.name:lower()
      local function named(entry)
        local verbs = TWDA.hotspotVerb(entry.agent) and { TWDA.hotspotVerb(entry.agent) }
          or TWDA.hotspotActions(entry.agent) or {}
        for _, v in ipairs(verbs) do
          local word = tostring(v):lower():match("^(%a+)")
          if word and #word >= 3 and timerName:find(word, 1, true) then return true end
        end
        return false
      end
      local lee = TWDA.player()
      local okLee, from = pcall(AgentGetWorldPos, lee)
      local best, bestScore = nil, math.huge
      for _, entry in ipairs(list) do
        local verb = soleVerb(entry.agent)
        if entry.clickable and entry.side == nil and not lookOnly(verb)
          and not (type(verb) == "string" and verb:lower():find("^talk")) then
          local okTo, to = pcall(AgentGetWorldPos, entry.agent)
          local okD, d = pcall(VectorDistance, okLee and from or nil, okTo and to or nil)
          local score = (okD and type(d) == "number" and d or 1000) + (named(entry) and 0 or 10000)
          if score < bestScore then best, bestScore = entry, score end
        end
      end
      if best and (named(best) or (current.length and current.length - current.left > 1)) then
        fresh = { best }
      else
        -- (Usable things flicker for a frame as a walk starts: look again, for up to a second.)
        hurry, toldCountdown = nil, nil
      end
    end
  end

  if #fresh > 0 then
    local parts = TWDA.offerTexts(fresh, true)
    if mode == "auto" then
      for _, entry in ipairs(fresh) do
        if not lookOnly(soleVerb(entry.agent)) then autoQueue[#autoQueue + 1] = entry.name end
      end
    end
    -- There is little time: say which key, for things that can be used from here.
    -- Except in a fight while Lee moves along a path ("Press W to back away!" from the two
    -- walkers in the train station, Episode 3): a blow there stops him for a second, and one
    -- thrown before a walker is in reach lets both catch him. The cue is lookaround.lua's "Now!
    -- Enter!" when one comes into reach.
    local okPath, path = pcall(ChoredMovement_GetController)
    local onlyTargets = okPath and path ~= nil and combatNow and TWDA.isFightTarget ~= nil
    for _, entry in ipairs(fresh) do
      if onlyTargets and not TWDA.isFightTarget(entry.agent) then onlyTargets = false end
    end
    -- And one thing with several ways to deal with it says them with their numbers: Enter alone
    -- takes the first, which in the Savannah sewers (Episode 4) is "Shoot" on the walker holding
    -- Lee's leg, where the climbing pick ("Pry") is quiet and the shot brings the rest.
    local numbered = nil
    if #fresh == 1 then
      local choices = {}
      for i, action in ipairs(currentActions(fresh[1].agent) or {}) do
        if not lookOnly(action) then choices[#choices + 1] = i .. " " .. tostring(action) end
      end
      if #choices > 1 then numbered = choices end
    end
    local turnable = turning and fresh[1].side ~= nil and TWDA.turnChoiceSides and TWDA.turnChoiceSides()[fresh[1].side]
    if mode ~= "auto" and turnable then
      -- (Off to one side while a turn choice is up: the arrows turn Lee towards it; the reticle
      -- cannot go there without turning him.)
      parts[#parts + 1] = "Turn with the arrow keys"
    elseif mode ~= "auto" and fresh[1].clickable and onlyTargets then
      parts[#parts + 1] = "Keep moving. Enter only when told"
    elseif mode ~= "auto" and fresh[1].clickable and numbered then
      parts = { TWDA.hotspotName(fresh[1].agent) .. ": " .. table.concat(numbered, ", "), "Pick a number, then Enter!" }
    elseif mode ~= "auto" and fresh[1].clickable then
      parts[#parts + 1] = #fresh == 1 and "Enter!" or "Tab to choose, Enter"
    elseif mode ~= "auto" and turning then
      -- (Out of view while a turn choice is up: the arrow keys bring it into view.)
      parts[#parts + 1] = "Turn with the arrow keys"
    elseif mode ~= "auto" and hurry then
      -- (Out of reach but needed in time: the semi truck to climb in the Crawford auto shop,
      -- Episode 4. Tab goes to it first; Enter walks there and does it.)
      parts[#parts + 1] = "Tab to it, then Enter"
    end
    local body = table.concat(parts, ". ")
    -- The time first, so that what to press comes last.
    local text = hurry and (hurry .. ". " .. body) or body
    hurry = nil
    -- The reticle may have landed on it and read it out a moment ago (lookaround.lua).
    -- Anything else said in the last second (such as "Leaning out up") is let finish; the same
    -- name just read out by the reticle is replaced by this fuller version.
    local recent = now - (TWDA.lastSpokenAt or -10) < 1
    local extends = type(TWDA.lastSpoken) == "string" and body:find(TWDA.lastSpoken, 1, true) == 1
    if not (text == TWDA.lastSpoken and recent) then
      TWDA.say(text, { interrupt = not recent or extends })
    end
    if mode ~= "auto" and TWDA.preferNextTab then TWDA.preferNextTab(fresh[1].name) end
  end
  if hurry then TWDA.say(hurry) end

  -- Against the clock and quiet for a while: say again what can be done here. (Lee's leg stuck on
  -- the stairs in Crawford, Episode 4: between the walkers to shoot, the leg has to be pulled
  -- free, and nothing else says so.)
  local busyOtherwise = (TWDA.coverWalkActive and TWDA.coverWalkActive()) or (TWDA.struggleActive and TWDA.struggleActive())
  if current and mode ~= "auto" and #fresh == 0 and not busyOtherwise and now - (TWDA.lastSpokenAt or -10) > 4 then
    local again = nil
    for _, entry in ipairs(list) do
      if not again and entry.clickable and not lookOnly(soleVerb(entry.agent)) then again = entry end
    end
    if again and turning and again.side ~= nil and TWDA.turnChoiceSides and TWDA.turnChoiceSides()[again.side] then
      again = nil
    end
    if again then
      local text = table.concat(TWDA.offerTexts({ again }, false), ". ") .. ". Enter!"
      TWDA.log("actions: again " .. text)
      TWDA.say(text)
      if TWDA.preferNextTab then TWDA.preferNextTab(again.name) end
    elseif turning and TWDA.describeTurnChoice then
      -- Nothing to do this way: which way there is (look down to the leg again).
      local turn = TWDA.describeTurnChoice()
      if turn then
        TWDA.log("actions: again " .. turn)
        TWDA.say("Nothing to do this way. " .. turn)
      end
    end
  end

  -- Auto mode: one at a time, through the reticle (lookaround.lua), which also turns the camera to
  -- things out of view and picks the first action that is not "Look".
  -- (Not while the arrow keys choose a side: whom to help is the player's choice.)
  if mode == "auto" and TWDA.useWithReticle and not TWDA.reticleBusy() and not turning then
    while #autoQueue > 0 do
      local name = table.remove(autoQueue, 1)
      local entry = usable[name]
      if entry then
        TWDA.log("actions: using " .. name)
        TWDA.useWithReticle(entry.agent)
        break
      end
    end
  end
end)

-- Outside action scenes: where Lee does not walk freely (a fixed view with things to use, such as
-- the woods at the start of Episode 2: "Zombie: Hit"), what is on offer is read out the first time
-- it appears in view, queued after what is being said. Where he walks, Tab and F6 are enough.
local sceneKnown, lastSceneCheck, sceneLeft, readySince = nil, 0, nil, nil
local walkReadySince, walkTold = nil, false
local stateStartedAt = TWDA.now() -- (this module loads once per Lua state, at the scene's start)
local walkKnown = nil -- where Lee walks: the actions each hotspot in view offered when last read
local pendingGain = nil -- { entry, at }: a new action not yet announced
local wasStruggling = false
TWDA.onFrame("sceneoffers", function()
  local now = TWDA.now()
  if now - lastSceneCheck < 0.5 then return end
  lastSceneCheck = now
  -- After a struggle everything on offer is news again: in the Savannah sewers (Episode 4) the
  -- walker beyond the one holding Lee's leg offered "Shoot, Attack" before the struggle and the
  -- same after it, when it had to be dealt with at once, and nothing was said.
  local struggling = TWDA.struggleActive ~= nil and TWDA.struggleActive() == true
  if wasStruggling and not struggling then sceneKnown, walkKnown, walkTold = nil, nil, false end
  wasStruggling = struggling
  local okWalk, walking = pcall(InputMapperIsActive, "Navigate.imap")
  walking = okWalk and walking == true
  local busy = inActionScene() or (TWDA.peekActive and TWDA.peekActive())
    or (TWDA.turnChoiceActive and TWDA.turnChoiceActive())
  -- Where Lee walks, Tab and F6 are enough, except when control comes back with one thing to do
  -- (the Macon pharmacy: "Counter: Jump Over", and seconds before the walkers get in).
  if walking and not busy then
    -- (Not while runto.lua guides a run: "Leland: Yell To. Enter to do it." in the middle of
    -- Bonnie's run, 400 Days, and Enter would yell rather than run.)
    if TWDA.runtoActive and TWDA.runtoActive() then return end
    local ready = TWDA.hotspots and TWDA.reticleReady and TWDA.reticleReady()
    if not ready then
      walkReadySince, walkTold = nil, false
      return
    end
    walkReadySince = walkReadySince or now
    -- Something in view that offers a new action is news too: Omid's "Give Blowtorch To" on the
    -- overpass (Episode 3), the next step once the blowtorch is lit and Lee cannot reach.
    walkKnown = walkKnown or {}
    local gained = nil
    for _, entry in ipairs(TWDA.hotspots()) do
      if entry.clickable and entry.side == nil and not entry.place then
        -- (Against what it offered last time: Omid already offered it when Lee came up with the
        -- blowtorch, lost it while the blowtorch was set down, and offers it again once lit. A
        -- list that cannot be read for a moment is skipped.)
        local actions = TWDA.hotspotActions and TWDA.hotspotActions(entry.agent) or {}
        local seen = walkKnown[entry.name]
        local new = {}
        local set = {}
        for _, action in ipairs(actions) do
          if seen and not seen[tostring(action)] and not lookOnly(action) and not tostring(action):lower():find("^talk") then
            new[#new + 1] = action -- (not "Talk To", which Clementine regains after each smear in Episode 5)
          end
          set[tostring(action)] = true
        end
        if #actions > 0 or not seen then walkKnown[entry.name] = set end
        if #new > 0 and not gained then gained, entry.onlyActions = entry, new end
      end
    end
    -- (Kept until it can be said: the gain usually shows the moment control comes back, as with
    -- the valve wheel in the Savannah sewers, Episode 4, which offers "Pick Up" once turned.)
    -- (Not on the thing Lee has just taken something from: it now offers to put it back, the
    -- valve wheel's "Place Valve" in the sewers.)
    local tookFrom = gained and TWDA.lastUse and TWDA.lastUse.name == gained.name and now - TWDA.lastUse.at < 15
      and TWDA.lastGotAt and TWDA.lastGotAt >= TWDA.lastUse.at
    if gained and not tookFrom then pendingGain = { entry = gained, at = now } end
    if pendingGain and now - pendingGain.at > 10 then pendingGain = nil end
    if pendingGain and walkTold then
      local entry = pendingGain.entry
      pendingGain = nil
      local text = table.concat(TWDA.offerTexts({ entry }, false), ". ") .. ". " .. enterWords(entry)
      TWDA.log("sceneoffers (new action): " .. text)
      TWDA.say(text)
      local index = nil
      for i, action in ipairs(currentActions(entry.agent) or {}) do
        if action == entry.onlyActions[1] then index = i break end
      end
      if TWDA.preferNextTab then TWDA.preferNextTab(entry.name, index) end
    end
    if walkTold or now - walkReadySince < 1 then return end
    walkTold = true
    local here, named = {}, nil
    for _, entry in ipairs(TWDA.hotspots()) do
      local verb = soleVerb(entry.agent)
      local talk = type(verb) == "string" and verb:lower():find("^talk")
      -- (Not the thing just used: the door propped open in the train station, Episode 3, offers
      -- "Open" again, which takes the tool back and shuts it.)
      local justUsed = TWDA.lastUse and TWDA.lastUse.name == entry.name and now - TWDA.lastUse.at < 15
      -- (Nor, just after going through a doorway, the door on this side of it: the classroom
      -- door and the hallway's "Classroom Door" in Crawford, Episode 4, are two hotspots, and
      -- offering each in turn sent Lee back and forth.)
      local function wayThrough(label)
        label = tostring(label or ""):lower()
        for _, word in ipairs({ "door", "exit", "gate", "ladder", "stair", "passage", "hatch", "window" }) do
          if label:find(word, 1, true) then return true end
        end
        return false
      end
      if not justUsed and TWDA.lastUse and now - TWDA.lastUse.at < 15 and wayThrough(TWDA.lastUse.label)
        and wayThrough(TWDA.hotspotName(entry.agent)) then
        justUsed = true
      end
      -- (A door that changes the scene starts a new Lua state, where the door just used is
      -- unknown: in the first 20 seconds of a scene, no way through is offered. The nurse's office
      -- and the hallway in Crawford, Episode 4: "Nurse's Office: Enter" and "Hallway Door: Use"
      -- offered in turn, and the game crashed during one of the quick scene changes.)
      if not justUsed and now - stateStartedAt < 20 then
        local label = tostring(TWDA.hotspotName(entry.agent) or ""):lower()
        if wayThrough(label) or label:find("office", 1, true) or label:find("room", 1, true) then justUsed = true end
      end
      if entry.clickable and entry.side == nil and not lookOnly(verb) and not talk and not justUsed then
        here[#here + 1] = entry
      end
      -- (Something a line has just asked for: "Check through the window", says Nate in the truck
      -- stop, 400 Days, and the window is the way on but out of Russell's reach. With subtitles
      -- read as the speaker's name only, nothing else says so.)
      if not named and not entry.place and not talk and not justUsed and mentioned(entry, 20) then named = entry end
    end
    if #here ~= 1 and named then
      local text = table.concat(TWDA.offerTexts({ named }, true), ". ")
        .. (named.clickable and (". " .. enterWords(named)) or ". Enter walks there.")
      TWDA.log("sceneoffers (walking, named): " .. text)
      TWDA.say(text, { interrupt = true })
      if TWDA.preferNextTab then TWDA.preferNextTab(named.name) end
    elseif #here == 1 then
      -- (Shooting or killing is never pressed on the player where Lee walks freely: the walkers
      -- in the barricade on River Street, Episode 4, are better left alone.)
      local violent = false
      for _, action in ipairs(currentActions(here[1].agent) or {}) do
        local a = tostring(action):lower()
        if a:find("shoot") or a:find("kill") then violent = true end
      end
      local text = table.concat(TWDA.offerTexts(here, false), ". ") .. (violent and "." or (". " .. enterWords(here[1])))
      TWDA.log("sceneoffers (walking): " .. text)
      TWDA.say(text, { interrupt = true })
      if TWDA.preferNextTab and not violent then TWDA.preferNextTab(here[1].name) end
      -- (Its numbers still mean it: "3" then Enter bashes the boy in the attic, Episode 4.)
      if violent and TWDA.numbersMean then TWDA.numbersMean(here[1].name) end
      -- (Its new action has just been read out with the rest.)
      if pendingGain and pendingGain.entry.name == here[1].name then pendingGain = nil end
    end
    return
  end
  walkReadySince, walkTold = nil, false
  busy = busy or walking
  if busy then
    readySince = nil
    -- (Forget the scene only after a while: a cutscene in between does not make it new.)
    sceneLeft = sceneLeft or now
    if now - sceneLeft > 20 then sceneKnown = nil end
    return
  end
  if not (TWDA.hotspots and TWDA.reticleReady and TWDA.reticleReady()) then
    readySince = nil
    return
  end
  sceneLeft = nil
  -- Wait a moment once the player has control: a countdown starting with it makes this an action
  -- scene, announced with its keys and time above.
  readySince = readySince or now
  if now - readySince < 1 then return end
  -- (Not while the mod turns a view to its far end: what passes by on the way is not news, and
  -- what is in view at the end is told then.)
  if TWDA.turningView and TWDA.turningView() then return end
  sceneKnown = sceneKnown or {}
  local fresh = {}
  local list = TWDA.hotspots()
  for _, entry in ipairs(list) do
    if entry.clickable and entry.side == nil then
      -- New, or offering an action it did not offer before: the cage door in the train station
      -- (Episode 3) once Lee has the key from Clementine, with a walker coming.
      local actions = TWDA.hotspotActions and TWDA.hotspotActions(entry.agent) or {}
      -- Then, unlocked, it offers only "Open": a change of any kind is news. (An action list that
      -- cannot be read for a moment is not a change.)
      local seen = sceneKnown[entry.name]
      local gained = seen == nil
      if seen ~= nil and #actions > 0 then
        local new, set, changed = {}, {}, false
        for _, action in ipairs(actions) do
          set[tostring(action)] = true
          if not seen[tostring(action)] then new[#new + 1] = action end
        end
        for action in pairs(seen) do
          if not set[action] then changed = true end
        end
        -- (Lost actions only count on the thing just used: the next step with it. Elsewhere a
        -- look that drops "Look At" would be read out again.)
        local justUsed = TWDA.lastUse and TWDA.lastUse.name == entry.name and now - TWDA.lastUse.at < 10
        if #new > 0 then gained, entry.onlyActions = true, new
        elseif changed and justUsed then gained = true end
      end
      if seen == nil or #actions > 0 then
        local set = {}
        for _, action in ipairs(actions) do set[tostring(action)] = true end
        sceneKnown[entry.name] = set
      end
      if gained then fresh[#fresh + 1] = entry end
    end
  end
  if #fresh == 0 then return end
  fresh = TWDA.orderByUrgency(fresh)
  local parts = TWDA.offerTexts(fresh, false)
  -- A hint that has just asked for this ("Grab the gun!!" and "Rifle: Grab" in the farmhouse barn,
  -- with seconds to act): say the key, at once.
  local verb = fresh[1].onlyActions and #fresh[1].onlyActions == 1 and fresh[1].onlyActions[1] or soleVerb(fresh[1].agent)
  local word = type(verb) == "string" and verb:lower():match("^(%a+)")
  local asked = word and #word >= 3 and type(TWDA.lastHint) == "string" and now - (TWDA.lastHintAt or -10) < 5
    and TWDA.lastHint:lower():find(word, 1, true) ~= nil
  -- Everything that can be done from here now, not only what is new: with Danny's fate to choose
  -- ("Danny: Kill", "Danny: Spare"), one of them must not be pressed on the player.
  local doable = 0
  for _, entry in ipairs(list) do
    if entry.clickable and entry.side == nil and not lookOnly(soleVerb(entry.agent)) then doable = doable + 1 end
  end
  if asked then
    parts[#parts + 1] = doable <= 1 and "Enter!" or "Tab to choose, Enter"
  elseif not lookOnly(verb) then
    -- (Sometimes with only seconds to act and no hint: Danny, rifle in hand, in the barn.)
    parts[#parts + 1] = doable <= 1 and enterWords(fresh[1]) or "Tab to choose, Enter."
  end
  TWDA.log("sceneoffers: " .. table.concat(parts, ". "))
  TWDA.say(table.concat(parts, ". "), { interrupt = asked or nil })
  -- Enter then does the newly gained action, not the hotspot's first one ("Open" on the cage door).
  local actionIndex = nil
  if fresh[1].onlyActions then
    for i, action in ipairs(currentActions(fresh[1].agent) or {}) do
      if action == fresh[1].onlyActions[1] then actionIndex = i break end
    end
  end
  if TWDA.preferNextTab then TWDA.preferNextTab(fresh[1].name, actionIndex) end
end)

-- F11.
function TWDA.cycleActionScenes()
  local current = TWDA.settings.actionscenes or "slow"
  local nextMode = MODES[1]
  for i, mode in ipairs(MODES) do
    if mode == current then nextMode = MODES[i % #MODES + 1] end
  end
  TWDA.settings.actionscenes = nextMode
  TWDA.saveSettings()
  TWDA.say(MODE_NAMES[nextMode], { interrupt = true })
end
