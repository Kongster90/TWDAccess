-- Season 1's message box (mode_UI_MessageBox): a question with one or two buttons, such as the
-- confirmation before deleting a save. Its input map only has mouse events, so the keyboard gets:
-- Left or Up for the first button, Right or Down for the second, Enter to press the chosen one, and
-- Backspace for the second (No).
local TWDA = ...
local G = _G

local VK_BACK, VK_ENTER, VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN = 0x08, 0x0D, 0x25, 0x26, 0x27, 0x28
local HANDLERS = { "OnButton1", "OnButton2" }

local function activeMode()
  local mode = rawget(G, "mode_UI_MessageBox")
  if type(mode) ~= "table" then return nil end
  local ok, current = pcall(Mode_GetCurrent)
  if ok and current == mode then return mode end
  return nil
end

local function find(name)
  local ok, agent = pcall(AgentFind, name)
  if ok then return agent end
  return nil
end

local function shownText(name)
  local agent = find(name)
  if agent == nil then return nil end
  local okHidden, isHidden = pcall(AgentIsHidden, agent)
  if okHidden and isHidden then return nil end
  return TWDA.normalCaps(TWDA.visibleText(agent))
end

local function readBox()
  local box = { message = shownText("ui_messageBox_message"), buttons = {} }
  for i, handler in ipairs(HANDLERS) do
    local name = "ui_messageBox_button" .. i
    local label = shownText(name)
    if label then box.buttons[#box.buttons + 1] = { name = name, label = label, handler = handler } end
  end
  return box
end

local function hint(box)
  if #box.buttons == 1 then return "Enter for " .. box.buttons[1].label end
  return "Left and right arrows to choose, Enter to confirm"
end

local function describe(box)
  local labels = {}
  for i, button in ipairs(box.buttons) do labels[i] = button.label end
  return TWDA.joinSentences({ box.message, table.concat(labels, ", "), hint(box) })
end

local function event(mode, button)
  local agent = find(button.name)
  return { type = 0, code = 768, x = 0, y = 0, agentName = button.name, agent = agent, controller = 0 }
end

local box, focus, openedAt = nil, nil, 0
local announced = false
local held = {}

local function setFocus(mode, index)
  local button = box.buttons[index]
  if not button then return end
  if focus and focus ~= index and box.buttons[focus] then
    pcall(mode.OnRollOff, mode, event(mode, box.buttons[focus]))
  end
  focus = index
  pcall(mode.OnRollOn, mode, event(mode, button))
  TWDA.say(button.label, { interrupt = true })
end

local function press(mode, index)
  local button = box.buttons[index]
  if not button or type(mode[button.handler]) ~= "function" then return end
  local ev = event(mode, button)
  local ok, err = pcall(ThreadStart, function()
    local okRun, errRun = pcall(mode[button.handler], mode, ev)
    if not okRun then TWDA.log("message box: " .. tostring(errRun)) end
  end)
  if not ok then TWDA.log("message box (thread): " .. tostring(err)) end
end

local keys = {
  [VK_LEFT] = function(mode) setFocus(mode, 1) end,
  [VK_UP] = function(mode) setFocus(mode, 1) end,
  [VK_RIGHT] = function(mode) setFocus(mode, #box.buttons) end,
  [VK_DOWN] = function(mode) setFocus(mode, #box.buttons) end,
  [VK_ENTER] = function(mode)
    if focus then
      press(mode, focus)
    elseif #box.buttons == 1 then
      press(mode, 1)
    else
      TWDA.say("Choose first: " .. hint(box), { interrupt = true })
    end
  end,
  [VK_BACK] = function(mode)
    if #box.buttons >= 2 then press(mode, 2) end
  end,
}

TWDA.onFrame("messagebox", function()
  local mode = activeMode()
  if not mode then
    box, focus, announced = nil, nil, false
    return
  end
  if box == nil then
    box, focus, openedAt, announced = { buttons = {} }, nil, TWDA.now(), false
    for vk in pairs(keys) do
      local ok, pressed = pcall(InputPCIsVKeyPressed, vk)
      held[vk] = ok and pressed == true -- a key still down from opening the box is not an answer
    end
  end
  -- The box fills in its text over a few frames.
  if not announced then
    local current = readBox()
    if (current.message and #current.buttons > 0) or TWDA.now() - openedAt > 1.5 then
      box, announced = current, true
      TWDA.lastHint = describe(box)
      TWDA.say(TWDA.lastHint, { interrupt = true })
    end
    return
  end
  for vk, action in pairs(keys) do
    local ok, pressed = pcall(InputPCIsVKeyPressed, vk)
    pressed = ok and pressed == true
    if pressed and not held[vk] then
      local okAction, err = pcall(action, mode)
      if not okAction then TWDA.log("message box key: " .. tostring(err)) end
    end
    held[vk] = pressed
  end
end)

-- For F6.
function TWDA.describeMessageBox()
  if not activeMode() or not box or not announced then return nil end
  local text = describe(box)
  if focus and box.buttons[focus] then text = TWDA.joinSentences({ text, box.buttons[focus].label .. " selected" }) end
  return text
end
