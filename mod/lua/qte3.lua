-- Quick-time events in A New Frontier (projectseason3's quicktimeevent.lua and
-- quicktimeevent_ui.lua). The PC version binds a key to every prompt (QuickTimeEvent.imap: the
-- arrows and W A S D for directions, Q and E, and Enter for the controller's face buttons:
-- QTE_EnterKey tries "y", "b", "x" and "a"), but the prompts are pictures, so nothing says which.
-- QTE_UI_ShowPrompt(qteAgent, action) shows one; the mod says its key ("Enter!", "Left arrow!").
-- A QTE agent with "QTE - UI Enable Alt Keyboard Keys" takes E for "a" and "b" and Q for "x" and
-- "y" instead, and shows those letters (the siphon pump, Episode 1); Enter does nothing there.
--
-- In the actionscenes modes: slow runs the game at 0.45 speed while a prompt is up; auto does the
-- action itself through the script's own ExecuteAction (an upvalue of the key handlers).
local TWDA = ...
local G = _G

local KEY_WORDS = {
  a = "Enter", b = "Enter", x = "Enter", y = "Enter",
  q = "Q", e = "E", shift = "Shift",
  left = "Left arrow", right = "Right arrow", up = "Up arrow", down = "Down arrow",
}

local function prop(agent, key)
  local ok, value = pcall(AgentGetProperty, agent, key)
  if ok then return value end
  return nil
end

local ALT_KEYS = { a = "E", b = "E", x = "Q", y = "Q" }

local function keyFor(action, agent)
  if type(action) ~= "string" then return nil end
  local name = action:lower():gsub("^hold", "")
  if agent and ALT_KEYS[name] and prop(agent, "QTE - UI Enable Alt Keyboard Keys") == true then return ALT_KEYS[name] end
  return KEY_WORDS[name] or action
end

local active = nil -- { agent, action, at, hold }
local lastSaid, lastSaidAt = nil, 0

local function say(text)
  local now = TWDA.now()
  if text == lastSaid and now - lastSaidAt < 0.6 then return end
  lastSaid, lastSaidAt = text, now
  TWDA.lastHint, TWDA.lastHintAt = text, now
  TWDA.say(text, { interrupt = true })
end

TWDA.hookAfter("QTE_UI_ShowPrompt", function(args)
  local agent, action = args[1], args[2]
  local key = keyFor(action, agent)
  if not key then return end
  local kind = tostring(prop(agent, "QTE - Type") or "")
  TWDA.log(("qte3: prompt %s on %s (type %s, in-world %s)"):format(tostring(action), TWDA.agentName(agent),
    kind, tostring(prop(agent, "QTE - UI Enable In-World"))))
  local hold = kind:lower():find("hold", 1, true) ~= nil or tostring(action):lower():find("^hold") ~= nil
  active = { agent = agent, action = action, at = TWDA.now(), hold = hold }
  say(hold and ("Hold " .. key .. "!") or (key .. "!"))
end)

