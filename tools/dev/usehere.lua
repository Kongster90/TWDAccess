-- Dev (Season 2 engine): use USEHERE_AGENT with the verb whose text is USEHERE_VERB where the
-- player stands (Game_UseAgent), as a click does when walking is off.
local agent = AgentFind(rawget(_G, "USEHERE_AGENT"))
local wanted = rawget(_G, "USEHERE_VERB")
ReticleVerbs_BuildVerbData(agent)
local chosen, names = nil, {}
for _, verb in ipairs(ReticleVerbs_GetAvailableVerbs() or {}) do
  local text = TWDA.keyOrText(verb.Text) or tostring(verb.Text)
  names[#names + 1] = text
  if text == wanted then chosen = verb end
end
if not chosen then return "no verb " .. tostring(wanted) .. " in " .. table.concat(names, ",") end
ThreadStart(function()
  Reticle_SelectAgent(agent)
  ReticleSelection_Lock(true)
  ReticleVerbs_SetActiveVerb(chosen)
  Game_UseAgent(agent)
end)
return "used"
