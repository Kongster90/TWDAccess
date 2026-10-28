-- Development: the zombie cop (Season 1 Episode 1, dev_saves\zombiecop) up to the shotgun aiming:
-- once Lee is back at the car, take the shell, pick up the shotgun and take the dropped shell, each
-- through the reticle as soon as it is offered. It waits for DEV_COP_GO (set by cop_run.ps1 once S
-- has been held: using things before Lee is back at the car gets him caught). Logs "CS" lines.
--   .\console.ps1 -File tools\dev\cop_setup.lua
DEV_COP_GO = nil
ThreadStart(function()
  while not rawget(_G, "DEV_COP_GO") do WaitForNextFrame() end
  local t0 = TWDA.now()
  local order = { "obj_shellShotgunWD", "obj_shotgunWD", "obj_shellShotgunWD_ground" }
  local step = 1
  local tried = -10
  while step <= #order and TWDA.now() - t0 < 120 do
    local agent = AgentFind(order[step])
    local offered = false
    for _, a in ipairs(TWDA.upvalue(Reticle_Update, "mUseables") or {}) do
      if a == agent then offered = true end
    end
    if agent and offered and not AgentIsHidden(agent) and TWDA.now() - tried > 3 then
      if TWDA.useWithReticle(agent) then
        tried = TWDA.now()
        TWDA.log(("CS %.1f using %s"):format(TWDA.now() - t0, order[step]))
        TWDA.flushLog()
      end
    end
    if tried > 0 and (not agent or AgentIsHidden(agent) or not offered) then
      step = step + 1
      tried = -10
    end
    WaitForNextFrame()
  end
  TWDA.log("CS end")
  TWDA.flushLog()
end)
return "cop setup armed"
