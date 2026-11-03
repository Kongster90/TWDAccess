-- Turning on-screen Telltale text into something worth speaking.
local TWDA = ...

-- Button glyphs embedded in text as <ui_legend_NAME.d3dtx: offset>, and the names used by
-- Legend_Add. Named after what a keyboard player presses: the widget menus map Enter and Space to
-- the confirm button and Escape to back; the mod's hotkeys stand in for X, Y and the bumpers.
local glyphNames = {
  faceButtonDown = "Enter",
  faceButtonRight = "Escape",
  faceButtonLeft = "F9",
  faceButtonUp = "F10",
  leftShoulder = "Page Up",
  rightShoulder = "Page Down",
  leftTrigger = "Left trigger",
  rightTrigger = "Right trigger",
  start = "Menu button",
  select = "View button",
  dpad = "Arrow keys",
  -- (The Final Season's tutorial notices: "Use <ui_notification_keyboardAndMouseWasd.d3dtx> to move";
  -- the other keys are named after "keyboardAndMouse": "Shift".)
  Wasd = "W A S D",
  leftStick = "Arrow keys",
  rightStick = "Right stick",
  backIcon = "Escape",
  stickLeft = "Left stick",
  stickRight = "Right stick",
  triggerButtonLeft = "Left trigger",
  triggerButtonRight = "Right trigger",
  shoulderButtonLeft = "Page Up",
  shoulderButtonRight = "Page Down",
}
TWDA.glyphNames = glyphNames

-- Some values are drawn as images, e.g. language names in their own script.
local languageNames = {
  ChineseSimplified = "Simplified Chinese", ChineseTraditional = "Traditional Chinese",
  Traditional_Chinese = "Traditional Chinese", PortugueseBrazil = "Brazilian Portuguese",
  BrazilianPortuguese = "Brazilian Portuguese", SpanishLatinAmerica = "Latin American Spanish",
}

-- "someCamelCaseName" -> "some camel case name"
local function words(name)
  return (name:gsub("_", " "):gsub("(%l)(%u)", "%1 %2"):gsub("^%s+", ""))
end

