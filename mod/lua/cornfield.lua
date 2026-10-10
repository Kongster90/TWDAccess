-- 400 Days, Bonnie's run through the cornfield (chapter4b_cornfield.lua). Pursuers with flashlights
-- come down the rows; when one comes down Bonnie's row (the panic meter, and arrows on screen),
-- she must step into the row to the left or right. The game's Cornfield.imap binds A, D, Left and
-- Right to that (Cornfield_OnButtonLeft/Right; S and Down look back), but the keys did not always
-- get there (in several tries nothing happened; the arrows on screen are for the mouse), so the
-- mod calls the game's own handlers for those keys when the game has not reacted, and says when
-- someone is coming. Then the rebar: see below.
local TWDA = ...
local G = _G

local VK_LEFT, VK_RIGHT, VK_DOWN, VK_A, VK_D, VK_S = 0x25, 0x27, 0x28, 0x41, 0x44, 0x53

-- Key forwarding: keys = { vk -> handler (a global the game's input map would call) }; guard() is
-- true once the game has reacted by itself. A key is passed on a moment after it is pressed, only
-- if the game has not reacted: a keyboard where its own binding works must not act twice.
local function forwarder(tag, keys, guard)
  local down, pending = {}, nil
  return function(on)
    if not on then
      down, pending = {}, nil
      return
    end
    local now = TWDA.now()
    for vk, handler in pairs(keys) do
      local ok, pressed = pcall(InputPCIsVKeyPressed, vk)
      pressed = ok and pressed == true
      if pressed and not down[vk] then
        if guard() then TWDA.log(tag .. ": key taken by the game") else pending = { handler = handler, at = now } end
      end
      down[vk] = pressed
    end
    if pending and now - pending.at > 0.05 then
      local p = pending
      pending = nil
      if not guard() then
        TWDA.log(tag .. ": " .. p.handler)
        local okThread, err = pcall(ThreadStart, function()
          local okCall, callErr = pcall(rawget(G, p.handler), {})
          if not okCall then TWDA.log(tag .. ": " .. tostring(callErr)) end
        end)
        if not okThread then TWDA.log(tag .. " (thread): " .. tostring(err)) end
      end
    end
  end
end

local function active()
  if type(rawget(G, "Cornfield_OnButtonLeft")) ~= "function" then return false end
  local ok, on = pcall(InputMapperIsActive, "Cornfield.imap")
  return ok and on == true
end
TWDA.cornfieldActive = active

-- The stealth run as a whole (the input map goes off during each row change): the scene's own flag.
function TWDA.cornfieldRunning()
  local handler = rawget(G, "Cornfield_OnButtonRight")
  return type(handler) == "function" and TWDA.upvalue(handler, "mSequenceActive") == true
end

-- A row change (or look back) is under way: the game's own guard, an upvalue of its handlers.
local function moving()
  return TWDA.upvalue(rawget(G, "Cornfield_OnButtonLeft"), "mStealthPositionChangeActive") == true
end

local rows = forwarder("cornfield", {
  [VK_LEFT] = "Cornfield_OnButtonLeft", [VK_A] = "Cornfield_OnButtonLeft",
  [VK_RIGHT] = "Cornfield_OnButtonRight", [VK_D] = "Cornfield_OnButtonRight",
  [VK_DOWN] = "Cornfield_OnButtonDown", [VK_S] = "Cornfield_OnButtonDown",
}, moving)

local told = false
local danger = false

local function dying()
  return TWDA.upvalue(TWDA.upvalue(rawget(G, "Cornfield_OnButtonLeft"), "UpdateDirection"), "mbPlayerIsDying") == true
end

-- Which way to step. The arrows on screen always offer both, but a second pursuer can be coming
-- down the next row ("HeadOnInLeftRow" in the scene's spawn table), where a sighted player sees its
-- light. Bonnie stays put and the field slides a row (about 2.25 m) round her, so the pursuers'
-- places in her frame tell: one ahead of her, a row to the side, makes that side unsafe.
-- (Measured with tools\dev\watch_pursuers.lua.)
local ROW = 2.25
local function rowDanger()
  local player = TWDA.player()
  local okP, here = pcall(AgentGetWorldPos, player)
  local okF, fwd = pcall(AgentGetForwardVec, player)
  if not (okP and here and okF and fwd) then return nil end
  local len = math.sqrt(fwd.x * fwd.x + fwd.z * fwd.z)
  if len < 0.01 then return nil end
  local fx, fz = fwd.x / len, fwd.z / len
  -- Nearest pursuer ahead in the row to the left and to the right (nil: none).
  local nearest, seen = {}, {}
  for _, base in ipairs({ "Pursuer", "CelebrityPursuer" }) do
    for i = 1, 6 do
      local name = base .. i
      local okE, exists = pcall(AgentExists, name)
      local okH, hidden = pcall(AgentIsHidden, name)
      local okW, there = pcall(AgentGetWorldPos, name)
      if okE and exists and okH and hidden == false and okW and there then
        local dx, dz = there.x - here.x, there.z - here.z
        local ahead, left = dx * fx + dz * fz, dx * fz - dz * fx
        seen[#seen + 1] = ("%s %.1f,%.1f"):format(name, ahead, left)
        if ahead > -3 and ahead < 40 then
          for side, offset in pairs({ left = ROW, right = -ROW, here = 0 }) do
            if math.abs(left - offset) < 1.1 and (nearest[side] == nil or ahead < nearest[side]) then
              nearest[side] = ahead
            end
          end
        end
      end
    end
  end
  -- (For the log: every shown pursuer as meters ahead, meters to the left.)
  nearest.seen = table.concat(seen, "; ")
  return nearest
end

-- The key to press ("Right arrow") and why, when only one way is good.
local function ways()
  local ok, nearest = pcall(rowDanger)
  if not ok or nearest == nil then return "Left or Right arrow" end
  TWDA.log("cornfield: pursuers " .. tostring(nearest.seen))
  local left, right = nearest.left, nearest.right
  if left and not right then return "Right arrow", "Someone is in the row to the left" end
  if right and not left then return "Left arrow", "Someone is in the row to the right" end
  if left and right then
    -- (Both: the one further off gives more time.)
    return (left > right and "Left" or "Right") .. " arrow", "Someone is in both rows; that one is further off"
  end
  return "Left or Right arrow"
end
local function warning(start)
  local key, why = ways()
  return ("%s %s%s."):format(start, key, why and (". " .. why) or " to change rows")
end
local lastWarnAt = -10

local warnAt = nil -- when to say who is coming (a moment after the meter, once the arrows show)
TWDA.hookBefore("Chapter4B_Cornfield_PursuerPanicMeter_Activate", function(pursuer)
  local okN, name = pcall(AgentGetName, pursuer)
  if danger then
    TWDA.log("cornfield: another pursuer's row (" .. tostring(okN and name) .. ")")
    return
  end
  danger, warnAt = true, TWDA.now() + 0.15
  TWDA.log("cornfield: pursuer coming (" .. tostring(okN and name) .. ")")
end)
TWDA.hookBefore("Chapter4B_Cornfield_PursuerPanicMeter_Deactivate", function()
  if not danger then return end
  danger, warnAt = false, nil
  -- (It goes off when they catch Bonnie too.)
  if dying() then return end
  TWDA.log("cornfield: out of the way")
  TWDA.say("Out of the way.", { interrupt = true })
end)

-- A row change that leaves Bonnie in someone's row all the same (the meter stays on; once she died
-- that way, a minute later): said again a moment after the move ends.
-- And the end: after a set time the scene's cornEnd() waits for Bonnie to run (W) far enough along
-- her path before the field is done; nothing on screen says so (it waited minutes in a test).
local function endBegun()
  local update = TWDA.upvalue(rawget(G, "Cornfield_OnButtonLeft"), "UpdateDirection")
  return TWDA.upvalue(update, "mCornEndFired") == true
end
local wasMoving, movedAt, toldEnd = false, nil, false
TWDA.onFrame("cornfield.again", function()
  if not TWDA.cornfieldRunning() then
    wasMoving, movedAt, toldEnd = false, nil, false
    return
  end
  if not toldEnd and endBegun() then
    toldEnd = true
    TWDA.log("cornfield: the end begins")
    TWDA.say("Nobody is coming now. Hold W to run out of the field.", { interrupt = true })
  end
  local now, isMoving = TWDA.now(), moving()
  if wasMoving and not isMoving then movedAt = now end
  wasMoving = isMoving
  if movedAt and now - movedAt > 0.6 then
    movedAt = nil
    if danger and not warnAt and now - lastWarnAt > 1.5 and not dying() then
      local okR, rows = pcall(rowDanger)
      if okR and rows and rows.here == nil then
        -- Out of every pursuer's row, and the meter still on: the game switches it off with a
        -- dialog when Bonnie leaves the pursuer's narrow panic box (trigger_PanicMeter_pursuerN,
        -- 0.6 m wide; "trigger_pursuer_panicOff"), and that was sometimes missed, so the meter
        -- went on filling and killed her a row away (four times in a row on 2026-10-10, each the
        -- first pursuer after a load). Do what that dialog does.
        TWDA.log("cornfield: meter still on with nobody in Bonnie's row (" .. tostring(rows.seen) .. "); switching it off")
        local okD, err = pcall(rawget(G, "Chapter4B_Cornfield_PursuerPanicMeter_Deactivate"))
        if not okD then TWDA.log("cornfield: " .. tostring(err)) end
      else
        TWDA.log("cornfield: still in a pursuer's row")
        lastWarnAt = now
        TWDA.say(warning("Still in someone's row!"), { interrupt = true })
      end
    end
  end
end)

TWDA.onFrame("cornfield", function()
  local on = active()
  rows(on)
  if not on then
    if not danger then warnAt = nil end
    return
  end
  if not told then
    told = true
    TWDA.say("Cornfield. Hold W to run. When someone comes down your row, Left or Right arrow to change rows. "
      .. "Down arrow looks back.")
  end
  if warnAt and TWDA.now() >= warnAt then
    warnAt, lastWarnAt = nil, TWDA.now()
    TWDA.say(warning("Someone is coming down this row!"), { interrupt = true })
  end
end)

-- The rebar, to free before the figure behind the tractor reaches Bonnie: after Enter on it
-- ("Rebar: Pull Out") mode_drag_rebarchoice.imap takes Left or Right for about 1.7 seconds, the way
-- to pull first (Chapter4B_Cornfield_RebarDragStart_OnLeft/Right); there too the keys did not get
-- through. Then come the pulls themselves (drag.lua).
local REBAR_MAP = "mode_drag_rebarchoice.imap"
local function rebarChosen()
  return TWDA.upvalue(rawget(G, "Chapter4B_Cornfield_RebarDragStart_OnLeft"), "mGotADirForRebarDrag") == true
end
local rebar = forwarder("rebar", {
  [VK_LEFT] = "Chapter4B_Cornfield_RebarDragStart_OnLeft", [VK_A] = "Chapter4B_Cornfield_RebarDragStart_OnLeft",
  [VK_RIGHT] = "Chapter4B_Cornfield_RebarDragStart_OnRight", [VK_D] = "Chapter4B_Cornfield_RebarDragStart_OnRight",
}, rebarChosen)
local rebarTold = false
TWDA.onFrame("rebar", function()
  local ok, on = pcall(InputMapperIsActive, REBAR_MAP)
  on = ok and on == true and type(rawget(G, "Chapter4B_Cornfield_RebarDragStart_OnLeft")) == "function"
  rebar(on)
  if not on then
    rebarTold = false
    return
  end
  if not rebarTold and not rebarChosen() then
    rebarTold = true
    TWDA.log("rebar: choose a way")
    TWDA.say("Grab it: Left or Right arrow, quickly.", { interrupt = true })
  end
end)

-- For F6.
function TWDA.describeCornfield()
  if not active() then return nil end
  return danger and warning("Someone is coming down this row.")
    or "Cornfield. Hold W to run; Left or Right arrow change rows when someone comes"
end
