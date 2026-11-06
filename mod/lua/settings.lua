-- Settings, stored as "key = value" lines in TWDAccess/settings.txt so they are easy to edit by hand.
local TWDA = ...

local path = TWDA.dir .. "settings.txt"

local defaults = {
  -- What to say when a character speaks: off, speaker (name only), or full (name and line).
  subtitles = "off",
  -- Speak menu items as they are highlighted.
  menus = true,
  -- After a menu item, read its description (the help line shown at the bottom of the screen).
  tooltips = true,
  -- Speak dialog choices when they appear and as you move between them.
  choices = true,
  -- Timed choices: "pause" stops the timer while choices are on screen, "normal" keeps the game's.
  choicetimer = "pause",
  -- Action scenes (danger against the clock): "normal", "slow" (slow motion) or "auto".
  actionscenes = "slow",
  -- Sound beacons: "tab" (on what Tab chose), "all" (also the nearest things, places and walkers)
  -- or "off"; F4 goes from one to the next.
  beacons = "tab",
  -- How loud the mod's beeps are (beacons and the aiming tone), in percent; F3 raises, Shift+F3 lowers.
  beepvolume = 100,
  -- Aiming (The Final Season's bow, Season 1's shotgun and rifle scope): "sound" (aim with the arrows
  -- by a tone) or "auto" (the mod aims).
  aim = "sound",
  -- How fast the arrow keys turn the bow's aim (mouse pixels a twentieth of a second; Shift: three times).
  bowturn = 16,
  -- The key that goes through the things to interact with, and with Shift back: Tab, or a letter
  -- the game and the mod do not use (TWDA.tabVK below). Players asked to move it off Tab, whose
  -- Shift+Tab opens the Steam overlay (SteamOverlay.cs).
  tabkey = "Tab",
  -- Read by the helper (TWDAccess.exe) as it starts: true opens it in a window of its own, so OBS's
  -- Application Audio Capture can record its beeps and tones (OwnWindow.cs).
  streaming = false,
  -- Log what the game's scripts do, for developing the mod.
  discovery = false,
  -- Let the helper run Lua in the game (development only).
  devconsole = false,
}

local order = { "subtitles", "menus", "tooltips", "choices", "choicetimer", "actionscenes", "beacons",
  "beepvolume", "aim", "bowturn", "tabkey", "streaming", "discovery", "devconsole" }

local settings = {}
for k, v in pairs(defaults) do settings[k] = v end

local function parse(value)
  if value == "true" then return true end
  if value == "false" then return false end
  return tonumber(value) or value
end

local file = io.open(path, "rb")
local missing = file == nil
if file then
  local present = {}
  for line in file:lines() do
    local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if key and defaults[key] ~= nil then
      settings[key] = parse(value)
      present[key] = true
    end
  end
  file:close()
  -- Settings added in a newer version get written out so they can be found and changed.
  for _, key in ipairs(order) do
    if not present[key] then missing = true end
  end
end

function TWDA.saveSettings()
  local out = io.open(path, "wb")
  if not out then return end
  out:write("# TWD Access settings. Lines are key = value.\n")
  out:write("# subtitles: off, speaker or full\n")
  out:write("# choicetimer: pause (timed choices wait for you) or normal\n")
  out:write("# actionscenes: normal, slow (slow motion) or auto (the mod acts for you); F11 cycles it\n")
  out:write("# beacons: tab (a sound on what Tab chose), all (on everything near) or off; F4 goes from one to the next\n")
  out:write("# beepvolume: how loud the beeps are, 10 to 150 percent (100); F3 raises it, Shift+F3 lowers it\n")
  out:write("# aim: sound (arrows aim, a tone guides) or auto (the mod aims): the bow, the shotgun and the rifle scope\n")
  out:write("# bowturn: how fast the arrows start turning the bow's aim (16; higher is faster; held, they speed up)\n")
  out:write("# tabkey: Tab, or a letter, to go through the things around you; Shift with it goes back. W, A, S, D, Z, Q, E, F, T, P and R cannot be used, because the game already uses them; takes effect when the game next starts\n")
  out:write("# streaming: true opens TWD Access in a window of its own, so OBS can record its sounds; takes effect when TWD Access next starts\n")
  for _, key in ipairs(order) do
    out:write(("%s = %s\n"):format(key, tostring(settings[key])))
  end
  out:close()
end

TWDA.settings = settings
if missing then TWDA.saveSettings() end

-- The tabkey setting: TWDA.tabVK is its key code, read where Tab was (the things to interact
-- with in every season, aiming, the bow, the stars, quick-time targets), and TWDA.tabName its name
-- in what is spoken. The letters the game uses are refused, since the mod only listens to a key
-- and the game would act on it too. Every season's input maps were read in the game
-- (tools\dev\imapscan.lua: ResourceGetNames("*.imap"), InputMapperGetInput; 2026-11-05): W A S D (walking, drags, peeking;
-- Z on French keyboards), Q and E (action scenes, struggles, fights), T (shows the game's own
-- labels on things: Navigate, ReticleSelection and Useable.imap; Season 1's first-person look lock),
-- F (uses things in The Final Season, Useable.imap), P (Season 1's game_debug.imap). R is the mod's
-- (bow4.lua draws). Every letter is bound only on the on-screen keyboard screens (ui_keyboard,
-- keyboardinput.imap). (The helper keeps the same list, TabKey.cs, and says when the setting cannot
-- be used: these scripts start again with every scene in Season One, so saying it here would
-- repeat it.)
local TAKEN = { W = "walks", A = "walks", S = "walks", D = "walks", Z = "walks on French keyboards",
  Q = "is used in action scenes", E = "is used in action scenes", T = "shows the game's labels",
  F = "uses things in The Final Season", P = "is a key of the game's", R = "draws the bow" }
TWDA.tabVK, TWDA.tabName = 0x09, "Tab"
do
  local key = tostring(settings.tabkey):upper()
  if key:match("^%u$") and not TAKEN[key] then
    TWDA.tabVK, TWDA.tabName = key:byte(), key
  elseif key ~= "TAB" then
    local problem = key == "" and "The tabkey setting is empty. Using Tab." or
      ("The tabkey setting, %s, cannot be used: %s. Using Tab. Choose another letter in settings.txt.")
        :format(tostring(settings.tabkey), TAKEN[key] and (key .. " " .. TAKEN[key]) or "it must be Tab or a letter")
    TWDA.log(problem)
  end
end

-- Text that names Tab, with the key chosen instead: "Tab to choose" becomes "G to choose".
function TWDA.tabWords(text)
  return (text:gsub("%f[%a]Tab%f[%A]", TWDA.tabName))
end