local function glyph(name)
  local key = name:match("ui_legend_([%w_]+)") or name:match("([%w_]+)%.d3dtx") or name
  if glyphNames[key] then return glyphNames[key] end
  local language = key:match("[Ll]anguage(%u[%w_]*)$")
  if language then return languageNames[language] or words(language) end
  -- Pictures beside a label that says the same (A New Frontier's legend: "iconCopy" before "Copy").
  if key:find("^icon%u") or key:find("%lIcon$") then return "" end
  -- (The Final Season: "When you see <ui_notification_iconUseable_updated.d3dtx>, consider the
  -- consequences", the token of a thing that makes a story choice; lookaround4.lua says "choice".)
  if key:find("iconUseable_updated$") then return "a thing marked choice" end
  -- Otherwise the last part of the texture name, made readable.
  local last = key:match("_(%a[%w]*)$") or key
  last = last:gsub("^keyboardAndMouse(%u)", "%1")
  return glyphNames[last] or words(last)
end

-- Removes Telltale text markup: ^style^ codes, <texture> glyphs (spoken as the key name),
-- and leftover whitespace.
function TWDA.cleanText(text)
  if type(text) ~= "string" then return "" end
  text = text:gsub("%^[^%^]*%^", "")
  text = text:gsub("<([^>]*)>", function(inner)
    if inner:find("%.d3dtx") then return " " .. glyph(inner) .. " " end
    return " "
  end)
  -- "%A9" is the game's escape for the copyright sign (the credits).
  text = text:gsub("%%A9", "copyright ")
  text = text:gsub("%s+", " ")
  return (text:gsub("^ ", ""):gsub(" $", ""))
end

---------------------------------------------------------------------------------------------------
-- Localized text. Text agents either hold literal text ("Text String") or a dialog node name plus
-- the dialog file it lives in; the engine resolves the node when it draws the agent, and so can we.
---------------------------------------------------------------------------------------------------

local TEXT_NODE = "Text Dialog 2.0 Node Name"
local TEXT_FILE = "Text Dialog 2.0 File"
local DEFAULT_DLOG = "ui_menu.dlog"

-- Text of a dialog node, or nil if it does not resolve.
function TWDA.nodeText(node, file)
  if type(node) ~= "string" or node == "" then return nil end
  local ok, data = pcall(DlgEvaluateToNode, file or DEFAULT_DLOG, node, "text", false)
  if not ok or not data then return nil end
  local okText, text = pcall(function() return data:GetText() end)
  if okText and type(text) == "string" and text ~= "" and text ~= node then
    text = TWDA.cleanText(text)
    if text ~= "" then return text end
  end
  return nil
end

-- A string that might be a node name (as menus often pass) or literal text.
function TWDA.keyOrText(value, file)
  if type(value) ~= "string" or value == "" then return nil end
  local text = TWDA.nodeText(value, file)
  if text then return text end
  if value:find("^[%w]+_[%w_]+$") then return nil end -- an unresolved key, not text
  if value:find("^%l+%d+$") then return nil end -- an internal id such as "video01"
  text = TWDA.cleanText(value)
  return text ~= "" and text or nil
end

-- What a text agent shows, or nil.
function TWDA.agentText(agent)
  if agent == nil then return nil end
  local okNode, node = pcall(AgentGetProperty, agent, TEXT_NODE)
  if okNode and type(node) == "string" and node ~= "" then
    local _, file = pcall(AgentGetProperty, agent, TEXT_FILE)
    local text = TWDA.nodeText(node, file)
    if text then return not TWDA.isPlaceholder(text) and text or nil end
  end
  local ok, value = pcall(AgentGetProperty, agent, "Text String")
  if ok and type(value) == "string" then
    local text = TWDA.cleanText(value)
    if text ~= "" and not TWDA.isPlaceholder(text) then return text end
  end
  return nil
end

-- Layout filler left in some menus' text agents (The Final Season's Episodes screen: "Episode
-- description text here."; its import screen: "Text text text ...").
function TWDA.isPlaceholder(text)
  local lower = text:lower()
  return lower:find("description text here", 1, true) ~= nil or lower:find("^text text text") ~= nil
    or lower:find("^[a-z]+$") ~= nil and #lower > 20 and not lower:find("[aeiou][aeiou]")
end

-- The language the game shows its text in: "english", "french", "russian", "chinese"... (the
-- Display Text setting).
function TWDA.language()
  local ok, language = pcall(LangGetCurLanguage)
  return ok and type(language) == "string" and language:lower() or "english"
end

function TWDA.isEnglish()
  return TWDA.language() == "english"
end

-- What an action is in English, for the mod's checks on it (looking, talking, a blow), which go by
-- English words. The game shows actions in the player's language, but a hotspot's verb property
-- is English underneath ("Look At", shown "Regarder" in French), and an action icon's picture says
-- what it is (ui_useicon_eye.d3dtx). The mod notes each shown text with its English as it meets
-- them. In English nothing is noted.
local ICON_VERBS = { eye = "Look", ear = "Listen", talk = "Talk", sneak = "Move To", walk = "Move To",
  punch = "Punch", punchglass = "Punch", headbutt = "Headbutt", kickwindow = "Kick", hatchetchop = "Chop",
  pistolshoot = "Shoot", zombiehead_smashleft = "Smash", zombiehead_smashright = "Smash" }
-- Verb properties that are not what English shows: the Motor Inn's stations "Go", shown "Move To".
local PROP_VERBS = { go = "Move To" }
local englishVerbs = {} -- shown text -> English

function TWDA.noteVerb(shown, english)
  if type(shown) ~= "string" or type(english) ~= "string" or english == "" or shown == english then return end
  if TWDA.isEnglish() then return end
  english = english:match("^[Vv]erb_(.+)$") or english -- (a key: "verb_break")
  englishVerbs[shown] = PROP_VERBS[english:lower()] or english
end

function TWDA.noteVerbIcon(shown, icon)
  if icon == nil then return end
  local ok, name = pcall(ResourceGetName, icon)
  local word = ok and type(name) == "string" and ICON_VERBS[name:match("^ui_useicon_(.-)%.d3dtx$") or ""]
  if word then TWDA.noteVerb(shown, word) end
end

function TWDA.englishVerb(shown)
  return englishVerbs[shown] or shown
end

-- Lua's own case functions only know A to Z. The game's text is UTF-8, and its other languages
-- have capitals of two bytes: the accented Latin ones (À to Þ, not ×), Œ, and Cyrillic (Ѐ to Я).
function TWDA.lower(text)
  text = text:lower():gsub("\195([\128-\150\152-\158])", function(b) return "\195" .. string.char(b:byte() + 32) end)
  text = text:gsub("\197\146", "\197\147")
  return (text:gsub("\208([\128-\175])", function(b)
    local c = b:byte()
    if c >= 0x90 and c <= 0x9F then return "\208" .. string.char(c + 32) end -- А to П
    if c >= 0xA0 then return "\209" .. string.char(c - 32) end -- Р to Я
    return "\209" .. string.char(c + 16) -- Ѐ to Џ
  end))
end

-- The text with each capital as "A" and each small letter as "a", byte for byte, so that %u and %l
-- see the two-byte letters too ("ÉPISODE" -> "AAPISODE"). (ß has no capital: it is neither.)
local function caseShape(text)
  return (text:gsub("\195[\128-\150\152-\158]", "AA"):gsub("\197\146", "AA"):gsub("\208[\128-\175]", "AA")
    :gsub("\195[\160-\182\184-\191]", "aa"):gsub("\197\147", "aa"):gsub("\208[\176-\191]", "aa")
    :gsub("\209[\128-\159]", "aa"))
end

-- A word with its first letter kept and the rest in small letters ("ÉPISODE" -> "Épisode"). A
-- letter here is A to Z, or a character of the Latin, Cyrillic or Chinese ranges (not punctuation
-- such as « or a curly quote).
local function capitalized(word)
  local s = word:find("[%a\195-\223\228-\233]")
  if not s then return word end
  local first = word:match("^.[\128-\191]*", s)
  return word:sub(1, s + #first - 1) .. TWDA.lower(word:sub(s + #first))
end

-- "THE WALKING DEAD: SEASON TWO" -> "The Walking Dead: Season Two". Only for text with no lower-case
-- letters at all, which speech would otherwise often spell out.
local KEEP_CAPS = { CEO = true, CTO = true, CFO = true, COO = true, SVP = true, VP = true, EVP = true, EMEA = true,
  QA = true, PR = true, UI = true, DLC = true, OG = true, TV = true, USA = true, UK = true, HDR = true, FPS = true,
  CD = true, DVD = true, RV = true, OK = true, AJ = true }

function TWDA.normalCaps(text)
  if type(text) ~= "string" then return text end
  local shape = caseShape(text)
  if shape:find("%l") or not shape:find("%u%u") then return text end
  -- (A curly apostrophe is part of the word: "IN HARM’S WAY" is "In Harm's Way", not "Harm’S".)
  text = text:gsub("\226\128\153", "'")
  return (text:gsub("[%w'\128-\255]+", function(word)
    if KEEP_CAPS[word] then return word end
    return capitalized(word)
  end))
end

-- "Episode 1 Ties That Bind PART ONE" (A New Frontier) -> "... Part One": a run of words in capitals
-- inside other text reads as words. (A lone "AJ" stays.)
function TWDA.capitalRuns(text)
  local shape = caseShape(text)
  local out, at = {}, 1
  for first, last in shape:gmatch("()%u%u+ [%u ]*%u%u()") do
    out[#out + 1] = text:sub(at, first - 1)
    out[#out + 1] = (text:sub(first, last - 1):gsub("[^ ]+", capitalized))
    at = last
  end
  out[#out + 1] = text:sub(at)
  return table.concat(out)
end

-- Whether text ends a sentence: with . ! ? : or the same in Chinese (。！？：) or an ellipsis (…).
local function endsSentence(text)
  return text:find("[%.!?:]$") ~= nil or text:find("\227\128\130$") ~= nil or text:find("\239\188[\129\154\159]$") ~= nil
    or text:find("\226\128\166$") ~= nil
end

-- Joins phrases into sentences without doubling punctuation ("trust?." -> "trust?").
function TWDA.joinSentences(parts, separator)
  separator = separator or ". "
  local out = ""
  for _, part in ipairs(parts) do
    if part and part ~= "" then
      if out == "" then
        out = part
      elseif endsSentence(out) then
        out = out .. " " .. part
      else
        out = out .. separator .. part
      end
    end
  end
  return out
end
