-- Wrapping game functions. Game scripts define most UI functions as globals, often after we load
-- and sometimes more than once, so hooks are applied when the global is first defined (through a
-- metatable on _G) and re-checked every frame in case the game redefines it.
--
-- Rules every hook follows: the original function is always called exactly as the game called it
-- (so its errors and coroutine yields behave normally), and our own code runs inside pcall so a
-- mistake in the mod can never break the game.
local TWDA = ...
local G = _G

-- name -> { factories = {...}, original = fn, wrapper = fn }. Several modules may hook the same
-- function; their wrappers are chained in the order they were registered.
local hooks = {}

-- Every function the mod installs in place of a game function. Development logging leaves these
-- alone, so feature hooks never end up wrapped over and over.
TWDA.wrappers = setmetatable({}, { __mode = "k" })

-- The engine kills script threads when scenes change, our frame thread included, but game code
-- keeps calling the functions we hook; each call brings the frame thread back if it has died.
local function revive()
  if not TWDA.threadAlive() then pcall(TWDA.ensureThread) end
end

local function apply(name)
  local h = hooks[name]
  local current = rawget(G, name)
  if type(current) ~= "function" or current == h.wrapper then return end
  local wrapper = current
  for _, factory in ipairs(h.factories) do
    local ok, result = pcall(factory, wrapper)
    if ok and type(result) == "function" then
      wrapper = result
    else
      TWDA.log("hook " .. name .. " failed: " .. tostring(result))
    end
  end
  do
    local original = wrapper -- named so TWDA.unwrap can see through this layer
    wrapper = function(...)
      revive()
      return original(...)
    end
  end
  h.original, h.wrapper = current, wrapper
  TWDA.wrappers[wrapper] = true
  rawset(G, name, wrapper)
end

-- factory(original) must return the replacement function.
function TWDA.hookGlobal(name, factory)
  local h = hooks[name]
  if not h then
    h = { factories = {} }
    hooks[name] = h
  elseif h.wrapper and rawget(G, name) == h.wrapper then
    -- Rebuild the chain from the real function so the new wrapper joins it.
    rawset(G, name, h.original)
    h.wrapper = nil
  end
  h.factories[#h.factories + 1] = factory
  apply(name)
end

-- Peels the mod's and the discovery logger's wrappers off a function to reach the game's own.
function TWDA.unwrap(fn)
  for _ = 1, 10 do
    if type(fn) ~= "function" then return fn end
    local inner
    for i = 1, 40 do
      local name, value = debug.getupvalue(fn, i)
      if not name then break end
      if (name == "f" or name == "original" or name == "select") and type(value) == "function" then inner = value end
    end
    if not inner then return fn end
    fn = inner
  end
  return fn
end

-- The value of a named upvalue (a local the game's script keeps between calls) of a function.
function TWDA.upvalue(fn, wanted)
  fn = TWDA.unwrap(fn)
  if type(fn) ~= "function" then return nil end
  for i = 1, 60 do
    local name, value = debug.getupvalue(fn, i)
    if not name then return nil end
    if name == wanted then return value end
  end
  return nil
end

function TWDA.isHooked(name)
  return hooks[name] ~= nil
end

function TWDA.originalOf(name)
  local h = hooks[name]
  return h and h.original or rawget(G, name)
end

local function report(name, err)
  TWDA.log(("hook %s error: %s"):format(name, tostring(err)))
end

-- fn(...) runs before the original with the same arguments.
function TWDA.hookBefore(name, fn)
  TWDA.hookGlobal(name, function(original)
    return function(...)
      local ok, err = pcall(fn, ...)
      if not ok then report(name, err) end
      return original(...)
    end
  end)
end

-- fn(args, results) runs after the original; both are table.pack()ed.
function TWDA.hookAfter(name, fn)
  TWDA.hookGlobal(name, function(original)
    return function(...)
      local results = table.pack(original(...))
      local ok, err = pcall(fn, table.pack(...), results)
      if not ok then report(name, err) end
      return table.unpack(results, 1, results.n)
    end
  end)
end

-- Same idea for a function stored in a table (methods on the game's UI classes).
function TWDA.hookMethod(tbl, key, label, fnBefore, fnAfter)
  local original = rawget(tbl, key)
  if type(original) ~= "function" then return false end
  local wrapper = function(...)
    revive()
    if fnBefore then
      local ok, err = pcall(fnBefore, ...)
      if not ok then report(label, err) end
    end
    if not fnAfter then return original(...) end
    local results = table.pack(original(...))
    local ok, err = pcall(fnAfter, table.pack(...), results)
    if not ok then report(label, err) end
    return table.unpack(results, 1, results.n)
  end
  TWDA.wrappers[wrapper] = true
  rawset(tbl, key, wrapper)
  return true
end

-- Catch first-time definitions immediately, keeping any metatable the game already set.
do
  local mt = getmetatable(G)
  if mt == nil then
    mt = {}
    setmetatable(G, mt)
  end
  local previous = rawget(mt, "__newindex")
  rawset(mt, "__newindex", function(t, k, v)
    if type(previous) == "function" then
      previous(t, k, v)
    elseif type(previous) == "table" then
      previous[k] = v
    else
      rawset(t, k, v)
    end
    if hooks[k] ~= nil then
      local ok, err = pcall(apply, k)
      if not ok then report(k, err) end
    end
    if TWDA.onGlobalDefined then
      local ok, err = pcall(TWDA.onGlobalDefined, k, v)
      if not ok then report("onGlobalDefined", err) end
    end
  end)
end

TWDA.onFrame("hooks", function()
  for name in pairs(hooks) do apply(name) end
end)

-- The engine calls EnginePostUpdate every frame, so a hook on it brings the frame thread back
-- within a frame of the engine killing it (death screen, scene changes), even when nothing else
-- we hook is being called.
TWDA.hookBefore("EnginePostUpdate", function() end)
