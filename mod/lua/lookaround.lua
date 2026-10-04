-- Hotspots: the things the player can look at, talk to or use (Season 1's reticle, mode_reticle.lua).
--
-- With a mouse the player moves a reticle over an object; the game then shows its name and action
-- (Tooltip_Show(verb, noun)) and a click does it. In first-person scenes the camera turns to follow
-- the reticle. The reticle also falls asleep and drops its focus soon after the mouse stops moving.
--
-- Keyboard: Tab and Shift+Tab move between the hotspots on offer. The mod steers the reticle onto
-- the chosen one each frame (ReticleController_SetScreenPos, which also keeps it awake) and the game
-- focuses it as if the mouse were there. Enter does the action (in mouse mode the game only takes a
-- click; mode_Reticle:DoAction is what the click calls). Names and actions are read whenever the
-- game shows them, so mouse use is read too. In look-around scenes Tab also reaches things out of
-- view: holding the reticle at a screen edge turns the camera that way. Where Lee walks freely,
-- Enter on something out of view walks him there (and F6 gives distances).
local TWDA = ...
local G = _G

local VK_TAB, VK_SHIFT, VK_ENTER, VK_ESCAPE = 0x09, 0x10, 0x0D, 0x1B
local REACH_SECONDS = 2.5        -- to focus something in view
local REACH_BEHIND_SECONDS = 8   -- to turn the camera round to something behind it
local REACH_WALK_SECONDS = 2.5   -- the same where Lee can walk there instead
local SWEEP_SECONDS = 2.5        -- before trying the other way round

-- Set TWDA.lookDebug = true from the dev console to log decisions.
local function debug(text)
  if TWDA.lookDebug then TWDA.log("lookaround: " .. text) end
end

local function call(name, ...)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

local function prop(agent, name)
  local ok, value = pcall(AgentGetProperty, agent, name)
  if ok then return value end
  return nil
end

-- Modes that own the keyboard while they are up.
local BUSY_MODES = { "Menu", "Pause", "MessageBox", "Dialog", "Death", "Credits" }

-- The reticle can be used now: the system is on and nothing else (a menu, a choice, a message box)
-- has the keyboard.
local function reticleReady()
  local update = rawget(G, "Reticle_Update")
  if type(update) ~= "function" then return false end
  if TWDA.upvalue(update, "mbReticleSystemActive") ~= true then return false end
  if call("ReticleUI_IsEnabled") ~= true then return false end
  if TWDA.hasChoices and TWDA.hasChoices() then return false end
  local mode = call("Mode_GetCurrent")
  local modeName = type(mode) == "table" and type(mode.name) == "string" and mode.name or ""
  for _, word in ipairs(BUSY_MODES) do
    if modeName:find(word, 1, true) then return false end
  end
  return true
end

local function isPlayer(name)
  return name:find("^character_player") ~= nil or name:find("^player_") ~= nil
end

-- The game's own test (an upvalue of Reticle_Update) for whether a hotspot can be used right now;
-- the reticle only ever focuses those.
local function clickable(agent)
  local fn = TWDA.upvalue(rawget(G, "Reticle_Update"), "agentIsClickableNoDialog")
  if type(fn) ~= "function" then return true end
  local ok, result = pcall(fn, agent)
  return not ok or result == true
end

-- Where to put the reticle: the game measures from each hotspot's dot (the marker drawn on the
-- spot to click), in the same screen coordinates as the reticle; the object's own position can be
-- well off it.
local function aimPoint(agent)
  local dot = rawget(agent, "dot")
  if dot ~= nil then
    local ok, pos = pcall(AgentGetLogicalScreenPos, dot)
    if ok and pos and pos.x and pos.y then return pos.x, pos.y end
  end
  local ok, pos = pcall(AgentGetScreenPos, agent)
  if ok and pos then return pos.x, pos.y end
  return nil
end

-- Invisible trigger volumes are selectable too, but they are not things to interact with.
local function isTrigger(name)
  return name:lower():find("triggeragent", 1, true) ~= nil
