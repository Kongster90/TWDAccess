-- Stargazing in The Final Season (projectseason4's constellation.lua: the bell tower with Violet,
-- Episode 2): stars are buttons ("ui_star_<constellation>Button<n>", each with the "Button -
-- Command" Constellation_ActivateStar(n)), linked by holding the left mouse button and dragging
-- from star to star; the game marks which stars can be linked next (kGameSelectable) and ends the
-- scene when the lines are all drawn. With the mouse only.
--
-- The mod: Tab picks the next star that can be linked, saying where it lies from the last one
-- ("up and to the right"), and Enter links it (Constellation_ActivateStar, what a drag onto it
-- comes to).
local TWDA = ...
local G = _G

local VK_TAB, VK_SHIFT = 0x09, 0x10

local function up(name)
  return TWDA.upvalue(rawget(G, "Constellation_ActivateStar"), name)
end

local function active()
  local map = TWDA.upvalue(rawget(G, "Constellation_Enter"), "kInputMap")
  if type(map) ~= "string" or type(up("mConstellation")) ~= "table" then return false end
  local ok, on = pcall(InputMapperIsActive, map)
  return ok and on == true
end
TWDA.starsActive = active

local function starAgent(star)
  local name = up("mConstellationName")
  if type(name) ~= "string" then return nil end
  local ok, agent = pcall(AgentFind, ("ui_star_%sButton%d"):format(name, star))
  return ok and agent or nil
end

local function position(agent)
  local ok, pos = pcall(AgentGetLogicalScreenPos, agent)
  return ok and pos or nil
end

-- The stars that can be linked now: { star, agent, pos }, in number order.
local function selectable()
  local list = {}
  for star in pairs(up("mConstellation") or {}) do
    local agent = type(star) == "number" and starAgent(star)
    local ok, on = pcall(AgentGetProperty, agent, rawget(G, "kGameSelectable"))
    if agent and ok and on == true then list[#list + 1] = { star = star, agent = agent, pos = position(agent) } end
  end
  table.sort(list, function(a, b) return a.star < b.star end)
  return list
end

-- "up and to the right" from the last star linked (screen y grows downwards).
local function direction(from, to)
  if not (from and to) then return nil end
  local dx, dy = to.x - from.x, to.y - from.y
  local parts = {}
  if math.abs(dy) > 0.04 then parts[#parts + 1] = dy < 0 and "up" or "down" end
  if math.abs(dx) > 0.04 then parts[#parts + 1] = dx < 0 and "to the left" or "to the right" end
  if #parts == 0 then return "right by it" end
  return table.concat(parts, " and ")
end

local chosen, wasActive, held = nil, false, {}

local function describe(entry)
  local last = up("mLastStar")
  local lastAgent = type(last) == "number" and starAgent(last) or nil
  local dir = lastAgent and direction(position(lastAgent), entry.pos)
  return ("Star %d%s"):format(entry.star, dir and (", " .. dir) or "")
end

TWDA.onFrame("stars4", function()
  local on = active()
  if on ~= wasActive then
    wasActive, chosen = on, nil
    if on then
      local n = #selectable()
      TWDA.say(("Stars to link, %d. Tab picks a star, Enter links it."):format(n), { interrupt = true })
    end
  end
  if not on then return end
  local ok, down = pcall(InputPCIsVKeyPressed, VK_TAB)
  down = ok and down == true
  if down and not held.tab then
    local list = selectable()
    if #list == 0 then
      TWDA.say("No star to link.", { interrupt = true })
    else
      local okS, shift = pcall(InputPCIsVKeyPressed, VK_SHIFT)
      local index = 0
      for i, entry in ipairs(list) do if chosen and entry.star == chosen then index = i end end
      index = ((index - 1 + ((okS and shift) and -1 or 1)) % #list) + 1
      if index < 1 then index = #list end
      chosen = list[index].star
      TWDA.say(("%s, %d of %d"):format(describe(list[index]), index, #list), { interrupt = true })
    end
  end
  held.tab = down
end)

-- Enter links the star picked with Tab; with none picked, the first. (Enter is the use key's,
-- Useable_OnButtonUse; the controller's button is Constellation_OnPressButton. A click is left to
-- the mouse.)
local function link()
  local list = selectable()
  local pick = nil
  for _, entry in ipairs(list) do if entry.star == chosen then pick = entry end end
  pick = pick or list[1]
  if not pick then return false end
  TWDA.log("stars4: linking star " .. pick.star)
  chosen = nil
  local ok, err = pcall(rawget(G, "Constellation_ActivateStar"), pick.star)
  if not ok then TWDA.log("stars4: " .. tostring(err)) end
  local left = #selectable()
  TWDA.say(("Linked star %d.%s"):format(pick.star, left > 0 and (" " .. left .. " to choose from.") or ""), { interrupt = true })
  return true
end

for _, name in ipairs({ "Useable_OnButtonUse", "Constellation_OnPressButton" }) do
  TWDA.hookGlobal(name, function(original)
    return function(event, ...)
      if active() and not (type(event) == "table" and event.code == 816) and link() then return end
      return original(event, ...)
    end
  end)
end

function TWDA.describeStars()
  if not active() then return nil end
  return ("Stargazing. %d stars can be linked. Tab picks one, Enter links it."):format(#selectable())
end
