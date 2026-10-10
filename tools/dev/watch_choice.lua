-- Development: while mode_choice (the game's directional choice: arrow keys turn Lee towards one
-- side or another) is up, log its logic agent's side nodes, the current side and what is
-- clickable, whenever any of that changes. For 120 seconds.
--   .\checkpoint_watch.ps1 -Watch watch_choice.lua -Filter "WC "
local t0 = TWDA.now()
local function log(s) TWDA.log(("WC %.2f %s"):format(TWDA.now() - t0, s)); TWDA.flushLog() end
ThreadStart(function()
  while type(rawget(_G, "mode_choice")) ~= "table" do WaitForNextFrame() end
  local left = TWDA.unwrap(mode_choice.OnButtonLeft)
  local kLogic = TWDA.upvalue(left, "kLogicAgentName")
  local transition = TWDA.upvalue(left, "transition")
  local getSide = TWDA.upvalue(transition, "getCurrentSide")
  local keys = {}
  for _, n in ipairs({ "kPropLeftNode", "kPropRightNode", "kPropUpNode", "kPropDownNode", "kPropDlgFile" }) do
    keys[n] = TWDA.upvalue(TWDA.upvalue(transition, "hasTransitionNodes") or left, n) or TWDA.upvalue(transition, n)
  end
  log("logic agent " .. tostring(kLogic) .. " keys " .. tostring(keys.kPropLeftNode) .. " / " .. tostring(keys.kPropRightNode) .. " / " .. tostring(keys.kPropDlgFile))
  local last = ""
  local click = TWDA.upvalue(Reticle_Update, "agentIsClickableNoDialog")
  while TWDA.now() - t0 < 120 do
    local okA, active = pcall(InputMapperIsActive, "mode_choice.imap")
    local parts = { "active " .. tostring(okA and active) }
    if okA and active then
      local agent = AgentFind(kLogic)
      for _, n in ipairs({ "kPropLeftNode", "kPropRightNode", "kPropUpNode", "kPropDownNode" }) do
        if keys[n] then parts[#parts + 1] = n .. "=" .. tostring(AgentGetProperty(agent, keys[n])) end
      end
      local okS, side = pcall(getSide)
      parts[#parts + 1] = "side " .. tostring(okS and side)
      for _, a in ipairs({ "ui_choice_arrowleft", "ui_choice_arrowright", "ui_choice_arrowup", "ui_choice_arrowdown" }) do
        local ag = AgentFind(a)
        parts[#parts + 1] = a .. (ag and (AgentIsHidden(ag) and ":hidden" or ":shown") or ":none")
      end
      local names = {}
      for _, u in ipairs(TWDA.upvalue(Reticle_Update, "mUseables") or {}) do
        local okc, c = pcall(click, u)
        if okc and c then names[#names + 1] = TWDA.agentName(u) end
      end
      parts[#parts + 1] = "clickable " .. table.concat(names, ",")
    end
    local key = table.concat(parts, " | ")
    if key ~= last then last = key; log(key) end
    WaitForNextFrame()
  end
  log("done")
end)
return "watching choice"
