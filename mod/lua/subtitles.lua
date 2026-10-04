-- Spoken subtitles. The game registers Subtitle_OnCreate with SubtitleSetCreateCallback, and the
-- engine calls it by name for every line, so wrapping that global sees every subtitle.
local TWDA = ...

local function describe(subtitle)
  local okText, text = pcall(SubtitleGetText, subtitle)
  local okName, speaker = pcall(SubtitleGetAgentName, subtitle)
  text = okText and type(text) == "string" and TWDA.cleanText(text) or ""
  speaker = okName and type(speaker) == "string" and speaker or ""
  return speaker, text
end

TWDA.hookBefore("Subtitle_OnCreate", function(subtitle)
  local speaker, text = describe(subtitle)
  TWDA.log(("subtitle [%s] %s"):format(speaker, text))
  if text == "" then return end
  TWDA.lastSubtitle = speaker ~= "" and (speaker .. ": " .. text) or text
  local mode = TWDA.settings.subtitles
  if mode == "full" then
    TWDA.say(TWDA.lastSubtitle)
  elseif mode == "speaker" and speaker ~= "" then
    TWDA.say(speaker)
  end
end)
