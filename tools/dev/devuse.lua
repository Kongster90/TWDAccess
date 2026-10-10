-- Development: DEV.use("Lilly's Door") walks Lee to the first hotspot with that display name
-- (path-finding, as the mod's walks do) and uses it through the reticle with its first action that
-- is not looking (TWDA.useWithReticle); DEV.use("Clementine", true) only walks there;
-- DEV.use("Chalk X", false, 2) does its second action (Inspect). Logs "DEVUSE" lines. For hurrying
-- through exploration that the mod already handles.
--   .\console.ps1 -File tools\dev\devuse.lua      (once per Lua state)
--   .\console.ps1 'DEV.use("Broken Glass")'
DEV = DEV or {}
function DEV.use(name, walkOnly, index)
  local agent
  for _, a in ipairs(TWDA.upvalue(Reticle_Update, "mUseables") or {}) do
    if not agent and TWDA.hotspotName(a) == name and not AgentIsHidden(a) then agent = a end
  end
  if not agent then TWDA.log("DEVUSE no " .. name) return "none" end
  ThreadStart(function()
    local lee = Game_GetPlayer()
    local okWalk = pcall(InputMapperIsActive, "Navigate.imap") and InputMapperIsActive("Navigate.imap")
    if okWalk then AgentPathToAgent(lee, rawget(agent, "usePosAgent") or agent) end
    for i = 1, 20 do WaitForNextFrame() end
    if not walkOnly then TWDA.useWithReticle(agent, index) end
    TWDA.log("DEVUSE done " .. name)
    TWDA.flushLog()
  end)
  return "going"
end
return "DEV.use ready"
