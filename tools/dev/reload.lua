-- Hot reload for development: re-runs the listed modules in the running game and drops the frame
-- callbacks they replaced. Copy the rebuilt files from build\mod\TWDAccess into <game>\TWDAccess
-- first, then: .\console.ps1 -File reload.lua -WaitMs 3000
-- Only for modules that work by polling (panes, messagebox, hotkeys). Modules that hook game
-- functions (menus, choices, uitext, subtitles) would hook twice; use restart.ps1 for those.
local modules = { "panes", "messagebox", "hotkeys" }
local callbacks = TWDA.upvalue(TWDA.onFrame, "frameCallbacks")
for _, name in ipairs(modules) do TWDA.safeInclude(name) end
local last = {}
for i, entry in ipairs(callbacks) do last[entry.name] = i end
for i = #callbacks, 1, -1 do
  if last[callbacks[i].name] ~= i then table.remove(callbacks, i) end
end
local names = {}
for _, entry in ipairs(callbacks) do names[#names + 1] = entry.name end
return table.concat(names, ",")
