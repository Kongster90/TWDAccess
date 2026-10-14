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
  -- Otherwise the last part of the texture name, made readable.
  local last = key:match("_(%a[%w]*)$") or key
  return words(last)
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
    if text then return text end
  end
  local ok, value = pcall(AgentGetProperty, agent, "Text String")
  if ok and type(value) == "string" then
    local text = TWDA.cleanText(value)
    if text ~= "" then return text end
  end
  return nil
end

-- "THE WALKING DEAD: SEASON TWO" -> "The Walking Dead: Season Two". Only for text with no lower-case
-- letters at all, which speech would otherwise often spell out.
local KEEP_CAPS = { CEO = true, CTO = true, CFO = true, COO = true, SVP = true, VP = true, EVP = true, EMEA = true,
  QA = true, PR = true, UI = true, DLC = true, OG = true, TV = true, USA = true, UK = true, HDR = true, FPS = true,
  CD = true, DVD = true, RV = true, OK = true }

function TWDA.normalCaps(text)
  if type(text) ~= "string" or text:find("%l") or not text:find("%u%u") then return text end
  -- (A curly apostrophe is part of the word: "IN HARM’S WAY" is "In Harm's Way", not "Harm’S".)
  text = text:gsub("\226\128\153", "'")
  return (text:gsub("(%a)([%w']*)", function(first, rest)
    if KEEP_CAPS[first .. rest] then return first .. rest end
    return first .. rest:lower()
  end))
end

-- Joins phrases into sentences without doubling punctuation ("trust?." -> "trust?").
function TWDA.joinSentences(parts, separator)
  separator = separator or ". "
  local out = ""
  for _, part in ipairs(parts) do
    if part and part ~= "" then
      if out == "" then
        out = part
      elseif out:find("[%.!?:]$") then
        out = out .. " " .. part
      else
        out = out .. separator .. part
      end
    end
  end
  return out
end
