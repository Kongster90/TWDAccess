-- TWD Access: screen reader support for The Walking Dead: The Telltale Definitive Series.
-- Installed into the game's Archives folder as DebugLoader.lua. The game's main menu script does
--   if ResourceExists("DebugLoader.lua") then require("DebugLoader.lua"); require("MenuBootUtils.lua") end
-- (a developer hook left in the retail build), so the game loads us itself without any game file
-- being replaced. Deleting this file removes the mod completely.
--
-- PROBE BUILD: works out which output channel the engine allows and logs how the game's own
-- scripts call the subtitle, dialog, text and menu functions, so the real hooks can be written.

local PORT = 41234
local BASE = "http://127.0.0.1:" .. PORT
local VARIANT = "@VARIANT@"

local G = _G or _ENV
if rawget(G, "TWDA_" .. VARIANT) then return end

local T = { version = "probe-6-" .. VARIANT }
rawset(G, "TWDA_" .. VARIANT, T)

-- Because DebugLoader.lua now "exists", the menu script goes on to
--   require("MenuBootUtils.lua")                      (a developer script that expects the real
--                                                      debug loader, so we never let it load), and
--   Callback_OnLoadDebugMenu:Add(OpenDebugMenu)       (needs that callback object to exist).
-- OpenDebugMenu disables input and then calls MenuBoot_CreateDebugMenu, so our stand-in for that
-- re-enables input in case it is ever reached.
pcall(function()
  local realRequire = rawget(G, "require")
  local exists = rawget(G, "ResourceExists")
  T.menuBootUtilsExists = type(exists) == "function" and exists("MenuBootUtils.lua") or false
  if type(realRequire) == "function" then
    rawset(G, "require", function(name, ...)
      if name == "MenuBootUtils.lua" then
        if rawget(G, "MenuBoot_CreateDebugMenu") == nil then
          rawset(G, "MenuBoot_CreateDebugMenu", function()
            local enable = rawget(G, "WidgetInputHandler_EnableInput")
            if enable then enable(true) end
          end)
        end
        return true
      end
      return realRequire(name, ...)
    end)
  end
  T.debugMenuCallbackExisted = rawget(G, "Callback_OnLoadDebugMenu") ~= nil
  if not T.debugMenuCallbackExisted then
    local noop = function() end
    rawset(G, "Callback_OnLoadDebugMenu", { Add = noop, Remove = noop, Call = noop, Clear = noop })
  end
end)

-- Side-effect markers that work even if no output channel does. Each is tried independently.
pcall(function() print("TWDA: probe " .. VARIANT .. " running") end)
pcall(function()
  local prefs = GetPreferences()
  PropertySet(prefs, "TWDA Probe " .. VARIANT, T.version)
  SavePrefs()
end)

local currentDir = rawget(G, "_currentDirectory")
local pending = {}
local ioFile

local function now()
  local f = rawget(G, "GetTotalTime")
  if f then
    local ok, t = pcall(f)
    if ok and type(t) == "number" then return t end
  end
  local os_ = rawget(G, "os")
  if type(os_) == "table" and os_.clock then return os_.clock() end
  return 0
end

