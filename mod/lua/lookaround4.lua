-- Things to interact with in The Final Season (projectseason4's useable.lua, crosshair.lua and
-- station.lua: a newer framework again).
--
-- The game keeps the things that can be used now in useable.lua's local mCurrentUseables (an
-- upvalue of Useable_GetCount) and picks one by where the camera or the mouse points
-- (mSelectedUseable); its token over the thing shows "Give Magazine" with the F key, and F or Enter
-- (Useable.imap: Useable_OnButtonUse) runs Navigate_PathToAndUseAgent(thing, Game_GetUseNodeName).
-- A token's words are its verb ("Useable - Verb Node", in the scene's dialog or "ui_text") and the
-- noun (Game_GetNounText). The input map finds Useable_OnButtonUse by name, so the mod wraps it:
-- what Tab chose is used instead of what the camera points at.
--
-- Keys: Tab and Shift+Tab go through the things ("Give Toy, 2 of 3"); Enter or F does it; F6 lists
-- them; Backspace steps back out of a close-up (a station: AJ's seat in the car).
local TWDA = ...
local G = _G

local function call(name, ...)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

local function isSeason4()
  return type(rawget(G, "Useable_GetCount")) == "function" and type(rawget(G, "Useable_OnButtonUse")) == "function"
end

local function prop(agent, name)
  local ok, value = pcall(AgentGetProperty, agent, name)
  if ok then return value end
  return nil
end

local function modeName()
  local mode = call("Game_GetMode")
  return type(mode) == "table" and rawget(mode, "name") or nil
end

local function playMode()
  local mode = call("Game_GetMode")
  return type(mode) == "table" and rawget(mode, "bPlayMode") == true
end

local function current()
  local list = TWDA.upvalue(rawget(G, "Useable_GetCount"), "mCurrentUseables")
  local out = {}
  for _, agent in ipairs(type(list) == "table" and list or {}) do
    if type(agent) == "table" and call("AgentIsHidden", agent) ~= true then out[#out + 1] = agent end
  end
  return out
end

local function gameSelected()
  return TWDA.upvalue(TWDA.unwrap(rawget(G, "Useable_OnButtonUse")), "mSelectedUseable")
end

local function dialogText(node)
  if type(node) ~= "string" or node == "" then return nil end
  local scene = TWDA.upvalue(rawget(G, "Game_GetNounText"), "mDialogScene")
  local text = scene and call("Dialog_GetText", scene, node) or nil
  if not text or text == "" then text = call("Dialog_GetText", "ui_text", node) end
  if not text or text == "" then return nil end
  return TWDA.cleanText(text)
end

-- "Give Magazine": the token's own words, as the game puts them together.
-- (Without a verb node, "Useable - Verb Preset" names a stock verb, "Grab", "Pick Up" or "Look At";
-- the game shows its "verb_grab" text.)
local function presetVerb(agent)
  local preset = prop(agent, "Useable - Verb Preset")
  if type(preset) ~= "string" or preset == "" then return nil end
  local camel = preset:lower():gsub(" (%l)", string.upper)
  return dialogText("verb_" .. camel) or dialogText("verb_" .. preset:lower():gsub(" ", "")) or preset
end

local function nameOf(agent)
  local ownVerb = dialogText(prop(agent, "Useable - Verb Node"))
  local verb = ownVerb or presetVerb(agent)
  local noun = call("Game_GetNounText", agent)
  noun = (type(noun) == "string" and noun ~= "") and TWDA.cleanText(noun) or nil
  -- (With no noun the game shows its own verb alone: Abel's cigarette, Episode 3, "Let Him Smoke",
  -- "Burn Him" and "Stub Out Cigarette" on obj_logicalAbel, obj_logicalAbelCheek and
  -- obj_logicalDeskBasement. A state, the gate traps' "No walker in range", still needs the name.)
  if not noun and ownVerb and not ownVerb:find("^[Nn]o ") then
    return TWDA.normalCaps((ownVerb:gsub("^%l", string.upper):gsub("%.$", "")))
  end
  if not noun then
    -- ("obj_logicalTrapBoulderA" -> "Trap boulder A")
    local name = TWDA.agentName(agent):gsub("^obj_", ""):gsub("^logical", ""):gsub("([%l])(%u)", "%1 %2")
    name = name:gsub("_", " "):gsub("^%s+", ""):lower():gsub(" (%a)$", function(c) return " " .. c:upper() end)
    noun = name:gsub("^%l", string.upper)
  end
  -- (A "verb" that is a state, the gate traps' "No walker in range", follows the noun.)
  local _, words = (verb or ""):gsub("%S+", "")
  -- (One that names the thing itself is said alone: planning the school's defenses, Episode 2,
  -- "Walls01" offers "fortify the Walls".)
  local base = noun:gsub("%d+$", ""):gsub("%s+$", ""):lower()
  if verb and words >= 3 and base ~= "" and verb:lower():find(base, 1, true) then
    return TWDA.normalCaps((verb:gsub("^%l", string.upper):gsub("%.$", "")))
  end
  -- (One ending in a preposition goes before it: the river at night, Episode 3, "Smear Guts On" Louis.)
  local last = verb and verb:match("(%a+)%.?$")
  local prepositions = { on = true, at = true, to = true, with = true, ["in"] = true, into = true, onto = true,
    from = true, ["for"] = true, off = true, up = true, over = true, down = true, about = true }
  if verb and words >= 3 and not (last and prepositions[last:lower()]) then
    return TWDA.normalCaps(noun .. ", " .. verb:gsub("^%u", string.lower):gsub("%.$", ""))
  end
  local text = verb and (verb .. " " .. noun) or noun
  return TWDA.normalCaps(text)
end

-- (A story choice made by using a thing has "Useable - Type" Choice; the game marks its token, and
-- a tutorial notice says to think before taking one: "a thing marked choice", text.lua.)
local function labelOf(agent)
  local label = nameOf(agent)
  if prop(agent, "Useable - Type") == "Choice" then return label .. ", choice" end
  return label
end

local function playerPos()
  local player = TWDA.player()
  if player == nil then return nil end
  local ok, pos = pcall(AgentGetWorldPos, player)
  return ok and pos or nil
end

local function distanceTo(agent, from)
  from = from or playerPos()
  local okPos, to = pcall(AgentGetWorldPos, agent)
  if not from or not okPos or not to then return nil end
  local ok, d = pcall(VectorDistance, from, to)
  if ok and type(d) == "number" then return d end
  return nil
end

local function sideOf(agent)
  local ok, pos = pcall(AgentGetScreenPos, agent)
  if not ok or not pos then return nil end
  if (pos.z or 1) <= 0 then return "behind you" end
  if pos.x < 0 then return "to your left" end
  if pos.x > 1 then return "to your right" end
  if pos.y < 0 then return "above you" end
  if pos.y > 1 then return "below you" end
  return nil
end

local function station()
  return modeName() == "Station"
end

-- The things to interact with, in view first, nearest first, with names told apart.
local function hotspots()
  local list = {}
  local from = playerPos()
  local closeUp = station()
  for _, agent in ipairs(current()) do
    list[#list + 1] = { agent = agent, name = labelOf(agent), distance = (not closeUp) and distanceTo(agent, from) or nil,
      side = (not closeUp) and sideOf(agent) or nil }
  end
  table.sort(list, function(a, b)
    if (a.side == nil) ~= (b.side == nil) then return a.side == nil end
    if a.distance and b.distance and math.abs(a.distance - b.distance) > 0.01 then return a.distance < b.distance end
    return TWDA.agentName(a.agent) < TWDA.agentName(b.agent)
  end)
  local alike = {}
  for _, h in ipairs(list) do
    alike[h.name] = alike[h.name] or {}
    table.insert(alike[h.name], h)
  end
  for name, group in pairs(alike) do
    if #group > 1 then
      table.sort(group, function(a, b) return TWDA.agentName(a.agent) < TWDA.agentName(b.agent) end)
      for i, h in ipairs(group) do h.label = name .. " " .. i end
    else
      group[1].label = name
    end
  end
  return list
end

local function whereText(h)
  local parts = {}
  if h.side then parts[#parts + 1] = h.side end
  if h.distance then
    local m = math.floor(h.distance + 0.5)
    parts[#parts + 1] = m <= 1 and "close by" or (m .. " meters")
  end
  return table.concat(parts, ", ")
end

local function speak(text)
  TWDA.say(text, { interrupt = true })
end

-- What Tab chose ({ agent, label, place }), kept on TWDA so that a copy of this module loaded again
-- from the dev console shares it with the copy the game's key map still calls.
local state = TWDA.lookaround4State or {}
TWDA.lookaround4State = state
local lastTabSet = nil

local function canWalk()
  local okMap, walking = pcall(InputMapperIsActive, "Navigate.imap")
  return okMap and walking == true and call("Navigate_IsEnabled") == true and call("ChoredMovement_IsActive") ~= true
end

-- Places to walk to: the story spots that start what comes next (lookaround2.lua finds them).
local function places()
  if not canWalk() or not TWDA.walkPlaces then return {} end
  local ok, list = pcall(TWDA.walkPlaces)
  return ok and type(list) == "table" and list or {}
end

-- Tab's list: the things to interact with, then the places to walk to.
local function entries()
  local list = hotspots()
  for _, p in ipairs(places()) do list[#list + 1] = p end
  -- (Walkers, to walk up to: combat4.lua.)
  if canWalk() and TWDA.walkerTargets then
    for _, w in ipairs(TWDA.walkerTargets()) do list[#list + 1] = w end
  end
  return list
end

-- For beacons.lua: Tab's list with a kind ("thing", "place" or "walker") and a point in the world,
-- in free play only. (The other seasons' lists: lookaround.lua and lookaround2.lua.)
local previousBeacons = TWDA.beaconEntries
function TWDA.beaconEntries()
  if not isSeason4() then return previousBeacons and previousBeacons() or {} end
  if not playMode() or not canWalk() or station() then return {} end
  local list = {}
  for _, h in ipairs(entries()) do
    local kind = h.place and (h.stopWhen and "walker" or "place") or "thing"
    local point = (kind == "place" and h.target) or call("AgentGetWorldPos", h.agent)
    if point then
      list[#list + 1] = { agent = h.agent, label = h.label or h.name, kind = kind, point = point,
        chosen = state.chosen ~= nil and state.chosen.agent == h.agent }
    end
  end
  return list
end

local function entryText(h)
  if h.place and h.stopAt then return h.label .. ", walk up to it" end
  return h.place and ("Place: " .. h.label) or h.label
end

local function cycle(delta)
  local list = entries()
  if #list == 0 then
    speak("Nothing to interact with here.")
    return
  end
  local names = {}
  for _, h in ipairs(list) do names[#names + 1] = TWDA.agentName(h.agent) end
  table.sort(names)
  local set = table.concat(names, ",")
  if set ~= lastTabSet then state.chosen, lastTabSet = nil, set end
  local index = 0
  for i, h in ipairs(list) do
    if state.chosen and h.agent == state.chosen.agent then index = i end
  end
  index = index + delta
  if index < 1 then index = #list elseif index > #list then index = 1 end
  local h = list[index]
  state.chosen = { agent = h.agent, label = h.label, place = h.place }
  local where = whereText(h)
  speak(("%s%s, %d of %d"):format(entryText(h), where ~= "" and (", " .. where) or "", index, #list))
end

local function findChosen()
  if not state.chosen then return nil end
  for _, h in ipairs(entries()) do
    if h.agent == state.chosen.agent then return h end
  end
  return nil
end

local busyUntil = 0
local usedAgent = nil -- the agent Game_UseAgent was last called with
TWDA.hookBefore("Game_UseAgent", function(agent) usedAgent = agent end)

-- (Navigate_PathToAndUseAgent gives up at once, without a word, when the engine's path-finding
-- finds no way to the thing: the spear on the shack's rack, The Final Season. Then the mod walks her
-- up to it by steering, lookaround2.lua, and uses it from there, where the path is nothing.)
local use
local function walkUpAndUse(agent, label, retried)
  local okP, pos = pcall(AgentGetWorldPos, agent)
  local here = TWDA.player() and AgentGetWorldPos(TWDA.player())
  if retried or not (okP and pos and here and TWDA.walkTo) then
    speak(("Can't get to %s from here."):format(label))
    return
  end
  local okWB, walkBoxes = pcall(PathAgentGetWalkBoxes, TWDA.player())
  local okG, ground = false, nil
  if okWB then okG, ground = pcall(WalkBoxesPosOnWalkBoxes, pos, walkBoxes) end
  local target = (okG and ground) or Vector(pos.x, here.y, pos.z)
  TWDA.log("lookaround4: walking up to " .. TWDA.agentName(agent))
  TWDA.walkTo({ agent = agent, place = true, label = label, target = target, distance = VectorDistance(here, target),
    stopAt = 0.8, onArrive = function() use(agent, label, true) end })
end

use = function(agent, label, retried)
  busyUntil = TWDA.now() + 0.8
  state.chosen = nil
  TWDA.log("lookaround4: using " .. TWDA.agentName(agent) .. " (" .. tostring(label) .. ")")
  local ok, err = pcall(ThreadStart, function()
    usedAgent = nil
    local okUse, errUse = pcall(function() Navigate_PathToAndUseAgent(agent, Game_GetUseNodeName(agent)) end)
    if not okUse then TWDA.log("lookaround4: use failed: " .. tostring(errUse)) end
    -- (No use at all, whether or not she moved a little first, while she can still play.)
    if okUse and usedAgent == nil and playMode() and canWalk() then
      TWDA.log("lookaround4: no way to " .. TWDA.agentName(agent))
      walkUpAndUse(agent, label, retried)
    end
  end)
  if not ok then TWDA.log("lookaround4: " .. tostring(err)) end
end

-- Enter or F: what Tab chose (a thing, used from wherever it is, as Clementine walks there by
-- herself; or a place, walked to), else the one thing on offer, else what the game points at.
local function enter(fromGame)
  if TWDA.now() < busyUntil then return true end
  if TWDA.qteTargetUp and TWDA.qteTargetUp() then return true end -- (qte3.lua's Enter)
  if TWDA.describeShooter and TWDA.describeShooter() then return true end -- (shooter4.lua's)
  local h = findChosen()
  if h and h.place then
    state.chosen = nil
    busyUntil = TWDA.now() + 0.8
    -- (Many story spots are thin lines across the way, "trigger_dialog_ajWarning": the walk aims
    -- a meter past the middle, so that it crosses the line; a scene starting ends it.)
    if not h.stopAt and h.target then
      local here = TWDA.player() and AgentGetWorldPos(TWDA.player())
      local dx, dz = here and (h.target.x - here.x) or 0, here and (h.target.z - here.z) or 0
      local d = math.sqrt(dx * dx + dz * dz)
      if d > 1 then
        local beyond = Vector(h.target.x + dx / d, h.target.y, h.target.z + dz / d)
        local okWB, walkBoxes = pcall(PathAgentGetWalkBoxes, TWDA.player())
        local okG, ground = false, nil
        if okWB then okG, ground = pcall(WalkBoxesPosOnWalkBoxes, beyond, walkBoxes) end
        if okG and ground and math.abs(ground.x - beyond.x) + math.abs(ground.z - beyond.z) < 0.5 then
          h.target = ground
          h.stopAt = 0.4
        end
      end
    end
    TWDA.walkTo(h)
    return true
  end
  if h then
    use(h.agent, h.label)
    return true
  end
  state.chosen = nil
  local list = hotspots()
  if #list == 1 then
    use(list[1].agent, list[1].label)
    return true
  end
  if fromGame and gameSelected() ~= nil then return false end -- (the game's own use)
  if #list == 0 then
    speak(#places() > 0 and "Nothing to interact with here. Tab for places to walk to." or "Nothing to interact with here.")
  else
    speak("Nothing chosen. Tab to choose something.")
  end
  return true
end

-- The game's F and Enter. (Unlike the mod's other hooks, this one can stand in for the game's
-- function: the use the mod makes replaces the game's.)
local lastUseFrame = nil
TWDA.hookGlobal("Useable_OnButtonUse", function(original)
  return function(event, ...)
    local okF, frame = pcall(GetFrameNumber)
    if okF and frame == lastUseFrame then return end -- (two bindings of one key, one frame)
    lastUseFrame = okF and frame or nil
    local okE, handled = pcall(enter, true)
    if not okE then TWDA.log("lookaround4: " .. tostring(handled)) end
    if okE and handled then return end
    return original(event, ...)
  end
end)

-- While hiding, Enter is the peek's own (Peek_OnSelect runs the lean's "Peek - Selected Dialog").
-- With none set and something offered, Enter uses that: leaning out from behind the tree in the
-- woods, Episode 2, opens a close-up with "Look At Stranger" and Enter did nothing.
TWDA.hookGlobal("Peek_OnSelect", function(original)
  return function(event, ...)
    local run = TWDA.upvalue(original, "RunSelectedDialog")
    local logic, key = TWDA.upvalue(run, "kLogicAgent"), TWDA.upvalue(run, "kSelectedDialog")
    local okS, selected = pcall(AgentGetProperty, logic, key)
    if isSeason4() and (type(event) ~= "table" or event.agent == nil)
        and (not okS or selected == nil or selected == "") and #hotspots() > 0 then
      local okE, handled = pcall(enter, true)
      if not okE then TWDA.log("lookaround4: " .. tostring(handled)) end
      if okE and handled then return end
    end
    return original(event, ...)
  end
end)

-- F6.
local previousDescribe = TWDA.describeLookaround
TWDA.describeLookaround = function()
  if not isSeason4() or not playMode() then return previousDescribe and previousDescribe() or nil end
  local list = hotspots()
  local walkTo = places()
  local sentences = {}
  if station() then sentences[#sentences + 1] = "Close-up" end
  local walkingTo = TWDA.walkingTo and TWDA.walkingTo()
  if walkingTo then sentences[#sentences + 1] = "Walking to " .. walkingTo end
  local parts = {}
  for _, h in ipairs(list) do
    local where = whereText(h)
    parts[#parts + 1] = h.label .. (where ~= "" and (" (" .. where .. ")") or "")
  end
  sentences[#sentences + 1] = #list == 0 and "Nothing to interact with here"
    or ("%d to interact with: %s"):format(#list, table.concat(parts, ", "))
  if #walkTo > 0 then
    local names = {}
    for _, p in ipairs(walkTo) do names[#names + 1] = ("%s (%s)"):format(p.label, whereText(p)) end
    sentences[#sentences + 1] = "Places to walk to: " .. table.concat(names, ", ")
  end
  if #list + #walkTo > 0 then sentences[#sentences + 1] = "Tab and Enter to use" end
  return TWDA.joinSentences(sentences)
end

-- When the player gets control, or what is on offer changes while they have it, say it once (when
-- it has settled).
local wasPlay, settleFrom, checkPending = false, 0, false
local lastNames, namesCheckedAt, lastSignature = nil, 0, nil
local wasWalk = false
local outSince, forceNext = nil, false
-- (A scene dialog named a timer runs out on her: the barn, Episode 4, "amb_closeDoorTimer" after the
-- stall door, and "Move Wheelbarrow" had to be done within 15 seconds. What is on offer then is
-- said with "Hurry!".)
local hurryAt = -10
TWDA.hookBefore("Game_RunSceneDialog", function(node)
  if type(node) == "string" and node:lower():find("timer$") then
    hurryAt = TWDA.now()
    TWDA.log("lookaround4: timer " .. node)
  end
end)
local function announce()
  local now = TWDA.now()
  -- (Out of play, or unable to walk, for a few seconds (a talk, a scene): when control comes back
  -- it is said even if what is on offer is the same as before.)
  local free = playMode() and (canWalk() or call("Navigate_IsPathing") == true) -- (walking there herself)
  if not free then
    outSince = outSince or now
  elseif outSince then
    if now - outSince > 3 then forceNext, checkPending, settleFrom = true, true, now end
    outSince = nil
  end
  if not playMode() then
    wasPlay = false
    return
  end
  if not wasPlay then wasPlay, settleFrom, checkPending = true, now, true end
  if now - namesCheckedAt > 0.2 then
    namesCheckedAt = now
    local names = {}
    for _, agent in ipairs(current()) do names[#names + 1] = TWDA.agentName(agent) end
    table.sort(names)
    local joined = table.concat(names, ",")
    local walkNow = canWalk()
    if joined ~= lastNames or walkNow ~= wasWalk then
      lastNames, wasWalk, settleFrom, checkPending = joined, walkNow, now, true
    end
  end
  if not checkPending or now - settleFrom < 0.6 then return end
  if TWDA.qteBusy and TWDA.qteBusy() then return end
  -- (Not while a walker closes in: combat4.lua speaks then. What is new is said once it has gone.)
  if TWDA.walkerNear and TWDA.walkerNear(8) then return end
  checkPending = false
  local list = hotspots()
  local walk = canWalk()
  local parts = {}
  for _, h in ipairs(list) do parts[#parts + 1] = h.label end
  -- (The same things in another order, as she walks, are not news.)
  local sorted = {}
  for i, p in ipairs(parts) do sorted[i] = p end
  table.sort(sorted)
  local signature = table.concat(sorted, ";") .. (walk and "|walk" or "")
  -- (With nothing to use, the places count: at the funeral, Episode 2, a place walked to fired
  -- its trigger and nothing more, and the one place left was never said.)
  if #list == 0 and walk then signature = signature .. "|" .. #places() end
  if signature == lastSignature and not forceNext then return end
  lastSignature, forceNext = signature, false
  local prefix = walk and ((TWDA.playerName and TWDA.playerName() or "You") .. " can move. ") or ""
  if now - hurryAt < 5 and #list > 0 then prefix = "Hurry! " .. prefix end
  if #list == 0 then
    if walk then
      local n = #places()
      TWDA.say(prefix .. (n > 0 and ("Nothing to interact with here. %d %s to walk to, Tab to choose."):format(n, n == 1 and "place" or "places")
        or "Nothing to interact with here."))
    elseif station() and call("Station_AllowExit") ~= false then
      TWDA.say("Nothing more here. Backspace steps back.")
    end
  elseif #list == 1 then
    TWDA.say(("%s%s. Enter to do it."):format(prefix, parts[1]))
  elseif #list <= 4 then
    TWDA.say(("%s%s. Tab to choose."):format(prefix, table.concat(parts, ". ")))
  else
    TWDA.say(("%s%d things to interact with. Tab to choose."):format(prefix, #list))
  end
end

local VK_TAB, VK_SHIFT = 0x09, 0x10
local held = {}
TWDA.onFrame("lookaround4", function()
  if not isSeason4() then return end
  announce()
  local active = playMode() and not (TWDA.hasChoices and TWDA.hasChoices()) and not (TWDA.bowDrawn and TWDA.bowDrawn())
    and not (TWDA.starsActive and TWDA.starsActive()) and not (TWDA.qteTargetUp and TWDA.qteTargetUp())
  local ok, down = pcall(InputPCIsVKeyPressed, VK_TAB)
  down = ok and down == true
  if down and not held.tab and active then
    local okS, shift = pcall(InputPCIsVKeyPressed, VK_SHIFT)
    local okC, err = pcall(cycle, (okS and shift) and -1 or 1)
    if not okC then TWDA.log("lookaround4: " .. tostring(err)) end
  end
  held.tab = down
  -- (Enter goes through the game's own Useable_OnButtonUse; only where its input map is off does
  -- the mod listen for it.)
  local okE, enterDown = pcall(InputPCIsVKeyPressed, 0x0D)
  enterDown = okE and enterDown == true
  if enterDown and not held.enter and active then
    local okMap, useMap = pcall(InputMapperIsActive, "Useable.imap")
    if not (okMap and useMap) and #current() > 0 then pcall(enter, false) end
  end
  held.enter = enterDown
end)

-- Close-ups (Game mode "Station"): Backspace steps back where the station allows it.
local inStation, backHeld = false, false
TWDA.onFrame("lookaround4.station", function()
  if not isSeason4() then return end
  local now = station()
  if now and not inStation then
    -- (Hiding behind a walker at the river, Episode 3, is a station too: combat4.lua says so.)
    local hidingNow = TWDA.hidingBehindWalker and TWDA.hidingBehindWalker()
    if call("Station_AllowExit") ~= false and not hidingNow then TWDA.say("Close-up. Backspace steps back.") end
  end
  inStation = now
  local ok, down = pcall(InputPCIsVKeyPressed, 0x08)
  down = ok and down == true
  if down and not backHeld and now then
    if call("Station_AllowExit") == false then
      speak("Can't step back from here.")
    else
      pcall(ThreadStart, function()
        local okExit, err = pcall(Station_OnButtonExit, {})
        if not okExit then TWDA.log("lookaround4: station exit: " .. tostring(err)) end
      end)
    end
  end
  backHeld = down
end)
