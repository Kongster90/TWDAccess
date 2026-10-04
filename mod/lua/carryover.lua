-- Keeps the mod running when the game starts a new script state.
--
-- The game throws every script away (ours included) and starts a new state with a given first
-- script when it switches between the hub, a season's menu and its episodes (SubProject_ResetEngine,
-- ResetGame, ResetEngine), and in Season 1 also between the scenes of an episode (LoadScript). We
-- pass our bootstrap (Archives\DebugLoader.lua) as the first script instead and leave the real one
-- in TWDAccess\next_script.txt; the bootstrap starts the mod again and then runs the real script,
-- exactly as the game would have. If writing the note fails, nothing is substituted.
--
-- Saves remember a state's first script, which for the states we start is the bootstrap, so when a
-- save is loaded the bootstrap has to work out the real one. Each save slot holds one save; when the
-- game saves inside an episode, the slot's real first script is written to TWDAccess\saves.txt
-- (lines of "slot<TAB>script"), and the bootstrap reads it back for the slot being loaded.
local TWDA = ...
local G = _G

local BOOTSTRAP = "DebugLoader.lua"
local NOTE = TWDA.dir .. "next_script.txt"
local SAVES = TWDA.dir .. "saves.txt"

local function describeArgs(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  return table.concat(parts, ", ")
end

local function withExtension(script)
  if type(script) ~= "string" or script == "" then return script end
  if script:lower():sub(-4) == ".lua" then return script end
  return script .. ".lua"
end

---------------------------------------------------------------------------------------------------
-- Which real first script each save slot's save belongs to.
---------------------------------------------------------------------------------------------------

local function currentSlot()
  for _, name in ipairs({ "SaveSlots_GetSlot", "SaveLoad_GetSlot" }) do
    local fn = rawget(G, name)
    if type(fn) == "function" then
      local ok, slot = pcall(fn)
      if ok and slot ~= nil then return tostring(slot) end
    end
  end
  local fn = rawget(G, "GetPreferences")
  if type(fn) == "function" then
    local ok, slot = pcall(function() return fn()["Save - Slot"] end)
    if ok and slot ~= nil then return tostring(slot) end
  end
  return nil
end

local function readSaves()
  local slots, order = {}, {}
  local file = io.open(SAVES, "rb")
  if file then
    for line in file:lines() do
      local slot, script = line:match("^([^\t]+)\t([^\r\n]+)")
      if slot then
        if not slots[slot] then order[#order + 1] = slot end
        slots[slot] = script
      end
    end
    file:close()
  end
  return slots, order
end

local function writeSaves(slots, order)
  local out = io.open(SAVES, "wb")
  if not out then return end
  for _, slot in ipairs(order) do
    if slots[slot] then out:write(slot, "\t", slots[slot], "\n") end
  end
  out:close()
end

local function setSlot(slot, script, via)
  if slot == nil then return end
  slot = tostring(slot)
  local slots, order = readSaves()
  if slots[slot] == script then return end
  if not slots[slot] then order[#order + 1] = slot end
  slots[slot] = script
  writeSaves(slots, order)
  TWDA.log(("%s: save slot %s -> %s"):format(via, slot, tostring(script)))
end

local function getSlot(slot)
  if slot == nil then return nil end
  return (readSaves())[tostring(slot)]
end

-- The menus' own first scripts never belong to a save.
local function isEpisodeScript(script)
  local l = type(script) == "string" and script:lower() or ""
  return l ~= "" and not l:find("^start_") and not l:find("menu", 1, true) and not l:find("boot", 1, true)
end

local function recordSave(via)
  local script = rawget(G, "TWDA_firstScript")
  if isEpisodeScript(script) then setSlot(currentSlot(), script, via) end
end

for _, name in ipairs({ "SaveGame", "SaveGameIncremental", "SaveLoad_AutoSave", "SaveSlots_Save" }) do
  TWDA.hookBefore(name, function()
    recordSave(name)
  end)
end

-- Copying and deleting slots in Season 1's Save Slots menu.
TWDA.hookBefore("SaveSlots_DoCopyForReal", function()
  local from, to = rawget(G, "mCopySlot"), rawget(G, "mCurrentSlot")
  if from ~= nil and to ~= nil then setSlot(to, getSlot(from), "copy") end
end)
for _, name in ipairs({ "SaveSlots_Delete", "SaveLoad_DeleteSlot" }) do
  TWDA.hookBefore(name, function(slot)
    if type(slot) == "number" or type(slot) == "string" then setSlot(slot, nil, name) end
  end)
end

---------------------------------------------------------------------------------------------------
-- The redirect.
---------------------------------------------------------------------------------------------------

-- Returns true if the note was written and the bootstrap should be substituted.
local function leaveNote(script, via)
  script = withExtension(script)
  if type(script) ~= "string" or script == "" or script:lower() == BOOTSTRAP:lower() then return false end
  local file = io.open(NOTE, "wb")
  if not file then return false end
  file:write(("%d\t%s\n"):format(os.time(), script))
  file:close()
  TWDA.log(("%s: next state starts with %s (real first script %s)"):format(via, BOOTSTRAP, script))
  TWDA.flushLog()
  return true
end

-- Leaving a menu for an episode starts it afresh; the slot's old record no longer applies.
local function fromMenu(script)
  if isEpisodeScript(script) and not isEpisodeScript(rawget(G, "TWDA_firstScript")) then
    setSlot(currentSlot(), nil, "new episode")
  end
end

TWDA.hookGlobal("SubProject_ResetEngine", function(original)
  return function(projectName, firstScript, ...)
    local script = firstScript
    if script == nil or script == "" then
      local ok, configured = pcall(SubProject_GetStartScript, projectName)
      script = ok and configured or nil
    end
    local ok, substitute = pcall(leaveNote, script, "SubProject_ResetEngine(" .. tostring(projectName) .. ")")
    if ok and substitute then
      return original(projectName, BOOTSTRAP, ...)
    end
    return original(projectName, firstScript, ...)
  end
end)

TWDA.hookGlobal("ResetGame", function(original)
  return function(firstScript, ...)
    pcall(fromMenu, withExtension(firstScript))
    local ok, substitute = pcall(leaveNote, firstScript, "ResetGame")
    if ok and substitute then
      return original(BOOTSTRAP, ...)
    end
    return original(firstScript, ...)
  end
end)

-- The engine's other reset; redirected the same way if its first argument names a script.
TWDA.hookGlobal("ResetEngine", function(original)
  return function(firstScript, ...)
    TWDA.log("ResetEngine(" .. describeArgs(firstScript, ...) .. ")")
    TWDA.flushLog()
    if type(firstScript) == "string" and firstScript:lower():find("%.lua$") then
      local ok, substitute = pcall(leaveNote, firstScript, "ResetEngine")
      if ok and substitute then
        return original(BOOTSTRAP, ...)
      end
    end
    return original(firstScript, ...)
  end
end)

-- Season 1 moves from one scene of an episode to the next with LoadScript(script), which runs that
-- script in a new state (after the car crash: LoadScript("env_woodsClementine.lua")).
TWDA.hookGlobal("LoadScript", function(original)
  return function(script, ...)
    local ok, substitute = pcall(leaveNote, script, "LoadScript")
    if ok and substitute then
      return original(BOOTSTRAP, ...)
    end
    return original(script, ...)
  end
end)
