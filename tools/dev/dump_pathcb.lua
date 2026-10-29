-- Dev (Michonne): dump the guided path's activation callback (mRefCounterActivate.mCallback of
-- ChoredMovement_Activate) and its upvalue functions to dumps\up\pathcb.*.luac.
local rc = TWDA.upvalue(DEV.unwrap(ChoredMovement_Activate), "mRefCounterActivate")
local cb = rc and rc.mCallback
if type(cb) ~= "function" then return "no callback" end
local dir = TWDA.dir .. "dumps/up/"
local saved = {}
local function save(name, fn, depth)
  local f = io.open(dir .. name .. ".luac", "wb")
  f:write(string.dump(fn)) f:close()
  saved[#saved + 1] = name
  if depth >= 3 then return end
  local i = 1
  while true do
    local n, v = debug.getupvalue(fn, i)
    if not n then break end
    if type(v) == "function" and not saved[n] then pcall(save, name .. "." .. n, v, depth + 1) end
    i = i + 1
  end
end
save("pathcb", cb, 0)
return table.concat(saved, " ")
