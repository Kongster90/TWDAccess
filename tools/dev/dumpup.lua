-- Dev console: save a game function's upvalue functions (and their upvalue functions, two levels)
-- as bytecode in TWDAccess\dumps\up\<global>.<upvalue>.luac. Set DUMPUP to the global's name (and
-- DUMPUP_DEPTH for more levels than two).
local name = rawget(_G, "DUMPUP")
local fn = DEV.unwrap(rawget(_G, name))
local dir = TWDA.dir .. "dumps/up/"
os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')
local saved, seen = {}, {}
local function save(prefix, f, depth)
  if seen[f] or depth > (rawget(_G, "DUMPUP_DEPTH") or 2) then return end
  seen[f] = true
  for i = 1, 80 do
    local n, v = debug.getupvalue(f, i)
    if not n then break end
    if type(v) == "function" then
      local ok, code = pcall(string.dump, v)
      if ok then
        local h = io.open(dir .. prefix .. "." .. n .. ".luac", "wb")
        if h then h:write(code) h:close() saved[#saved + 1] = prefix .. "." .. n end
      end
      save(prefix .. "." .. n, v, depth + 1)
    end
  end
end
save(name, fn, 1)
return table.concat(saved, " ")
