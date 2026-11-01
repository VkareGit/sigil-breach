-- Named poses and the corpse rule (plan v11 E1). A sheet names the frames of
-- every state and the clock that chooses them; a broken sheet is refused by
-- name before it registers. Reordering an atlas's frames (its poses,
-- anatomy and masks with them) changes nothing in play; a longer painted
-- collapse changes what is drawn, never how long a body shields or when it
-- lands. Test-only: every registration is undone.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
local function copy(value)
  if type(value) ~= 'table' then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = copy(v)
  end
  return out
end
local DERIVED = { 'sheets', 'layouts', 'entries', 'idle', 'poses' }
-- Register sheet in place of the atlas of the same id, keeping its place
-- in the list of atlases; returns what it replaced (restore puts it back,
-- the same tables, so the sealed definitions see no change).
local function swap(Atlases, sheet)
  local place, saved = nil, {}
  for index, kind in ipairs(Atlases.kinds) do
    if kind == sheet.id then
      place = index
    end
  end
  for _, field in ipairs(DERIVED) do
    saved[field] = Atlases[field][sheet.id]
  end
  saved.sizes = {}
  for _, source in ipairs(saved.sheets.sources) do
    saved.sizes[source.path] = Atlases.sizes[source.path]
  end
  Atlases.unregister(sheet.id)
  Atlases.register(sheet)
  table.remove(Atlases.kinds)
  table.insert(Atlases.kinds, place, sheet.id)
  return saved
end
local function restore(Atlases, id, saved)
  for _, field in ipairs(DERIVED) do
    Atlases[field][id] = saved[field]
  end
  for path, size in pairs(saved.sizes) do
    Atlases.sizes[path] = size
  end
