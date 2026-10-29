-- Lists globals whose name matches GLOBALS_LIKE (a Lua pattern), with their types, and
-- for functions the source file and line.
local pat = rawget(_G, "GLOBALS_LIKE") or "Episode"
local out = {}
for k, v in pairs(_G) do
  if type(k) == "string" and k:find(pat) then
    local where = ""
    if type(v) == "function" then
      local info = debug.getinfo(v, "S")
      where = info and (info.short_src .. ":" .. tostring(info.linedefined)) or ""
    end
    out[#out + 1] = k .. " " .. type(v) .. " " .. where
  end
end
table.sort(out)
return table.concat(out, "\n")
