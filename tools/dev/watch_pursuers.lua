-- Development: 400 Days' cornfield (Chapter4B_Cornfield.lua). For 150 seconds logs (PU lines),
-- once a second and at each panic meter change, every shown pursuer ("Pursuer1".."Pursuer6",
-- "CelebrityPursuer1".."6") in Bonnie's frame: fwd = meters ahead of her (AgentGetForwardVec),
-- lat = meters to her right. Run watch_cornfield.lua too for the scene's own prints.
--   .\console.ps1 -File watch_pursuers.lua
local function frame()
  local player = TWDA.player()
  local okP, here = pcall(AgentGetWorldPos, player)
  local okF, fwd = pcall(AgentGetForwardVec, player)
  if not (okP and here and okF and fwd) then return nil end
  local len = math.sqrt(fwd.x * fwd.x + fwd.z * fwd.z)
  local fx, fz = fwd.x / len, fwd.z / len
  local parts = {}
  for _, base in ipairs({ "Pursuer", "CelebrityPursuer" }) do
    for i = 1, 6 do
      local name = base .. i
      local okE, exists = pcall(AgentExists, name)
      local okH, hidden = pcall(AgentIsHidden, name)
      if okE and exists and okH and not hidden then
        local okW, there = pcall(AgentGetWorldPos, name)
        if okW and there then
          local dx, dz = there.x - here.x, there.z - here.z
          -- (Right of forward in a left-handed, y-up world: (fz, -fx); the sign is checked in the log.)
          parts[#parts + 1] = ("%s fwd=%.1f lat=%.1f"):format(name, dx * fx + dz * fz, dx * fz - dz * fx)
        end
      end
    end
  end
  return ("Bonnie %.1f,%.1f facing %.2f,%.2f | %s"):format(here.x, here.z, fx, fz, table.concat(parts, "; "))
end

local last = 0
local function log(why)
  local ok, text = pcall(frame)
  TWDA.log("PU " .. why .. " " .. tostring(ok and text or text))
  last = TWDA.now()
end
TWDA.hookBefore("Chapter4B_Cornfield_PursuerPanicMeter_Activate", function(pursuer, trigger)
  log("ACTIVATE " .. tostring(pursuer and AgentGetName(pursuer) or pursuer) .. " " .. tostring(trigger and AgentGetName(trigger) or trigger))
end)
TWDA.hookBefore("Chapter4B_Cornfield_PursuerPanicMeter_Deactivate", function() log("DEACTIVATE") end)
for _, name in ipairs({ "Cornfield_OnButtonLeft", "Cornfield_OnButtonRight" }) do
  TWDA.hookBefore(name, function() log(name) end)
end
ThreadStart(function()
  local t0 = TWDA.now()
  while TWDA.now() - t0 < 150 do
    if TWDA.now() - last > 1 then log("tick") end
    Yield()
  end
  TWDA.log("PU done")
end)
return "watching pursuers"
