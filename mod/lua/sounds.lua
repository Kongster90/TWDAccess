-- Sound beacons' shared parts: TWDA.tone plays a short tone through the helper (/tone: Tones.cs, a
-- small mixer, so tones overlap), and TWDA.soundDirection works out how a place in the world should
-- sound from where the camera looks: panned left or right, muffled when behind, and how far.
local TWDA = ...
local G = _G

local BASE = "http://127.0.0.1:41234"
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- opts: f (Hz, or a list played one after another), ms (each note), p (pan, -1 left to 1 right),
-- v (volume 0 to 1, scaled by the setting beepvolume), w ("s" sine, "q" square, "t" triangle, "n"
-- noise), behind (muffled).
local VOLUME_MIN, VOLUME_MAX, VOLUME_STEP = 10, 150, 10

local function volumePercent()
  local percent = tonumber(TWDA.settings.beepvolume) or 100
  return math.max(VOLUME_MIN, math.min(VOLUME_MAX, percent))
end

function TWDA.tone(opts)
  local f = type(opts.f) == "table" and table.concat(opts.f, ",") or tostring(opts.f or 880)
  local v = (opts.v or 0.3) * volumePercent() / 100
  local url = ("%s/tone?f=%s&ms=%d&p=%.2f&v=%.3f&w=%s&lp=%d"):format(BASE, f, math.floor(opts.ms or 60),
    math.max(-1, math.min(1, opts.p or 0)), math.max(0, math.min(1, v)), opts.w or "s",
    opts.behind and 1 or 0)
  pcall(HttpGetAsync, url)
end

-- F3 (louder) and Shift+F3 (quieter): the beeps' volume, said and then heard (a blip in the middle).
function TWDA.changeBeepVolume(louder)
  local before = volumePercent()
  local after = math.max(VOLUME_MIN, math.min(VOLUME_MAX, before + (louder and VOLUME_STEP or -VOLUME_STEP)))
  TWDA.settings.beepvolume = after
  if TWDA.saveSettings then TWDA.saveSettings() end
  local text = ("Beeps %d percent."):format(after)
  if after == before then text = (louder and "Beeps loudest, %d percent." or "Beeps quietest, %d percent."):format(after) end
  TWDA.say(text, { interrupt = true })
  TWDA.tone({ f = 1200, ms = 60, v = 0.3 })
end

local function call(name, ...)
  local fn = rawget(G, name)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

-- The camera's facing on the ground: forward and right, unit vectors in x and z.
local function cameraAxes()
  local player = TWDA.player()
  local camera = player and call("AgentGetCamera", player)
  if camera == nil then
    local okC, c = pcall(function() return SceneGetCamera(TWDA.playerScene()) end)
    camera = okC and c or nil
  end
  if camera == nil then return nil end
  local okF, f = pcall(AgentGetForwardVec, camera, true)
  local okR, r = pcall(AgentGetRightVec, camera, true)
  if not (okF and f and okR and r) then return nil end
  local fl = math.sqrt(f.x * f.x + f.z * f.z)
  local rl = math.sqrt(r.x * r.x + r.z * r.z)
  if fl < 0.0001 or rl < 0.0001 then return nil end
  return { fx = f.x / fl, fz = f.z / fl, rx = r.x / rl, rz = r.z / rl }
end

-- For a point in the world: { angle (radians, 0 ahead, positive to the right, up to pi behind),
-- pan (-1 to 1), behind, distance (meters, on the ground) }; nil when there is no camera.
function TWDA.soundDirection(point)
  local axes = cameraAxes()
  local okP, here = pcall(AgentGetWorldPos, TWDA.player())
  if not axes or not okP or not here or not point then return nil end
  local dx, dz = point.x - here.x, point.z - here.z
  local distance = math.sqrt(dx * dx + dz * dz)
  local ahead = dx * axes.fx + dz * axes.fz
  local right = dx * axes.rx + dz * axes.rz
  local angle = atan2(right, ahead)
  return { angle = angle, pan = math.sin(angle), behind = math.abs(angle) > math.pi / 2 + 0.2,
    distance = distance }
end