end
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'named poses: ', 'named poses: ')
  local Atlases = require('src.content.art.atlases')
  local Sheet = require('src.content.art.sheet')
  local Poses = require('src.content.art.poses')
  local Anim = require('src.enemies.animation')
  local Corpse = require('src.enemies.corpse')
  local A = require('src.content.enemies')

  -- Every shipped sheet names its poses; every required pose resolves.
  local complete = true
  for _, id in ipairs(Atlases.kinds) do
    complete = complete and #Sheet.problems(Atlases.sheets[id]) == 0
    for _, name in ipairs(Poses.required) do
      complete = complete and Poses.resolve(Atlases.poses[id], name) ~= nil
    end
  end
  check('every atlas names all its poses, itself or through fallbacks', complete)
  check(
    'a pose a sheet leaves out falls back (painHeavy to pain, watchRear to quiet)',
    Poses.resolve({ pain = { frames = { 3 } } }, 'painHeavy').frames[1] == 3
      and Poses.resolve({ quiet = { clock = 'breath', frames = { 9 } } }, 'watchRear').clock
        == 'breath'
  )
  check(
    'a value on a boundary belongs to the next frame',
    Poses.frame(Atlases.poses.imp.windup, 0.22) == 8
      and Poses.frame(Atlases.poses.imp.windup, 0.22 - 1e-9) == 7
  )

  -- Negative: a broken sheet is refused, by name, before it registers.
  local function refused(label, change, expected)
    local sheet = copy(Atlases.sheets.imp)
    sheet.id = 'trial_broken'
    change(sheet.poses)
    local problems = table.concat(Sheet.problems(sheet), '\n')
    local ok = pcall(Atlases.register, sheet)
    check(
      'a sheet with ' .. label .. ' is refused before registration (' .. expected .. ')',
      not ok and problems:find(expected, 1, true) ~= nil and Atlases.sheets.trial_broken == nil
    )
  end
  refused('falling boundaries', function(poses)
    poses.windup.bounds = { 0.6, 0.22 }
  end, 'windup: boundaries do not rise')
  refused('a frame outside the sheet', function(poses)
    poses.strike.frames = { 10, 99 }
  end, 'strike: frame 2 (99) is not in the sheet')
  refused('an empty sequence', function(poses)
    poses.recover.frames = {}
  end, 'recover: no frames')
  refused('a fallback cycle', function(poses)
    poses.painHeavy = { fallback = 'trialPain' }
    poses.trialPain = { fallback = 'painHeavy' }
  end, 'fallback cycle')
  refused('a missing required pose', function(poses)
    poses.rise = nil
  end, 'missing pose rise')
  refused('an action boundary past its clock', function(poses)
    poses.windup.bounds = { 0.22, 1.5 }
  end, 'windup: boundary 2 outside its clock')
  refused('a pose chosen by another clock', function(poses)
    poses.windup.clock = 'seconds'
  end, 'windup: chosen by the action clock')
  local AbilityArt = require('src.content.ability_art')
  check(
    'ability thresholds pass the same boundary check (and a falling one is refused)',
    #AbilityArt.timingProblems(AbilityArt.timing) == 0
      and #AbilityArt.timingProblems({
          coil = 0.5,
          launch = 0.2,
          land = 0.8,
          rise = 0.3,
          evade = { 0.1, 0.05 },
        })
        == 2
  )

  -- Reordering: buer's action frames reversed, with its poses, anatomy and
  -- masks; the drill (every demon, buer among them) plays exactly as 0.33.
  local Anatomy = require('src.content.art.anatomy_regions')
  local Masks = require('src.content.art.hit_masks')
  local original = Atlases.sheets.buer
  local count = Atlases.entries.buer.originalCount
  local function moved(frame)
    return frame <= count and count + 1 - frame or frame
  end
  local reversed = copy(original)
  for index = 1, count do
    reversed.frames[index] = copy(original.frames[moved(index)])
  end
  for _, pose in pairs(reversed.poses) do
    for i, frame in ipairs(pose.frames or {}) do
      pose.frames[i] = moved(frame)
    end
  end
  local anatomy, masks = Anatomy.layouts.buer, Masks.layouts.buer
  local reordered, rebaked = { frames = {} }, {}
  for k, v in pairs(anatomy) do
    if k ~= 'frames' then
      reordered[k] = v
    end
  end
  for index = 1, #anatomy.frames do
    reordered.frames[index] = anatomy.frames[moved(index)]
    rebaked[index] = masks[moved(index)]
  end
  local Projection = require('qa.state_projection')
  local reference = love.filesystem.read('tests/fixtures/v033/projection-drill.txt')
  local saved
  local ok, difference = pcall(function()
    saved = swap(Atlases, reversed)
    Anatomy.layouts.buer, Masks.layouts.buer = reordered, rebaked
    local recorder = Projection.recorder(120)
    require('qa.scenarios.drill').run(
      require('tests.support.v033_encounters').game(G),
      recorder.observe,
      40
    )
    return Projection.compare(reference, recorder.text())
  end)
  if saved then
    restore(Atlases, 'buer', saved)
  end
  Anatomy.layouts.buer, Masks.layouts.buer = anatomy, masks
  check(
    'buer with its frames reversed plays the drill exactly as 0.33 ('
      .. tostring(ok and (difference or 'equal') or difference)
      .. ')',
    ok and difference == nil and Atlases.sheets.buer == original
  )
  check('the original atlas is back in its place', Atlases.kinds[4] == 'buer')

  -- The corpse rule: two more painted collapse frames change the drawing,
  -- not how long the body shields or when it lands.
  local Creature = require('src.content.defs.creature')
  Fixtures.words({ trial_fall = 'Trial Fall' })
  local long = copy(Atlases.sheets.imp)
  long.id = 'trial_fall'
  long.poses.collapse.frames = { 14, 15, 16, 17, 18, 17, 18 }
  Atlases.register(long)
  Anatomy.layouts.trial_fall, Masks.layouts.trial_fall = Anatomy.layouts.imp, Masks.layouts.imp
  A.register(Creature.define({
    extends = A.imp,
    id = 'trial_fall',
    kind = 'imp',
    variant = 'trial_fall',
    name = 'trial_fall',
    appearance = { atlas = 'trial_fall' },
  }))
  local same, drawn = true, false
  local settle = A.imp.body.corpse.settle
  for _, t in ipairs({ 0, 0.1, 0.22, 0.3, settle - 1e-9, settle, settle + 1e-9, 0.6, 0.8, 2 }) do
    local short = { id = 1, kind = 'imp', hp = 0, deathTime = t, fallY = 0, fallVY = 0 }
    local longer =
      { id = 1, kind = 'imp', variant = 'trial_fall', hp = 0, deathTime = t, fallY = 0, fallVY = 0 }
    same = same
      and Corpse.shields(short) == Corpse.shields(longer)
      and Corpse.landing(short) == Corpse.landing(longer)
    local g = { time = 0, player = { x = 0, z = 5 } }
    drawn = drawn or (Anim.pose(g, short)) ~= (Anim.pose(g, longer))
  end
  check(
    'a longer painted collapse is drawn but shields and lands exactly as before',
    same and drawn and Corpse.landing({ kind = 'imp' }) == 0.22
  )
  -- A body thrown up past its settling still shields; landing ends it in the
  -- step its lying condition holds, with the long collapse or without.
  local function landing(kind)
    local g = Fixtures.arena(G)
    g.state = 'playing'
    local e = g:spawn(kind, 16, 20)
    e.spawnAge = 1
    g:damageEnemy(e, e.hp + 1, 'weapon')
    e.deathTime, e.fallY, e.fallVY = settle + 0.01, 0.3, 1.5
    local aloft = Corpse.shields(e)
    for step = 1, 600 do
      g:update(1 / 120, {})
      if not Corpse.shields(e) then
        return aloft, step, (e.fallY or 0) <= 0
      end
    end
    return aloft, nil, false
  end
  local aloftA, stepA, lyingA = landing('imp')
  local aloftB, stepB, lyingB = landing('trial_fall')
  check(
    string.format(
      'a thrown body shields until it lies (steps %s / %s)',
      tostring(stepA),
      tostring(stepB)
    ),
    aloftA and aloftB and stepA ~= nil and stepA == stepB and lyingA and lyingB and stepA > 1
  )
  A.unregister('trial_fall')
  Anatomy.layouts.trial_fall, Masks.layouts.trial_fall = nil, nil
  Atlases.unregister('trial_fall')
  return lines
end
return Tests
