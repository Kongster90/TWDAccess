-- Development: for 150 seconds, log to twda.log (lines starting "WS") calls to every global
-- function whose name looks like part of a struggle, button mash, QTE or combat, plus mode changes,
-- active input maps, clickable hotspots, Dialog_Play nodes and Logic["Dying"]. Written for the
-- babysitter fight in Clementine's house (2026-10-07).
--   .\console.ps1 -File tools\dev\watch_struggle.lua
local t0 = TWDA.now()
local function log(s) TWDA.log(("WS %.2f %s"):format(TWDA.now() - t0, s)); TWDA.flushLog() end
local describe = TWDA.describe or tostring
local function args(...)
  local parts = {}
  for i = 1, math.min(select("#", ...), 6) do
    local v = select(i, ...)
    local ok, name = pcall(AgentGetName, v)
    parts[#parts + 1] = (type(v) == "userdata" and ok and name) and ("agent:" .. name) or (pcall(describe, v) and describe(v) or tostring(v))
  end
  return table.concat(parts, ", ")
end

local PATTERNS = { "struggle", "mash", "qte", "combat", "panic", "kick", "hammer", "death", "dying", "attack", "prompt", "clemhouse", "choredmovement", "reticleui_set", "reticleui_expand", "reticleui_contract", "motorinn" }
local SKIP = { PanicMeter_Mapping_Combat = true, PanicMeter_Mapping_Death = true, PanicMeter_Mapping_DialogTimer = true,
  PanicMeter_Mapping_Death_SecondHalfWarn = true, ReticleUI_InCombatMode = true,
  Struggle_GetAgent = true, ButtonMash_DoTheMash = true, Struggle_ChoresArePlaying = true, ChoredMovement_IsPathing = true, ChoredMovement_GetController = true, ChoredMovement_GetTimePercent = true }
if not TWDA.wsHooked then
  TWDA.wsHooked = true
  TWDA.lookDebug = true
  local names = {}
  for k, v in next, _G do
    if type(k) == "string" and type(v) == "function" and not SKIP[k] then
      local lower = k:lower()
      for _, p in ipairs(PATTERNS) do
        if lower:find(p, 1, true) then names[#names + 1] = k; break end
      end
    end
  end
  table.sort(names)
  log("hooking " .. table.concat(names, " "))
  for _, name in ipairs(names) do
    TWDA.hookBefore(name, function(...) if rawget(_G, "WS_on") then log("call " .. name .. "(" .. args(...) .. ")") end end)
  end
  TWDA.hookBefore("Dialog_Play", function(node, agent) if rawget(_G, "WS_on") then log("Dialog_Play " .. tostring(node) .. " / " .. tostring(agent and AgentGetName(agent))) end end)
  TWDA.hookBefore("Main_OnUse", function(agent) if rawget(_G, "WS_on") then log("Main_OnUse " .. TWDA.agentName(agent)) end end)
  TWDA.hookBefore("Reticle_UpdateActionIcons", function(default, choices, text)
    if not rawget(_G, "WS_on") then return end
    local parts = {}
    for i, c in pairs(type(choices) == "table" and choices or {}) do parts[#parts + 1] = tostring(i) .. ":" .. tostring(type(c) == "table" and (c["Choice Display Text"] or c.mVerb)) end
    log("icons " .. TWDA.agentName(Reticle_GetAgentFocused()) .. " default=" .. tostring(text) .. " " .. table.concat(parts, " "))
  end)
  TWDA.hookBefore("AgentSetProperty", function(agent, key, value)
    if not rawget(_G, "WS_on") or key ~= "Text String" then return end
    log("text " .. TWDA.agentName(agent) .. " = " .. tostring(value))
  end)
end
rawset(_G, "WS_on", true)
ThreadStart(function()
  local click = TWDA.upvalue(Reticle_Update, "agentIsClickableNoDialog")
  local last, lastMode, lastDying, lastMaps, lastExtra, lastShown = "", "", nil, "", "", ""
  while TWDA.now() - t0 < 150 do
    local names = {}
    local useables = TWDA.upvalue(Reticle_Update, "mUseables") or {}
    for _, agent in ipairs(useables) do
      local ok, sel = pcall(AgentGetProperty, agent, "Game Selectable")
      local okc, c = pcall(click, agent)
      if ok and sel and okc and c and not AgentIsHidden(agent) then names[#names + 1] = TWDA.agentName(agent) end
    end
    local key = table.concat(names, ", ")
    if key ~= last then last = key; log("clickable: " .. key) end
    local shown = {}
    for _, agent in ipairs(useables) do
      local ok, sel = pcall(AgentGetProperty, agent, "Game Selectable")
      if ok and sel and not AgentIsHidden(agent) then shown[#shown + 1] = TWDA.agentName(agent) end
    end
    local shownKey = table.concat(shown, ", ")
    if shownKey ~= lastShown then lastShown = shownKey; log("shown: " .. shownKey) end
    local okm, mode = pcall(Mode_GetCurrent)
    local m = tostring(okm and mode and mode.name)
    if m ~= lastMode then lastMode = m; log("mode " .. m) end
    local okA, maps = pcall(InputMapperGetActiveMapperNames)
    local mapKey = okA and type(maps) == "table" and table.concat(maps, ",") or tostring(maps)
    if mapKey ~= lastMaps then lastMaps = mapKey; log("maps " .. mapKey) end
    local okc, combat = pcall(ReticleUI_InCombatMode)
    local extra = "reticle " .. tostring(TWDA.upvalue(Reticle_Update, "mbReticleSystemActive")) .. " combat " .. tostring(okc and combat)
      .. " focus " .. TWDA.agentName(Reticle_GetAgentFocused())
    if extra ~= lastExtra then lastExtra = extra; log(extra) end
    local dying = Logic and Logic["Dying"]
    if dying ~= lastDying then lastDying = dying; log("Dying " .. tostring(dying)) end
    WaitForNextFrame()
  end
  rawset(_G, "WS_on", false)
  log("done")
end)
return "watching"
