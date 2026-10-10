-- Controls whose setting a sighted player sees on screen and a puzzle depends on: the mod names
-- them by their place in the row and says how each is set ("Switch 2 of 7, up"), when the reticle
-- is on one and in F6's list.
--
-- What the game does: each control's use dialog flips a property on the logic agent (Logic_IsReady's
-- upvalue mLogicProps). The keys are symbols (hashes of names the mod does not know), found by
-- using each control and seeing which property changed (tools\dev\logicdiff.lua).
--
-- Episode 3, the train's cab console (env_wreckedTrain.lua, 2026-10-09): panel 6 is seven
-- controls in a row, all down at first: two switches, two banks of four switches that move
-- together, and three more switches; then panel 5's dials. The engineer's notepad (readables.lua)
-- gives the settings.
local TWDA = ...

local CONTROLS = {
  obj_trainEngineConsoleSwitch1 = { label = "Switch 1 of 7", key = "40339919695431865" },
  obj_trainEngineConsoleSwitch2 = { label = "Switch 2 of 7", key = "7843973203586336663" },
  obj_trainEngineConsoleSwitchBank1 = { label = "Bank switch 3 of 7", key = "10673269112038881824" },
  obj_trainEngineConsoleSwitchBank2 = { label = "Bank switch 4 of 7", key = "17891434993876301070" },
  obj_trainEngineConsoleSwitch3 = { label = "Switch 5 of 7", key = "9891920086788722940" },
  obj_trainEngineConsoleSwitch4 = { label = "Switch 6 of 7", key = "13002751739155929547" },
  obj_trainEngineConsoleSwitch5 = { label = "Switch 7 of 7", key = "5904009284045164192" },
  -- Panel 5, once panel 6 is set: two dials, both straight up at first. Only the left one turns
  -- (between straight up and sideways); the right one does nothing.
  obj_trainEngineConsoleDial1 = { label = "Left dial", key = "9546653420513341639", on = "sideways", off = "straight up" },
  obj_trainEngineConsoleDial2 = { label = "Right dial" },
}
local ON, OFF = "up", "down"

local symbols = {} -- key digits -> the symbol object, once found
local function logicValue(digits)
  local props = TWDA.upvalue(rawget(_G, "Logic_IsReady"), "mLogicProps")
  if props == nil then return nil end
  local ok, value = pcall(function()
    local symbol = symbols[digits]
    if symbol == nil then
      local wanted = 'symbol: "' .. digits .. '"'
      for _, k in ipairs(PropertyGetKeys(props)) do
        if tostring(k) == wanted then symbol = k break end
      end
      if symbol == nil then return nil end
      symbols[digits] = symbol
    end
    return props[symbol]
  end)
  if ok then return value end
  return nil
end

-- Episode 3, on the train (env_trainAfterStop.lua, 2026-10-09): Lee teaches Clementine to shoot
-- a bottle, steering her aim with choices that take turns ("Aim left. Aim right. Keep it steady."
-- and "Aim higher. Aim lower. Keep it steady."). Two logic values hold how far off she is, -1, 0
-- or 1 each; she fires and hits once both are 0. Across: below 0 is too far left. Up and down:
-- below 0 is too high.
local AIM_ACROSS, AIM_HEIGHT = "17246942754874666973", "12513694551940471118"

local function offText(value, below, above)
  if type(value) ~= "number" then return nil end
  if value < 0 then return below end
  if value > 0 then return above end
  return "on the bottle"
end

TWDA.choiceContext = function(texts)
  local first = type(texts) == "table" and tostring(texts[1] or ""):lower() or ""
  if first:find("^aim left") or first:find("^aim right") then
    local where = offText(logicValue(AIM_ACROSS), "too far left", "too far right")
    return where and ("Left to right, her aim is " .. where) or nil
  end
  if first:find("^aim higher") or first:find("^aim lower") then
    local where = offText(logicValue(AIM_HEIGHT), "too high", "too low")
    return where and ("Up and down, her aim is " .. where) or nil
  end
  return nil
end

TWDA.hotspotLabel = function(agentName)
  local control = CONTROLS[agentName]
  return control and control.label or nil
end

TWDA.hotspotState = function(agent)
  local control = CONTROLS[TWDA.agentName(agent)]
  if not (control and control.key) then return nil end
  local value = logicValue(control.key)
  if value == true then return control.on or ON end
  if value == false then return control.off or OFF end
  return nil
end
