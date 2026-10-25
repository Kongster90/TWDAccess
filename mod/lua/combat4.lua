-- Walkers in The Final Season (projectseason4's ai_player.lua): Clementine fights walkers in free
-- walking. When one is in reach (about 2 meters), the player's AI properties (ExecuteInteraction's
-- upvalue mPlayer, its mProps) name it as "AI Player - Interaction Current Target", and the walker's
-- own "AI Agent - Player Used Interaction Prompt 1/2" give the prompts ("y" with "cs_attackTarget",
-- "b" with "cs_stunTarget"). Q (AI_Player_Q) takes an "x" or "y" prompt, E an "a" or "b" one, the
-- left mouse button an "rt" one. The window is short, about half a second before the walker grabs
-- her (a struggle, struggle.lua).
--
-- The mod says when a walker comes near and from where, names the keys once one is in reach, and
-- remembers Q or E pressed while one is coming (for 1.5 seconds), doing it the moment it is in
-- reach. Slow mode slows the game while one is close; auto mode attacks by itself.
local TWDA = ...
local G = _G

local KEYS = { a = "E", b = "E", e = "E", x = "Q", y = "Q", q = "Q", rt = "Left click", l = "Left click" }
local NEAR_METERS, CLOSE_METERS = 6, 3.5
local BUFFER_SECONDS = 1.5

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
local WORDS = { stun = "shove", attack = "attack", kill = "kill", push = "push", shove = "shove", stab = "stab" }
local function actionWord(node)
  local word = tostring(node or ""):gsub("^cs_", ""):gsub("Target$", ""):gsub("([%l])(%u)", "%1 %2"):lower()
  return WORDS[word] or (word ~= "" and word or "act")
end

local function targetOf(props)
  local name = get(props, "AI Player - Interaction Current Target Override")
  if not name or name == "" then name = get(props, "AI Player - Interaction Current Target") end
  if not name or name == "" then return nil end
  local ok, agent = pcall(AgentFind, name)
  return ok and agent or nil
end

-- The prompts a walker offers: { key = "Q", letter = "y", word = "attack" }.
local function promptsOf(agent)
  local list = {}
  for i = 1, 2 do
    local pre = "AI Agent - Player Used Interaction Prompt " .. i
    if prop(agent, pre .. " Enable") == true then
      local letter = tostring(prop(agent, pre) or ""):lower()
      if KEYS[letter] then
        list[#list + 1] = { key = KEYS[letter], letter = letter, word = actionWord(prop(agent, pre .. " Dialog Node")) }
      end
    end
  end
  return list
end

local function nameOf(agent)
  local noun = call("Game_GetNounText", agent)
  if type(noun) == "string" and noun ~= "" then return TWDA.cleanText(noun) end
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

local warned = setmetatable({}, { __mode = "k" }) -- walker -> "near" or "close"
local target, targetAt = nil, 0
local buffered = nil -- { key, at }
local keyHeld = {}

TWDA.onFrame("combat4", function()
  local props = playerProps()
  if props == nil then return end
  local enabled = get(props, "AI Player - Interaction Enable") == true
  local now = TWDA.now()
  local mode = TWDA.settings.actionscenes or "slow"
  local struggling = TWDA.struggleActive and TWDA.struggleActive()
  local current = enabled and targetOf(props) or nil
  local walker, d = nil, math.huge
  if enabled and not struggling then walker, d = nearest() end

  -- A walker coming near: said once at about 6 meters and again at 3.5.
  if walker and not current then
    local stage = d <= CLOSE_METERS and "close" or (d <= NEAR_METERS and "near" or nil)
    if stage and warned[walker] ~= stage and not (stage == "near" and warned[walker] == "close") then
      warned[walker] = stage
      local side = sideOf(walker)
      TWDA.say(("%s, %d meters%s."):format(nameOf(walker), math.floor(d + 0.5), side and (", " .. side) or ""),
        { interrupt = stage == "close" })
    end
  end
  for agent, stage in pairs(warned) do
    local da = distance(agent)
    if not da or da > NEAR_METERS + 3 then warned[agent] = nil end
  end

  -- In reach: the keys, once per walker; a key pressed while it came is done now.
  if current ~= target then
    target, targetAt = current, now
    if current then
      local list = promptsOf(current)
      TWDA.log(("combat4: %s in reach, %s"):format(TWDA.agentName(current), promptText(list)))
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
      if not done and mode == "auto" and #list > 0 then
        local pick = list[1]
        for _, p in ipairs(list) do if p.word == "attack" or p.word == "kill" then pick = p end end
        TWDA.say(nameOf(current) .. ": " .. pick.word .. "!", { interrupt = true })
        press(pick.letter)
      elseif not done and #list > 0 then
        TWDA.say(("%s! %s!"):format(nameOf(current), promptText(list)), { interrupt = true })
      end
    end
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
    if d and d < 25 and okW and pos and targetOf(props) ~= agent then
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
