-- How much the viewer steers the simulation (plan v11 E0, gap C4): every
-- pose query a headless run makes (no renderer: every query is the
-- simulation's own) turns the billboard to Roles.viewer, and a walking or
-- watchful body seen from behind shows its back frames. This counts, by the
-- module that asked (a shot, a missile, a demon's sight, a claw's contact),
-- how many queries there were and how many chose another frame than a viewer
-- in front of the body would have seen. QA instrumentation only: the pose
-- functions are wrapped for the run and put back after it.
local Pose = require('src.enemies.pose')
local Anim = require('src.enemies.animation')
local V = {}
local skipped = {
  ['src/enemies/pose.lua'] = true,
  ['src/enemies/surface.lua'] = true,
  ['src/enemies/animation.lua'] = true,
  ['src/enemies/geometry.lua'] = true,
  ['qa/viewer_influence.lua'] = true,
}
local function caller()
  for level = 3, 30 do
    local info = debug.getinfo(level, 'Sl')
    if not info then
      break
    end
    local source = (info.source or ''):gsub('^@', ''):gsub('\\', '/')
    source = source:match('(src/.+)$')
      or source:match('(qa/.+)$')
      or source:match('(tests/.+)$')
      or source
    if not skipped[source] then
      return source
    end
  end
  return '?'
end
-- The frame a viewer straight in front of the body would see.
local function frontFrame(g, e)
  local f = e.facing or 0
  local front = setmetatable({
    viewer = { x = e.x + math.sin(f) * 5, z = e.z + math.cos(f) * 5 },
  }, { __index = g })
  return (Anim.pose(front, e))
end
-- run(fn): fn() runs a scenario; returns the counts by asking module.
function V.measure(fn)
  local counts = {}
  local sample, anchor = Pose.sample, Pose.anchor
  local function count(kind, g, e)
    local key = kind .. ' ' .. caller()
    local c = counts[key] or { calls = 0, rear = 0 }
    counts[key] = c
    c.calls = c.calls + 1
    if (Anim.pose(g, e)) ~= frontFrame(g, e) then
      c.rear = c.rear + 1
    end
  end
  Pose.sample = function(g, e, out)
    count('sample', g, e)
    return sample(g, e, out)
  end
  Pose.anchor = function(g, e, name)
    count('anchor', g, e)
    return anchor(g, e, name)
  end
  local ok, err = pcall(fn)
  Pose.sample, Pose.anchor = sample, anchor
  assert(ok, err)
  return counts
end
function V.lines(name, counts)
  local keys = {}
  for key in pairs(counts) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local out, calls, rear = {}, 0, 0
  for _, key in ipairs(keys) do
    local c = counts[key]
    calls, rear = calls + c.calls, rear + c.rear
    out[#out + 1] =
      string.format('%s  %-58s calls=%d back-or-turned-frame=%d', name, key, c.calls, c.rear)
  end
  out[#out + 1] = string.format(
    '%s  TOTAL queries turned to the viewer=%d, frame chosen by the viewer=%d',
    name,
    calls,
    rear
  )
  return out
end
return V
