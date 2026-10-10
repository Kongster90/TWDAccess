-- Season 1's full-screen prompts that only take a mouse click: the death screen
-- (mode_UI_Death: the words "You are dead" are a picture, then "Click to continue"). Enter does
-- what the click does, mode_UI_Death:UnPause(), which reloads the last checkpoint.
local TWDA = ...
local G = _G

local VK_ENTER = 0x0D

local announced = false
local held = true

TWDA.onFrame("prompts", function()
  local death = rawget(G, "mode_UI_Death")
  local okMode, mode = pcall(Mode_GetCurrent)
  if type(death) ~= "table" or not okMode or mode ~= death then
    announced = false
    return
  end
  local okKey, down = pcall(InputPCIsVKeyPressed, VK_ENTER)
  down = okKey and down == true
  if not announced then
    announced = true
    held = down -- an Enter still held from before is not an answer
    TWDA.lastHint = "You are dead. Press Enter to try again from the last checkpoint."
    TWDA.say(TWDA.lastHint, { interrupt = true })
    return
  end
  if down and not held and type(death.UnPause) == "function" then
    local ok, err = pcall(ThreadStart, function()
      local okRun, errRun = pcall(death.UnPause, death)
      if not okRun then TWDA.log("death screen: " .. tostring(errRun)) end
    end)
    if not ok then TWDA.log("death screen (thread): " .. tostring(err)) end
  end
  held = down
end)

