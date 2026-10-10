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
