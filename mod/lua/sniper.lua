-- The rifle scope in Season 1 (the game's mode_sniper.lua): in the bandit attack at the Motor Inn
-- (Episode 3) Lee hides behind the RV, and leaning out puts the view down a rifle scope for about
-- ten seconds (the dialog timer timer_sniperScope) while bandits duck in and out of cover. Shooting
-- them in time is the way on; otherwise Lee is shot after half a minute or so.
--
-- What the game does: the scope turns with the mouse (dragging moves two pan chores) and a click
-- fires: sniperFire calls sniperFireAtPos(screen position), which hits when a target is what lies
-- under that point (AgentAtScreenPos). The mode's Enter handler fires nothing on PC.
--
-- The mod watches the targets (whatever the reticle could take while the scope is up: only the
-- bandits, or the walkers and their heads, are; the hotspots' own verbs say nothing useful here,
-- "Talk To" on a walker) and counts one as in sight when it is itself under a point at or near its
-- hotspot dot, not behind its cover.
-- With the setting aim = auto, "In sight! Enter!" is said when one comes out, and Enter shoots it
-- there. In automatic action scenes (actions.lua, F11) the mod shoots by itself.
--
-- With aim = sound (the default) the player aims, as with the bow: the scope turns with where the
-- pointer is (sniperUpdate: h_chore:MouseUpdate(x), v_chore:MouseUpdate(1 - y)), the arrows move the
-- pointer, and the game's own shot (sniperFire) is at the middle of the screen. A tone (sounds.lua)
-- on the target nearest the crosshair, those in sight first: panned to it, higher the nearer, muffled
-- while it is behind cover, a double tick when it is under the crosshair. The height is kept level
-- with it, and once the arrows are let go near it the mod closes the rest. Enter fires at the middle.
local TWDA = ...
local G = _G

local VK_ENTER, VK_SHIFT = 0x0D, 0x10
local VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN = 0x25, 0x26, 0x27, 0x28
local CHECK_EVERY = 0.08 -- seconds between hit tests
local LIST_EVERY = 0.5   -- seconds between refreshing the targets
local AUTO_DELAY = 0.2   -- auto mode: in sight this long before the shot
local LOST_AFTER = 0.3   -- out of the hit test this long before "Gone"
local TONE_EVERY = 0.12
local HAND_SPEED = 0.2   -- pointer travel per second with an arrow held (Shift: three times)
local SNAP = 0.06        -- how near the target (screen) the mod closes the aim
-- (A move of the pointer moves what the scope shows the other way, about as far across and 0.8 as
-- far up and down: measured at the start of Episode 4.)
local TURN_X, TURN_Y = 1.0, 0.8

-- Points tried around a target's dot, nearest first.
local NEAR = { { 0, 0 } }
for _, r in ipairs({ 0.02, 0.04, 0.06, 0.08 }) do
  for _, d in ipairs({ { 0, -r }, { 0, r }, { r, 0 }, { -r, 0 }, { r, -r }, { -r, -r }, { r, r }, { -r, r } }) do
    NEAR[#NEAR + 1] = d
  end
end

local function active()
  if type(rawget(G, "mode_sniper")) ~= "table" then return false end
  local ok, on = pcall(InputMapperIsActive, "mode_sniper.imap")
  return ok and on == true
end
TWDA.sniperActive = active

local function fireAt()
  local fire = TWDA.upvalue(TWDA.unwrap(mode_sniper.OnRelease), "sniperFire")
  local at = type(fire) == "function" and TWDA.upvalue(fire, "sniperFireAtPos") or nil
  return type(at) == "function" and at or nil
end

-- Where a target is on screen (its hotspot dot, else the agent), on screen or not.
local function screenPos(agent)
  local dot = rawget(agent, "dot")
  if dot ~= nil then
    local ok, pos = pcall(AgentGetLogicalScreenPos, dot)
    if ok and pos and pos.x then return pos end
  end
  local ok, pos = pcall(AgentGetScreenPos, agent)
  if ok and pos and pos.x then return pos end
  return nil
end

-- Where on screen the target itself can be hit, or nil while it is behind cover.
local function sightPoint(agent)
  local base = screenPos(agent)
  if not base or base.x < -0.05 or base.x > 1.05 or base.y < -0.05 or base.y > 1.05 then return nil end
  for _, d in ipairs(NEAR) do
    local point = Vector(base.x + d[1], base.y + d[2], 0)
    local ok, hit = pcall(AgentAtScreenPos, point)
    if ok and hit == agent then return point end
  end
  return nil
end

local state = nil -- while the scope is up: { targets, listAt, checkAt, sight, sightSince, lostAt, quietSince,
                  --   sideHint, shot, auto, upAt, sound, points, toneAt, toldOn, lastFrame }

-- A target with a target of its own is shot through that one: the walkers at the Motor Inn
-- (Zombie6) only go down to a shot in the head (obj_ZombieHead6, its child); a body shot counts as
-- a hit and changes nothing.
local function refreshTargets()
  local list, parents = {}, {}
  for _, entry in ipairs(TWDA.hotspots and TWDA.hotspots() or {}) do
    if entry.clickable and not state.shot[entry.agent] then
      list[#list + 1] = entry
      local ok, parent = pcall(AgentGetParent, entry.agent)
      if ok and parent ~= nil then parents[#parents + 1] = parent end
    end
  end
  local targets = {}
  for _, entry in ipairs(list) do
    local isParent = false
    for _, parent in ipairs(parents) do
      if parent == entry.agent then isParent = true break end
    end
    if not isParent then targets[#targets + 1] = entry end
  end
  state.targets = targets
end

local function distanceToLee(agent)
  local ok, d = pcall(function() return VectorDistance(AgentGetWorldPos(agent), AgentGetWorldPos(TWDA.player())) end)
  return ok and d or math.huge
end

-- The nearest target in sight: { entry, point }. (Each target's point is kept in state.points.)
local function findSight()
  local best, bestDistance = nil, math.huge
  state.points = {}
  for _, entry in ipairs(state.targets) do
    if not state.shot[entry.agent] then
      local point = sightPoint(entry.agent)
      state.points[entry.agent] = point
      if point then
        local d = distanceToLee(entry.agent)
        if d < bestDistance then best, bestDistance = { entry = entry, point = point }, d end
      end
    end
  end
  return best
end

local held = false
local function enterPressed()
  local ok, down = pcall(InputPCIsVKeyPressed, VK_ENTER)
  down = ok and down == true
  local edge = down and not held
  held = down
  return edge
end

-- A target that was hit is done with, and so are its head or body (the walkers at the Motor Inn are
-- each two targets: Zombie6 and obj_ZombieHead6, its child).
local function markShot(agent)
  state.shot[agent] = true
  local ok, parent = pcall(AgentGetParent, agent)
  if ok and parent ~= nil then state.shot[parent] = true end
  for _, entry in ipairs(state.targets) do
    local okP, p = pcall(AgentGetParent, entry.agent)
    if okP and p == agent then state.shot[entry.agent] = true end
  end
end

-- Walkers come at the RV from both sides; with the scope up and Lee not leaning, the lean keys
-- move him to the other side ("Press A or D to move between sides!"). Said once after a while with
-- nothing in sight.
local QUIET_HINT_AFTER = 0.8
local function otherSideKey()
  local okPeek, peeking = pcall(Peek_IsPeeking)
  if okPeek and peeking == true then return nil end
  local dirs = TWDA.peekDirections and TWDA.peekDirections()
  if type(dirs) ~= "table" or #dirs ~= 1 then return nil end
  return dirs[1]:match("^(%a)")
end

local function shoot()
  local sight = findSight() or state.sight
  if not sight then
    TWDA.say("Nobody in sight. Wait for it.", { interrupt = true })
    return
  end
  local at = fireAt()
  if not at then
    TWDA.log("sniper: no sniperFireAtPos")
    return
  end
  local ok, hit = pcall(at, sight.point)
  TWDA.log(("sniper: shot at %s (%.2f,%.2f): %s %s"):format(TWDA.agentName(sight.entry.agent), sight.point.x, sight.point.y,
    tostring(ok), tostring(hit)))
  if ok and hit then
    markShot(sight.entry.agent)
    state.sight, state.lostAt, state.quietSince = nil, nil, TWDA.now()
    TWDA.say("Hit!", { interrupt = true })
  else
    TWDA.say("Missed.", { interrupt = true })
  end
end

-- Aiming by a tone: the target nearest the crosshair, those in sight first. { entry, pos, inSight }.
local function toneTarget()
  local best, bestKey = nil, math.huge
  for _, entry in ipairs(state.targets) do
    if not state.shot[entry.agent] then
      local point = state.points and state.points[entry.agent]
      local pos = point or screenPos(entry.agent)
      if pos then
        local key = math.sqrt((pos.x - 0.5) ^ 2 + (pos.y - 0.5) ^ 2) + (point and 0 or 10)
        if key < bestKey then best, bestKey = { entry = entry, pos = pos, inSight = point ~= nil }, key end
      end
    end
  end
  return best
end

local function keyDown(vk)
  local ok, down = pcall(InputPCIsVKeyPressed, vk)
  return ok and down == true
end

local function prop(agent, key)
  local ok, value = pcall(AgentGetProperty, agent, key)
  if ok then return value end
  return nil
end

-- Enter, aiming by a tone: the game's own shot, at the middle of the screen (sniperFire).
local function shootMiddle()
  local at = fireAt()
  if not at then return end
  if prop("logic_mode_sniper", "Sniper - Fire Delayed") == true then return end
  local middle = Vector(0.5, 0.5, 0)
  local okA, under = pcall(AgentAtScreenPos, middle)
  local ok, hit = pcall(at, middle)
  TWDA.log(("sniper: shot at the middle (%s): %s %s"):format(okA and TWDA.agentName(under) or "?", tostring(ok), tostring(hit)))
  if ok and hit then
    if okA and under ~= nil then markShot(under) end
    state.sight, state.lostAt, state.quietSince = nil, nil, TWDA.now()
    TWDA.say("Hit!", { interrupt = true })
  else
    local node = prop("logic_mode_sniper", "Sniper - Miss Dialog Node")
    if node then pcall(Dialog_Play, node) end
    TWDA.say("Missed.", { interrupt = true })
  end
end

-- Aiming by a tone, each frame: the arrows, the tone, and the height and the last bit closed.
local function aimByTone(now)
  local dt = math.min(0.1, now - (state.lastFrame or now))
  state.lastFrame = now
  local aim = toneTarget()
  local on = false
  if aim and aim.inSight then
    local okM, mid = pcall(AgentAtScreenPos, Vector(0.5, 0.5, 0))
    on = okM and mid == aim.entry.agent
  end
  if on and not state.toldOn then
    state.toldOn = true
    TWDA.say("On target. Enter shoots.", { interrupt = true })
  end
  if aim and now - state.toneAt >= TONE_EVERY and TWDA.aimTone then
    state.toneAt = now
    local ex = aim.pos.x - 0.5
    TWDA.aimTone({ on = on, off = math.sqrt(ex * ex + (aim.pos.y - 0.5) ^ 2) / 0.6,
      pan = math.max(-1, math.min(1, ex / 0.3)), behind = not aim.inSight })
  end
  local left, right, up, down = keyDown(VK_LEFT), keyDown(VK_RIGHT), keyDown(VK_UP), keyDown(VK_DOWN)
  local x, y = TWDA.getPointer()
  local speed = HAND_SPEED * (keyDown(VK_SHIFT) and 3 or 1)
  x = x + ((right and 1 or 0) - (left and 1 or 0)) * speed * dt
  y = y + ((down and 1 or 0) - (up and 1 or 0)) * speed * dt
  -- (The view moves the other way from the pointer: a target to the right of the middle comes to it
  -- as the pointer goes right.)
  if aim and not on then
    local ex, ey = aim.pos.x - 0.5, aim.pos.y - 0.5
    if not up and not down then y = y + 0.3 * ey / TURN_Y end
    if not left and not right and math.abs(ex) <= SNAP and math.abs(ey) <= SNAP * 2 then x = x + 0.3 * ex / TURN_X end
  end
  if left or right or up or down or aim then TWDA.setPointer(x, y) end
end

-- With the scope up and aiming by a tone the arrows are the scope's: the leaning mode (mode_peek,
-- whose map takes the arrows as well as W A S D) does not get them. (A and D still lean and change
-- sides at the Motor Inn.)
local peekWrapper
local function keepArrowsFromPeek()
  local mode = rawget(G, "mode_peek")
  local original = type(mode) == "table" and rawget(mode, "OnDirection")
  if type(original) ~= "function" or original == peekWrapper then return end
  peekWrapper = function(self, event, ...)
    if state and state.sound and type(event) == "table" and event.code ~= nil then
      for _, name in ipairs({ "kEventCodeLeft", "kEventCodeRight", "kEventCodeUp", "kEventCodeDown" }) do
        if event.code == rawget(G, name) then return end
      end
    end
    return original(self, event, ...)
  end
  TWDA.wrappers[peekWrapper] = true
  rawset(mode, "OnDirection", peekWrapper)
end

TWDA.describeSniper = function()
  if not state then return nil end
  if state.sound then
    return "Rifle scope, arrows aim. " .. (state.sight and (TWDA.hotspotName(state.sight.entry.agent) .. " in sight.")
      or "Nobody in sight.")
  end
  if state.sight then
    return "Rifle scope. " .. TWDA.hotspotName(state.sight.entry.agent) .. " in sight. Enter!"
  end
  return "Rifle scope. Nobody in sight; wait for one to come out, then Enter."
end

-- Moving to the other side lowers the scope for a second or so; peek.lua keeps quiet about the
-- leaning that goes with it.
local downAt, sideModeAt = -10, -10
TWDA.sniperSwitchingSides = function() return TWDA.now() - sideModeAt < 2.5 end

TWDA.onFrame("sniper", function()
  if not active() then
    if state then
      TWDA.log("sniper: scope down")
      downAt = TWDA.now()
    end
    state = nil
    return
  end
  local now = TWDA.now()
  local okPeek, peeking = pcall(Peek_IsPeeking)
  if not (okPeek and peeking == true) and TWDA.peekActive and TWDA.peekActive() then sideModeAt = now end
  if not state then
    local auto = (TWDA.settings.actionscenes or "slow") == "auto"
    local sound = not auto and (TWDA.settings.aim or "sound") ~= "auto" and TWDA.setPointer ~= nil
    state = { targets = {}, listAt = -10, checkAt = -10, shot = {}, auto = auto, upAt = now, quietSince = now,
      sound = sound, toneAt = 0 }
    held = true -- (an Enter still down from before does not shoot)
    TWDA.log("sniper: scope up" .. (sound and " (by a tone)" or ""))
    if sound then keepArrowsFromPeek() end
    local text = auto and "Rifle scope. Shooting for you."
      or sound and "Rifle scope. Arrows aim, a tone guides you, Enter fires."
      or "Rifle scope. Enter shoots when someone is in sight."
    if now - downAt < 3 then text = "Other side." end
    TWDA.say(text, { interrupt = true })
  end
  if now - state.listAt >= LIST_EVERY then
    state.listAt = now
    refreshTargets()
  end
  if now - state.checkAt >= CHECK_EVERY then
    state.checkAt = now
    local sight = findSight()
    if sight then
      if not state.sight then
        state.sightSince = now
        TWDA.log("sniper: in sight " .. TWDA.agentName(sight.entry.agent))
        -- (Queued after the scope's own announcement when that was only just said.)
        if not state.auto then
          TWDA.say(state.sound and "In sight!" or "In sight! Enter!", { interrupt = now - state.upAt > 1.5 })
        end
      end
      state.sight, state.lostAt, state.sideHint = sight, nil, nil
    elseif state.sight then
      -- (A moment out of the hit test is not yet gone: the edge of the cover flickers.)
      state.lostAt = state.lostAt or now
      if now - state.lostAt >= LOST_AFTER then
        TWDA.log("sniper: out of sight")
        if not state.auto then TWDA.say("Gone.", { interrupt = true }) end
        state.sight, state.lostAt, state.quietSince = nil, nil, now
      end
    elseif now - state.quietSince >= QUIET_HINT_AFTER then
      local key = otherSideKey()
      if key and state.sideHint ~= key then
        state.sideHint = key
        TWDA.log("sniper: nothing in sight; other side " .. key)
        TWDA.say("Nothing in sight here. " .. key .. " for the other side.", { interrupt = true })
      end
    end
  end
  if state.sound then aimByTone(now) end
  if enterPressed() then
    if state.sound then shootMiddle() else shoot() end
  elseif state.auto and state.sight and now - (state.sightSince or now) >= AUTO_DELAY then
    shoot()
  end
end)
