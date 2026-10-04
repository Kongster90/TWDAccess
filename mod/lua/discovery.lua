-- Development aid: logs how the game's own scripts use their UI functions, so features can be
-- built on the real call patterns. Enabled with "discovery = true" in settings.txt.
local TWDA = ...
local G = _G
local log = TWDA.log

local counts = {}
local function shouldLog(key)
  local c = (counts[key] or 0) + 1
  counts[key] = c
  return c <= 40 or c % 200 == 0, c
end

local function describe(v)
  local t = type(v)
  if t == "string" then
    if #v > 160 then v = v:sub(1, 160) .. "..." end
    return string.format("%q", v)
  elseif t == "number" or t == "boolean" or t == "nil" then
    return tostring(v)
  elseif t == "function" then
    return "fn"
  elseif t == "table" then
    local parts = {}
    for _, key in ipairs({ "name", "label", "text", "type", "id", "agentName" }) do
      local value = rawget(v, key)
      if type(value) == "string" or type(value) == "number" then parts[#parts + 1] = key .. "=" .. tostring(value) end
    end
    local agent = rawget(v, "agent")
    if agent ~= nil then
      local ok, name = pcall(AgentGetName, agent)
      if ok and name then parts[#parts + 1] = "agent=" .. tostring(name) end
    end
    if #parts == 0 then
      local n = 0
      for k in next, v do
        n = n + 1
        if n <= 6 then parts[#parts + 1] = tostring(k) end
      end
      if n > 6 then parts[#parts + 1] = "+" .. (n - 6) end
    end
    return "{" .. table.concat(parts, " ") .. "}"
  end
  local ok, s = pcall(tostring, v)
  return t .. "<" .. (ok and tostring(s) or "?") .. ">"
end
TWDA.describe = describe

local function argList(...)
  local n = select("#", ...)
  local parts = {}
  for i = 1, math.min(n, 8) do parts[i] = describe((select(i, ...))) end
  if n > 8 then parts[#parts + 1] = "+" .. (n - 8) end
  return table.concat(parts, ", ")
end

local wrapped = setmetatable({}, { __mode = "k" })

local function wrap(label, f)
  if wrapped[f] or TWDA.wrappers[f] then return f end
  local w = function(...)
    local doLog, c = shouldLog(label)
    if doLog then
      local args = table.pack(...)
      pcall(function() log(("call %s#%d(%s)"):format(label, c, argList(table.unpack(args, 1, args.n)))) end)
    end
    local r = table.pack(f(...))
    if doLog and r.n > 0 then
      pcall(function() log(("  ret %s#%d -> %s"):format(label, c, argList(table.unpack(r, 1, r.n)))) end)
    end
    return table.unpack(r, 1, r.n)
  end
  wrapped[w] = true
  return w
end

---------------------------------------------------------------------------------------------------
-- Global functions and UI class tables whose names suggest UI, dialog or QTE logic.
---------------------------------------------------------------------------------------------------

local FUNCTION_PATTERNS = {
  "^Menu", "^UI_", "^Legend", "QTE", "Qte", "Struggle", "Choice", "^Dialog_", "^Subtitle_", "Prompt",
  "Hint", "Popup", "Confirm", "Tutorial", "Inspect", "Hotspot", "Notif", "Reticle", "Mash", "Dodge",
  "^WidgetInputHandler", "Objective", "Walk", "Interact", "Shoot", "Aim", "Swipe", "Timer", "Inventory",
  "Selection", "Focus", "Highlight", "Rollover", "Clickable", "Use_", "Look_", "Talk_",
}
local TABLE_PATTERNS = {
  "^Menu", "^List", "Widget", "Legend", "Button", "Popup", "^UI", "Dialog", "Choice", "Subtitle", "QTE",
  "Struggle", "Hud", "HUD", "Prompt", "Hint", "Reticle", "Cursor", "Inspect", "Hotspot", "Scroll",
  "Slider", "Toggle", "Tab", "Option", "Carousel", "Grid", "Label", "Focus", "Selectable", "Chooser",
}
local SKIP_FUNCTIONS = { Menu_Text = true }

local function matches(name, patterns)
  for _, p in ipairs(patterns) do
    if name:find(p) then return true end
  end
  return false
end

local wrappedTables = setmetatable({}, { __mode = "k" })

local function wrapTable(name, tbl)
  if wrappedTables[tbl] then return end
  wrappedTables[tbl] = true
  local methods = {}
  for k, v in next, tbl do
    if type(k) == "string" and type(v) == "function" and k:sub(1, 2) ~= "__" then
      rawset(tbl, k, wrap(name .. "." .. k, v))
      methods[#methods + 1] = k
    end
  end
  if #methods > 0 then
    table.sort(methods)
    log(("class %s: %s"):format(name, table.concat(methods, " ")))
  end
end

local function consider(name, value)
  if type(name) ~= "string" or TWDA.isHooked(name) then return end
  if type(value) == "function" then
    if not SKIP_FUNCTIONS[name] and matches(name, FUNCTION_PATTERNS) and rawget(G, name) == value then
      rawset(G, name, wrap(name, value))
    end
  elseif type(value) == "table" and matches(name, TABLE_PATTERNS) then
    wrapTable(name, value)
  end
end

local defs = {}
TWDA.onGlobalDefined = function(name, value)
  if type(value) == "function" or type(value) == "table" then
    defs[#defs + 1] = name .. (type(value) == "table" and "{}" or "")
  end
  consider(name, value)
end

-- Everything already defined when we loaded.
do
  local existing = {}
  for k, v in next, G do existing[#existing + 1] = { k, v } end
  for _, kv in ipairs(existing) do consider(kv[1], kv[2]) end
end

-- Tables defined later can gain methods after definition; rescan watched tables now and then.
local lastScan = 0
TWDA.onFrame("discovery", function()
  if #defs > 0 then
    log("defs: " .. table.concat(defs, " "))
    defs = {}
  end
  local t = TWDA.now()
  if t - lastScan > 2 then
    lastScan = t
    for k, v in next, G do
      if type(v) == "table" and type(k) == "string" and matches(k, TABLE_PATTERNS) then
        for mk, mv in next, v do
          if type(mk) == "string" and type(mv) == "function" and mk:sub(1, 2) ~= "__" and not wrapped[mv] and not TWDA.wrappers[mv] then
            rawset(v, mk, wrap(k .. "." .. mk, mv))
          end
        end
      end
    end
  end
end)

---------------------------------------------------------------------------------------------------
-- Text and engine callbacks worth seeing.
---------------------------------------------------------------------------------------------------

do
  local asp = rawget(G, "AgentSetProperty")
  if type(asp) == "function" then
    TWDA.hookGlobal("AgentSetProperty", function(original)
      return function(agent, prop, value, ...)
        if type(prop) == "string" and type(value) == "string" and (prop:find("Text") or prop:find("Label")) then
          local doLog, c = shouldLog("prop:" .. prop)
          if doLog then
            pcall(function() log(("prop %s#%d %s = %s"):format(prop, c, describe(agent), describe(value))) end)
          end
        end
        return original(agent, prop, value, ...)
      end
    end)
  end
end

for _, name in ipairs({ "TextSet", "DlgSelectChoice", "DlgPreSelectChoice", "DialogSelectChoice", "DlgGetChoices",
  "DialogGetNumChoices", "DialogGetChoiceDispText", "SceneOpen", "SceneAdd", "InputMapperActivate",
  "InputMapperDeactivate", "SubtitleSetCreateCallback", "DlgAddCallbackChoicesAvailable",
  "DlgAddCallbackChoicesChanged", "DialogUISetNewChoiceCallback", "DlgRun", "DialogRun" }) do
  local f = rawget(G, name)
  if type(f) == "function" and not TWDA.isHooked(name) then rawset(G, name, wrap(name, f)) end
end

---------------------------------------------------------------------------------------------------
-- Reference dumps: every global with where it comes from, and call stacks for chosen functions.
---------------------------------------------------------------------------------------------------

local function dumpGlobals()
  local rows = {}
  for k, v in next, G do
    local t = type(v)
    local where = ""
    if t == "function" then
      local ok, info = pcall(debug.getinfo, v, "S")
      if ok and info then where = info.what == "C" and "C" or (info.short_src .. ":" .. tostring(info.linedefined)) end
    elseif t == "table" then
      local n = 0
      for _ in next, v do n = n + 1 end
      where = n .. " fields"
    elseif t == "string" or t == "number" or t == "boolean" then
      where = tostring(v):sub(1, 80)
    end
    rows[#rows + 1] = ("%s\t%s\t%s"):format(tostring(k), t, where)
  end
  table.sort(rows)
  local name = ("%sglobals_%s.txt"):format(TWDA.dir, os.date("%H%M%S"))
  local f = io.open(name, "wb")
  if f then
    f:write(table.concat(rows, "\n"), "\n")
    f:close()
    log("wrote " .. name .. " (" .. #rows .. " globals)")
  end
end
TWDA.dumpGlobals = dumpGlobals
-- Run once the scripts that load after us have had a moment to define things.
local dumped = false
local loadedAt = TWDA.now()
TWDA.onFrame("dumpGlobals", function()
  if not dumped and TWDA.now() - loadedAt > 5 then
    dumped = true
    dumpGlobals()
  end
end)

-- Object layout: own keys plus the method names reachable through its metatable.
local function describeClass(obj)
  if type(obj) ~= "table" then return describe(obj) end
  local own = {}
  for k, v in next, obj do own[#own + 1] = tostring(k) .. ":" .. type(v):sub(1, 3) end
  table.sort(own)
  local methods = {}
  local mt = getmetatable(obj)
  local depth = 0
  while type(mt) == "table" and depth < 5 do
    local index = rawget(mt, "__index")
    if type(index) ~= "table" then break end
    for k, v in next, index do
      if type(v) == "function" then methods[#methods + 1] = tostring(k) end
    end
    mt = getmetatable(index)
    depth = depth + 1
  end
  table.sort(methods)
  return "own{" .. table.concat(own, " ") .. "} methods{" .. table.concat(methods, " ") .. "}"
end
TWDA.describeClass = describeClass

-- Our own stack trace; the game's debug.traceback returns an empty string.
local function stack(level)
  local lines = {}
  for i = (level or 2), 14 do
    local ok, info = pcall(debug.getinfo, i, "Sln")
    if not ok or not info then break end
    lines[#lines + 1] = ("  %s:%s %s"):format(info.short_src or "?", tostring(info.currentline), tostring(info.name))
  end
  return table.concat(lines, "\n")
end
TWDA.stack = stack

local function traceCalls(name, times, withClassOfArg)
  local remaining = times
  TWDA.hookBefore(name, function(...)
    if remaining <= 0 then return end
    remaining = remaining - 1
    log(("trace %s(%s)\n%s"):format(name, argList(...), stack(4)))
    if withClassOfArg then
      log(("  arg%d class: %s"):format(withClassOfArg, describeClass((select(withClassOfArg, ...)))))
    end
  end)
end
traceCalls("Cursor_Highlight", 3)
traceCalls("AgentGetSelectionScreenPos", 3, 1)
traceCalls("Dialog_GetText", 3)

---------------------------------------------------------------------------------------------------
-- One-off engine experiments.
---------------------------------------------------------------------------------------------------

pcall(function()
  local f = load("return 6 * 7")
  log("load(text) -> " .. describe(f and f()))
end)
pcall(function()
  local r = table.pack(pcall(HttpPostAsync, "http://127.0.0.1:41234/probe/json", { hello = "world", n = 1 }))
  log("HttpPostAsync(url, table) -> " .. argList(table.unpack(r, 1, r.n)))
end)

-- Can we read the keyboard for hotkeys? Log state changes of a few keys.
local KEYS = { [0x70] = "F1", [0x71] = "F2", [0x72] = "F3", [0x73] = "F4", [0x74] = "F5", [0x75] = "F6",
  [0x76] = "F7", [0x77] = "F8", [0x78] = "F9", [0x79] = "F10", [0x7A] = "F11", [0x7B] = "F12",
  [0x10] = "Shift", [0x11] = "Ctrl", [0x26] = "Up", [0x28] = "Down", [0x0D] = "Enter" }
local keyState = {}
local keyReads = 0
TWDA.onFrame("keytest", function()
  for vk, name in pairs(KEYS) do
    local ok, down = pcall(InputPCIsVKeyPressed, vk)
    if keyReads < 3 then
      keyReads = keyReads + 1
      log(("InputPCIsVKeyPressed(%s) -> %s, %s"):format(name, tostring(ok), describe(down)))
    end
    if ok and down ~= keyState[vk] then
      if keyState[vk] ~= nil then log(("key %s %s"):format(name, down and "down" or "up")) end
      keyState[vk] = down
    end
  end
end)

log("discovery enabled")
