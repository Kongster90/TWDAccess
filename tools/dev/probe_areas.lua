-- Development probe (nineteenth session): for each Season 1 hotspot, whether its use dialog is
-- loaded where Lee is (the game's findDialogWithNode), valid (DialogManager_ItemIsValid), and
-- clickable, with its distance and position, Lee's position, and the dialog files. Logged as AREA
-- lines. For telling whether "dialog not loaded" means "in another area" (the dairy's fence).
local lee = Game_GetPlayer()
local here = AgentGetWorldPos(lee)
local getCached = TWDA.upvalue(Reticle_Update, "CachedUseableQueue_GetCached")
local onlyDialog = TWDA.upvalue(getCached, "agentIsClickableDialogOnly")
local findDialog = TWDA.upvalue(onlyDialog, "findDialogWithNode")
local key = TWDA.upvalue(onlyDialog, "kUseDialog")
local noDialog = TWDA.upvalue(Reticle_Update, "agentIsClickableNoDialog")
local out = { ("lee %.1f %.1f %.1f, key %s"):format(here.x, here.y, here.z, tostring(key)) }
for _, agent in ipairs(TWDA.upvalue(Reticle_Update, "mUseables") or {}) do
  local name = AgentGetName(agent)
  local selectable = AgentGetProperty(agent, "Game Selectable") == true
  if selectable and not AgentIsHidden(agent) then
    local p = AgentGetWorldPos(agent)
    local node = agent.mProps[key]
    local okD, dlog = pcall(findDialog, agent, node)
    local okV, valid = false, nil
    if okD and dlog then okV, valid = pcall(DialogManager_ItemIsValid, dlog, node) end
    local okC, clickable = pcall(noDialog, agent)
    out[#out + 1] = ("%s (%s): %.1f m at %.1f %.1f, node %s, dialog %s, valid %s, noDialog-clickable %s, own file %s, far use %s")
      :format(name, tostring(TWDA.hotspotName(agent)), VectorDistance(here, p), p.x, p.z, tostring(node),
        tostring(okD and dlog), tostring(okV and valid), tostring(okC and clickable),
        tostring(agent.mProps["WDUseable - Action Use Dialog File"]), tostring(agent.mProps["WDUseable - Far Use"]))
  end
end
TWDA.log("AREA " .. table.concat(out, "\nAREA "))
return #out
