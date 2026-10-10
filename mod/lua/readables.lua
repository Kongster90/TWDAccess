-- Pictures with something to read that the game shows close up, as drawn pages with no text the
-- mod could find: when the camera is one of these, what it shows is read out, and F6 repeats it.
-- Described from the game's own drawings (screenshots taken while testing).
--
--   cam_notepad  Episode 3, the train: the engineer's notepad after Lee rubs a pencil over it
--                (2026-10-09). The steps for the cab's panels.
local TWDA = ...

local PAGES = {
  cam_notepad = "The notepad, Engine Startup. Panel 6: seven switches, left to right: down, down, up, up, up, "
    .. "down, up. Panel 5: two dials, the left one turned sideways, the right one straight up. "
    .. "Panel 9: a handle, turned left, then turned right.",
}

local function cameraName()
  local ok, name = pcall(function() return TWDA.agentName(SceneGetCamera(SceneGetBottomScene())) end)
  return ok and name or nil
end

local shown = nil
TWDA.describeReadable = function()
  local cam = cameraName()
  return cam and PAGES[cam] or nil
end

TWDA.onFrame("readables", function()
  local cam = cameraName()
  local page = cam and PAGES[cam] or nil
  if page and shown ~= cam then
    TWDA.log("readables: " .. cam)
    -- (Queued: Lee usually says something as it comes up.)
    TWDA.say(page)
  end
  shown = page and cam or nil
end)
