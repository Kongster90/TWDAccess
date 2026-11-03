-- TWD Access: screen reader support for The Walking Dead: The Telltale Definitive Series.
-- Loaded by the bootstrap (Archives\DebugLoader.lua) once per game script state.
-- Everything here is plain Lua 5.2 running inside the game; speech goes to the TWD Access helper
-- program over the engine's HTTP functions, and the helper speaks it through Prism.

local MOD_DIR = ... or "TWDAccess/"
local G = _G
if rawget(G, "TWDA") then return end

local TWDA = { dir = MOD_DIR, version = "1.2.0" }
rawset(G, "TWDA", TWDA)

-- Loads MOD_DIR/<name>.lua and returns true plus the module's result, or false plus an error
-- message. (Some game states replace error() with a version that does not stop execution, so the
-- mod never relies on it.)
function TWDA.include(name)
  local path = MOD_DIR .. name .. ".lua"
  local file, openErr = io.open(path, "rb")
  if not file then return false, "cannot open " .. path .. ": " .. tostring(openErr) end
  local source = file:read("*a")
  file:close()
  local chunk, loadErr = load(source, "@" .. path, "t")
  if not chunk then return false, loadErr end
  return pcall(chunk, TWDA)
end

-- Loads a module, logging instead of failing so one broken feature cannot take the others down.
function TWDA.safeInclude(name)
  local ok, result = TWDA.include(name)
  if not ok then
    if TWDA.log then TWDA.log("module " .. name .. " failed: " .. tostring(result)) end
    return nil
  end
  return result
end

local coreOk, coreErr = TWDA.include("core")
if not coreOk then
  pcall(HttpGetAsync, "http://127.0.0.1:41234/log?t=" .. tostring(coreErr):gsub("[^%w]", "+"))
  return
end
TWDA.log(("TWD Access %s starting (Lua state %s)"):format(TWDA.version, tostring(G)))

TWDA.safeInclude("settings")
TWDA.safeInclude("text")
TWDA.safeInclude("hooks")
TWDA.safeInclude("carryover")
TWDA.safeInclude("uitext")
TWDA.safeInclude("menus")
TWDA.safeInclude("panes")
TWDA.safeInclude("messagebox")
TWDA.safeInclude("prompts")
TWDA.safeInclude("prompts2")
TWDA.safeInclude("choices")
TWDA.safeInclude("choices2")
TWDA.safeInclude("lookaround")
TWDA.safeInclude("lookaround2")
TWDA.safeInclude("lookaround4")
TWDA.safeInclude("actions")
TWDA.safeInclude("action2")
TWDA.safeInclude("qte3")
TWDA.safeInclude("configurator")
TWDA.safeInclude("aiming")
TWDA.safeInclude("sniper")
TWDA.safeInclude("struggle")
TWDA.safeInclude("combat4")
TWDA.safeInclude("shooter4")
TWDA.safeInclude("sounds")
TWDA.safeInclude("bow4")
TWDA.safeInclude("stars4")
TWDA.safeInclude("searchlight4")
TWDA.safeInclude("michonne")
TWDA.safeInclude("beacons")
TWDA.safeInclude("turnchoice")
TWDA.safeInclude("inventory")
TWDA.safeInclude("peek")
TWDA.safeInclude("guided")
TWDA.safeInclude("runto")
TWDA.safeInclude("cornfield")
TWDA.safeInclude("drag")
TWDA.safeInclude("drag2")
TWDA.safeInclude("drag3")
TWDA.safeInclude("fastslow")
TWDA.safeInclude("cover")
TWDA.safeInclude("readables")
TWDA.safeInclude("panels")
TWDA.safeInclude("subtitles")
TWDA.safeInclude("hotkeys")
if TWDA.settings and TWDA.settings.discovery then
  TWDA.safeInclude("discovery")
end
if TWDA.settings and TWDA.settings.devconsole then
  TWDA.safeInclude("devconsole")
end

TWDA.start()
