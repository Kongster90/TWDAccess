-- Development: log ("SAVETRACE" lines in twda.log) every call to a global function whose name
-- looks like saving (Save, Checkpoint, Bundle, Autosave), to find which one the game uses when a
-- save is not recorded in saves.txt (the house in Savannah, Episode 4, 2026-10-09). Runs in the
-- current Lua state only; the next scene change starts a fresh one.
--   .\console.ps1 -File tools\dev\trace_saves.lua
local wrapped = {}
for name, fn in pairs(_G) do
  if type(name) == "string" and type(fn) == "function" and (name:find("Save") or name:find("Checkpoint")
    or name:find("Bundle") or name:lower():find("autosave")) and not name:find("^SAVETRACE") then
    rawset(_G, name, function(...)
      TWDA.log("SAVETRACE " .. name)
      TWDA.flushLog()
      return fn(...)
    end)
    wrapped[#wrapped + 1] = name
  end
end
table.sort(wrapped)
return #wrapped .. " wrapped: " .. table.concat(wrapped, " ")
