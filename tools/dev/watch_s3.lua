-- Dev console (A New Frontier): log calls (WS2 lines) to the gameplay globals that matter for the
-- mod: QTEs (quicktimeevent.lua, its UI, struggles, multi-QTEs, swipes), choices, drags, peeking,
-- death, modes, the reticle and navigation. Each function is logged at most WS2_MAX times
-- (default 40). Stays on for the whole Lua state (until the next scene change). (From
-- watch_s2.lua.)
local max = rawget(_G, "WS2_MAX") or 40
local prefixes = { "Dialog_OnChoices", "Dialog_Activate", "QTE", "StruggleQTE", "MultiQTE", "Swipe_", "Drag_",
  "Peek_", "Death", "Inventory_", "Reticle", "ChoredMovement_", "Game_PushMode", "Game_PopMode", "Game_SetMode",
  "Navigate_Enable", "Navigate_PathTo", "Game_UseAgent", "DirectControl_", "Timer", "Notification_", "Look_",
  "Station", "Range", "Logic_", "Trigger_" }
local skip = { QTE_MouseMove = true, QTE_GetQuickTimeAgents = true, MultiQTE_IsEnabled = true,
  ReticleSelection_GetUsables = true, QTE_UI_UpdateHoldTimer = true, QTE_IsTouchMode = true }
local function brief(v)
  if type(v) == "table" then
    local n = TWDA.agentName(v)
    if n ~= "" then return n end
    return "{table}"
  end
  if type(v) == "string" then return '"' .. v:sub(1, 60) .. '"' end
  return tostring(v)
end
local count, wrapped = {}, 0
local names = {}
for k, v in pairs(_G) do
  if type(k) == "string" and type(v) == "function" and not skip[k] then
    for _, p in ipairs(prefixes) do
      if k:sub(1, #p) == p and not k:find("Node", 1, true) then names[#names + 1] = k break end
    end
  end
end
for _, k in ipairs(names) do
  local original = rawget(_G, k)
  if not TWDA.wrappers[original] or true then
    local wrapper = function(...)
      count[k] = (count[k] or 0) + 1
      if count[k] <= max then
        local args = table.pack(...)
        local parts = {}
        for i = 1, math.min(args.n, 5) do parts[#parts + 1] = brief(args[i]) end
        TWDA.log(("WS2 %s(%s)"):format(k, table.concat(parts, ", ")))
      end
      return original(...)
    end
    rawset(_G, k, wrapper)
    wrapped = wrapped + 1
  end
end
return "watching " .. wrapped .. " functions"
