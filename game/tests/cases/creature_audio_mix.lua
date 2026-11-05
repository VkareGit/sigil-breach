-- Exercise native playback, not only the recipe declarations.
local T = {}
function T.run(Game)
  local A = require('src.audio.audio')
  local Recipes = require('src.audio.recipes')
  local Enemies = require('src.content.enemies')
  local Presence = require('src.audio.body_voices')
  local F = require('tests.support.fixtures')
  local Integrity = require('src.session.integrity')
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'creature mix: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local function drain()
    for _, source in ipairs(A.live) do
      source:stop()
    end
    A.update(0)
  end
  local muted, effects, playAt, stopVoice = A.muted, A.levels.effects, A.playAt, A.stopVoice
  -- This stress test owns its playback state. A full idle cache must not
  -- change the starting conditions of later integration tests.
  local previous = {}
  for _, field in ipairs({ 'live', 'pool', 'pooled', 'voiceNames', 'priorities', 'lastTake', 'set' }) do
    previous[field] = A[field]
  end
  local warningHold, randomState = A.warningHold, love.math.getRandomState()
  A.live, A.pool, A.pooled, A.voiceNames, A.priorities, A.lastTake = {}, {}, 0, {}, {}, {}
  A.warningHold = 0
  A.muted, A.levels.effects = false, 1
  local ok, err = xpcall(function()
    drain()
    for _, kind in ipairs({ 'stolas', 'armored', 'buer', 'imp' }) do
      local sounds = Enemies[kind].sounds
      local recipe = Recipes[sounds.death]
      check(kind .. ' has three death performances', #(recipe.variants or {}) == 2)
      local seen, last, different = {}, nil, true
      local random = love.math.getRandomState()
      for _ = 1, 18 do
        local source = A.play(sounds.death, 0.1)
        local key = A.voiceNames[source]
        seen[key], different, last = true, different and key ~= last, key
        drain()
      end
      local count = 0
      for _ in pairs(seen) do
        count = count + 1
      end
      check(kind .. ' death playback varies without consecutive repeats', count == 3 and different)
      check(
        kind .. ' variant selection leaves simulation RNG alone',
        random == love.math.getRandomState()
      )
      local body = Recipes[sounds.breath]
      check(
        kind .. ' has distinct movement and recovery voices',
        body.presence ~= nil
          and body.presence.move ~= body.presence.recover
          and body.presence.move ~= sounds.breath
      )
      local g = F.arena(Game)
      local e = g:spawn(kind, g.player.x + 3, g.player.z)
      local calls = {}
      A.playAt = function(name)
        calls[#calls + 1] = name
      end
      A.stopVoice = function() end
      for _, mode in ipairs({ 'move', 'recover' }) do
        Presence.reset()
        calls = {}
        e.ai, e.walkSpeed, e.spawnAge = mode, mode == 'move' and 2 or 0, 2
        local before = Integrity.capture(g)
        for _ = 1, mode == 'recover' and 30 or 180 do
          Presence.update(A, g, 1 / 60)
        end
        check(
          kind .. ' voices ' .. mode .. ' from the actual body state',
          body.presence and calls[1] == body.presence[mode]
        )
        check(
          kind .. ' presence is presentation only',
          not Integrity.difference(before, Integrity.capture(g))
        )
      end
      A.playAt, A.stopVoice = playAt, stopVoice
    end
    for _, name in ipairs({
      'owl_star_warning',
      'owl_trio_warning',
      'owl_release',
      'iron_charge_effort',
      'iron_slam_effort',
      'gardener_retch_prepare',
      'gardener_sow_release',
      'ember_claw_effort',
      'ember_leap_effort',
    }) do
      local data = require('src.audio.voice_data').render(name, Recipes[name], A.rate)
      local sum = 0
      for i = 0, data:getSampleCount() - 1 do
        sum = sum + data:getSample(i) ^ 2
      end
      local rms = math.sqrt(sum / data:getSampleCount())
      data:release()
      local source = A.playAt(name, 10, 0, { x = 0, z = 0, yaw = 0 }, 0.58, 2)
      check(name .. ' carries an audible body at ten metres', source:getVolume() * rms >= 0.045)
      drain()
    end
    for _, voices in ipairs({
      require('src.audio.owl_voices'),
      require('src.audio.iron_voices'),
      require('src.audio.garden_voices'),
      require('src.audio.ember_voices'),
    }) do
      for name, recipe in pairs(voices) do
        local paths, hashes = { recipe.path }, {}
        for _, path in ipairs(recipe.variants or {}) do
          paths[#paths + 1] = path
        end
        for _, path in ipairs(paths) do
          local bytes = assert(love.filesystem.read(path))
          local hash = love.data.hash('sha256', bytes)
          check(path .. ' is an independent performance', not hashes[hash])
          hashes[hash] = true
          local data = require('src.audio.voice_data').render(name, { path = path }, A.rate)
          local peak, sum, jump, previous = 0, 0, 0, 0
          for i = 0, data:getSampleCount() - 1 do
            local value = data:getSample(i)
            peak, sum = math.max(peak, math.abs(value)), sum + value * value
            jump, previous = math.max(jump, math.abs(value - previous)), value
          end
          check(
            path .. ' has headroom, body and smooth endpoints',
            peak <= 0.581
              and sum / data:getSampleCount() >= 0.003
              and jump < 0.2
              and math.abs(data:getSample(0)) < 0.001
              and math.abs(previous) < 0.001
              and math.abs(data:getDuration() - recipe.duration) < 0.002
          )
          data:release()
        end
        A.levels.effects = 0
        local silent = A.play(name, 0.7)
        check(name .. ' obeys the effects mute', silent and silent:getVolume() == 0)
        drain()
        A.levels.effects = 1
      end
    end
    do
      -- Three simultaneous reload answers can align their recordings. Test
      -- the actual runtime gains with the loud recorded Exorcist take.
      local VoiceData = require('src.audio.voice_data')
      local throat = VoiceData.render('ember_leap_effort', Recipes.ember_leap_effort, A.rate)
      local cloth = VoiceData.render('ember_prepare', Recipes.ember_prepare, A.rate)
      local shot = VoiceData.render('shot', { path = 'assets/sounds/exorcist/B1-3.wav' }, A.rate)
      local voice = A.playAt('ember_leap_effort', 0, 0, { x = 0, z = 0, yaw = 0 }, 0.58, 2)
      local throatGain = voice:getVolume()
      drain()
      voice = A.playAt('ember_prepare', 0, 0, { x = 0, z = 0, yaw = 0 }, 0.7, 3)
      local clothGain = voice:getVolume()
      drain()
      local peak, start = 0, math.floor(A.rate * 0.15)
      for i = 0, math.max(throat:getSampleCount(), cloth:getSampleCount(), shot:getSampleCount() + start) - 1 do
        local sample = 0
        if i < throat:getSampleCount() then
          sample = sample + throat:getSample(i) * throatGain * 3
        end
        if i < cloth:getSampleCount() then
          sample = sample + cloth:getSample(i) * clothGain * 3
        end
        if i >= start and i - start < shot:getSampleCount() then
          sample = sample
            + shot:getSample(i - start) * 0.95 * require('src.content.sound_sets').cues.shot.gain
        end
        peak = math.max(peak, math.abs(sample * 0.7))
      end
      throat:release()
      cloth:release()
      shot:release()
      check(
        'three aligned Ember warnings leave headroom for Exorcist (peak '
          .. string.format('%.3f', peak)
          .. ')',
        peak < 1
      )
    end
    -- Defaults must not rebalance shared spells or the knight's weapon sets.
    local generic = A.playAt('cast', 10, 0, { x = 0, z = 0, yaw = 0 }, 0.7)
    check(
      'unmodified voices retain their original attenuation',
      math.abs(generic:getVolume() - 0.7 / 2.3) < 0.00001
    )
    drain()
    local oldSet = A.set
    for _, set in ipairs({ 'classic', 'iron', 'stone' }) do
      A.useSet(set)
      local shot = A.play('revolver', 0.5)
      local gain = A.baked('revolver') and require('src.content.sound_sets').cues.revolver.gain or 1
      check(set .. ' retains its weapon gain', math.abs(shot:getVolume() - 0.5 * gain) < 0.00001)
      drain()
    end
    A.useSet(oldSet)
    for _ = 1, 28 do
      A.play('crypt_drip', 0.01)
    end
    local effort = A.play('iron_charge_effort', 0.3, 2)
    check(
      'physical effort survives crowd ambience and opens music space',
      effort and A.priorities[effort] == 3 and A.warningHold > 0
    )
    for i = 1, 150 do
      A.play(i % 2 == 0 and 'owl_death' or 'gardener_death', 0.01)
    end
    check('variants preserve the voice and cache caps', #A.live <= 28 and A.pooled <= 28)
    drain()
    check('variants retire without live voices', #A.live == 0)
    A.muted = true
    check('master mute prevents variant playback', A.play('owl_death') == nil)
  end, debug.traceback)
  A.playAt, A.stopVoice, A.muted, A.levels.effects = playAt, stopVoice, muted, effects
  Presence.reset()
  drain()
  for _, list in pairs(A.pool) do
    for _, source in ipairs(list) do
      source:release()
    end
  end
  for field, value in pairs(previous) do
    A[field] = value
  end
  A.warningHold = warningHold
  love.math.setRandomState(randomState)
  assert(ok, err)
  assert(#failures == 0, table.concat(lines, '\n'))
  return lines
end
return T
