-- On-screen text as the game writes it: hints and notifications are read as they appear, and other
-- modules (choices) can watch every text write through TWDA.onTextProperty.
local TWDA = ...

TWDA.onTextProperty = TWDA.onTextProperty or {}

function TWDA.agentName(agent)
  if type(agent) == "string" then return agent end
  if agent == nil then return "" end
  local ok, name = pcall(AgentGetName, agent)
  if ok and type(name) == "string" then return name end
  return ""
end

-- Speaking the same text again within a moment is noise (the game often sets a label twice).
local lastText, lastTime = nil, -10
function TWDA.sayOnce(text, opts)
  if text == lastText and TWDA.now() - lastTime < 2 then return end
  lastText, lastTime = text, TWDA.now()
  TWDA.say(text, opts)
end

-- Text agents read aloud as soon as their text changes (tutorial hints, choice notifications).
local SPOKEN = { "helptext", "notification", "notify", "tutorial", "hint", "choicemade", "nowplaying" }

local function spokenAgent(name)
  name = name:lower()
  for _, pattern in ipairs(SPOKEN) do
    if name:find(pattern, 1, true) then return true end
  end
  return false
end

TWDA.hookGlobal("AgentSetProperty", function(original)
  return function(agent, prop, value, ...)
    if prop == "Text String" and type(value) == "string" then
      local ok, err = pcall(function()
        local name = TWDA.agentName(agent)
        for _, handler in pairs(TWDA.onTextProperty) do handler(name, value) end
        if spokenAgent(name) then
          local text = TWDA.cleanText(value)
          if text ~= "" then
            TWDA.lastHint = text
            TWDA.sayOnce(text)
          end
        end
      end)
      if not ok then TWDA.log("text hook: " .. tostring(err)) end
    end
    return original(agent, prop, value, ...)
  end
end)
