-- Dev: what menus.lua's michonneStats reads from the current Your Choices screen (a copy of it).
local menu = Menu_GetCurrentMenu()
local function isHidden(a) local ok, h = pcall(AgentIsHidden, a) return ok and h == true end
local okS, agents = pcall(function() return SceneGetAgents(AgentGetScene(rawget(menu, "agent"))) end)
local rows = {}
for _, agent in ipairs(okS and type(agents) == "table" and agents or {}) do
  local episode, stat, field = TWDA.agentName(agent):match("^ui_stats_episode(%d+)_stat(%d+)_(%a+)$")
  local text = episode and not isHidden(agent) and TWDA.agentText(agent) or nil
  if text then
    local n = tonumber(episode) * 100 + tonumber(stat)
    rows[n] = rows[n] or {}
    rows[n][field] = text
  end
end
local order = {}
for n in pairs(rows) do order[#order + 1] = n end
table.sort(order)
local okT, title = pcall(AgentFind, "ui_stats_episodeTitle")
local parts = { "Your choices", okT and title and TWDA.agentText(title) or nil }
for i, n in ipairs(order) do
  parts[#parts + 1] = ("%d: %s"):format(i, TWDA.joinSentences({ rows[n].question, rows[n].label }))
end
parts[#parts + 1] = "Enter continues"
return TWDA.joinSentences(parts)
