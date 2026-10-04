-- Development: find how the game leaves the current script state. Wraps every global function whose
-- name suggests a scene, level, episode or engine change and appends each call straight to
-- TWDAccess\trap.log (written immediately, since the state may vanish right after).
--   .\console.ps1 -File tools\dev\trap_transitions.lua -WaitMs 4000
local WORDS = { "reset", "restart", "switch", "scene", "load", "boot", "project", "engine", "episode",
  "chapter", "level", "script", "game", "checkpoint", "transition", "exit", "quit" }
local SKIP = { "^get", "^is", "^has", "get", "isloaded", "exists", "callback", "print", "^twda" }
local path = TWDA.dir .. "trap.log"

local function wanted(name)
  local l = name:lower()
  for _, pattern in ipairs(SKIP) do
    if l:find(pattern) then return false end
  end
  for _, word in ipairs(WORDS) do
    if l:find(word, 1, true) then return true end
  end
  return false
end

local function write(text)
  local f = io.open(path, "ab")
  if f then
    f:write(os.date("%H:%M:%S "), text, "\n")
    f:close()
  end
end

local count = 0
for name, fn in pairs(_G) do
  if type(name) == "string" and type(fn) == "function" and wanted(name) and not TWDA.wrappers[fn] then
    local original = fn
    local wrapper = function(...)
      local parts = {}
      for i = 1, math.min(select("#", ...), 4) do parts[#parts + 1] = tostring((select(i, ...))) end
      write(name .. "(" .. table.concat(parts, ", ") .. ")")
      return original(...)
    end
    TWDA.wrappers[wrapper] = true
    rawset(_G, name, wrapper)
    count = count + 1
  end
end
write("---- armed " .. count .. " functions")
return count
