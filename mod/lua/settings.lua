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
  -- Log what the game's scripts do, for developing the mod.
  discovery = false,
  -- Let the helper run Lua in the game (development only).
  devconsole = false,
}

local order = { "subtitles", "menus", "tooltips", "choices", "choicetimer", "actionscenes", "discovery",
  "devconsole" }

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
  for _, key in ipairs(order) do
    out:write(("%s = %s\n"):format(key, tostring(settings[key])))
  end
  out:close()
end

TWDA.settings = settings
if missing then TWDA.saveSettings() end
