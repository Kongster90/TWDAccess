-- Screens that need a key press in Season 2 (projectseason2): the death screen. Death_ShowUI
-- shows "You are dead" and "Click to continue" (Death.imap: a click or the controller's A, both
-- going to the local OnPressButton, which reloads the last checkpoint). Enter does it here.
-- A New Frontier has the same screen; its button handler is Death_OnButtonPress.
local TWDA = ...
local G = _G

local deathShown = false
local function deathButton()
  return rawget(G, "Death_OnButtonA") or rawget(G, "Death_OnButtonPress")
end

TWDA.hookAfter("Death_ShowUI", function()
  if type(deathButton()) ~= "function" then return end
  deathShown = true
  TWDA.say("You are dead. Press Enter to try again from the last checkpoint.", { interrupt = true })
end)

local enterHeld = false
TWDA.onFrame("prompts2", function()
  if not deathShown then return end
  local okMap, active = pcall(InputMapperIsActive, "Death.imap")
  if okMap and not active then
    deathShown = false
    return
  end
  local ok, down = pcall(InputPCIsVKeyPressed, 0x0D)
  down = ok and down == true
  if down and not enterHeld then
    deathShown = false
    TWDA.say("Trying again.", { interrupt = true })
    -- (A New Frontier's Death.imap takes Enter itself.)
    if rawget(G, "Death_OnButtonA") == nil then return end
    pcall(ThreadStart, function()
      local okPress, err = pcall(deathButton(), {})
      if not okPress then TWDA.log("prompts2: death screen: " .. tostring(err)) end
    end)
  end
  enterHeld = down
end)

-- The inventory (inventory.lua): items appear in a bar on the left as Clementine picks them up
-- (Inventory_AddItem("hammer")) and go when used up (Inventory_RemoveItem). Said out loud.
-- The bar labels each icon with node "item_<name>" of the dialog its text agent ui_inventory_text
-- reads ("Survival Knife" for knifeSurvival); items without one are named from their code name.
local function itemName(name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("^ui_item_", "")
  local okA, textAgent = pcall(AgentFind, "ui_inventory_text")
  if okA and textAgent then
    local okF, file = pcall(AgentGetProperty, textAgent, "Text Dialog 2.0 File")
    local text = okF and file and TWDA.nodeText("item_" .. name, file)
    if text then return text end
  end
  local words = name:gsub("([%l])(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2"):gsub("_", " "):lower()
  return words
end

-- (A scene sets up the inventory as it starts, an episode hands over what Clementine carried and a
-- scene can take everything at once: nothing is said for the first seconds of a scene, and
-- changes in the same moment are said together.)
local quietUntil = TWDA.now() + 6
local gained, lost = {}, {}
TWDA.hookBefore("Inventory_AddItem", function(name)
  if type(rawget(G, "Inventory_ItemExists")) ~= "function" or TWDA.now() < quietUntil then return end
  local ok, exists = pcall(Inventory_ItemExists, name)
  if ok and exists then return end
  local words = itemName(name)
  if words then gained[#gained + 1] = words end
end)
TWDA.hookBefore("Inventory_RemoveItem", function(name)
  if TWDA.now() < quietUntil then return end
  local words = itemName(name)
  if words then lost[#lost + 1] = words end
end)
TWDA.onFrame("prompts2.inventory", function()
  if #gained > 0 then
    TWDA.say("Got " .. table.concat(gained, ", "))
    gained = {}
  end
  if #lost > 0 then
    TWDA.say(#lost > 2 and ("Put away: " .. table.concat(lost, ", ")) or ("No more " .. table.concat(lost, ", ")))
    lost = {}
  end
end)

-- On-screen notices (projectseason2's notification.lua): Notification_ShowTutorial(node, delay,
-- duration) shows a hint ("Hold A to escape!" when a walker has Clementine down in the shoe store,
-- Episode 3) and Notification_ShowChoice(node, delay, duration) the "Kenny will remember that."
-- kind. After the delay the local ShowNotification sets the node on its text agent (upvalue
-- kTextAgents, indexed by the upvalue kNotificationTutorial or kNotificationChoice); ShowChoice does
-- nothing when the game's notifications are off. The mod reads the text agent once the node is on
-- it.
local pendingNotes = {} -- { node, index, at, giveUpAt, hint }
-- The Final Season's notices share one text agent (ShowTextNotification's upvalue kTextAgent,
-- "ui_notification_text"), whatever their kind.
local function finalSeasonNoteAgent()
  local showText = TWDA.upvalue(rawget(G, "Notification_ShowTutorial"), "ShowTextNotification")
  local name = showText and TWDA.upvalue(showText, "kTextAgent")
  if type(name) ~= "string" then return nil end
  local ok, agent = pcall(AgentFind, name)
  return ok and agent or nil
end

-- A notice's lines said as sentences, each out of capitals: "You have: ", "RULER", "Thin enough."
-- is "You have: Ruler. Thin enough." (said as one run, the name and its description ran together).
local function noteLines(node, file)
  local ok, raw = pcall(function() return DlgEvaluateToNode(file, node, "text", false):GetText() end)
  if not ok or type(raw) ~= "string" or raw == "" or raw == node then return nil end
  local parts = {}
  for line in (raw .. "\n"):gmatch("([^\n]*)\n") do
    local text = TWDA.cleanText(line)
    if text ~= "" then parts[#parts + 1] = TWDA.normalCaps(text) end
  end
  if #parts == 0 then return nil end
  if #parts > 1 and parts[1]:find(":$") then
    parts[2] = parts[1] .. " " .. parts[2]
    table.remove(parts, 1)
  end
  return TWDA.joinSentences(parts)
end

local function noteText(note)
  local show = TWDA.upvalue(rawget(G, "Notification_ShowTutorial"), "ShowNotification")
  local agents = show and TWDA.upvalue(show, "kTextAgents")
  if agents == nil then
    -- (The notice's own node, in the agent's dialog file: "obj_makeFriends" is "HELP AJ MAKE
    -- FRIENDS". The agent's words lag behind, still the last notice's for a while.)
    local agent = finalSeasonNoteAgent()
    if not agent then return nil end
    local okF, file = pcall(AgentGetProperty, agent, "Text Dialog 2.0 File")
    local text = okF and file and noteLines(note.node, file) or TWDA.nodeText(note.node, okF and file or nil)
    if text and text ~= "" then return text end
    text = TWDA.agentText(agent)
    if not text or text == "" or text == note.before then return nil end
    return text
  end
  local agent = type(agents) == "table" and agents[note.index] or nil
  if type(agent) == "string" then
    local ok, found = pcall(AgentFind, agent)
    agent = ok and found or nil
  end
  if agent == nil then return nil end
  local okN, node = pcall(AgentGetProperty, agent, rawget(G, "kTextNode") or "Text Dialog 2.0 Node Name")
  if not okN or node ~= note.node then return nil end
  return TWDA.agentText(agent)
end
local function queueNote(fnName, indexName, hint, prefix)
  TWDA.hookBefore(fnName, function(node, delay)
    if type(node) ~= "string" then return end
    local index = TWDA.upvalue(rawget(G, fnName), indexName)
    local at = TWDA.now() + (type(delay) == "number" and delay or 0)
    local tfs = finalSeasonNoteAgent()
    pendingNotes[#pendingNotes + 1] = { node = node, index = index, at = at, giveUpAt = at + 2, hint = hint,
      before = tfs and TWDA.agentText(tfs) or nil, prefix = prefix }
  end)
end
queueNote("Notification_ShowTutorial", "kNotificationTutorial", true)
queueNote("Notification_ShowChoice", "kNotificationChoice", false)
-- (The Final Season's other kinds. An objective says so: Episode 4's "Escape" is not the key.)
queueNote("Notification_ShowObjective", "kNotificationObjective", true, "Objective: ")
queueNote("Notification_ShowBranch", "kNotificationBranch", false)
queueNote("Notification_ShowInventory", "kNotificationInventory", false)
queueNote("Notification_ShowRelationship", "kNotificationRelationship", false)
queueNote("Notification_ShowGift", "kNotificationGift", false)
TWDA.onFrame("prompts2.notes", function()
  if #pendingNotes == 0 then return end
  local now = TWDA.now()
  for i = #pendingNotes, 1, -1 do
    local note = pendingNotes[i]
    if now >= note.at then
      local text = noteText(note)
      if text or now > note.giveUpAt then
        table.remove(pendingNotes, i)
        if text then
          text = TWDA.normalCaps(text) -- (The Final Season's are in capitals: "HELP AJ MAKE FRIENDS")
          if note.prefix then text = note.prefix .. text end
          TWDA.log("prompts2: notice " .. note.node .. ": " .. text)
          if note.hint then
            TWDA.lastHint, TWDA.lastHintAt = text, now
            TWDA.say(text, { interrupt = true })
          else
            TWDA.say(text)
          end
        end
      end
    end
  end
end)

-- F6's "Carrying: ...": the inventory's container (upvalue mContainer of Inventory_Activate).
local previousInventory = TWDA.describeInventory
TWDA.describeInventory = function()
  local container = TWDA.upvalue(rawget(G, "Inventory_Activate"), "mContainer")
  if container == nil then return previousInventory and previousInventory() or nil end
  local okN, n = pcall(ContainerGetNumElements, container)
  local items = {}
  for i = 0, (okN and n or 0) - 1 do
    local ok, item = pcall(ContainerGetElement, container, i)
    local words = ok and itemName(tostring(item)) or nil
    if words then items[#items + 1] = words end
  end
  if #items == 0 then return nil end
  return "Carrying: " .. table.concat(items, ", ")
end

local previousHint = TWDA.describeDeath
TWDA.describeDeath = function()
  if deathShown then return "You are dead. Press Enter to try again from the last checkpoint." end
  return previousHint and previousHint() or nil
end
