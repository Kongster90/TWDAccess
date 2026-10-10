-- Directional choices in Season 1 (the game's mode_choice.lua): during some action scenes the
-- arrow keys turn Lee towards one side or another, and what can be done is then on that side. The
-- first is the attack at Hershel's fence (Episode 1): Left turns towards Shawn, Right towards
-- Duck, and each view then offers "Help" (read out by actions.lua; Tab and Enter as usual).
--
-- What the game does: Choice_Start pushes mode_choice (input map mode_choice.imap). The logic
-- agent (upvalue kLogicAgentName, "logic_mode_choice") holds one dialog node per side ("Choice -
-- Dlg Node Left" and so on, such as "choice_centerToShawn"); an empty node means nothing that way.
-- The local transition(side) plays that node (the turn) and the nodes then change for the new view.
-- On PC the arrow keys' handlers (OnButtonLeft...) return at once (they only work on one TV-box
-- platform); a mouse player turns by pushing the reticle to a screen edge (the mode's update
-- thread). So the mod calls transition itself for the arrow keys.
local TWDA = ...
local G = _G

local SIDES = { { "kPropLeftNode", "Left arrow", 0x25, "kSideLeft" }, { "kPropRightNode", "Right arrow", 0x27, "kSideRight" },
  { "kPropUpNode", "Up arrow", 0x26, "kSideUp" }, { "kPropDownNode", "Down arrow", 0x28, "kSideDown" } }

local function active()
  local ok, on = pcall(InputMapperIsActive, "mode_choice.imap")
  return ok and on == true
end
TWDA.turnChoiceActive = active

-- The person furthest that way on screen, for nodes that only name a direction: Larry's heart
-- attack in the meat locker ("choice_CenterToLeft": Kenny is on the left, Lilly on the right);
-- Omid and Christa hanging from the train at the end of Episode 3 ("choice_centerLeft", then
-- "choice_left"; their actions are "Grab" and "Yell To", so a person is any agent with a name of
-- its own that is not an object).
local SIGN = { Left = -1, Right = 1 }
local function isPerson(agent)
  local okLee, lee = pcall(Game_GetPlayer)
  if okLee and agent == lee then return false end
  -- (Not the walkers hanging on: "Zombie" has a name of its own too.)
  local shown = tostring(TWDA.hotspotName(agent) or ""):lower()
  if shown:find("zombie") or shown:find("walker") or shown == "lee" then return false end
  local verb = TWDA.hotspotVerb(agent)
  if type(verb) == "string" and verb:lower():find("^talk") then return true end
  local name = TWDA.agentName(agent) or ""
  return not name:lower():find("^obj_") and not name:lower():find("trigger") and TWDA.isFightTarget ~= nil
    and not TWDA.isFightTarget(agent)
end
local function personTowards(direction)
  local sign = SIGN[direction]
  local useables = TWDA.upvalue(rawget(G, "Reticle_Update"), "mUseables")
  if not sign or type(useables) ~= "table" or not TWDA.hotspotVerb then return nil end
  local best, bestX = nil, nil
  for _, agent in ipairs(useables) do
    local ok, pos = pcall(AgentGetScreenPos, agent)
    local hidden = select(2, pcall(AgentIsHidden, agent)) == true
    if not hidden and isPerson(agent) and ok and pos and (pos.z or 1) > 0 then
      local x = (pos.x - 0.5) * sign
      if x > 0.1 and (not bestX or x > bestX) then best, bestX = agent, x end
    end
  end
  return best and TWDA.hotspotName(best) or nil
end

-- "choice_centerToShawn" -> "towards Shawn"; otherwise the node name made readable ("smash_left",
-- pushing zombie David's head away in Episode 2 -> "to smash left").
-- (Each node is named once while the choice lasts: people move about on screen, and a name that
-- changed with them made the same choice be announced again and again.)
local named = {}
local function whereUncached(node)
  local target = node:match("To(%u[%w]*)$")
  local person = target and personTowards(target)
  if person then return "towards " .. person end
  -- ("choice_centerLeft", "choice_left": only a direction.)
  local direction = node:match("[Ll]eft$") and "Left" or node:match("[Rr]ight$") and "Right" or nil
  person = direction and personTowards(direction)
  if person then return "towards " .. person end
  local text = target or node:gsub("^choice_", "")
  text = text:gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
  return (target and "towards " or "to ") .. text
end
local function where(node)
  named[node] = named[node] or whereUncached(node)
  return named[node]
end

-- The arrows that do something now, as "Left arrow towards Shawn", and the side numbers of those
-- arrows' keys.
local function directions()
  local mode = rawget(G, "mode_choice")
  if type(mode) ~= "table" then return nil end
  local left = TWDA.unwrap(rawget(mode, "OnButtonLeft"))
  local logicName = TWDA.upvalue(left, "kLogicAgentName")
  local nodesFn = TWDA.upvalue(left, "hasTransitionNodes")
  local update = TWDA.upvalue(rawget(mode, "OnActivate"), "update")
  local okAgent, agent = pcall(AgentFind, logicName)
  if not okAgent or agent == nil or type(nodesFn) ~= "function" then return nil end
  local parts, keys = {}, {}
  for _, side in ipairs(SIDES) do
    local key = TWDA.upvalue(nodesFn, side[1])
    local okNode, node = pcall(AgentGetProperty, agent, key)
    if okNode and type(node) == "string" and node:match("%S") then
      parts[#parts + 1] = side[2] .. " " .. where(node)
      keys[side[3]] = TWDA.upvalue(update, side[4])
    end
  end
  return parts, keys, TWDA.upvalue(left, "transition")
end

local held = {}
local function pressed(vk)
  local ok, down = pcall(InputPCIsVKeyPressed, vk)
  down = ok and down == true
  local edge = down and not held[vk]
  held[vk] = down
  return edge
end

local lastKey = nil
local inactiveSince = nil
local dropped = false -- the mode went away for a moment (a turn or a push played) since the last announcement
local lastTurn = -10
TWDA.describeTurnChoice = function()
  if not active() then return nil end
  local parts = directions()
  if not parts or #parts == 0 then return nil end
  return "Turn: " .. table.concat(parts, ", ")
end

TWDA.onFrame("turnchoice", function()
  local now = TWDA.now()
  if not active() then
    -- (The mode drops out for a moment while a turn plays; only a real end starts afresh.)
    inactiveSince = inactiveSince or now
    dropped = lastKey ~= nil
    if now - inactiveSince > 2 then
      lastKey, dropped, named = nil, false, {}
      if type(TWDA.lastHint) == "string" and TWDA.lastHint:find("^Turn: ") then TWDA.lastHint = nil end
    end
    for _, side in ipairs(SIDES) do pressed(side[3]) end -- keep the key states current
    return
  end
  inactiveSince = nil
  local parts, keys, transition = directions()
  if not parts then return end
  for _, side in ipairs(SIDES) do
    -- (A second press while a turn is still playing is dropped.)
    if pressed(side[3]) and now - lastTurn > 1.2 then
      local number = keys[side[3]]
      if number and type(transition) == "function" then
        lastTurn = now
        TWDA.log("turnchoice: turning, side " .. tostring(number))
        local ok, err = pcall(transition, number)
        if not ok then TWDA.log("turnchoice: " .. tostring(err)) end
      elseif #parts > 0 then
        TWDA.say("Nothing that way. " .. table.concat(parts, ", "), { interrupt = true })
      end
    end
  end
  local key = table.concat(parts, ", ")
  if key == "" or (key == lastKey and not dropped) then return end
  -- The first time it interrupts; after a turn it waits for what the new view offers (actions.lua).
  -- The same choice back again after a moment (zombie David's head, pushed away again and again in
  -- Episode 2) is said again at once.
  local first = lastKey == nil or key == lastKey
  lastKey, dropped = key, false
  TWDA.log("turnchoice: " .. key)
  TWDA.lastHint = "Turn: " .. key
  TWDA.say(TWDA.lastHint, { interrupt = first })
end)
