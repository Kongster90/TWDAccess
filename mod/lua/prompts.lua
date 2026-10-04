-- Season 1's full-screen prompts that only take a mouse click. So far: the death screen
-- (mode_UI_Death: the words "You are dead" are a picture, then "Click to continue"). Enter does
-- what the click does, mode_UI_Death:UnPause(), which reloads the last checkpoint.
local TWDA = ...
local G = _G

local VK_ENTER = 0x0D

local announced = false
local held = true

TWDA.onFrame("prompts", function()
  local death = rawget(G, "mode_UI_Death")
  local okMode, mode = pcall(Mode_GetCurrent)
  if type(death) ~= "table" or not okMode or mode ~= death then
    announced = false
    return
  end
  local okKey, down = pcall(InputPCIsVKeyPressed, VK_ENTER)
  down = okKey and down == true
  if not announced then
    announced = true
    held = down -- an Enter still held from before is not an answer
    TWDA.lastHint = "You are dead. Press Enter to try again from the last checkpoint."
    TWDA.say(TWDA.lastHint, { interrupt = true })
    return
  end
  if down and not held and type(death.UnPause) == "function" then
    local ok, err = pcall(ThreadStart, function()
      local okRun, errRun = pcall(death.UnPause, death)
      if not okRun then TWDA.log("death screen: " .. tostring(errRun)) end
    end)
    if not ok then TWDA.log("death screen (thread): " .. tostring(err)) end
  end
  held = down
end)
