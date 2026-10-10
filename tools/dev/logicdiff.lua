-- Development: which of the game's logic properties (Logic_IsReady's mLogicProps, keyed by symbols)
-- each hotspot's action changes. DEV.logicKeys({ "obj_a", "obj_b" }, 1) uses each in turn with
-- action 1 through the reticle and logs "LOGICDIFF <agent>: <key>: <before> -> <after>".
--   .\console.ps1 -File tools\dev\logicdiff.lua
DEV = DEV or {}
local function snapshot()
  local P = TWDA.upvalue(Logic_IsReady, "mLogicProps")
  local out = {}
  for _, k in ipairs(PropertyGetKeys(P)) do out[tostring(k)] = tostring(P[k]) end
  return out
end
function DEV.logicKeys(names, index)
  ThreadStart(function()
    for _, name in ipairs(names) do
      local before = snapshot()
      TWDA.useWithReticle(AgentFind(name), index)
      local t0 = TWDA.now()
      while TWDA.reticleReady() and TWDA.now() - t0 < 3 do WaitForNextFrame() end
      while not TWDA.reticleReady() and TWDA.now() - t0 < 10 do WaitForNextFrame() end
      for i = 1, 30 do WaitForNextFrame() end
      local after, changes = snapshot(), {}
      for k, v in pairs(after) do
        if before[k] ~= v and not v:find("^userdata") then changes[#changes + 1] = k .. ": " .. tostring(before[k]) .. " -> " .. v end
      end
      TWDA.log("LOGICDIFF " .. name .. ": " .. (#changes == 0 and "none" or table.concat(changes, " | ")))
      TWDA.flushLog()
    end
    TWDA.log("LOGICDIFF end")
    TWDA.flushLog()
  end)
  return "diffing"
end
return "logicdiff ready"
