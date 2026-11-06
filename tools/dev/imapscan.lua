-- Dev console (console.ps1 -File tools\dev\imapscan.lua): every input map of the current season
-- (ResourceGetNames("*.imap"), plus "x.imap" strings in the bytecode of loaded functions) and the
-- letter keys each binds. Used to choose the letters the tabkey setting refuses (settings.lua).
local names, seen, visited = {}, {}, {}
local function scanFn(f)
  if visited[f] then return end
  visited[f] = true
  local ok, s = pcall(string.dump, f)
  if ok and type(s) == "string" then
    for n in s:gmatch("[%w_%-]+%.imap") do
      if not seen[n:lower()] then seen[n:lower()] = true; names[#names + 1] = n end
    end
  end
  local i = 1
  while true do
    local okU, name, v = pcall(debug.getupvalue, f, i)
    if not okU or name == nil then break end
    if type(v) == "function" then scanFn(v) end
    i = i + 1
  end
end
local function walk(t, depth)
  if visited[t] or depth > 4 then return end
  visited[t] = true
  for _, v in pairs(t) do
    if type(v) == "function" then scanFn(v) elseif type(v) == "table" then walk(v, depth + 1) end
  end
end
walk(_G, 0)
pcall(walk, debug.getregistry(), 0)
local okR, res = pcall(ResourceGetNames, "*.imap")
local fromRes = 0
if okR and type(res) == "table" then
  for _, n in pairs(res) do
    n = tostring(n)
    fromRes = fromRes + 1
    if not seen[n:lower()] then seen[n:lower()] = true; names[#names + 1] = n end
  end
end
table.sort(names, function(a, b) return a:lower() < b:lower() end)
local out, all = {}, {}
for _, n in ipairs(names) do
  local okN, count = pcall(InputMapperGetNumEvents, n)
  local letters = {}
  if okN and type(count) == "number" then
    for i = 0, count do
      local okI, input = pcall(InputMapperGetInput, n, i)
      if okI and type(input) == "number" and input >= 65 and input <= 90 then
        local okC, cb = pcall(InputMapperGetCallback, n, i)
        letters[#letters + 1] = string.char(input) .. "=" .. tostring(okC and cb)
        all[string.char(input)] = true
      end
    end
  end
  if #letters > 0 or not okN then out[#out + 1] = n .. (okN and "" or "(?)") .. ": " .. table.concat(letters, ",") end
end
local used = {}
for c in pairs(all) do used[#used + 1] = c end
table.sort(used)
return ("%d maps (%s from ResourceGetNames: %s), letters %s | %s"):format(#names, tostring(fromRes), tostring(okR and type(res) or res), table.concat(used), table.concat(out, " | "))
