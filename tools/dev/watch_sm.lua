-- Dev console (Michonne): log calls (WS2 lines) to the gameplay globals that matter for the mod:
-- QTEs (quicktimeevent.lua and its UI, timed buttons), deadly focus, struggles, button mashes,
-- multi-QTEs, swipes, drags, peeking, stations, death, modes, the reticle and navigation. Each
-- function is logged at most WS2_MAX times (default 40). Stays on for the whole Lua state (until
-- the next scene change); copy to <game>\TWDAccess\autorun.lua to watch every state. (From
-- watch_s2.lua and watch_s4.lua.)
local max = rawget(_G, "WS2_MAX") or 40
local prefixes = { "DeadlyFocus_", "QTE", "MultiQTE", "Struggle_", "ButtonMash_", "Swipe_", "Drag_", "Peek_", "Station_",
  "Death", "Inventory_", "Reticle_Enable", "Reticle_Select", "ReticleSelection_Lock", "ChoredMovement_",
  "Game_PushMode", "Game_PopMode", "Game_SetMode", "Navigate_Enable", "Navigate_PathTo", "Game_UseAgent",
  "DirectControl_Enable", "DirectControl_SetConstrained", "Timer", "Notification_", "Look_SetFocus", "Action",
  "Dialog_OnChoices", "Dialog_Activate", "CloseUp_" }
local skip = { QTE_MouseMove = true, QTE_IsTouchMode = true, QTE_GetAgents = true, DeadlyFocus_GetDFActivated = true,
  DeadlyFocus_GetDFMode = true, DeadlyFocus_GetHold = true, DeadlyFocus_GetPoints = true, DeadlyFocus_GetPrompt = true,
  Drag_GetActiveAgent = true, Drag_IsEnabled = true, Drag_GetSelectedAgent = true, ChoredMovement_IsActive = true,
  ChoredMovement_GetController = true, ChoredMovement_GetTimePercent = true, Peek_IsPeeking = true,
  Peek_IsTransitioning = true, Death_InProgress = true, Action_OnMouseMove = true, Action_GetActiveActions = true,
  -- (Called every frame by the mod's own polling or the reticle.)
  Look_SetFocus = true, Reticle_SelectAgent = true, Drag_SelectAgent = true, Drag_DisableProximity = true,
  Station_AllowExit = true, Drag_IsDragAgent = true, Struggle_OnMash = true, ButtonMash_DoTheMash = true,
  Struggle_OnSwipe = true, ChoredMovement_IsPathing = true, ChoredMovement_SetJoystickDirection = true }
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
return "watching " .. wrapped .. " functions"
