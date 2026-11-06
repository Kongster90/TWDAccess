-- Aiming the shotgun at the zombie cop (Season 1 Episode 1; the game's mode_shotgun.lua).
--
-- What the game does: once Lee has loaded the shotgun, the view turns with the mouse pointer (its
-- x and y set the times of two camera-pan chores, ShotGun_Update) and a click fires. The shot hits
-- when the cop is under the screen centre (Shotgun_Fire: AgentAtScreenPos(centre, true, cop)),
-- which in practice means his head; anything else is a miss, and Lee dies. On PC the mode's own
-- arrow-key and Enter handlers do nothing (they only work on one TV-box platform).
--
-- Keys while aiming:
--   Tab         aim for you: turns the view until the cop's head is under the crosshair
--   Arrow keys  aim by hand (the mod moves the pointer; Shift three times as fast)
--   Enter       fire
-- With the setting aim = sound (the default) a tone guides the arrows, as with the bow (sounds.lua):
-- panned to where the cop is, higher the nearer the aim is to him, and a double tick on target
-- ("On target" is said once). Where he is comes from the hit test, along the crosshair's row first
-- (the head projected through the pan camera was found up to a tenth of a screen off what a shot
-- hits). Near him, once the arrows are let go, the mod closes the rest and finds the height (it
-- sweeps the pointer's height until the hit test says on target, as Tab does). With aim = auto
-- there is no tone: "On target" is said when the crosshair comes onto the cop and "Off target"
-- when it leaves him.
-- In automatic action scenes (actions.lua, F11) the mod aims and fires by itself.
local TWDA = ...
local G = _G

local VK_TAB, VK_ENTER, VK_SHIFT = TWDA.tabVK or 0x09, 0x0D, 0x10
local VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN = 0x25, 0x26, 0x27, 0x28
local HAND_SPEED = 0.12      -- pointer travel per second with an arrow key held (0 to 1 is the full turn)
local SCAN_LOW, SCAN_HIGH = 0.25, 0.65 -- pointer heights the assist searches for the head
local SCAN_SPEED = 0.2       -- per second
local TONE_EVERY = 0.12
local SNAP_X = 0.08          -- how near the cop (screen widths across) the mod closes the aim
local ROWS = { 0.5, 0.38, 0.62, 0.26, 0.74, 0.14, 0.86 } -- screen heights searched for the cop

local function call(name, ...)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

-- The shotgun mode is up: combat reticle shown and its input map active.
local function shotgunActive()
  if type(rawget(G, "mode_shotgun")) ~= "table" then return false end
  if call("ReticleUI_InCombatMode") ~= true then return false end
  local ok, names = pcall(InputMapperGetActiveMapperNames)
  if not ok or type(names) ~= "table" then return false end
  for _, name in ipairs(names) do
    if tostring(name):lower() == "mode_shotgun.imap" then return true end
  end
  return false
end

-- The game's own target (Shotgun_Fire checks AgentFind("cop")), and the point to aim at.
local function targets()
  local cop = call("AgentFind", "cop")
  return cop, call("AgentFind", "obj_copHead") or cop
end

local function onTarget(cop)
  if cop == nil then return false end
  local ok, agent = pcall(AgentAtScreenPos, Vector(0.5, 0.5), true, cop)
  return ok and agent == cop
end

-- The mouse pointer, 0 to 1 across and down; the shotgun and the rifle scope (sniper.lua) turn with
-- where it is.
local function getPointer()
  local ok, pos = pcall(function() return ScreenToViewport(CursorGetPos()) end)
  if ok and pos then return pos.x, pos.y end
  return 0.5, 0.5
end
TWDA.getPointer = getPointer

local function setPointer(x, y)
  x, y = math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
  pcall(function() CursorSetPos(ViewportToScreen(Vector(x, y, 0))) end)
end
TWDA.setPointer = setPointer

-- Left-right: the horizontal pan camera (the scene camera's parent, "cam_pan_player_horizontal")
-- projects the head where it is drawn across the screen. (The scene camera itself and
-- AgentGetScreenPos do not follow the pan, and nothing found so far follows the up-down pan, so
-- the assist searches for the height with the hit test instead.)
local function horizontalCamera()
  local cam = call("AgentFind", "cam_pan_player_horizontal")
  if cam then return cam end
  local scene = call("SceneGetCamera", call("SceneGetBottomScene"))
  return scene and call("AgentGetParent", scene) or nil
end

local function headAcross(head)
  local cam = horizontalCamera()
  if not cam or not head then return nil end
  local ok, pos = pcall(CameraGetScreenPosFromWorldPos, cam, AgentGetWorldPos(head))
  if ok and pos and pos.x then return pos.x end
  return nil
end

-- Where on screen a shot would hit the cop: the middle of the run of such points along the
-- crosshair's row, else along the nearest row with any. x, y, or nil when he is not in view.
local function copOnScreen(cop)
  for _, y in ipairs(ROWS) do
    local first, last
    for i = 1, 39 do
      local x = i / 40
      local ok, hit = pcall(AgentAtScreenPos, Vector(x, y), true, cop)
      if ok and hit == cop then
        first, last = first or x, x
      elseif first then
        break
      end
    end
    if first then return (first + last) / 2, y end
  end
  return nil
end

local state = nil -- while aiming: { assist, auto, sound, scanDir, wasOn, onSince, toldOn, toneAt, spotX, spotY, fired,
                  --   lastFrame }
local held = {}

local function edge(vk)
  local ok, down = pcall(InputPCIsVKeyPressed, vk)
  down = ok and down == true
  local e = down and not held[vk]
  held[vk] = down
  return e, down
end

local function fire()
  if state.fired then return end
  state.fired = true
  TWDA.log("aiming: firing" .. (onTarget((targets())) and " (on target)" or " (off target)"))
  local mode = rawget(G, "mode_shotgun")
  local ok, err = pcall(mode.OnGamepadButtonA, mode)
  if not ok then TWDA.log("aiming: fire failed: " .. tostring(err)) end
end

local function describe()
  local cop, head = targets()
  if onTarget(cop) then return "Aiming the shotgun. On target. Enter to fire." end
  local x = headAcross(head)
  local where = ""
  if x then
    if x < 0.4 then where = " The cop is to the left."
    elseif x > 0.6 then where = " The cop is to the right."
    else where = " The cop is straight ahead; aim up or down." end
  end
  return "Aiming the shotgun." .. where .. TWDA.tabWords(" Tab aims for you, arrow keys aim by hand, Enter fires.")
end
TWDA.describeAiming = function() return state and describe() or nil end

TWDA.onFrame("aiming", function()
  if not shotgunActive() then
    if state then TWDA.log("aiming: mode over") end
    state = nil
    return
  end
  local now = TWDA.now()
  local dt = state and math.min(0.1, now - state.lastFrame) or 0
  if not state then
    local auto = (TWDA.settings.actionscenes or "slow") == "auto"
    local sound = not auto and (TWDA.settings.aim or "sound") ~= "auto"
    state = { assist = auto, auto = auto, sound = sound, scanDir = -1, wasOn = false, toneAt = 0, lastFrame = now }
    TWDA.log("aiming: shotgun mode" .. (sound and " (by a tone)" or ""))
    TWDA.say(auto and "Aiming the shotgun at the cop. Aiming for you."
      or sound and TWDA.tabWords("Aiming the shotgun at the cop. Arrows aim, a tone guides you, Enter fires. Tab aims for you.")
      or TWDA.tabWords("Aiming the shotgun at the cop. Tab aims for you, arrow keys aim by hand, Enter fires."), { interrupt = true })
  end
  state.lastFrame = now
  if state.fired then return end

  local tab = edge(VK_TAB)
  local enter = edge(VK_ENTER)
  local _, left = edge(VK_LEFT)
  local _, right = edge(VK_RIGHT)
  local _, up = edge(VK_UP)
  local _, down = edge(VK_DOWN)

  local cop, head = targets()
  local on = onTarget(cop)
  if on ~= state.wasOn then
    state.wasOn = on
    state.onSince = on and now or nil
    if state.sound then
      if on and not state.toldOn then
        state.toldOn = true
        TWDA.say("On target. Enter to fire.", { interrupt = true })
      end
    elseif not state.auto then
      TWDA.say(on and "On target. Enter to fire." or "Off target", { interrupt = true })
    end
  end
  local across = headAcross(head)
  -- (Panned fully a third of a screen off; lowest at two thirds or more. Out of view, the head
  -- through the pan camera gives the way.)
  local spotNew = false
  if state.sound and now - state.toneAt >= TONE_EVERY then
    state.toneAt = now
    local sx, sy = copOnScreen(cop)
    state.spotX, state.spotY = sx, sy
    spotNew = sx ~= nil
    local ex = sx and sx - 0.5 or across and across - 0.5
    if ex and TWDA.aimTone then
      local ey = sy and sy - 0.5 or 0
      TWDA.aimTone({ on = on, off = math.sqrt(ex * ex + ey * ey) / 0.65, pan = math.max(-1, math.min(1, ex / 0.33)) })
    end
  end

  if enter then fire() return end
  if tab then
    state.assist = true
    TWDA.say("Aiming", { interrupt = true })
  end

  local x, y = getPointer()
  if left or right or up or down then
    state.assist = false
    local okS, shift = pcall(InputPCIsVKeyPressed, VK_SHIFT)
    local speed = HAND_SPEED * ((okS and shift == true) and 3 or 1)
    x = x + ((right and 1 or 0) - (left and 1 or 0)) * speed * dt
    y = y + ((down and 1 or 0) - (up and 1 or 0)) * speed * dt
    setPointer(x, y)
    return
  end

  -- By a tone, near the cop: the rest closed across (a step for each new look, the pointer moving
  -- the view about two screen widths for its whole way), the height swept.
  local near = not state.assist and state.sound and state.spotX and math.abs(state.spotX - 0.5) <= SNAP_X
  if not state.assist and not near then return end
  if near then
    if spotNew then x = x + 0.25 * (state.spotX - 0.5) end
  -- Across: steer the head to the middle (moving the pointer right turns the view right, which
  -- moves the head left on screen).
  elseif across then
    x = x + 0.25 * (across - 0.5)
  end
  -- Up and down: hold while on target or (near, by a tone) while he is in the crosshair's row,
  -- otherwise sweep between SCAN_LOW and SCAN_HIGH.
  if not on and not (near and state.spotY == ROWS[1]) then
    y = y + state.scanDir * SCAN_SPEED * dt
    if y <= SCAN_LOW then y, state.scanDir = SCAN_LOW, 1 end
    if y >= SCAN_HIGH then y, state.scanDir = SCAN_HIGH, -1 end
  end
  setPointer(x, y)
  if state.auto and on and state.onSince and now - state.onSince > 0.15 then fire() end
end)
