-- Marlon's bow in The Final Season (projectseason4's ai_player.lua, from Episode 2): the right mouse
-- button held draws it (AI_Player_RM_Down sets the player's "AI Player - Scrub Chore Desired
-- Percent" to 1; drawn, "AI Player - Interaction Ranged Enable" is on) and the left one shoots
-- (AI_Player_L runs the player's dialog node "bg_rangedProjectile"; an arrow that reaches a hit box
-- runs "bg_hitTarget"). The arrow goes where the camera looks, and the camera turns with the mouse:
-- nothing for the keyboard, nothing to aim by ear.
--
-- The mod: R draws the bow and puts it down. Drawn, it takes the nearest target (the swinging
-- target's hit box "ai_hitBox_target" at the school, or a walker's head) and, with the setting
-- aim = sound (the default), plays a tone on it every eighth of a second (sounds.lua): panned to
-- where it is from where the camera looks, higher the nearer the aim is to it, muffled behind, and
-- a quick double tick when it is in the middle ("On target. Enter shoots." once). The arrow keys turn
-- the camera (the helper's /mouse: the camera turns only with the mouse), slowly when tapped and
-- faster the longer they are held, Shift faster still; the height
-- is kept level with the target, and the last few degrees are closed for the player once the arrows
-- are let go. With aim = auto the mod turns the camera onto the target by itself. Enter shoots,
-- Tab picks the next target. A bow drawn with the mouse is left to the mouse.
local TWDA = ...
local G = _G

local BASE = "http://127.0.0.1:41234"
local VK_R, VK_TAB, VK_SHIFT = 0x52, 0x09, 0x10
local VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN = 0x25, 0x26, 0x27, 0x28
local STEER_EVERY = 0.15 -- seconds between mouse moves in auto aim (each one the helper spreads out)
local TURN_EVERY = 0.05 -- seconds between turns while an arrow is held
-- (Mouse pixels per turn: the setting bowturn, 16 by default; Shift three times as fast. The game
-- turns about a degree for 65 pixels, so 16 alone is some 5 degrees a second, fine for the last
-- bit but far too slow to turn to a walker coming from the side: held, the arrows speed up to
-- RAMP_MAX times that, some 40 degrees a second, from RAMP_AFTER to RAMP_FULL seconds in.)
local RAMP_AFTER, RAMP_FULL, RAMP_MAX = 0.2, 0.8, 8
local TONE_EVERY = 0.12
local SNAP_X = 0.12 -- how near the middle the aim is closed for the player
local RANGE = 30 -- meters
local ON_X, ON_Y = 0.03, 0.04 -- how near the middle counts as on target (a walker keeps moving)

local function playerProps()
  local exec = TWDA.upvalue(rawget(G, "AI_Player_E"), "ExecuteInteraction")
  local player = exec and TWDA.upvalue(exec, "mPlayer")
  local ok, props = pcall(function() return player.mProps end)
  return ok and props or nil
end

local function get(props, key)
  local ok, value = pcall(function() return props[key] end)
  if ok then return value end
  return nil
end

local function prop(agent, key)
  local ok, value = pcall(AgentGetProperty, agent, key)
  if ok then return value end
  return nil
end

local function bowInHand(props)
  return props ~= nil and get(props, "AI Player - Scrub Chore Enable") == true
end

local function call(name, ...)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

-- What the arrow can hit: hit boxes ("ai_hitBox_target"), and walkers up and about, aimed at the
-- head. { agent, name, point (world), distance }.
local function targets()
  local list = {}
  local okP, here = pcall(AgentGetWorldPos, TWDA.player())
  if not okP or not here then return list end
  local okS, agents = pcall(SceneGetAgents, TWDA.playerScene())
  for _, agent in ipairs(okS and type(agents) == "table" and agents or {}) do
    local name = TWDA.agentName(agent)
    local point = nil
    if name:find("^ai_hitBox") and call("AgentIsHidden", agent) == false then
      point = call("AgentGetWorldPos", agent)
    elseif agent ~= TWDA.player() and prop(agent, "AI Agent - AI Agent Enable") == true and call("AgentIsHidden", agent) == false then
      local pos = call("AgentGetWorldPos", agent)
      point = pos and Vector(pos.x, pos.y + 1.55, pos.z)
    end
    if point then
      local dx, dz = point.x - here.x, point.z - here.z
      local d = math.sqrt(dx * dx + dz * dz)
      if d <= RANGE then
        local label = name:find("^ai_hitBox") and "Target" or (call("Game_GetNounText", agent) or "Walker")
        if label == "" then label = "Walker" end
        list[#list + 1] = { agent = agent, name = name, label = TWDA.cleanText(label), point = point, distance = d }
      end
    end
  end
  table.sort(list, function(a, b) return a.distance < b.distance end)
  return list
end

local function screenPos(point)
  local okC, camera = pcall(function() return SceneGetCamera(TWDA.playerScene()) end)
  if not okC or camera == nil then return nil end
  local ok, pos = pcall(CameraGetScreenPosFromWorldPos, camera, point)
  if ok and pos then return pos end
  return nil
end

local drawn, aim, onTarget, lastSteer = false, nil, false, 0
local wanted, loweredAt, lastLook = false, nil, 0 -- (the player's own R: the bow stays up until R again)
local held, toldInHand = {}, false

local function soundMode()
  return (TWDA.settings.aim or "sound") ~= "auto"
end

local function whereText(t)
  local dir = TWDA.soundDirection and TWDA.soundDirection(t.point)
  if not dir then return nil end
  local deg = math.deg(dir.angle)
  if math.abs(deg) <= 10 then return "ahead" end
  if math.abs(deg) >= 135 then return "behind you" end
  return deg < 0 and "to your left" or "to your right"
end

local function sayTarget(t)
  if soundMode() then
    local where = whereText(t)
    TWDA.say(("%s, %d meters%s."):format(t.label, math.floor(t.distance + 0.5), where and (", " .. where) or ""),
      { interrupt = true })
  else
    TWDA.say(("%s, %d meters. Turning to it."):format(t.label, math.floor(t.distance + 0.5)), { interrupt = true })
  end
end

local drawnAt = 0

local function draw(on)
  drawn, aim, onTarget = on, nil, false
  drawnAt = TWDA.now()
  pcall(rawget(G, on and "AI_Player_RM_Down" or "AI_Player_RM_Up"), {})
  if not on then
    TWDA.say("Bow down.", { interrupt = true })
    return
  end
  local list = targets()
  aim = list[1]
  if aim then sayTarget(aim) else TWDA.say("Bow drawn. Nothing to shoot at in range.", { interrupt = true }) end
end

function TWDA.bowDrawn()
  return drawn
end

local function keyDown(vk)
  local ok, down = pcall(InputPCIsVKeyPressed, vk)
  return ok and down == true
end

local function mouse(dx, dy)
  dx, dy = math.floor(dx + 0.5), math.floor(dy + 0.5)
  if dx == 0 and dy == 0 then return end
  pcall(HttpGetAsync, ("%s/mouse?dx=%d&dy=%d"):format(BASE, dx, dy))
end

local lastTurn, lastTone = 0, 0
local turnSince, turnWay = nil, nil -- (when the arrows held now went down, and which way they turn)

-- The tone on the target: see the top of the file.
local function playTone(on)
  if not TWDA.aimTone then return end
  local dir = TWDA.soundDirection and TWDA.soundDirection(aim.point)
  if not dir then return end
  -- (Panned fully at 30 degrees off: fine near the middle. Lowest at 90 degrees or more.)
  TWDA.aimTone({ on = on, off = math.abs(dir.angle) / (math.pi / 2),
    pan = math.max(-1, math.min(1, dir.angle / (math.pi / 6))), v = 0.5 - math.min(0.3, aim.distance / 60),
    behind = dir.behind })
end

local function steer()
  local now = TWDA.now()
  -- (Drawn with nothing to aim at: the next walker to come is taken; the target gone: the next.)
  if now - lastSteer >= STEER_EVERY then
    if not aim then
      lastSteer = now
      aim, onTarget = targets()[1], false
      if aim then sayTarget(aim) end
      return
    end
    if call("AgentIsHidden", aim.agent) == true
        or (not aim.name:find("^ai_hitBox") and prop(aim.agent, "AI Agent - AI Agent Enable") ~= true) then
      lastSteer = now
      aim, onTarget = targets()[1], false
      if aim then sayTarget(aim) else TWDA.say("Nothing more to shoot at.", { interrupt = true }) end
      return
    end
  end
  if not aim then return end
  if not aim.name:find("^ai_hitBox") then
    local pos = call("AgentGetWorldPos", aim.agent)
    if pos then aim.point = Vector(pos.x, pos.y + 1.55, pos.z) end
  end
  local pos = screenPos(aim.point)
  if not pos then return end
  local ex, ey = pos.x - 0.5, pos.y - 0.5
  local front = (pos.z or 1) > 0
  local on = front and math.abs(ex) <= ON_X and math.abs(ey) <= ON_Y
  -- (Said once for each target: a walker's head swings in and out of the middle as it comes.)
  onTarget = on
  if on and not aim.toldOn then
    aim.toldOn = true
    TWDA.say("On target. Enter shoots.", { interrupt = true })
  end

  if soundMode() then
    if now - lastTone >= TONE_EVERY then
      lastTone = now
      playTone(on)
    end
    if now - lastTurn < TURN_EVERY then return end
    lastTurn = now
    local left, right, up, down = keyDown(VK_LEFT), keyDown(VK_RIGHT), keyDown(VK_UP), keyDown(VK_DOWN)
    local way = (left and "l" or "") .. (right and "r" or "") .. (up and "u" or "") .. (down and "d" or "")
    if way == "" then
      turnSince = nil
    elseif way ~= turnWay or not turnSince then
      turnSince = now
    end
    turnWay = way
    local step = tonumber(TWDA.settings.bowturn) or 16
    if turnSince then
      local ramp = math.max(0, math.min(1, (now - turnSince - RAMP_AFTER) / (RAMP_FULL - RAMP_AFTER)))
      step = step * (1 + (RAMP_MAX - 1) * ramp)
    end
    if keyDown(VK_SHIFT) then step = step * 3 end
    step = math.min(400, step)
    local dx = (right and step or 0) - (left and step or 0)
    local dy = (down and step or 0) - (up and step or 0)
    -- (Height kept level with the target unless Up or Down is held; the last few degrees closed once
    -- the arrows are let go.)
    if front and not up and not down and math.abs(ey) > ON_Y / 3 then
      dy = math.max(-120, math.min(120, ey * 800))
    end
    if front and not left and not right and math.abs(ex) <= SNAP_X and math.abs(ex) > ON_X / 3 then
      dx = math.max(-100, math.min(100, ex * 1000))
    end
    mouse(dx, dy)
    return
  end

  if now - lastSteer < STEER_EVERY then return end
  lastSteer = now
  if on then return end
  local dx, dy
  if not front then
    dx, dy = 350, 0 -- (behind: turn until it comes round)
  else
    dx = math.max(-350, math.min(350, ex * 1500))
    dy = math.max(-250, math.min(250, ey * 1000))
    if math.abs(ex) > ON_X / 2 and math.abs(dx) < 4 then dx = ex > 0 and 4 or -4 end
    if math.abs(ey) > ON_Y / 2 and math.abs(dy) < 4 then dy = ey > 0 and 4 or -4 end
  end
  if now - (aim.loggedAt or -10) > 1 then
    aim.loggedAt = now
    TWDA.log(("bow4: %s at %.2f %.2f %.2f, moving %d %d"):format(aim.name, pos.x, pos.y, pos.z or -9, math.floor(dx), math.floor(dy)))
  end
  mouse(dx, dy)
end

TWDA.onFrame("bow4", function()
  local props = playerProps()
  -- (Interaction can be off while the bow is up: the burning walkers at the school, Episode 2.)
  local inHand = bowInHand(props)
  if not inHand then
    if drawn then
      drawn, aim = false, nil
      loweredAt = TWDA.now()
      TWDA.log("bow4: bow put away")
    end
    toldInHand = false
    held = {}
    return
  end
  if not toldInHand then
    toldInHand = true
    TWDA.say(soundMode() and "Bow in hand: R draws it. Drawn, arrows aim, Enter shoots, Tab picks another target."
      or "Bow in hand: R draws it. Drawn, Enter shoots, Tab picks another target.")
  end
  -- (Lowered by the game, a walker grabbing her, or drawn with the mouse: the player's own aim.
  -- A bow the mod drew comes back up a second after the game lowers it, until R puts it away:
  -- the burning walkers at the school, Episode 2, keep coming after each struggle.)
  local now = TWDA.now()
  if drawn and get(props, "AI Player - Scrub Chore Desired Percent") ~= 1 then
    drawn, aim = false, nil
    loweredAt = now
    TWDA.log("bow4: lowered by the game or the mouse")
  end
  -- (Only with something to shoot: the game lowers it for cut scenes too, and the end of Episode 2
  -- had it drawn again over the statistics. Not with a walker close that Q and E can fight: the
  -- pier, Episode 3, is fought hand to hand; the burning walkers offer no Q or E.)
  local struggling = TWDA.struggleActive and TWDA.struggleActive()
  if wanted and not drawn and not struggling and loweredAt and now - loweredAt > 1
      and get(props, "AI Player - Interaction Enable") == true and now - lastLook > 0.5 then
    lastLook = now
    local melee = TWDA.walkerNear and TWDA.walkerNear(6)
    if #targets() > 0 and not melee and call("Menu_GetCurrentMenu") == nil then
      loweredAt = nil
      TWDA.log("bow4: drawing again")
      draw(true)
    end
  end
  for _, vk in ipairs({ VK_R, VK_TAB }) do
    local ok, down = pcall(InputPCIsVKeyPressed, vk)
    down = ok and down == true
    if down and not held[vk] then
      if vk == VK_R then
        wanted = not drawn
        draw(not drawn)
      elseif drawn then
        local list = targets()
        if #list > 0 then
          local okS, shift = pcall(InputPCIsVKeyPressed, VK_SHIFT)
          local index = 1
          for i, t in ipairs(list) do if aim and t.agent == aim.agent then index = i end end
          index = ((index - 1 + ((okS and shift) and -1 or 1)) % #list) + 1
          aim, onTarget = list[index], false
          sayTarget(aim)
        end
      end
    end
    held[vk] = down
  end
  if drawn then steer() end
end)

-- Enter shoots while the mod holds the bow drawn (Enter is otherwise the game's "use", and
-- lookaround4.lua's). A click is the game's own shot.
-- (Drawn but still not ready after a moment and a half, the game has taken the shot away: the river
-- at night, Episode 3, keeps the bow up while "Use Guts" waits for Enter. With nothing to aim at and
-- something the game offers, Enter uses that too.)
TWDA.hookGlobal("Useable_OnButtonUse", function(original)
  return function(event, ...)
    if drawn and not (type(event) == "table" and event.code == 816) then -- (816: the left mouse button)
      local props = playerProps()
      local ready = get(props, "AI Player - Interaction Ranged Enable") == true
      local offered = TWDA.upvalue(TWDA.unwrap(original), "mSelectedUseable")
      if ready and (aim or offered == nil) then
        -- (Where the target was on screen, for telling a miss from a walker that takes two.)
        local pos = aim and screenPos(aim.point)
        TWDA.log(("bow4: shooting at %s%s"):format(aim and aim.name or "nothing",
          pos and (" (screen %.3f %.3f)"):format(pos.x, pos.y) or ""))
        pcall(rawget(G, "AI_Player_L"), {})
        return
      end
      if not ready and TWDA.now() - drawnAt < 1.5 then
        TWDA.say("Still drawing.", { interrupt = true })
        return
      end
      TWDA.log("bow4: Enter left to the game (" .. (ready and "nothing to aim at" or "bow not ready") .. ")")
    elseif drawn then
      return
    end
    return original(event, ...)
  end
end)

-- While the mod holds the bow drawn and aims by ear, the arrow keys turn the camera, not walk her
-- (the same handlers take W A S D, which still walk).
for _, name in ipairs({ "Navigate_OnButtonLeft", "Navigate_OnButtonRight", "Navigate_OnButtonUp", "Navigate_OnButtonDown" }) do
  TWDA.hookGlobal(name, function(original)
    return function(event, ...)
      if drawn and soundMode()
          and (keyDown(VK_LEFT) or keyDown(VK_RIGHT) or keyDown(VK_UP) or keyDown(VK_DOWN))
          and not (keyDown(0x57) or keyDown(0x41) or keyDown(0x53) or keyDown(0x44)) then
        return
      end
      return original(event, ...)
    end
  end)
end

function TWDA.describeBow()
  if not drawn then return nil end
  if not aim then return "Bow drawn. Nothing to shoot at." end
  local where = not onTarget and whereText(aim)
  return ("Bow drawn, aiming at %s, %d meters%s."):format(aim.label, math.floor(aim.distance + 0.5),
    onTarget and ", on target. Enter shoots" or (where and (", " .. where) or ""))
end
