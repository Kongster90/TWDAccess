-- Dev console: list the bindings of the input map named IMAP (key code = callback).
local map = rawget(_G, "IMAP")
local binds = {}
for i = 0, InputMapperGetNumEvents(map) do
  local okI, input = pcall(InputMapperGetInput, map, i)
  local okC, cb = pcall(InputMapperGetCallback, map, i)
  if okI and input then binds[#binds + 1] = tostring(input) .. "=" .. tostring(okC and cb) end
end
return map .. ": " .. table.concat(binds, " ")
