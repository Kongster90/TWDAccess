-- Development: lists every loaded function that has an upvalue with the given name, walking globals,
-- global tables (one level) and functions reachable through upvalues. Set WANTED, then
-- .\console.ps1 -File tools\dev\find_upvalue.lua -WaitMs 4000
local WANTED = rawget(_G, "FIND_UPVALUE") or "mbPause"
local seen, found = {}, {}

local function visit(fn, path, depth)
  if type(fn) ~= "function" or seen[fn] or depth > 6 then return end
  seen[fn] = true
  for i = 1, 255 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == WANTED then
      local info = debug.getinfo(fn, "S")
      found[#found + 1] = path .. " @" .. info.short_src:match("[^/]*$") .. ":" .. info.linedefined
    end
    if type(value) == "function" then visit(value, path .. ">" .. name, depth + 1) end
  end
end

for k, v in pairs(_G) do
  if type(k) == "string" then
    if type(v) == "function" then
      visit(v, k, 0)
    elseif type(v) == "table" and k ~= "_G" then
      for k2, v2 in pairs(v) do
        if type(v2) == "function" then visit(v2, k .. "." .. tostring(k2), 0) end
      end
    end
  end
end
return #found .. ": " .. table.concat(found, " | ")
