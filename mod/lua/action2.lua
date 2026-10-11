-- Action prompts in Season 2 (projectseason2's action.lua and action_ui.lua): dodges and blows
-- against the clock, shown as arrows and buttons on screen. The scene's dialog enables an action
-- agent (the local EnableAction: it goes into mActiveActionAgents, which Action_GetActiveActions
-- returns, and ActionUI_Set shows the prompts). While a window is open the agent's properties say
-- what works: "Action Enabled", and "Move Right Enabled", "Attack Up Enabled" and so on, each with a
-- "... Dialog" to play. On PC, action.imap takes moves from the arrows and W A S D
-- (ActionMove_OnUp/Down/Left/Right) and blows from a click or Enter (Action_OnEnterKey tries every
-- direction).
--
-- The mod says what to press the moment a window opens ("Right arrow!", "Enter!"), and in the
-- actionscenes modes: slow runs the game at 0.45 speed while action prompts can come; auto presses
-- for you.
local TWDA = ...
local G = _G

local DIRS = { "Up", "Down", "Left", "Right" }
local KEY_WORDS = { Up = "Up arrow", Down = "Down arrow", Left = "Left arrow", Right = "Right arrow" }
local SLOW_SCALE = 0.45

local function prop(agent, key)
  local ok, value = pcall(AgentGetProperty, agent, key)
  if ok then return value end
  return nil
end

local function usable(agent, actionType)
  if prop(agent, actionType .. " Enabled") ~= true then return false end
  local dialog = prop(agent, actionType .. " Dialog")
  return dialog ~= nil and dialog ~= ""
end

-- What can be pressed right now: { moves = { "Right", ... }, attack = true/false }.
local function openNow()
  local fn = rawget(G, "Action_GetActiveActions")
  if type(fn) ~= "function" then return nil end
  local ok, agents = pcall(fn)
  if not ok or type(agents) ~= "table" then return nil end
  local moves, attack, seen = {}, false, {}
  for _, agent in ipairs(agents) do
    if prop(agent, "Action Enabled") ~= false then
      for _, d in ipairs(DIRS) do
        if usable(agent, "Move " .. d) and not seen[d] then
          seen[d] = true
          moves[#moves + 1] = d
        end
        if usable(agent, "Attack " .. d) then attack = true end
      end
    end
  end
  if #moves == 0 and not attack then return nil end
  return { moves = moves, attack = attack }
end

local function promptText(open)
  local keys = {}
  for _, d in ipairs(open.moves) do keys[#keys + 1] = KEY_WORDS[d] end
  if open.attack then keys[#keys + 1] = "Enter" end
  return table.concat(keys, " or ") .. "!"
end

local function press(open)
  local ok, err
  if open.attack then
    ok, err = pcall(Action_OnEnterKey, {})
  else
    ok, err = pcall(rawget(G, "ActionMove_On" .. open.moves[1]), {})
  end
  if not ok then TWDA.log("action2: press failed: " .. tostring(err)) end
end

local lastText, lastOpenAt, autoDone = nil, 0, false
local slowedByUs = false

local function setSlow(on)
  if on and not slowedByUs then
    if pcall(SetTimeScale, SLOW_SCALE) then slowedByUs = true end
  elseif not on and slowedByUs then
    pcall(SetTimeScale, 1)
    slowedByUs = false
  end
end

TWDA.onFrame("action2", function()
  if type(rawget(G, "Action_GetActiveActions")) ~= "function" then return end
  local mode = TWDA.settings.actionscenes or "slow"
  local open = openNow()
  local okAgents, agents = pcall(Action_GetActiveActions)
  local anyActive = okAgents and type(agents) == "table" and #agents > 0
  setSlow(mode == "slow" and anyActive)
  if not open then
    lastText, autoDone = nil, false
    return
  end
  local text = promptText(open)
  if text ~= lastText then
    lastText, lastOpenAt, autoDone = text, TWDA.now(), false
    TWDA.log("action2: open " .. text)
    TWDA.lastHint = text
    if mode ~= "auto" then TWDA.say(text, { interrupt = true }) end
  end
  if mode == "auto" and not autoDone and TWDA.now() - lastOpenAt > 0.15 then
    autoDone = true
    press(open)
  end
end)

local previousDescribe = TWDA.describeAction2
TWDA.describeAction2 = function()
  local open = openNow()
  if open then return "Now: " .. promptText(open) end
  return previousDescribe and previousDescribe() or nil
end
