-- Things to interact with in Season 2 (projectseason2's reticle.lua, reticleselection.lua,
-- reticleverb.lua and navigate.lua: the newer Telltale framework; Season 1's are in lookaround.lua).
--
-- The reticle follows the mouse. The usables (ReticleSelection_GetUsables: agents with a dot) are
-- selected when the pointer comes near their dot, and their verbs (ReticleVerbs_BuildVerbData(agent),
-- then ReticleVerbs_GetAvailableVerbs: { Text, Direction = "South", "East", "West" or "North",
-- Icon }) are shown round it. Clicking a verb runs the local OnDoVerb: ReticleSelection_Lock(true),
-- ReticleVerbs_SetActiveVerb(verb) and Navigate_PathToAndUseAgent(agent), which walks the player
-- there when the hotspot needs it and runs its use dialog; that dialog's choice follows the active
-- verb (OnChoicesAvailable in reticle.lua). The mod does the same without the mouse.
--
-- Keys: Tab and Shift+Tab go through the things that can be used, nearest first ("Stall: Open, to
-- your left, 3 meters, 1 of 5"); a number key picks one of several verbs; Enter does it. F6 lists
-- them all. When the player is given control, the number of things is said once.
local TWDA = ...
local G = _G

local function call(name, ...)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

-- The usables; A New Frontier spells it ReticleSelection_GetUseables.
local function getUsables()
  return call("ReticleSelection_GetUsables") or call("ReticleSelection_GetUseables")
end

-- Season 2's reticle (also A New Frontier's): ReticleSelection_GetUsables and
-- ReticleVerbs_BuildVerbData exist only there.
local function isSeason2()
  return (type(rawget(G, "ReticleSelection_GetUsables")) == "function"
    or type(rawget(G, "ReticleSelection_GetUseables")) == "function")
    and type(rawget(G, "ReticleVerbs_BuildVerbData")) == "function"
end

local function playMode()
  if call("Reticle_IsEnabled") ~= true then return false end
  local mode = call("Game_GetMode")
  return type(mode) == "table" and rawget(mode, "bPlayMode") == true
end

local function prop(agent, name)
  local ok, value = pcall(AgentGetProperty, agent, name)
  if ok then return value end
  return nil
end

-- Some things flicker in and out of being selectable as they move: the walker's head to finish
-- off in the herd (Episode 3) is usable for half a second, then not for a quarter, for about two
-- and a half seconds. Anything usable in the last RECENT_SECONDS still counts (if not hidden).
local RECENT_SECONDS = 0.8
local recentlyUsable = setmetatable({}, { __mode = "k" }) -- agent -> when last seen usable

local function usableNow(agent)
  if agent == nil or call("AgentIsHidden", agent) == true then return false end
  if prop(agent, "Game Selectable") == false then
    return TWDA.now() - (recentlyUsable[agent] or -10) <= RECENT_SECONDS
  end
  recentlyUsable[agent] = TWDA.now()
  return true
end

-- Whether anything at all can be used now (cheaper than the full list, which builds every
-- thing's verbs).
local function anyUsable()
  for _, agent in pairs(getUsables() or {}) do
    if type(agent) == "table" and usableNow(agent) then return true end
  end
  return false
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

-- Where a hotspot is relative to the view: nil when on screen.
local function sideOf(agent)
  local ok, pos = pcall(AgentGetScreenPos, rawget(agent, "dot") or agent)
  if not ok or not pos then return nil end
  if (pos.z or 1) <= 0 then return "behind you" end
  if pos.x < 0 then return "to your left" end
  if pos.x > 1 then return "to your right" end
  if pos.y < 0 then return "above you" end
  if pos.y > 1 then return "below you" end
  return nil
end

-- The game's noun for a hotspot, or its agent name in words ("obj_throwRockAtZombie1" ->
-- "Throw rock at zombie 1"; fight targets have no noun).
local function nameOf(agent)
  local noun = call("Game_GetNounText", agent)
  if type(noun) == "string" and noun ~= "" then return TWDA.normalCaps(TWDA.cleanText(noun)) end
  -- (Michonne's "obj_Logical_dinghy", "obj_logical_gagJonas".)
  local name = TWDA.agentName(agent):gsub("^obj_", ""):gsub("^[Ll]ogical_?", ""):gsub("^logic_", "")
  name = name:gsub("([%l])(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")
  -- (Someone in the scene keeps a capital: "Gag Jonas".)
  name = name:gsub("_", " "):gsub("%a+", function(word)
    local okE, exists = pcall(AgentExists, word:sub(1, 1):upper() .. word:sub(2))
    return (okE and exists == true and #word > 2) and (word:sub(1, 1):upper() .. word:sub(2)) or word:lower()
  end):gsub("^%s+", "")
  -- ("obj_doorComicShopUsePoint" -> "Comic shop door", not "Door comic shop use point".)
  name = name:gsub("%s*use ?point$", "")
  local first, rest = name:match("^(%a+)%s+(.+)$")
  if first and ({ door = true, gate = true, window = true, hatch = true, ladder = true })[first] then
    name = rest .. " " .. first
  end
  return (name:gsub("^%l", string.upper))
end

local function combatMode()
  return call("Reticle_IsCombatMode") == true
end

-- Michonne's scripts (projectseasonm), told apart from Season 2's by where navigate.lua comes from.
local michonneCache = nil
local function isSeason2Michonne()
  if michonneCache == nil then
    local fn = TWDA.unwrap(rawget(G, "Navigate_PathToAndUseAgent"))
    local ok, info = pcall(debug.getinfo, fn, "S")
    michonneCache = ok and info and tostring(info.source):find("projectseasonm", 1, true) ~= nil or false
  end
  return michonneCache
end

local function inStation()
  local mode = call("Game_GetMode")
  return type(mode) == "table" and rawget(mode, "name") == "Station"
end

-- (On a guided path, such as crawling under the porch, the walking keys move along the path only:
-- nothing out of view can be reached, and there are no places to walk to.)
local function onGuidedPath()
  return call("ChoredMovement_IsActive") == true
end

-- The verbs the reticle offers for an agent. Building them for one agent replaces the reticle's
-- own verb data, so it is rebuilt for the agent the reticle shows afterwards.
local function verbsOf(agent)
  local ok, err = pcall(ReticleVerbs_BuildVerbData, agent)
  if not ok then
    TWDA.log("lookaround2: verbs for " .. TWDA.agentName(agent) .. ": " .. tostring(err))
    return {}
  end
  local list = {}
  for _, verb in ipairs(call("ReticleVerbs_GetAvailableVerbs") or {}) do
    list[#list + 1] = verb
  end
  local shown = TWDA.upvalue(rawget(G, "ReticleUpdateInterface"), "mInterfaceAgent")
  if shown ~= nil and shown ~= agent then pcall(ReticleVerbs_BuildVerbData, shown) end
  return list
end

local function verbText(verb)
  local text = type(verb) == "table" and (rawget(verb, "Text") or rawget(verb, "Preset")) or nil
  if text == "" and type(verb) == "table" then text = rawget(verb, "Preset") end
  text = text and TWDA.normalCaps(TWDA.cleanText(tostring(text))) or ""
  return (text:gsub("%.+$", "")) -- (Michonne's "Look At.")
end

-- The things to interact with now, nearest first, with names told apart ("Stall 2").
local function hotspots()
  local list = {}
  local from = playerPos()
  local guided = onGuidedPath()
  local outOfView = {}
  local station = inStation()
  local seen = {}
  for _, agent in pairs(getUsables() or {}) do
    -- (Michonne's list can hold one agent twice: "obj_logical_gagJonas", Episode 2.)
    if type(agent) == "table" and not seen[agent] and usableNow(agent) then
      seen[agent] = true
      local verbs = verbsOf(agent)
      local side = #verbs == 0 and station and sideOf(agent) or nil
      local okD, drag = pcall(rawget(G, "Drag_IsDragAgent") or function() return false end, agent)
      if #verbs == 0 and okD and drag == true and TWDA.pickDrag then
        -- (Michonne's drags have no action: "Hold and drag to bandage Sam", Episode 2.)
        list[#list + 1] = { agent = agent, name = nameOf(agent), verbs = {}, dragOnly = true,
          distance = distanceTo(agent, from), side = sideOf(agent) }
      elseif side then
        -- (Michonne's close-ups go on when the view is turned to a spot with no actions, as the mouse
        -- turns it: "obj_logical_sawGhostKidsTrigger" in the boat town's storeroom, Episode 1. Enter
        -- turns the view to it.)
        list[#list + 1] = { agent = agent, name = "Something to look at", verbs = {}, lookOnly = true, side = side }
      elseif #verbs > 0 then
        local entry = { agent = agent, name = nameOf(agent), verbs = verbs, distance = distanceTo(agent, from),
          side = sideOf(agent) }
        if guided and entry.side ~= nil then
          outOfView[#outOfView + 1] = entry
        else
          list[#list + 1] = entry
        end
      end
    end
  end
  -- (A path that stops on the way for something out of view: Michonne's sneak through the ferry,
  -- Episode 1, halts by the snack bar for "Walker: Kill Walker", then a close-up wants the rope it
  -- hangs from, both off screen. With nothing in view, those count.)
  if #list == 0 then list = outOfView end
  table.sort(list, function(a, b)
    if (a.side == nil) ~= (b.side == nil) then return a.side == nil end -- (in view first)
    return (a.distance or 999) < (b.distance or 999)
  end)
  -- (Numbered in the order of their agents' names, not by distance, so that "Stall 2" stays the
  -- same stall as Clementine walks about.)
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

---------------------------------------------------------------------------------------------------
-- Places to walk to. Trails and clearings often have nothing to interact with, only walk-in
-- triggers that start the next bit of story ("trigger_path_tJunction_enter", "Trigger Enabled" set).
-- They lie below the ground, so their middle is put on the walk boxes (WalkBoxesPosOnWalkBoxes(pos,
-- PathAgentGetWalkBoxes(player))). The engine's path-finding will not take the player to most of
-- them, so the mod steers instead, as the stick or W A S D would (DirectControl_SetJoystickDirection
-- with the way to go on screen, worked out again every frame as the camera cuts).
---------------------------------------------------------------------------------------------------

-- ("warp" triggers move the player between the parts of a room or yard that have walk boxes of
-- their own, in pairs: "Warp tables to fireplace" and back. Walks to the things on the far side
-- cross them anyway.)
-- (Death traps are no places either: The Final Season's "trigger_dialog_caughtByTrappedZombie" kills
-- Clementine beside a pinned walker.)
-- ("zombat": The Final Season's walker fights, "trigger_dialog_zombatLatecomer" on the shore at the
-- start of Episode 4 brings one more walker, and stood first in Tab's list during the escape.)
local NOT_PLACES = { "cam", "chore", "depth", "tracking", "death", "dies", "die_", "kill", "pursuer", "fail", "lose",
  "warp", "caught", "zombat" }
local DEATH_TRAPS = { "death", "dies", "die_", "kill", "caught" }

local function canWalk()
  if onGuidedPath() then return false end
  local okMap, walking = pcall(InputMapperIsActive, "Navigate.imap")
  return okMap and walking == true and call("Navigate_IsEnabled") == true
end

local function placeName(agentName)
  -- (The Final Season's "trigger_dialog_bg_creakyBridge", "trigger_dialog_cs_zombiePier": the kind of
  -- dialog, background or cut scene, is not part of the name.)
  local name = agentName:gsub("^trigger_", ""):gsub("^cam_nav_", ""):gsub("^path_", ""):gsub("^dialog_", "")
    :gsub("^bg_", ""):gsub("^cs_", "")
  name = name:gsub("([%l])(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2"):gsub("_", " "):lower()
  return (name:gsub("^%l", string.upper))
end

local function places()
  local list = {}
  local player = TWDA.player()
  if player == nil or not canWalk() then return list end
  local okWB, walkBoxes = pcall(PathAgentGetWalkBoxes, player)
  local from = playerPos()
  local okS, agents = pcall(SceneGetAgents, TWDA.playerScene and TWDA.playerScene() or call("Game_GetScene"))
  for _, agent in ipairs(okS and type(agents) == "table" and agents or {}) do
    local name = TWDA.agentName(agent)
    local lower = name:lower()
    if lower:find("^trigger_") and prop(agent, "Trigger Enabled") == true then
      local skip = false
      for _, word in ipairs(NOT_PLACES) do
        if lower:find(word, 1, true) then skip = true break end
      end
      -- (Camera triggers are no places, except "cam_nav" ones, which mark where a walk leads: in
      -- the snowstorm, Episode 5, "trigger_cam_nav_restStopEntrance" is the only sign of the way,
      -- 115 m off, and W leads away from it.)
      if lower:find("^trigger_cam_nav_") and not lower:find("death", 1, true) then skip = false end
      -- (A New Frontier: over-the-shoulder camera zones, "trigger_cam_nav_OTS", focus pulls and
      -- walking-speed switches, "trigger_dialog_fastWalk", are not places either.)
      if lower:find("_ots", 1, true) or lower:find("walk$") or lower:find("rackfocus", 1, true) then skip = true end
      -- (Nor the walkers' own triggers, "trigger_zombie3" in A New Frontier's herd, Episode 5; nor
      -- story spots named after what happens there, "trigger_dialog_zombieAttack". The Final Season
      -- names most of its story spots so, "trigger_dialog_firstZombie", and they are the way on.)
      local finalSeason = type(rawget(G, "Useable_GetCount")) == "function"
      if (lower:find("zombie", 1, true) or lower:find("walker", 1, true))
          and not (finalSeason and lower:find("^trigger_dialog_")) then
        skip = true
      end
      local okP, pos = pcall(AgentGetWorldPos, agent)
      if not skip and okP and pos and okWB then
        local okG, ground = pcall(WalkBoxesPosOnWalkBoxes, pos, walkBoxes)
        if okG and ground then
          local d = from and VectorDistance(from, ground) or nil
          if d and d > 1.5 then
            list[#list + 1] = { agent = agent, place = true, target = ground, raw = pos, label = placeName(name),
              verbs = {}, distance = d, side = sideOf(agent) }
          end
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.distance < b.distance end)
  return list
end

local walk = nil -- { agent, label, target, best, bestAt, start }
local cutShort = nil -- a walk the game interrupted, to go on with: { agent, label, target, first, at }
local MOVE_KEYS = { 0x57, 0x41, 0x53, 0x44, 0x25, 0x26, 0x27, 0x28 }

-- Walkers that a walk should keep clear of: the triggers that go about with them ("trigger_zombie3"
-- on Zombie3 in A New Frontier's herd), looked up again five times a second.
local AVOID_METERS = 1.3
local spots, spotsAt = {}, -10
local traps = {} -- (the death traps among the spots)
local function walkerSpots()
  local now = TWDA.now()
  if now - spotsAt < 0.2 then return spots end
  spotsAt, spots, traps = now, {}, {}
  local okS, agents = pcall(SceneGetAgents, TWDA.playerScene and TWDA.playerScene() or call("Game_GetScene"))
  for _, agent in ipairs(okS and type(agents) == "table" and agents or {}) do
    local lower = TWDA.agentName(agent):lower()
    local avoid = lower:find("^trigger_zombie%d") or lower:find("^trigger_zombielow") or lower:find("^trigger_walker%d")
    -- (And the death traps, while they are on.)
    if not avoid and lower:find("^trigger_") and prop(agent, "Trigger Enabled") == true then
      for _, word in ipairs(DEATH_TRAPS) do
        if lower:find(word, 1, true) then avoid = true break end
      end
    end
    if avoid then
      local okP, pos = pcall(AgentGetWorldPos, agent)
      if okP and pos then spots[#spots + 1] = pos end
      if okP and pos and not lower:find("^trigger_zombie") and not lower:find("^trigger_walker") then
        traps[#traps + 1] = pos
      end
    end
  end
  return spots
end

-- A death trap near the straight way there (the trapped walker's at the train station, The Final
-- Season, lies right on the way to AJ): a point 2.5 meters to one side of it, on the walk boxes,
-- to head for first.
local function detourAround(here, target)
  walkerSpots()
  local dx, dz = target.x - here.x, target.z - here.z
  local length = math.sqrt(dx * dx + dz * dz)
  if length < 1 then return nil end
  local ux, uz = dx / length, dz / length
  local okWB, walkBoxes = pcall(PathAgentGetWalkBoxes, TWDA.player())
  for _, c in ipairs(traps) do
    local along = (c.x - here.x) * ux + (c.z - here.z) * uz
    local across = math.abs((c.x - here.x) * uz - (c.z - here.z) * ux)
    if along > 0.3 and along < length - 0.3 and across < 1.2 then
      local best, bestLength = nil, math.huge
      for _, sign in ipairs({ 1, -1 }) do
        local wx, wz = c.x - uz * 2.5 * sign, c.z + ux * 2.5 * sign
        local okG, ground = false, nil
        if okWB then okG, ground = pcall(WalkBoxesPosOnWalkBoxes, Vector(wx, c.y, wz), walkBoxes) end
        if okG and ground and math.abs(ground.x - wx) + math.abs(ground.z - wz) < 0.6 then
          local total = math.sqrt((wx - here.x) ^ 2 + (wz - here.z) ^ 2) + math.sqrt((target.x - wx) ^ 2 + (target.z - wz) ^ 2)
          if total < bestLength then best, bestLength = ground, total end
        end
      end
      if best then return best end
    end
  end
  return nil
end

-- (The Final Season runs with Shift, through navigatewd.lua's SetRunning, an upvalue of
-- Navigate_OnButtonRun. A walk runs while a walker is near: on the shore at the start of Episode 4
-- the herd sweeps in at about walking pace.)
local running = false
local function setRun(on)
  if on == running then return end
  local fn = TWDA.upvalue(rawget(G, "Navigate_OnButtonRun"), "SetRunning")
  if type(fn) == "function" and pcall(fn, on) then
    running = on
    TWDA.log("lookaround2: running " .. tostring(on))
  end
end

local function stopWalk(text)
  pcall(DirectControl_SetJoystickDirection, Vector(0, 0, 0))
  setRun(false)
  if walk and walk.pathing then pcall(PathAgentStop, TWDA.player()) end
  if text then TWDA.say(text, { interrupt = true }) end
  if walk then TWDA.log("lookaround2: walk to " .. walk.label .. " ended: " .. tostring(text)) end
  walk = nil
end

-- The game's own path-finding first (AgentPathToPosition: it goes round things, but gives up on
-- many places straight away); steering takes over from wherever it stops.
local function startWalk(h)
  local w = { agent = h.agent, label = h.label, target = h.target, best = h.distance, first = h.distance, bestAt = TWDA.now(),
    start = TWDA.now(), pathing = true, stopAt = h.stopAt, stopWhen = h.stopWhen, onArrive = h.onArrive,
    noResume = h.noResume }
  walk = w
  TWDA.log("lookaround2: walking to " .. h.label)
  TWDA.say(("Walking to %s, %d meters. A movement key stops."):format(h.label, math.floor(h.distance + 0.5)),
    { interrupt = true })
  -- (Among walkers the mod steers from the start: the path-finding goes straight through them.)
  if #walkerSpots() > 0 then
    w.pathing = false
    w.best, w.bestAt = math.huge, TWDA.now()
    return
  end
  local ok = pcall(ThreadStart, function()
    -- (The trigger's own place first: on another floor, the point put on the walk boxes can be on
    -- the wrong floor; then that point.)
    local okPath, arrived = false, false
    if h.raw then okPath, arrived = pcall(AgentPathToPosition, TWDA.player(), h.raw) end
    if walk == w and not (okPath and arrived) then
      okPath, arrived = pcall(AgentPathToPosition, TWDA.player(), w.target)
    end
    if walk ~= w then return end
    TWDA.log(("lookaround2: path-finding to %s: %s"):format(w.label, tostring(okPath and arrived)))
    w.pathing = false
    w.best, w.bestAt = math.huge, TWDA.now()
  end)
  if not ok then w.pathing = false end
end

local function horizontalDistance(a, b)
  local dx, dz = b.x - a.x, b.z - a.z
  return math.sqrt(dx * dx + dz * dz)
end

local function steer()
  if not walk then return end
  local now = TWDA.now()
  if not playMode() or not canWalk() then
    -- (Shooting the target the walk waited for leaves play mode for a moment: walk on after it.)
    if walk.paused and now - walk.paused < 15 then return end
    -- (Something has started: a scene, a talk. It speaks for itself. The walk goes on after it,
    -- below: through the herd to the generator, Episode 5 of A New Frontier, a walker turns to look
    -- for a few seconds, and then there are only about fifteen to get there.)
    TWDA.log("lookaround2: walk interrupted (play " .. tostring(playMode()) .. ", walking " .. tostring(canWalk()) .. ")")
    -- (Not a step made to start a scene, lookaround4.lua's step off a story line.)
    if not walk.noResume then
      cutShort = { agent = walk.agent, label = walk.label, target = walk.target, first = walk.first, at = now }
    end
    stopWalk(nil)
    return
  end
  -- (A movement key held a quarter of a second takes over; a key reading true for a moment as a
  -- walk starts does not.)
  local anyDown = false
  for _, vk in ipairs(MOVE_KEYS) do
    local ok, down = pcall(InputPCIsVKeyPressed, vk)
    if ok and down then anyDown = vk end
  end
  if anyDown and now - walk.start > 0.5 then
    walk.keySince = walk.keySince or now
    if now - walk.keySince > 0.25 then
      TWDA.log("lookaround2: walk stopped by key " .. anyDown)
      stopWalk(nil)
      return
    end
  else
    walk.keySince = nil
  end
  if prop(walk.agent, "Trigger Enabled") == false then
    TWDA.log("lookaround2: walk ended, trigger fired")
    stopWalk(nil)
    return
  end
  local here = playerPos()
  if not here then return stopWalk(nil) end
  local d = horizontalDistance(here, walk.target)
  -- (A walk can end when something else says so: a walker in reach, combat4.lua, which says so.)
  if walk.stopWhen then
    local okW, done = pcall(walk.stopWhen)
    if okW and done then return stopWalk(nil) end
  end
  -- (Half a meter: a story trigger has to be stepped into, and many are small.)
  if d < (walk.stopAt or 0.5) then
    -- (A walk made to use something, lookaround4.lua, uses it on arrival, which speaks for itself.)
    local onArrive = walk.onArrive
    stopWalk(not onArrive and ("At " .. walk.label .. ".") or nil)
    if onArrive then
      local okA, errA = pcall(onArrive)
      if not okA then TWDA.log("lookaround2: on arrival: " .. tostring(errA)) end
    end
    return
  end
  -- Long walks say how far is left every 10 s, while it goes down.
  if now - (walk.toldAt or walk.start) >= 10 and not walk.paused then
    walk.toldAt = now
    local m = math.floor(d + 0.5)
    if m < (walk.toldMeters or math.huge) - 1 then
      walk.toldMeters = m
      TWDA.say(m .. " meters to go.")
    end
  end
  -- A target in a fight (a walker out of the snowstorm, Episode 5): stand still until it is dealt
  -- with (Enter goes for it), then walk on.
  if combatMode() and anyUsable() then
    if not walk.paused then
      walk.paused = now
      TWDA.log("lookaround2: walk paused for a target")
      pcall(DirectControl_SetJoystickDirection, Vector(0, 0, 0))
      if walk.pathing then
        pcall(PathAgentStop, TWDA.player())
        walk.pathing = false
      end
    end
    walk.bestAt = now
    return
  end
  if walk.paused then
    walk.start, walk.paused = walk.start + (now - walk.paused), nil
  end
  if walk.pathing then return end -- (the game's path-finding is walking her)
  -- (Given up on after a time that grows with the way: 115 m of snowstorm take minutes.)
  if now - walk.start > 60 + 2.5 * (walk.first or 24) then
    return stopWalk("Gave up walking to " .. walk.label .. ".")
  end
  -- (Round a death trap by way of a point beside it, looked for twice a second.)
  if walk.waypoint and horizontalDistance(here, walk.waypoint) < 0.8 then walk.waypoint, walk.best = nil, math.huge end
  if not walk.waypoint and now - (walk.detourCheckAt or -10) > 0.5 then
    walk.detourCheckAt = now
    walk.waypoint = detourAround(here, walk.target)
    if walk.waypoint then
      walk.best = math.huge
      TWDA.log(("lookaround2: round a trap by %.1f, %.1f"):format(walk.waypoint.x, walk.waypoint.z))
    end
  end
  local aim = walk.waypoint or walk.target
  local ad = horizontalDistance(here, aim)
  if ad < 0.0001 then return end
  -- (Progress is towards the point beside a trap while there is one.)
  if ad < walk.best - 0.3 then walk.best, walk.bestAt, walk.detours = ad, now, 0 end
  -- Stuck against something: try going round it, one side then the other, before giving up.
  local detour = walk.detour
  if detour and now > detour.untilTime then walk.detour, detour = nil, nil end
  if not detour and now - walk.bestAt > 1.2 then
    walk.detours = (walk.detours or 0) + 1
    -- (Among walkers the way opens as they move: keep trying.)
    if walk.detours > 4 and #walkerSpots() > 0 then walk.detours = 1 end
    if walk.detours > 4 then
      return stopWalk(("Blocked, %d meters from %s. Try another way."):format(math.floor(d + 0.5), walk.label))
    end
    local sign = (walk.detours % 2 == 1) and 1 or -1
    walk.detour = { angle = sign * math.rad(60 + 15 * walk.detours), untilTime = now + 1.0 }
    walk.bestAt = now + 1.0
    detour = walk.detour
  end
  local okCam, camera = pcall(function() return SceneGetCamera(TWDA.playerScene and TWDA.playerScene() or Game_GetScene()) end)
  if not okCam or camera == nil then return end
  local ux, uz = (aim.x - here.x) / ad, (aim.z - here.z) / ad
  -- Keeping clear of walkers on the way (through the herd in Episode 5 of A New Frontier, where
  -- brushing against them gives Javier away): each pushes the way aside, harder the closer.
  local px, pz = 0, 0
  for _, pos in ipairs(walkerSpots()) do
    local ax, az = here.x - pos.x, here.z - pos.z
    local dist = math.sqrt(ax * ax + az * az)
    if dist > 0.01 and dist < AVOID_METERS then
      local push = (AVOID_METERS - dist) / AVOID_METERS * 2
      px, pz = px + ax / dist * push, pz + az / dist * push
    end
  end
  if px ~= 0 or pz ~= 0 then
    ux, uz = ux + px, uz + pz
    local n = math.sqrt(ux * ux + uz * uz)
    if n < 0.0001 then return end
    ux, uz = ux / n, uz / n
  end
  local okA, a = pcall(CameraGetScreenPosFromWorldPos, camera, here)
  local okB, b = pcall(CameraGetScreenPosFromWorldPos, camera, Vector(here.x + ux, here.y, here.z + uz))
  if not (okA and a and okB and b) then return end
  local dx, dy = (b.x - a.x) * 16 / 9, -(b.y - a.y)
  if detour then
    local c, s = math.cos(detour.angle), math.sin(detour.angle)
    dx, dy = dx * c - dy * s, dx * s + dy * c
  end
  local length = math.sqrt(dx * dx + dy * dy)
  if length < 0.0001 then return end
  setRun(TWDA.walkerNear ~= nil and TWDA.walkerNear(12))
  pcall(DirectControl_SetJoystickDirection, Vector(dx / length, dy / length, 0))
end
TWDA.onFrame("lookaround2.walk", steer)

-- (The Final Season's lookaround4.lua offers the same places to walk to, through these.)
TWDA.walkPlaces = places
TWDA.walkTo = startWalk
function TWDA.walkingTo()
  return walk and walk.label or nil
end

-- A walk the game cut short goes on once the player can walk again (within 20 seconds, if the
-- place is still there and no movement key is held).
TWDA.onFrame("lookaround2.resume", function()
  if not cutShort or walk then return end
  local now = TWDA.now()
  if now - cutShort.at > 20 or prop(cutShort.agent, "Trigger Enabled") == false then
    cutShort = nil
    return
  end
  for _, vk in ipairs(MOVE_KEYS) do
    local ok, down = pcall(InputPCIsVKeyPressed, vk)
    if ok and down then cutShort = nil return end
  end
  if not (playMode() and canWalk()) or (TWDA.qteBusy and TWDA.qteBusy()) then
    cutShort.playSince = nil
    return
  end
  cutShort.playSince = cutShort.playSince or now
  if now - cutShort.playSince < 0.5 then return end
  local here = playerPos()
  local d = here and horizontalDistance(here, cutShort.target)
  local c = cutShort
  cutShort = nil
  if not d or d < 0.5 then return end
  TWDA.log("lookaround2: walking on to " .. c.label)
  startWalk({ agent = c.agent, label = c.label, target = c.target, distance = d })
  if walk then walk.first = c.first or d end
end)

-- The item a verb's icon shows ("ui_icon_hammer.d3dtx" -> "hammer"), to tell apart two verbs with
-- the same words (Board: "Pry" with the hammer, "Pry" with the knife).
local function iconWord(verb)
  local icon = type(verb) == "table" and rawget(verb, "Icon") or nil
  if icon == nil then return nil end
  local ok, name = pcall(ResourceGetName, icon)
  if not ok or type(name) ~= "string" then return nil end
  local word = name:lower():gsub("%.d3dtx$", ""):gsub("^ui_icon_", ""):gsub("^ui_", ""):gsub("_", " ")
  return word ~= "" and word or nil
end

local function verbsText(h, numbered)
  if #h.verbs == 1 then return verbText(h.verbs[1]) end
  local count = {}
  for _, verb in ipairs(h.verbs) do
    local t = verbText(verb)
    count[t] = (count[t] or 0) + 1
  end
  local parts = {}
  for i, verb in ipairs(h.verbs) do
    local t = verbText(verb)
    if count[t] > 1 then
      local word = iconWord(verb)
      if word then t = t .. " with " .. word end
    end
    parts[#parts + 1] = numbered and (i .. " " .. t) or t
  end
  return table.concat(parts, ", ")
end

-- "Stall: Open", or just the name for a target whose only verb has no words (a fight target such
-- as "Throw rock at zombie 1").
local function entryText(h, numbered)
  if h.place then return "Place: " .. h.label end
  if h.lookOnly then return h.label .. ": turn the view to it" end
  if h.dragOnly then return h.label .. ": take hold, then drag" end
  local verbs = verbsText(h, numbered)
  if verbs == "" then return h.label end
  return h.label .. ": " .. verbs
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

local current = nil   -- { agent, label } chosen with Tab
local lastTabSet = nil -- the agents Tab went through last time
local lastUsed = nil   -- { agent, verb, index }: the last thing used, to offer it again
local recheckAt = nil  -- when to look at what is on offer again after a use

local usedAgent = nil  -- the agent Game_UseAgent was last called with
TWDA.hookBefore("Game_UseAgent", function(agent) usedAgent = agent end)

-- Actions that the game can ask for several times over (a walker that takes four blows, a door
-- listened at again and again); other things still offered after a use (an open door) are not
-- offered "again".
local REPEATABLE = { smash = true, hit = true, kick = true, punch = true, stab = true, bash = true, strike = true,
  shove = true, pull = true, push = true, pry = true, chop = true, shoot = true, swing = true, knock = true,
  ["listen at"] = true, eavesdrop = true, puncture = true, attack = true, ["swing rock at"] = true, bite = true }
local chosenVerb = nil
local busyUntil = 0
local RUN_METERS = 6 -- things at least this far away are run to

local function speak(text)
  TWDA.say(text, { interrupt = true })
end

-- Tab's list: the things to interact with, then the places to walk to.
local function entries()
  local list = hotspots()
  -- (In a fight Tab goes through the targets only; with none in sight, as between the walkers in
  -- the snowstorm, Episode 5, the places count again.)
  if not combatMode() or #list == 0 then
    for _, p in ipairs(places()) do list[#list + 1] = p end
  end
  return list
end

local function cycle(delta)
  local list = entries()
  if #list == 0 then
    speak("Nothing to interact with here.")
    return
  end
  -- (When what is on offer has changed since the last Tab, start again from the top.)
  local names = {}
  for _, h in ipairs(list) do names[#names + 1] = TWDA.agentName(h.agent) end
  table.sort(names) -- (the order changes as the player moves; the set is what counts)
  local set = table.concat(names, ",")
  if set ~= lastTabSet then current, lastTabSet = nil, set end
  local index = 0
  for i, h in ipairs(list) do
    if current and h.agent == current.agent then index = i end
  end
  index = index + delta
  if index < 1 then index = #list elseif index > #list then index = 1 end
  local h = list[index]
  current, chosenVerb = { agent = h.agent, label = h.label }, nil
  local where = whereText(h)
  speak(("%s%s, %d of %d"):format(entryText(h, true), where ~= "" and (", " .. where) or "", index, #list))
end

local function findCurrent()
  if not current then return nil end
  for _, h in ipairs(entries()) do
    if h.agent == current.agent then return h end
  end
  return nil
end

-- Turns a close-up's view to an agent the way the mouse does: the pointer held at the screen's edge
-- on its side pans the camera (ReticleCameraControl), until it is on screen.
local function turnViewTo(agent)
  pcall(ThreadStart, function()
    local started = TWDA.now()
    while TWDA.now() - started < 4 and inStation() do
      local ok, pos = pcall(AgentGetScreenPos, agent)
      if not ok or not pos then break end
      local x = pos.x > 0.85 and 0.99 or pos.x < 0.15 and 0.01 or 0.5
      local y = pos.y > 0.85 and 0.99 or pos.y < 0.15 and 0.01 or 0.5
      if (pos.z or 1) <= 0 then x = 0.99 end -- (behind: turn one way round)
      if x == 0.5 and y == 0.5 then break end
      if TWDA.setPointer then TWDA.setPointer(x, y) end
      WaitForNextFrame()
    end
    if TWDA.setPointer then TWDA.setPointer(0.5, 0.5) end
  end)
end

local function use(h, verbIndex)
  if h.lookOnly then
    TWDA.log("lookaround2: turning the view to " .. TWDA.agentName(h.agent))
    current, chosenVerb = nil, nil
    busyUntil = TWDA.now() + 1
    turnViewTo(h.agent)
    return
  end
  if h.dragOnly then
    TWDA.log("lookaround2: taking hold of the drag " .. TWDA.agentName(h.agent))
    current, chosenVerb = nil, nil
    busyUntil = TWDA.now() + 1
    TWDA.pickDrag(h.agent)
    return
  end
  local verb = h.verbs[verbIndex or 1] or h.verbs[1]
  local agent = h.agent
  busyUntil = TWDA.now() + 1
  TWDA.log(("lookaround2: %s, %s"):format(TWDA.agentName(agent), verbText(verb)))
  -- (What is on offer changes after a use; the next Tab starts again from the top.)
  current, chosenVerb = nil, nil
  lastUsed = { agent = agent, verb = verbText(verb), index = verbIndex or 1 }
  -- (Some uses play inside a scene that never leaves play mode, a blow at a walker: look again a
  -- moment later.)
  recheckAt = TWDA.now() + 1.5
  local d = h.distance and math.floor(h.distance + 0.5) or 0
  if d >= 3 and not combatMode() and verbText(verb) ~= "" then
    speak(("%s %s, walking there."):format(verbText(verb), h.label))
  end
  local startPos = playerPos()
  local fight = combatMode()
  -- (Its second argument runs there, as a double click does: walking pace is slow, ten meters
  -- across the yard at Carver's compound in Episode 3 took over half a minute.)
  local run = d >= RUN_METERS and not fight
  local ok, err = pcall(ThreadStart, function()
    usedAgent = nil
    local okUse, errUse = pcall(function()
      Reticle_SelectAgent(agent)
      ReticleSelection_Lock(true)
      ReticleVerbs_SetActiveVerb(verb)
      Navigate_PathToAndUseAgent(agent, run)
    end)
    if not okUse then TWDA.log("lookaround2: use failed: " .. tostring(errUse)) end
    -- (Navigate_PathToAndUseAgent gives up without a word when the path-finding cannot get there,
    -- as with doors upstairs; the use itself goes through Game_UseAgent.)
    -- (Only when nothing at all happened: no use of anything, Clementine where she was, outside
    -- fights, whose targets are used in other ways.)
    local here = playerPos()
    local moved = startPos and here and VectorDistance(startPos, here) > 0.3
    -- (Michonne's scenes switch the walk-to-use off for her now and then, Navigate_IsAgentPathingEnabled
    -- false: the ferry's deck door, Episode 1. There a click uses the thing where she stands, as
    -- Game_UseAgent does.)
    -- (She may turn on the spot first, so a small move counts as none here; and the game is given a
    -- moment to use it itself.)
    -- (Michonne's navigate.lua also gives up after the walk when AgentPathToAgent does not report
    -- arriving: she stood 3 m from Paige with the ammo, Episode 3, and at the apartment's bedroom
    -- door. A walk that ends near it counts as arriving.)
    local okP, pathing = pcall(rawget(G, "Navigate_IsAgentPathingEnabled") or function() return true end,
      Game_GetPlayer and Game_GetPlayer() or nil)
    local nearNow = (distanceTo(agent) or 99) < 4
    if okUse and usedAgent == nil and ((okP and pathing == false) or (moved and nearNow and isSeason2Michonne())) then
      local waitUntil = TWDA.now() + 0.6
      while usedAgent == nil and TWDA.now() < waitUntil do WaitForNextFrame() end
      if usedAgent == nil and playMode() and call("Navigate_IsPathing") ~= true then
        TWDA.log("lookaround2: walking is off; using " .. TWDA.agentName(agent) .. " from here")
        local okG, errG = pcall(Game_UseAgent, agent)
        if not okG then TWDA.log("lookaround2: use failed: " .. tostring(errG)) end
      end
    end
    if okUse and usedAgent == nil and not moved and not fight and not combatMode() and playMode() then
      pcall(ReticleSelection_Lock, false)
      TWDA.log("lookaround2: could not get to " .. TWDA.agentName(agent))
      if lastUsed and lastUsed.agent == agent then lastUsed = nil end
      speak(("Can't get to %s from here."):format(h.label))
    end
  end)
  if not ok then TWDA.log("lookaround2: " .. tostring(err)) end
end

local function enter()
  if TWDA.now() < busyUntil then return end
  -- (A target in a fight comes first: a walker out of the snowstorm, Episode 5, while walking.)
  if walk and not (combatMode() and anyUsable()) then
    local here = playerPos()
    speak(("Walking to %s, %d meters to go."):format(walk.label, here and math.floor(horizontalDistance(here, walk.target) + 0.5) or 0))
    return
  end
  local h = findCurrent()
  if h and h.place then
    current, chosenVerb = nil, nil
    startWalk(h)
    return
  end
  if not h then
    local list = hotspots()
    -- (In a fight any target will do: the nearest in view.)
    if #list == 1 or (#list > 1 and combatMode()) then
      h = list[1]
    else
      local placesToo = #list == 0 and #places() > 0
      speak(placesToo and TWDA.tabWords("Nothing to interact with here. Tab for places to walk to.")
        or (#list == 0 and "Nothing to interact with here." or TWDA.tabWords("Nothing chosen. Tab to choose something.")))
      return
    end
  end
  use(h, chosenVerb)
end

local function chooseVerb(n)
  local h = findCurrent()
  if not h then return end
  if not h.verbs[n] then
    speak(("%s has %d %s."):format(h.label, #h.verbs, #h.verbs == 1 and "action" or "actions"))
    return
  end
  chosenVerb = n
  speak(verbText(h.verbs[n]))
end

-- F6: everything there is to interact with.
local previousDescribe = TWDA.describeLookaround
TWDA.describeLookaround = function()
  if not isSeason2() or not playMode() then return previousDescribe and previousDescribe() or nil end
  local list = hotspots()
  local walkTo = (combatMode() and #list > 0) and {} or places()
  local sentences = {}
  if walk then sentences[#sentences + 1] = "Walking to " .. walk.label end
  local parts = {}
  for _, h in ipairs(list) do
    local where = whereText(h)
    parts[#parts + 1] = entryText(h, false) .. (where ~= "" and (" (" .. where .. ")") or "")
  end
  sentences[#sentences + 1] = #list == 0 and "Nothing to interact with here"
    or ("%d to interact with: %s"):format(#list, table.concat(parts, ", "))
  if #walkTo > 0 then
    local names = {}
    for _, p in ipairs(walkTo) do names[#names + 1] = ("%s (%s)"):format(p.label, whereText(p)) end
    sentences[#sentences + 1] = ("Places to walk to: %s"):format(table.concat(names, ", "))
  end
  sentences[#sentences + 1] = TWDA.tabWords("Tab and Enter to use")
  return TWDA.joinSentences(sentences)
end

-- For beacons.lua: where Clementine (or Javier) walks freely, what can be used, the places to walk
-- to (as Tab has them) and the walkers that go about with triggers of their own ("trigger_zombie3"
-- in A New Frontier's herd, Episode 5), each with a kind ("thing", "place" or "walker") and a point
-- in the world. Fight targets named after walkers ("obj_throwRockAtZombie1") sound as walkers.
-- (Things are taken from the usables, with their verbs looked at only every few seconds to leave
-- out those with none: building verbs twice a second would keep resetting the reticle's own.)
local hasVerbs = setmetatable({}, { __mode = "k" }) -- agent -> { yes, at }
local function offersVerbs(agent)
  local now = TWDA.now()
  local known = hasVerbs[agent]
  if known and now - known.at < 3 then return known.yes end
  local yes = #verbsOf(agent) > 0
  hasVerbs[agent] = { yes = yes, at = now }
  return yes
end

local function isWalkerTrigger(lower)
  return lower:find("^trigger_zombie%d") or lower:find("^trigger_zombielow") or lower:find("^trigger_walker%d")
end

local previousBeacons = TWDA.beaconEntries
function TWDA.beaconEntries()
  if not isSeason2() then return previousBeacons and previousBeacons() or {} end
  if not playMode() or not canWalk() then return {} end
  local list = {}
  local chosen = current and current.agent
  local things = 0
  for _, agent in pairs(getUsables() or {}) do
    if type(agent) == "table" and usableNow(agent) and offersVerbs(agent) then
      local okP, point = pcall(AgentGetWorldPos, agent)
      if okP and point then
        local lower = TWDA.agentName(agent):lower()
        local walker = lower:find("zombie", 1, true) or lower:find("walker", 1, true)
        list[#list + 1] = { agent = agent, label = TWDA.agentName(agent), kind = walker and "walker" or "thing",
          point = point, chosen = agent == chosen }
        things = things + 1
      end
    end
  end
  -- (As in Tab's list: in a fight, places only when there is nothing to hit.)
  if not combatMode() or things == 0 then
    for _, p in ipairs(places()) do
      list[#list + 1] = { agent = p.agent, label = p.label, kind = "place", point = p.target, chosen = p.agent == chosen }
    end
  end
  local okS, agents = pcall(SceneGetAgents, TWDA.playerScene and TWDA.playerScene() or call("Game_GetScene"))
  for _, agent in ipairs(okS and type(agents) == "table" and agents or {}) do
    local name = TWDA.agentName(agent)
    if isWalkerTrigger(name:lower()) and prop(agent, "Trigger Enabled") == true then
      local okP, point = pcall(AgentGetWorldPos, agent)
      if okP and point then list[#list + 1] = { agent = agent, label = name, kind = "walker", point = point } end
    end
  end
  return list
end

-- When the player is given control, or the things to interact with change while they have it,
-- say what there is once (a second later, when things have settled). Nothing is said when it is
-- the same as last time.
local wasPlay, settleFrom, checkPending = false, 0, false
local lastNames, namesCheckedAt, lastSignature, fromNothing = nil, 0, nil, false
local function usableNames()
  local names = {}
  for _, agent in pairs(getUsables() or {}) do
    if type(agent) == "table" and usableNow(agent) then names[#names + 1] = TWDA.agentName(agent) end
  end
  table.sort(names)
  return table.concat(names, ",")
end

-- Whether the things on offer are all of one kind (three walkers to shoot): then naming the first
-- is enough.
local function allAlike(list)
  for i = 2, #list do
    if list[i].name ~= list[1].name then return false end
  end
  return true
end

local function announceControl()
  local now = TWDA.now()
  if not playMode() then
    wasPlay = false
    return
  end
  if not wasPlay then wasPlay, settleFrom, checkPending = true, now, true end
  if recheckAt and now >= recheckAt then
    recheckAt, checkPending, settleFrom = nil, true, now - 1
  end
  -- (Targets in a fight can be up for only a few seconds: the walker's head after the rifle
  -- struggle at the lodge, Episode 2, about three. They are looked for more often and said sooner.)
  -- (Something appearing where there was nothing is said sooner too: that walker's head in the
  -- herd is there for two and a half seconds.)
  local fight = combatMode()
  if now - namesCheckedAt > (fight and 0.1 or 0.2) then
    namesCheckedAt = now
    local names = usableNames()
    if names ~= lastNames then
      fromNothing = lastNames == "" or lastNames == nil
      lastNames, settleFrom, checkPending = names, now, true
    end
  end
  if not checkPending or now - settleFrom < ((fight or fromNothing) and 0.3 or 1) then return end
  -- (A New Frontier: a moment between two prompts of one QTE is no time to explore; fight targets
  -- are still said.)
  if not fight and TWDA.qteBusy and TWDA.qteBusy() then return end
  checkPending = false
  local list = hotspots()
  local parts = {}
  for _, h in ipairs(list) do parts[#parts + 1] = entryText(h, false) end
  -- (The same things in another order, as Clementine moves, are not news.)
  -- (Which things, not only what they are called: after one walker is chopped in the herd,
  -- Episode 3, the next is "Walker: Chop" too.)
  local sorted = {}
  for i, p in ipairs(parts) do sorted[i] = TWDA.agentName(list[i].agent) .. "=" .. p end
  table.sort(sorted)
  local signature = table.concat(sorted, ";")
  -- The thing just used, still offered with the same action (a walker that takes several blows):
  -- offer it again, and let Enter repeat it.
  local used = lastUsed
  lastUsed = nil
  if used and (REPEATABLE[used.verb:lower()] or (used.verb == "" and combatMode()) or #list == 1) then
    for _, h in ipairs(list) do
      local again = h.agent == used.agent and h.verbs[used.index] and verbText(h.verbs[used.index]) == used.verb
      if again and combatMode() and TWDA.settings.actionscenes == "auto" then
        lastSignature = signature
        use(h, used.index)
        return
      elseif again then
        lastSignature = signature
        current, chosenVerb = { agent = h.agent, label = h.label }, used.index
        TWDA.say(("%s again? Enter."):format(used.verb ~= "" and (h.label .. ": " .. used.verb) or h.label))
        return
      end
    end
  end
  if signature == lastSignature or (#list == 0 and lastSignature == nil) then
    lastSignature = signature
    return
  end
  local previousSignature = lastSignature
  lastSignature = signature
  if #list == 0 then
    -- (Not between the prompts of a QTE, even in a fight: the last walker down, Episode 2's
    -- underpass, and then "Up arrow!".)
    if TWDA.qteBusy and TWDA.qteBusy() then
      lastSignature, checkPending = previousSignature, true
      return
    end
    -- (Everything used up: say where the way on is, if there are places to walk to.)
    local walkTo = (canWalk() and not walk) and places() or {}
    if #walkTo > 0 then
      TWDA.say((TWDA.tabWords("%s can move. Nothing to interact with here. %d %s to walk to, Tab to choose.")):format(
        TWDA.playerName and TWDA.playerName() or "You", #walkTo, #walkTo == 1 and "place" or "places"))
    end
    return
  end
  -- (Free walking only where the walking keys work; in hiding places and action moments the
  -- player can only use what is offered, often against the clock.)
  local okMap, walking = pcall(InputMapperIsActive, "Navigate.imap")
  local prefix = (okMap and walking and call("Navigate_IsEnabled") == true)
    and ((TWDA.playerName and TWDA.playerName() or "You") .. " can move. ") or ""
  if combatMode() then
    -- (Targets in a fight: Enter goes for the nearest; in auto mode the mod goes for it.)
    local first = parts[1]
    if TWDA.settings.actionscenes == "auto" then
      TWDA.say(first .. ".")
      use(list[1], nil)
      return
    end
    -- (Two or three are all named: in the herd, Episode 3, they are "Sarita's Arm: Hack Off" and
    -- the walker biting her, a choice that matters.)
    local text
    if #list == 1 then
      text = first .. ". Enter!"
    elseif #list <= 3 and not allAlike(list) then
      text = (TWDA.tabWords("%s, or %s. Enter for the first, or Tab to choose.")):format(table.concat(parts, ", ", 1, #list - 1), parts[#list])
    else
      text = (TWDA.tabWords("%s, and %d more. Enter for the nearest, or Tab to choose.")):format(first, #list - 1)
    end
    TWDA.say(text)
  elseif #list == 1 and #list[1].verbs > 1 then
    current, chosenVerb = { agent = list[1].agent, label = list[1].label }, nil
    TWDA.say(("%s%s. A number picks one, then Enter."):format(prefix, entryText(list[1], true)))
  elseif #list == 1 then
    TWDA.say(("%s%s. Enter to do it."):format(prefix, parts[1]))
  else
    -- (A long list: what is new since last time, then how many more.)
    local what
    if #list <= 4 then
      what = table.concat(parts, ". ")
    else
      local before, new = {}, {}
      for entry in (previousSignature or ""):gmatch("[^;]+") do before[entry:gsub("^[^=]*=", "")] = true end
      for _, part in ipairs(parts) do
        if not before[part] and #new < 3 then new[#new + 1] = part end
      end
      what = (#new > 0 and #new < #list) and ("%s, and %d more"):format(table.concat(new, ". "), #list - #new)
        or (#list .. " things to interact with")
    end
    TWDA.say((TWDA.tabWords("%s%s. Tab to choose.")):format(prefix, what))
  end
end

local VK_TAB, VK_SHIFT, VK_ENTER = TWDA.tabVK or 0x09, 0x10, 0x0D
local KEYS = { VK_TAB, VK_ENTER, 0x31, 0x32, 0x33, 0x34 }
local held = {}
TWDA.onFrame("lookaround2", function()
  if not isSeason2() then return end
  -- (Slow mode slows targets in a fight too, as it does the action prompts, action2.lua; only while
  -- there is something to hit or shoot: the snowstorm in Episode 5 is in combat mode throughout.)
  if TWDA.setSlowFor then
    TWDA.setSlowFor("targets", TWDA.settings.actionscenes == "slow" and playMode() and combatMode() and anyUsable())
  end
  announceControl()
  local active = playMode() and not (TWDA.hasChoices and TWDA.hasChoices())
  for _, vk in ipairs(KEYS) do
    local ok, down = pcall(InputPCIsVKeyPressed, vk)
    down = ok and down == true
    if down and not held[vk] and not active and vk == VK_ENTER then
      local okMode, mode = pcall(Game_GetMode)
      TWDA.log(("lookaround2: Enter while not in play (mode %s, reticle %s)"):format(
        tostring(okMode and type(mode) == "table" and rawget(mode, "name")), tostring(call("Reticle_IsEnabled"))))
    end
    if down and not held[vk] and active then
      local okAct, err = pcall(function()
        if vk == VK_TAB then
          local okS, shift = pcall(InputPCIsVKeyPressed, VK_SHIFT)
          cycle((okS and shift) and -1 or 1)
        elseif vk == VK_ENTER then
          enter()
        else
          chooseVerb(vk - 0x30)
        end
      end)
      if not okAct then TWDA.log("lookaround2: " .. tostring(err)) end
    end
    held[vk] = down
  end
end)

-- Close-ups (Game mode "CloseUp", inside the truck at the overlook in Episode 4): the game steps back
-- on S, Down arrow or a right click (CloseUp.imap: CloseUp_OnButtonExit), not on Backspace as in
-- Season 1. The mod says so on the way in, and Backspace steps back too.
-- A New Frontier's close-ups are "stations" (Game mode "Station", station.lua: a door or a car up
-- close, "Right click to back out"; Station.imap has no key for it but 5). Backspace steps back
-- there (Station_OnButtonExit) when the station allows it (Station_AllowExit).
local inCloseUp, backHeld = false, false
TWDA.onFrame("lookaround2.closeup", function()
  if not isSeason2() then return end
  local okMode, mode = pcall(Game_GetMode)
  local name = okMode and type(mode) == "table" and rawget(mode, "name") or nil
  local station = name == "Station"
  local now = name == "CloseUp" or station
  if now and not inCloseUp then
    if not station then
      TWDA.say("Close-up. S steps back.")
    elseif call("Station_AllowExit") ~= false then
      TWDA.say("Close-up. Backspace steps back.")
    end
  end
  inCloseUp = now
  local ok, down = pcall(InputPCIsVKeyPressed, 0x08)
  down = ok and down == true
  if down and not backHeld and now then
    pcall(ThreadStart, function()
      local okExit, err = pcall(station and Station_OnButtonExit or CloseUp_OnButtonExit, {})
      if not okExit then TWDA.log("lookaround2: close-up exit: " .. tostring(err)) end
    end)
  end
  backHeld = down
end)

-- Michonne's UI.imap also opens the pause menu on Backspace (UI_OnButtonMenu, code 8), so stepping
-- back out of a close-up opened the menu as well. Backspace is left to the mod; Escape still opens
-- the menu. Input maps hold their callbacks by reference, taken when the map is activated, so an
-- active UI.imap is switched off and on again once the wrapper is in (tested: the wrapper then
-- gets the key).
local menuWrapper = nil
TWDA.onFrame("lookaround2.backspaceMenu", function()
  local original = rawget(G, "UI_OnButtonMenu")
  if type(original) ~= "function" or original == menuWrapper then return end
  menuWrapper = function(event, ...)
    if type(event) == "table" and event.code == 8 then return end
    return original(event, ...)
  end
  TWDA.wrappers[menuWrapper] = true
  rawset(G, "UI_OnButtonMenu", menuWrapper)
  local okA, active = pcall(InputMapperGetActiveMapperNames)
  for _, map in ipairs(okA and type(active) == "table" and active or {}) do
    if map == "UI.imap" then
      pcall(InputMapperDeactivate, "UI.imap")
      pcall(InputMapperActivate, "UI.imap")
      TWDA.log("lookaround2: Backspace no longer opens the pause menu")
    end
  end
end)
