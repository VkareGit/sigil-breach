-- A third sequence and a three-frame effect use existing PNGs. Registration,
-- baking, provenance, anatomy, sampling and the complete renderer share them.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local Sequences = require('src.content.ability_art')
  local Pose = require('src.enemies.ability_pose')
  local Contract = require('src.enemies.art_contract')
  local Anatomy = require('src.content.art.anatomy_regions')
  local Masks = require('src.content.art.hit_masks')
  local Art = require('src.render.ability_art')
  local Effects = require('src.content.effect_art')
  local FX = require('src.feedback.effects')
  local Schema = require('src.core.schema')
  local Integrity = require('src.session.integrity')
  local Snapshot = require('src.session.snapshot')
  local UI = require('src.ui.interface')
  local lines = {}
  local check = Fixtures.checker(lines, 'art extension: ', 'art extension: ')
  local id, effect = 'trial_pose', 'trial_dust'
  local previous, loaded = renderer.abilityArt, nil
  local ok, problem = xpcall(function()
    local entry = Schema.copy(Sequences.leap)
    entry.sampler = id
    entry.frames, entry.feet, entry.actions = { entry.frames[1] }, { entry.feet[1] }, { 'trial' }
    entry.anchors = { entry.anchors[1] }
    entry.anatomy = { frames = { Schema.copy(Anatomy.abilities.leap.frames[1]) } }
    Sequences.register(id, entry)
    Pose.register(id, function(e)
      if e.ai == 'windup' then
        return 1, 0
      end
    end)
    local mask = require('qa.bake_hit_masks').frame(entry.frames[1], entry.path, false)
    Masks.abilities[id] = { mask }
    check(
      'single-frame baker preserves the existing source silhouette',
      table.concat(mask) == table.concat(Masks.abilities.leap[1])
    )
    check(
      'third sequence resolves its sampler anatomy and baked mask',
      #Contract.sequenceProblems(id) == 0
    )
    local Provenance = require('qa.mask_provenance')
    local frames = {}
    for _, f in ipairs(Provenance.frames()) do
      if f.id == id then
        frames[#frames + 1] = f
      end
    end
    local proof = Provenance.capture(frames)
    check(
      'provenance discovers the third sequence without a second list',
      #frames == 1 and proof.abilities[id][1][1] == entry.path and proof.images[entry.path] ~= nil
    )
    loaded = Art.load()
    renderer.abilityArt = loaded
    check('loader discovers the new atlas registration', loaded[id] and #loaded[id].frames == 1)
    local g = Fixtures.arena(G)
    local e = g:spawn('imp', 16, 21)
    e.archetype = Schema.copy(require('src.content.enemies').imp)
    e.archetype.appearance.art.leap = id
    e.attackKind, e.attackSpec = 'leap', e.archetype.attacks[2]
    e.spawnAge, e.stun, e.ai, e.windupDuration, e.windup = 1, 0, 'windup', 0.45, 0.3
    check(
      'creature reference resolves third artwork',
      #Contract.problems(e.archetype) == 0 and Pose.select(g, e) == id
    )
    local surface = require('src.enemies.surface').prepare(g, e)
    check('painted hit surface uses the third sequence mask', surface.mask == mask)
    Effects:register(
      effect,
      { duration = 0.3, frames = { 1, 3, 4 }, alpha = 0.6, brightness = 1, limit = 2 }
    )
    local fx = FX.emit(g, effect, 16, 1, 22, 0.5)
    Snapshot.invalidateDefinitions()
    local before = Integrity.capture(g)
    for i, age in ipairs({ 0, 0.11, 0.21 }) do
      fx.age = age
      check('three-frame effect selects authored phase ' .. i, FX.frame(fx) == ({ 1, 3, 4 })[i])
      renderer:draw(g, 1280, 720)
      UI.draw(g, 1280, 720, {})
    end
    check(
      'full world weapon and UI rendering preserves authoritative state',
      not Integrity.difference(before, Integrity.capture(g))
    )
    FX.emit(g, effect, 16, 1, 22)
    FX.emit(g, effect, 16, 1, 22)
    check('new effect obeys its bounded pool', #g.view.effects == 2)
    FX.update(g, 0.31)
    check('new effect expires by its own duration', #g.view.effects == 0)
    local function rejects(label, change, match)
      local def = Schema.copy(e.archetype)
      change(def)
      local messages = table.concat(Contract.problems(def), '\n')
      check(label, messages:find(match, 1, true) ~= nil)
      check(label .. ' rejects composition before rendering', not pcall(Contract.validate, def))
    end
    rejects('unknown creature atlas fails clearly', function(d)
      d.appearance.atlas = 'missing'
    end, 'unknown atlas missing')
    rejects('unknown anatomy fails clearly', function(d)
      d.appearance.regions = 'missing'
    end, 'unknown/incomplete anatomy missing')
    rejects('unknown sequence fails clearly', function(d)
      d.appearance.art.leap = 'missing'
    end, 'unknown sequence')
    rejects('unknown attack reference fails clearly', function(d)
      d.appearance.art.missing = id
    end, 'unknown attack missing')
    check(
      'explicit inherited artwork removal stays valid',
      #Contract.problems(require('src.content.enemies').armored) == 0
    )
    local savedSampler = entry.sampler
    entry.sampler = 'missing'
    local sampled, reason = pcall(Pose.select, g, e)
    check(
      'missing sampler fails before rendering a fallback',
      not sampled and tostring(reason):find('missing sampler missing', 1, true) ~= nil
    )
    check(
      'composition catches missing sampler',
      table.concat(Contract.sequenceProblems(id)):find('missing sampler missing', 1, true) ~= nil
    )
    entry.sampler = savedSampler
    Pose.samplers[id] = function()
      return 2
    end
    sampled, reason = pcall(Pose.select, g, e)
    check(
      'out-of-range sampler frame fails clearly',
      not sampled and tostring(reason):find('unknown frame 2', 1, true) ~= nil
    )
    local path = entry.path
    entry.path = 'assets/art/missing.png'
    check(
      'unknown atlas dimensions fail before GPU loading',
      table.concat(Contract.sequenceProblems(id)):find('unknown atlas dimensions', 1, true) ~= nil
    )
    entry.path = path
    Masks.abilities[id] = nil
    check(
      'missing baked mask blocks composition',
      table.concat(Contract.sequenceProblems(id)):find('missing baked masks', 1, true) ~= nil
    )
  end, debug.traceback)
  renderer.abilityArt = previous
  if loaded then
    for _, sheet in pairs(loaded) do
      sheet.image:release()
    end
  end
  Sequences.unregister(id)
  Pose.unregister(id)
  Masks.abilities[id] = nil
  Effects:unregister(effect)
  Snapshot.invalidateDefinitions()
  assert(ok, problem)
  return lines
end
return Tests
