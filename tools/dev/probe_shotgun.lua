-- Development: once the shotgun aiming at the zombie cop starts (Season 1 Episode 1, mode_shotgun),
-- put the pointer at a few places and log ("PS" lines) where the cop's head is on screen: across from
-- the horizontal pan camera, and up and down from the hit test down that column (the run of points
-- where a shot would hit). Also what the cameras named cam_pan* make of the head. Written to learn
-- how far the head moves for a move of the pointer, for aiming by a tone.
--   .\console.ps1 -File tools\dev\probe_shotgun.lua     (then play to the aiming)
ThreadStart(function()
  local function active()
    local ok, names = pcall(InputMapperGetActiveMapperNames)
    for _, n in ipairs(ok and names or {}) do
      if tostring(n):lower() == "mode_shotgun.imap" then return true end
    end
    return false
  end
  local t0 = TWDA.now()
  while not active() and TWDA.now() - t0 < 300 do WaitForNextFrame() end
  if not active() then TWDA.log("PS no aiming") TWDA.flushLog() return end
  local cop, head = AgentFind("cop"), AgentFind("obj_copHead")
  local hcam = AgentFind("cam_pan_player_horizontal")
  local cams = {}
  for _, a in ipairs(SceneGetAgents(SceneGetBottomScene()) or {}) do
    local name = TWDA.agentName(a)
    if name:find("^cam") then cams[#cams + 1] = a end
  end
  local function f(v) return v and ("%.3f,%.3f"):format(v.x, v.y) or "nil" end
  local function column(x)
    local top, bottom
    for i = 0, 100 do
      local y = i / 100
      local ok, hit = pcall(AgentAtScreenPos, Vector(x, y), true, cop)
      if ok and hit == cop then
        top = top or y
        bottom = y
      end
    end
    return top, bottom
  end
  for _, x in ipairs({ 0.55, 0.6, 0.65 }) do
    for _, y in ipairs({ 0.3, 0.4, 0.5 }) do
      pcall(function() CursorSetPos(ViewportToScreen(Vector(x, y, 0))) end)
      for i = 1, 6 do WaitForNextFrame() end
      local headPos = AgentGetWorldPos(head or cop)
      local okA, across = pcall(CameraGetScreenPosFromWorldPos, hcam, headPos)
      local ax = okA and across and across.x
      local parts = {}
      for _, dx in ipairs({ -0.02, 0, 0.02 }) do
        local top, bottom = nil, nil
        if ax and ax > 0 and ax < 1 then top, bottom = column(ax + dx) end
        parts[#parts + 1] = ("%+.2f:%s-%s"):format(dx, tostring(top), tostring(bottom))
      end
      TWDA.log(("PS %.1f pointer %.2f,%.2f across %s head %s cols %s"):format(TWDA.now() - t0, x, y, okA and f(across) or "?",
        f(headPos), table.concat(parts, " ")))
      for _, c in ipairs(cams) do
        local ok, p = pcall(CameraGetScreenPosFromWorldPos, c, headPos)
        TWDA.log(("PS   cam %s %s"):format(TWDA.agentName(c), ok and f(p) or "?"))
      end
      TWDA.flushLog()
    end
  end
  TWDA.log("PS end")
  TWDA.flushLog()
end)
return "probe armed"
