-- Development: for WATCH_MAPS_SECONDS (default 90), log (WM lines) each change in the active input
-- maps, with the bindings of every map not seen before (key code = callback), and the mode.
--   .\console.ps1 -File watch_maps.lua
local seconds = rawget(_G, "WATCH_MAPS_SECONDS") or 90
ThreadStart(function()
  local t0, last, seen = TWDA.now(), "", {}
  while TWDA.now() - t0 < seconds do
    local ok, err = pcall(function()
      local maps = InputMapperGetActiveMapperNames() or {}
      local s = table.concat(maps, ",")
      if s ~= last then
        last = s
        local mode = rawget(_G, "Mode_GetCurrent") and Mode_GetCurrent()
        TWDA.log(("WM %.1f %s | %s"):format(TWDA.now() - t0, s, tostring(mode and mode.name)))
        for _, map in ipairs(maps) do
          if not seen[map] then
            seen[map] = true
            local binds = {}
            for i = 0, InputMapperGetNumEvents(map) do
              local okI, input = pcall(InputMapperGetInput, map, i)
              local okC, cb = pcall(InputMapperGetCallback, map, i)
              if okI and input then binds[#binds + 1] = tostring(input) .. "=" .. tostring(okC and cb) end
            end
            TWDA.log("WM   " .. map .. ": " .. table.concat(binds, " "))
          end
        end
      end
    end)
    if not ok then TWDA.log("WM error " .. tostring(err)) return end
    WaitForNextFrame()
  end
end)
return "watching maps"
