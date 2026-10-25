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

local function labelOf(agent)
  local verb = dialogText(prop(agent, "Useable - Verb Node")) or presetVerb(agent)
  local noun = call("Game_GetNounText", agent)
  noun = (type(noun) == "string" and noun ~= "") and TWDA.cleanText(noun) or nil
  if not noun then
    local name = TWDA.agentName(agent):gsub("^obj_", ""):gsub("([%l])(%u)", "%1 %2"):gsub("_", " "):lower()
    noun = name
  end
  local text = verb and (verb .. " " .. noun) or noun
  return TWDA.normalCaps(text)
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

local chosen = nil      -- { agent, label } chosen with Tab
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
  if set ~= lastTabSet then chosen, lastTabSet = nil, set end
  local index = 0
  for i, h in ipairs(list) do
    if chosen and h.agent == chosen.agent then index = i end
  end
  index = index + delta
  if index < 1 then index = #list elseif index > #list then index = 1 end
  local h = list[index]
  chosen = { agent = h.agent, label = h.label, place = h.place }
  local where = whereText(h)
  speak(("%s%s, %d of %d"):format(entryText(h), where ~= "" and (", " .. where) or "", index, #list))
end

local function findChosen()
  if not chosen then return nil end
  for _, h in ipairs(entries()) do
    if h.agent == chosen.agent then return h end
  end
  return nil
end

local busyUntil = 0
local function use(agent, label)
  busyUntil = TWDA.now() + 0.8
  chosen = nil
  TWDA.log("lookaround4: using " .. TWDA.agentName(agent) .. " (" .. tostring(label) .. ")")
  local ok, err = pcall(ThreadStart, function()
    local okUse, errUse = pcall(function() Navigate_PathToAndUseAgent(agent, Game_GetUseNodeName(agent)) end)
    if not okUse then TWDA.log("lookaround4: use failed: " .. tostring(errUse)) end
  end)
  if not ok then TWDA.log("lookaround4: " .. tostring(err)) end
end

-- Enter or F: what Tab chose (a thing, used from wherever it is, as Clementine walks there by
-- herself; or a place, walked to), else the one thing on offer, else what the game points at.
local function enter(fromGame)
  if TWDA.now() < busyUntil then return true end
  if TWDA.qteTargetUp and TWDA.qteTargetUp() then return true end -- (qte3.lua's Enter)
  local h = findChosen()
  if h and h.place then
    chosen = nil
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
  chosen = nil
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
local function announce()
  local now = TWDA.now()
  -- (Out of play, or unable to walk, for a few seconds (a talk, a scene): when control comes back
  -- it is said even if what is on offer is the same as before.)
  local free = playMode() and canWalk()
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
  checkPending = false
  local list = hotspots()
  local walk = canWalk()
  local parts = {}
  for _, h in ipairs(list) do parts[#parts + 1] = h.label end
  local signature = table.concat(parts, ";") .. (walk and "|walk" or "")
  if signature == lastSignature and not forceNext then return end
  lastSignature, forceNext = signature, false
  local prefix = walk and ((TWDA.playerName and TWDA.playerName() or "You") .. " can move. ") or ""
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
  local active = playMode() and not (TWDA.hasChoices and TWDA.hasChoices())
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
    if call("Station_AllowExit") ~= false then TWDA.say("Close-up. Backspace steps back.") end
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
