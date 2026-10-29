-- Scenes of Michonne's own that need more than the shared modules give.
local TWDA = ...
local G = _G

-- Episode 1, the boat's radio (dockchesapeakebay.lua): "Hold A or D to turn the Dial." Each dial is
-- a chore the scene's thread plays forwards or backwards while D or A is held (the radio's from 0.1
-- to 4.9 seconds, the squelch's from 0 to 6), checking the values as it turns
-- (logic_checkRadioValues). The radio dial stops by itself once it is in tune (about the middle);
-- with the squelch turned well down (about a quarter) Samantha comes through. Nothing but the
-- picture says where a dial is, so a tone rises with it every twentieth of the way, and its ends
-- are said.
local DIALS = {
  { controller = "DockChesapeakeBay_GetRadioController", flag = "mbUsingRadioDial", low = 0.1, high = 4.9 },
  { controller = "DockChesapeakeBay_GetSquelchController", flag = "mbUsingSquelchDial", low = 0.05 },
}
local lastStep, atEnd, wasUsing = {}, {}, {}
TWDA.onFrame("michonne.dials", function()
  local begin = rawget(G, "DockChesapeakeBay_BeginRadioDial")
  if type(begin) ~= "function" then return end
  for i, dial in ipairs(DIALS) do
    local using = TWDA.upvalue(begin, dial.flag) == true
    -- (The radio dial lets go by itself once it is in tune; only its picture showed it.)
    if i == 1 and wasUsing[i] and not using and lastStep[i] and lastStep[i] > 1 and lastStep[i] < 19 then
      TWDA.say("The radio dial is in tune. Now the squelch dial.", { interrupt = true })
    end
    wasUsing[i] = using
    local okC, controller = pcall(rawget(G, dial.controller) or function() end)
    local okT, time = pcall(ControllerGetTime, okC and controller or nil)
    local okL, length = pcall(ControllerGetLength, okC and controller or nil)
    if using and okT and okL and type(time) == "number" and type(length) == "number" and length > 0 then
      local high = dial.high or (length - 0.05)
      local step = math.floor(time / length * 20 + 0.5)
      if lastStep[i] ~= nil and step ~= lastStep[i] then
        TWDA.tone({ f = 300 + step * 40, ms = 40, v = 0.3 })
      end
      lastStep[i] = step
      local edge = time <= dial.low and "left" or time >= high and "right" or nil
      if edge and atEnd[i] ~= edge then
        TWDA.say(edge == "left" and "All the way left. D turns it back." or "All the way right. A turns it back.",
          { interrupt = true })
      end
      atEnd[i] = edge
    else
      lastStep[i], atEnd[i] = nil, nil
    end
  end
end)

-- F6 while turning one.
local previous = TWDA.describeAction2
TWDA.describeAction2 = function()
  local begin = rawget(G, "DockChesapeakeBay_BeginRadioDial")
  if type(begin) == "function" then
    for i, dial in ipairs(DIALS) do
      if TWDA.upvalue(begin, dial.flag) == true and lastStep[i] then
        return ("%s, %d percent of the way round. Hold A or D to turn it"):format(i == 1 and "Radio dial" or "Squelch dial",
          lastStep[i] * 5)
      end
    end
  end
  return previous and previous() or nil
end
