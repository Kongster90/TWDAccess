-- Season 1's inventory (the game's wdinventory.lua): picking something up or handing it over only
-- shows or hides an icon. The items are registered by AddInventoryItem and kept in the upvalue
-- inventoryItems of WDInventory_Refresh; each has a logic property key ("Inventory - Hammer",
-- "Drugstore - PlayerFood", "Office - got photo"), an icon texture ("ui_useIcon_hammer.d3dtx",
-- sometimes empty) and propValue, the property's value (a count or true/false) kept current by the
-- game's own property callback. The mod compares the values a few times a second and says what
-- changed; F6 adds what Lee is carrying.
local TWDA = ...
local G = _G

local CHECK_SECONDS = 0.3

local function items()
  local list = TWDA.upvalue(rawget(G, "WDInventory_Refresh"), "inventoryItems")
  if type(list) ~= "table" then return nil end
  return list
end

-- "ui_useIcon_walkieTalkie.d3dtx" -> "walkie talkie"; else from the key: "Drugstore - Player
-- Batteries" -> "batteries", "Macon St - Have Brick" -> "brick".
-- Icon names that do not read well as they are (Episodes 3 and 4).
local BETTER = {
  ["map savannah"] = "map of Savannah", ["tape danger"] = "tape", ["shovel empty"] = "shovel",
  ["valve on"] = "valve wheel", ["bottle whiskey"] = "bottle of whiskey", ["key train station"] = "station key",
  ["ice climber"] = "climbing pick", ["photo torn"] = "torn photo", ["dv tape"] = "video tape", ["paper slip logan"] = "paper slip with a code",
}

local function itemName(item)
  local texture = type(item.texture) == "string" and item.texture:match("[Uu]se[Ii]con_([%w]+)") or nil
  local text = texture
  if not text and type(item.key) == "string" then
    text = item.key:match(" %- (.+)$") or item.key
    text = text:gsub("^[Pp]layer ?", ""):gsub("^[Gg]ot ", ""):gsub("^[Hh]ave ", "")
  end
  if not text then return "something" end
  text = text:gsub("(%l)(%u)", "%1 %2"):gsub("_", " "):lower()
  return BETTER[text] or text
end

local function count(value)
  if value == true then return 1 end
  if type(value) == "number" then return value end
  return 0
end

local known = nil -- key -> count, for the current list
local knownList = nil
local lastCheck = 0

TWDA.onFrame("inventory", function()
  local now = TWDA.now()
  if now - lastCheck < CHECK_SECONDS then return end
  lastCheck = now
  local list = items()
  if not list then return end
  if list ~= knownList then
    knownList, known = list, nil
  end
  local first = known == nil
  local current, parts = {}, {}
  for _, item in ipairs(list) do
    if type(item) == "table" and item.key then
      local n = count(item.propValue)
      current[item.key] = n
      local before = not first and known[item.key] or nil
      if before ~= nil and n ~= before then
        local name = itemName(item)
        if n > before then
          TWDA.lastGotAt = now -- (actions.lua: a thing just taken from is not offered to put it back)
          parts[#parts + 1] = n > 1 and ("Got %s, %d now"):format(name, n) or ("Got " .. name)
        else
          parts[#parts + 1] = n > 0 and ("%s, %d left"):format(name, n) or ("No more " .. name)
        end
      end
    end
  end
  known = current
  if #parts > 0 then
    TWDA.log("inventory: " .. table.concat(parts, ", "))
    TWDA.say(table.concat(parts, ". "))
  end
end)

-- For F6: "Carrying: hammer, food (2)", or nil when nothing.
function TWDA.describeInventory()
  local list = items()
  if not list then return nil end
  local names = {}
  for _, item in ipairs(list) do
    if type(item) == "table" then
      local n = count(item.propValue)
      if n > 0 then names[#names + 1] = itemName(item) .. (n > 1 and (" (" .. n .. ")") or "") end
    end
  end
  if #names == 0 then return nil end
  return "Carrying: " .. table.concat(names, ", ")
end
