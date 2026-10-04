-- TWD Access bootstrap: screen reader support for The Walking Dead: The Telltale Definitive Series.
--
-- Installed as Archives\DebugLoader.lua in the game's script format. It is reached two ways:
--
-- 1. The title screen and the main menu contain a developer hook,
--        if ResourceExists("DebugLoader.lua") then require("DebugLoader.lua") ... end
--    so the game loads this file by itself; no game file is replaced.
-- 2. When the game throws its scripts away to load a season or episode, the mod (see
--    TWDAccess\carryover.lua) asks for this file to be run first in the new state and leaves the
--    game's real first script in TWDAccess\next_script.txt; we start the mod and then run it.
-- 3. Saves remember a state's first script, which for states started that way is this file, so
--    loading a save runs us with no note; we then work out the real first script (see below).
--
-- The mod itself is plain-text Lua in the TWDAccess folder next to WDC.exe (the game's working
-- directory). Deleting this file and that folder removes the mod completely.
--
-- Note: some game states replace error() with a version that does not stop execution, so this file
-- never relies on it.

local G = _G
local BASE = "http://127.0.0.1:41234"
local MOD_DIR = "TWDAccess/"

local function report(message)
  pcall(function()
    local text = tostring(message):gsub("[^%w%-%._~ ]", function(c) return string.format("%%%02X", c:byte()) end)
    HttpGetAsync(BASE .. "/log?t=" .. text:gsub(" ", "%%20"))
  end)
end

local function loadedByRequire()
  for level = 2, 5 do
    local okInfo, info = pcall(debug.getinfo, level, "n")
    if not okInfo or not info then break end
    if info.name == "require" or info.name == "realRequire" then return true end
  end
  return false
end
local viaRequire = loadedByRequire()

-- The real first script of this state, if an engine reset left us a fresh note. The note is always
-- removed, so a stale one (say, after a crash) can never run somewhere it does not belong.
local nextScript
pcall(function()
  local path = MOD_DIR .. "next_script.txt"
  local file = io.open(path, "rb")
  if not file then return end
  local content = file:read("*a")
  file:close()
  os.remove(path)
  local stamp, script = content:match("^(%d+)\t([^\r\n]+)")
  if stamp and os.time() - tonumber(stamp) <= 120 and not viaRequire then nextScript = script end
end)

-- No note, yet we are this state's first script: it was started from a save. The engine keeps the
-- name of the state's first script in saves, and in a state started through the mod that name is
-- ours, so loading such a save runs us. Work out what the game itself would have run: the script
-- the mod noted for this save slot when the game saved (TWDAccess\saves.txt), else the stored name
-- if it is not ours, else the episode's first script.
local recovered = nil
local function call(name, ...)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return nil end
  local okCall, result = pcall(fn, ...)
  if okCall then return result end
  return nil
end
local function slotScript()
  local slot = call("SaveSlots_GetSlot") or call("SaveLoad_GetSlot")
  if slot == nil then
    local prefs = call("GetPreferences")
    if prefs then pcall(function() slot = prefs["Save - Slot"] end) end
  end
  if slot == nil then return nil end
  local file = io.open(MOD_DIR .. "saves.txt", "rb")
  if not file then return nil end
  local found
  for line in file:lines() do
    local s, script = line:match("^([^\t]+)\t([^\r\n]+)")
    if s == tostring(slot) then found = script end
  end
  file:close()
  return found
end
if not nextScript and not viaRequire then
  pcall(function()
    nextScript = slotScript()
    if nextScript then recovered = "the save slot's record" return end
    local current = call("ScriptManagerGetCurrentScriptName")
    if type(current) == "string" and current ~= "" and current:lower() ~= "debugloader.lua" then
      nextScript, recovered = current, "the save"
      return
    end
    local episodeScript = call("SubProject_GetEpisodeFirstScript")
    if type(episodeScript) == "string" and episodeScript ~= "" then
      nextScript, recovered = episodeScript, "the episode's first script"
    end
  end)
  if not nextScript then report("bootstrap: started as a first script with nothing to hand over to") end
end

-- Only the developer hook needs these. Because DebugLoader.lua now "exists", the menu script goes on to
--   require("MenuBootUtils.lua")                  a developer script that expects the real debug
--                                                 loader, so it must never actually load; and
--   Callback_OnLoadDebugMenu:Add(OpenDebugMenu)   which needs that callback object to exist.
-- OpenDebugMenu disables input and then calls MenuBoot_CreateDebugMenu, so our stand-in for that
-- turns input back on in case it is ever reached.
if viaRequire then
  local ok, err = pcall(function()
    local realRequire = rawget(G, "require")
    if type(realRequire) == "function" and rawget(G, "TWDA_requireShim") ~= realRequire then
      local shim = function(name, ...)
        if name == "MenuBootUtils.lua" then
          if rawget(G, "MenuBoot_CreateDebugMenu") == nil then
            rawset(G, "MenuBoot_CreateDebugMenu", function()
              local enable = rawget(G, "WidgetInputHandler_EnableInput")
              if enable then enable(true) end
            end)
          end
          return true
        end
        return realRequire(name, ...)
      end
      rawset(G, "require", shim)
      rawset(G, "TWDA_requireShim", shim)
    end
    if rawget(G, "Callback_OnLoadDebugMenu") == nil then
      -- Same interface as the game's callback objects (Add, Exists, Remove, Run); never fires.
      local stub = {}
      function stub:Add() end
      function stub:Remove() end
      function stub:Exists() return false end
      function stub:Run() end
      rawset(G, "Callback_OnLoadDebugMenu", stub)
    end
  end)
  if not ok then report("bootstrap shims failed: " .. tostring(err)) end
end

-- The mod records which save belongs to which real first script (see carryover.lua).
if nextScript then rawset(G, "TWDA_firstScript", nextScript) end

-- Run the mod. main.lua guards itself, so it runs once per script state.
local ok, err = pcall(function()
  local path = MOD_DIR .. "main.lua"
  local file, openErr = io.open(path, "rb")
  if not file then return "cannot open " .. path .. ": " .. tostring(openErr) end
  local source = file:read("*a")
  file:close()
  local chunk, loadErr = load(source, "@" .. path, "t")
  if not chunk then return loadErr end
  chunk(MOD_DIR)
end)
if not ok or err then report("TWD Access failed to start: " .. tostring(err)) end

-- Hand over to the script the game meant to run. The game's loadfile() loads a script resource by
-- name, so the real first script runs right here, in this same top-level script thread and with the
-- same arguments, exactly as if the engine had started it. (Queuing it with LoadScript instead
-- leaves season loading stuck.) It is called outside any pcall so its errors and waits behave as
-- they normally would.
if nextScript then
  local twda = rawget(G, "TWDA")
  local chunk = loadfile(nextScript)
  if twda and twda.log then
    twda.log("bootstrap: running the game's first script " .. nextScript
      .. (recovered and (" (loading a save; from " .. recovered .. ")") or "")
      .. (chunk and "" or " (loadfile failed, using LoadScript)"))
    twda.flushLog()
  end
  if chunk then
    return chunk(...)
  end
  -- The mod's own LoadScript hook would send us straight back here.
  local loadScript = twda and twda.originalOf and twda.originalOf("LoadScript") or LoadScript
  loadScript(nextScript)
end
