-- Dialog choices.
--
-- Seasons 1 and 2 (the older Telltale framework): choices are shown by mode_DialogChoice:OnStart,
-- which writes each option onto the screen with AgentSetProperty(agent, "Text String", text) before
-- it returns. We collect those texts while OnStart runs and read them out as a numbered list; the
-- number keys 1-4 pick an option in the game itself. "..." is the silent option.
local TWDA = ...
local G = _G

local choices = {}      -- texts of the choices currently on screen
local collecting = nil  -- list being filled while the game builds the choice display
local selected = 0      -- our idea of the highlighted option, for wheel/arrow movement

local function describeChoice(text)
  if text == "..." or text == "" then return "Say nothing" end
  return TWDA.normalCaps(text)
end

local function announce(interrupt)
  if #choices == 0 then
    TWDA.say("No choices right now.", { interrupt = true })
    return
  end
  local parts = { "Choices" }
  for i, text in ipairs(choices) do
    parts[#parts + 1] = ("%d: %s"):format(i, describeChoice(text))
  end
  TWDA.say(TWDA.joinSentences(parts), { interrupt = interrupt })
end

-- Timed choices. The countdown is the dialog engine's own ("Remaining" in DlgGetChoices), so the
-- mod holds it the way the pause menu does: Game_PauseAllDialogs() while the choices are up and
-- Game_ResumeAllDialogs() as soon as one is picked. A pick made while paused is kept and takes
-- effect on resume. The pause menu resumes dialogs when it closes, so the pause is re-applied
-- every frame until a choice is picked.
local pausedByUs = false
local picked = false

local function holdTimer()
  return TWDA.settings.choicetimer ~= "normal"
end

local function callGame(name)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return false end
  local ok, err = pcall(fn)
  if not ok then TWDA.log("choices: " .. name .. " failed: " .. tostring(err)) end
  return ok
end

local function dialogsPaused()
  local fn = rawget(G, "Game_AllDialogsPaused")
  if type(fn) ~= "function" then return false end
  local ok, paused = pcall(fn)
  return ok and paused == true
end

local function resumeDialogs()
  if not pausedByUs then return end
  pausedByUs = false
  if dialogsPaused() then callGame("Game_ResumeAllDialogs") end
end

local function keepPaused()
  if picked or #choices == 0 or not holdTimer() then return end
  -- Leave the pause menu alone while it is open; it pauses dialogs itself.
  local okMode, mode = pcall(Mode_GetCurrent)
  if okMode and type(mode) == "table" and mode == rawget(G, "mode_PauseMenu") then return end
  if not dialogsPaused() and callGame("Game_PauseAllDialogs") then pausedByUs = true end
end
TWDA.readChoices = function() announce(true) end
TWDA.hasChoices = function() return #choices > 0 end

-- Text written to the screen while a choice display is being built.
TWDA.onTextProperty = TWDA.onTextProperty or {}
TWDA.onTextProperty.choices = function(agentName, text)
  if not collecting or text == nil then return end
  if agentName:lower():find("helptext", 1, true) then return end
  text = TWDA.cleanText(text)
  if text == "" or collecting[#collecting] == text then return end
  collecting[#collecting + 1] = text
end

local function onStart()
  collecting = {}
end

local function afterStart()
  local list = collecting or {}
  collecting = nil
  if #list == 0 then return end
  choices = list
  selected = 0
  picked = false
  TWDA.log("choices: " .. table.concat(choices, " | "))
  keepPaused()
  if TWDA.settings.choices ~= false then announce(true) end
end

local function moveSelection(delta)
  if #choices == 0 then return end
  if selected == 0 then
    selected = delta > 0 and 1 or #choices
  else
    selected = (selected - 1 + delta) % #choices + 1
  end
  TWDA.say(("%d: %s"):format(selected, describeChoice(choices[selected])), { interrupt = true })
end

local function onEnd()
  choices = {}
  selected = 0
  resumeDialogs()
end

-- Every way of picking (number keys, Enter, a click) goes through mode_dialog.lua's local
-- selectChoice; resume the dialogs just before it runs.
local function wrapSelectChoice(mode)
  local fn = TWDA.unwrap(rawget(mode, "OnChoice"))
  if type(fn) ~= "function" then return end
  for i = 1, 60 do
    local name, value = debug.getupvalue(fn, i)
    if not name then return end
    if name == "selectChoice" and type(value) == "function" then
      if TWDA.wrappers[value] then return end
      local original = value
      local wrapper = function(...)
        picked = true
        local ok, err = pcall(resumeDialogs)
        if not ok then TWDA.log("choices: resume failed: " .. tostring(err)) end
        return original(...)
      end
      TWDA.wrappers[wrapper] = true
      debug.setupvalue(fn, i, wrapper)
      return
    end
  end
end

-- mode_DialogChoice is defined by the episode's scripts after we load, and its methods can be
-- replaced, so (re)attach every frame when needed.
local attached = setmetatable({}, { __mode = "k" })
local function attach()
  local mode = rawget(G, "mode_DialogChoice")
  if type(mode) ~= "table" then return end
  local current = rawget(mode, "OnStart")
  if attached[mode] == current then return end
  TWDA.hookMethod(mode, "OnStart", "mode_DialogChoice.OnStart", onStart, afterStart)
  TWDA.hookMethod(mode, "OnEnd", "mode_DialogChoice.OnEnd", onEnd)
  for _, key in ipairs({ "OnDown", "OnScrollDown" }) do
    TWDA.hookMethod(mode, key, "mode_DialogChoice." .. key, function() moveSelection(1) end)
  end
  for _, key in ipairs({ "OnUp", "OnScrollUp" }) do
    TWDA.hookMethod(mode, key, "mode_DialogChoice." .. key, function() moveSelection(-1) end)
  end
  wrapSelectChoice(mode)
  attached[mode] = rawget(mode, "OnStart")
  TWDA.log("choices: attached to mode_DialogChoice")
end

TWDA.onFrame("choices", function()
  attach()
  keepPaused()
  -- Never leave the game paused once the choices are gone.
  if pausedByUs and #choices == 0 then resumeDialogs() end
end)
