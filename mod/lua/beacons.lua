-- Sound beacons in free play, every season: what Tab chose sounds where it is, so one can walk to
-- it by ear (setting beacons = tab, the default). With beacons = all the nearest few of Tab's list
-- ping in turn as well, a few times a second (too many at once to tell apart, the user found).
-- Each is panned to where it lies from where the camera looks (the walking keys go by the camera too, so
-- a beacon on the right is reached with D, even after a cut to another fixed camera in Season 1),
-- louder the nearer, muffled behind (sounds.lua). Each kind has its sound: a short high blip for a
-- thing to interact with, a rising two-note chime for a place to walk to, a low buzz for a walker.
-- F4 goes from Tab's choice to all to off (setting beacons). The lists come from each season's look-around module
-- (TWDA.beaconEntries: lookaround.lua for Season 1 and 400 Days, lookaround2.lua for Season 2 and A
-- New Frontier, lookaround4.lua for The Final Season), only where the player walks freely: quiet
-- in close-ups, talks and scenes, and while the bow is drawn (bow4.lua has its own tone).
local TWDA = ...

local PING_EVERY = 0.22 -- seconds between pings (one thing each)
local PING_CHOSEN_EVERY = 0.4 -- the same with only Tab's choice to sound
local LIST_EVERY = 0.5 -- seconds between looking for what is about
local LIST_CHOSEN_EVERY = 0.25 -- (sooner after a Tab)
local NEAREST = 4
local RANGE = 25 -- meters

local KINDS = {
  thing = { f = 1200, ms = 30, w = "s" },
  place = { f = { 660, 990 }, ms = 45, w = "s" },
  walker = { f = 140, ms = 110, w = "q" },
}

local list, listAt, nextIndex, lastPing = {}, -10, 1, 0

-- "tab", "all" or "off" (true and false from before there were three: tab and off).
local function mode()
  local value = TWDA.settings.beacons
  if value == true or value == nil then return "tab" end
  if value == false then return "off" end
  return value
end

local MODES = { "tab", "all", "off" }
local MODE_TEXT = { tab = TWDA.tabWords("Beacons on what Tab chose."), all = "Beacons on everything near.", off = "Beacons off." }

function TWDA.toggleBeacons()
  local nextMode = MODES[1]
  for i, m in ipairs(MODES) do
    if m == mode() then nextMode = MODES[i % #MODES + 1] end
  end
  TWDA.settings.beacons = nextMode
  if TWDA.saveSettings then TWDA.saveSettings() end
  list, nextIndex = {}, 1
  TWDA.say(MODE_TEXT[nextMode], { interrupt = true })
end

local function refresh()
  local found = TWDA.beaconEntries and TWDA.beaconEntries() or {}
  local near, chosen = {}, nil
  for _, e in ipairs(found) do
    local dir = TWDA.soundDirection(e.point)
    if dir and dir.distance <= RANGE then
      e.distance = dir.distance
      near[#near + 1] = e
    end
    if e.chosen then chosen = e end
  end
  table.sort(near, function(a, b) return a.distance < b.distance end)
  list = {}
  local count = mode() == "all" and NEAREST or 0
  for i = 1, math.min(count, #near) do list[i] = near[i] end
  -- (What Tab chose sounds too, however far.)
  if chosen then
    local included = false
    for _, e in ipairs(list) do if e.agent == chosen.agent then included = true end end
    if not included then list[#list + 1] = chosen end
  end
  if nextIndex > #list then nextIndex = 1 end
end

local function ping(e)
  -- (Things and walkers move: where they are now.)
  if e.kind ~= "place" then
    local ok, pos = pcall(AgentGetWorldPos, e.agent)
    if ok and pos then e.point = pos end
  end
  local dir = TWDA.soundDirection(e.point)
  if not dir then return end
  local sound = KINDS[e.kind] or KINDS.thing
  local volume = 0.08 + 0.4 * math.max(0, 1 - dir.distance / RANGE)
  local f = sound.f
  if dir.behind then
    -- (A little lower behind, as well as muffled.)
    if type(f) == "table" then
      local lower = {}
      for i, v in ipairs(f) do lower[i] = math.floor(v * 0.85) end
      f = lower
    else
      f = math.floor(f * 0.85)
    end
  end
  TWDA.tone({ f = f, ms = sound.ms, w = sound.w, p = dir.pan, v = volume, behind = dir.behind })
end

TWDA.onFrame("beacons", function()
  if mode() == "off" or not TWDA.tone or not TWDA.soundDirection then return end
  if TWDA.bowDrawn and TWDA.bowDrawn() then return end
  local now = TWDA.now()
  local chosenOnly = mode() == "tab"
  if now - lastPing < (chosenOnly and PING_CHOSEN_EVERY or PING_EVERY) then return end
  lastPing = now
  if now - listAt >= (chosenOnly and LIST_CHOSEN_EVERY or LIST_EVERY) then
    listAt = now
    local ok, err = pcall(refresh)
    if not ok then TWDA.log("beacons: " .. tostring(err)) list = {} end
  end
  if #list == 0 then return end
  if nextIndex > #list then nextIndex = 1 end
  local ok, err = pcall(ping, list[nextIndex])
  if not ok then TWDA.log("beacons: " .. tostring(err)) end
  nextIndex = nextIndex + 1
end)
