-- Michonne Episode 1, the boat's radio (dockchesapeakebay.lua): the dials' chore times and the
-- logic values the scene's dialog checks.
local out = {}
local function ctime(getter)
  local ok, c = pcall(rawget(_G, getter) or function() end)
  if not ok or c == nil then return "nil" end
  local okT, t = pcall(ControllerGetTime, c)
  local okL, l = pcall(ControllerGetLength, c)
  return ("%s/%s"):format(tostring(okT and t), tostring(okL and l))
end
out[#out + 1] = "radio " .. ctime("DockChesapeakeBay_GetRadioController")
out[#out + 1] = "squelch " .. ctime("DockChesapeakeBay_GetSquelchController")
for _, key in ipairs({ "1DockChesapeakeBay - Radio Value", "1DockChesapeakeBay - Squelch Value",
  "1DockChesapeakeBay - Radio Tuned", "1DockChesapeakeBay - Squelch Tuned" }) do
  local ok, v = pcall(LogicGet, key)
  out[#out + 1] = key .. " = " .. tostring(ok and v)
end
local f = DEV.unwrap(DockChesapeakeBay_BeginRadioDial)
for _, name in ipairs({ "mbUsingRadioDial", "mbUsingSquelchDial", "mbHoldingLeft", "mbHoldingRight", "kImap" }) do
  out[#out + 1] = name .. " = " .. tostring(TWDA.upvalue(f, name) or TWDA.upvalue(DEV.unwrap(DockChesapeakeBay_OnRightDown), name))
end
return table.concat(out, " | ")
