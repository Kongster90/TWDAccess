-- Hotkeys, read straight from the keyboard each frame. The game does not use these keys.
--   F5  repeat the last thing spoken
--   F6  describe the screen: a struggle, aiming or a turn choice; the current choices; or the menu,
--       selected item, its tooltip and keys; in play, hiding (peek.lua), the time left in a
--       countdown, the things to interact with and what Lee is carrying
--   F7  subtitles: off, speaker names only, or full lines
--   F8  stop speech
--   F11 action scenes: normal speed, slow motion or automatic
--   F4  sound beacons: on what Tab chose, on everything near, or off (beacons.lua)
--   F3  the beeps louder, Shift+F3 quieter (sounds.lua)
--   In the game's menus, keys for controller buttons that have no keyboard key of their own:
--   F9  X button     F10  Y button     Page Up  left bumper     Page Down  right bumper
local TWDA = ...

local SUBTITLE_MODES = { "off", "speaker", "full" }
local SUBTITLE_NAMES = { off = "Subtitles off", speaker = "Subtitles: speaker names", full = "Subtitles: full lines" }

local function repeatLast()
  if TWDA.lastSpoken then
    TWDA.say(TWDA.lastSpoken, { interrupt = true })
  else
    TWDA.say("Nothing to repeat.", { interrupt = true })
  end
end

