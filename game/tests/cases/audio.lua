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
  -- This name is already in the full idle pool above. Borrowing it opens a
  -- cache slot, guaranteeing reuse instead of testing the eviction policy.
  local oldVoice, oldTicket = A.play('revolver', 0.01)
  A.stopVoice(oldVoice, oldTicket)
  check('owned voice can stop when an attack is cancelled', not oldVoice:isPlaying())
  A.update(0)
  local nextVoice = A.play('revolver', 0.01)
  A.stopVoice(oldVoice, oldTicket)
  check(
    'stale cancellation cannot silence a recycled Source',
    nextVoice == oldVoice and nextVoice:isPlaying()
  )
  nextVoice:stop()
  A.update(0)
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
    #calls == 1
      and calls[1] == 'ember_step'
      and not Integrity.difference(before, Integrity.capture(g))
  )
  C.update(fake, g, 0.01)
  check('standing at the same stride produces no duplicate footstep', #calls == 1)
  e.leaping, e.walk = true, 2
  C.update(fake, g, 0.01)
  check('an airborne stride produces no ground contact', #calls == 1)
  C.reset()
  -- A crowd's steps and wings (PLAN Z10b): at most Mix.crowd.voices of each category sound
  -- at once, the nearest first, and a voice still sounding holds its place.
  local Mix = require('src.content.audio_mix')
  local crowd = Fixtures.arena(Game)
  local q = crowd.player
  local walkers, fliers = {}, {}
  for i = 1, 30 do
    local e = crowd:spawn('imp', q.x + 1 + i * 0.4, q.z + 0.5)
    e.spawnAge, e.walkSpeed, e.walk = 1, 2, 0
    walkers[i] = e
  end
  for i = 1, 6 do
    local e = crowd:spawn('stolas', q.x - 1 - i * 0.5, q.z - 0.5)
    e.spawnAge, e.walkSpeed, e.walk = 1, 2, 0
    fliers[i] = e
  end
  local heard, held = {}, {}
  local listening = {
    playAt = function(_, _, _, _, _, _, _, _, body)
      heard[#heard + 1] = body
      local source = {}
      held[source] = true
      return source, 1
    end,
    ownsVoice = function(source)
      return held[source] == true
    end,
    stopVoice = function(source)
      held[source] = nil
    end,
    loopVoice = function() end,
  }
  local function stride(index)
    heard = {}
    for _, e in ipairs(walkers) do
      e.walk = index
    end
    for _, e in ipairs(fliers) do
      e.walk = index
    end
    C.update(listening, crowd, 0.01)
  end
  stride(0)
  stride(1)
  local steps, wings, nearest = 0, 0, true
  for _, body in ipairs(heard) do
    if require('src.content.enemies').of(body).id == 'stolas' then
      wings = wings + 1
    else
      steps = steps + 1
      nearest = nearest and body == walkers[steps]
    end
  end
  check(
    'thirty steps at once sound their nearest eighteen, six wings their four',
    steps == Mix.crowd.voices.steps and wings == Mix.crowd.voices.wings and nearest
  )
  stride(2)
  check('while they sound, the next strides wait', #heard == 0)
  held = {}
  stride(3)
  check('once they ended, the nearest sound again', #heard == steps + wings)
  C.reset()
  -- Today's chapel, every body awake and on the knight for twenty seconds: its steps are
  -- the same with the crowd's room as without it.
  local Recipes = require('src.audio.recipes')
  local function chapel()
    local way = Game.new('pilgrimage', nil, { origin = false })
    way.ephemeral = true
    way:act('start')
    way.state = 'playing'
    local knight = way.player
    knight.x, knight.z = 24, 24
    for _, e in ipairs(require('src.session.world').of(way, 'enemies')) do
      e.awake, e.memory, e.leash = true, 60, 200
    end
    local now, order, voices = 0, {}, {}
    local ear = {
      playAt = function(name, _, _, _, _, _, _, _, body)
        order[#order + 1] = string.format('%.4f %s %s', now, name, tostring(body and body.id))
        local source = { ends = now + ((Recipes[name] or {}).duration or 0.5) }
        voices[source] = true
        return source, 1
      end,
      ownsVoice = function(source)
        return voices[source] == true and now < source.ends
      end,
      stopVoice = function(source)
        voices[source] = nil
      end,
      loopVoice = function() end,
    }
    for _ = 1, 20 * 120 do
      now = now + 1 / 120
      way:update(1 / 120, {})
      knight.hp = knight.maxHp
      C.update(ear, way, 1 / 120)
    end
    C.reset()
    return order
  end
  local limited = chapel()
  local voices = Mix.crowd.voices
  Mix.crowd.voices = { steps = math.huge, wings = math.huge }
  local ok, free = pcall(chapel)
  Mix.crowd.voices = voices
  check(
    "today's chapel, every body awake, steps as it did before the crowd's room",
    ok and #limited > 100 and table.concat(limited, '\n') == table.concat(free, '\n')
  )
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
    local Action = require('src.content.defs.action')
    for _, attack in ipairs(def.attacks) do
      Action.kinds:get(attack.kind):marked(attack, 'voice', function(name, where)
        check(where .. ' resolves', Recipes[name] ~= nil)
      end, id .. '/' .. attack.id)
    end
  end
  check(
    'every sound recipe is rendered, the perfect dodge and the fuse included',
    all and A.sources.afterimage and A.sources.fuse and A.sources.slide
  )
  -- Sound banks are the files of content/sounds (PLAN F2, G7): a new bank is
  -- a new file there, merged without a list kept in audio/recipes.lua.
  local banks, merged = love.filesystem.getDirectoryItems('src/content/sounds'), true
  for _, file in ipairs(banks) do
    local made = Recipes.banks[file:match('^(.+)%.lua$')]
    merged = merged and made ~= nil
    for name, recipe in pairs(made or {}) do
      merged = merged and Recipes[name] == recipe
    end
  end
  check('every sound bank file is merged into the recipes', #banks > 0 and merged)
  -- A field that names a voice says so in its schema (PLAN F2): the audio
  -- contract checks it wherever it sits, with no list of keys of its own.
  local Contracts = require('src.audio.contracts')
  local function refused(record, key)
    local kept = record[key]
    record[key] = 'trial_missing_voice'
    local ok = pcall(Contracts.validate)
    record[key] = kept
    return not ok
  end
  local trail
  for _, attack in ipairs(require('src.content.enemies').get('boss').attacks) do
    trail = trail or (attack.trail and attack.trail.impactSound and attack.trail)
  end
  check(
    'a missing voice deep in an action (its trail) stops the load',
    refused(trail, 'impactSound')
  )
  check(
    'a missing voice of a weapon shot stops the load',
    refused(require('src.content.weapons').get('judge').fire, 'sound')
  )
  check('the live voices pass the audio contract', pcall(Contracts.validate))
  local Synth = require('src.audio.synth')
  for name, recipe in pairs(Recipes.banks.rites) do
    local data = Synth.effect(recipe.duration, A.rate, Synth.seed(name), recipe.make(A.rate))
    local peak, sum = 0, 0
    for i = 0, data:getSampleCount() - 1 do
      local value = data:getSample(i)
      peak, sum = math.max(peak, math.abs(value)), sum + value * value
    end
    check(
      'ritual voice is audible with headroom and a faded end: ' .. name,
      peak < 0.95
        and sum / data:getSampleCount() > 0.00001
        and math.abs(data:getSample(data:getSampleCount() - 1)) < 0.001
    )
    data:release()
  end
  local handlers = require('src.feedback.world_feedback').handlers
  local demon = { kind = 'boss', x = g.player.x, z = g.player.z }
  handlers.AttackTelegraphed(g, { enemy = demon, attack = { windupSound = 'ash_lance_warning' } })
  local voice = A.live[#A.live]
  local level = voice:getVolume()
  local function retired(source)
    -- A full cache releases stopped Sources; do not query a destroyed native handle.
    for _, live in ipairs(A.live) do
      if live == source then
        return false
      end
    end
    return true
  end
  handlers.AttackCancelled(g, { enemy = demon })
  A.update(0.01)
  check('actual cancellation fades the warning immediately', voice:getVolume() < level * 0.5)
  A.update(0.02)
  check('actual cancellation event stops its windup within 30 ms', retired(voice))
  handlers.AttackTelegraphed(g, { enemy = demon, attack = { windupSound = 'ash_fan_warning' } })
  voice = A.live[#A.live]
  handlers.EnemyKilled(g, { enemy = demon })
  A.update(0.03)
  check('death stops the pending warning within 30 ms', retired(voice))
  A.update(0)
  -- The score: its layers loop together; the mood follows the session.
  local S = require('src.audio.soundscape')
  local Score = require('src.content.score')
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
  require('tests.cases.audio_scene').run(check)
  return lines
end
return Tests
