local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local A = require('src.audio.audio')
  local Enemies = require('src.content.enemies')
  local C = require('src.audio.world_cues')
  local H = require('src.feedback.world_feedback').handlers
  local Integrity = require('src.session.integrity')
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'iron audio: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local sounds = Enemies.armored.sounds
  for _, role in ipairs({ 'breath', 'murmur', 'hurt', 'death', 'alert' }) do
    check(
      'the body has its own ' .. role,
      sounds[role] ~= nil and sounds[role] ~= Enemies.imp.sounds[role]
    )
  end
  local play, stop = A.playAt, A.stopVoice
  local calls, stops = {}, {}
  A.playAt = function(name, x, z)
    calls[#calls + 1] = { name = name, x = x, z = z }
    return { name = name }, #calls
  end
  A.stopVoice = function(source, ticket)
    stops[#stops + 1] = { source, ticket }
  end
  local ok, err = xpcall(function()
    local g = F.arena(Game)
    local e = g:spawn('armored', 16, 20)
    e.awake, e.spawnAge, e.ai = true, 2, 'move'
    local voices = {}
    for _, attack in ipairs(Enemies.armored.attacks) do
      calls, stops = {}, {}
      H.AttackTelegraphed(g, { enemy = e, attack = attack })
      check(
        attack.id .. ' has its own preparation effort',
        attack.windupVoice ~= nil and not voices[attack.windupVoice]
      )
      if attack.windupVoice then
        voices[attack.windupVoice] = true
      end
      check(
        attack.id .. ' separates the throat from moving iron',
        #calls == 2 and calls[1].name ~= calls[2].name and calls[2].x == e.x and calls[2].z == e.z
      )
      H.AttackCancelled(g, { enemy = e })
      check(attack.id .. ' cancellation stops both layers', #stops == 2)
    end
    C.reset()
    calls = {}
    local before = Integrity.capture(g)
    for _ = 1, 1200 do
      C.update(A, g, 1 / 60)
    end
    check('the body breathes between attacks', #calls >= 2)
    check(
      'presence never changes simulation or RNG',
      not Integrity.difference(before, Integrity.capture(g))
    )
    calls = {}
    for _ = 1, 20 do
      H.BodyHit(g, { enemy = e, health = 1 })
    end
    check('pellets share one pain call', #calls == 1 and calls[1].name == sounds.hurt)
    for _, mode in ipairs({ 'paused', 'map', 'help', 'dead', 'distant', 'attacking' }) do
      g.state, g.map, g.help, e.hp, e.x, e.ai = 'playing', false, false, 560, 16, 'move'
      if mode == 'paused' then
        g.state = 'paused'
      elseif mode == 'map' then
        g.map = true
      elseif mode == 'help' then
        g.help = true
      elseif mode == 'dead' then
        e.hp = 0
      elseif mode == 'distant' then
        e.x = 100
      else
        e.ai = 'strike'
      end
      calls = {}
      for _ = 1, 600 do
        C.update(A, g, 1 / 60)
      end
      check(mode .. ' suppresses incidental breathing', #calls == 0)
    end
    local crowd = F.arena(Game)
    for i = 1, 128 do
      local b = crowd:spawn(i % 2 == 0 and 'armored' or 'stolas', 16, 20)
      b.ai, b.spawnAge = 'move', 2
    end
    calls = {}
    for _ = 1, 600 do
      C.update(A, crowd, 1 / 60)
    end
    check('128 mixed bodies share the room voice budget', #calls >= 2 and #calls <= 9)
    -- A moving, seconds-clocked foot cycle is heard; the charge pause cannot drum in place.
    g = F.arena(Game)
    e = g:spawn('armored', 16, 20)
    e.spawnAge, e.ai, e.attackKind, e.phase, e.walkSpeed = 2, 'strike', 'shoulder', 0.02, 0
    C.reset()
    calls = {}
    C.update(A, g, 1 / 60)
    e.phase, e.z = 0.2, 20.4
    C.update(A, g, 1 / 60)
    check(
      'the running charge has a foot contact without a walking clock',
      #calls == 1 and calls[1].name == sounds.step
    )
    calls = {}
    e.act = e.act or {}
    e.act.turnAt = 0.7
    for i = 1, 20 do
      e.phase = e.phase + 1 / 60
      C.update(A, g, 1 / 60)
    end
    check('the planted return pause has no false running steps', #calls == 0)
    e.act.turnAt = nil
    e.phase, e.z = 0.9, 20.8
    C.update(A, g, 1 / 60)
    e.phase, e.z = 1.1, 21.2
    C.update(A, g, 1 / 60)
    check('foot contacts resume with the return rush', #calls >= 1)
    calls = {}
    e.hp = 0
    e.phase, e.z = 1.3, 21.6
    C.update(A, g, 1 / 60)
    check('death ends charge footfalls', #calls == 0)
  end, debug.traceback)
  A.playAt, A.stopVoice = play, stop
  C.reset()
  assert(ok, err)
  for name, recipe in pairs(require('src.audio.banks.iron_voices')) do
    local data = require('src.audio.voice_data').render(name, recipe, A.rate)
    local peak, sum, jump, prev = 0, 0, 0, 0
    for i = 0, data:getSampleCount() - 1 do
      local v = data:getSample(i)
      peak = math.max(peak, math.abs(v))
      sum = sum + v * v
      jump = math.max(jump, math.abs(v - prev))
      prev = v
    end
    check(
      name .. ' retains headroom and smooth audible endpoints',
      peak < 0.65
        and sum / data:getSampleCount() > 0.0001
        and jump < 0.2
        and math.abs(data:getSample(0)) < 0.001
        and math.abs(prev) < 0.001
    )
    data:release()
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T
