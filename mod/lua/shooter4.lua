-- Aiming in The Final Season's shooter stations (projectseason4's shooter.lua: spear fishing at the
-- river, Episode 1). The view turns with the mouse and the crosshair (the station's "crosshairs"
-- agent) stays in the middle; Shooter_OnFire (Enter, Shooter.imap) runs the hit dialog of whatever
-- target is under the crosshair (the station camera's target-to-dialog map, upvalue
-- kTargetDialogMap) or the miss dialog. Moving fish cannot be aimed at by ear, so the mod aims for
-- the player: Enter fires at the target nearest the middle of the view, through the same dialogs
-- the game would run, and a target coming into view is announced.
local TWDA = ...
local G = _G

local function up(name)
  return TWDA.upvalue(rawget(G, "Shooter_OnFire"), name)
end

local function prop(agent, key)
  local ok, value = pcall(AgentGetProperty, agent, key)
  if ok then return value end
  return nil
end

-- The targets in view: { name, dialog, distance from the middle of the screen }.
local function targets()
  local cam, kMap = up("mStationCam"), up("kTargetDialogMap")
  local list = {}
  if cam == nil or kMap == nil then return list end
  local map = prop(cam, kMap)
  local ok = pcall(function()
    for name, dialog in map:iterator() do
      local okA, agent = pcall(AgentFind, name)
      local okS, pos = pcall(AgentGetScreenPos, okA and agent or nil)
      -- (In front of the camera and near the view: a rabbit at the edge runs off before anyone could
      -- turn to it.)
      if okS and pos and (pos.z or 1) > 0 and pos.x > -0.5 and pos.x < 1.5 and pos.y > -0.5 and pos.y < 1.5
          and not AgentIsHidden(agent) then
        local dx, dy = pos.x - 0.5, pos.y - 0.5
        list[#list + 1] = { name = name, dialog = dialog, off = math.sqrt(dx * dx + dy * dy) }
      end
    end
  end)
  if not ok then return {} end
  table.sort(list, function(a, b) return a.off < b.off end)
  return list
end

local active = false
TWDA.hookAfter("Shooter_Enter", function()
  active = true
  TWDA.log("shooter4: station " .. TWDA.agentName(up("mStationCam") or {}))
  TWDA.say("Aiming. When a target is in view, Enter fires at it.")
end)
TWDA.hookAfter("Shooter_Exit", function()
  active = false
  TWDA.setSlowFor("shooter4", false)
end)

-- "Rabbit02" -> "Rabbit", "obj_fishKoi01" -> "Fish koi".
local function targetName(name)
  local words = name:gsub("^obj_", ""):gsub("%d+$", ""):gsub("([%l])(%u)", "%1 %2"):lower()
  return (words:gsub("^%l", string.upper))
end

-- A target coming into view is said ("Rabbit in view. Enter!"); slow mode slows the game while one
-- is up, auto mode fires.
local inView = 0
TWDA.onFrame("shooter4", function()
  if not active then return end
  local ok, mode = pcall(Game_GetMode)
  local station = ok and type(mode) == "table" and mode.name == "Station"
  local list = station and targets() or {}
  local setting = TWDA.settings.actionscenes or "slow"
  TWDA.setSlowFor("shooter4", setting == "slow" and #list > 0)
  if #list > 0 and inView == 0 then
    TWDA.log("shooter4: " .. list[1].name .. " in view")
    if setting == "auto" then
      pcall(ThreadStart, function() pcall(Shooter_OnFire, { code = 13, type = 0 }) end)
    else
      TWDA.say(targetName(list[1].name) .. " in view. Enter!", { interrupt = true })
    end
  end
  inView = #list
end)

-- What a hit on a target does in the game's own Shooter_OnFire, for a target the mod chose.
local function fireAt(target)
  local cam, kInputMap = up("mStationCam"), up("kInputMap")
  local kFire = up("kFireDialog")
  TWDA.log("shooter4: throwing at " .. target.name)
  pcall(InputMapperDeactivate, kInputMap)
  pcall(RenderDelay, 1)
  if target.dialog and target.dialog ~= "" then pcall(Game_RunSceneDialog, target.dialog, false) end
  local fire = kFire and prop(cam, kFire) or ""
  if fire ~= "" then pcall(Game_RunSceneDialog, fire) else pcall(WaitForNextFrame) end
  pcall(InputMapperActivate, kInputMap)
end

TWDA.hookGlobal("Shooter_OnFire", function(original)
  return function(event, ...)
    -- (A target already under the crosshair: the game's own throw.)
    local cross = up("mCrosshairs")
    local okC, under = pcall(function()
      return AgentAtScreenPos(AgentGetScreenPos(cross), true, AgentGetScene(up("mStationCam")))
    end)
    local list = targets()
    local onTarget = false
    for _, t in ipairs(list) do
      if okC and under ~= nil and TWDA.agentName(under) == t.name then onTarget = true end
    end
    if onTarget or #list == 0 then
      if #list == 0 then TWDA.say("Nothing to aim at in view.", { interrupt = true }) end
      return original(event, ...)
    end
    fireAt(list[1])
  end
end)

function TWDA.describeShooter()
  if not active then return nil end
  local n = #targets()
  return ("Aiming. %d %s in view. Enter fires at the nearest to the middle."):format(n, n == 1 and "target" or "targets")
end
