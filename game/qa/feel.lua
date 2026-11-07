-- The feel meter (PLAN E0): what a player sees, frame by frame, for a scripted
-- set of inputs at a chosen display rate. It runs the application's own loop
-- (fixed 1/120 s steps, the capture before the last step, the interpolated
-- sample that the renderer and the HUD draw) and reads only that sample, so
-- every number below is a property of the shown image, not of the simulation.
-- Nothing here changes gameplay; it is a measuring instrument for the tests.
local Presentation = require('src.render.presentation')
local Intent = require('src.player.intent')
local Rate = require('src.core.rate')
local Pose = require('src.enemies.pose')
local Context = require('src.session.context')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local Feel = {}
-- Display rates measured: below, at and above the simulation's 120 Hz.
Feel.rates = { 30, 60, 120, 144, 165, 240 }
-- An uneven display: a repeating pattern of frame times (s) around 144 Hz.
Feel.uneven = { 1 / 144, 1 / 97, 1 / 211, 1 / 144, 1 / 130, 1 / 175 }
-- Two shown values closer than this are the same picture.
Feel.still = 1e-9
-- The frame times of a run: a rate (Hz) or an explicit repeating pattern.
local function frameTime(rate, i)
  if type(rate) == 'table' then
    return rate[(i - 1) % #rate + 1]
  end
  return 1 / rate
end
Feel.frameTime = frameTime
-- Run session g for `seconds` of display time.
--   script(t, frame, g) -> input table for this display frame (held controls),
--     and optionally a list of edges: 'fire' (a click), any other key is set
--     for the first simulation step only, as the application does for dash/slide.
--   probes: { name = function(shown, g) -> number } read from the drawn sample.
-- Returns { time = {...}, input = {...}, [name] = {...} } per display frame.
function Feel.run(g, rate, seconds, script, probes)
  local step = Rate.step
  local trace = { time = {}, frames = 0 }
  for name in pairs(probes) do
    trace[name] = {}
  end
  local accumulator, t, i = 0, 0, 0
  while t < seconds - 1e-12 do
    i = i + 1
    local dt = frameTime(rate, i)
    t = t + dt
    local input, edges = script(t, i, g)
    input = input or {}
    for _, edge in ipairs(edges or {}) do
      if edge == 'fire' then
        Intent.queue(g, 'fire', nil)
      else
        input[edge] = true
      end
    end
    accumulator = math.min(0.20, accumulator + dt)
    while accumulator >= step do
      if accumulator - step < step then
        Presentation.capture(g)
      end
      g:update(step, input)
      input.dash, input.slide = false, false
      accumulator = accumulator - step
    end
    local shown = Presentation.sample(g, accumulator / step)
    trace.time[i] = t
    for name, probe in pairs(probes) do
      trace[name][i] = probe(shown, g)
    end
  end
  trace.frames = i
  return trace
end
-- A frozen picture inside motion: the value did not change on frame i while it
-- moved the same way, by a similar step, on the frames on both sides. Pauses
-- longer than one frame (a stop, a windup), a turn at a peak and a hold next to a
-- change of painted frame (a step several times larger) are not a stutter.
Feel.steady = 4
function Feel.stalls(series)
  local count, first = 0, nil
  local still = Feel.still
  for i = 3, #series - 1 do
    local before = series[i - 1] - series[i - 2]
    local now = math.abs(series[i] - series[i - 1])
    local after = series[i + 1] - series[i]
    if now <= still and math.abs(before) > still and math.abs(after) > still then
      local small, large =
        math.min(math.abs(before), math.abs(after)), math.max(math.abs(before), math.abs(after))
      if (before > 0) == (after > 0) and large <= small * Feel.steady then
        count = count + 1
        first = first or i
      end
    end
  end
  return count, first
end
-- Display frames from frame `from` until the value first visibly changes; nil if never.
function Feel.latency(series, from)
  local base = series[from - 1] or series[from]
  for i = from, #series do
    if math.abs(series[i] - base) > Feel.still then
      return i - from
    end
  end
end
-- The largest excursion from rest after frame `from`, its frame, and the time (s)
-- until the value stays within `share` of that excursion for good.
function Feel.settle(series, times, from, share)
  local peak, at = 0, from
  for i = from, #series do
    if math.abs(series[i]) > math.abs(peak) then
      peak, at = series[i], i
    end
  end
  local limit = math.abs(peak) * (share or 0.02)
  local settled = #series
  for i = #series, at, -1 do
    if math.abs(series[i]) > limit then
      break
    end
    settled = i
  end
  return peak, at, times[settled] - times[from]
end
-- The ratio of the largest to the smallest per-frame step of a steady motion
-- between frames a and b: 1 is perfectly even; a stutter shows as a large ratio.
function Feel.evenness(series, a, b)
  local low, high = math.huge, 0
  for i = a + 1, b do
    local d = math.abs(series[i] - series[i - 1])
    low, high = math.min(low, d), math.max(high, d)
  end
  return low > 0 and high / low or math.huge
end
-- Probes of the drawn sample.
function Feel.knight(key)
  return function(shown)
    return shown.player[key] or 0
  end
end
function Feel.view(key)
  return function(shown)
    return shown.view[key] or 0
  end
end
-- The drawn sprite of creature e: its height off the floor and its frame.
local placement = {}
local function sprite(shown, e)
  for _, view in ipairs(Pools.of(shown, 'enemies')) do
    if rawequal(getmetatable(view) and getmetatable(view).__index, e) or view == e then
      local p = Pose.sample(shown, view, placement, Context.viewer(shown))
      return p, view
    end
  end
end
function Feel.spriteHeight(e)
  return function(shown)
    local p, view = sprite(shown, e)
    return p and (p.baseY + Ground.of(shown.world, view)) or 0
  end
end
-- The continuous part of the drawn pose (enemies/animation.lua: Anim.pose): lift
-- off the floor, lean and stretch. The painted frame itself changes in steps.
local Animation = require('src.enemies.animation')
local function posed(shown, e)
  for _, view in ipairs(Pools.of(shown, 'enemies')) do
    if rawequal(getmetatable(view) and getmetatable(view).__index, e) or view == e then
      local _, bounce, lean, sx, sy = Animation.pose(shown, view, Context.viewer(shown))
      return bounce, lean, sx + sy
    end
  end
  return 0, 0, 0
end
function Feel.spriteLift(e)
  return function(shown)
    return (posed(shown, e))
  end
end
function Feel.spriteLean(e)
  return function(shown)
    return select(2, posed(shown, e))
  end
end
function Feel.spriteScale(e)
  return function(shown)
    return select(3, posed(shown, e))
  end
end
function Feel.spriteX(e)
  return function(shown)
    local _, view = sprite(shown, e)
    return view and view.x or 0
  end
end
function Feel.spriteZ(e)
  return function(shown)
    local _, view = sprite(shown, e)
    return view and view.z or 0
  end
end
return Feel
