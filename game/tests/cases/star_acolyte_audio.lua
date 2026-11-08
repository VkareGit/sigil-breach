-- The caster's warnings distinguish commitments without relying on volume.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local A = require('src.audio.audio')
  local Enemies = require('src.content.enemies')
  local Actions = require('src.enemies.actions')
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'owl audio: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local cues = {}
  for _, role in ipairs({ 'breath', 'hurt', 'death' }) do
    check('the creature has its own ' .. role .. ' voice', Enemies.stolas.sounds[role] ~= nil)
  end
  for _, attack in ipairs(Enemies.stolas.attacks) do
    local cue = attack.windupSound or Enemies.stolas.sounds.windup
    check(attack.id .. ' has a distinct warning', not cues[cue])
    cues[cue] = true
  end
  local VoiceData = require('src.audio.voice_data')
  for name, recipe in pairs(require('src.content.creatures.stolas.voices')) do
    local data = VoiceData.render(name, recipe, A.rate)
    local peak, sum, jump, previous = 0, 0, 0, 0
    for i = 0, data:getSampleCount() - 1 do
      local value = data:getSample(i)
      peak, sum = math.max(peak, math.abs(value)), sum + value * value
      jump, previous = math.max(jump, math.abs(value - previous)), value
    end
    check(
      name .. ' has headroom, an audible body and smooth endpoints',
      peak < 0.65
        and sum / data:getSampleCount() > 0.0001
        and jump < 0.2
        and math.abs(data:getSample(0)) < 0.001
        and math.abs(previous) < 0.001
    )
    data:release()
  end
  local play, stop, calls, stoppedWarnings = A.playAt, A.stopVoice, {}, {}
  A.playAt = function(name, x, z, _, volume)
    calls[#calls + 1] = { name = name, x = x, z = z, volume = volume }
    return { name = name }, #calls
  end
  A.stopVoice = function(source, ticket)
    stoppedWarnings[#stoppedWarnings + 1] = { source = source, ticket = ticket }
  end
  local ok, err = xpcall(function()
    local caster = F.arena(Game)
    local owl = caster:spawn('stolas', 16, 20)
    local handlers = require('src.feedback.world_feedback').handlers
    for _, attack in ipairs(Enemies.stolas.attacks) do
      calls, stoppedWarnings = {}, {}
      handlers.AttackTelegraphed(caster, { enemy = owl, attack = attack })
      check(
        attack.id .. ' has a separate vocal performance beside its spell sound',
        #calls == 2
          and calls[1].name ~= calls[2].name
          and calls[1].x == owl.x
          and calls[2].x == owl.x
          and calls[1].z == owl.z
          and calls[2].z == owl.z
      )
      handlers.AttackCancelled(caster, { enemy = owl })
      check(attack.id .. ' cancellation stops both warning layers', #stoppedWarnings == 2)
    end
    calls, stoppedWarnings = {}, {}
    handlers.AttackTelegraphed(caster, { enemy = owl, attack = Enemies.stolas.attacks[1] })
    handlers.EnemyKilled(caster, { enemy = owl })
    check('death stops the caster voice together with the pending spell', #stoppedWarnings == 2)
    calls = {}
    local WorldCues = require('src.audio.world_cues')
    local Integrity = require('src.session.integrity')
    local quiet = F.arena(Game)
    local body = quiet:spawn('stolas', 16, 20)
    body.spawnAge, body.awake, body.ai = 2, true, 'move'
    WorldCues.reset()
    local state = Integrity.capture(quiet)
    for _ = 1, 1200 do
      WorldCues.update(A, quiet, 1 / 60)
    end
    check('a nearby non-casting creature breathes between spells', #calls >= 2)
    check(
      'body voices never alter the fight or its random stream',
      not Integrity.difference(state, Integrity.capture(quiet))
    )
    calls = {}
    body.hp = 0
    for _ = 1, 600 do
      WorldCues.update(A, quiet, 1 / 60)
    end
    check('a corpse cannot keep breathing', #calls == 0)
    body.hp, body.ai = 100, 'move'
    for _, mode in ipairs({ 'paused', 'map', 'help', 'distant', 'casting' }) do
      quiet.state, quiet.map, quiet.help, body.x, body.ai = 'playing', false, false, 16, 'move'
      if mode == 'paused' then
        quiet.state = 'paused'
      elseif mode == 'map' then
        quiet.map = true
      elseif mode == 'help' then
        quiet.help = true
      elseif mode == 'distant' then
        body.x = 100
      else
        body.ai = 'windup'
      end
      calls = {}
      for _ = 1, 600 do
        WorldCues.update(A, quiet, 1 / 60)
      end
      check(mode .. ' suppresses incidental body chatter', #calls == 0)
    end
    local crowd = F.arena(Game)
    for i = 1, 128 do
      local creature = crowd:spawn('stolas', 16, 20)
      creature.ai, creature.spawnAge = 'move', 2
    end
    calls = {}
    for _ = 1, 600 do
      WorldCues.update(A, crowd, 1 / 60)
    end
    check('128 bodies share a bounded breath cadence', #calls >= 2 and #calls <= 9)
    calls = {}
    local handlers = require('src.feedback.world_feedback').handlers
    local creature = crowd.enemies[1]
    handlers.Alerted(crowd, { enemy = creature })
    check(
      'detection has its own creature call',
      #calls == 1 and calls[1].name == Enemies.stolas.sounds.alert
    )
    calls = {}
    for _ = 1, 20 do
      handlers.BodyHit(crowd, { enemy = creature, health = 1 })
    end
    check(
      'pellets cannot stack twenty pain calls',
      #calls == 1 and calls[1].name == Enemies.stolas.sounds.hurt
    )
    calls = {}
    creature.hp = 0
    handlers.BodyHit(crowd, { enemy = creature, health = 1 })
    check('a lethal hit leaves the voice to the death event', #calls == 0)
    local BodyVoices = require('src.audio.body_voices')
    local stopped, source = 0, {}
    local native = {
      playAt = function()
        return source, 1
      end,
      stopVoice = function(s, ticket)
        assert(s == source and ticket == 1)
        stopped = stopped + 1
      end,
    }
    local wounded = F.arena(Game)
    local hurt = wounded:spawn('stolas', 16, 20)
    hurt.ai = 'hurt'
    BodyVoices.hurt(native, wounded, hurt)
    BodyVoices.update(native, wounded, 1 / 60)
    check('the pain voice survives its own hurt animation', stopped == 0)
    BodyVoices.interrupt(native, wounded, hurt)
    check('a new commitment can stop a previous body voice by ticket', stopped == 1)
    wounded.elapsed = wounded.elapsed + 1
    BodyVoices.hurt(native, wounded, hurt)
    wounded.state = 'paused'
    BodyVoices.update(native, wounded, 1 / 60)
    check('pausing stops an already playing body voice', stopped == 2)
    WorldCues.reset()
    local g = F.arena(Game)
    local e = g:spawn('stolas', 16, 18)
    e.target = g.player.id
    local blink
    for _, attack in ipairs(Enemies.stolas.attacks) do
      if attack.kind == 'blink' then
        blink = attack
      end
    end
    Actions.begin(g, e, 3, blink)
    calls = {}
    Actions.execute(g, e)
    local arrivals, departures = 0, 0
    for _, call in ipairs(calls) do
      if call.x == e.x and call.z == e.z then
        arrivals = arrivals + 1
      end
      if call.x == 16 and call.z == 18 then
        departures = departures + 1
      end
    end
    check(
      'teleport has one departure and one arrival, without stacked release voices',
      departures == 1 and arrivals == 1
    )
    calls = {}
    require('src.feedback.world_feedback').handlers.AttackReleased(g, { enemy = e, attack = blink })
    check('a blink without a successful destination does not sound a false arrival', #calls == 0)
  end, debug.traceback)
  A.playAt, A.stopVoice = play, stop
  assert(ok, err)
  for _, line in ipairs(lines) do
    print(line)
  end
  assert(#failures == 0, table.concat(failures, '; '))
  return lines
end
return T
