-- Walkers in The Final Season (projectseason4's ai_player.lua): Clementine fights walkers in free
-- walking. When one is in reach (about 2 meters), the player's AI properties (ExecuteInteraction's
-- upvalue mPlayer, its mProps) name it as "AI Player - Interaction Current Target", and the walker's
-- own "AI Agent - Player Used Interaction Prompt 1/2" give the prompts ("y" with "cs_attackTarget",
-- "b" with "cs_stunTarget"). Q (AI_Player_Q) takes an "x" or "y" prompt, E an "a" or "b" one, the
-- left mouse button an "rt" one. The window is short, about half a second before the walker grabs
-- her (a struggle, struggle.lua).
--
-- The mod says when a walker comes near and from where, names the keys once one is in reach, and
-- remembers Q or E pressed while one is coming (for 3.5 seconds), doing it the moment it is in
-- reach. Slow mode slows the game while one is close; auto mode attacks by itself.
local TWDA = ...
local G = _G

local KEYS = { a = "E", b = "E", e = "E", x = "Q", y = "Q", q = "Q", rt = "Left click", l = "Left click" }
local NEAR_METERS, CLOSE_METERS = 6, 3.5
-- (Another walker this close to her when one is in reach: a group. A kill takes about four and a
-- half seconds; at the pier, Episode 3, one 6 meters off grabbed her during it.)
local GROUP_METERS = 7.5
local BUFFER_SECONDS = 3.5 -- (game time; a walker can take three seconds from "3 meters" to reach)

local function call(name, ...)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

local function playerProps()
  local exec = TWDA.upvalue(rawget(G, "AI_Player_E"), "ExecuteInteraction")
  local player = exec and TWDA.upvalue(exec, "mPlayer")
  local ok, props = pcall(function() return player.mProps end)
  return ok and props or nil
end

local function get(props, key)
  local ok, value = pcall(function() return props[key] end)
  if ok then return value end
  return nil
end

local function prop(agent, key)
  local ok, value = pcall(AgentGetProperty, agent, key)
  if ok then return value end
  return nil
end

-- "cs_attackTarget" -> "attack", "cs_stunTarget" -> "shove".
local WORDS = { stun = "shove", attack = "attack", kill = "kill", push = "push", shove = "shove", stab = "stab",
  ["hide behind zombie"] = "hide behind it" }
