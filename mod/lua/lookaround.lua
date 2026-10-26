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
-- Tab on something the reticle cannot take from where he stands offers a walk there, and Enter
-- walks him (and F6 gives distances). The number keys pick an action and are remembered until
-- Enter; Backspace steps back out of a close-up (as a right click does), and elsewhere lets go of
-- the hotspot or stops a walk. Escape is left to the game (the pause menu). In a fight (the reticle in
-- combat mode) targets are named from their use dialog ("babysitter: Punch") and Enter goes for
-- the first one on offer.
local TWDA = ...
local G = _G

local VK_TAB, VK_SHIFT, VK_ENTER, VK_BACK = 0x09, 0x10, 0x0D, 0x08
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

-- Actions that only look ("Look At", "Examine", "Observe", "Inspect"), as opposed to doing.
local function looksOnly(verb)
  if type(verb) ~= "string" then return false end
  verb = verb:lower()
  return verb:find("^look") ~= nil or verb:find("^examine") ~= nil or verb:find("^observe") ~= nil
    or verb:find("^inspect") ~= nil
end
TWDA.looksOnly = looksOnly

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

-- The game's own tests (in Reticle_Update) for whether a hotspot can be used right now; the
-- reticle only ever focuses those. agentIsClickableNoDialog is about where it is (on screen, in
-- reach). agentIsClickableDialogOnly asks whether its use dialog's entry is valid now
-- (DialogManager_ItemIsValid): behind the tractor at the dairy, the plow lever only when Lee leans
-- out right, the chock only when he leans left. The game caches that one and refreshes one
-- hotspot per frame; the mod keeps its answers for a moment too.
-- The game's version returns false both when the entry is not valid and when the dialog holding it
-- is not loaded: the game loads dialogs by area, so from the barn side of the dairy the gazebo
-- cannot be used, though walking over there makes it usable. The mod tells the two apart: true,
-- false (not valid: story-locked, such as the gate where Andy and Danny wait until Lee has done
-- the rounds), or nil (not loaded here).
local dialogValid = setmetatable({}, { __mode = "k" }) -- agent -> { valid, at }
local function dialogAllows(agent)
  local now = TWDA.now()
  local cached = dialogValid[agent]
  if cached and now - cached.at < 0.3 then return cached.valid end
  local getCached = TWDA.upvalue(rawget(G, "Reticle_Update"), "CachedUseableQueue_GetCached")
  local fn = TWDA.upvalue(getCached, "agentIsClickableDialogOnly")
  local findDialog = TWDA.upvalue(fn, "findDialogWithNode")
  local key = TWDA.upvalue(fn, "kUseDialog")
  local valid = true
  if type(findDialog) == "function" and key ~= nil then
    local ok, result = pcall(function()
      local node = agent.mProps[key]
      if not node then return false end
      local dlog = findDialog(agent, node)
      if not dlog then return nil end
      return DialogManager_ItemIsValid(dlog, node) == true
    end)
    if ok then valid = result end
  end
  dialogValid[agent] = { valid = valid, at = now }
  return valid
end

local function clickable(agent)
  local fn = TWDA.upvalue(rawget(G, "Reticle_Update"), "agentIsClickableNoDialog")
  if type(fn) ~= "function" then return true end
  local ok, result = pcall(fn, agent)
  if ok and result ~= true then return false end
  return dialogAllows(agent) == true
end

