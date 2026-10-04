-- Development console: runs Lua sent from the helper (POST http://127.0.0.1:41234/enqueue) inside the
-- game and logs the result. Enabled with "devconsole = true" in settings.txt; off for players.
local TWDA = ...
local BASE = "http://127.0.0.1:41234"
local POLL_SECONDS = 0.25

local function urlencode(s)
  return (s:gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
end

local function report(text)
  TWDA.log(text)
  TWDA.flushLog()
  if #text > 1500 then text = text:sub(1, 1500) .. " ...(see twda.log)" end
  pcall(HttpGetAsync, BASE .. "/log?t=" .. urlencode(text))
end

local function run(code)
  -- Expressions print their value; statements just run.
  local chunk = load("return " .. code, "=console", "t")
  local compileErr
  if not chunk then chunk, compileErr = load(code, "=console", "t") end
  if not chunk then
    report("console> " .. code .. "\n  compile error: " .. tostring(compileErr))
    return
  end
  local results = table.pack(pcall(chunk))
  local parts = {}
  for i = 2, results.n do
    parts[#parts + 1] = TWDA.describe and TWDA.describe(results[i]) or tostring(results[i])
  end
  if results[1] then
    report("console> " .. code .. "\n  = " .. table.concat(parts, ", "))
  else
    report("console> " .. code .. "\n  error: " .. tostring(results[2]))
  end
end
TWDA.runConsole = run

local lastPoll = TWDA.now()

local function poll()
  while true do
    lastPoll = TWDA.now()
    local ok, body = pcall(HttpGetAndWait, BASE .. "/cmd")
    if ok and type(body) == "string" and body ~= "" then
      -- Commands run in this thread, so they may wait (e.g. call ...AndWait functions).
      run(body)
    end
    local start = TWDA.now()
    repeat
      if not pcall(WaitForNextFrame) then return end
    until TWDA.now() - start >= POLL_SECONDS
  end
end

local ok, err = pcall(ThreadStart, poll)
TWDA.log(ok and "dev console listening" or ("dev console failed: " .. tostring(err)))

-- Scene changes can kill the console's thread too; start it again. (A command that waits a long
-- time also looks dead from here, so allow plenty of time.)
TWDA.onFrame("devconsole", function()
  if TWDA.now() - lastPoll < 10 then return end
  lastPoll = TWDA.now()
  local okRestart, errRestart = pcall(ThreadStart, poll)
  TWDA.log(okRestart and "dev console restarted" or ("dev console restart failed: " .. tostring(errRestart)))
end)

-- The console's helper functions (DEV.dump, DEV.where, ...).
TWDA.safeInclude("devtools")