-- The end-of-episode statistics (ui_stats.scene, input map ui_stats.imap, opened by UI_Stats_Open):
-- one row per big decision, each with a title ("Honesty"), the question ("Lied to Hershel?") and
-- the result ("You and 46% of players lied."), on the agents ui_stats_decision<n>Title, Desc and
-- Result. Enter is the game's own key for "Click to continue" (Stats_OnLeftClick).
local function statsText()
  local parts = {}
  for i = 1, 10 do
    local row = {}
    for _, field in ipairs({ "Title", "Desc", "Result" }) do
      local okAgent, agent = pcall(AgentFind, "ui_stats_decision" .. i .. field)
      local okHidden, hidden = pcall(AgentIsHidden, agent)
      if okAgent and agent and not (okHidden and hidden) then
        local text = TWDA.agentText(agent)
        if text and text ~= "" then row[#row + 1] = text end
      end
    end
    -- "Honesty: Lied to Hershel? You and 46% of players lied."
    if #row == 3 then row = { row[1] .. (row[1]:find("[%?%.!]$") and " " or ": ") .. row[2], row[3] } end
    if #row > 0 then parts[#parts + 1] = table.concat(row, " ") end
  end
  if #parts == 0 then return nil end
  return "Your decisions. " .. table.concat(parts, " ") .. " Enter to continue."
end

local statsShown = false
TWDA.describeStats = function()
  local ok, on = pcall(InputMapperIsActive, "ui_stats.imap")
  if not (ok and on) then return nil end
  return statsText()
end

TWDA.onFrame("stats", function()
  local ok, on = pcall(InputMapperIsActive, "ui_stats.imap")
  on = ok and on == true
  if on and not statsShown then
    local text = statsText()
    if text then
      statsShown = true
      TWDA.lastHint = text
      TWDA.say(text, { interrupt = true })
    end
  elseif not on and statsShown then
    statsShown = false
    if type(TWDA.lastHint) == "string" and TWDA.lastHint:find("^Your decisions") then TWDA.lastHint = nil end
  end
end)

-- The season's summary after its last episode (ui_seasonStats.scene, input map ui_seasonstats.imap,
-- UI_SeasonStats_Open; Season 1's ends after Episode 5): a card per character
-- ("ui_seasonStats_kenny", lines on ..._text1 to _text4), five to a page. Only a mouse click goes
-- on (SeasonStats_OnLeftClick, which plays chores and so needs a thread of its own); Enter does it
-- here. Each page is read as it appears, cards left to right.
local SEASON_IMAP = "ui_seasonstats.imap"
local function shown(agent)
  local okHidden, isHidden = pcall(AgentIsHidden, agent)
  return agent ~= nil and not (okHidden and isHidden)
end
local function seasonText()
  local cards, order = {}, {}
  local okA, agents = pcall(SceneGetAgents, "ui_seasonStats.scene")
  for _, agent in ipairs(okA and type(agents) == "table" and agents or {}) do
    local who, n = TWDA.agentName(agent):match("^ui_seasonStats_(%a+)_text(%d)$")
    local okParent, parent = pcall(AgentGetParent, agent)
    if who and shown(agent) and (not okParent or parent == nil or shown(parent)) then
      local text = TWDA.agentText(agent)
      if text and text ~= "" then
        if not cards[who] then
          local okPos, pos = pcall(AgentGetScreenPos, agent)
          cards[who] = { x = okPos and pos and pos.x or 0, lines = {} }
          order[#order + 1] = who
        end
        cards[who].lines[tonumber(n)] = text
      end
    end
  end
  if #order == 0 then return nil end
  table.sort(order, function(a, b) return cards[a].x < cards[b].x end)
  local parts = {}
  for _, who in ipairs(order) do
    local lines = {}
    for i = 1, 4 do
      if cards[who].lines[i] then lines[#lines + 1] = cards[who].lines[i] end
    end
    parts[#parts + 1] = who:sub(1, 1):upper() .. who:sub(2) .. ": " .. TWDA.joinSentences(lines)
  end
  return "Season summary. " .. table.concat(parts, " ") .. " Enter to continue."
end

TWDA.describeSeasonStats = function()
  local ok, on = pcall(InputMapperIsActive, SEASON_IMAP)
  if not (ok and on) then return nil end
  return seasonText()
end

local seasonSaid, enterHeld = nil, true
TWDA.onFrame("seasonstats", function()
  local ok, on = pcall(InputMapperIsActive, SEASON_IMAP)
  local okKey, down = pcall(InputPCIsVKeyPressed, 0x0D)
  down = okKey and down == true
  local enter = down and not enterHeld
  enterHeld = down
  if not (ok and on) then
    seasonSaid = nil
    return
  end
  local text = seasonText()
  if text and text ~= seasonSaid then
    seasonSaid = text
    TWDA.lastHint = text
    TWDA.say(text, { interrupt = true })
  end
  if enter and type(rawget(G, "SeasonStats_OnLeftClick")) == "function" then
    pcall(ThreadStart, function() pcall(SeasonStats_OnLeftClick) end)
  end
end)

-- An episode's credits (mode_UI_Credits; one long text on ui_credits_text, the episode's name on
-- ui_credits_textTitle). After an episode they cannot be skipped (OnMouseLDouble only works when
-- they were opened from the menu); F6 reads them.
local function creditsText()
  local okMode, mode = pcall(Mode_GetCurrent)
  if not okMode or mode ~= rawget(G, "mode_UI_Credits") then return nil end
  local okAgent, agent = pcall(AgentFind, "ui_credits_text")
  if not okAgent or agent == nil then return nil end
  return TWDA.agentText(agent)
end

local creditsAnnounced = false
TWDA.onFrame("episodecredits", function()
  local text = creditsText()
  if text and not creditsAnnounced then
    creditsAnnounced = true
    local okTitle, title = pcall(AgentFind, "ui_credits_textTitle")
    local name = okTitle and title and TWDA.agentText(title) or nil
    TWDA.say("Credits" .. (name and name ~= "" and (" for " .. name) or "") .. ". F6 reads them.", { interrupt = true })
  elseif not text then
    creditsAnnounced = false
  end
end)

-- For F6 (hotkeys.lua asks TWDA.creditsText, also used by the hub's credits in menus.lua).
local hubCredits = TWDA.creditsText
TWDA.creditsText = function()
  return creditsText() or (hubCredits and hubCredits()) or nil
end
