-- Development: 400 Days' cornfield stealth (Chapter4B_Cornfield.lua). Sends the scene script's
-- own debug prints (its local consolePrint, shared by all its functions) to twda.log as CP lines,
-- and for 90 seconds logs (CF lines) each change in: Cornfield.imap active, which ui_peek_arrow
-- agents are shown, the panic meter, and Bonnie's position.
--   .\console.ps1 -File watch_cornfield.lua
local ud = TWDA.upvalue(rawget(_G, "Cornfield_OnButtonLeft"), "UpdateDirection")
for i = 1, 60 do
  local name = debug.getupvalue(ud, i)
  if not name then break end
  if name == "consolePrint" then
    debug.setupvalue(ud, i, function(...)
      local parts = {}
      for k = 1, select("#", ...) do parts[#parts + 1] = tostring((select(k, ...))) end
      TWDA.log("CP " .. table.concat(parts, " "))
    end)
  end
end
local arrows = {}
for _, a in ipairs(SceneGetAgents(TWDA.playerScene())) do
  local n = AgentGetName(a)
  if n:find("^ui_peek") then arrows[#arrows + 1] = n end
end
TWDA.log("CF arrows: " .. table.concat(arrows, " "))
ThreadStart(function()
  local t0, last, lastPos = TWDA.now(), "", -10
  local toldMap = false
  while TWDA.now() - t0 < 90 do
    local ok, err = pcall(function()
      if not toldMap and InputMapperIsActive("Cornfield.imap") then
        toldMap = true
        local binds = {}
        for i = 0, InputMapperGetNumEvents("Cornfield.imap") do
          local okI, input = pcall(InputMapperGetInput, "Cornfield.imap", i)
          local okC, cb = pcall(InputMapperGetCallback, "Cornfield.imap", i)
          if okI and input then binds[#binds + 1] = tostring(input) .. "=" .. tostring(okC and cb) end
        end
        TWDA.log("CF Cornfield.imap: " .. table.concat(binds, " "))
      end
      local shown = {}
      for _, n in ipairs(arrows) do
        if AgentIsHidden(n) == false then shown[#shown + 1] = n:gsub("^ui_peek_", "") end
      end
      local okH, hidden = pcall(SceneIsHidden, "ui_panicmeter.scene")
      local left = rawget(_G, "Cornfield_OnButtonLeft")
      local flags = ("main %s seq %s change %s okay %s dying %s"):format(tostring(Mode_IsActive(mode_Main)), tostring(TWDA.upvalue(left, "mSequenceActive")),
        tostring(TWDA.upvalue(left, "mStealthPositionChangeActive")), tostring(TWDA.upvalue(ud, "mbOkayToUpdateDirection")),
        tostring(TWDA.upvalue(ud, "mbPlayerIsDying")))
      local state = ("imap %s | shown %s | panic %s | %s"):format(tostring(InputMapperIsActive("Cornfield.imap")),
        table.concat(shown, ","), tostring(okH and not hidden), flags)
      local now = TWDA.now()
      if state ~= last or now - lastPos > 1 then
        last, lastPos = state, now
        local p = AgentGetWorldPos(TWDA.player())
        TWDA.log(("CF %.1f %s | bonnie %.1f %.1f"):format(now - t0, state, p.x, p.z))
      end
    end)
    if not ok then TWDA.log("CF error " .. tostring(err)) return end
    WaitForNextFrame()
  end
end)
return "watching"
