-- The story recap at the start of The Final Season (configurator.lua): Clementine tells the story so
-- far over drawn slides and asks the player to settle choices the imported save does not ("Lee
-- saved Doug." or "Lee saved Carley."), or to click on. On PC it takes only the mouse
-- (Configurator.imap: clicks and the controller's D-pad, which its own Left/Right handlers ignore
-- once the mouse was used), and the captions are text on ui_configurator_button1 to 3.
--
-- Configurator_ChoiceEnableInput(targetList, stringList) opens a question (one target: "Click to
-- Continue", mTargetSingleNode); Configurator_SelectButtonByIndex(i) highlights a caption;
-- Configurator_OnA() confirms the highlighted one (or continues); Configurator_ChoiceDisableInput
-- closes it. The mod reads the captions, and Left, Right, 1 to 3 and Enter do the rest.
local TWDA = ...
local G = _G

local open = nil -- { count, index, single } while a question waits

local function buttonText(i)
  local okA, agent = pcall(AgentFind, "ui_configurator_button" .. i)
  if not okA or agent == nil then return nil end
  local okH, hidden = pcall(AgentIsHidden, agent)
  if okH and hidden then return nil end
  local text = TWDA.agentText(agent)
  if type(text) ~= "string" or text == "" then return nil end
  return (TWDA.cleanText(text):gsub("%.$", ""))
end

local function captions()
  local list = {}
  for i = 1, 3 do
    local text = buttonText(i)
    if text then list[#list + 1] = { index = i, text = text } end
  end
  return list
end

local function question()
  local list = captions()
  if #list == 0 then return nil end
  local texts = {}
  for _, c in ipairs(list) do texts[#texts + 1] = c.text end
  return ("Which is right: %s? Left and right arrows to choose, Enter to confirm."):format(
    table.concat(texts, ", or "))
end

TWDA.hookAfter("Configurator_ChoiceEnableInput", function(args)
  local targets = args[1]
  local count = type(targets) == "table" and #targets or 0
  open = { count = count, index = nil, single = count <= 1 }
  TWDA.log("configurator: question with " .. count .. " targets")
  if open.single then
    TWDA.say("Enter to continue.")
  else
    local text = question()
    if text then TWDA.say(text, { interrupt = true }) end
  end
end)

TWDA.hookAfter("Configurator_ChoiceDisableInput", function()
  if open then TWDA.log("configurator: question closed") end
  open = nil
end)

-- (The caption is read by menus.lua, which hears every button's Select.)
TWDA.hookAfter("Configurator_SelectButtonByIndex", function(args)
  if open then open.index = args[1] end
end)

local function confirm()
  pcall(ThreadStart, function()
    local ok, err = pcall(Configurator_OnA)
    if not ok then TWDA.log("configurator: confirm failed: " .. tostring(err)) end
  end)
end

local function select(index)
  local ok, err = pcall(Configurator_SelectButtonByIndex, index)
  if not ok then TWDA.log("configurator: select failed: " .. tostring(err)) end
end

-- (A question already up when the mod loads, as after a reload from the dev console.)
do
  local okM, active = pcall(InputMapperIsActive, "Configurator.imap")
  local enable = rawget(G, "Configurator_ChoiceEnableInput")
  if okM and active and type(enable) == "function" then
    local total = TWDA.upvalue(enable, "mTotalOptions")
    local single = TWDA.upvalue(enable, "mTargetSingleNode")
    open = { count = total or 0, single = type(single) == "string" and single ~= "" }
  end
end

local KEYS = { [0x25] = "left", [0x27] = "right", [0x0D] = "enter", [0x31] = 1, [0x32] = 2, [0x33] = 3,
  [0x61] = 1, [0x62] = 2, [0x63] = 3 }
local held = {}
TWDA.onFrame("configurator", function()
  if type(rawget(G, "Configurator_OnA")) ~= "function" then return end
  for vk, action in pairs(KEYS) do
    local okK, down = pcall(InputPCIsVKeyPressed, vk)
    down = okK and down == true
    if down and not held[vk] and open then
      local paused = rawget(G, "Game_IsPaused") and Game_IsPaused()
      if not paused then
        if open.single then
          if action == "enter" then
            open = nil
            confirm()
          end
        elseif action == "enter" then
          if open.index then confirm() else TWDA.say("Choose with the left and right arrows first.", { interrupt = true }) end
        elseif action == "left" or action == "right" then
          local list = captions()
          if #list > 0 then
            local pos = 0
            for i, c in ipairs(list) do if c.index == open.index then pos = i end end
            if action == "right" then pos = pos + 1 else pos = (pos == 0) and #list or pos - 1 end
            if pos < 1 then pos = #list elseif pos > #list then pos = 1 end
            select(list[pos].index)
          end
        elseif type(action) == "number" then
          local list = captions()
          if list[action] then
            select(list[action].index)
            open.index = list[action].index
            confirm()
          end
        end
      end
    end
    held[vk] = down
  end
end)

-- (menus.lua reads a caption only while its question is open.)
function TWDA.configuratorOpen()
  return open ~= nil and not open.single
end

function TWDA.describeConfigurator()
  if not open then return nil end
  if open.single then return "Story so far. Enter to continue." end
  local text = question()
  if open.index then
    local current = buttonText(open.index)
    if current then text = (text or "") .. " Chosen: " .. current .. "." end
  end
  return text
end
