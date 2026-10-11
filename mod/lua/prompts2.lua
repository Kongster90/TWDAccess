-- Screens that need a key press in Season 2 (projectseason2): the death screen. Death_ShowUI
-- shows "You are dead" and "Click to continue" (Death.imap: a click or the controller's A, both
-- going to the local OnPressButton, which reloads the last checkpoint). Enter does it here.
local TWDA = ...
local G = _G

local deathShown = false

TWDA.hookAfter("Death_ShowUI", function()
  if type(rawget(G, "Death_OnButtonA")) ~= "function" then return end
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
    pcall(ThreadStart, function()
      local okPress, err = pcall(Death_OnButtonA, {})
      if not okPress then TWDA.log("prompts2: death screen: " .. tostring(err)) end
    end)
  end
  enterHeld = down
end)

-- The inventory (inventory.lua): items appear in a bar on the left as Clementine picks them up
-- (Inventory_AddItem("hammer")) and go when used up (Inventory_RemoveItem). Said out loud.
local function itemName(name)
  if type(name) ~= "string" then return nil end
  local words = name:gsub("^ui_item_", ""):gsub("([%l])(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2"):gsub("_", " "):lower()
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
