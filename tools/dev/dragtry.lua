-- Dev (Michonne): point at DRAGTRY_AGENT, then press the drag's hold (Drag_OnHoldPress as Enter
-- would), logging (DT lines) the selected and active drag agents and the enabled ways.
local name = rawget(_G, "DRAGTRY_AGENT")
local agent = AgentFind(name)
ThreadStart(function()
  local pos = AgentGetScreenPos(agent)
  for i = 1, 20 do TWDA.setPointer(pos.x, pos.y) WaitForNextFrame() end
  TWDA.log("DT selected=" .. TWDA.agentName(Drag_GetSelectedAgent()) .. " active=" .. TWDA.agentName(Drag_GetActiveAgent()))
  local ok, err = pcall(Drag_OnHoldPress, { code = 13, type = 0, controller = -1, x = 0, y = 0, agentName = "" }, true)
  WaitForNextFrame() WaitForNextFrame()
  local ways = {}
  for _, w in ipairs({ { "Drag_OnButtonUp", "kDirUpEnabled" }, { "Drag_OnButtonDown", "kDirDownEnabled" },
    { "Drag_OnButtonLeft", "kDirLeftEnabled" }, { "Drag_OnButtonRight", "kDirRightEnabled" } }) do
    local key = TWDA.upvalue(rawget(_G, w[1]), w[2])
    local a = TWDA.upvalue(rawget(_G, w[1]), "mActiveAgent")
    local props = type(a) == "table" and rawget(a, "mProps") or nil
    ways[#ways + 1] = w[2] .. "=" .. tostring(key) .. ":" .. tostring(props and key and props[key])
  end
  TWDA.log("DT hold ok=" .. tostring(ok) .. " " .. tostring(err) .. " active=" .. TWDA.agentName(Drag_GetActiveAgent()) .. " " .. table.concat(ways, " "))
end)
return "trying"