local function actionWord(node)
  -- ("cs_schoolDamaged_targetAttack": the scene's name first.)
  local base = tostring(node or ""):gsub("^cs_", ""):match("([^_]*)$") or ""
  local word = base:gsub("^target(%u)", "%1"):gsub("Target$", ""):gsub("([%l])(%u)", "%1 %2"):lower()
  -- (AJ's own, "cs_ajStunTarget": the game says "Press E to stun, then Q to kill" for him.)
  local mine = word:match("^aj (.+)$")
  if mine then return mine end
  return WORDS[word] or (word ~= "" and word or "act")
end

local OVERRIDE = "AI Player - Interaction Current Target Override"

local function alive(agent)
  return agent ~= nil and prop(agent, "AI Agent - AI Agent Enable") == true
end

-- The walker Q and E would act on. (A walker put down stays the game's current target for a while:
-- it is not one, or the next walker coming was never said.)
local function targetOf(props)
  for _, key in ipairs({ OVERRIDE, "AI Player - Interaction Current Target" }) do
    local name = get(props, key)
    if type(name) == "string" and name ~= "" then
      local ok, agent = pcall(AgentFind, name)
      if ok and alive(agent) then return agent end
    end
  end
  return nil
end

-- The prompts a walker offers: { key = "Q", letter = "y", word = "attack" }.
-- (A person's name in the node is left out: the guard on the boat, Episode 3, "cs_stabMichael".)
local function promptsOf(agent)
  local list = {}
  local own = " " .. TWDA.agentName(agent):lower()
  for i = 1, 2 do
    local pre = "AI Agent - Player Used Interaction Prompt " .. i
    if prop(agent, pre .. " Enable") == true then
      local letter = tostring(prop(agent, pre) or ""):lower()
      if KEYS[letter] then
        local word = actionWord(prop(agent, pre .. " Dialog Node"))
        if #word > #own and word:sub(-#own) == own then word = word:sub(1, -#own - 1) end
        list[#list + 1] = { key = KEYS[letter], letter = letter, word = word }
      end
    end
  end
  return list
end

local function nameOf(agent)
  local noun = call("Game_GetNounText", agent)
  if type(noun) == "string" and noun ~= "" then return TWDA.cleanText(noun) end
  -- (Someone met like a walker, James in the woods in Episode 2, by name.)
  local name = TWDA.agentName(agent)
  if name:find("^%u%l+$") and not name:find("^Zombie") and not name:find("^Walker") then return name end
  return "Walker"
end

-- Walkers about: active agents with interaction prompts that are shown (looked up twice a second).
local walkers, walkersAt = {}, -10
local function aliveWalkers()
  local now = TWDA.now()
  if now - walkersAt < 0.5 then return walkers end
  walkersAt, walkers = now, {}
  local player = TWDA.player()
  local okS, agents = pcall(SceneGetAgents, TWDA.playerScene())
  for _, agent in ipairs(okS and type(agents) == "table" and agents or {}) do
    -- ("AI Agent - AI Agent Enable" goes false when one is put down; its prompts stay on.)
    if agent ~= player and prop(agent, "AI Agent - AI Agent Enable") == true
        and (prop(agent, "AI Agent - Player Used Interaction Prompt 1 Enable") == true
          or prop(agent, "AI Agent - Player Used Interaction Prompt 2 Enable") == true)
        and call("AgentIsHidden", agent) ~= true then
      walkers[#walkers + 1] = agent
    end
  end
  return walkers
end

local function distance(agent)
  local okA, a = pcall(AgentGetWorldPos, agent)
  local okB, b = pcall(AgentGetWorldPos, TWDA.player())
  if not (okA and okB and a and b) then return nil end
  local dx, dz = a.x - b.x, a.z - b.z
  return math.sqrt(dx * dx + dz * dz)
end

local function sideOf(agent)
  local ok, pos = pcall(AgentGetScreenPos, agent)
  if not ok or not pos then return nil end
  if (pos.z or 1) <= 0 then return "behind you" end
  if pos.x < 0.2 then return "to your left" end
  if pos.x > 0.8 then return "to your right" end
  return "ahead"
end

local function nearest()
  local best, bestD = nil, math.huge
  for _, agent in ipairs(aliveWalkers()) do
    local d = distance(agent)
    if d and d < bestD then best, bestD = agent, d end
  end
  return best, bestD
end

local function promptText(list)
  local parts = {}
  for _, p in ipairs(list) do parts[#parts + 1] = p.key .. " to " .. p.word end
  return table.concat(parts, ", ")
end

local function press(letter)
  local fn = (KEYS[letter] == "Q" and "AI_Player_Q") or (KEYS[letter] == "E" and "AI_Player_E") or "AI_Player_L"
  local ok, err = pcall(rawget(G, fn), { type = 0, code = 0 })
  if not ok then TWDA.log("combat4: " .. fn .. " failed: " .. tostring(err)) end
end

-- Aiming for the player: the game only takes a walker within 45 degrees of where she faces as the
-- target, and she turns only by moving, so one at her side or back cannot be fought by ear. And a
-- walker shoved stays the game's target while the next one closes in (the woods in Episode 2: one
-- stood 2 meters off for four seconds, out of reach of Q and E, and grabbed her). So Q and E go for
-- the walker in reach that is still coming for her: ExecuteInteraction takes the target override
-- first and does not look at the angle (the walker is brought round to her). The override is put
-- back after a moment.
local ASSIST_METERS = 2.5
local overrideName, overrideAt = nil, 0

local function setOverride(props, name)
  pcall(function() props[OVERRIDE] = name end)
end

-- (One that can still be shoved has not been: it is coming for her.)
local function canShove(agent)
  for _, p in ipairs(promptsOf(agent)) do
    if p.key == "E" then return true end
  end
  return false
end

-- Hiding behind walkers from the raiders' flashlights (the river at night, Episode 3,
-- RiverShorelineNight.lua): every walker of the herd offers Q, "cs_hideBehindZombie", and the game
-- takes one several meters off once it is the target, bringing her to it; hiding is a station
-- (dialogs "bg_stationHideBehindZombieEnter" and "...Exit"). The flashlight
-- (RiverShorelineNight_EnableFlashlightTracking(true)) finds her about six seconds after the herd
-- sets off and again after each hide ends (the raiders shoot the walker she hid behind); four
-- seconds later, out in the open, she is shot. The herd walks on ahead of her, out of reach of Q.
local HIDE_METERS = 15 -- (the game took one 7 meters off; the herd can be further ahead of her)

local function canHide(agent)
  for _, p in ipairs(promptsOf(agent)) do
    if p.word:find("^hide") then return true end
  end
  return false
end

-- The walker in reach that matters: the game's target while it can be shoved; else the nearest in
-- reach that can be; else the game's target, or the nearest in reach; else one to hide behind.
local function reachTarget(props)
  local gameTarget = targetOf(props)
  if gameTarget and canShove(gameTarget) then return gameTarget end
  local coming, comingD, any, anyD, hide, hideD = nil, math.huge, nil, math.huge, nil, math.huge
  for _, agent in ipairs(aliveWalkers()) do
    local d = distance(agent)
    if d and d <= ASSIST_METERS then
      if d < comingD and canShove(agent) then coming, comingD = agent, d end
      if d < anyD then any, anyD = agent, d end
    end
    if d and d <= HIDE_METERS and d < hideD and canHide(agent) then hide, hideD = agent, d end
  end
  return coming or gameTarget or any or hide
end

local hiding, hideWanted = false, nil -- (hideWanted: when auto mode should hide her)
function TWDA.hidingBehindWalker()
  return hiding
end
TWDA.hookBefore("Game_RunDialog", function(node)
  if node == "bg_stationHideBehindZombieEnter" then
    hiding, hideWanted = true, nil
    TWDA.say("Hiding behind a walker.", { interrupt = true })
  elseif node == "bg_stationHideBehindZombieExit" then
    hiding, hideWanted = false, TWDA.now()
    TWDA.say("Out in the open. Q to hide behind another walker!", { interrupt = true })
  end
end)
TWDA.hookBefore("RiverShorelineNight_EnableFlashlightTracking", function(on)
  if on == true and not hiding then
    hideWanted = TWDA.now()
    TWDA.say("The light is on you! Q to hide behind a walker!", { interrupt = true })
  end
end)

local function aimAtReachable()
  local props = playerProps()
  if props == nil then return end
  local now = TWDA.now()
  if overrideName and get(props, OVERRIDE) == overrideName then
    local ok, agent = pcall(AgentFind, overrideName)
    if not (ok and alive(agent)) then setOverride(props, ""); overrideName = nil end
  end
  local pick = reachTarget(props)
  if pick and pick ~= targetOf(props) then
    overrideName, overrideAt = TWDA.agentName(pick), now
    setOverride(props, overrideName)
    TWDA.log(("combat4: aiming at %s, %.1f m"):format(overrideName, distance(pick) or -1))
  end
end

for _, name in ipairs({ "AI_Player_Q", "AI_Player_E" }) do
  TWDA.hookGlobal(name, function(original)
    return function(event, ...)
      local ok, err = pcall(aimAtReachable)
      if not ok then TWDA.log("combat4: " .. tostring(err)) end
      return original(event, ...)
    end
  end)
end

local warned = setmetatable({}, { __mode = "k" }) -- walker -> "near" or "close"
local target, targetAt, targetKeys = nil, 0, nil
local buffered = nil -- { key, at }
local autoAt = nil -- (when auto mode acts on the walker in reach)
local keyHeld = {}

TWDA.onFrame("combat4", function()
  local props = playerProps()
  if props == nil then return end
  local enabled = get(props, "AI Player - Interaction Enable") == true
  local now = TWDA.now()
  local mode = TWDA.settings.actionscenes or "slow"
  local struggling = TWDA.struggleActive and TWDA.struggleActive()
  local walker, d = nil, math.huge
  if enabled and not struggling then walker, d = nearest() end
  -- (In reach: the game's target, or the nearest walker close enough for the aiming above.)
  local current = enabled and not struggling and reachTarget(props) or nil
  if overrideName and now - overrideAt > 2.5 then
    if get(props, OVERRIDE) == overrideName then setOverride(props, "") end
    overrideName = nil
  end

  -- A walker coming near: said once at about 6 meters and again at 3.5. (Not in a close-up: at the
  -- train station Clementine looks over walkers she is not meant to fight.)
  local okM, gameMode = pcall(Game_GetMode)
  local station = okM and type(gameMode) == "table" and gameMode.name == "Station"
  -- (Each one, not only the nearest: in the woods in Episode 2 the next two came while she dealt
  -- with one in reach, unsaid, and grabbed her. While one is in reach the others are "another".)
  if enabled and not struggling and not station then
    for _, other in ipairs(aliveWalkers()) do
      -- (Not the herd at the river, walkers only to hide behind: they are not coming for her.)
      local dw = other ~= current and not (canHide(other) and not canShove(other)) and distance(other)
      local stage = dw and (dw <= CLOSE_METERS and "close" or (dw <= NEAR_METERS and "near" or nil))
      if stage and current and stage == "near" then stage = nil end
      if stage and warned[other] ~= stage and not (stage == "near" and warned[other] == "close") then
        warned[other] = stage
        local side = sideOf(other)
        local name = current and ("Another " .. nameOf(other):gsub("^%u", string.lower)) or nameOf(other)
        TWDA.say(("%s, %d meters%s."):format(name, math.floor(dw + 0.5), side and (", " .. side) or ""),
          { interrupt = stage == "close" })
      end
    end
  end
  for agent, stage in pairs(warned) do
    local da = distance(agent)
    if not da or da > NEAR_METERS + 3 then warned[agent] = nil end
  end

  -- In reach: the keys, once per walker and again when they change (a walker shoved offers only Q);
  -- a key pressed while it came is done now.
  local keysNow = current and promptText(promptsOf(current)) or nil
  if current ~= target or keysNow ~= targetKeys then
    target, targetAt, targetKeys = current, now, keysNow
    if current then
      local list = promptsOf(current)
      TWDA.log(("combat4: %s in reach, %s"):format(TWDA.agentName(current), promptText(list)))
      -- Others close behind it: killing one takes long enough for the next to grab her, and that is
      -- death at once ("Walkers are dangerous in groups. Use E to break them up", the woods in
      -- Episode 2). Then a Q pressed early is not done for the player, and the keys are said. (An
      -- early E is: a shove, or AJ's stun in the barn, Episode 4, is what a group calls for.)
      local others = 0
      for _, agent in ipairs(aliveWalkers()) do
        local da = distance(agent)
        if agent ~= current and da and da <= GROUP_METERS and canShove(agent) then others = others + 1 end
      end
      if others > 0 and buffered and buffered.key ~= "E" then
        TWDA.log(("combat4: not doing the early %s, %d more close"):format(buffered.key, others))
        buffered = nil
      end
      local done = false
      if buffered and now - buffered.at <= BUFFER_SECONDS then
        for _, p in ipairs(list) do
          if p.key == buffered.key and not done then
            done = true
            TWDA.log("combat4: doing the early " .. p.key .. " (" .. p.word .. ")")
            press(p.letter)
          end
        end
      end
      buffered = nil
      -- (The herd at the river: the nearest one to hide behind changes all the time as they walk;
      -- the flashlight warnings above say when to press Q.)
      local hideOnly = canHide(current) and not canShove(current)
      if hideOnly and not done then
        -- (nothing said)
      elseif not done and mode == "auto" and #list > 0 then
        -- (Half a second later, below: on the shore at the start of Episode 4 a shove the moment the
        -- first walker was in reach came before the game had set the escape up, and it never began.)
        autoAt = now + 0.5
      elseif not done and #list > 0 and others > 0 then
        TWDA.say(("%s, and %d more close! %s!"):format(nameOf(current), others, promptText(list)), { interrupt = true })
      elseif not done and #list > 0 then
        TWDA.say(("%s! %s!"):format(nameOf(current), promptText(list)), { interrupt = true })
      end
    end
  end

  if autoAt and now >= autoAt then
    autoAt = nil
    local list = current and promptsOf(current) or {}
    if mode == "auto" and #list > 0 then
      local pick = list[1]
      for _, p in ipairs(list) do if p.word == "attack" or p.word == "kill" then pick = p end end
      aimAtReachable()
      TWDA.say(nameOf(current) .. ": " .. pick.word .. "!", { interrupt = true })
      press(pick.letter)
    end
  end

  -- (Auto mode hides her when the light comes or her walker is shot.)
  if hideWanted and mode == "auto" and not hiding and current and canHide(current) then
    hideWanted = nil
    aimAtReachable()
    TWDA.log("combat4: hiding behind " .. TWDA.agentName(current))
    press("x")
  end

  -- Q or E pressed while a walker comes, before it is in reach: kept for a moment.
  for _, k in ipairs({ { 0x51, "Q" }, { 0x45, "E" } }) do
    local okK, down = pcall(InputPCIsVKeyPressed, k[1])
    down = okK and down == true
    if down and not keyHeld[k[2]] and enabled and not current and not struggling and walker and d <= NEAR_METERS then
      buffered = { key = k[2], at = now }
      TWDA.log("combat4: early " .. k[2] .. " kept, walker at " .. string.format("%.1f", d))
    end
    keyHeld[k[2]] = down
  end

  -- Slow mode: while a walker is close or in reach.
  TWDA.setSlowFor("combat4", mode == "slow" and enabled and not struggling and (current ~= nil or (walker ~= nil and d <= CLOSE_METERS)))
end)

-- Walkers to walk up to, for lookaround4.lua's Tab list: one that stays put (pinned under a train car,
-- "ZombieHeadCrush" at the train station) has to be gone to. The walk heads straight for it, so that
-- she faces it (the game offers the strike only within 45 degrees of where she faces, and she turns
-- only by moving), and ends the moment it is in reach.
function TWDA.walkerTargets()
  local props = playerProps()
  if props == nil or get(props, "AI Player - Interaction Enable") ~= true then return {} end
  local list = {}
  local okP, here = pcall(AgentGetWorldPos, TWDA.player())
  if not okP or not here then return list end
  for _, agent in ipairs(aliveWalkers()) do
    local d = distance(agent)
    local okW, pos = pcall(AgentGetWorldPos, agent)
    -- (Not one that can be shoved: it comes for her by itself. Running from the herd on the shore,
    -- Episode 4, Tab's list was walkers to walk up to before the way out.)
    if d and d < 25 and okW and pos and targetOf(props) ~= agent and not canShove(agent) then
      local walker = agent
      list[#list + 1] = { agent = agent, place = true, label = nameOf(agent), distance = d, side = sideOf(agent),
        target = Vector(pos.x, here.y, pos.z), stopAt = 0.6,
        stopWhen = function()
          local p = playerProps()
          return p ~= nil and targetOf(p) == walker
        end }
    end
  end
  return list
end

-- (lookaround4.lua keeps quiet about the scenery while a walker is this close.)
function TWDA.walkerNear(meters)
  local props = playerProps()
  if props == nil or get(props, "AI Player - Interaction Enable") ~= true then return false end
  local walker, d = nearest()
  return walker ~= nil and d <= (meters or 8)
end

-- F6: the walker in reach (first, alone), or the nearest one coming (with the rest of the screen).
function TWDA.describeCombat()
  local props = playerProps()
  if props == nil or get(props, "AI Player - Interaction Enable") ~= true then return nil end
  local current = targetOf(props)
  if current then return ("%s in reach. %s."):format(nameOf(current), promptText(promptsOf(current))) end
  return nil
end

function TWDA.describeWalkers()
  local props = playerProps()
  if props == nil or get(props, "AI Player - Interaction Enable") ~= true then return nil end
  local walker, d = nearest()
  if walker and d <= NEAR_METERS * 2 then
    local side = sideOf(walker)
    return ("%s, %d meters%s. Q or E when it comes"):format(nameOf(walker), math.floor(d + 0.5), side and (", " .. side) or "")
  end
  return nil
end
