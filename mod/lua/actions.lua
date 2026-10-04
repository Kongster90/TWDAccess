-- Action scenes in Season 1: danger against the clock, such as the zombie cop crawling at Lee. The
-- game shows its red "panic meter" vignette (ui_panicmeter.scene) for as long as one lasts.
--
-- Setting actionscenes (settings.txt, F11 cycles it):
--   normal  the game's own timing. Things that become usable are still read out as they appear
--           ("Shotgun: Take"), and Enter uses the chosen one at once (lookaround.lua).
--   slow    the same, with the game at half speed for the length of the scene. Keys held to move
--           need holding longer in real time.
--   auto    the mod uses each thing as it becomes usable, one at a time and through the reticle,
--           with its first action that is not "Look"; it also aims and fires the shotgun
--           (aiming.lua). Holding movement keys is still up to the player. Experimental.
local TWDA = ...

local MODES = { "normal", "slow", "auto" }
local MODE_NAMES = {
  normal = "Action scenes: normal speed",
  slow = "Action scenes: slow motion",
  auto = "Action scenes: automatic",
}
-- An unusual value, so a slow-down left over from before (say, a reload in mid-scene) is
-- recognisable as ours.
local SLOW_SCALE = 0.45
local CHECK_SECONDS = 0.2

local function inActionScene()
  local ok, hidden = pcall(SceneIsHidden, "ui_panicmeter.scene")
  return ok and hidden == false
end
TWDA.inActionScene = inActionScene

local function timeScale()
  local ok, scale = pcall(GetTimeScale)
  if ok and type(scale) == "number" then return scale end
  return 1
end

local function setSlow(on)
  local scale = timeScale()
  if on and math.abs(scale - 1) < 0.001 then
    pcall(SetTimeScale, SLOW_SCALE)
  elseif not on and math.abs(scale - SLOW_SCALE) < 0.001 then
    pcall(SetTimeScale, 1)
  end
end

local function lookOnly(verb)
  return type(verb) == "string" and verb:lower():find("^look") ~= nil
end

local known = nil -- names of the hotspots usable at the last check, while a scene lasts
local lastCheck = 0
local autoQueue = {} -- auto mode: names of hotspots still to use, in the order they appeared

TWDA.onFrame("actions", function()
  local mode = TWDA.settings.actionscenes or "slow"
  local active = inActionScene()
  setSlow(active and mode == "slow")
  if not active then
    known, autoQueue = nil, {}
    return
  end
  local now = TWDA.now()
  if now - lastCheck < CHECK_SECONDS then return end
  lastCheck = now
  if not (TWDA.hotspots and TWDA.reticleReady and TWDA.reticleReady()) then return end

  local list = TWDA.hotspots()
  local usable, fresh = {}, {}
  for _, entry in ipairs(list) do
    usable[entry.name] = entry
    if known == nil or not known[entry.name] then fresh[#fresh + 1] = entry end
  end
  known = usable

  if #fresh > 0 then
    local parts = {}
    for _, entry in ipairs(fresh) do
      local name = TWDA.hotspotName(entry.agent)
      local verb = TWDA.hotspotVerb(entry.agent)
      -- No single verb means several actions, which only show once the hotspot is focused (Tab).
      local text = verb and (name .. ": " .. verb) or (name .. ", several actions")
      if entry.side then text = text .. ", " .. (entry.side == "behind" and "behind you" or "to your " .. entry.side) end
      parts[#parts + 1] = text
      if mode == "auto" and not lookOnly(verb) then autoQueue[#autoQueue + 1] = entry.name end
    end
    TWDA.say(table.concat(parts, ". "), { interrupt = true })
  end

  -- Auto mode: one at a time, through the reticle (lookaround.lua), which also turns the camera to
  -- things out of view and picks the first action that is not "Look".
  if mode == "auto" and TWDA.useWithReticle and not TWDA.reticleBusy() then
    while #autoQueue > 0 do
      local name = table.remove(autoQueue, 1)
      local entry = usable[name]
      if entry then
        TWDA.log("actions: using " .. name)
        TWDA.useWithReticle(entry.agent)
        break
      end
    end
  end
end)

-- F11.
function TWDA.cycleActionScenes()
  local current = TWDA.settings.actionscenes or "slow"
  local nextMode = MODES[1]
  for i, mode in ipairs(MODES) do
    if mode == current then nextMode = MODES[i % #MODES + 1] end
  end
  TWDA.settings.actionscenes = nextMode
  TWDA.saveSettings()
  TWDA.say(MODE_NAMES[nextMode], { interrupt = true })
end