-- A held prompt: the window to let go opens later (QTE_UI_UpdateHoldTimer's inWindow).
local inWindowSaid = false
TWDA.hookAfter("QTE_UI_StartHoldTimer", function(args)
  inWindowSaid = false
  TWDA.log("qte3: hold timer for " .. tostring(args[2]))
end)
TWDA.hookAfter("QTE_UI_UpdateHoldTimer", function(args)
  local inWindow = args[3]
  if inWindow and not inWindowSaid then
    inWindowSaid = true
    say("Let go!")
  end
end)

TWDA.hookAfter("QTE_UI_ShowTimedButton", function(args)
  TWDA.log(("qte3: timed button %s on %s, prompt %s of %s s"):format(tostring(args[2]), TWDA.agentName(args[1]),
    tostring(args[3]), tostring(args[4])))
end)

local function finished()
  active = nil
  TWDA.setSlowFor("qte3", false)
end
TWDA.hookAfter("QTE_UI_ShowSuccess", finished)
TWDA.hookAfter("QTE_UI_ShowFailure", function(args)
  TWDA.log("qte3: failed " .. tostring(args[2]))
  finished()
end)
TWDA.hookAfter("QTE_SetActivated", function(args)
  if args[1] == false then finished() end
end)

-- Some prompts are things to pick with the reticle, not keys: the QTE's prompt is the agent's name
-- (Clementine's rock at the railroad, "obj_rockClem"; QTE_SetActivated(true) with the reticle on
-- and no QTE_UI_ShowPrompt). The QTE agents (upvalue mQuickTimeEventAgents of the script's
-- ExecuteAction) list them in promptsCurrent. The mod names the thing and Enter does it:
-- ExecuteAction(name) is what a click on it comes to.
local qteOn, qteOffAt = false, -10
TWDA.hookAfter("QTE_SetActivated", function(args)
  qteOn = args[1] == true
  if not qteOn then qteOffAt = TWDA.now() end
end)
-- (Not every prompt comes with QTE_SetActivated: the car door at the Richmond factory, Episode 3.)
for _, name in ipairs({ "QTE_UI_ShowPrompt", "QTE_UI_ShowSuccess", "QTE_UI_ShowFailure", "MultiQTE_Enable" }) do
  TWDA.hookAfter(name, function() qteOffAt = TWDA.now() end)
end

-- Between the prompts of one QTE the game hands control back for a moment (navigation on, things
-- offered); lookaround2.lua waits for this before saying "Javier can move".
function TWDA.qteBusy()
  return qteOn or TWDA.now() - qteOffAt < 1.5
end

local function executeAction()
  return TWDA.upvalue(rawget(G, "QTE_KeyE"), "ExecuteAction")
end

local function isTarget(prompt)
  if type(prompt) ~= "string" or prompt == "" or KEY_WORDS[prompt:lower()] or prompt:lower():find("^hold") then return false end
  local okE, exists = pcall(AgentExists, prompt)
  return okE and exists == true
end

local function targetPrompt()
  local execute = executeAction()
  local list = type(execute) == "function" and TWDA.upvalue(execute, "mQuickTimeEventAgents") or nil
  for _, qte in ipairs(type(list) == "table" and list or {}) do
    local prompts = rawget(qte, "promptsCurrent")
    for _, prompt in ipairs(type(prompts) == "table" and prompts or {}) do
      if isTarget(prompt) then return prompt end
    end
  end
  -- (The Final Season keeps that list empty: its QTE agents, QTE_GetQuickTimeAgents(), carry their
  -- prompts in "QTE Prompt - 1", "- 2"..., "obj_logicalAction" at the train station.)
  local okQ, agents = pcall(rawget(G, "QTE_GetQuickTimeAgents") or function() return nil end)
  for _, qte in ipairs(okQ and type(agents) == "table" and agents or {}) do
    for i = 1, 5 do
      local prompt = prop(qte, "QTE Prompt - " .. i)
      if isTarget(prompt) then return prompt end
    end
  end
  return nil
end

local function targetName(prompt)
  local okA, agent = pcall(AgentFind, prompt)
  local okN, noun = pcall(Game_GetNounText, okA and agent or nil)
  if okN and type(noun) == "string" and noun ~= "" then return TWDA.cleanText(noun) end
  -- "obj_rockClem" -> "rock" (the player's own), "obj_logicalHandConrad" -> "Conrad's hand"
  local parts = {}
  for word in prompt:gsub("^obj_", ""):gsub("([%l%d])(%u)", "%1 %2"):gmatch("%S+") do
    if word:lower() ~= "logical" then parts[#parts + 1] = word end
  end
  local last = parts[#parts]
  -- (A name only if someone of that name is in the scene: "Conrad", not the "Head" of
  -- "obj_zombieHead".)
  local okE, isAgent = pcall(AgentExists, last or "")
  local lowerLast = (last or ""):lower()
  local playerName = lowerLast == "clem" or lowerLast == "javi"
  if #parts >= 2 and last and last:find("^%u%l") and ((okE and isAgent) or playerName) then
    table.remove(parts)
    local rest = table.concat(parts, " "):lower()
    local lower = last:lower()
    if lower == "clem" or lower == "clementine" or lower == "javier" or lower == "javi" then return rest end
    return last .. "'s " .. rest
  end
  return table.concat(parts, " "):lower()
end

local target, enterHeld = nil, false

-- (lookaround4.lua leaves Enter alone while a thing to pick is up: the train station's
-- "obj_logicalAction" is a usable too.)
function TWDA.qteTargetUp()
  return target ~= nil
end
TWDA.onFrame("qte3.targets", function()
  local prompt = qteOn and targetPrompt() or nil
  if prompt ~= (target and target.prompt) then
    target = prompt and { prompt = prompt, at = TWDA.now() } or nil
    if target then
      local name = targetName(prompt)
      TWDA.log("qte3: target " .. prompt .. " (" .. name .. ")")
      say(name:gsub("^%l", string.upper) .. ": Enter!")
    end
  end
  local ok, down = pcall(InputPCIsVKeyPressed, 0x0D)
  down = ok and down == true
  local mode = TWDA.settings.actionscenes or "slow"
  if target then
    TWDA.setSlowFor("qte3.target", mode == "slow")
    local auto = mode == "auto" and not target.autoDone and TWDA.now() - target.at > 0.3
    if (down and not enterHeld) or auto then
      target.autoDone = true
      local execute = executeAction()
      local okX, err = pcall(execute, target.prompt)
      if not okX then TWDA.log("qte3: target failed: " .. tostring(err)) end
    end
  else
    TWDA.setSlowFor("qte3.target", false)
  end
  enterHeld = down
end)

-- Multi-prompt QTEs (multiqte.lua): MultiQTE_Enable(agent, true) shows several prompts at once,
-- from the agent's "QTE Prompt - 1", "- 2"... (the script's list: upvalue mMultiQTE_Table, the next
-- one mCurrentMultiQTEIndex). "QTE - Type" "Rapid" wants them pressed one after another, fast
-- (prying a door at the underpass, Episode 2: E three times); "Simultaneous" all together. The
-- keys are those of single prompts (MultiQTE.imap: E for "a" and "b", Q for "x" and "y", the
-- arrows, Shift, Enter).
local multi = nil -- { agent, at, kind }
local function multiPrompts()
  local list = TWDA.upvalue(rawget(G, "MultiQTE_OnE"), "mMultiQTE_Table")
  return type(list) == "table" and list or {}
end
local function multiText(agent, kind)
  local keys = {}
  for _, prompt in ipairs(multiPrompts()) do
    if type(prompt) == "string" and prompt ~= "" then keys[#keys + 1] = keyFor(prompt, agent) end
  end
  if #keys == 0 then return nil end
  if kind == "Simultaneous" then return "Press " .. table.concat(keys, " and ") .. " together!" end
  local same = true
  for _, k in ipairs(keys) do if k ~= keys[1] then same = false end end
  if same then return ("%s, %d times, fast!"):format(keys[1], #keys) end
  return table.concat(keys, ", then ") .. "!"
end
TWDA.hookAfter("MultiQTE_Enable", function(args)
  local agent, on = args[1], args[2]
  if on ~= true then
    multi = nil
    TWDA.setSlowFor("qte3.multi", false)
    return
  end
  if type(agent) == "string" then
    local okA, found = pcall(AgentFind, agent)
    agent = okA and found or agent
  end
  local kind = tostring(prop(agent, "QTE - Type") or "")
  multi = { agent = agent, at = TWDA.now(), kind = kind, lastPress = 0 }
  local text = multiText(agent, kind)
  TWDA.log(("qte3: multi %s on %s: %s"):format(kind, TWDA.agentName(agent), tostring(text)))
  if text then say(text) end
end)
TWDA.onFrame("qte3.multi", function()
  if not multi then return end
  local mode = TWDA.settings.actionscenes or "slow"
  TWDA.setSlowFor("qte3.multi", mode == "slow")
  if mode ~= "auto" or TWDA.now() - multi.at < 0.3 or TWDA.now() - multi.lastPress < 0.15 then return end
  multi.lastPress = TWDA.now()
  local onInput = TWDA.upvalue(rawget(G, "MultiQTE_OnE"), "OnInput")
  local prompts = multiPrompts()
  if type(onInput) ~= "function" then return end
  if multi.kind == "Simultaneous" then
    for _, prompt in ipairs(prompts) do pcall(onInput, prompt) end
  else
    local index = TWDA.upvalue(rawget(G, "MultiQTE_OnE"), "mCurrentMultiQTEIndex")
    local prompt = type(index) == "number" and prompts[index] or prompts[1]
    if prompt then pcall(onInput, prompt) end
  end
end)

-- The actionscenes modes.
TWDA.onFrame("qte3", function()
  if not active then return end
  local mode = TWDA.settings.actionscenes or "slow"
  TWDA.setSlowFor("qte3", mode == "slow")
  if mode == "auto" and not active.autoDone and TWDA.now() - active.at > 0.3 and not active.hold then
    active.autoDone = true
    local execute = executeAction()
    if type(execute) == "function" then
      local ok, err = pcall(execute, active.action)
      if not ok then TWDA.log("qte3: auto failed: " .. tostring(err)) end
    end
  end
  -- (A prompt that never reports back is let go after 10 seconds.)
  if TWDA.now() - active.at > 10 then finished() end
end)

-- F6 while a prompt is up.
local previous = TWDA.describeAction2
TWDA.describeAction2 = function()
  if active then
    local key = keyFor(active.action, active.agent)
    return active.hold and ("Hold " .. key) or ("Press " .. key)
  end
  if target then return targetName(target.prompt):gsub("^%l", string.upper) .. ": press Enter" end
  return previous and previous() or nil
end
