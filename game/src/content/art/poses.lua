-- Named poses of a painted atlas (plan v11 E1): which frames of its sheet a
-- creature shows in each state, chosen by an explicit clock. A sheet names
-- them (content/art/sheets/<id>.lua: poses), the animation asks for them by
-- name (enemies/animation.lua) and never knows a frame number or a layout.
--   pose = { clock, frames, bounds? | rate? | step?, ends?, offset? }
--   clock    what chooses the frame (a pose of one frame needs none):
--              action     the action's normalized phase, 0..1 (ActionPhase)
--              seconds    seconds since the state began
--              countdown  minus the seconds the state has left (rising to 0)
--              stride     metres walked (the walk clock, e.walk)
--              world      world time, shifted by offset x the body's id
--              breath     the quiet breathing of the sheet's idle frames
--   bounds   inner boundaries of half-open intervals [a, b): frame i holds
--            from bounds[i - 1] up to (not including) bounds[i]; a value on
--            a boundary belongs to the next frame
--   rate     cycles frames: floor(clock x rate) mod #frames
--   step     one frame every step seconds, the last held
--   ends     the clock value where the pose is over (the state goes on in
--            another pose: a knockdown in its rise)
-- A pose may instead be { fallback = '<name>' }; a pose a sheet leaves out
-- falls back by Poses.fallbacks ('strike.<attack>' falls back to 'strike').
local Poses = {}
Poses.clocks = {
  action = true,
  seconds = true,
  countdown = true,
  stride = true,
  world = true,
  breath = true,
}
-- The clock every named pose is chosen by.
Poses.clockOf = {
  walk = 'stride',
  walkRear = 'stride',
  quiet = 'breath',
  windup = 'action',
  strike = 'action',
  recover = 'action',
  pain = 'seconds',
  painHeavy = 'seconds',
  knockdown = 'seconds',
  rise = 'countdown',
  collapse = 'seconds',
  hover = 'world',
  hoverRear = 'world',
}
-- Every sheet answers these, itself or through its fallbacks.
Poses.required = {
  'walk',
  'walkRear',
  'watchRear',
  'quiet',
  'windup',
  'strike',
  'recover',
  'pain',
  'painHeavy',
  'knockdown',
  'rise',
  'collapse',
}
Poses.fallbacks = {
  walkRear = 'walk',
  watchRear = 'quiet',
  painHeavy = 'pain',
  hover = 'walk',
  hoverRear = 'walkRear',
}
local function clockOf(name)
  return Poses.clockOf[name]
    or ((name:match('^strike%.') or name:match('^windup%.')) and 'action')
    or nil
end
local function fallbackOf(poses, name)
  local entry = poses[name]
  if entry and entry.fallback then
    return entry.fallback
  end
  if entry then
    return nil
  end
  return Poses.fallbacks[name]
    or (name:match('^strike%.') and 'strike')
    or (name:match('^windup%.') and 'windup')
    or nil
end
-- The pose a name stands for (its fallbacks followed), or nil.
function Poses.resolve(poses, name)
  for _ = 1, 16 do
    local entry = poses[name]
    if entry and not entry.fallback then
      return entry
    end
    name = fallbackOf(poses, name)
    if not name then
      return nil
    end
  end
  return nil
end
-- The index into pose.frames at clock value v, or nil once the pose ends.
function Poses.index(pose, v)
  if pose.ends and v >= pose.ends then
    return nil
  end
  local n = #pose.frames
  if pose.rate then
    return math.floor(v * pose.rate) % n + 1
  elseif pose.step then
    return math.min(n, math.floor(v / pose.step) + 1)
  end
  local bounds, i = pose.bounds, 1
  if bounds then
    while i <= #bounds and v >= bounds[i] do
      i = i + 1
    end
  end
  return i
end
-- The frame of the atlas at clock value v, or nil once the pose ends.
function Poses.frame(pose, v)
  local i = Poses.index(pose, v)
  return i and pose.frames[i]
