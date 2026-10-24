-- Drags in A New Frontier (projectseason3's drag.lua): prying, pulling, pushing. On PC the game
-- takes Enter as the held button (Drag_OnButtonEnter: Drag_OnHoldPress on key down,
-- Drag_OnHoldRelease on key up) and, while it is held, the arrows and W A S D as the way to pull
-- (Drag_OnButtonDown and so on), but only the ways the drag agent enables: its "Drag - Direction
-- Down Enabled" and the like (the script keeps those key names in upvalues, kDirDownEnabled...).
-- Nothing on screen says which way but a picture. The mod says it ("Drag: hold Down arrow.") and
-- holds the button itself while an arrow is held, so the arrow alone is enough.
local TWDA = ...
local G = _G

local WAYS = {
  { fn = "Drag_OnButtonUp", key = "kDirUpEnabled", words = "Up arrow", vks = { 0x26, 0x57 } },
  { fn = "Drag_OnButtonDown", key = "kDirDownEnabled", words = "Down arrow", vks = { 0x28, 0x53 } },
  { fn = "Drag_OnButtonLeft", key = "kDirLeftEnabled", words = "Left arrow", vks = { 0x25, 0x41 } },
  { fn = "Drag_OnButtonRight", key = "kDirRightEnabled", words = "Right arrow", vks = { 0x27, 0x44 } },
}

local function isDrag3()
  return type(rawget(G, "Drag_GetActiveAgent")) == "function"
    and TWDA.upvalue(rawget(G, "Drag_OnButtonUp"), "kDirUpEnabled") ~= nil
end

local function pressed(vk)
  local ok, down = pcall(InputPCIsVKeyPressed, vk)
  return ok and down == true
end

local function event(code, kind)
  return { code = code, type = kind, controller = -1, x = 0, y = 0, agentName = "" }
end

-- The ways the active drag can go.
local function enabledWays()
  local agent = TWDA.upvalue(rawget(G, "Drag_OnButtonUp"), "mActiveAgent")
  local props = type(agent) == "table" and rawget(agent, "mProps") or nil
  local list = {}
  if props == nil then return list end
  for _, way in ipairs(WAYS) do
    local key = TWDA.upvalue(rawget(G, way.fn), way.key)
    local ok, on = pcall(function() return props[key] end)
    if ok and on == true then list[#list + 1] = way end
  end
  return list
end

local function waysText()
  local words = {}
  for _, way in ipairs(enabledWays()) do words[#words + 1] = way.words end
  -- (No way at all: the drag is a hold, filling the syringe in Episode 3's flashback.)
  if #words == 0 then return "Hold Enter!" end
  return "Drag: hold " .. table.concat(words, " or ") .. "."
end

local activeAgent, announceAt = nil, nil
local holding, lastPush = false, 0

local function release()
  if not holding then return end
  holding = false
  local ok, err = pcall(Drag_OnHoldRelease, event(13, 1), true)
  if not ok then TWDA.log("drag3: release failed: " .. tostring(err)) end
end

TWDA.onFrame("drag3", function()
  if not isDrag3() then return end
  local ok, agent = pcall(Drag_GetActiveAgent)
  agent = ok and agent or nil
  if agent ~= activeAgent then
    activeAgent = agent
    release()
    announceAt = agent and TWDA.now() + 0.2 or nil
    if agent then TWDA.log("drag3: drag " .. TWDA.agentName(agent)) end
  end
  if not agent then return end
  if announceAt and TWDA.now() >= announceAt then
    announceAt = nil
    TWDA.say(waysText(), { interrupt = true })
  end
  -- An arrow held without Enter: hold the button for the player, and pass the arrow on (the game
  -- ignored its first press, the button not being held yet; repeating it keeps the pull going).
  if pressed(0x0D) then return end
  local wayDown = nil
  for _, way in ipairs(enabledWays()) do
    for _, vk in ipairs(way.vks) do
      if pressed(vk) then wayDown = way end
    end
  end
  if wayDown then
    local now = TWDA.now()
    if not holding then
      holding = true
      local okHold, err = pcall(Drag_OnHoldPress, event(13, 0), true)
      if not okHold then TWDA.log("drag3: hold failed: " .. tostring(err)) end
      lastPush = 0
    end
    if now - lastPush >= 0.1 then
      lastPush = now
      pcall(TWDA.unwrap(rawget(G, wayDown.fn)), event(wayDown.vks[1], 0))
    end
  else
    release()
  end
end)

local previousDescribe = TWDA.describeDrag
TWDA.describeDrag = function()
  if activeAgent and isDrag3() then return waysText() end
  return previousDescribe and previousDescribe() or nil
end
