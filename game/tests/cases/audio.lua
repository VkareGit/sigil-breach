local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run()
  local A = require('src.audio.audio')
  local oldMuted = A.muted
  local lines = {}
  local check = Fixtures.checker(lines, '', '')
  A.muted = false
  local spatial = A.playAt('revolver', 5, 0, { x = 0, z = 0, yaw = 0 }, 0.1)
  check('physical revolver has a playable spatial audio voice', spatial and spatial:isPlaying())
  spatial:stop()
  A.update(0)
  local reused = A.play('revolver', 0.1)
  local x, y, z = reused:getPosition()
  check(
    'finished Source is reused and its spatial position resets',
    reused == spatial and x == 0 and y == 0 and z == 0
  )
  local keys = { 'shot', 'revolver', 'blast', 'thunder', 'cast', 'antler', 'step' }
  for i = 1, 180 do
    A.play(keys[(i - 1) % #keys + 1], 0.01)
  end
  check('audio overload keeps at most28active and28cached voices', #A.live <= 28 and A.pooled <= 28)
  for _, s in ipairs(A.live) do
    s:stop()
  end
  A.update(0)
  check('stopped audio voices retire without a live Source leak', #A.live == 0 and A.pooled <= 28)
  local total = 0
  for _, pool in pairs(A.pool) do
    total = total + #pool
  end
  check('cached Source count matches the bounded idle pools', total == A.pooled)
  for _ = 1, 28 do
    A.play('storm_warning', 0.01)
  end
  local warning = A.live[1]
  check(
    'ambient cannot displace a full warning mix',
    A.play('crypt_drip', 0.01) == nil and A.live[1] == warning
  )
  for _, s in ipairs(A.live) do
    s:stop()
  end
  A.update(0)
  for _ = 1, 28 do
    A.play('crypt_drip', 0.01)
  end
  check(
    'an attack warning displaces ambience at the bounded cap',
    A.play('ember_warning', 0.01) ~= nil and #A.live == 28
  )
  for _, s in ipairs(A.live) do
    s:stop()
  end
  A.update(0)
  local C = require('src.audio.world_cues')
  local Game = require('src.session.game')
  local g = Fixtures.arena(Game)
  local e = g:spawn('imp', g.player.x + 3, g.player.z)
  e.spawnAge, e.walkSpeed, e.walk = 1, 2, 0
  local calls = {}
  local fake = {
    playAt = function(name)
      calls[#calls + 1] = name
    end,
  }
  C.update(fake, g, 0.01)
  e.walk = 1
  local Integrity = require('src.session.integrity')
  local before = Integrity.capture(g)
  C.update(fake, g, 0.01)
  check(
    'painted stride produces one spatial foot contact without simulation mutation',
    calls[1] == 'cloven_step' and not Integrity.difference(before, Integrity.capture(g))
  )
  C.update(fake, g, 0.01)
  check('standing at the same stride produces no duplicate footstep', #calls == 1)
  e.leaping, e.walk = true, 2
  C.update(fake, g, 0.01)
  check('an airborne stride produces no ground contact', #calls == 1)
  C.reset()
  -- Every recipe is a sound; the knight's movement has its own voices.
  local Recipes = require('src.audio.recipes')
  local all = true
  for name in pairs(Recipes) do
    all = all and A.sources[name] ~= nil
  end
  for id, def in require('src.content.enemies').each() do
    for role, name in pairs(def.sounds) do
      check(id .. ' sound ' .. role .. ' resolves', Recipes[name] ~= nil)
    end
    for _, attack in ipairs(def.attacks) do
      for _, key in ipairs({ 'sound', 'windupSound' }) do
        if attack[key] then
          check(id .. '/' .. attack.id .. ' ' .. key .. ' resolves', Recipes[attack[key]] ~= nil)
        end
      end
    end
  end
  check(
    'every sound recipe is rendered, the perfect dodge and the fuse included',
    all and A.sources.afterimage and A.sources.fuse and A.sources.slide
  )
  -- The score: its layers loop together; the mood follows the session.
  local S = require('src.audio.soundscape')
  local Score = require('src.audio.score')
  -- (QA stops every Source after loading, so only the loops are asserted.)
  local looping = true
  for _, layer in ipairs(Score.layers) do
    local source = S.layers[layer.id]
    looping = looping and source and source:isLooping()
  end
  check('every layer of the score is a loop', looping)
  local notes, phrases, units = S.timeline()
  local sung = 0
  for _, line in ipairs(Score.chant) do
    for _ in line.words:gmatch('%S+') do
      sung = sung + 1
    end
  end
  check(
    'the chant sings one syllable on each of its notes',
    #notes == sung and #phrases == #Score.chant
  )
  check(
    'the chant keeps its loop of units',
    units * Score.unit > 0 and phrases[#phrases].start < units
  )
  check(
    'the mood follows the session: menu, play, guardian, rest, death',
    S.mood({ state = 'menu' }) == 'menu'
      and S.mood({ state = 'playing' }) == 'battle'
      and S.mood({ state = 'playing', encounter = { guardianSpawned = true } }) == 'guardian'
      and S.mood({
        state = 'playing',
        encounter = { guardianSpawned = true, guardianDead = true },
      }) == 'battle'
      and S.mood({ state = 'playing', map = true }) == 'rest'
      and S.mood({ state = 'dead' }) == 'death'
  )
  check(
    'battle blends calm into fight by danger: no heartbeat in calm, the full one in a fight',
    S.gain('battle', 'heart', 0) == (Score.moods.calm.heart or 0)
      and S.gain('battle', 'heart', 1) == Score.moods.fight.heart
  )
  local intensity, gains = S.intensity, {}
  for id, gain in pairs(S.gains) do
    gains[id] = gain
  end
  local danger = { state = 'playing', threat = Score.danger.full }
  for _ = 1, 100 do
    S.update(A, 0.1, danger)
  end
  check(
    'a fight near the knight brings the heartbeat in and the chant down',
    S.intensity > 0.99 and S.gains.heart > 0.6 and S.gains.chant < Score.moods.calm.chant
  )
  S.intensity = intensity
  for id, gain in pairs(gains) do
    S.gains[id] = gain
  end
  A.muted = oldMuted
  return lines
end
return Tests
