-- Offline test of lookaround.lua (no game needed): stand-ins for the engine, then the open doorway
-- (the Macon pharmacy door), the "out of reach" / "in another area" / "blocked" tags and when they
-- clear. Run: python tools/dev/offline_lookaround.py [folder holding lupa]
local SRC = ...
local clock = 100
local said, logs = {}, {}
local hooksBefore, frames = {}, {}
local UPV = {}
local KEYS = {}

local TWDA = {}
TWDA.now = function() return clock end
TWDA.say = function(text) said[#said + 1] = text; print("SAY  " .. text) end
TWDA.log = function(text) logs[#logs + 1] = text; print("LOG  " .. text) end
TWDA.trace = function() end
TWDA.upvalue = function(fn, name) return UPV[name] end
TWDA.agentName = function(a) return type(a) == "table" and a.name or "" end
TWDA.player = function() return PLAYER end
TWDA.playerScene = function() return "scene" end
TWDA.playerName = function() return "Lee" end
TWDA.hookBefore = function(name, fn) hooksBefore[name] = hooksBefore[name] or {}; table.insert(hooksBefore[name], fn) end
TWDA.hookAfter = function() end
TWDA.onFrame = function(name, fn) frames[name] = fn end
TWDA.settings = {}
TWDA.isEnglish = function() return true end
TWDA.lower = string.lower
TWDA.englishVerb = function(v) return tostring(v) end
TWDA.cleanText = function(t) return t end
TWDA.keyOrText = function(t) return t end
TWDA.noteVerbIcon = function() end
TWDA.noteVerb = function() end
TWDA.joinSentences = function(parts) return table.concat(parts, ". ") end
TWDA.hotspotWordsExtra = nil

-- Engine stand-ins.
function Vector(x, y, z) return { x = x, y = y, z = z } end
function VectorDistance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
function AgentGetWorldPos(a) assert(type(a) == "table" and a.pos, "no agent") return Vector(a.pos.x, a.pos.y, a.pos.z) end
function AgentGetScreenPos(a) return { x = 0.5 + a.pos.x * 0.05, y = 0.5 + a.pos.z * 0.05, z = 1 } end
function AgentGetLogicalScreenPos(a) return AgentGetScreenPos(a) end
function AgentAtScreenPos() return nil end
function AgentIsHidden(a) return a.hidden == true end
function AgentGetProperty(a, name) return a.mProps and a.mProps[name] end
function AgentGetScene() return "scene" end
function AgentGetName(a) return a.name end
function AgentHasNode() return false end
function SceneGetAgents() return {} end
function SceneGetBottomScene() return "scene" end
function SceneGetSceneAgent() return { mProps = {} } end
function SceneGetCamera() return "cam" end
function SceneIsHidden() return true end
function CameraGetScreenPosFromWorldPos(cam, p) return { x = 0.5 + p.x * 0.05, y = 0.5 + p.z * 0.05 } end
function InputMapperIsActive(name) return name == "Navigate.imap" end
function InputPCIsVKeyPressed(vk) return KEYS[vk] == true end
function CursorGetDevicePos() return { x = 0, y = 0 } end
local pathTo = nil -- function(goal) -> new player position
local pathOk = true -- what AgentPathToAgent returns (false: the walk ended short)
function AgentPathToAgent(p, a) local to = pathTo and pathTo(a.pos) or a.pos; PLAYER.pos = Vector(to.x, to.y, to.z); return pathOk end
function AgentPathToPosition(p, pos) PLAYER.pos = Vector(pos.x, pos.y, pos.z); WALKED_TO = pos; return true end
function ThreadStart(fn) fn() end
function PathAgentIsBlocked() return false end
function PathAgentStop() end
function PathAgentGetWalkBoxes() return "wb" end
function WalkBoxesPosOnWalkBoxes(p) return Vector(p.x, p.y, p.z) end
function Reticle_Update() end
function Reticle_UpdateActionIcons() end
function Reticle_GetAgentFocused() return nil end
function ReticleUI_IsEnabled() return true end
function ReticleUI_InCombatMode() return false end
function Platform_IsBimodal() return false end
function Mode_GetCurrent() return { name = "Reticle" } end
function WDBackButton_IsOccupied() return false end
function ReticleController_SetScreenPos() end
function Dialog_GetText(noun) return noun end
function DialogManager_ItemIsValid() return true end
function DlgEvaluateToNode() return nil end
local RETICLE_CAM = { name = "reticleCamV", mProps = { ["Pan Cam - Horiztonal Max Percentage Allowed"] = 0.7 } }
function CameraControlReticle_GetCamera() return RETICLE_CAM end
function Main_OnUse() end
function PathToAndUseAgent() end
Logic = {}

local function agent(name, x, z, label, extra)
  local a = { name = name, pos = Vector(x, 0, z), mProps = { ["Game Selectable"] = true, ["WDUseable - Name"] = label,
    ["WDUseable - Verb"] = "Look At", ["WDUseable - Action Use Dialog Start Node"] = "use_" .. name } }
  for k, v in pairs(extra or {}) do a[k] = v end
  return a
end
PLAYER = { name = "Lee", pos = Vector(0, 0, 0) }
local door = agent("obj_doorPharmacy", 0, -1, "Door to Pharmacy", { clickable = true })
local lilly = agent("Lilly", 1, 0, "Lilly", { clickable = false })
UPV.mUseables = { door, lilly }
UPV.mbReticleSystemActive = true
UPV.kUseName = "WDUseable - Name"
UPV.kVerb = "WDUseable - Verb"
UPV.agentIsClickableNoDialog = function(a) return a.clickable == true end
UPV.CachedUseableQueue_GetCached = function() end
UPV.agentIsClickableDialogOnly = function() end
UPV.kUseDialog = "WDUseable - Action Use Dialog Start Node"
UPV.findDialogWithNode = function(a) if a.otherArea then return nil end return "dlog" end

local mod = assert(load(SRC, "@lookaround.lua"))
mod(TWDA)

local function frame(seconds)
  local stop = clock + (seconds or 0.05)
  repeat
    clock = clock + 0.05
    frames.lookaround()
  until clock >= stop
end
local function press(vk)
  KEYS[vk] = true; frame(0.05); KEYS[vk] = false; frame(0.05)
end
local function check(cond, what)
  print((cond and "PASS " or "FAIL ") .. what)
  if not cond then FAILED = (FAILED or 0) + 1 end
end
local function lastSaid() return said[#said] or "" end

print("== pharmacy doorway")
frame(1)
for _, fn in ipairs(hooksBefore.Main_OnUse) do fn(door) end
frame(0.5)
check(not lastSaid():find("is open"), "nothing said while the door is still on offer")
door.mProps["Game Selectable"] = false
door.clickable = false
frame(2)
check(lastSaid() == "Door to Pharmacy is open. Enter walks through it.", "announced: " .. lastSaid())
local found = nil
for _, e in ipairs(TWDA.hotspots()) do if e.place and e.name:find("^doorway:") then found = e end end
check(found ~= nil, "the open doorway is on the Tab list")
print("F6: " .. tostring(TWDA.describeLookaround()))
press(0x0D)
check(said[#said - 1] == "Walking to Open doorway." or lastSaid():find("Through the doorway"), "Enter walks: " .. table.concat(said, " | ", math.max(1, #said - 1)))
check(WALKED_TO and math.abs(WALKED_TO.z + 3.5) < 0.01, "walked to the point past the door: " .. tostring(WALKED_TO and WALKED_TO.z))
frame(0.5)
check(lastSaid():find("^Through the doorway%. If nothing happens, walk on a little with W%.") ~= nil, "arrival: " .. lastSaid())
local still = false
for _, e in ipairs(TWDA.hotspots()) do if e.name:find("^doorway:") then still = true end end
check(not still, "no doorway on the list once through")

print("== Tab tags")
PLAYER.pos = Vector(0, 0, 0)
local toolbox = agent("obj_toolbox", 20, 0, "Toolbox", { clickable = false })
local gate = agent("obj_gate", 11, 0, "Gate", { clickable = false })
local gazebo = agent("obj_gazebo", -15, 0, "Gazebo", { clickable = false, otherArea = true })
UPV.mUseables = { toolbox, gate, gazebo }
frame(0.5)
press(0x09)
press(0x09)
press(0x09)
local tabs = {}
for i = math.max(1, #said - 2), #said do tabs[#tabs + 1] = said[i] end
local joined = table.concat(tabs, " | ")
check(joined:find("Toolbox, out of reach, to your right, 20 meters%. Enter walks there") ~= nil, "out of reach tag: " .. joined)
check(joined:find("Gazebo, in another area, to your left, 15 meters") ~= nil, "another area tag")
-- A walk to the toolbox that stops at the gate.
pathTo = function(goal) return Vector(10, 0, 0) end
local idx = nil
for i, e in ipairs(TWDA.hotspots()) do if e.name == "obj_toolbox" then idx = i end end
-- Tab until the toolbox, then Enter.
for _ = 1, 3 do
  press(0x09)
  if lastSaid():find("^Toolbox") then break end
end
press(0x0D)
frame(0.5)
check(lastSaid():find("can go no further this way") ~= nil, "walk stopped: " .. lastSaid())
local list = TWDA.hotspots()
check(list[#list].name == "obj_toolbox", "blocked thing comes last: " .. list[#list].name)
for _ = 1, 3 do
  press(0x09)
  if lastSaid():find("^Toolbox") then break end
end
check(lastSaid():find("^Toolbox, blocked, the last walk stopped near Gate, to your right, 10 meters%. Enter walks there") ~= nil, "blocked tag: " .. lastSaid())
print("F6: " .. tostring(TWDA.describeLookaround()))
check(tostring(TWDA.describeLookaround()):find("Toolbox %(blocked, the last walk stopped near Gate") ~= nil, "F6 blocked tag")
check(tostring(TWDA.describeLookaround()):find("Gazebo %(in another area") ~= nil, "F6 another-area tag")
-- Using something clears it.
for _, fn in ipairs(hooksBefore.Main_OnUse) do fn(gate) end
frame(0.2)
list = TWDA.hotspots()
local tagged = tostring(TWDA.describeLookaround()):find("blocked") ~= nil
check(not tagged, "a use clears blocked")
-- Walking 10 m away clears it too.
pathTo = function(goal) return Vector(10, 0, 0) end
PLAYER.pos = Vector(0, 0, 0)
frame(0.2)
for _ = 1, 3 do press(0x09) if lastSaid():find("^Toolbox") then break end end
press(0x0D)
frame(0.5)
check(tostring(TWDA.describeLookaround()):find("blocked") ~= nil, "blocked again after another short walk")
PLAYER.pos = Vector(-5, 0, 0)
frame(0.2)
check(tostring(TWDA.describeLookaround()):find("blocked") == nil, "cleared 15 m from where Lee stopped")

print("== a door opened with a line after it is not announced")
door = agent("obj_doorBedroom", 0, -1, "Door", { clickable = true })
UPV.mUseables = { door, lilly }
PLAYER.pos = Vector(0, 0, 0)
local before = #said
for _, fn in ipairs(hooksBefore.Main_OnUse) do fn(door) end
TWDA.onSubtitle.lookaroundDoor("Lee", "Oh my God")
door.mProps["Game Selectable"] = false
door.clickable = false
frame(2)
local any = false
for i = before + 1, #said do if said[i]:find("is open") then any = true end end
check(not any, "not announced after a line")
found = nil
for _, e in ipairs(TWDA.hotspots()) do if e.name:find("^doorway:") then found = e end end
check(found ~= nil, "still on the Tab list")

print("== people and things close by are never 'in another area'")
local lilly2 = agent("Lilly", 0, -1, "Lilly", { clickable = false, otherArea = true })
UPV.mUseables = { lilly2 }
PLAYER.pos = Vector(0, 0, 0)
frame(0.2)
press(0x09)
check(lastSaid():find("^Lilly, out of reach") ~= nil, "Lilly: " .. lastSaid())

print("== the dairy porch steps, only while up on the porch")
TWDA_firstScript = "env_dairyExteriorDay.lua"
local steps = { name = "trigger_dialog_exitPorch", pos = Vector(3, 3.9, 0), mProps = { ["Trigger Enabled"] = true } }
function AgentFind(name) if name == steps.name then return steps end return nil end
UPV.mUseables = { agent("obj_plantsDairyExterior", -2, 0, "Plants", { clickable = true }) }
PLAYER.pos = Vector(0, 3.9, 0)
frame(0.2)
local onPorch = false
for _, e in ipairs(TWDA.hotspots()) do if e.name == steps.name then onPorch = true end end
check(onPorch, "porch steps offered on the porch")
PLAYER.pos = Vector(0, 0, 0)
frame(0.2)
local inYard = false
for _, e in ipairs(TWDA.hotspots()) do if e.name == steps.name then inYard = true end end
check(not inYard, "porch steps not offered down in the yard")
TWDA_firstScript = nil

print("== a walk taken over with a movement key is not 'no way' (a player's log, 2026-11-05)")
PLAYER.pos = Vector(0, 0, 0)
UPV.mUseables = { agent("obj_PoolCover", 12, 0, "Pool Cover", { clickable = false }),
  agent("obj_Treehouse", -10, 0, "Treehouse", { clickable = false }) }
local function listed(name)
  for _, e in ipairs(TWDA.hotspots()) do if e.name == name then return true end end
  return false
end
local function tabTo(prefix)
  for _ = 1, 4 do
    press(0x09)
    if lastSaid():find("^" .. prefix) then return true end
  end
  return false
end
-- An arrow key a moment into the walk: the game ends it with Lee hardly moved.
pathTo, pathOk = function() return Vector(0.3, 0, 0) end, false
frame(0.2)
check(tabTo("Pool Cover"), "Tab to the Pool Cover")
KEYS[0x0D] = true; frame(0.05); KEYS[0x0D] = false
KEYS[0x25] = true; frame(0.05); KEYS[0x25] = false
frame(0.5)
check(lastSaid() == "Walking to Pool Cover.", "nothing said after the walk was taken over: " .. lastSaid())
check(listed("obj_PoolCover"), "the Pool Cover is still on the Tab list")
check(tostring(TWDA.describeLookaround()):find("blocked") == nil, "not tagged blocked")
-- The same failed walk with no key down is still no way there.
PLAYER.pos = Vector(0, 0, 0)
check(tabTo("Pool Cover"), "Tab to the Pool Cover again")
press(0x0D)
frame(0.5)
check(lastSaid() == "There is no way to Pool Cover from here.", "no key: " .. lastSaid())
check(not listed("obj_PoolCover"), "then it leaves the list")
pathTo, pathOk = nil, true

print(FAILED and ("FAILED " .. FAILED) or "ALL PASSED")
