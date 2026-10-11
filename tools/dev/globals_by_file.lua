-- Dev console: write every global function, grouped by the script it comes from, to
-- TWDAccess\globals_<GLOBALS_TAG or "state">.txt. Tables are listed with their function fields.
local tag = rawget(_G, "GLOBALS_TAG") or "state"
local byFile = {}
local function add(file, line)
  byFile[file] = byFile[file] or {}
  table.insert(byFile[file], line)
end
local unwrap = (rawget(_G, "DEV") and DEV.unwrap) or function(f) return f end
for k, v in pairs(_G) do
  if type(k) == "string" then
    if type(v) == "function" then
      local fn = unwrap(v)
      local ok, info = pcall(debug.getinfo, fn, "S")
      local src = ok and info and info.short_src:match("[^/\\]*$") or "?"
      if src == "[C]" then src = "C" end
      local params = {}
      for i = 1, 8 do
        local name = debug.getlocal(fn, i)
        if not name then break end
        params[#params + 1] = name
      end
      add(src, k .. "(" .. table.concat(params, ",") .. ")")
    elseif type(v) == "table" and k ~= "_G" and not k:find("^TWDA") then
      local fields, src = {}, nil
      for fk, fv in pairs(v) do
        if type(fk) == "string" and type(fv) == "function" then
          fields[#fields + 1] = fk
          if not src then
            local ok, info = pcall(debug.getinfo, unwrap(fv), "S")
            src = ok and info and info.short_src:match("[^/\\]*$") or nil
          end
        end
      end
      if #fields > 0 then
        table.sort(fields)
        add(src or "?", "TABLE " .. k .. ": " .. table.concat(fields, " "))
      end
    end
  end
end
local files = {}
for f in pairs(byFile) do files[#files + 1] = f end
table.sort(files)
local out = io.open(TWDA.dir .. "globals_" .. tag .. ".txt", "w")
local total = 0
for _, f in ipairs(files) do
  table.sort(byFile[f])
  out:write("== " .. f .. "\n")
  for _, line in ipairs(byFile[f]) do out:write("  " .. line .. "\n") total = total + 1 end
end
out:close()
return total