-- Where to put the reticle: the game measures from each hotspot's dot (the marker drawn on the
-- spot to click), in the same screen coordinates as the reticle; the object's own position can be
-- well off it.
-- With the mouse the reticle must also be on the hotspot itself (see tightSelection below), and
-- the dot can sit just off it (Kenny's hand): then a point close by that is on it.
local NEAR = { { 0, 0.03 }, { 0, -0.03 }, { 0.03, 0 }, { -0.03, 0 }, { 0.03, 0.03 }, { -0.03, 0.03 },
  { 0.03, -0.03 }, { -0.03, -0.03 }, { 0, 0.06 }, { 0, -0.06 }, { 0.06, 0 }, { -0.06, 0 } }
local aimCache = setmetatable({}, { __mode = "k" }) -- agent -> { x, y, dx, dy, at }
local function aimPoint(agent)
  local dot = rawget(agent, "dot")
  if dot ~= nil then
    local ok, pos = pcall(AgentGetLogicalScreenPos, dot)
    if ok and pos and pos.x and pos.y then
      local onScreen = pos.x >= 0 and pos.x <= 1 and pos.y >= 0 and pos.y <= 1
      if not onScreen then return pos.x, pos.y end
      local now = TWDA.now()
      local cached = aimCache[agent]
      if cached and now - cached.at < 0.5 and math.abs(cached.x - pos.x) < 0.01 and math.abs(cached.y - pos.y) < 0.01 then
        return pos.x + cached.dx, pos.y + cached.dy
      end
      local dx, dy = 0, 0
      local okHit, hit = pcall(AgentAtScreenPos, Vector(pos.x, pos.y, 0))
      if okHit and hit ~= agent then
        for _, d in ipairs(NEAR) do
          local okNear, near = pcall(AgentAtScreenPos, Vector(pos.x + d[1], pos.y + d[2], 0))
          if okNear and near == agent then dx, dy = d[1], d[2] break end
        end
      end
      aimCache[agent] = { x = pos.x, y = pos.y, dx = dx, dy = dy, at = now }
      return pos.x + dx, pos.y + dy
    end
  end
  local ok, pos = pcall(AgentGetScreenPos, agent)
  if ok and pos then return pos.x, pos.y end
  return nil
end

-- With the mouse and outside fights, the game's Reticle_Update only lets the reticle take a
-- hotspot that is itself what lies under it (AgentAtScreenPos), so one hidden behind something
-- else cannot be used from here: the plow lever and the chock behind the tractor at the dairy,
-- until Lee leans out. The mod aims at the dot, so that is where it looks.
local function tightSelection()
  if call("ReticleUI_InCombatMode") == true or call("Platform_IsBimodal") == true then return false end
  local logic = rawget(G, "Logic")
  local okJoy, joystick = pcall(function() return logic and logic["bUsingJoystick"] end)
  return not (okJoy and joystick)
end

-- Something else in front of the dot means hidden; nothing there at all (Kenny's hand reaching
-- down from the truck in Macon) is not, as the reticle only has to be on the hotspot near its dot.
local function visibleAtDot(agent)
  local x, y = aimPoint(agent)
  if not x then return true end
  local ok, hit = pcall(AgentAtScreenPos, Vector(x, y, 0))
  return not ok or hit == nil or hit == agent
end

-- Invisible trigger volumes are selectable too, but they are not things to interact with.
local function isTrigger(name)
  return name:lower():find("triggeragent", 1, true) ~= nil
end

-- Selectable props with no name, action or use dialog at all (the fourteen items on the
-- drugstore's shelf): nothing would happen with them.
local function isEmpty(agent)
  local ok, empty = pcall(function()
    for _, key in ipairs({ "WDUseable - Name", "WDUseable - Verb", "WDUseable - Action Use Dialog Start Node" }) do
      local value = agent.mProps[key]
      if value ~= nil and value ~= "" then return false end
    end
    return true
  end)
  return ok and empty
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

-- The same for a hotspot, judged by its dot where it has one: a big object (the car in the road)
-- can have its middle just off screen while the spot to click is in view.
local function sideOf(agent, pos)
  if (pos.z or 1) <= 0 then return "behind" end
  local x, y = aimPoint(agent)
  if x and y then return offScreenSide({ x = x, y = y, z = 1 }) end
  return offScreenSide(pos)
end

local SIDE_WORDS = { behind = "behind you", left = "to your left", right = "to your right", up = "above you",
  down = "below you" }
TWDA.sideWords = SIDE_WORDS

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

-- The camera in use and the reticle's camera: a close-up changes the first (the generator at the
-- dairy) while the second stays "reticleCamV".
local function cameraName()
  local cam = call("CameraControlReticle_GetCamera")
  local player = TWDA.player()
  local scene = player and call("AgentGetScene", player)
  local view = scene and call("SceneGetCamera", scene)
  -- (A close-up can keep the camera's name: the meat locker's air conditioner.)
  local closeUp = call("WDBackButton_IsOccupied") == true and "|close-up" or ""
  return (cam ~= nil and TWDA.agentName(cam) or "") .. "|" .. (view ~= nil and TWDA.agentName(view) or "") .. closeUp
end

local function playerPos()
  local player = TWDA.player()
  if player == nil then return nil end
  local ok, pos = pcall(AgentGetWorldPos, player)
  if ok then return pos end
  return nil
end

local function forgetUnreachable()
  unreachable, unreachableFrom, unreachableCamera = {}, nil, nil
end

-- Hotspots Lee has no way to from where he is: a walk there ended well short (see walkTick). Left
-- out of the list until something is used or he has walked well away.
local noWay = {} -- agent name -> true
local noWayFrom = nil -- where Lee was
local NO_WAY_CLEAR_METERS = 10

local function forgetNoWay()
  noWay, noWayFrom = {}, nil
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
-- Places that are no hotspot but worth walking to (stairs): agent name -> what to call it.
local places = {}
-- Places in particular scenes where the way on has no hotspot at all: walking into a trigger
-- starts the next part. Scene script (lower case) -> { agent, name, arrive (said on arrival) }.
local SCENE_PLACES = {
  -- Episode 1, leaving Clementine's house at night: out through the gate, Shawn and Chet turn up
  -- once Lee walks on towards the street (the yard's things are out of reach from there).
  ["env_clementinehouseexterior_night.lua"] = {
    { agent = "trigger_MeetShawnNight", name = "Street" },
  },
  -- Episode 4, the Savannah sewers: once the walkers have gone to the leaking pipe and Lee has
  -- hidden in the low passage, the tunnel goes on to the left to where Chuck lies.
  ["env_savannahsewers.lua"] = {
    { agent = "trigger_dialog_chuck", name = "Way on along the tunnel" },
  },
}
local placeArrive = {} -- agent name -> what to say on arrival
-- Views (close-up cameras that turn with the reticle) where something happens only once the view
-- is turned all the way to one side, with no hotspot there to Tab to. Camera name -> { side, name }.
local SCENE_VIEWS = {
  -- Episode 4, River Street: through the telescope, turned fully left, Lee spots the stranger
  -- running into the newsstand (env_savannahRiverStreet.lua plays cs_telescopeLooksFarLeft once
  -- reticleCamH's pan is under a tenth from the left end). The story waits for it.
  cam_panningTelescope = { { side = "left", name = "Far left" } },
}
local stairAgents, stairScanAt = {}, -10

-- The nearest stair trigger on Lee's floor (trigger_dialog_leeStairsBottom at the foot of the
-- farmhouse stairs, ...Top at the top), from the scene's agents (looked through every few seconds).
local nearestStairs

-- " It is upstairs." and the like, for a goal on another floor; only in scenes with stairs (the
-- air conditioner high on the meat locker's wall is no floor up).
local function floorOf(agent)
  if #stairAgents == 0 then return nil end
  local from = playerPos()
  local okTo, to = pcall(AgentGetWorldPos, agent)
  if not from or not okTo or not to then return nil end
  if to.y - from.y > 2.6 then return "upstairs" end
  if from.y - to.y > 2.6 then return "downstairs" end
  return nil
end

function nearestStairs()
  local now = TWDA.now()
  if now - stairScanAt > 5 then
    stairScanAt, stairAgents = now, {}
    local player = TWDA.player()
    local scene = player and call("AgentGetScene", player)
    local okA, agents = pcall(SceneGetAgents, scene)
    for _, agent in ipairs(okA and type(agents) == "table" and agents or {}) do
      local name = TWDA.agentName(agent):lower()
      -- (Not the camera "chorebox" volumes, which can lie well away from the stairs, nor camera
      -- triggers named after a floor: trigger_cam_upstairsWide in the Savannah house, Episode 4.)
      if name:find("^trigger") and name:find("stair", 1, true) and not name:find("chorebox", 1, true)
        and not name:find("^trigger_cam") then
        stairAgents[#stairAgents + 1] = agent
      end
    end
  end
  local from = playerPos()
  if not from then return nil end
  local best, bestDistance = nil, math.huge
  for _, agent in ipairs(stairAgents) do
    local ok, p = pcall(AgentGetWorldPos, agent)
    if ok and p and math.abs(p.y - from.y) < 1 then
      local d = (p.x - from.x) ^ 2 + (p.z - from.z) ^ 2
      if d < bestDistance then best, bestDistance = agent, d end
    end
  end
  return best
end

local listOrder, listKey = {}, ""
local listMoves = 0 -- goes up whenever the order is worked out again because Lee has moved
local listFrom = nil -- where Lee was when the order was worked out

-- The hotspots on offer. In look-around scenes that includes usable things out of view, which
-- the camera turns to (the shotgun shell and the shotgun beside Lee at the zombie cop).
local function hotspots()
  local useables = TWDA.upvalue(rawget(G, "Reticle_Update"), "mUseables")
  local list = {}
  if type(useables) ~= "table" then return list end
  local canTurn = panningCamera()
  local walk = canWalk()
  -- While the arrow keys turn Lee (turnchoice.lua), only what is in view: holding the reticle at
  -- a screen edge would turn him too.
  local turning = TWDA.turnChoiceActive and TWDA.turnChoiceActive()
  if turning then canTurn, walk = false, false end
  -- (But what lies on a side the arrows turn to is listed, to be announced with the arrow to
  -- press: the walker coming down the stairs while Lee pulls at his stuck leg in Crawford.)
  local turnSides = turning and TWDA.turnChoiceSides and TWDA.turnChoiceSides() or {}
  -- In a close-up (the game's Back button is set: the generator at the dairy, Carley's radio)
  -- only what is close by: steering the reticle to the rest of the area pans the close-up away
  -- (the wind chimes, 12 meters from the generator), but something just below its edge counts
  -- (the power cord by the farmhouse closet).
  local closeUp = call("WDBackButton_IsOccupied") == true
  if closeUp then walk = false end
  local tight = tightSelection()
  for _, agent in ipairs(useables) do
    local name = TWDA.agentName(agent)
    local okHidden, isHidden = pcall(AgentIsHidden, agent)
    -- (Not those whose use is not valid yet, whatever the view: the gate where Andy and Danny wait
    -- at the dairy only opens once Lee has done the rounds; walking there would do nothing.)
    if name ~= "" and not isPlayer(name) and not isTrigger(name) and prop(agent, "Game Selectable") == true and not isEmpty(agent)
      and not (okHidden and isHidden) and dialogAllows(agent) ~= false then
      local okPos, pos = pcall(AgentGetScreenPos, agent)
      -- (A thing marked unreachable after a failed try counts again once it is within reach: the
      -- doctor's corpse in the Crawford alley, issue #20.)
      if okPos and pos and (not (unreachable[name] or noWay[name]) or clickable(agent)) then
        local side = sideOf(agent, pos)
        if closeUp and side ~= nil and (distanceTo(agent) or 99) > 3 then side = "away" end
        local canClick = side ~= "away" and clickable(agent) and (side ~= nil or not tight or visibleAtDot(agent))
        -- Where Lee walks freely, also things in view that he must first walk up to (the game's
        -- clickable test wants him at their use position unless they can be used from afar).
        if side ~= "away" and ((canClick and (side ~= "behind" or canTurn)) or (canTurn and side ~= nil) or (walk and side == nil)
          or (side ~= nil and turnSides[side])) then
          list[#list + 1] = { agent = agent, name = name, x = pos.x, y = pos.y, behind = side == "behind",
            side = side, clickable = canClick, n = #list }
        end
      end
    end
  end
  -- Stairs are no hotspot, but walking onto them starts a guided path up or down (the dairy
  -- farmhouse; the path-finding does not take them): where Lee walks, the nearest on his floor is
  -- offered as a place to walk to.
  local stairs = walk and nearestStairs()
  if stairs then
    local okPos, pos = pcall(AgentGetScreenPos, stairs)
    if okPos and pos then
      local side = sideOf(stairs, pos)
      local name = TWDA.agentName(stairs)
      places[name] = "Stairs"
      list[#list + 1] = { agent = stairs, name = name, x = pos.x, y = pos.y, behind = side == "behind",
        side = side, clickable = false, n = #list, place = true }
    end
  end
  local script = tostring(rawget(G, "TWDA_firstScript") or ""):lower()
  for _, place in ipairs(walk and SCENE_PLACES[script] or {}) do
    local okFind, agent = pcall(AgentFind, place.agent)
    local okPos, pos = pcall(AgentGetScreenPos, agent)
    if okFind and agent ~= nil and okPos and pos and call("AgentIsHidden", agent) ~= true
      and prop(agent, "Trigger Enabled") ~= false then
      local side = sideOf(agent, pos)
      places[place.agent] = place.name
      placeArrive[place.agent] = place.arrive or ("At the " .. place.name:lower() .. ".")
      list[#list + 1] = { agent = agent, name = place.agent, x = pos.x, y = pos.y, behind = side == "behind",
        side = side, clickable = false, n = #list, place = true }
    end
  end
  local player = TWDA.player()
  local view = player and call("SceneGetCamera", call("AgentGetScene", player))
  for _, pan in ipairs(view ~= nil and SCENE_VIEWS[TWDA.agentName(view)] or {}) do
    local name = "view:" .. pan.side
    places[name] = pan.name
    list[#list + 1] = { agent = view, name = name, x = 0.5, y = 0.5, clickable = false, n = #list, place = true,
      pan = pan.side }
  end
  local names = {}
  for _, entry in ipairs(list) do names[#names + 1] = entry.name end
  table.sort(names)
  local key = table.concat(names, "|")
  -- Where Lee walks about, the order is worked out again once he has moved.
  local here = playerPos()
  local moved = false
  if here and listFrom then
    local okDist, dist = pcall(VectorDistance, here, listFrom)
    moved = okDist and type(dist) == "number" and dist > 1.5
  end
  if key ~= listKey or moved then
    listKey, listOrder, listFrom = key, {}, here
    if moved then listMoves = listMoves + 1 end
    -- In view first, then out of view to a side, then behind; where Lee walks about, nearest
    -- first within each (28 things at the dairy, the gate he needs 2 meters away).
    local function rank(entry) return entry.pan and 3 or entry.behind and 2 or entry.side and 1 or 0 end
    local distances = {}
    if walk then
      for _, entry in ipairs(list) do distances[entry] = distanceTo(entry.agent) or math.huge end
    end
    table.sort(list, function(a, b)
      if rank(a) ~= rank(b) then return rank(a) < rank(b) end
      if walk and distances[a] ~= distances[b] then return distances[a] < distances[b] end
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

-- Agent names made readable where the game gives no name: "obj_doorManor" -> "door manor". A
-- character's agent keeps its capitals ("ChristaAndOmid" -> "Christa and Omid").
local PRETTY = { ["bottle breakable"] = "bottle", ["door manor"] = "front door" }
-- Words after "zombie" that name a part of one, not the model of a walker.
local ZOMBIE_PARTS = { arm = true, arms = true, hand = true, hands = true, head = true, leg = true, legs = true,
  foot = true, body = true, corpse = true }
local function prettyName(agentName)
  local person = agentName:find("^%u%l") ~= nil
  local name = agentName:gsub("^obj_", ""):gsub("^char_", ""):gsub("^peek", ""):gsub("%d+$", "")
  name = name:gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
  local second = name:match("^[Zz]ombie (%a+)")
  if second and not ZOMBIE_PARTS[second:lower()] then return "zombie" end -- (ZombieAverage1)
  if person then
    return (name:gsub(" (%a+)", function(word)
      local lower = word:lower()
      if lower == "and" or lower == "of" or lower == "the" then return " " .. lower end
      return " " .. word
    end))
  end
  name = name:lower()
  return PRETTY[name] or name
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
  if okText and type(text) == "string" and text ~= "" then
    -- A name key with no text behind it comes back as itself ("zombieArm" in the Savannah
    -- sewers, Episode 4): made readable.
    if text:match("^[%a_][%w_]*$") and (text:find("%l%u") or text:find("_")) then
      text = text:gsub("%d+$", ""):gsub("(%l)(%u)", "%1 %2"):gsub("_", " "):lower()
      text = text:sub(1, 1):upper() .. text:sub(2)
    end
    return TWDA.cleanText(text)
  end
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
  if not (okText and type(text) == "string" and text ~= "") then text = type(verb) == "string" and verb or nil end
  if not text then return nil end
  -- "Cs" marks things that play a short scene when looked at (the walkers seen from cover at the
  -- Motor Inn).
  if text:lower() == "cs" then return "Look" end
  -- An unresolved verb key ("verb_break" on the attic wall, Episode 5): the word in it.
  local word = text:match("^[Vv]erb_(%a[%w_]*)$")
  if word then
    word = word:gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
    text = word:sub(1, 1):upper() .. word:sub(2)
  end
  return TWDA.cleanText(text)
end

-- Targets in fights (the reticle in combat mode, such as the babysitter's face to punch) have no
-- name or verb and show no tooltip; only their use dialog node says what they are:
-- "punch_babySitter" -> "baby sitter", "Punch". Nil for anything else.
local USE_NODE = "WDUseable - Action Use Dialog Start Node"

local ADVERBS = { away = true, back = true, off = true, out = true, over = true, around = true }
-- A "name" that only completes the verb: "Away" with "Drive" for Shel's way out of the camp (400
-- Days), shown by the game as "Drive Away". Read as one phrase, not "Away: Drive".
function TWDA.isAdverbName(name)
  return type(name) == "string" and ADVERBS[name:lower()] == true
end

local function nodeLabel(agent)
  if gameName(agent) ~= nil then return nil end
  local ok, node = pcall(function() return agent.mProps[USE_NODE] end)
  if not ok or type(node) ~= "string" then return nil end
  local verb, object = node:match("^(%a+)_(%a[%w_]*)$")
  if not verb then return nil end
  -- "walk_away" (Kenny, at the end of the dairy) is an action, not a thing called "away"; a
  -- character keeps its own name.
  if ADVERBS[object:lower()] then
    local who = TWDA.agentName(agent)
    local action = verb:sub(1, 1):upper() .. verb:sub(2):lower() .. " " .. object:lower()
    return (who:find("^%u%l+$") and who or action), action
  end
  -- "cs_" nodes are short scenes played when the thing is looked at.
  if verb:lower() == "cs" then verb = "look" end
  object = object:gsub("%d+$", ""):gsub("(%l)(%u)", "%1 %2"):gsub("_", " "):lower()
  object = object:match("^%s*(.-)%s*$") -- ("shoot_zombie_2" left "zombie " with a space)
  object = object:gsub("baby sitter", "babysitter")
  object = PRETTY[object] or object
  return object, verb:sub(1, 1):upper() .. verb:sub(2):lower()
end

-- People the game labels alike are told apart by their own names: "Prisoner" for both Danny and
-- Justin, chained together on the bus in 400 Days (agents "Dan" and "Justin"), when Vince must
-- shoot one of them free. Name -> true, for names two or more characters on offer share.
local function isCharacterAgent(agentName)
  local lower = agentName:lower()
  return agentName:find("^%u%a+%d*$") ~= nil and not lower:find("zombie", 1, true) and not lower:find("walker", 1, true)
end
local sharedAt, shared = -10, {}
local function sharedNames()
  local now = TWDA.now()
  if now - sharedAt < 0.5 then return shared end
  sharedAt, shared = now, {}
  local agentsByName = {}
  for _, agent in ipairs(TWDA.upvalue(rawget(G, "Reticle_Update"), "mUseables") or {}) do
    local agentName = TWDA.agentName(agent)
    if isCharacterAgent(agentName) then
      if knownNames[agentName] == nil then knownNames[agentName] = gameName(agent) or nodeLabel(agent) end
      local name = knownNames[agentName]
      if name then
        agentsByName[name] = agentsByName[name] or {}
        agentsByName[name][agentName] = true
      end
    end
  end
  for name, agents in pairs(agentsByName) do
    if next(agents, next(agents)) ~= nil then shared[name] = true end
  end
  return shared
end
local function distinctName(agentName, name)
  if not (type(name) == "string" and isCharacterAgent(agentName) and sharedNames()[name]) then return name end
  local own = prettyName(agentName)
  return own ~= name and own or name
end

local function displayName(agentName, agent)
  if places[agentName] then return places[agentName] end
  -- (Controls in a row that the game names alike, panels.lua: "Switch 2 of 7".)
  local label = TWDA.hotspotLabel and TWDA.hotspotLabel(agentName)
  if label then return label end
  if not knownNames[agentName] and agent ~= nil then knownNames[agentName] = gameName(agent) or nodeLabel(agent) end
  local name = knownNames[agentName] or prettyName(agentName)
  -- (Walkers named after their model: "zombie large low slave a" in the gauntlet, Episode 5. Not
  -- a part of one: "zombie arm", the walker holding Lee's leg in the Savannah sewers, beside a
  -- "Zombie" to attack.)
  local second = type(name) == "string" and name:lower():match("^zombie (%a+)")
  if second and not ZOMBIE_PARTS[second] then return "zombie" end
  return distinctName(agentName, name)
end

-- The nearest thing within 3 meters, a way out (door, ladder, stairs, gate, hatch, exit) before
-- anything else: from inside the boxcar or the train's cab (Episode 3) only the door leads
-- anywhere, with Kenny standing closer. Returns the list entry and its distance, or nil.
local function nearestWayOut(exceptName)
  local nearest, nearestDistance, nearestExit = nil, math.huge, false
  for _, entry in ipairs(hotspots()) do
    local d = entry.name ~= exceptName and distanceTo(entry.agent)
    if d and d <= 3 then
      local label = displayName(entry.name, entry.agent):lower()
      local exit = label:find("door", 1, true) or label:find("ladder", 1, true) or label:find("stair", 1, true)
        or label:find("gate", 1, true) or label:find("hatch", 1, true) or label:find("exit", 1, true)
      if (exit and not nearestExit) or (exit or not nearestExit) and d < nearestDistance then
        nearest, nearestDistance, nearestExit = entry, d, exit ~= nil
      end
    end
  end
  return nearest, nearest and nearestDistance or nil
end

-- What stands in front of a hotspot whose marker is on screen, when the game has put a blocker
-- there ("blocker_alley" before the truck stop's back door in 400 Days, from the kitchen side: the
-- way is through the back hall). Its name, or nil.
local function blockerInFront(agent)
  local dot = rawget(agent, "dot")
  local okPos, pos = pcall(AgentGetLogicalScreenPos, dot)
  if dot == nil or not okPos or not pos or pos.x < 0 or pos.x > 1 or pos.y < 0 or pos.y > 1 then return nil end
  local okHit, hit = pcall(AgentAtScreenPos, Vector(pos.x, pos.y, 0))
  local name = okHit and hit ~= nil and TWDA.agentName(hit) or ""
  return name:lower():find("^blocker") and name or nil
end

-- The verb shown for a hotspot, or the one its use node implies for a fight target.
local function hotspotVerb(agent)
  local verb = gameVerb(agent)
  if verb then return verb end
  local _, nodeVerb = nodeLabel(agent)
  return nodeVerb
end

---------------------------------------------------------------------------------------------------
-- Reading what the game shows.
---------------------------------------------------------------------------------------------------

local current = { noun = nil, verb = nil, actions = {} }
local lastActions = nil -- { name, actions }: the last hotspot's actions, kept when the focus lapses
local lastSpoken, lastSpokenAt = nil, -10
local target = nil -- { agent, name, since, index, count }
-- The last hotspot chosen with Tab that the reticle cannot take from here, and what Enter does
-- about it: { agent, name, at, kind = "walk" (walk there) or "use" (use it from here) }.
local walkOffer = nil

-- The tooltip's name for an object, or nil plus the raw key when it is a text key that does not
-- resolve ("text_Car" on the car in the road).
local function nounText(noun)
  if type(noun) ~= "string" or noun == "" then return nil end
  local ok, text = pcall(Dialog_GetText, noun, nil, "text.dlog")
  if ok and type(text) == "string" and text ~= "" then return TWDA.cleanText(text) end
  local resolved = TWDA.keyOrText(noun)
  if resolved then return resolved end
  return nil, noun
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
  -- How a control is set, where a puzzle depends on it (panels.lua): "Switch 2 of 7, up".
  local noun = current.noun
  if current.agent ~= nil then
    local name = TWDA.agentName(current.agent)
    local label = TWDA.hotspotLabel and TWDA.hotspotLabel(name)
    local state = TWDA.hotspotState and TWDA.hotspotState(current.agent)
    if label then noun = label end
    if state then noun = noun .. ", " .. state end
  end
  local actions = actionList()
  if #actions <= 1 and TWDA.isAdverbName(noun) and current.verb and current.verb ~= "" then
    return current.verb .. " " .. noun:lower()
  end
  if #actions > 1 then
    local parts = {}
    for i, action in ipairs(actions) do parts[#parts + 1] = i .. " " .. action end
    return noun .. ": " .. table.concat(parts, ", ")
  end
  -- (Some close-up controls are named after their action: "Flip the Radio Over".)
  if current.verb and current.verb ~= "" and current.verb ~= current.noun then return noun .. ": " .. current.verb end
  return noun
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
  -- A hint that has just asked for this very action ("Grab the gun!!" with the reticle on "Rifle:
  -- Grab", the farmhouse barn): say the key too.
  local verbWord = type(current.verb) == "string" and current.verb:lower():match("^(%a+)")
  if verbWord and #verbWord >= 3 and type(TWDA.lastHint) == "string" and TWDA.now() - (TWDA.lastHintAt or -10) < 5
    and TWDA.lastHint:lower():find(verbWord, 1, true) then
    text = text .. ". Enter!"
  end
  -- A fight target the reticle landed on by itself is announced with its key by actions.lua.
  if current.fightTarget and not target then return end
  -- Running for it (runto.lua): the reticle passing over people ("Dee: Yell To") must not cut the
  -- keys off (Bonnie's run in 400 Days).
  if not target and TWDA.runtoActive and TWDA.runtoActive() then return end
  if TWDA.now() < quietUntil and not (target and target.name == TWDA.agentName(current.agent)) then return end
  if text == lastSpoken and TWDA.now() - lastSpokenAt < 1.5 then return end
  -- A fight target just announced with its key (actions.lua): do not cut that short.
  if current.fightTarget and TWDA.lastSpoken and TWDA.lastSpoken:find(text, 1, true) == 1
    and TWDA.now() - (TWDA.lastSpokenAt or -10) < 2 then return end
  lastSpoken, lastSpokenAt = text, TWDA.now()
  TWDA.say(text, { interrupt = true })
end

-- The action icons for the focused object, in the order of their number keys.
-- The moment to strike. In fights the reticle closes on the target when it is not yet in reach
-- (Lee: "Wait for it..."; a press then does nothing) and opens again on the same target when it
-- is: the walker coming round the RV at the Motor Inn, the babysitter's face coming back. That
-- second opening is announced ("Now! Enter!"), and in auto mode acted on.
local lastStrikeName, contractedAt, strikeAt = nil, -10, nil
TWDA.hookBefore("ReticleUI_Contract", function() contractedAt = TWDA.now() end)

-- Outside fights too, the same thing offered again a moment after it was used means another go:
-- the zombie pilot in the Macon pharmacy takes two blows ("Again! Enter!"). Only for something
-- with a single action that is not looking: after a look, the reticle just comes back to it.
local lastUsed = { name = nil, at = -10 }
-- A blow or a shot ("Punch", "Shoot"): taken again at the same thing, it means another go.
local function isBlow(verb)
  verb = tostring(verb or ""):lower()
  for _, word in ipairs({ "punch", "hit", "kick", "stab", "strike", "smash", "bash", "shove", "elbow", "headbutt",
    "stomp", "chop", "shoot", "fire" }) do
    if verb:find("^" .. word) then return true end
  end
  return false
end
local function checkStrike(focused, actions)
  if focused == nil then return end
  if call("ReticleUI_InCombatMode") ~= true then
    local name = TWDA.agentName(focused)
    local single = type(actions) == "table" and #actions == 1 and not looksOnly(tostring(actions[1]))
      and not tostring(actions[1]):lower():find("talk", 1, true)
    -- (Characters only, "zombiePilot": a gate or door is simply offered again after its use; and
    -- not talking: Clementine is offered again when a short talk with her ends. Or a blow at a
    -- part of someone: "Attacker: Punch" on obj_armNate, reaching into the car in 400 Days, takes
    -- several, and Wyatt died after one.)
    local character = not name:lower():find("^obj_")
    local blow = single and isBlow(actions[1])
    if single and (character or blow) and name == lastUsed.name and TWDA.now() - lastUsed.at < 10 then
      lastUsed.name = nil
      TWDA.log("lookaround: again at " .. name)
      TWDA.say("Again! Enter!", { interrupt = true })
    end
    return
  end
  local name = TWDA.agentName(focused)
  -- (Not while something to deal with waits on a side the arrows turn to: the walker coming down
  -- the stairs comes before another pull at Lee's stuck leg, Crawford, Episode 4.)
  local waiting = false
  if TWDA.turnChoiceActive and TWDA.turnChoiceActive() and TWDA.turnChoiceSides then
    local sides = TWDA.turnChoiceSides()
    for _, entry in ipairs(hotspots()) do
      local verb = tostring(hotspotVerb(entry.agent) or ""):lower()
      local threat = verb:find("shoot") or verb:find("attack") or verb:find("hit") or verb:find("kill")
        or verb:find("stab") or verb:find("kick") or verb:find("shove") or verb:find("punch") or verb:find("bash")
      if entry.side ~= nil and sides[entry.side] and entry.name ~= name and threat then waiting = true end
    end
  end
  if waiting then
    lastStrikeName = name
    return
  end
  if name == lastStrikeName and TWDA.now() - contractedAt < 10 then
    strikeAt = TWDA.now()
    TWDA.log("lookaround: strike now at " .. name)
    -- (Where it offers more than one thing to do, the choice is the player's: "Now! Pick a number,
    -- then Enter!")
    local doing = {}
    for i, action in ipairs(type(actions) == "table" and actions or {}) do
      if not looksOnly(tostring(action)) then doing[#doing + 1] = i .. " " .. tostring(action) end
    end
    TWDA.say(#doing > 1 and ("Now! " .. table.concat(doing, ", ") .. ". Pick a number, then Enter!") or "Now! Enter!",
      { interrupt = true })
  end
  lastStrikeName = name
end

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
  current.fightTarget = false
  -- For hotspots whose actions come from a dialog ("Reticle presentation"), this arrives a moment
  -- after the focus; an action must not be started before it (see doAction).
  local focused = call("Reticle_GetAgentFocused")
  current.actionsFor = TWDA.agentName(focused)
  -- Kept after the focus lapses, for the number keys.
  if #actions > 0 then lastActions = { name = current.actionsFor, actions = actions } end
  checkStrike(focused, actions)
  -- A fight target shows no tooltip at all: name it from its use node instead.
  if #actions == 0 and focused ~= nil then
    local object, verb = nodeLabel(focused)
    if object then
      current.agent, current.noun, current.verb, current.at = focused, object, verb, TWDA.now()
      current.actions, current.fightTarget, current.pending = { verb }, true, true
    end
  end
end)

TWDA.hookBefore("Tooltip_Show", function(verb, noun)
  local name, rawKey = nounText(noun)
  -- A name key with no text behind it can come back as itself ("zombieArm" in the Savannah
  -- sewers): treated as unresolved, so the hotspot's name below is made readable.
  if name and name:match("^[%a_][%w_]*$") and (name:find("%l%u") or name:find("_")) then name, rawKey = nil, true end
  local focused = call("Reticle_GetAgentFocused")
  if not name and rawKey and focused ~= nil then
    -- The hotspot's own name property usually resolves where the tooltip's key does not.
    name = displayName(TWDA.agentName(focused), focused)
  end
  if not name then return end
  if focused ~= nil then
    if not rawKey then knownNames[TWDA.agentName(focused)] = name end
    name = distinctName(TWDA.agentName(focused), name)
    current.agent, current.at = focused, TWDA.now()
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
local cycleMoves = 0 -- listMoves at the last Tab
local preferNext = nil -- name of the hotspot the next Tab goes to (just announced by actions.lua)
-- A hotspot read out with its numbered actions but not pressed on the player (one that offers
-- Shoot): the number keys still mean it. { name, at }
local numbersFor = nil
local preferNextAt = -10
-- The same announcement, kept after Tab has used preferNext, for Enter's choice of action.
local announced = { name = nil, at = -10 }

-- preferNext while it still stands: not after 15 seconds, nor once the reticle has read out
-- something else since. Enter and the number keys both go by it.
local function stillPreferred()
  if preferNext and (TWDA.now() - preferNextAt > 15 or (current.agent ~= nil and (current.at or -10) > preferNextAt + 0.5
    and TWDA.agentName(current.agent) ~= preferNext)) then
    preferNext = nil
  end
  return preferNext
end
local lastTabAt = -10 -- (an announcement made before the last Tab no longer steers Enter)

local function cycle(delta)
  quietUntil = 0
  local list = hotspots()
  if #list == 0 then
    TWDA.say("Nothing to interact with here.", { interrupt = true })
    return
  end
  local index = 0
  local from = target and target.name or lastTargetName
  -- Once Lee has moved, the list is in a new order (nearest first): start again from the top.
  if listMoves ~= cycleMoves then from, lastIndex = nil, 0 end
  cycleMoves = listMoves
  if from then
    for i, entry in ipairs(list) do
      if entry.name == from then index = i end
    end
  end
  local preferred = 0
  for i, entry in ipairs(list) do
    if delta > 0 and entry.name == preferNext then preferred = i end
  end
  preferNext = nil
  if preferred > 0 then
    index = preferred
  elseif index == 0 and lastIndex > 0 then
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
  lastTargetName, lastIndex = entry.name, index
  lastSpoken = nil
  if entry.pan then
    -- A view's far end: turned to at once (see the frame loop), quietly past what is on the way.
    target = { agent = entry.agent, name = entry.name, since = TWDA.now(), pan = entry.pan, camera = cameraName() }
    TWDA.say(("%s, %d of %d. Turning."):format(displayName(entry.name, entry.agent), index, #list), { interrupt = true })
    quietUntil = math.huge
    return
  end
  -- Where Lee walks freely the cameras are fixed: something the game will not let the reticle take
  -- from here is offered as a walk straight away.
  if canWalk() and not clickable(entry.agent) then
    target = nil
    walkOffer = { agent = entry.agent, name = entry.name, at = TWDA.now(), kind = "walk" }
    local where = {}
    if entry.side then where[#where + 1] = SIDE_WORDS[entry.side] end
    local d = distanceTo(entry.agent)
    if d then where[#where + 1] = d .. " meters" end
    TWDA.say(("%s%s. Enter walks there, %d of %d"):format(displayName(entry.name, entry.agent),
      #where > 0 and (", " .. table.concat(where, ", ")) or "", index, #list), { interrupt = true })
    quietUntil = TWDA.now() + 3
    return
  end
  target = { agent = entry.agent, name = entry.name, since = TWDA.now(), index = index, count = #list }
  if TWDA.agentName(call("Reticle_GetAgentFocused")) == entry.name then
    -- Already focused (only one hotspot, or the same one again): the tooltip will not change.
    speakFocus()
  end
end

-- Whether a hotspot's use dialog shows its actions through the reticle ("Reticle presentation" on
-- its choices node). Those only work when the reticle starts the use (see TWDA.useWithReticle);
-- other hotspots can also be used with Main_OnUse directly, which is what Enter falls back to for
-- one the camera cannot show even after walking there.
local USE_FILE = "WDUseable - Action Use Dialog File"

-- The dialog files a hotspot's use node may be in: its own, then the scene's. (Most hotspots have
-- no file of their own, such as the bear trap's Leg; a nil first in the list would stop ipairs.)
local function useDialogs(agent)
  local sceneAgent = SceneGetSceneAgent(AgentGetScene(agent))
  local candidates = { agent.mProps[USE_FILE], sceneAgent.mProps["Dialog Agent - File Primary"],
    sceneAgent.mProps["Dialog Agent - File Secondary"] }
  local files = {}
  for i = 1, 3 do
    if candidates[i] ~= nil then files[#files + 1] = candidates[i] end
  end
  return files
end

-- A hotspot's actions without focusing it, in number-key order, read from the choices node of its
-- use dialog (DlgChoicesGetDisplayProps maps the shown choices' node ids to their texts); nil when
-- it has none (or its choices are not shown as action icons). For announcements ("Zombie:
-- Examine, Stab"), and over a stale verb property (Danny: "Eviscerate", not "Talk To").
local function actionsOf(agent)
  local ok, list = pcall(function()
    local node = agent.mProps[USE_NODE]
    if node == nil or node == "" then return nil end
    for _, dlog in ipairs(useDialogs(agent)) do
      TWDA.trace("actionsOf " .. TWDA.agentName(agent) .. " " .. tostring(node) .. " in " .. tostring(dlog))
      local found = DlgEvaluateToNode(dlog, node, "choices", false)
      if found then
        -- Only choices the game shows as the reticle's action icons; others are conversation.
        if DlgGetObjUserPropsValue(found["Dlog"], found["Node ID"], "Reticle presentation") ~= true then
          return nil
        end
        local props = DlgChoicesGetDisplayProps(found["Dlog"], found["Node ID"]) or {}
        local out = {}
        for _, kid in ipairs(DlgNodeGetChildNodes(found["Dlog"], found["Node ID"]) or {}) do
          for id, display in pairs(props) do
            if tostring(id) == tostring(kid["Node ID"]) and type(display) == "table" then
              local text = display["Choice Display Text"]
              text = TWDA.keyOrText(text) or text
              if type(text) == "string" and text ~= "" then out[#out + 1] = text end
            end
          end
        end
        return out
      end
    end
    return nil
  end)
  if ok and type(list) == "table" and #list > 0 then return list end
  return nil
end

local function presentsChoices(agent)
  local ok, result = pcall(function()
    local node = agent.mProps[USE_NODE]
    if node == nil or node == "" then return false end
    for _, dlog in ipairs(useDialogs(agent)) do
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
local walking = nil   -- { agent, name, since, done, success, blockedSince }
local walkCutShort = nil -- { w = the walk, at } when the game took Lee over during a walk
local WALK_GIVE_UP_SECONDS = 60

-- The nearest walker that can be seen, as (distance, agent), or nil. Walkers are agents with
-- "zombie" or "walker" in their names that are no helper (obj_, trigger_, lights, sounds) and
-- have a head bone: River Street's "Zombie_wall_vocals_near_water" (a sound) stopped a walk.
local function isWalkerName(name)
  local l = name:lower()
  if not (l:find("zombie", 1, true) or l:find("walker", 1, true)) then return false end
  for _, helper in ipairs({ "^obj_", "^trigger_", "^cam", "^ui_", "^light", "^struggle_", "^group_", "emitter", "sound" }) do
    if l:find(helper) then return false end
  end
  return true
end
local function nearestWalker()
  local from = playerPos()
  local okScene, scene = pcall(SceneGetBottomScene)
  local okAgents, agents = pcall(SceneGetAgents, okScene and scene or nil)
  if not from or not okAgents or type(agents) ~= "table" then return nil end
  local best, bestAgent = nil, nil
  for _, agent in ipairs(agents) do
    if isWalkerName(TWDA.agentName(agent)) then
      local okHidden, hidden = pcall(AgentIsHidden, agent)
      local okPos, pos = pcall(AgentGetWorldPos, agent)
      local okHead, head = pcall(AgentHasNode, agent, "head")
      if not (okHidden and hidden) and okPos and pos and okHead and head == true then
        local okD, d = pcall(VectorDistance, from, pos)
        if okD and type(d) == "number" and (not best or d < best) then best, bestAgent = d, agent end
      end
    end
  end
  return best, bestAgent
end

-- "A walker 5 meters away, to your left. "
local function walkerWords(d, walker)
  local okScreen, screen = pcall(AgentGetScreenPos, walker)
  local side = okScreen and screen and offScreenSide(screen)
  return ("A walker %d meters away, %s. "):format(math.floor(d + 0.5), side and SIDE_WORDS[side] or "in view")
end

-- act: do the hotspot's action on arrival (the walk was started with Enter on it, rather than by
-- accepting "Enter walks there" for something only looked up with Tab).
local function startWalk(agent, act)
  local name = TWDA.agentName(agent)
  local w = { agent = agent, name = name, since = TWDA.now(), act = act, from = playerPos() }
  -- Walkers far away when the walk starts that come close on the way stop it (see walkTick);
  -- not when going for a walker on purpose.
  if not isWalkerName(name) then w.walkerAtStart = nearestWalker() end
  local ok, err = pcall(ThreadStart, function()
    -- To where the game wants Lee to stand to use it, when it says.
    local okPath, result = pcall(AgentPathToAgent, TWDA.player(), rawget(agent, "usePosAgent") or agent)
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

-- What the reticle passed over on the way was not read out, so it is not what Enter is for next
-- (issue #16: after a walk upstairs in the Savannah house was cut short, Enter opened the Bathroom
-- Door passed on the way instead of going on to the Bedroom Door).
local function forgetFocusPassed(w)
  if current.agent ~= nil and current.agent ~= w.agent then current.agent = nil end
end

local function stopWalk(say)
  if not walking then return end
  forgetFocusPassed(walking)
  walking = nil
  quietUntil = 0
  pcall(PathAgentStop, TWDA.player())
  if say then TWDA.say("Stopped.", { interrupt = true }) end
end

-- Each frame while walking: say if Lee gets stuck; when he has arrived, aim the reticle at the
-- hotspot again (the camera has probably changed).
local function walkTick()
  local w = walking
  if not w then return end
  local now = TWDA.now()
  -- Danger on the way (the red panic vignette, or the game's "Dying" flag): stop at once and say
  -- so. A walk takes the shortest way, and in the Savannah sewers (Episode 4) that led Lee past the
  -- walkers at the leaking pipe.
  -- Danger on the way: stop and say so. Walks take the shortest way, and in the Savannah sewers
  -- (Episode 4) one past the walkers feeding by the leaking pipe got Lee killed. Signs of it:
  --   the panic vignette coming up during the walk (near the sewer walkers it shows the whole
  --   time, and a walk away from them must still go), or the game's "Dying" flag;
  --   a walker that was at least 8 meters off at the start within 5, with Lee heading for it.
  -- Neither while the nearest walker is on the move: when walkers come after Lee (the run to the
  -- low passage when the sewer walkers come), stopping would leave him to them.
  if not w.done then
    if now - (w.walkerCheckedAt or 0) > 0.25 then
      w.walkerCheckedAt = now
      local d, walker = nearestWalker()
      local here = playerPos()
      local okW, there = pcall(AgentGetWorldPos, walker)
      local towards, still = false, false
      if here and w.checkedFrom and okW and there then
        local mx, mz = here.x - w.checkedFrom.x, here.z - w.checkedFrom.z
        towards = mx * (there.x - here.x) + mz * (there.z - here.z) > 0
        local last = w.walkerSeen
        still = last ~= nil and last.agent == walker and math.abs(there.x - last.x) + math.abs(there.z - last.z) < 0.15
      end
      if here then w.checkedFrom = { x = here.x, z = here.z } end
      if okW and there then w.walkerSeen = { agent = walker, x = there.x, z = there.z } end
      w.near = { d = d, walker = walker, towards = towards, still = still }
    end
    local near = w.near or {}
    local chased = near.d ~= nil and near.d < 15 and not near.still
    local okHidden, hidden = pcall(SceneIsHidden, "ui_panicmeter.scene")
    local panic = okHidden and hidden == false
    if w.panicAtStart == nil then w.panicAtStart = panic end
    local okLogic, dying = pcall(function() return Logic["Dying"] end)
    local okCombat, combat = pcall(ReticleUI_InCombatMode)
    local danger = (okLogic and dying == true) and "dying"
      or (panic and not w.panicAtStart and not chased) and "vignette"
      or (w.walkerAtStart and w.walkerAtStart >= 8 and near.d and near.d < 5 and near.towards and near.still
        and not (okCombat and combat == true)) and "walker"
    if danger then
      debug(("walk danger (%s): panic %s (at start %s), walker %s m, still %s"):format(danger, tostring(panic),
        tostring(w.panicAtStart), tostring(near.d), tostring(near.still)))
      stopWalk(false)
      TWDA.say("Danger! " .. (near.d and near.d < 15 and walkerWords(near.d, near.walker) or "")
        .. "Walk stopped short of " .. displayName(w.name, w.agent) .. ".", { interrupt = true })
      return
    end
  end
  if not w.done then
    local okB, blocked = pcall(PathAgentIsBlocked, TWDA.player())
    if okB and blocked == true then
      w.blockedSince = w.blockedSince or now
      if now - w.blockedSince > 2 then
        stopWalk(false)
        TWDA.say(TWDA.playerName() .. " is blocked on the way to " .. displayName(w.name, w.agent) .. ".", { interrupt = true })
      end
    else
      w.blockedSince = nil
    end
    -- Lee can stop with the path-finding still waiting: in the Savannah sewers a walk to the far
    -- stairs ended at the low passage (which only an action gets through), with nothing said. If
    -- he has not moved for a few seconds, the walk is over.
    local okPos, pos = pcall(AgentGetWorldPos, TWDA.player())
    if walking and okPos and pos then
      local last = w.lastPos
      if not last or math.abs(pos.x - last.x) + math.abs(pos.y - last.y) + math.abs(pos.z - last.z) > 0.3 then
        w.lastPos, w.movedAt = { x = pos.x, y = pos.y, z = pos.z }, now
      elseif now - (w.movedAt or w.since) > 4 then
        stopWalk(false)
        debug("walk to " .. w.name .. ": Lee stopped moving")
        w.done, w.success = true, false
        walking = w
      end
    end
    -- A long walk is not silent (Lee limps the 35 m to Hershel in about 40 s): the distance left
    -- every 10 seconds, while it goes down.
    if walking and not w.done and now - (w.toldAt or w.since) >= 10 then
      w.toldAt = now
      local left = distanceTo(rawget(w.agent, "usePosAgent") or w.agent)
      if left and left > 5 and (not w.lastLeft or left < w.lastLeft - 2) then
        TWDA.say(left .. " meters to go.")
      end
      w.lastLeft = left or w.lastLeft
    end
    if walking and not w.done and now - w.since > WALK_GIVE_UP_SECONDS then
      stopWalk(false)
      w.done, w.success = true, false
      walking = w
    end
    if not w.done then return end
  end
  walking = nil
  quietUntil = 0
  forgetFocusPassed(w)
  debug("walk to " .. w.name .. " finished, success " .. tostring(w.success))
  -- The path-finding does not take stairs (the dairy farmhouse): say when the goal is on another
  -- floor; walking onto the stairs by hand starts a guided path up or down (guided.lua).
  local where = floorOf(w.agent)
  local floor = where and (" It is " .. where .. ".") or ""
  local left = distanceTo(rawget(w.agent, "usePosAgent") or w.agent)
  -- Usable from where he stopped counts as there (Shawn at the farm's fence, Episode 1: the walk
  -- ends 4 meters from his use position, but he can be talked to from afar).
  local usable = clickable(w.agent)
  -- The path-finding takes Lee as near as it can and can report success well short of the goal: a
  -- closed gate in the way (the yard gate at the dairy, on the way to the barn). Or there is no way
  -- at all: once he is out through Clementine's gate at night (Episode 1), walks to the backyard's
  -- things end at once with him hardly moved. Such a thing is left out of the list (noWay) until
  -- something is used or he has gone elsewhere; not one on another floor (the stairs lead there).
  -- (Failed at once without a step is no way either, however near: the second Bathroom Door
  -- upstairs in the Savannah house, Episode 4, a meter away through the wall.)
  local okMoved, moved = pcall(VectorDistance, playerPos(), w.from)
  local stuck = okMoved and type(moved) == "number" and moved < 1.5
  if stuck and not usable and ((left and left > 6) or (not w.success and now - w.since < 2 and left and left > 0.5)) then
    if floor == "" then
      noWay[w.name] = true
      noWayFrom = noWayFrom or playerPos()
      TWDA.log("lookaround: no way to " .. w.name)
    end
    TWDA.say(("There is no way to %s from here.%s"):format(displayName(w.name, w.agent), floor), { interrupt = true })
    return
  end
  if left and left > 3 and not usable then
    -- Say how far he got and what is close by.
    local nearest, nearestDistance = nearestWayOut(w.name)
    TWDA.say(("%s got to %d meters from %s and can go no further this way.%s%s"):format(TWDA.playerName(), left, displayName(w.name, w.agent),
      floor, floor == "" and nearest and nearestDistance <= 3 and (" Close by: " .. displayName(nearest.name, nearest.agent)
        .. ", " .. nearestDistance .. " meters.") or ""), { interrupt = true })
    return
  end
  if not w.success and not usable then
    -- (Often a remark of Lee's on the way cut it short: Enter goes on there.)
    walkOffer = { agent = w.agent, name = w.name, at = now, kind = "walk" }
    lastTargetName = w.name
    TWDA.say(TWDA.playerName() .. " stopped before reaching " .. displayName(w.name, w.agent) .. "." .. floor
      .. " Enter walks on.", { interrupt = true })
    return
  end
  if placeArrive[w.name] then
    TWDA.say(placeArrive[w.name], { interrupt = true })
    return
  end
  if places[w.name] then
    TWDA.say("At the " .. places[w.name]:lower() .. ". Hold W or S to go up or down.", { interrupt = true })
    return
  end
  forgetUnreachable()
  target = { agent = w.agent, name = w.name, since = now, afterWalk = true, actOnReach = w.act,
    pickNonLook = w.act }
  lastTargetName = w.name
  lastSpoken = nil
end

-- The game starts an action with Main_OnUse or PathToAndUseAgent (walking there first). If neither
-- follows an Enter (the focus lapsed just then, or the game was still busy), aim again and retry.
local lastUseAt = -1
local pendingAction = nil -- { agent, at, tries }
local doorUse = nil -- { label, from, at }: a door just used; said "Through X." if Lee came out elsewhere
for _, name in ipairs({ "Main_OnUse", "PathToAndUseAgent" }) do
  TWDA.hookBefore(name, function(agent)
    lastUseAt = TWDA.now()
    forgetNoWay() -- (a use can open the way: the yard gate at the dairy)
    lastUsed.name, lastUsed.at = TWDA.agentName(agent), lastUseAt
    local acts = (lastActions and lastActions.name == lastUsed.name) and lastActions.actions or {}
    lastUsed.blow = #acts == 1 and isBlow(acts[1])
    TWDA.lastUse = { name = lastUsed.name, at = lastUseAt, label = displayName(lastUsed.name, agent) }
    -- A door used where Lee stands may take him through to another room of the same scene without
    -- a sound (the truck stop's Kitchen Doors and Pantry Door, 400 Days): see doorPassed below.
    local label = TWDA.lastUse.label:lower()
    if name == "Main_OnUse" and (label:find("door", 1, true) or label:find("gate", 1, true) or label:find("hatch", 1, true)) then
      doorUse = { label = TWDA.lastUse.label, from = playerPos(), at = lastUseAt }
    end
    -- In a fight the camera follows the reticle; holding it where the last target was (the hammer
    -- Clementine held out) turns the view away from the next one, which then cannot be clicked.
    if target and target.agent == agent and call("ReticleUI_InCombatMode") == true then target = nil end
  end)
end

-- PathToAndUseAgent walks Lee up to the thing and then uses it, but gives up without a word when a
-- check after the walk fails (navigate.lua: the path, the Navigate map and mode_Reticle active, Lee
-- no longer pathing). Issue #16: at the boy's grave in Episode 4 the first Enter walked Lee up to it
-- and nothing more; a second Enter dug. When it returns with no use, the use is tried once more.
local pathUse = nil -- { agent, used }
local pathRetried = {} -- agent name -> when
TWDA.hookBefore("Main_OnUse", function(agent)
  if pathUse and pathUse.agent == agent then pathUse.used = true end
end)
TWDA.hookBefore("PathToAndUseAgent", function(agent) pathUse = { agent = agent, used = false } end)
TWDA.hookAfter("PathToAndUseAgent", function(args)
  local p = pathUse
  pathUse = nil
  if not p or p.used or p.agent ~= args[1] then return end
  local name, now = TWDA.agentName(p.agent), TWDA.now()
  TWDA.log("lookaround: PathToAndUseAgent ended without a use of " .. name)
  if now - (pathRetried[name] or -60) < 20 or prop(p.agent, "Game Selectable") ~= true then return end
  -- (Not when the player walked off with a movement key.)
  for _, vk in ipairs({ 0x57, 0x41, 0x53, 0x44, 0x25, 0x26, 0x27, 0x28 }) do
    local okKey, down = pcall(InputPCIsVKeyPressed, vk)
    if okKey and down == true then return end
  end
  pathRetried[name] = now
  target = { agent = p.agent, name = name, since = now, actOnReach = true }
  lastTargetName = name
end)

-- The first action that is not just looking (for auto mode), as a number-key index.
-- (Not shooting while there is another way: the gun is loud. In the Savannah sewers, Episode 4,
-- a shot at the walker holding Lee's leg brings the whole group; the climbing pick does not.)
local function firstUseAction()
  local first = nil
  for i, action in ipairs(actionList()) do
    local text = tostring(action)
    if not looksOnly(text) then
      if not text:lower():find("shoot", 1, true) then return i end
      first = first or i
    end
  end
  return first
end

-- pickNonLook: choose the first action that is not "Look" first (auto mode); without it the
-- action chosen with the number keys (or the first) is done.
-- The action picked with a number key, kept for the hotspot it was meant for: the game only takes
-- the key while the reticle is awake on the object (mActionExists), and it dozes off a moment
-- after the mouse stops, so the pick is applied again just before the action (Clementine's finger:
-- 3 Bandage).
local chosen = nil -- { name, index }

local function doAction(pickNonLook)
  local mode = rawget(G, "mode_Reticle")
  if type(mode) ~= "table" or type(mode.DoAction) ~= "function" then return false end
  local focused = call("Reticle_GetAgentFocused")
  if focused == nil then return false end
  -- (A pick made for this hotspot wins: a number key, or the action actions.lua announced it has
  -- just gained, the cage door's "Unlock" in the train station.)
  if chosen and chosen.name == TWDA.agentName(focused) then
    local selectAction = TWDA.upvalue(mode.OnChoice, "selectAction")
    if type(selectAction) == "function" then pcall(selectAction, chosen.index) end
    pickNonLook = false
  end
  chosen = nil
  -- A fight target has a single action and nothing to choose; so has a target whose actions are
  -- not listed at all (the walker on Clementine at the drugstore: "Zombie", icon only).
  local unlisted = #actionList() == 0
  if pickNonLook and not unlisted and not (current.fightTarget and current.agent == focused) then
    local index = firstUseAction()
    if not index then
      debug("only looking possible at " .. TWDA.agentName(focused) .. "; nothing done")
      return false
    end
    local selectAction = TWDA.upvalue(mode.OnChoice, "selectAction")
    if type(selectAction) == "function" then pcall(selectAction, index) end
  end
  if TWDA.lookDebug then
    -- (Issue #16: what the game's DoAction will act on.)
    local doAct = TWDA.unwrap(mode.DoAction)
    debug(("doAction: ours %s, game's focus %s, selected %s, cooldown left %s"):format(TWDA.agentName(focused),
      TWDA.agentName(TWDA.upvalue(doAct, "mAgentWithFocus")), tostring(TWDA.upvalue(doAct, "mSelectedActionIndex")),
      tostring((TWDA.upvalue(doAct, "mReticleNotActiveUntil") or 0) - (call("GetTotalTime") or 0))))
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

-- Whether all a hotspot offers is looking: by its use dialog's actions when they can be read,
-- else by its verb property, which can be stale ("Look At" on the dog's carcass at the house in
-- Savannah, Episode 4, which offers "Look At, Pick Up").
local function onlyLooks(agent)
  local actions = actionsOf(agent)
  if actions and #actions > 0 then
    for _, action in ipairs(actions) do
      if not looksOnly(tostring(action)) then return false end
    end
    return true
  end
  return looksOnly(hotspotVerb(agent))
end

-- Enter. If nothing is focused (the reticle has fallen asleep, or is still on its way to a
-- hotspot), aim at the hotspot last read out and do the action once it is focused.
local function enterPressed()
  local focused = call("Reticle_GetAgentFocused")
  debug(("enter: focused %s, target %s, last %s"):format(TWDA.agentName(focused),
    target and target.name or "none", TWDA.agentName(current.agent)))
  if target and target.pan then return end -- (still turning a view: nothing to do yet)
  -- The last thing chosen with Tab was out of view ("Enter walks there").
  if walkOffer and walkOffer.name == lastTargetName and TWDA.now() - walkOffer.at < 30 then
    local offer = walkOffer
    walkOffer = nil
    if offer.kind == "use" then
      directUse(offer.agent)
      return
    elseif canWalk() then
      -- (In a hurry the action follows the walk without another Enter.)
      startWalk(offer.agent, TWDA.inActionScene ~= nil and TWDA.inActionScene() == true)
      return
    end
  end
  if focused ~= nil then
    local name = TWDA.agentName(focused)
    -- Something just announced by name ("Sign: Pick Up. Enter to do it.") is what Enter is for,
    -- even when the reticle has drifted onto the thing beside it (the ladder above the sign in the
    -- Savannah sewers, Episode 4), unless Tab has been pressed since.
    -- (Not for another of the same kind: on the stairs of the Crawford school, Episode 4, walkers
    -- come one after another, each announced as "Zombie: Shoot", and the nearer one the reticle is
    -- already on is the one to shoot.)
    local sameKind = announced.name and displayName(announced.name) == displayName(name, focused)
    if announced.name and announced.name ~= name and not sameKind and TWDA.now() - announced.at < 15
      and lastTabAt < announced.at then
      for _, entry in ipairs(hotspots()) do
        if entry.name == announced.name and entry.clickable then
          debug("enter: going for the announced " .. entry.name .. " instead")
          target = { agent = entry.agent, name = entry.name, since = TWDA.now(), actOnReach = true,
            pickNonLook = not onlyLooks(entry.agent) }
          lastTargetName = entry.name
          return
        end
      end
    end
    -- In a fight the nearest target comes first, even when the reticle rests on a farther one.
    if call("ReticleUI_InCombatMode") == true then
      local here = distanceTo(focused)
      local nearest, best = nil, (here or 1000) - 1
      for _, entry in ipairs(hotspots()) do
        if entry.clickable and entry.name ~= name and not looksOnly(hotspotVerb(entry.agent)) then
          local d = distanceTo(entry.agent)
          if d and d < best then nearest, best = entry, d end
        end
      end
      if nearest then
        debug("enter: going for the nearer " .. nearest.name)
        target = { agent = nearest.agent, name = nearest.name, since = TWDA.now(), actOnReach = true, picked = true }
        lastTargetName = nearest.name
        return
      end
    end
    -- Just announced with its action ("Brick Wall: Move To. Enter!"): do that action, unless one
    -- was picked with a number key.
    local fresh = announced.name == name and TWDA.now() - announced.at < 15 and not (chosen and chosen.name == name)
    doAction(fresh and not onlyLooks(focused))
    return
  end
  -- A target that is no longer on offer (the pillow, once taken) is forgotten.
  if target then
    local offered = false
    for _, entry in ipairs(hotspots()) do
      if entry.name == target.name then offered = true end
    end
    if not offered then target = nil end
  end
  -- So is one chosen before something newer was announced (the shovel Tabbed to at the boy's
  -- grave, Episode 4, out of reach once "Loose Dirt: Shovel. Enter to do it." came).
  if target and stillPreferred() and preferNext ~= target.name and preferNextAt > (target.since or 0) then
    target = nil
  end
  -- (Even in action scenes this goes through the reticle: the game only applies the chosen action,
  -- such as Take rather than Look, to uses that the reticle started; Main_OnUse on its own leaves
  -- the hotspot's dialog waiting and the scene stalls.)
  -- In a fight there is no time to Tab first: go for the target chosen with Tab if it is still on
  -- offer, else the first thing to do (not one only to look at: zombie David's body lies beside
  -- the walker to kick), else the first one.
  if call("ReticleUI_InCombatMode") == true then
    local list = hotspots()
    local pick = nil
    for _, entry in ipairs(list) do
      if target and not target.picked and entry.name == target.name then pick = entry end
    end
    if not pick then
      -- The nearest thing to do first: the closest walker is the one about to get Lee (the stairs
      -- of the Crawford school, Episode 4).
      local best = math.huge
      for _, entry in ipairs(list) do
        if entry.clickable and not looksOnly(hotspotVerb(entry.agent)) then
          local d = distanceTo(entry.agent) or 1000
          if d < best then pick, best = entry, d end
        end
      end
    end
    pick = pick or list[1]
    if pick then
      local tabbed = target and not target.picked and target.name == pick.name
      target = { agent = pick.agent, name = pick.name, since = TWDA.now(), actOnReach = true, picked = not tabbed }
      lastTargetName = pick.name
      return
    end
  end
  if target then
    target.actOnReach = true
    return
  end
  -- Something was just announced as new (actions.lua, peek.lua): Enter goes for it, with the
  -- action announced (the truck's "Move To" rather than its first action, "Look At"). Not when
  -- that was a while ago, or the reticle has read out something else since.
  -- A number was picked for something read out with its numbered actions ("Zombie: 1 Look At,
  -- 2 Shoot, 3 Bash, 4 Stomp." for the boy in the attic, Episode 4): go and do that.
  if chosen and chosen.at and TWDA.now() - chosen.at < 15 then
    for _, entry in ipairs(hotspots()) do
      if entry.name == chosen.name then
        target = { agent = entry.agent, name = entry.name, since = TWDA.now(), actOnReach = true }
        lastTargetName = entry.name
        return
      end
    end
  end
  if stillPreferred() then
    for _, entry in ipairs(hotspots()) do
      if entry.name == preferNext then
        local looking = onlyLooks(entry.agent)
        target = { agent = entry.agent, name = entry.name, since = TWDA.now(), actOnReach = true,
          pickNonLook = not looking }
        lastTargetName, preferNext = entry.name, nil
        return
      end
    end
  end
  -- Whichever came last, the announcement or the reticle's last focus (the shovel, read out before
  -- "Loose Dirt: Shovel. Enter to do it." at the boy's grave, Episode 4; Enter came 20 s later).
  if announced.name and announced.at > (current.at or -10) then
    for _, entry in ipairs(hotspots()) do
      if entry.name == announced.name then
        target = { agent = entry.agent, name = entry.name, since = TWDA.now(), actOnReach = true,
          pickNonLook = not onlyLooks(entry.agent) }
        lastTargetName = entry.name
        return
      end
    end
  end
  local agent = current.agent
  if agent ~= nil and prop(agent, "Game Selectable") == true then
    target = { agent = agent, name = TWDA.agentName(agent), since = TWDA.now(), actOnReach = true }
    return
  end
  -- Only one thing can be used from here (Brenda, gun in hand, in the farmhouse kitchen): that.
  local usable = {}
  for _, entry in ipairs(hotspots()) do
    if entry.clickable and entry.side == nil then usable[#usable + 1] = entry end
  end
  if #usable == 1 then
    -- (Its first action that is not looking, as announced: "Pipe: Look At, Place Valve. Enter!" in
    -- the Savannah sewers; pressed late, Enter looked at the pipe.)
    target = { agent = usable[1].agent, name = usable[1].name, since = TWDA.now(), actOnReach = true,
      pickNonLook = not onlyLooks(usable[1].agent) }
    lastTargetName = usable[1].name
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

-- Backspace steps back out of a close-up (Carley's radio), as a right click does
-- (reticle.imap: OnBack). Elsewhere the game does nothing with it.
local function goBack()
  target = nil
  local mode = rawget(G, "mode_Reticle")
  if type(mode) == "table" and type(mode.OnBack) == "function" then
    local ok, err = pcall(ThreadStart, function()
      local okBack, errBack = pcall(mode.OnBack, mode, {})
      if not okBack then TWDA.log("lookaround back: " .. tostring(errBack)) end
    end)
    if not ok then TWDA.log("lookaround back (thread): " .. tostring(err)) end
  end
end

TWDA.onFrame("lookaround", function()
  local ready = reticleReady()
  -- (Not Escape: that is the game's pause menu, issue #6. Backspace lets go and stops walks.)
  local tab, enter, back = pressed(VK_TAB), pressed(VK_ENTER), pressed(VK_BACK)
  local number = nil
  for i = 1, 4 do
    if pressed(0x30 + i) then number = i end
  end
  if walking and (back or not canWalk()) then
    -- The game took Lee over (a remark when he came close to something, a cut scene). Say how the
    -- walk ended once he can walk again; nothing else would.
    if not back then walkCutShort = { w = walking, at = TWDA.now() } end
    stopWalk(back)
    back = false
  end
  if walkCutShort and canWalk() then
    local w = walkCutShort.w
    if TWDA.now() - walkCutShort.at > 120 or walking then
      walkCutShort = nil
    elseif TWDA.now() - walkCutShort.at > 0.5 then
      walkCutShort = nil
      local left = distanceTo(rawget(w.agent, "usePosAgent") or w.agent)
      if left and left > 3 then
        walkOffer = { agent = w.agent, name = w.name, at = TWDA.now(), kind = "walk" }
        lastTargetName = w.name
        TWDA.say(("The walk to %s was cut short, %d meters away. Enter walks on."):format(displayName(w.name, w.agent), left))
      end
    end
  end
  walkTick()
  if enter and not ready then debug("enter ignored: reticle not ready") end
  -- (Some close-ups have no reticle at all: the notepad shown from the train's console, Episode 3.)
  if back and not ready and call("WDBackButton_IsOccupied") == true then goBack() end
  if not ready then
    -- (A scene that starts while a view is being turned is what the turn was for.)
    if target and target.pan then target, quietUntil = nil, 0 end
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
  if strikeAt then
    local at = strikeAt
    strikeAt = nil
    if (TWDA.settings.actionscenes or "slow") == "auto" and TWDA.now() - at < 1 then doAction(true) end
  end
  -- A blow or a shot whose target stays in the reticle all along: the game does not show its
  -- actions again, so checkStrike never hears of it ("Window: Shoot" in Russell's story, 400 Days:
  -- "DON'T stop shooting!"; one shot, and Nate was hit). Still on it a second later: another go.
  -- Back in control after a door: came out somewhere else? (Nothing else says so.)
  -- (Watched for a few seconds, as the move can come a moment after control is back; not once
  -- the player walks off by hand or with Enter.)
  if doorUse then
    local d = doorUse
    local moving = walking ~= nil
    for _, vk in ipairs({ 0x57, 0x41, 0x53, 0x44, 0x25, 0x26, 0x27, 0x28 }) do
      local okKey, down = pcall(InputPCIsVKeyPressed, vk)
      if okKey and down == true then moving = true end
    end
    local here = playerPos()
    local okDist, dist = pcall(VectorDistance, here, d.from)
    if moving or TWDA.now() - d.at > 6 then
      doorUse = nil
    elseif here and okDist and type(dist) == "number" and dist > 1.5 then
      doorUse = nil
      TWDA.log("lookaround: through " .. d.label .. " (" .. math.floor(dist + 0.5) .. " m)")
      TWDA.say("Through " .. d.label .. ".")
    end
  end
  if lastUsed.name and lastUsed.blow and TWDA.now() - lastUsed.at > 1 and TWDA.now() - lastUsed.at < 10
    and call("ReticleUI_InCombatMode") ~= true and TWDA.agentName(call("Reticle_GetAgentFocused")) == lastUsed.name then
    TWDA.log("lookaround: again at " .. lastUsed.name .. " (still in the reticle)")
    lastUsed.name = nil
    TWDA.say("Again! Enter!", { interrupt = true })
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
  if noWayFrom then
    local okDist, dist = pcall(VectorDistance, playerPos(), noWayFrom)
    if okDist and type(dist) == "number" and dist > NO_WAY_CLEAR_METERS then forgetNoWay() end
  end

  if number then
    -- (When the reticle is awake on the object, the game takes the key itself and shows the
    -- action, which is read out from its tooltip.)
    local focused = call("Reticle_GetAgentFocused")
    -- (Before the reticle gets there, a number is meant for what was just announced: "Zombie: 1
    -- Shoot, 2 Attack" in the Savannah sewers, not the walker's arm dealt with a moment before.)
    -- (Within the same time as Enter goes for it: the pipe in the Savannah sewers was announced
    -- with "1 Turn left, 2 Turn right", 2 was pressed after eight seconds, and Enter turned it left.)
    local announcedName = stillPreferred()
      or (numbersFor and TWDA.now() - numbersFor.at < 15 and numbersFor.name) or nil
    local name = focused ~= nil and TWDA.agentName(focused) or (target and target.name) or announcedName
      or TWDA.agentName(current.agent)
    local actions = (lastActions and lastActions.name == name) and lastActions.actions or actionList()
    local action = actions[number]
    if action and name ~= "" then
      chosen = { name = name, index = number, at = TWDA.now() }
      if focused == nil then TWDA.say(action, { interrupt = true }) end
    end
  end

  if tab then
    chosen = nil
    local okShift, shift = pcall(InputPCIsVKeyPressed, VK_SHIFT)
    lastTabAt = TWDA.now()
    cycle((okShift and shift == true) and -1 or 1)
  elseif enter then
    enterPressed()
  elseif back then
    goBack()
  end

  -- The mouse moved: the player is aiming by hand, so stop steering.
  local okMouse, mouse = pcall(CursorGetDevicePos)
  if okMouse and mouse then
    if lastMouse and (math.abs(mouse.x - lastMouse.x) > 2 or math.abs(mouse.y - lastMouse.y) > 2) then target = nil end
    lastMouse = { x = mouse.x, y = mouse.y }
  end

  if target and target.pan then
    -- Turning a view to its far end: hold the reticle at that edge until the view stops moving
    -- (measured by where the hotspots' markers fall on screen).
    local now = TWDA.now()
    if cameraName() ~= target.camera then
      target, quietUntil = nil, 0
      return
    end
    pcall(ReticleController_SetScreenPos, target.pan == "left" and 0.01 or 0.99, 0.5, false)
    local x = nil
    for _, agent in ipairs(TWDA.upvalue(rawget(G, "Reticle_Update"), "mUseables") or {}) do
      local dot = rawget(agent, "dot")
      local okPos, pos = pcall(AgentGetLogicalScreenPos, dot)
      if dot ~= nil and okPos and pos and pos.x then x = pos.x break end
    end
    if x == nil or target.probeX == nil or math.abs(x - target.probeX) > 0.002 then
      target.probeX, target.movedAt = x, now
    end
    if (now - target.movedAt > 0.6 and now - target.since > 1) or now - target.since > 10 then
      local side = target.pan
      target, quietUntil = nil, 0
      TWDA.say(("Turned as far %s as it goes."):format(side), { interrupt = true })
    end
    return
  end
  if target then
    local okSel = prop(target.agent, "Game Selectable") == true
    local okPos, pos = pcall(AgentGetScreenPos, target.agent)
    if not okSel or not okPos or not pos then
      target = nil
      return
    end
    local now = TWDA.now()
    local side = sideOf(target.agent, pos)
    -- While a turn choice is up, the arrows turn Lee and the game also turns when the reticle is
    -- held at an edge, so out of view is left to the arrows (Lee's stuck leg in Crawford, Episode
    -- 4: aiming at the walker above turned the view up and down over and over).
    if side ~= nil and TWDA.turnChoiceActive and TWDA.turnChoiceActive() and clickable(target.agent) then
      -- (Its marker is on screen: aim at that, if it lies where the reticle can go without
      -- turning Lee; see the clamp below.)
      local ax, ay = aimPoint(target.agent)
      local okW, width = pcall(AgentGetProperty, "logic_mode_choice", "Choice - Reticle Move Width")
      local half = (okW and type(width) == "number" and width or 0.6) * 0.5 - 0.03
      if ax and ay and math.abs(ax - 0.5) <= half + 0.05 and math.abs(ay - 0.5) <= half + 0.05 then side = nil end
    end
    -- (A side Lee cannot turn to is no reason to turn: aim at it as well as the bounds allow.)
    if side ~= nil and TWDA.turnChoiceActive and TWDA.turnChoiceActive() and TWDA.turnChoiceSides
      and not TWDA.turnChoiceSides()[side] then
      side = nil
    end
    if side ~= nil and TWDA.turnChoiceActive and TWDA.turnChoiceActive() then
      local where = TWDA.sideWords[side] or side
      TWDA.say(displayName(target.name, target.agent) .. " is " .. where .. ". Turn with the arrow keys first.",
        { interrupt = true })
      target = nil
      return
    end
    if side == nil then
      local x, y = aimPoint(target.agent)
      x, y = x or pos.x, y or pos.y
      -- (During a turn choice the game turns Lee when the reticle goes more than half the move
      -- width from the centre, mode_choice.lua's update thread: keep inside that.)
      if TWDA.turnChoiceActive and TWDA.turnChoiceActive() then
        local okW, width = pcall(AgentGetProperty, "logic_mode_choice", "Choice - Reticle Move Width")
        local half = (okW and type(width) == "number" and width or 0.6) * 0.5 - 0.03
        x = math.max(0.5 - half, math.min(0.5 + half, x))
        y = math.max(0.5 - half, math.min(0.5 + half, y))
      end
      pcall(ReticleController_SetScreenPos, x, y, false)
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
      -- After a walk the reticle may have settled on it while Lee was still walking, when nothing
      -- is said; read it out on arrival (the pried passage in the Savannah sewers: silence).
      -- (speakFocus skips it if it was just said.)
      if target.afterWalk and not target.reached and not target.actOnReach then speakFocus() end
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
        startWalk(t.agent, true)
      else
        walkOffer = { agent = t.agent, name = t.name, at = now, kind = "walk" }
        local d = distanceTo(t.agent)
        TWDA.say(displayName(t.name, t.agent) .. " is out of view" .. (d and (", " .. d .. " meters away") or "")
          .. ". Enter walks there.", { interrupt = true })
        quietUntil = now + 4
      end
    elseif not target.reached and now - target.since > limit and target.afterWalk and blockerInFront(target.agent) then
      -- Something the game put in its way: using it anyway (below) only got a confused remark from
      -- Shel at the truck stop's back door, 400 Days, which opened from the back hall.
      local t = target
      target = nil
      debug("blocked by " .. tostring(blockerInFront(t.agent)))
      local way, wayDistance = nearestWayOut(t.name)
      TWDA.say(displayName(t.name, t.agent) .. " can't be used from this side."
        .. (way and (" Close by: " .. displayName(way.name, way.agent) .. ", " .. wayDistance .. " meters.") or ""),
        { interrupt = true })
      quietUntil = now + 4
    elseif not target.reached and now - target.since > limit and target.afterWalk and not presentsChoices(target.agent) then
      -- Still out of view after walking there, but simple enough to use without the reticle.
      local t = target
      target = nil
      walkOffer = { agent = t.agent, name = t.name, at = now, kind = "use" }
      lastTargetName = t.name
      local verb = gameVerb(t.agent)
      -- (Named again rather than "it": this is often a person, Ben on the train in Episode 3.)
      local name = displayName(t.name, t.agent)
      TWDA.say(name .. " is out of view from here, but " .. TWDA.playerName() .. " can still " .. (verb and verb:lower() or "use") .. " "
        .. name .. ". Enter to do it.", { interrupt = true })
      quietUntil = now + 5
    elseif not target.reached and now - target.since > limit then
      TWDA.say(displayName(target.name, target.agent) .. (target.afterWalk and " still can't be reached from here."
        or " can't be reached from here.") .. (target.actOnReach and " Nothing done." or ""), { interrupt = true })
      quietUntil = now + 3
      unreachable[target.name] = true
      -- Behind the camera and out of reach: so is everything else behind it (at the barn's locked
      -- door the camera hardly turns, and a dozen things are behind Lee).
      local okPos, pos = pcall(AgentGetScreenPos, target.agent)
      if okPos and pos and sideOf(target.agent, pos) == "behind" then
        for _, entry in ipairs(hotspots()) do
          if entry.side == "behind" then unreachable[entry.name] = true end
        end
      end
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
  if call("WDBackButton_IsOccupied") == true then parts[#parts + 1] = "Close-up, Backspace to go back" end
  if focus then
    local doing = 0
    for _, action in ipairs(actionList()) do
      if not looksOnly(tostring(action)) then doing = doing + 1 end
    end
    parts[#parts + 1] = focus .. (doing > 1 and ". A number key to choose, then Enter" or ". Enter to do it")
  end
  local names = {}
  local walk = canWalk()
  for _, entry in ipairs(list) do
    local where = {}
    if entry.side then where[#where + 1] = SIDE_WORDS[entry.side] end
    local d = walk and distanceTo(entry.agent)
    if d then where[#where + 1] = d .. " meters" end
    local floor = walk and floorOf(entry.agent)
    if floor then where[#where + 1] = floor end
    local state = TWDA.hotspotState and TWDA.hotspotState(entry.agent)
    if state then where[#where + 1] = state end
    names[#names + 1] = displayName(entry.name, entry.agent) .. (#where > 0 and (" (" .. table.concat(where, ", ") .. ")") or "")
  end
  parts[#parts + 1] = ("%d to interact with: %s. Tab and Shift Tab to move between them"):format(#list,
    table.concat(names, ", "))
  return TWDA.joinSentences(parts)
end

-- For beacons.lua: where Lee walks freely, what Tab offers, with a kind ("thing" or "place") and a
-- point in the world; not in close-ups. (No walkers: dead ones lie about with their heads on, and
-- nothing tells them from the living.) Tab's choice is the latest of the reticle's target, a walk
-- offered ("Duck, behind you, 3 meters. Enter walks there": Tab on what the reticle cannot take
-- from here sets no target) and a walk under way; it is listed even when the list has lost it (out
-- of view after a camera cut).
function TWDA.beaconEntries()
  if not reticleReady() or not canWalk() or call("WDBackButton_IsOccupied") == true then return {} end
  local chosen, latest = nil, -math.huge
  local picks = { target and not target.pan and { target.agent, target.since },
    walkOffer and { walkOffer.agent, walkOffer.at }, walking and { walking.agent, walking.since } }
  for i = 1, 3 do
    local pick = picks[i]
    if pick and pick[1] ~= nil and (pick[2] or 0) >= latest then chosen, latest = pick[1], pick[2] or 0 end
  end
  local list, listed = {}, false
  for _, entry in ipairs(hotspots()) do
    if not entry.pan then
      local okPos, point = pcall(AgentGetWorldPos, entry.agent)
      if okPos and point then
        list[#list + 1] = { agent = entry.agent, label = entry.name, kind = entry.place and "place" or "thing",
          point = point, chosen = chosen ~= nil and chosen == entry.agent }
        listed = listed or list[#list].chosen
      end
    end
  end
  if chosen ~= nil and not listed and call("AgentIsHidden", chosen) ~= true then
    local okPos, point = pcall(AgentGetWorldPos, chosen)
    if okPos and point then
      local name = TWDA.agentName(chosen)
      list[#list + 1] = { agent = chosen, label = name, kind = places[name] and "place" or "thing", point = point,
        chosen = true }
    end
  end
  return list
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

-- True while the mod turns a view to its far end (SCENE_VIEWS).
function TWDA.turningView()
  return target ~= nil and target.pan ~= nil
end

-- index: do that action (as its number key would) instead.
function TWDA.useWithReticle(agent, index)
  if TWDA.reticleBusy() then return false end
  target = { agent = agent, name = TWDA.agentName(agent), since = TWDA.now(), actOnReach = true,
    pickNonLook = index == nil }
  if index then chosen = { name = target.name, index = index } end
  lastTargetName = target.name
  return true
end

TWDA.hotspots = hotspots
-- actions.lua: the next Tab goes to this hotspot first (what was just announced as new).
-- With an action index, Enter on it does that action (as if picked with its number key).
function TWDA.numbersMean(name)
  numbersFor = { name = name, at = TWDA.now() }
end
function TWDA.preferNextTab(name, actionIndex)
  preferNext, preferNextAt = name, TWDA.now()
  announced = { name = name, at = preferNextAt }
  if actionIndex then chosen = { name = name, index = actionIndex } end
end
TWDA.hotspotName = function(agent) return displayName(TWDA.agentName(agent), agent) end
TWDA.hotspotVerb = hotspotVerb
-- Fight targets (a walker's head, the babysitter's face) have no name of their own in the game.
TWDA.isFightTarget = function(agent) return gameName(agent) == nil end
TWDA.hotspotActions = actionsOf
TWDA.reticleReady = reticleReady
