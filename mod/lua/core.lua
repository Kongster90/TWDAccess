-- Core services: logging, speech transport to the helper, and a per-frame script thread.
local TWDA = ...
local G = _G

local BASE = "http://127.0.0.1:41234"
local MAX_URL_TEXT = 1800 -- characters of encoded payload per request

---------------------------------------------------------------------------------------------------
-- Time
---------------------------------------------------------------------------------------------------

function TWDA.now()
  local ok, t = pcall(GetTotalTime)
  if ok and type(t) == "number" then return t end
  return os.clock()
end

---------------------------------------------------------------------------------------------------
-- Logging (TWDAccess/twda.log). Buffered and flushed once per frame.
---------------------------------------------------------------------------------------------------

local logPath = TWDA.dir .. "twda.log"
local logFile
do
  local existing = io.open(logPath, "rb")
  local size = 0
  if existing then
    size = existing:seek("end") or 0
    existing:close()
  end
  logFile = io.open(logPath, size > 4 * 1024 * 1024 and "wb" or "ab")
end
local logBuffer = {}

function TWDA.log(message)
  logBuffer[#logBuffer + 1] = string.format("%s %9.3f %s", os.date("%H:%M:%S"), TWDA.now(), tostring(message))
  if #logBuffer > 200 then TWDA.flushLog() end
end

function TWDA.flushLog()
  if #logBuffer == 0 or not logFile then return end
  local text = table.concat(logBuffer, "\n") .. "\n"
  logBuffer = {}
  pcall(function()
    logFile:write(text)
    logFile:flush()
  end)
end

-- Development: with TWDA.tracing on (from the dev console), a line written straight to the log
-- before a call into the engine, so that the last line before a crash says which call it was.
-- TWDA.traceFrames = { lookaround = true } also traces those frame callbacks (it floods the log,
-- which load_slot2.ps1 reads).
function TWDA.trace(message)
  if not TWDA.tracing then return end
  TWDA.log("trace " .. message)
  TWDA.flushLog()
end

---------------------------------------------------------------------------------------------------
-- Speech. Messages are collected during a frame and sent together at the end of it, each request
-- numbered so the helper can put them back in order.
---------------------------------------------------------------------------------------------------

local outbox = {}
local seq = 0
local stateId = tostring(math.floor(os.time() % 100000)) .. tostring(math.random(100, 999))

local function urlencode(s)
  return (s:gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
end

local function send(path, payload)
  seq = seq + 1
  local ok, err = pcall(HttpGetAsync, ("%s%s?k=%s&s=%d&t=%s"):format(BASE, path, stateId, seq, urlencode(payload)))
  if not ok then TWDA.log("send failed: " .. tostring(err)) end
end

-- Speaks text through the helper. opts.interrupt stops whatever is being spoken first.
function TWDA.say(text, opts)
  if text == nil then return end
  text = tostring(text)
  if TWDA.cleanText then text = TWDA.cleanText(text) end
  text = text:gsub("[\r\n\t]+", " ")
  if text:match("^%s*$") then return end
  local interrupt = opts and opts.interrupt or false
  if interrupt then
    -- Anything still queued this frame would be cut off anyway.
    outbox = {}
  end
  outbox[#outbox + 1] = (interrupt and "i" or "q") .. "\t" .. text
  TWDA.lastSpoken, TWDA.lastSpokenAt = text, TWDA.now()
  TWDA.log("say" .. (interrupt and "!" or "") .. " " .. text)
  if not TWDA.threadAlive() then TWDA.flushSpeech() end
end

function TWDA.stopSpeech()
  outbox = {}
  outbox[1] = "s\t"
end

function TWDA.flushSpeech()
  if #outbox == 0 then return end
  local lines = outbox
  outbox = {}
  local batch = {}
  local size = 0
  for _, line in ipairs(lines) do
    local encodedSize = #urlencode(line) + 3
    if size > 0 and size + encodedSize > MAX_URL_TEXT then
      send("/speak", table.concat(batch, "\n"))
      batch, size = {}, 0
    end
    batch[#batch + 1] = line
    size = size + encodedSize
  end
  if #batch > 0 then send("/speak", table.concat(batch, "\n")) end
end

---------------------------------------------------------------------------------------------------
-- Per-frame thread. Features register callbacks with TWDA.onFrame(fn). The engine may kill script
-- threads on scene changes, so anything that runs in game code calls TWDA.ensureThread().
---------------------------------------------------------------------------------------------------

local frameCallbacks = {}
local lastTick = -1
local threadStarts = 0

-- Registering a name again replaces its callback (so a module can be reloaded).
function TWDA.onFrame(name, fn)
  for _, entry in ipairs(frameCallbacks) do
    if entry.name == name then
      entry.fn, entry.errors = fn, 0
      return
    end
  end
  frameCallbacks[#frameCallbacks + 1] = { name = name, fn = fn, errors = 0 }
end

function TWDA.frameNames()
  local names = {}
  for _, entry in ipairs(frameCallbacks) do names[#names + 1] = entry.name end
  return names
end

function TWDA.threadAlive()
  return lastTick >= 0 and TWDA.now() - lastTick < 1.0
end

local function frameLoop()
  while true do
    local ok = pcall(WaitForNextFrame)
    if not ok then
      TWDA.log("WaitForNextFrame failed; frame thread stopping")
      lastTick = -1
      return
    end
    lastTick = TWDA.now()
    for _, cb in ipairs(frameCallbacks) do
      -- (TWDA.frameOff[name] = true skips one, for finding which one misbehaves.)
      if cb.errors < 5 and not (TWDA.frameOff and TWDA.frameOff[cb.name]) then
        if TWDA.tracing and TWDA.traceFrames and TWDA.traceFrames[cb.name] then TWDA.trace("frame " .. cb.name) end
        local cbOk, err = pcall(cb.fn)
        if not cbOk then
          cb.errors = cb.errors + 1
          TWDA.log(("frame callback %s failed (%d): %s"):format(cb.name, cb.errors, tostring(err)))
        end
      end
    end
    TWDA.flushSpeech()
    TWDA.flushLog()
  end
end

function TWDA.ensureThread()
  if TWDA.threadAlive() then return end
  if threadStarts > 0 and lastTick >= 0 and TWDA.now() - lastTick < 2.0 then return end
  threadStarts = threadStarts + 1
  lastTick = TWDA.now()
  local ok, err = pcall(ThreadStart, frameLoop)
  if not ok then
    TWDA.log("ThreadStart failed: " .. tostring(err))
    lastTick = -1
  elseif threadStarts > 1 then
    TWDA.log("frame thread restarted (" .. threadStarts .. ")")
  end
end

function TWDA.start()
  TWDA.ensureThread()
  TWDA.flushLog()
end
