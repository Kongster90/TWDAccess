-- Dev console (Season 2): the inventory's icons (upvalue mIcons of Inventory_Activate) and container.
local fn = TWDA.unwrap(Inventory_Activate)
local out = {}
local icons = TWDA.upvalue(fn, "mIcons") or {}
for i, icon in ipairs(icons) do
  local f = {}
  for k, v in pairs(icon) do
    f[#f + 1] = tostring(k) .. "=" .. (type(v) == "table" and (TWDA.agentName(v) ~= "" and TWDA.agentName(v) or "{}") or tostring(v))
  end
  table.sort(f)
  out[#out + 1] = i .. ": " .. table.concat(f, " ")
end
local container = TWDA.upvalue(fn, "mContainer")
local n = container and ContainerGetNumElements(container) or 0
for i = 0, n - 1 do out[#out + 1] = "container " .. i .. ": " .. tostring(ContainerGetElement(container, i)) end
local scene = TWDA.upvalue(fn, "mScene")
out[#out + 1] = "scene " .. tostring(scene) .. " active " .. tostring(TWDA.upvalue(fn, "mbActive"))
local sel = Buttons_GetSelected and Buttons_GetSelected(scene)
out[#out + 1] = "selected " .. TWDA.agentName(sel)
TWDA.log("INV\n" .. table.concat(out, "\n"))
return #out