local function log(s)
  s = string.format("%9.3f %s", now(), tostring(s))
  if ioFile then pcall(function() ioFile:write(s, "\n"); ioFile:flush() end) end
  pending[#pending + 1] = s
  if #pending > 4000 then table.remove(pending, 1) end
end
T.log = log

local function safeStr(v)
  local t = type(v)
  if t == "string" then
    if #v > 160 then v = v:sub(1, 160) .. "..." end
    return string.format("%q", v)
  elseif t == "number" or t == "boolean" or t == "nil" then
    return tostring(v)
  elseif t == "table" then
    local keys, n = {}, 0
    for k in next, v do
      n = n + 1
      if n <= 8 then keys[#keys + 1] = tostring(k) end
    end
    return "table{" .. table.concat(keys, ",") .. (n > 8 and (",+" .. (n - 8)) or "") .. "}"
  elseif t == "function" then
    return "fn"
  end
  local ok, s = pcall(tostring, v)
  return t .. "<" .. (ok and tostring(s) or "?") .. ">"
end
T.safeStr = safeStr

local function argList(...)
  local n = select("#", ...)
  local parts = {}
  for i = 1, math.min(n, 10) do parts[i] = safeStr((select(i, ...))) end
  if n > 10 then parts[#parts + 1] = "+" .. (n - 10) .. " more" end
  return table.concat(parts, ", ")
end

local function urlencode(s)
  return (tostring(s):gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", string.byte(c)) end))
end

---------------------------------------------------------------------------------------------------
-- Output channels. Each candidate is tried; the helper logs which requests actually arrive.
---------------------------------------------------------------------------------------------------

local senders = {
  { id = "postA", fn = function(p, b) return HttpPostAsync(BASE .. p, b) end },
  { id = "postB", fn = function(p, b) return HttpPostAsync(BASE .. p, b, "text/plain") end },
  { id = "postC", fn = function(p, b) return HttpPostAsync(BASE .. p, {}, b) end },
  { id = "postD", fn = function(p, b) return HttpPostAsync(BASE .. p, b, {}) end },
  { id = "getA",  fn = function(p, b) return HttpGetAsync(BASE .. p .. "?t=" .. urlencode(b)) end },
  { id = "getB",  fn = function(p, b) return HttpGetAsync(BASE .. p .. "?t=" .. urlencode(b), {}) end },
}

local function trySenders(stage, body)
  for _, s in ipairs(senders) do
    if not s.broken then
      local r = table.pack(pcall(s.fn, "/probe/" .. VARIANT .. "/" .. stage .. "/" .. s.id, body or ("probe " .. VARIANT .. " " .. stage .. " " .. s.id)))
      if r[1] then
        log(("sender %s stage %s ok -> %s"):format(s.id, stage, argList(table.unpack(r, 2, r.n))))
      else
        s.errors = (s.errors or 0) + 1
        if s.errors >= 3 then s.broken = true end
        log(("sender %s stage %s error: %s"):format(s.id, stage, tostring(r[2])))
      end
    end
  end
end

-- inThread: true when called from our own script thread, where the synchronous POST may wait.
local function flush(inThread)
  if #pending == 0 then return end
  local chunk = {}
  for i = 1, math.min(#pending, 300) do chunk[i] = pending[i] end
  for i = #chunk, 1, -1 do table.remove(pending, i) end
  local body = table.concat(chunk, "\n")
  if inThread and rawget(G, "HttpPostAndWait") then
    local ok, err = pcall(HttpPostAndWait, BASE .. "/log", body)
    if ok then return end
    pending[#pending + 1] = "HttpPostAndWait failed: " .. tostring(err)
  end
  pcall(HttpPostAsync, BASE .. "/log", body)
end
T.flush = flush

---------------------------------------------------------------------------------------------------
-- Wrapping helpers. Logging failures must never leak into game code, so logging is in pcall and the
-- original is always called directly (keeps errors and coroutine yields intact).
---------------------------------------------------------------------------------------------------

local isWrapper = setmetatable({}, { __mode = "k" })
local counts = {}

local function shouldLog(name)
  local c = (counts[name] or 0) + 1
  counts[name] = c
  return c <= 30 or c % 200 == 0, c
end

local traceback = type(rawget(G, "debug")) == "table" and debug.traceback or tostring

-- Logs entry (so calls that never return still show up), the return values, and any error the
-- wrapped function raises before re-raising it unchanged.
local function wrapFn(name, f, withResults)
  if type(f) ~= "function" or isWrapper[f] then return f end
  local onError = function(e)
    pcall(function() log(("ERROR in %s: %s"):format(name, traceback(tostring(e), 2))) end)
    return e
  end
  local w = function(...)
    local doLog, c = shouldLog(name)
    if doLog then
      local args = table.pack(...)
      pcall(function() log(("call %s#%d(%s)"):format(name, c, argList(table.unpack(args, 1, args.n)))) end)
    end
    local r = table.pack(xpcall(f, onError, ...))
    if not r[1] then error(r[2], 0) end
    if doLog and withResults and r.n > 1 then
      pcall(function() log(("  ret %s#%d -> %s"):format(name, c, argList(table.unpack(r, 2, r.n)))) end)
    end
    return table.unpack(r, 2, r.n)
  end
  isWrapper[w] = true
  return w
end

local function wrapGlobal(name, withResults)
  local f = rawget(G, name)
  if type(f) == "function" and not isWrapper[f] then
    rawset(G, name, wrapFn(name, f, withResults))
    return true
  end
  return false
end

-- Callback setters: wrap the callback so we can see when the engine calls it and with what.
local function wrapCallbackSetter(name)
  local f = rawget(G, name)
  if type(f) ~= "function" then return end
  local w = function(...)
    local args = table.pack(...)
    pcall(function() log(("set %s(%s)"):format(name, argList(table.unpack(args, 1, args.n)))) end)
    for i = 1, args.n do
      if type(args[i]) == "function" then
        args[i] = wrapFn(name .. "->cb", args[i], true)
      elseif type(args[i]) == "string" then
        -- Telltale often passes the callback as a global function name.
        local target = args[i]
        pcall(function()
          if not wrapGlobal(target, true) then T.watchNames[target] = true end
        end)
      end
    end
    return f(table.unpack(args, 1, args.n))
  end
  isWrapper[w] = true
  rawset(G, name, w)
end

T.watchNames = {}

-- Script-defined globals whose names match these patterns get wrapped when they are defined.
local WATCH = {
  "^Menu", "^UI_", "^Legend", "QTE", "Qte", "Struggle", "Choice", "^Dialog", "^Dlg", "Subtitle",
  "Prompt", "Hint", "Popup", "Confirm", "Tutorial", "Inspect", "Hotspot", "Notif", "Selectable",
  "^Hud", "^HUD", "Reticle", "Mash", "Dodge", "Widget", "Button", "Timer", "Objective", "Achievement",
  "Walk", "Interact", "Look", "Use", "Shoot", "Aim", "Swipe", "Tap", "Hold", "Input_", "Cursor",
}
local function watched(name)
  if T.watchNames[name] then return true end
  for _, p in ipairs(WATCH) do
    if name:find(p) then return true end
  end
  return false
end

---------------------------------------------------------------------------------------------------
-- Probe body
---------------------------------------------------------------------------------------------------

local function probe()
  if type(io) == "table" and type(io.open) == "function" then
    local ok, f = pcall(io.open, (type(currentDir) == "string" and currentDir or "") .. "TWDAccess_probe_" .. VARIANT .. ".log", "a")
    if ok and f then ioFile = f end
  end

  log("==== TWD Access " .. T.version .. " boot ====")
  log("_VERSION=" .. tostring(rawget(G, "_VERSION")) .. " _currentDirectory=" .. safeStr(currentDir)
      .. " _G=" .. tostring(rawget(G, "_G")) .. " _ENV==_G " .. tostring(_ENV == rawget(G, "_G"))
      .. " metatable(_G)=" .. safeStr(getmetatable(G)) .. " MenuBootUtils exists=" .. tostring(T.menuBootUtilsExists) .. " debug-menu callback existed=" .. tostring(T.debugMenuCallbackExisted))

  local names = { "io", "os", "debug", "package", "string", "table", "math", "coroutine", "bit32", "utf8",
    "require", "load", "loadstring", "dofile", "loadfile", "print", "Print", "setmetatable", "rawset",
    "HttpPostAsync", "HttpGetAsync", "HttpPostAndWait", "HttpGetAndWait", "HttpToJson", "HttpParseJson",
    "ThreadStart", "WaitForNextFrame", "Sleep", "GetTotalTime", "GetFrameTime", "SubtitleSetCreateCallback",
    "TextSet", "AgentSetProperty", "DlgGetChoices", "InputMapperSetCallback", "InputPCIsVKeyPressed",
    "RegisterSetDescription", "ResourceExists", "SceneOpen", "LocalizationGetDisplayText" }
  local parts = {}
  for _, n in ipairs(names) do parts[#parts + 1] = n .. "=" .. type(rawget(G, n)) end
  log("globals: " .. table.concat(parts, " "))
  if type(rawget(G, "io")) == "table" then
    local p = {}
    for k in pairs(io) do p[#p + 1] = tostring(k) end
    log("io: " .. table.concat(p, ","))
  end
  if type(rawget(G, "os")) == "table" then
    local p = {}
    for k in pairs(os) do p[#p + 1] = tostring(k) end
    log("os: " .. table.concat(p, ","))
  end
  if type(rawget(G, "debug")) == "table" then
    local p = {}
    for k in pairs(debug) do p[#p + 1] = tostring(k) end
    log("debug: " .. table.concat(p, ","))
  end

  -- Count what is already defined (engine C functions vs Lua functions).
  local nC, nL, nOther = 0, 0, 0
  local dinfo = type(rawget(G, "debug")) == "table" and debug.getinfo
  for k, v in next, G do
    if type(v) == "function" then
      if dinfo then
        local ok, info = pcall(dinfo, v, "S")
        if ok and info and info.what == "C" then nC = nC + 1 else nL = nL + 1 end
      else
        nC = nC + 1
      end
    else
      nOther = nOther + 1
    end
  end
  log(("existing globals: %d C/unknown functions, %d Lua functions, %d other"):format(nC, nL, nOther))

  trySenders("boot")

  -- Engine functions to watch.
  for _, n in ipairs({
    "SubtitleSetCreateCallback", "SubtitleSetDestroyCallback", "SubtitleSetBeginSequenceCallback",
    "SubtitleSetEndSequenceCallback", "DialogUISetNewChoiceCallback", "DialogUISetDlgBeginCallback",
    "DialogUISetDlgEndCallback", "DialogUISetBranchBeginCallback", "DialogUISetBranchEndCallback",
    "DialogUISetItemBeginCallback", "DialogUISetItemEndCallback", "DialogUISetExchangeBeginCallback",
    "DialogUISetExchangeEndCallback", "DlgAddCallbackChoicesAvailable", "DlgAddCallbackChoicesChanged",
    "DlgAddCallbackDialogBegin", "DlgAddCallbackDialogEnd", "DlgSetCallbackNodeBegin", "DlgSetCallbackNodeEnd",
    "InputMapperSetCallback", "RolloverSetRolledOnCallback", "RolloverSetRolledOffCallback",
  }) do wrapCallbackSetter(n) end

  for _, n in ipairs({
    "SubtitleGetText", "SubtitleGetAgentName", "DialogGetNumChoices", "DialogGetChoiceDispText",
    "DlgGetChoices", "DlgSelectChoice", "DlgPreSelectChoice", "DialogSelectChoice", "TextSet",
    "LangGetTextFromID", "SceneOpen", "SceneAdd", "DlgRun", "DialogRun", "InputMapperActivate",
    "InputMapperDeactivate", "CursorSetPos", "ChorePlay", "ChorePlayAndWait",
  }) do wrapGlobal(n, true) end

  -- AgentSetProperty: only log text-like properties.
  local asp = rawget(G, "AgentSetProperty")
  if type(asp) == "function" then
    local w = function(agent, prop, value, ...)
      if type(prop) == "string" and type(value) == "string" and (prop:find("[Tt]ext") or prop:find("[Ll]abel")) then
        local doLog, c = shouldLog("AgentSetProperty:" .. prop)
        if doLog then
          pcall(function() log(("prop %s#%d %s = %s"):format(prop, c, safeStr(agent), safeStr(value))) end)
        end
      end
      return asp(agent, prop, value, ...)
    end
    isWrapper[w] = true
    rawset(G, "AgentSetProperty", w)
  end

  -- require: record each module the first time it loads.
  local req = rawget(G, "require")
  if type(req) == "function" then
    local seen = {}
    local w = function(name, ...)
      if not seen[name] then
        seen[name] = true
        pcall(log, "require " .. tostring(name))
      end
      return req(name, ...)
    end
    isWrapper[w] = true
    rawset(G, "require", w)
  end

  -- Catch new global definitions, wrapping interesting ones.
  local defined = {}
  local oldMt = getmetatable(G)
  local mt = {}
  if type(oldMt) == "table" then for k, v in next, oldMt do mt[k] = v end end
  local prevNewindex = mt.__newindex
  mt.__newindex = function(t, k, v)
    if type(k) == "string" and type(v) == "function" then
      local ok, isWatched = pcall(watched, k)
      if ok and isWatched then v = wrapFn(k, v, true) end
      defined[#defined + 1] = k .. (isWatched and "*" or "")
      if #defined >= 40 then
        pcall(log, "defs: " .. table.concat(defined, " "))
        defined = {}
      end
    end
    if type(prevNewindex) == "function" then
      return prevNewindex(t, k, v)
    elseif type(prevNewindex) == "table" then
      prevNewindex[k] = v
    else
      rawset(t, k, v)
    end
  end
  setmetatable(G, mt)
  T.flushDefs = function()
    if #defined > 0 then log("defs: " .. table.concat(defined, " ")); defined = {} end
  end

  -- Heartbeat thread: flushes logs and retries the senders once the engine is fully running.
  local function heartbeat()
    log("heartbeat thread started")
    local t0 = now()
    local lastFlush, frames = 0, 0
    local stages = { [3] = "t3", [15] = "t15", [60] = "t60" }
    local waited = false
    while true do
      local ok, err = pcall(WaitForNextFrame)
      if not ok then
        log("WaitForNextFrame failed: " .. tostring(err))
        return
      end
      frames = frames + 1
      local t = now() - t0
      for at, tag in pairs(stages) do
        if t >= at then
          stages[at] = nil
          trySenders(tag)
          if tag == "t15" and not waited then
            waited = true
            local r = table.pack(pcall(HttpGetAndWait, BASE .. "/probe/" .. VARIANT .. "/getwait"))
            log("HttpGetAndWait -> " .. argList(table.unpack(r, 1, r.n)))
            local r2 = table.pack(pcall(HttpPostAndWait, BASE .. "/probe/" .. VARIANT .. "/postwait", "hello from postwait"))
            log("HttpPostAndWait -> " .. argList(table.unpack(r2, 1, r2.n)))
          end
        end
      end
      if t - lastFlush >= 1 then
        lastFlush = t
        pcall(T.flushDefs)
        if getmetatable(G) ~= mt then log("NOTE: _G metatable was replaced by game code") ; mt = getmetatable(G) or mt end
        flush(true)
      end
    end
  end

  local ts = rawget(G, "ThreadStart")
  if type(ts) == "function" then
    local r = table.pack(pcall(ts, heartbeat))
    log("ThreadStart(heartbeat) -> " .. argList(table.unpack(r, 1, r.n)))
  end
end

local ok, err = pcall(probe)
if not ok then
  pcall(log, "probe failed: " .. tostring(err))
end
