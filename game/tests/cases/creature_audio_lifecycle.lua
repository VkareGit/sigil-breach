-- Follow real sources and event routes, including the gaps found in the audio audit.
local T = {}
function T.run(Game)
  local A = require('src.audio.audio')
  local Cues = require('src.audio.world_cues')
  local Handlers = require('src.feedback.world_feedback').handlers
  local F = require('tests.support.fixtures')
  local Arena = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local Integrity = require('src.session.integrity')
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'creature lifecycle: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local previous = {}
  for _, field in ipairs({
    'live',
    'pool',
    'pooled',
    'voiceNames',
    'priorities',
    'lastTake',
    'muted',
    'warningHold',
  }) do
    previous[field] = A[field]
  end
  local playAt, stopVoice, effects = A.playAt, A.stopVoice, A.levels.effects
  A.live, A.pool, A.pooled, A.voiceNames, A.priorities, A.lastTake = {}, {}, 0, {}, {}, {}
  A.muted, A.warningHold, A.levels.effects = false, 0, 1
  local function drain()
    for _, source in ipairs(A.live) do
      source:stop()
    end
    A.update(0)
    Cues.reset()
  end
  local function room()
    local g = F.arena(Game)
    for z = 8, 30 do
      for x = 8, 28 do
        Arena.setCell(g.world, x, z, Tiles.floor)
      end
    end
    g.player.x, g.player.z, g.player.yaw = 16, 20, 0
    return g
  end
  local ok, err = xpcall(function()
    for _, hz in ipairs({ 60, 120, 240 }) do
      drain()
      local g = room()
      local source = A.playAt('owl_death', 18, 20, g.player, 0.65, 2, g.world)
      local beforeX = source:getPosition()
      local beforeVolume = source:getVolume()
      g.player.x, g.player.yaw = 10, math.pi / 2
      for _ = 1, hz / 10 do
        A.update(1 / hz, g)
      end
      local afterX = source:getPosition()
      check(
        hz .. ' Hz listener turn moves an existing voice in the panorama',
        math.abs(afterX - beforeX) > 0.2
      )
      check(
        hz .. ' Hz listener distance attenuates an existing voice',
        source:getVolume() < beforeVolume * 0.9
      )
      local state = Integrity.capture(g)
      A.update(1 / hz, g)
      check(
        hz .. ' Hz presentation leaves simulation unchanged',
        not Integrity.difference(state, Integrity.capture(g))
      )
      drain()
    end
    local g = room()
    local source = A.playAt('owl_death', 16, 14, g.player, 0.65, 2, g.world)
    local before = source:getVolume()
    Arena.setCell(g.world, 16, 17, Tiles.wall)
    for _ = 1, 30 do
      A.update(1 / 120, g)
    end
    check('a newly occluding wall attenuates a live voice', source:getVolume() < before * 0.6)
    A.levels.effects = 0
    A.update(1 / 60, g)
    check('effects mute silences an already playing spatial voice', source:getVolume() == 0)
    A.levels.effects = 1
    drain()
    g = room()
    source = A.playAt('owl_death', 16, 14, g.player, 0.65, 2, g.world)
    g.state = 'paused'
    A.update(1 / 60, g)
    check('pause suspends existing world sounds', not source:isPlaying())
    g.state = 'playing'
    A.update(1 / 60, g)
    check('resume continues a suspended world sound', source:isPlaying())
    g.world = room().world
    A.update(1 / 60, g)
    check('changing worlds retires old spatial voices', not source:isPlaying())
    drain()
    g = room()
    local e = g:spawn('stolas', 16, 14)
    local calls = {}
    A.playAt = function(name, x, z, listener, gain, priority, world)
      calls[#calls + 1] = { name = name, world = world, x = x, z = z }
    end
    A.stopVoice = function() end
    for _, event in ipairs({ 'Evaded', 'Alerted', 'ChargeBlocked' }) do
      calls = {}
      Handlers[event](g, { enemy = e })
      check(
        event .. ' uses the actual world for occlusion',
        #calls == 1 and calls[1].world == g.world
      )
    end
    g.enemies, calls = {}, {}
    g.hazards = {
      {
        x = 16,
        z = 18,
        delay = 0,
        life = 1,
        owner = 101,
        packet = { damageType = 'fire' },
        impactSound = 'margrave_burst',
      },
      {
        x = 16,
        z = 17,
        delay = 0,
        life = 1,
        owner = 102,
        packet = { damageType = 'fire' },
        impactSound = 'margrave_ash_release',
      },
    }
    Cues.reset()
    Cues.update(A, g, 1 / 120)
    check('distinct simultaneous fields retain both activation voices', #calls == 2)
    Cues.update(A, g, 1 / 120)
    check('the same fields never replay their activation', #calls == 2)
    calls = {}
    g.hazards[2].owner, g.hazards[2].impactSound = 101, 'margrave_burst'
    Cues.reset()
    Cues.update(A, g, 1 / 120)
    check('simultaneous marks of one rite share their activation', #calls == 1)
    calls = {}
    g.hazards = {
      {
        x = 16,
        z = 18,
        delay = 0,
        life = 1,
        owner = e.id,
        art = 'hell',
        kind = 'wave',
        radius = 2,
        packet = { damageType = 'astral' },
      },
    }
    g.enemies = { e }
    e.ai, e.hp = 'strike', 100
    Cues.reset()
    Cues.update(A, g, 1 / 120)
    check(
      'hellfire has a voice at the active field',
      #calls >= 1 and calls[1].name ~= 'owl_rupture'
    )
    A.playAt, A.stopVoice = playAt, stopVoice
    drain()
    -- Dynamic emitters, envelopes and ownership must work with native Sources.
    local Spatial = require('src.audio.spatial')
    local Recipes = require('src.audio.recipes')
    local Profiles = require('src.audio.creature_profiles')
    local Enemies = require('src.content.enemies')
    local Fields = require('src.audio.field_voices')
    local Snapshot = require('src.session.snapshot')
    g = room()
    local dying = g:spawn('furfur', 16, 14)
    local alert, alertTicket =
      A.playAt(Enemies.furfur.sounds.alert, dying.x, dying.z, g.player, 0.4, 2, g.world, nil, dying)
    g:damageEnemy(dying, dying.hp + 1, 'weapon', nil, g.player.id)
    g.bus:flush()
    A.update(0.05, g)
    check('death retires an already sounding living voice', not A.ownsVoice(alert, alertTicket))
    local deathPlays = false
    for _, voice in ipairs(A.live) do
      if A.voiceNames[voice]:match('^furfur_death') then
        deathPlays = voice:isPlaying()
      end
    end
    check('death cleanup preserves the new death performance', deathPlays)
    drain()
    local profiles = require('src.content.creature_audio')
    profiles.stolas.actions.missing = { release = 'owl_release' }
    local invalid = pcall(require('src.audio.contracts').validate)
    profiles.stolas.actions.missing = nil
    check('content validation rejects an override for a missing action', not invalid)
    profiles.stolas.fields.missing = { active = 'missing_voice' }
    invalid = pcall(require('src.audio.contracts').validate)
    profiles.stolas.fields.missing = nil
    check('content validation rejects an unknown material recording', not invalid)
    for _, kind in ipairs({ 'imp', 'armored', 'stolas', 'buer', 'furfur', 'boss' }) do
      g = room()
      local body = g:spawn(kind, 16, 14)
      check(
        kind .. ' selects its own identity rather than its inherited AI kind',
        Profiles.of(body) == require('src.content.creature_audio')[kind]
      )
      check(
        kind .. ' physical contacts have a recorded body material',
        Recipes[Profiles.body(body, 'fall')].path ~= nil
      )
      for _, attack in ipairs(Enemies.of(body).attacks) do
        calls = {}
        A.playAt = function(name, x, z, listener, gain, priority, world, category, emitter)
          calls[#calls + 1] = { name = name, emitter = emitter, world = world }
        end
        Handlers.AttackTelegraphed(g, { enemy = body, attack = attack })
        local valid = #calls > 0 or attack.warning == false
        for _, call in ipairs(calls) do
          valid = valid
            and Recipes[call.name] ~= nil
            and call.emitter == body
            and call.world == g.world
        end
        check(kind .. '/' .. attack.id .. ' warning belongs to its caster and real world', valid)
      end
      A.playAt = playAt
      drain()
    end
    g = room()
    local emitter = { x = 13, z = 20 }
    source = A.playAt('owl_death', emitter.x, emitter.z, g.player, 0.6, 2, g.world, nil, emitter)
    local left = source:getPosition()
    emitter.x = 19
    A.update(0.02, g)
    check(
      'a moving emitter crosses the listener without replaying',
      left < -0.5 and source:getPosition() > 0.5
    )
    local _, _, behind = source:getPosition()
    emitter.x, emitter.z = 16, 23
    A.update(0.02, g)
    local _, _, front = source:getPosition()
    check('relative placement preserves front and rear', front < -0.5 and math.abs(behind) < 0.01)
    drain()
    g = room()
    local ticket
    source, ticket = A.playAt('owl_death', 16, 14, g.player, 0.6, 2, g.world)
    before = source:getVolume()
    A.stopVoice(source, ticket, 0.04)
    A.update(0.02, g)
    check(
      'cancellation fades rather than cutting a nonzero sample',
      source:isPlaying() and source:getVolume() < before * 0.3
    )
    A.update(0.03, g)
    check('cancellation ends within its envelope', not source:isPlaying())
    local stale, oldTicket = A.play('cast', 0.4)
    A.stopVoice(stale, oldTicket)
    A.update(0)
    local reused, newTicket = A.play('cast', 0.4)
    A.stopVoice(stale, oldTicket, 0.02)
    A.update(0.03)
    check(
      'an old cancellation cannot silence a reused source',
      reused == stale and newTicket ~= oldTicket and reused:isPlaying()
    )
    drain()
    for _ = 1, 28 do
      A.play('owl_wave_choir', 0.6, 3)
    end
    check(
      'a distant equal-priority cue cannot steal a loud warning',
      A.play('owl_wave_choir', 0.05, 3) == nil
    )
    check(
      'a nearer warning can replace an equal-priority distant voice',
      A.play('owl_wave_choir', 0.7, 3) ~= nil and #A.live == 28
    )
    check(
      'the player report survives a room full of warnings',
      A.play('revolver', 0.6) ~= nil and #A.live == 28
    )
    drain()
    drain()
    local choir = Recipes.owl_wave_choir
    local VoiceData = require('src.audio.voice_data')
    local samples = {
      VoiceData.render('choir', { path = choir.path }, A.rate),
      VoiceData.render('choir', { path = choir.variants[1] }, A.rate),
    }
    local shotData = VoiceData.render('shot', { path = 'assets/sounds/exorcist/B1-3.wav' }, A.rate)
    local gains = { 0, 0 }
    for _ = 1, 24 do
      A.playAt('owl_wave_choir', 0, 2, { x = 0, z = 0, yaw = 0 }, 0.4, 2)
    end
    A.update(0)
    for _, voice in ipairs(A.live) do
      local index = tonumber(A.voiceNames[voice]:match('voice(%d+)$'))
      gains[index] = gains[index] + voice:getVolume()
    end
    local peak = 0
    for i = 0, samples[1]:getSampleCount() - 1 do
      local value = samples[1]:getSample(i) * gains[1] + samples[2]:getSample(i) * gains[2]
      if i >= 6615 and i - 6615 < shotData:getSampleCount() then
        value = value
          + shotData:getSample(i - 6615) * 0.95 * require('src.content.sound_sets').cues.shot.gain
      end
      peak = math.max(peak, math.abs(value * 0.7))
    end
    for _, data in ipairs(samples) do
      data:release()
    end
    shotData:release()
    check(
      '24 coincident field choirs leave headroom for Exorcist (peak '
        .. string.format('%.3f', peak)
        .. ')',
      peak < 1
    )
    drain()
    g = room()
    local owl = g:spawn('stolas', 16, 14)
    local field = {
      x = 16,
      z = 14,
      delay = -0.4,
      life = 2,
      owner = owl.id,
      kind = 'wave',
      art = 'hell',
      radius = 2,
      packet = { damageType = 'astral' },
    }
    g.hazards = { field }
    Cues.update(A, g, 0.01)
    local loop
    for _, voice in ipairs(A.live) do
      if voice:isLooping() then
        loop = voice
      end
    end
    check('the moving hellwave owns an active sound', loop ~= nil)
    owl.hp = 0
    field.radius = 4
    Cues.update(A, g, 0.01)
    check(
      'a released wave survives caster death according to the actual field',
      loop and loop:isPlaying()
    )
    field.cancelled = true
    Cues.update(A, g, 0.01)
    A.update(0.05, g)
    check('cancelling a field also stops its sustained sound', loop and not loop:isPlaying())
    drain()
    g = room()
    owl = g:spawn('stolas', 16, 14)
    field = {
      x = 16,
      z = 14,
      delay = -0.4,
      life = 2,
      owner = owl.id,
      kind = 'wave',
      art = 'hell',
      radius = 2,
      packet = { damageType = 'astral' },
    }
    g.hazards = { field }
    local saved = Snapshot.capture(g)
    Snapshot.restore(g, saved)
    loop = nil
    for _, voice in ipairs(A.live) do
      if voice:isLooping() then
        loop = voice
      end
    end
    check(
      'Continue resumes an active field at its elapsed phase with a fade-in',
      loop and loop:getVolume() == 0 and loop:tell() >= 0.39
    )
    A.update(0.05, g)
    check('the resumed field reaches its normal level', loop and loop:getVolume() > 0)
    -- A removed footprint must remain reachable until its audio is retired.
    g.hazards = {}
    collectgarbage('collect')
    Cues.update(A, g, 0.01)
    A.update(0.05, g)
    check('garbage collection cannot orphan a sustained field voice', loop and not loop:isPlaying())
    drain()
    g = room()
    owl = g:spawn('stolas', 16, 14)
    field = {
      x = 16,
      z = -40,
      delay = -1,
      life = 2,
      owner = owl.id,
      kind = 'wave',
      art = 'hell',
      radius = 2,
      packet = { damageType = 'astral' },
    }
    g.hazards = { field }
    Cues.update(A, g, 0.01)
    field.z = 14
    Cues.update(A, g, 0.3)
    loop = nil
    for _, voice in ipairs(A.live) do
      if voice:isLooping() then
        loop = voice
      end
    end
    check(
      'an active field entering hearing range resumes without repeating its onset',
      loop and loop:tell() >= 0.99 and loop:getVolume() == 0
    )
    drain()
    calls = {}
    A.playAt = function(name)
      calls[#calls + 1] = name
    end
    A.stopVoice = function() end
    g = room()
    local furfur = g:spawn('furfur', 16, 14)
    field = {
      x = 16,
      z = 18,
      delay = -0.5,
      life = 0.1,
      owner = furfur.id,
      kind = 'lightning',
      impactSound = 'furfur_thunder',
      packet = { damageType = 'lightning' },
    }
    g.hazards = { field }
    Cues.restored(A, g)
    Cues.update(A, g, 0.01)
    check('Continue does not repeat an already struck lightning impact', #calls == 0)
    field.delay = 0.2
    field.struck = nil
    Cues.reset()
    Cues.restored(A, g)
    field.delay = 0
    Cues.update(A, g, 0.01)
    check(
      'Continue retains a pending lightning impact',
      #calls == 1 and calls[1] == 'furfur_thunder'
    )
    calls = {}
    Cues.reset()
    field.life = 0
    Fields.struck(A, g, field)
    Fields.ended(A, g, field)
    g.hazards = {}
    Cues.update(A, g, 0.1)
    check('a contact shorter than one update still sounds exactly once', #calls == 1)
    calls = {}
    Cues.reset()
    g = room()
    owl = g:spawn('stolas', 16, 14)
    local near = { x = 16, z = 18, owner = owl.id, packet = { damageType = 'astral' } }
    local far = { x = 16, z = 8, owner = owl.id, packet = { damageType = 'astral' } }
    g.bullets = { near, far }
    Cues.restored(A, g)
    Cues.update(A, g, 0.01)
    check('Continue does not replay a near projectile flyby', #calls == 0)
    far.z = 18
    Cues.update(A, g, 0.01)
    check(
      'a restored distant projectile can still enter hearing range',
      #calls == 1 and calls[1] == 'owl_flight'
    )
    calls = {}
    g.bullets = {}
    owl.ai = 'windup'
    owl.attackSpec = Enemies.stolas.attacks[1]
    owl.windupDuration = 0.74
    owl.windup = 0.54
    Snapshot.restore(g, Snapshot.capture(g))
    check('Continue reattaches both layers of a pending cast', #calls == 2)
    A.playAt, A.stopVoice = playAt, stopVoice
    drain()
  end, debug.traceback)
  A.playAt, A.stopVoice, A.levels.effects = playAt, stopVoice, effects
  drain()
  for _, source in ipairs(A.live) do
    source:release()
  end
  for _, list in pairs(A.pool) do
    for _, source in ipairs(list) do
      source:release()
    end
  end
  for field, value in pairs(previous) do
    A[field] = value
  end
  assert(ok, err)
  for _, line in ipairs(lines) do
    print(line)
  end
  assert(#failures == 0, table.concat(failures, '; '))
  return lines
end
return T
