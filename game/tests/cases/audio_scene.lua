local T = {}
function T.run(check)
  local Scene = require('src.audio.scene')
  local Schema = require('src.core.schema')
  local Config = require('src.content.maps.proving_soundscape')
  local Contract = require('src.content.defs.soundscape')
  local Recipes = require('src.audio.recipes')
  local Score = require('src.audio.score')
  local layers = {}
  for _, layer in ipairs(Score.layers) do
    layers[layer.id] = true
  end
  for _, mix in ipairs({
    Config.base,
    Config.summoning,
    Config.duel,
    Config.pressure,
    Config.aftermath,
  }) do
    for id in pairs(mix) do
      check('score layer resolves: ' .. id, layers[id])
    end
  end
  for _, region in ipairs(Config.regions) do
    for id in pairs(region.mix) do
      check(region.id .. ' score layer resolves: ' .. id, layers[id])
    end
  end
  for _, source in ipairs(Config.sources) do
    check('authored ambience resolves: ' .. source.voice, Recipes[source.voice] ~= nil)
  end
  local invalid = Schema.copy(Config)
  invalid.base.typographical_error = 0.1
  check(
    'unknown music stem rejected before native playback',
    not pcall(require('src.audio.contracts').scene, invalid)
  )
  invalid = Schema.copy(Config)
  invalid.sources[1].voice = 'missing_ambient'
  check(
    'unknown ambience voice rejected before native playback',
    not pcall(require('src.audio.contracts').scene, invalid)
  )
  invalid = Schema.copy(Config)
  invalid.regions[1].fade = 0
  check('zero spatial fade rejected', not pcall(Contract.check, invalid, 49, 43))
  invalid = Schema.copy(Config)
  invalid.sources[1].interval = 0 / 0
  check('non-finite ambient cadence rejected', not pcall(Contract.check, invalid, 49, 43))
  invalid = Schema.copy(Config)
  invalid.regions[2].id = invalid.regions[1].id
  check('duplicate region rejected', not pcall(Contract.check, invalid, 49, 43))
  local r = Config.regions[1]
  check(
    'room fades continuously at its border',
    math.abs(Scene.weight(r, r.x1 - 0.001, 36) - Scene.weight(r, r.x1, 36)) < 0.00001
  )
  check('room influence ends outside its authored fade', Scene.weight(r, r.x1 - r.fade, 36) == 0)

  local Game = require('src.session.game')
  local Release = require('src.app.release')
  local g = Game.new('field', Release.sessionMaps.field, Release.sessionOptions.field)
  g.ephemeral = true
  g:start()
  local sample = {}
  Scene.sample(g, sample)
  check('empty field starts in traversal music', sample.config and sample.stage == 'traversal')
  g.player.x, g.player.z = 24, 20
  Scene.sample(g, sample)
  local nave = Scene.gain(sample, 'chant', 0)
  g.player.x, g.player.z = 18.5, 27.5
  Scene.sample(g, sample)
  check(
    'broken binding passage withdraws the nave chant',
    Scene.gain(sample, 'chant', 0) < nave * 0.3
  )
  check('real trial command accepted', g:act('catalog', 'field_chamber_ash'))
  Scene.sample(g, sample)
  check(
    'pending portal withdraws battle stems',
    sample.stage == 'summoning' and Scene.gain(sample, 'heart', 1) == 0
  )
  for _ = 1, 600 do
    if #g.run.pending == 0 then
      break
    end
    g:update(1 / 120, {})
  end
  local Pools = require('src.session.world')
  local enemy = Pools.of(g, 'enemies')[1]
  check('real chamber arrival exists', enemy ~= nil)
  enemy.awake = true
  enemy.x, enemy.z = g.player.x + 8, g.player.z
  Scene.sample(g, sample)
  check('arrived live opponent enters duel', sample.stage == 'duel')
  local far = sample.pressure
  enemy.x, enemy.ai = g.player.x + 2, 'windup'
  Scene.sample(g, sample)
  check(
    'nearby committed attack raises pressure without a phase transition',
    sample.pressure > far
      and Scene.gain(sample, 'heart', sample.pressure) > Scene.gain(sample, 'heart', far)
  )
  local Integrity = require('src.session.integrity')
  local before = Integrity.capture(g)
  Scene.sample(g, sample)
  check(
    'music sampling does not mutate simulation',
    not Integrity.difference(before, Integrity.capture(g))
  )
  enemy.hp = 0
  g:update(1 / 120, {})
  Scene.sample(g, sample)
  check(
    'actual completed encounter enters quiet aftermath',
    sample.stage == 'aftermath' and Scene.gain(sample, 'heart', 1) == 0
  )
  g.elapsed = g.elapsed + Config.aftermathHold + Config.aftermathFade + 0.1
  Scene.sample(g, sample)
  check('aftermath returns to room music', sample.stage == 'traversal')
  g.help = true
  Scene.sample(g, sample)
  check('help pauses adaptive encounter mix', sample.config == nil)

  local C = require('src.audio.world_cues')
  local calls = {}
  local fake = {
    playAt = function(name, x, z)
      calls[#calls + 1] = { name, x, z }
    end,
  }
  local arena = require('tests.support.fixtures').arena(Game)
  arena.world.decor.soundscape = {
    sources = {
      {
        voice = 'chain_settle',
        x = 16,
        z = 24,
        volume = 0.2,
        reach = 10,
        interval = 2,
        offset = 0,
      },
    },
  }
  C.reset()
  C.update(fake, arena, 0.01)
  arena.player.x = 17
  C.update(fake, arena, 2.1)
  check(
    'ambience stays attached to masonry when listener moves',
    #calls == 2 and calls[1][2] == calls[2][2] and calls[2][2] == 16
  )
  C.update(fake, arena, 100)
  check('hitch does not replay all missed ambient cues', #calls == 3)
  arena.world.decor.soundscape = nil
  local h = { x = 16, z = 25, delay = 0.2, life = 1, packet = { damageType = 'fire' } }
  arena.hazards = { h }
  C.update(fake, arena, 0.01)
  check('waiting eruption remains silent', #calls == 3)
  h.delay = 0
  arena.hazards[2] = Schema.copy(h)
  C.update(fake, arena, 0.01)
  check(
    'simultaneous fire marks play one eruption at activation',
    #calls == 4 and calls[4][1] == 'ash_eruption'
  )
  C.update(fake, arena, 0.2)
  check('persistent fire pool does not retrigger explosion every tick', #calls == 4)
  local thunder = {
    x = 16,
    z = 25,
    delay = 0,
    life = 0.2,
    waitForCast = true,
    packet = { damageType = 'lightning' },
  }
  arena.hazards[3] = thunder
  C.update(fake, arena, 0.01)
  check('lightning cannot sound before caster releases it', #calls == 4)
  thunder.waitForCast = nil
  C.update(fake, arena, 0.01)
  check('released lightning sounds at its actual mark', #calls == 5 and calls[5][1] == 'thunder')
  C.reset()
end
return T
