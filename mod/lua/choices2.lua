-- Dialog choices in Season 2 (projectseason2's gamedialog.lua, the newer Telltale framework).
--
-- Dialog_OnChoicesAvailable(dialogID) collects the choices (DlgGetChoices) and its local
-- SetChoices puts them into on-screen slots: the upvalue mMappedChoices maps a slot (1 to 4) to a
-- choice, whose text is "Choice Display Text" or "First Line" ("..." for the silent default,
-- mDefaultChoice); mChoices holds the slots' button agents. On PC only the mouse picks: the
-- "Dialog" input map has clicks and controller buttons, no keys. Dialog_ActivateChoice(slot) is
-- what a click or a controller button does, so the mod numbers the choices in reading order and
-- answers 1 to 4, Up and Down (read the next one) and Enter.
--
-- Timed choices: a thread plays the timer bar (upvalue mTimerController, scaled to the time left
-- in the line being spoken) and picks the default when it ends. Holding the bar's time scale at 0
-- holds the choice for as long as the player needs (setting choicetimer = pause).
local TWDA = ...
local G = _G

local choices = {} -- { text, slot } in reading order, while choices are up
local highlighted = nil
local picking = false

local function describeChoice(text)
  if text == "..." or text == "" then return "Say nothing" end
  return TWDA.normalCaps(TWDA.cleanText(text))
end

local function gameFn()
  local fn = rawget(G, "Dialog_OnChoicesAvailable")
  return type(fn) == "function" and fn or nil
end

local function announce(interrupt)
  if #choices == 0 then
    TWDA.say("No choices right now.", { interrupt = true })
    return
  end
  local parts = { "Choices" }
  for i, c in ipairs(choices) do
    parts[#parts + 1] = ("%d: %s"):format(i, describeChoice(c.text))
  end
  TWDA.say(TWDA.joinSentences(parts), { interrupt = interrupt })
end

local function holdTimer()
  return TWDA.settings.choicetimer ~= "normal"
end

local originals = {} -- the game's own SetChoices and ActivateChoice, under our wrappers
local mine = setmetatable({}, { __mode = "k" }) -- wrappers this copy of the module installed

-- The choices as SetChoices has just laid them out. (mMappedChoices and mChoices are locals that
-- only SetChoices and the pick functions use, so they are read through SetChoices itself.)
local function onChoicesShown()
  local fn = originals.SetChoices
  local mapped = TWDA.upvalue(fn, "mMappedChoices")
  local buttons = TWDA.upvalue(fn, "mChoices")
  local default = TWDA.upvalue(fn, "mDefaultChoice")
  if type(mapped) ~= "table" then return end
  local list = {}
  for slot = 1, 4 do
    local choice = mapped[slot]
    if type(choice) == "table" then
      local text = choice["Choice Display Text"]
      if not text or text == "" then text = (choice == default) and "..." or choice["First Line"] end
      local agent = type(buttons) == "table" and buttons[slot] or nil
      local okPos, pos = pcall(AgentGetScreenPos, agent)
      list[#list + 1] = { text = text or "", slot = slot, x = okPos and pos and pos.x or slot, y = okPos and pos and pos.y or slot }
    end
  end
  if #list == 0 then return end
  -- (Reading order: top to bottom, then left to right.)
  table.sort(list, function(a, b)
    if math.abs(a.y - b.y) > 0.02 then return a.y < b.y end
    return a.x < b.x
  end)
  choices, highlighted, picking = list, nil, false
  local texts = {}
  for _, c in ipairs(list) do texts[#texts + 1] = c.slot .. "=" .. tostring(c.text) end
  TWDA.log("choices: " .. table.concat(texts, " | "))
  if TWDA.settings.choices ~= false then announce(true) end
end

local function onPicked()
  if #choices > 0 then TWDA.log("choices: ended") end -- (tools\dev\play_by_ear.ps1 goes by it)
  choices, highlighted, picking = {}, nil, false
end

local function pick(index)
  local c = choices[index]
  if not c or picking then return end
  picking = true
  TWDA.say(("%d: %s"):format(index, describeChoice(c.text)), { interrupt = true })
  -- (Dialog_ActivateChoice waits on the line being spoken, so it runs in a thread of its own.)
  local ok, err = pcall(ThreadStart, function()
    local okA, errA = pcall(Dialog_ActivateChoice, c.slot)
    if not okA then TWDA.log("choices: activate failed: " .. tostring(errA)) end
  end)
  if not ok then
    picking = false
    TWDA.log("choices: " .. tostring(err))
  end
end

-- Wraps the local function named `name` that Dialog_OnChoicesAvailable keeps as an upvalue (the
-- upvalue is gamedialog.lua's own local, shared by all its functions).
local function wrapUpvalue(name, before, after)
  local fn = TWDA.unwrap(gameFn())
  if type(fn) ~= "function" then return false end
  for i = 1, 80 do
    local n, value = debug.getupvalue(fn, i)
    if not n then return false end
    if n == name and type(value) == "function" then
      if mine[value] then return true end
      local original = value
      originals[name] = TWDA.unwrap(original)
      local wrapper = function(...)
        if before then
          local ok, err = pcall(before, ...)
          if not ok then TWDA.log("choices " .. name .. ": " .. tostring(err)) end
        end
        if not after then return original(...) end
        local results = table.pack(original(...))
        local ok, err = pcall(after, ...)
        if not ok then TWDA.log("choices " .. name .. ": " .. tostring(err)) end
        return table.unpack(results, 1, results.n)
      end
      TWDA.wrappers[wrapper] = true
      mine[wrapper] = true
      debug.setupvalue(fn, i, wrapper)
      return true
    end
  end
  return false
end

local attachedTo = nil
local function attach()
  local fn = gameFn()
  if not fn or fn == attachedTo then return end
  if TWDA.upvalue(fn, "SetChoices") == nil then return end -- (not Season 2's gamedialog)
  local okSet = wrapUpvalue("SetChoices", nil, onChoicesShown)
  local okAct = wrapUpvalue("ActivateChoice", onPicked, nil)
  attachedTo = fn
  TWDA.log(("choices: attached to Season 2's dialog (%s, %s)"):format(tostring(okSet), tostring(okAct)))
end

-- Keys: 1 to 4 (top row or number pad) pick; Up and Down read the next; Enter picks that one.
local KEYS = {
  [0x31] = 1, [0x32] = 2, [0x33] = 3, [0x34] = 4,
  [0x61] = 1, [0x62] = 2, [0x63] = 3, [0x64] = 4,
  [0x26] = "up", [0x28] = "down", [0x0D] = "enter",
}
-- A menu over the game (the pause menu, ui_menu_pause) has the keyboard; the choices wait behind
-- it. (While choices are up on their own, UIZ_GetActiveMenu() is nil.)
local function menuUp()
  local ok, menu = pcall(UIZ_GetActiveMenu)
  return ok and menu ~= nil
end

local held = {}
local function pollKeys()
  local menu = menuUp()
  for vk, action in pairs(KEYS) do
    local ok, down = pcall(InputPCIsVKeyPressed, vk)
    down = ok and down == true
    if down and not held[vk] and #choices > 0 and not picking and not menu then
      if type(action) == "number" then
        if choices[action] then pick(action) end
      elseif action == "enter" then
        if highlighted then
          pick(highlighted)
        else
          TWDA.say("Choose with 1 to " .. #choices .. ", or the up and down arrows then Enter.", { interrupt = true })
        end
      else
        local step = action == "down" and 1 or -1
        highlighted = math.max(1, math.min(#choices, (highlighted or (step == 1 and 0 or #choices + 1)) + step))
        TWDA.say(("%d: %s"):format(highlighted, describeChoice(choices[highlighted].text)), { interrupt = true })
      end
    end
    held[vk] = down
  end
end

-- Hold the timer bar while choices are up.
local heldTimer = nil
local function holdChoiceTimer()
  if #choices == 0 or picking or not holdTimer() then return end
  local controller = TWDA.upvalue(gameFn(), "mTimerController")
  if controller == nil then return end
  local ok, err = pcall(ControllerSetTimeScale, controller, 0)
  if not ok then
    TWDA.log("choices: timer hold failed: " .. tostring(err))
  elseif heldTimer ~= controller then
    heldTimer = controller
    TWDA.log("choices: holding the choice timer")
  end
end

-- Choices that went away without a pick going through ActivateChoice (a scene cut).
local function stillUp()
  if #choices == 0 then return end
  local mapped = TWDA.upvalue(gameFn(), "mDialogChoices")
  if mapped == nil then onPicked() end
end

local previousHas, previousRead = TWDA.hasChoices, TWDA.readChoices
TWDA.hasChoices = function()
  return (#choices > 0 and not menuUp()) or (previousHas ~= nil and previousHas())
end
TWDA.readChoices = function()
  if #choices > 0 or not previousRead then announce(true) else previousRead() end
end

TWDA.onFrame("choices2", function()
  attach()
  if not attachedTo then return end
  stillUp()
  pollKeys()
  holdChoiceTimer()
end)