end
-- The problems of a list of boundaries in [low, high] (strictly rising);
-- also the thresholds of ability art (content/ability_art.lua: timing).
function Poses.boundsProblems(bounds, low, high)
  local out = {}
  for i, b in ipairs(bounds) do
    if type(b) ~= 'number' or b ~= b then
      out[#out + 1] = 'boundary ' .. i .. ' is not a number'
    elseif (low and b < low) or (high and b > high) then
      out[#out + 1] = 'boundary ' .. i .. ' outside its clock'
    elseif i > 1 and type(bounds[i - 1]) == 'number' and b <= bounds[i - 1] then
      out[#out + 1] = 'boundaries do not rise at ' .. i
    end
  end
  return out
end
local DOMAINS = {
  action = { 0, 1 },
  seconds = { 0 },
  countdown = { nil, 0 },
  stride = { 0 },
  world = {},
  breath = { 0, 1 },
}
local function poseProblems(name, pose, frameCount, fail)
  local frames = pose.frames
  if type(frames) ~= 'table' or #frames == 0 then
    return fail(name .. ': no frames')
  end
  for i, f in ipairs(frames) do
    if type(f) ~= 'number' or f % 1 ~= 0 or f < 1 or f > frameCount then
      fail(name .. ': frame ' .. i .. ' (' .. tostring(f) .. ') is not in the sheet')
    end
  end
  local forms = (pose.bounds and 1 or 0) + (pose.rate and 1 or 0) + (pose.step and 1 or 0)
  if forms > 1 then
    fail(name .. ': bounds, rate and step exclude each other')
  end
  local clock = pose.clock
  if (#frames > 1 or forms > 0 or pose.ends) and not clock then
    fail(name .. ': a pose of several frames names its clock')
  end
  if clock and not Poses.clocks[clock] then
    fail(name .. ': unknown clock ' .. tostring(clock))
  end
  local wanted = clockOf(name)
  if clock and wanted and clock ~= wanted then
    fail(name .. ': chosen by the ' .. wanted .. ' clock, not ' .. clock)
  end
  if pose.bounds then
    if type(pose.bounds) ~= 'table' or #pose.bounds ~= #frames - 1 then
      fail(name .. ': ' .. #frames .. ' frames need ' .. (#frames - 1) .. ' boundaries')
    else
      local domain = DOMAINS[clock] or {}
      for _, problem in ipairs(Poses.boundsProblems(pose.bounds, domain[1], domain[2])) do
        fail(name .. ': ' .. problem)
      end
    end
  elseif #frames > 1 and forms == 0 and clock ~= 'breath' then
    fail(name .. ': ' .. #frames .. ' frames need boundaries, a rate or a step')
  end
  if pose.rate ~= nil and not (type(pose.rate) == 'number' and pose.rate > 0) then
    fail(name .. ': rate must be positive')
  end
  if pose.step ~= nil and not (type(pose.step) == 'number' and pose.step > 0) then
    fail(name .. ': step must be positive')
  end
  if pose.ends ~= nil then
    local last = pose.bounds and pose.bounds[#pose.bounds]
    if type(pose.ends) ~= 'number' or (last and pose.ends <= last) then
      fail(name .. ': ends must follow the last boundary')
    end
  end
end
-- What is wrong with the poses of a sheet of frameCount frames: every pose,
-- every fallback (an existing pose, no cycle) and every required pose.
function Poses.problems(poses, frameCount, where)
  local out = {}
  local function fail(message)
    out[#out + 1] = (where or 'poses') .. ': ' .. message
  end
  if type(poses) ~= 'table' then
    fail('no poses')
    return out
  end
  local names = {}
  for name in pairs(poses) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local pose = poses[name]
    if type(pose) ~= 'table' then
      fail(name .. ': not a pose')
    elseif pose.fallback then
      if type(pose.fallback) ~= 'string' then
        fail(name .. ': fallback is not a name')
      end
    else
      poseProblems(name, pose, frameCount, fail)
    end
  end
  -- Fallback chains: depth-first, each name followed until a pose.
  local state = {}
  local function visit(name, path)
    if state[name] == 'done' then
      return
    end
    if state[name] == 'open' then
      fail('fallback cycle ' .. table.concat(path, ' -> ') .. ' -> ' .. name)
      return
    end
    state[name] = 'open'
    path[#path + 1] = name
    local entry = poses[name]
    if not (entry and not entry.fallback) then
      local next = fallbackOf(poses, name)
      if not next then
        fail('missing pose ' .. name)
      else
        visit(next, path)
      end
    end
    path[#path] = nil
    state[name] = 'done'
  end
  for _, name in ipairs(names) do
    visit(name, {})
  end
  for _, name in ipairs(Poses.required) do
    visit(name, {})
  end
  return out
end
return Poses
