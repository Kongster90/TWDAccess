-- Dev console (The Final Season): for 80 s, log (PW lines, on change) the guided path: chore time and
-- length, the forward key (GetRelativeDirection), the keys held, the game's move value and the move
-- agent's "Chored Movement - Reverse Controls".
--   .\console.ps1 -File watch_path4.lua
local start = GetTotalTime()
ThreadStart(function()
  local last = ""
  while GetTotalTime() - start < 80 do
    local line = "off"
    if ChoredMovement_IsActive() then
      local c = ChoredMovement_GetController()
      local t, l = c and ControllerGetTime(c), c and ControllerGetLength(c)
      local act = TWDA.upvalue(ChoredMovement_Start, "Activate")
      local opu = act and TWDA.upvalue(act, "OnPostUpdate")
      local grd = opu and TWDA.upvalue(opu, "GetRelativeDirection")
      local fwd = "?"
      if grd then for _, k in ipairs({{"W",0,1},{"S",0,-1},{"A",-1,0},{"D",1,0}}) do if grd(Vector(k[2],k[3],0)) == 1 then fwd = k[1] end end end
      local keys = ""
      for _, k in ipairs({{"W",0x57},{"A",0x41},{"S",0x53},{"D",0x44}}) do if InputPCIsVKeyPressed(k[2]) then keys = keys .. k[1] end end
      line = string.format("t=%.2f/%.2f fwd=%s held=%s move=%s rev=%s", t or -1, l or -1, fwd, keys, tostring(ChoredMovement_GetMoveDir()), tostring(AgentGetProperty(TWDA.player(), "Chored Movement - Reverse Controls")))
    end
    if line ~= last then TWDA.log("PW " .. line) last = line end
    local s = GetTotalTime()
    while GetTotalTime() - s < 0.25 do WaitForNextFrame() end
  end
end)
return "pathwatch"
