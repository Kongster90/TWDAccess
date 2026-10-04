-- Development helpers, loaded on demand from the dev console: TWDA.safeInclude("devtools").
-- Saves loaded game functions as bytecode so tools/dev/luadis.py can disassemble them.
local TWDA = ...
local G = _G

local DEV = {}
rawset(G, "DEV", DEV)

-- Peels off mod and discovery wrappers to reach the game's own function.
function DEV.unwrap(fn)
  for _ = 1, 10 do
    local inner
    for i = 1, 40 do
      local name, value = debug.getupvalue(fn, i)
      if not name then break end
      if (name == "f" or name == "original") and type(value) == "function" then inner = value end
    end
    if not inner then return fn end
    fn = inner
  end
  return fn
end

function DEV.params(fn)
  fn = DEV.unwrap(fn)
  local names = {}
  for i = 1, 12 do
    local name = debug.getlocal(fn, i)
    if not name then break end
    names[#names + 1] = name
  end
  local info = debug.getinfo(fn, "Su")
  return table.concat(names, ",") .. (info.isvararg and ",..." or "") .. " @" .. info.short_src:match("[^/]*$") .. ":" .. info.linedefined
end

local function save(path, fn)
  local ok, code = pcall(string.dump, DEV.unwrap(fn))
  if not ok then return false end
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(code)
  f:close()
  return true
end

-- Saves every function in the named global tables (classes) and every named global function to
-- TWDAccess/dumps/<name>.luac. Returns how many were written.
function DEV.dump(...)
  local count = 0
  for _, name in ipairs({ ... }) do
    local value = rawget(G, name)
    if type(value) == "function" then
      if save(TWDA.dir .. "dumps/" .. name .. ".luac", value) then count = count + 1 end
    elseif type(value) == "table" then
      for k, v in next, value do
        if type(k) == "string" and type(v) == "function" then
          if save(TWDA.dir .. "dumps/" .. name .. "." .. k .. ".luac", v) then count = count + 1 end
        end
      end
    end
  end
  return count
end

-- Saves every global function defined in a script whose path contains the given text.
function DEV.dumpScript(fragment)
  local count = 0
  for k, v in next, G do
    if type(k) == "string" and type(v) == "function" then
      local fn = DEV.unwrap(v)
      local ok, info = pcall(debug.getinfo, fn, "S")
      if ok and info and info.short_src:find(fragment, 1, true) then
        if save(TWDA.dir .. "dumps/" .. k .. ".luac", fn) then count = count + 1 end
      end
    end
  end
  return count
end

-- The game's own source location of a global, through any wrappers.
function DEV.where(name)
  local value = rawget(G, name)
  if type(value) ~= "function" then return type(value) end
  return DEV.params(value)
end

return DEV