local function readCurrent()
  local aiming = (TWDA.describeDeath and TWDA.describeDeath())
    or (TWDA.describeAction2 and TWDA.describeAction2())
    or (TWDA.describeConfigurator and TWDA.describeConfigurator())
    or (TWDA.describeCombat and TWDA.describeCombat())
    or (TWDA.describeShooter and TWDA.describeShooter())
    or (TWDA.describeBow and TWDA.describeBow())
    or (TWDA.describeStars and TWDA.describeStars())
    or (TWDA.describeReadable and TWDA.describeReadable())
    or (TWDA.describeStruggle and TWDA.describeStruggle()) or (TWDA.describeAiming and TWDA.describeAiming())
    or (TWDA.describeSniper and TWDA.describeSniper())
    or (TWDA.describeCover and TWDA.describeCover())
    or (TWDA.describeCornfield and TWDA.describeCornfield())
    or (TWDA.describeDrag and TWDA.describeDrag())
    or (TWDA.describeFastSlow and TWDA.describeFastSlow())
    or (TWDA.describeTurnChoice and TWDA.describeTurnChoice())
    or (TWDA.describeStats and TWDA.describeStats())
    or (TWDA.describeSeasonStats and TWDA.describeSeasonStats())
    or (TWDA.describeWhoWent and TWDA.describeWhoWent())
  if aiming then
    TWDA.say(aiming, { interrupt = true })
    return
  end
  if TWDA.hasChoices and TWDA.hasChoices() then
    TWDA.readChoices()
    return
  end
  local box = TWDA.describeMessageBox and TWDA.describeMessageBox()
  if box then
    TWDA.say(box, { interrupt = true })
    return
  end
  local credits = TWDA.creditsText and TWDA.creditsText()
  if credits then
    TWDA.say(credits, { interrupt = true })
    return
  end
  local parts = {}
  local okPopup, popupOpen = pcall(function() return DialogBox_IsActive and DialogBox_IsActive() end)
  if okPopup and popupOpen and TWDA.lastPopup then parts[#parts + 1] = TWDA.lastPopup end
  local menu = (TWDA.describePane and TWDA.describePane()) or (TWDA.describeMenu and TWDA.describeMenu())
  if menu then parts[#parts + 1] = menu end
  local peek = not menu and TWDA.describePeek and TWDA.describePeek()
  if peek then parts[#parts + 1] = peek end
  local guided = not menu and TWDA.describeGuided and TWDA.describeGuided()
  if guided then parts[#parts + 1] = guided end
  local walkers = not menu and TWDA.describeWalkers and TWDA.describeWalkers()
  if walkers then parts[#parts + 1] = walkers end
  local countdown = not menu and TWDA.describeCountdown and TWDA.describeCountdown()
  if countdown then parts[#parts + 1] = countdown end
  local hotspots = not menu and TWDA.describeLookaround and TWDA.describeLookaround()
  if hotspots then parts[#parts + 1] = hotspots end
  local carrying = hotspots and TWDA.describeInventory and TWDA.describeInventory()
  if carrying then parts[#parts + 1] = carrying end
  if #parts == 0 then parts[1] = TWDA.lastHint or "Nothing on screen to read." end
  TWDA.say(table.concat(parts, ". "), { interrupt = true })
end

local function cycleSubtitles()
  local current = TWDA.settings.subtitles
  local nextMode = SUBTITLE_MODES[1]
  for i, mode in ipairs(SUBTITLE_MODES) do
    if mode == current then nextMode = SUBTITLE_MODES[i % #SUBTITLE_MODES + 1] end
  end
  TWDA.settings.subtitles = nextMode
  TWDA.saveSettings()
  TWDA.say(SUBTITLE_NAMES[nextMode], { interrupt = true })
end

-- Sends a controller button press to the widget menus, built like the game's own input events.
local function menuButton(handlerName, code, label, legendButtons, paneMethod)
  return function()
    -- Season 1's pane menus (panes.lua).
    if TWDA.paneButton and TWDA.paneButton(paneMethod) then return end
    -- The menu's own legend says what this button does; run that directly.
    if TWDA.runLegendCommand and TWDA.runLegendCommand(legendButtons) then return end
    local handler = rawget(_G, handlerName)
    local okMenu, menu = pcall(function() return Menu_GetCurrentMenu and Menu_GetCurrentMenu() end)
    if type(handler) ~= "function" or not okMenu or not menu then
      TWDA.say(label .. " does nothing here.", { interrupt = true })
      return
    end
    local event = { type = 0, code = code, x = 0, y = 0, agentName = "", controller = 0 }
    -- The widget input handler ignores controller buttons while the game is in mouse-and-keyboard
    -- mode (always, on PC), so for the length of this one press it is told otherwise.
    local G = _G
    local useCursor = rawget(G, "Input_UseCursor")
    rawset(G, "Input_UseCursor", function() return false end)
    local ok, err = pcall(handler, event)
    rawset(G, "Input_UseCursor", useCursor)
    if not ok then TWDA.log("menu button " .. label .. ": " .. tostring(err)) end
    -- Nothing in the legend for this button, so most likely nothing happened.
    TWDA.say(label .. " does nothing here.", { interrupt = true })
  end
end

local KEYS = {
  [0x74] = repeatLast,      -- F5
  [0x75] = readCurrent,     -- F6
  [0x76] = cycleSubtitles,  -- F7
  [0x77] = TWDA.stopSpeech, -- F8
  [0x7A] = function() if TWDA.cycleActionScenes then TWDA.cycleActionScenes() end end, -- F11
  [0x73] = function() if TWDA.toggleBeacons then TWDA.toggleBeacons() end end,         -- F4
  [0x72] = function()                                                                    -- F3
    local ok, shift = pcall(InputPCIsVKeyPressed, 0x10)
    if TWDA.changeBeepVolume then TWDA.changeBeepVolume(not (ok and shift == true)) end
  end,
  [0x78] = menuButton("WidgetInputHandler_OnX", 514, "F9", { "faceButtonLeft" }, "OnX"),               -- F9
  [0x79] = menuButton("WidgetInputHandler_OnY", 515, "F10", { "faceButtonUp" }, "OnY"),                 -- F10
  [0x21] = menuButton("WidgetInputHandler_OnL", 516, "Page Up", { "leftShoulder", "shoulderButtonLeft" }, "OnLB"),  -- Page Up
  [0x22] = menuButton("WidgetInputHandler_OnR", 517, "Page Down", { "rightShoulder", "shoulderButtonRight" }, "OnRB"), -- Page Down
}

local held = {}
TWDA.onFrame("hotkeys", function()
  for vk, action in pairs(KEYS) do
    local ok, pressed = pcall(InputPCIsVKeyPressed, vk)
    pressed = ok and pressed == true
    if pressed and not held[vk] then
      local actionOk, err = pcall(action)
      if not actionOk then TWDA.log("hotkey failed: " .. tostring(err)) end
    end
    held[vk] = pressed
  end
end)