end

-- Where a hotspot is relative to the view: nil when on screen, else "behind", "left", "right",
-- "up" or "down". (The game's own test only lets the reticle focus things on screen; in
-- look-around scenes the camera can be turned towards the others.)
local function offScreenSide(pos)
  if (pos.z or 1) <= 0 then return "behind" end
  if pos.x < 0 then return "left" end
  if pos.x > 1 then return "right" end
  if pos.y < 0 then return "up" end
  if pos.y > 1 then return "down" end
  return nil
end

local SIDE_WORDS = { behind = "behind you", left = "to your left", right = "to your right", up = "above you",
  down = "below you" }

-- In look-around scenes the camera turns to follow the reticle (a "pan cam"), so things behind it
-- can be reached as well.
local function panningCamera()
  local cam = call("CameraControlReticle_GetCamera")
  if cam == nil then return false end
  local range = prop(cam, "Pan Cam - Horiztonal Max Percentage Allowed")
  return type(range) == "number" and range > 0
end

-- Hotspots that could not be focused (out of the camera's reach from here), left out of the list
-- until the player moves or the camera changes.
local unreachable = {}
local unreachableFrom = nil -- where the player was
local unreachableCamera = nil

local function cameraName()
  local cam = call("CameraControlReticle_GetCamera")
  return cam ~= nil and TWDA.agentName(cam) or ""
end

local function playerPos()
  local player = call("Game_GetPlayer")
  if player == nil then return nil end
  local ok, pos = pcall(AgentGetWorldPos, player)
  if ok then return pos end
  return nil
end

local function forgetUnreachable()
  unreachable, unreachableFrom, unreachableCamera = {}, nil, nil
end

-- Free walking (the game's navigate.lua: Navigate.imap is active, W A S D walk relative to the
-- camera, a click walks to the spot). The mod can walk Lee to a hotspot the camera does not show
-- with the game's own path-finding (AgentPathToAgent, as PathToAndUseAgent does).
local function canWalk()
  if type(rawget(G, "AgentPathToAgent")) ~= "function" then return false end
  local ok, active = pcall(InputMapperIsActive, "Navigate.imap")
  return ok and active == true
end

-- Rounded distance from Lee in the game's units (about a meter each).
local function distanceTo(agent)
  local from = playerPos()
  local okPos, to = pcall(AgentGetWorldPos, agent)
  if not from or not okPos or not to then return nil end
  local ok, d = pcall(VectorDistance, from, to)
  if ok and type(d) == "number" then return math.floor(d + 0.5) end
  return nil
end

-- The order of the list: things in view first, then things behind the camera, each in the game's
-- own order. It is worked out when the set of hotspots changes and then kept, because the camera
-- turning as you move between them would otherwise reshuffle it.
local listOrder, listKey = {}, ""

-- The hotspots on offer. In look-around scenes that includes usable things out of view, which
-- the camera turns to (the shotgun shell and the shotgun beside Lee at the zombie cop).
local function hotspots()
  local useables = TWDA.upvalue(rawget(G, "Reticle_Update"), "mUseables")
  local list = {}
  if type(useables) ~= "table" then return list end
  local canTurn = panningCamera()
  for _, agent in ipairs(useables) do
    local name = TWDA.agentName(agent)
    local okHidden, isHidden = pcall(AgentIsHidden, agent)
    if name ~= "" and not isPlayer(name) and not isTrigger(name) and prop(agent, "Game Selectable") == true
      and not (okHidden and isHidden) then
      local okPos, pos = pcall(AgentGetScreenPos, agent)
      if okPos and pos and not unreachable[name] then
        local side = offScreenSide(pos)
        if (clickable(agent) and (side ~= "behind" or canTurn)) or (canTurn and side ~= nil) then
          list[#list + 1] = { agent = agent, name = name, x = pos.x, y = pos.y, behind = side == "behind",
            side = side, n = #list }
        end
      end
    end
  end
  local names = {}
  for _, entry in ipairs(list) do names[#names + 1] = entry.name end
  table.sort(names)
  local key = table.concat(names, "|")
  if key ~= listKey then
    listKey, listOrder = key, {}
    table.sort(list, function(a, b)
      if a.behind ~= b.behind then return not a.behind end
      return a.n < b.n
    end)
    for i, entry in ipairs(list) do listOrder[entry.name] = i end
  else
    table.sort(list, function(a, b) return listOrder[a.name] < listOrder[b.name] end)
  end
  return list
end

-- Display names, learnt from the tooltip whenever an object is focused.
local knownNames = {}

local function prettyName(agentName)
  local name = agentName:gsub("^obj_", ""):gsub("^char_", ""):gsub("%d+$", "")
  name = name:gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
  return name:lower()
end

-- The name and default action the game would show for a hotspot, without focusing it:
-- Reticle_UpdateActionIcons reads them from the agent's properties named by its upvalues kUseName
-- and kVerb.
local function propKey(name)
  return TWDA.upvalue(rawget(G, "Reticle_UpdateActionIcons"), name)
end

local function gameName(agent)
  local key = propKey("kUseName")
  if key == nil then return nil end
  local ok, noun = pcall(function() return agent.mProps[key] end)
  if not ok or type(noun) ~= "string" or noun == "" then return nil end
  local okText, text = pcall(Dialog_GetText, noun, nil, "text.dlog")
  if okText and type(text) == "string" and text ~= "" then return TWDA.cleanText(text) end
  return nil
end

local function gameVerb(agent)
  local key = propKey("kVerb")
  if key == nil then return nil end
  local ok, verb = pcall(function() return agent.mProps[key] end)
  if not ok or verb == nil or verb == "" then return nil end
  -- Usually plain text already ("Look At", "Take"); otherwise a dialog text key. Empty when the
  -- hotspot offers several actions (only shown once it is focused).
  local okText, text = pcall(Dialog_GetText, verb, agent)
  if okText and type(text) == "string" and text ~= "" then return TWDA.cleanText(text) end
  if type(verb) == "string" then return TWDA.cleanText(verb) end
  return nil
end

local function displayName(agentName, agent)
  if not knownNames[agentName] and agent ~= nil then knownNames[agentName] = gameName(agent) end
  return knownNames[agentName] or prettyName(agentName)
end

---------------------------------------------------------------------------------------------------
-- Reading what the game shows.
---------------------------------------------------------------------------------------------------

local current = { noun = nil, verb = nil, actions = {} }
local lastSpoken, lastSpokenAt = nil, -10
local target = nil -- { agent, name, since, index, count }

local function nounText(noun)
  if type(noun) ~= "string" or noun == "" then return nil end
  local ok, text = pcall(Dialog_GetText, noun, nil, "text.dlog")
  if ok and type(text) == "string" and text ~= "" then return TWDA.cleanText(text) end
  return TWDA.keyOrText(noun) or noun
end

-- The object's actions in key order (1 to 4 choose one; Enter does the chosen one).
local function actionList()
  local list, seen = {}, {}
  for _, action in ipairs(current.actions or {}) do
    if not seen[action] then
      seen[action] = true
      list[#list + 1] = action
    end
  end
  return list
end

local function describeFocus()
  if not current.noun then return nil end
  local actions = actionList()
  if #actions > 1 then
    local parts = {}
    for i, action in ipairs(actions) do parts[#parts + 1] = i .. " " .. action end
    return current.noun .. ": " .. table.concat(parts, ", ")
  end
  if current.verb then return current.noun .. ": " .. current.verb end
  return current.noun
end

local spokenNoun = nil
-- After a message about a hotspot the reticle could not reach, the reticle (left at a screen edge)
-- may land on something else; its name must not cut the message off. Tab ends the quiet.
local quietUntil = 0

local function speakFocus()
  local text
  if current.verbChanged and current.noun == spokenNoun then
    -- Same object, another of its actions chosen (number keys or the mouse wheel).
    text = current.verb
  else
    text = describeFocus()
    spokenNoun = current.noun
    if text and target and target.count and target.focusedOnce ~= true then
      target.focusedOnce = true
      text = ("%s, %d of %d"):format(text, target.index, target.count)
    end
  end
  current.verbChanged = false
  if not text then return end
  if TWDA.now() < quietUntil and not (target and target.name == TWDA.agentName(current.agent)) then return end
  if text == lastSpoken and TWDA.now() - lastSpokenAt < 1.5 then return end
  lastSpoken, lastSpokenAt = text, TWDA.now()
  TWDA.say(text, { interrupt = true })
end

-- The action icons for the focused object, in the order of their number keys.
TWDA.hookBefore("Reticle_UpdateActionIcons", function(default, choices, defaultText)
  local actions = {}
  if type(choices) == "table" then
    local iterate = #choices > 0 and ipairs or pairs
    for _, choice in iterate(choices) do
      local text = type(choice) == "table" and (choice["Choice Display Text"] or choice.mVerb) or nil
      text = TWDA.keyOrText(text)
      if text then actions[#actions + 1] = text end
    end
  end
  if #actions == 0 then actions[1] = TWDA.keyOrText(defaultText) end
  current.actions = actions
  -- For hotspots whose actions come from a dialog ("Reticle presentation"), this arrives a moment
  -- after the focus; an action must not be started before it (see doAction).
  current.actionsFor = TWDA.agentName(call("Reticle_GetAgentFocused"))
end)

TWDA.hookBefore("Tooltip_Show", function(verb, noun)
  local name = nounText(noun)
  if not name then return end
  local focused = call("Reticle_GetAgentFocused")
  if focused ~= nil then
    knownNames[TWDA.agentName(focused)] = name
    current.agent = focused
  end
  verb = TWDA.keyOrText(verb) or verb
  current.verbChanged = name == current.noun and verb ~= current.verb
  current.noun, current.verb = name, verb
  -- Speak on the next frame, once the action icons for this object are known too.
  current.pending = true
end)

TWDA.hookBefore("Tooltip_Clear", function()
  current.noun, current.verb, current.actions, current.actionsFor = nil, nil, {}, nil
  spokenNoun = nil
end)

---------------------------------------------------------------------------------------------------
-- Keys and steering.
---------------------------------------------------------------------------------------------------

local lastTargetName, lastIndex = nil, 0

local function cycle(delta)
  quietUntil = 0
  local list = hotspots()
  if #list == 0 then
    TWDA.say("Nothing to interact with here.", { interrupt = true })
    return
  end
  local index = 0
  local from = target and target.name or lastTargetName
  if from then
    for i, entry in ipairs(list) do
      if entry.name == from then index = i end
    end
  end
  if index == 0 and lastIndex > 0 then
    -- The last one has dropped out of the list; carry on from about where it was.
    index = math.min(lastIndex, #list + 1) - (delta > 0 and 1 or 0)
    if index < 1 then index = #list end
    index = (index - 1 + delta) % #list + 1
  elseif index == 0 then
    index = delta > 0 and 1 or #list
  else
    index = (index - 1 + delta) % #list + 1
  end
  local entry = list[index]
  target = { agent = entry.agent, name = entry.name, since = TWDA.now(), index = index, count = #list }
  lastTargetName, lastIndex = entry.name, index
  lastSpoken = nil
  if TWDA.agentName(call("Reticle_GetAgentFocused")) == entry.name then
    -- Already focused (only one hotspot, or the same one again): the tooltip will not change.
    speakFocus()
  end
end

-- Whether a hotspot's use dialog shows its actions through the reticle ("Reticle presentation" on
-- its choices node). Those only work when the reticle starts the use (see TWDA.useWithReticle);
-- other hotspots can also be used with Main_OnUse directly, which is what Enter falls back to for
-- one the camera cannot show even after walking there.
local USE_NODE, USE_FILE = "WDUseable - Action Use Dialog Start Node", "WDUseable - Action Use Dialog File"

local function presentsChoices(agent)
  local ok, result = pcall(function()
    local node = agent.mProps[USE_NODE]
    if node == nil or node == "" then return false end
    local sceneAgent = SceneGetSceneAgent(AgentGetScene(agent))
    for _, dlog in ipairs({ agent.mProps[USE_FILE], sceneAgent.mProps["Dialog Agent - File Primary"],
      sceneAgent.mProps["Dialog Agent - File Secondary"] }) do
      local found = DlgEvaluateToNode(dlog, node, "choices", false)
      if found then return DlgGetObjUserPropsValue(found["Dlog"], found["Node ID"], "Reticle presentation") == true end
    end
    return false
  end)
  -- When unsure, assume it needs the reticle.
  return not ok or result ~= false
end

local function directUse(agent)
  rawset(agent, "lastSelectedIcon", 1)
  local ok, err = pcall(ThreadStart, function()
    local okUse, errUse = pcall(Main_OnUse, agent)
    if not okUse then TWDA.log("direct use " .. TWDA.agentName(agent) .. ": " .. tostring(errUse)) end
  end)
  if not ok then TWDA.log("direct use (thread): " .. tostring(err)) end
end

-- Walking to a hotspot that the camera cannot show from here (free walking only).
-- AgentPathToAgent only returns once Lee has got there (or stopped), so it runs in a thread of its
-- own and the frame loop watches for it to finish.
-- The last hotspot chosen with Tab that the reticle could not reach, and what Enter does about it:
-- { agent, name, at, kind = "walk" (walk there) or "use" (use it from here) }.
local walkOffer = nil
local walking = nil   -- { agent, name, since, done, success, blockedSince }
local WALK_GIVE_UP_SECONDS = 60

local function startWalk(agent)
  local name = TWDA.agentName(agent)
  local w = { agent = agent, name = name, since = TWDA.now() }
  local ok, err = pcall(ThreadStart, function()
    local okPath, result = pcall(AgentPathToAgent, call("Game_GetPlayer"), agent)
    if not okPath then TWDA.log("walk: " .. tostring(result)) end
    w.done, w.success = true, okPath and result == true
  end)
  if not ok then
    TWDA.log("walk (thread): " .. tostring(err))
    return
  end
  walkOffer, target = nil, nil
  walking = w
  quietUntil = math.huge -- things passed on the way are not announced
  TWDA.say("Walking to " .. displayName(name, agent) .. ".", { interrupt = true })
end

local function stopWalk(say)
  if not walking then return end
  walking = nil
  quietUntil = 0
  pcall(PathAgentStop, call("Game_GetPlayer"))
  if say then TWDA.say("Stopped.", { interrupt = true }) end
end

-- Each frame while walking: say if Lee gets stuck; when he has arrived, aim the reticle at the
-- hotspot again (the camera has probably changed).
local function walkTick()
  local w = walking
  if not w then return end
  local now = TWDA.now()
  if not w.done then
    local okB, blocked = pcall(PathAgentIsBlocked, call("Game_GetPlayer"))
    if okB and blocked == true then
      w.blockedSince = w.blockedSince or now
      if now - w.blockedSince > 2 then
        stopWalk(false)
        TWDA.say("Lee is blocked on the way to " .. displayName(w.name, w.agent) .. ".", { interrupt = true })
      end
    else
      w.blockedSince = nil
    end
    if walking and now - w.since > WALK_GIVE_UP_SECONDS then walking, quietUntil = nil, 0 end
    return
  end
  walking = nil
  quietUntil = 0
  debug("walk to " .. w.name .. " finished, success " .. tostring(w.success))
  if not w.success then
    TWDA.say("Lee stopped before reaching " .. displayName(w.name, w.agent) .. ".", { interrupt = true })
    return
  end
  forgetUnreachable()
  target = { agent = w.agent, name = w.name, since = now, afterWalk = true }
  lastTargetName = w.name
  lastSpoken = nil
end

-- The game starts an action with Main_OnUse or PathToAndUseAgent (walking there first). If neither
-- follows an Enter (the focus lapsed just then, or the game was still busy), aim again and retry.
local lastUseAt = -1
local pendingAction = nil -- { agent, at, tries }
for _, name in ipairs({ "Main_OnUse", "PathToAndUseAgent" }) do
  TWDA.hookBefore(name, function() lastUseAt = TWDA.now() end)
end

-- The first action that is not just looking (for auto mode), as a number-key index.
local function firstUseAction()
  for i, action in ipairs(actionList()) do
    if not tostring(action):lower():find("^look") then return i end
  end
  return nil
end

-- pickNonLook: choose the first action that is not "Look" first (auto mode); without it the
-- action chosen with the number keys (or the first) is done.
local function doAction(pickNonLook)
  local mode = rawget(G, "mode_Reticle")
  if type(mode) ~= "table" or type(mode.DoAction) ~= "function" then return false end
  local focused = call("Reticle_GetAgentFocused")
  if focused == nil then return false end
  if pickNonLook then
    local index = firstUseAction()
    if not index then
      debug("only looking possible at " .. TWDA.agentName(focused) .. "; nothing done")
      return false
    end
    local selectAction = TWDA.upvalue(mode.OnChoice, "selectAction")
    if type(selectAction) == "function" then pcall(selectAction, index) end
  end
  pendingAction = { agent = focused, at = TWDA.now(), tries = (pendingAction and pendingAction.agent == focused)
    and pendingAction.tries or 0, pickNonLook = pickNonLook }
  -- With a controller the game's own Enter already does this.
  if TWDA.upvalue(mode.OnEnter, "mbJoystickOn") == true then return false end
  local ok, err = pcall(ThreadStart, function()
    local okRun, errRun = pcall(mode.DoAction, mode)
    if not okRun then TWDA.log("lookaround action: " .. tostring(errRun)) end
  end)
  if not ok then TWDA.log("lookaround action (thread): " .. tostring(err)) end
  -- Keep holding the reticle there: some actions take several goes (kicking the car window).
  return true
end

-- Enter. If nothing is focused (the reticle has fallen asleep, or is still on its way to a
-- hotspot), aim at the hotspot last read out and do the action once it is focused.
local function enterPressed()
  local focused = call("Reticle_GetAgentFocused")
  debug(("enter: focused %s, target %s, last %s"):format(TWDA.agentName(focused),
    target and target.name or "none", TWDA.agentName(current.agent)))
  -- The last thing chosen with Tab was out of view ("Enter walks there").
  if walkOffer and walkOffer.name == lastTargetName and TWDA.now() - walkOffer.at < 30 then
    local offer = walkOffer
    walkOffer = nil
    if offer.kind == "use" then
      directUse(offer.agent)
      return
    elseif canWalk() then
      startWalk(offer.agent)
      return
    end
  end
  if focused ~= nil then
    doAction()
    return
  end
  -- (Even in action scenes this goes through the reticle: the game only applies the chosen action,
  -- such as Take rather than Look, to uses that the reticle started; Main_OnUse on its own leaves
  -- the hotspot's dialog waiting and the scene stalls.)
  if target then
    target.actOnReach = true
    return
  end
  local agent = current.agent
  if agent ~= nil and prop(agent, "Game Selectable") == true then
    target = { agent = agent, name = TWDA.agentName(agent), since = TWDA.now(), actOnReach = true }
    return
  end
  TWDA.say("Nothing chosen. Tab to choose something.", { interrupt = true })
end

local held = {}
local lastMouse = nil

local function pressed(vk)
  local ok, down = pcall(InputPCIsVKeyPressed, vk)
  down = ok and down == true
  local edge = down and not held[vk]
  held[vk] = down
  return edge
end

TWDA.onFrame("lookaround", function()
  local ready = reticleReady()
  local tab, enter, escape = pressed(VK_TAB), pressed(VK_ENTER), pressed(VK_ESCAPE)
  if walking and (escape or not canWalk()) then stopWalk(escape) end
  walkTick()
  if enter and not ready then debug("enter ignored: reticle not ready") end
  if not ready then
    -- The reticle is off while an action or a short cutscene plays; take up the same object again
    -- afterwards, unless that takes too long.
    if target then
      target.waitSince = target.waitSince or TWDA.now()
      if TWDA.now() - target.waitSince > 15 then target = nil end
    end
    return
  end
  if target and target.waitSince then
    target.waitSince = nil
    if not target.reached then target.since = TWDA.now() end
  end

  if current.pending then
    current.pending = false
    speakFocus()
  end

  if pendingAction and TWDA.now() - pendingAction.at > 0.7 then
    local p = pendingAction
    pendingAction = nil
    if lastUseAt < p.at and p.tries < 2 and prop(p.agent, "Game Selectable") == true then
      TWDA.log("lookaround: action did not start, trying again")
      pendingAction = { agent = p.agent, at = TWDA.now() + 5, tries = p.tries + 1 } -- re-armed by doAction
      target = { agent = p.agent, name = TWDA.agentName(p.agent), since = TWDA.now(), actOnReach = true,
        pickNonLook = p.pickNonLook }
    end
  end

  if unreachableFrom then
    local pos = playerPos()
    local okDist, dist = pcall(VectorDistance, pos, unreachableFrom)
    if (pos and okDist and dist > 1) or cameraName() ~= unreachableCamera then forgetUnreachable() end
  end

  if tab then
    local okShift, shift = pcall(InputPCIsVKeyPressed, VK_SHIFT)
    cycle((okShift and shift == true) and -1 or 1)
  elseif enter then
    enterPressed()
  elseif escape then
    target = nil -- stop holding the reticle on it
  end

  -- The mouse moved: the player is aiming by hand, so stop steering.
  local okMouse, mouse = pcall(CursorGetDevicePos)
  if okMouse and mouse then
    if lastMouse and (math.abs(mouse.x - lastMouse.x) > 2 or math.abs(mouse.y - lastMouse.y) > 2) then target = nil end
    lastMouse = { x = mouse.x, y = mouse.y }
  end

  if target then
    local okSel = prop(target.agent, "Game Selectable") == true
    local okPos, pos = pcall(AgentGetScreenPos, target.agent)
    if not okSel or not okPos or not pos then
      target = nil
      return
    end
    local now = TWDA.now()
    local side = offScreenSide(pos)
    if side == nil then
      local x, y = aimPoint(target.agent)
      pcall(ReticleController_SetScreenPos, x or pos.x, y or pos.y, false)
    elseif side ~= "behind" then
      -- Out of view to one side: hold the reticle at that edge, which turns the camera that way.
      target.behind = true -- (allow the longer time to reach it)
      local x = side == "left" and 0.03 or side == "right" and 0.97 or math.max(0.03, math.min(0.97, pos.x))
      local y = side == "up" and 0.05 or side == "down" and 0.95 or math.max(0.05, math.min(0.95, pos.y))
      pcall(ReticleController_SetScreenPos, x, y, false)
    else
      -- Behind the camera: push the reticle to one side to turn the camera round, trying the other
      -- side if that does not bring it into view. (Projected from behind, it shows up mirrored, so
      -- start on the side opposite to where it appears.)
      if not target.sweep then
        target.sweep, target.sweepSince, target.behind = pos.x < 0.5 and 1 or -1, now, true
      elseif now - target.sweepSince > SWEEP_SECONDS then
        target.sweep, target.sweepSince = -target.sweep, now
      end
      pcall(ReticleController_SetScreenPos, target.sweep > 0 and 0.97 or 0.03, 0.5, false)
    end
    local focused = TWDA.agentName(call("Reticle_GetAgentFocused"))
    local limit = target.behind and REACH_BEHIND_SECONDS or REACH_SECONDS
    -- Where Lee can walk, the cameras are mostly fixed: do not sweep for long before offering a walk.
    if target.behind and canWalk() then limit = REACH_WALK_SECONDS end
    if focused == target.name then
      target.reached = target.reached or now
      -- Wait for the hotspot's actions to be shown (they come a moment later when a dialog
      -- presents them) before starting one.
      if target.actOnReach and (current.actionsFor == target.name or now - target.reached > 0.6) then
        target.actOnReach = false
        doAction(target.pickNonLook)
      end
    elseif not target.reached and now - target.since > limit and canWalk() and not target.afterWalk then
      -- Out of this camera's view: offer to walk there, or go at once if Enter was pressed.
      local t = target
      target = nil
      if t.actOnReach then
        startWalk(t.agent)
      else
        walkOffer = { agent = t.agent, name = t.name, at = now, kind = "walk" }
        local d = distanceTo(t.agent)
        TWDA.say(displayName(t.name, t.agent) .. " is out of view" .. (d and (", " .. d .. " meters away") or "")
          .. ". Enter walks there.", { interrupt = true })
        quietUntil = now + 4
      end
    elseif not target.reached and now - target.since > limit and target.afterWalk and not presentsChoices(target.agent) then
      -- Still out of view after walking there, but simple enough to use without the reticle.
      local t = target
      target = nil
      walkOffer = { agent = t.agent, name = t.name, at = now, kind = "use" }
      lastTargetName = t.name
      local verb = gameVerb(t.agent)
      TWDA.say(displayName(t.name, t.agent) .. ": the camera does not show it from here, but Lee can "
        .. (verb and verb:lower() or "use") .. " it. Enter to do it.", { interrupt = true })
      quietUntil = now + 5
    elseif not target.reached and now - target.since > limit then
      TWDA.say(displayName(target.name, target.agent) .. (target.afterWalk and " still can't be reached from here."
        or " can't be reached from here.") .. (target.actOnReach and " Nothing done." or ""), { interrupt = true })
      quietUntil = now + 3
      unreachable[target.name] = true
      unreachableFrom = unreachableFrom or playerPos()
      unreachableCamera = unreachableCamera or cameraName()
      target = nil
    end
  end
end)

-- For F6.
function TWDA.describeLookaround()
  if not reticleReady() then return nil end
  local list = hotspots()
  local focus = call("Reticle_GetAgentFocused") ~= nil and describeFocus() or nil
  if #list == 0 and not focus then return nil end
  local parts = {}
  if focus then parts[#parts + 1] = focus .. ". Enter to do it" end
  local names = {}
  local walk = canWalk()
  for _, entry in ipairs(list) do
    local where = {}
    if entry.side then where[#where + 1] = SIDE_WORDS[entry.side] end
    local d = walk and distanceTo(entry.agent)
    if d then where[#where + 1] = d .. " meters" end
    names[#names + 1] = displayName(entry.name, entry.agent) .. (#where > 0 and (" (" .. table.concat(where, ", ") .. ")") or "")
  end
  parts[#parts + 1] = ("%d to interact with: %s. Tab and Shift Tab to move between them"):format(#list,
    table.concat(names, ", "))
  return TWDA.joinSentences(parts)
end

---------------------------------------------------------------------------------------------------
-- For actions.lua (auto mode): use a hotspot the way a player would, by steering the reticle onto
-- it (turning the camera if need be) and doing its first action that is not "Look". Calling
-- Main_OnUse directly is not enough: the game applies the chosen action only to uses the reticle
-- started (Reticle_HandleReticleInstance), so the hotspot's dialog would wait for ever.
---------------------------------------------------------------------------------------------------

-- True while the mod is steering the reticle to do something.
function TWDA.reticleBusy()
  return target ~= nil and target.actOnReach == true
end

function TWDA.useWithReticle(agent)
  if TWDA.reticleBusy() then return false end
  target = { agent = agent, name = TWDA.agentName(agent), since = TWDA.now(), actOnReach = true, pickNonLook = true }
  lastTargetName = target.name
  return true
end

TWDA.hotspots = hotspots
TWDA.hotspotName = function(agent) return displayName(TWDA.agentName(agent), agent) end
TWDA.hotspotVerb = gameVerb
TWDA.reticleReady = reticleReady
