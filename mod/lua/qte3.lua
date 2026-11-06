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
-- (Michonne: each QTE agent's last prompt said, by its actionActivateTime; see qte3.agents.)
local shownAt = setmetatable({}, { __mode = "k" })
local lastSaid, lastSaidAt = nil, 0

local function say(text)
  local now = TWDA.now()
  if text == lastSaid and now - lastSaidAt < 0.6 then return end
  lastSaid, lastSaidAt = text, now
  TWDA.lastHint, TWDA.lastHintAt = text, now
  TWDA.urgentAt = now -- (a tip shown with it waits: prompts2.lua)
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
  if type(agent) == "table" then shownAt[agent] = rawget(agent, "actionActivateTime") end
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

-- The things to pick now, as a list (usually one).
local function targetPrompts()
  local execute = executeAction()
  local list = type(execute) == "function" and TWDA.upvalue(execute, "mQuickTimeEventAgents") or nil
  for _, qte in ipairs(type(list) == "table" and list or {}) do
    local prompts = rawget(qte, "promptsCurrent")
    for _, prompt in ipairs(type(prompts) == "table" and prompts or {}) do
      if isTarget(prompt) then return { prompt } end
    end
  end
  -- (The Final Season keeps that list by scene, and its QTE agents, QTE_GetQuickTimeAgents(), carry
  -- their prompts in "QTE Prompt - 1", "- 2"..., "obj_logicalAction" at the train station.)
  -- (Several in turn, "obj_logicalAction01" then "02" when Lilly comes at Clementine in Episode 2:
  -- the one to pick now is the one the game has made selectable, kGameSelectable. Several at once
  -- in one prompt, "obj_logicalArmandoKnee,obj_logicalArmandoHead" for the ambush on the boat in
  -- Episode 3: a choice of either, ExecuteAction takes each name.)
  local okQ, agents = pcall(rawget(G, "QTE_GetQuickTimeAgents") or function() return nil end)
  local all, selected, offered = {}, {}, false
  for _, qte in ipairs(okQ and type(agents) == "table" and agents or {}) do
    for i = 1, 5 do
      local value = prop(qte, "QTE Prompt - " .. i)
      for prompt in tostring(value or ""):gmatch("[^,%s]+") do
        -- (Once each: the knife on the boat, Episode 3, is "obj_knifeKaBar,obj_knifeKaBar".)
        local seen = false
        for _, other in ipairs(all) do seen = seen or other == prompt end
        if isTarget(prompt) and not seen then
          all[#all + 1] = prompt
          local okA, agent = pcall(AgentFind, prompt)
          local selectable = okA and agent and prop(agent, rawget(G, "kGameSelectable"))
          if selectable == true then selected[#selected + 1] = prompt end
          if selectable == false then offered = true end
        end
      end
    end
  end
  if #selected > 0 then return selected end
  -- (None selectable just now, between two: nothing to pick yet.)
  if offered or #all == 0 then return nil end
  return all
end

local function targetName(prompt)
  local okA, agent = pcall(AgentFind, prompt)
  local okN, noun = pcall(Game_GetNounText, okA and agent or nil)
  if okN and type(noun) == "string" and noun ~= "" then return TWDA.cleanText(noun) end
  -- "obj_rockClem" -> "rock" (the player's own), "obj_logicalHandConrad" -> "Conrad's hand"
  local parts = {}
  for word in prompt:gsub("^obj_", ""):gsub("([%l%d])(%u)", "%1 %2"):gmatch("%S+") do
    -- (Not a model number: Lilly's gun on the boat, Episode 3, "obj_gunP250".)
    if word:lower() ~= "logical" and not (#parts > 0 and word:find("^%u%d+$")) then parts[#parts + 1] = word end
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
  -- (The name first: the ambush on the boat, Episode 3, "obj_logicalArmandoKnee" -> "Armando's knee".)
  local firstWord = parts[1]
  local okF, isPerson = pcall(AgentExists, firstWord or "")
  if #parts >= 2 and firstWord and firstWord:find("^%u%l") and okF and isPerson then
    table.remove(parts, 1)
    return firstWord .. "'s " .. table.concat(parts, " "):lower()
  end
  -- (Shooting from the beach, Episode 4: "obj_logicalZombieHead1" -> "walker head 1".)
  local text = table.concat(parts, " "):lower():gsub("(%a)(%d)", "%1 %2"):gsub("^zombie ", "walker ")
  return text
end

local target, enterHeld, tabHeld = nil, false, false

-- (lookaround4.lua leaves Enter and Tab alone while a thing to pick is up: the train station's
-- "obj_logicalAction" is a usable too.)
function TWDA.qteTargetUp()
  return target ~= nil
end
local function capital(text)
  return (text:gsub("^%l", string.upper))
end
TWDA.onFrame("qte3.targets", function()
  -- (A key prompt up wins over a thing to pick: fighting zombie Brody in the school's basement,
  -- Episode 1, "Left arrow!" came with obj_logicalAction still listed, and "Action: Enter!" talked
  -- over it.)
  local keyUp = active ~= nil and TWDA.now() - active.at < 8
  local prompts = qteOn and not keyUp and targetPrompts() or nil
  local key = prompts and table.concat(prompts, ",") or nil
  if key ~= (target and target.key) then
    target = prompts and { prompts = prompts, key = key, index = 1, at = TWDA.now() } or nil
    if target then
      local names = {}
      for i, prompt in ipairs(prompts) do names[i] = targetName(prompt) end
      target.names = names
      TWDA.log("qte3: target " .. key .. " (" .. table.concat(names, ", ") .. ")")
      if #names == 1 then
        say(capital(names[1]) .. ": Enter!")
      else
        say((TWDA.tabWords("%s, or %s. Tab to choose, Enter does %s!")):format(capital(table.concat(names, ", ", 1, #names - 1)),
          names[#names], names[1]))
      end
    end
  end
  local ok, down = pcall(InputPCIsVKeyPressed, 0x0D)
  down = ok and down == true
  local okT, tab = pcall(InputPCIsVKeyPressed, TWDA.tabVK or 0x09)
  tab = okT and tab == true
  local mode = TWDA.settings.actionscenes or "slow"
  if target then
    TWDA.setSlowFor("qte3.target", mode == "slow")
    if tab and not tabHeld and #target.prompts > 1 then
      local okS, shift = pcall(InputPCIsVKeyPressed, 0x10)
      target.index = (target.index - 1 + ((okS and shift) and -1 or 1)) % #target.prompts + 1
      say(capital(target.names[target.index]) .. ": Enter!")
    end
    local auto = mode == "auto" and not target.autoDone and TWDA.now() - target.at > 0.3
    if (down and not enterHeld) or auto then
      target.autoDone = true
      local execute = executeAction()
      local okX, err = pcall(execute, target.prompts[target.index])
      if not okX then TWDA.log("qte3: target failed: " .. tostring(err)) end
    end
  else
    TWDA.setSlowFor("qte3.target", false)
  end
  enterHeld, tabHeld = down, tab
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
-- (Michonne's MultiQTE_Enable takes about 0.65 s to return, a third of the time to press the keys
-- in the ferry fight, Episode 1: so the prompts are read from the agent's "QTE Prompt - 1", "- 2"...
-- as it starts, and from the script's own list once it is done if that was not possible.)
local function agentMultiText(agent, kind)
  local keys = {}
  for i = 1, 8 do
    local prompt = prop(agent, "QTE Prompt - " .. i)
    prompt = prompt ~= nil and tostring(prompt) or nil -- (not always a Lua string)
    if prompt == nil or prompt == "" or prompt:find(",") then break end
    local key = keyFor(prompt, agent)
    if not KEY_WORDS[prompt:lower():gsub("^hold", "")] then return nil end
    keys[#keys + 1] = key
  end
  if #keys < 2 then return nil end
  if kind == "Simultaneous" then return "Press " .. table.concat(keys, " and ") .. " together!" end
  local same = true
  for _, k in ipairs(keys) do if k ~= keys[1] then same = false end end
  if same then return ("%s, %d times, fast!"):format(keys[1], #keys) end
  return table.concat(keys, ", then ") .. "!"
end
local function findAgent(agent)
  if type(agent) == "string" then
    local okA, found = pcall(AgentFind, agent)
    return okA and found or agent
  end
  return agent
end
local multiSaid, multiSaidAt = nil, -10
TWDA.hookBefore("MultiQTE_Enable", function(agent, on)
  if on ~= true then return end
  agent = findAgent(agent)
  local text = agentMultiText(agent, tostring(prop(agent, "QTE - Type") or ""))
  if text then
    TWDA.log(("qte3: multi on %s (as it starts): %s"):format(TWDA.agentName(agent), text))
    multiSaid, multiSaidAt = text, TWDA.now()
    say(text)
  end
end)
TWDA.hookAfter("MultiQTE_Enable", function(args)
  local agent, on = args[1], args[2]
  if on ~= true then
    multi = nil
    TWDA.setSlowFor("qte3.multi", false)
    return
  end
  agent = findAgent(agent)
  local kind = tostring(prop(agent, "QTE - Type") or "")
  multi = { agent = agent, at = TWDA.now(), kind = kind, lastPress = 0 }
  local text = multiText(agent, kind)
  TWDA.log(("qte3: multi %s on %s: %s"):format(kind, TWDA.agentName(agent), tostring(text)))
  if text and not (text == multiSaid and TWDA.now() - multiSaidAt < 3) then say(text) end
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

-- Michonne's prompts (the arrow drawn over the bush to slash at, Episode 1) are shown by
-- ShowNextPrompt, a local of quicktimeevent.lua, often without QTE_UI_ShowPrompt. Each QTE agent's
-- table (mQuickTimeEventAgents) says what is up: actionPromptShown, promptsCurrent ({ "left" }, or
-- several that each do) and actionActivateTime, new for each prompt.
local pollAt = 0
TWDA.onFrame("qte3.agents", function()
  local now = TWDA.now()
  if now - pollAt < 0.05 then return end
  pollAt = now
  local execute = executeAction()
  local list = type(execute) == "function" and TWDA.upvalue(execute, "mQuickTimeEventAgents") or nil
  for _, qte in ipairs(type(list) == "table" and list or {}) do
    local when = rawget(qte, "actionActivateTime")
    if rawget(qte, "actionPromptShown") == true and when ~= nil and shownAt[qte] ~= when then
      shownAt[qte] = when
      local keys, first = {}, nil
      for _, prompt in ipairs(rawget(qte, "promptsCurrent") or {}) do
        local key = type(prompt) == "string" and KEY_WORDS[prompt:lower():gsub("^hold", "")] and keyFor(prompt, qte) or nil
        if key then
          first = first or prompt
          local seen = false
          for _, k in ipairs(keys) do seen = seen or k == key end
          if not seen then keys[#keys + 1] = key end
        end
      end
      if first then
        TWDA.log(("qte3: prompt %s on %s (shown by the agent)"):format(table.concat(rawget(qte, "promptsCurrent"), ","),
          TWDA.agentName(qte)))
        local hold = first:lower():find("^hold") ~= nil
        active = { agent = qte, action = first, at = now, hold = hold }
        local words = table.concat(keys, " or ")
        say(hold and ("Hold " .. words .. "!") or (words .. "!"))
      end
    elseif rawget(qte, "actionPromptShown") ~= true and active and active.agent == qte then
      finished()
    end
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
  if target then
    local now = capital(target.names[target.index]) .. ": press Enter"
    if #target.names > 1 then now = now .. TWDA.tabWords(". Tab for ") .. table.concat(target.names, " or ") end
    return now
  end
  return previous and previous() or nil
end
