-- Development: for 120 seconds, log to twda.log (lines starting "W2") the clickable hotspots with
-- their visible actions, every Dialog_Play node, the action icons shown, uses (Main_OnUse,
-- PathToAndUseAgent), mode changes, Logic["Dying"], whether the reticle system is on, and Lee's
-- position. How the zombie cop scene was worked out (2026-10-03).
--   .\console.ps1 -File tools\dev\watch_scene.lua
local t0 = TWDA.now()
local function log(s) TWDA.log(("W2 %.1f %s"):format(TWDA.now() - t0, s)); TWDA.flushLog() end
local K = "WDUseable - Action Use Dialog Start Node"
local KF = "WDUseable - Action Use Dialog File"
local function choiceTexts(agent)
  local ok, res = pcall(function()
    local node = agent.mProps[K]
    if not node then return "" end
    local sceneAgent = SceneGetSceneAgent(AgentGetScene(agent))
    for _, dlog in ipairs({ agent.mProps[KF], sceneAgent.mProps["Dialog Agent - File Primary"] }) do
      local found = DlgEvaluateToNode(dlog, node, "choices", false)
      if found then
        local parts = {}
        local kids = DlgNodeGetChildNodes(found["Dlog"], found["Node ID"]) or {}
        local props = DlgChoicesGetDisplayProps(found["Dlog"], found["Node ID"]) or {}
        for i, kid in ipairs(kids) do
          local id = kid["Node ID"]
          local text = "-"
          for k, v in pairs(props) do if tostring(k) == tostring(id) then text = tostring(v["Choice Display Text"]) end end
          parts[#parts + 1] = i .. ":" .. text
        end
        return "[" .. table.concat(parts, " ") .. "]"
      end
      if DlgEvaluateToNode(dlog, node, "start", false) then return "[start node]" end
    end
    return "[?]"
  end)
  return ok and res or ("[err " .. tostring(res) .. "]")
end
if not rawget(_G, "W2_hooked") then
  rawset(_G, "W2_hooked", true)
  TWDA.hookBefore("Dialog_Play", function(node, agent) if rawget(_G, "W2_on") then log("Dialog_Play " .. tostring(node) .. " / " .. tostring(agent and AgentGetName(agent))) end end)
  TWDA.hookBefore("Main_OnUse", function(agent) if rawget(_G, "W2_on") then log("Main_OnUse " .. TWDA.agentName(agent) .. " icon " .. tostring(rawget(agent, "lastSelectedIcon"))) end end)
  TWDA.hookBefore("PathToAndUseAgent", function(agent) if rawget(_G, "W2_on") then log("PathToAndUse " .. TWDA.agentName(agent)) end end)
  TWDA.hookBefore("Reticle_UpdateActionIcons", function(default, choices, text)
    if not rawget(_G, "W2_on") then return end
    local parts = {}
    for i, c in pairs(type(choices) == "table" and choices or {}) do parts[#parts + 1] = tostring(i) .. ":" .. tostring(type(c) == "table" and (c["Choice Display Text"] or c.mVerb)) end
    log("icons " .. TWDA.agentName(Reticle_GetAgentFocused()) .. " default=" .. tostring(text) .. " " .. table.concat(parts, " "))
  end)
end
rawset(_G, "W2_on", true)
ThreadStart(function()
  local click = TWDA.upvalue(Reticle_Update, "agentIsClickableNoDialog")
  local last, lastMode, lastDying = "", "", nil
  local lastExtra = ""
  local lastPos = nil
  while TWDA.now() - t0 < 120 do
    local names = {}
    local useables = TWDA.upvalue(Reticle_Update, "mUseables") or {}
    for _, agent in ipairs(useables) do
      local ok, sel = pcall(AgentGetProperty, agent, "Game Selectable")
      local okc, c = pcall(click, agent)
      if ok and sel and okc and c and not AgentIsHidden(agent) then names[#names + 1] = TWDA.agentName(agent) .. choiceTexts(agent) end
    end
    local key = table.concat(names, ", ")
    if key ~= last then last = key; log("clickable: " .. key) end
    local okm, mode = pcall(Mode_GetCurrent)
    local m = tostring(okm and mode and mode.name)
    if m ~= lastMode then lastMode = m; log("mode " .. m) end
    local okc, combat = pcall(ReticleUI_InCombatMode)
    local extra = "reticle " .. tostring(TWDA.upvalue(Reticle_Update, "mbReticleSystemActive")) .. " combat " .. tostring(okc and combat)
    if extra ~= lastExtra then lastExtra = extra; log(extra) end
    local okp, pos = pcall(AgentGetWorldPos, Game_GetPlayer())
    if okp and pos and (not lastPos or math.abs(pos.x - lastPos.x) + math.abs(pos.z - lastPos.z) > 0.15) then
      lastPos = pos
      local okS, sDown = pcall(InputPCIsVKeyPressed, 0x53)
      log(("lee at %.2f %.2f %.2f, S down %s"):format(pos.x, pos.y, pos.z, tostring(okS and sDown)))
    end
    local dying = Logic and Logic["Dying"]
    if dying ~= lastDying then lastDying = dying; log("Dying " .. tostring(dying)) end
    WaitForNextFrame()
  end
  rawset(_G, "W2_on", false)
  log("done")
end)
TWDA.lookDebug = true
return "watching"
