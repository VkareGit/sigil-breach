-- The common thrall must communicate movement separately from a damaging blow.
local T = {}
function T.run(Game, renderer)
  local F = require('tests.support.fixtures')
  local Enemies = require('src.content.enemies')
  local Anim = require('src.enemies.animation')
  local Pose = require('src.enemies.pose')
  local Actions = require('src.enemies.actions')
  local Recipes = require('src.audio.recipes')
  local Feedback = require('src.feedback.world_feedback')
  local Audio = require('src.audio.audio')
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'ember: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local g = F.arena(Game)
  local e = g:spawn('imp', 16, 23.2)
  e.spawnAge, e.facing, e.target = 2, 0, g.player.id
  local specs = {}
  for _, spec in ipairs(Enemies.imp.attacks) do
    specs[spec.id] = spec
  end
  check(
    'the common body retains its health and speed',
    Enemies.imp.body.hp == 360 and Enemies.imp.move.speed == 4.6
  )
  check('retreat never advertises a damaging release', specs['hop-back'].warning == false)
  local sequence = {}
  for _, id in ipairs({ 'claw', 'claw-late', 'pounce', 'hop-back' }) do
    Actions.begin(g, e, 1.8, specs[id])
    local frames = {}
    for _, t in ipairs({ 0, 0.25, 0.5, 0.75, 0.95 }) do
      e.holdSpan, e.holdLeft = nil, nil
      e.phase, e.windup = t * e.windupDuration, (1 - t) * e.windupDuration
      frames[#frames + 1] = Anim.pose(g, e)
    end
    sequence[id] = table.concat(frames, ',')
  end
  check('retreat has no claw windup', sequence['hop-back'] ~= sequence.claw)
  check('the held second claw has its own preparation', sequence['claw-late'] ~= sequence.claw)
  check('the landing follow-up has its own preparation', sequence.pounce ~= sequence.claw)
  e.ai, e.phase, e.attackKind, e.attackSpec = 'strike', 0.1, 'hop-back', specs['hop-back']
  local retreat = Pose.sample(g, e)
  check(
    'retreat never shows the two extended striking paintings',
    retreat.frame ~= 10 and retreat.frame ~= 11
  )
  local playAt, calls = Audio.playAt, {}
  Audio.playAt = function(name)
    calls[#calls + 1] = name
  end
  local ok, err = xpcall(function()
    Feedback.handlers.AttackTelegraphed(g, { enemy = e, attack = specs['hop-back'] })
    Feedback.handlers.AttackReleased(g, { enemy = e, attack = specs['hop-back'] })
  end, debug.traceback)
  Audio.playAt = playAt
  if not ok then
    error(err, 0)
  end
  local wrong = false
  for _, name in ipairs(calls) do
    wrong = wrong or name == 'snarl' or name == 'claw' or name == Enemies.imp.sounds.windup
  end
  check('retreat audio does not reuse an attack warning or rake', not wrong)
  for _, role in ipairs({ 'breath', 'murmur', 'hurt', 'death', 'alert' }) do
    local name = Enemies.imp.sounds[role]
    local recipe = name and Recipes[name]
    check(
      role .. ' belongs to a recorded Ember voice',
      recipe ~= nil and recipe.path ~= nil and recipe.path:find('/ember-thrall/', 1, true) ~= nil
    )
  end
  local death = Recipes[Enemies.imp.sounds.death or '']
  check('death has three distinct performances', death ~= nil and #(death.variants or {}) == 2)
  for _, id in ipairs({ 'claw', 'claw-late', 'leap', 'pounce' }) do
    check(
      id .. ' has both bodily effort and attack material',
      specs[id].windupVoice ~= nil
        and specs[id].sound ~= nil
        and specs[id].windupVoice ~= specs[id].sound
    )
  end
  check(
    'Iron retains its own voice and palette',
    Enemies.armored.sounds.death == 'iron_death'
      and Enemies.armored.appearance.atlas == 'armored'
      and Enemies.armored.appearance.art.leap == false
  )
  local World = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local Rules = require('src.combat.rules')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local function actor(distance)
    local session = F.arena(Game)
    for z = 8, 30 do
      for x = 8, 26 do
        World.setCell(session.world, x, z, Tiles.floor)
      end
    end
    session.player.x, session.player.z, session.player.armor = 16, 20 + distance, 0
    session.rng.sim:seed(1)
    local body = session:spawn('imp', 16, 20)
    body.target, body.facing, body.awake, body.visible, body.memory, body.spawnAge, body.sense =
      session.player.id, 0, true, true, 60, 2, 10
    return session, body
  end
  local function step(session, body, dt, input)
    body.attack = 999
    body.answered = { hugging = 999, reloading = 999, drinking = 999 }
    session:update(dt, input or {})
  end
  for _, hz in ipairs({ 60, 120, 240 }) do
    for _, id in ipairs({ 'claw', 'claw-late', 'leap', 'pounce', 'hop-back' }) do
      for _, response in ipairs({ 'still', 'dodge' }) do
        local distance = id == 'leap' and 5 or (id == 'pounce' and 3 or 1.8)
        local session, body = actor(distance)
        local initial = session.player.hp
        Actions.begin(session, body, distance, specs[id])
        local released = false
        for _ = 1, hz * 3 do
          local ready = response == 'dodge' and body.ai == 'windup' and body.windup < 0.1
          step(session, body, 1 / hz, { strafe = ready and 1 or 0, dash = ready })
          released = released or body.ai == 'strike'
          if released and body.ai ~= 'strike' then
            break
          end
        end
        local loss = initial - session.player.hp
        check(
          id .. ' ' .. response .. ' at ' .. hz .. ' Hz',
          released and (response == 'dodge' or id == 'hop-back') and loss == 0
            or released
              and response == 'still'
              and id ~= 'hop-back'
              and loss == specs[id].packet.base
        )
      end
    end
  end
  -- Replaying each state restores clocks, pose-dependent contact and the pending string.
  for _, id in ipairs({ 'claw', 'claw-late', 'leap', 'pounce', 'hop-back' }) do
    for _, phase in ipairs({ 'windup', 'strike', 'recover' }) do
      local distance = id == 'leap' and 5 or (id == 'pounce' and 3 or 1.8)
      local session, body = actor(distance)
      Actions.begin(session, body, distance, specs[id])
      for _ = 1, 300 do
        if body.ai == phase then
          break
        end
        step(session, body, 1 / 120)
      end
      check(id .. ' reaches ' .. phase, body.ai == phase)
      local saved = Snapshot.capture(session)
      for _ = 1, 90 do
        step(session, body, 1 / 120)
      end
      local expected = Integrity.capture(session)
      Snapshot.restore(session, saved)
      body = session.enemies[1]
      for _ = 1, 90 do
        step(session, body, 1 / 120)
      end
      check(
        id .. ' restores ' .. phase .. ' without drift',
        not Integrity.difference(expected, Integrity.capture(session))
      )
    end
    for _, terminal in ipairs({ 'interrupt', 'death' }) do
      local session, body = actor(1.8)
      Actions.begin(session, body, 1.8, specs[id])
      if terminal == 'death' then
        body.hp = 0
      else
        Rules.interrupt(body)
      end
      local initial = session.player.hp
      for _ = 1, 90 do
        step(session, body, 1 / 120)
      end
      check(id .. ' ' .. terminal .. ' cancels the prepared contact', session.player.hp == initial)
    end
  end
  for _, id in ipairs({ 'claw', 'claw-late', 'leap', 'pounce' }) do
    local session, body = actor(3)
    World.setCell(session.world, 16, 21, Tiles.wall)
    Actions.begin(session, body, 3, specs[id])
    local initial = session.player.hp
    for _ = 1, 180 do
      step(session, body, 1 / 120)
    end
    check(id .. ' cannot hurt through a stone obstacle', session.player.hp == initial)
  end
  do
    local session, body = actor(5)
    Actions.begin(session, body, 5, specs.leap)
    for _ = 1, 180 do
      step(session, body, 1 / 120)
      if body.leaping then
        break
      end
    end
    local vx, vz = body.leapVX, body.leapVZ
    session.player.x = session.player.x + 8
    step(session, body, 1 / 120)
    check(
      'a released leap cannot secretly follow a sidestep',
      body.leaping and math.abs(body.leapVX - vx) < 1e-9 and math.abs(body.leapVZ - vz) < 1e-9
    )
  end
  do
    local session, body = actor(5)
    local HazardArt = require('src.render.hazard_art')
    local circle, upright = HazardArt.circle, HazardArt.upright
    local marks, cuts = {}, {}
    HazardArt.circle = function(_, _, source)
      marks[#marks + 1] = source
    end
    HazardArt.upright = function(_, _, _, _, cell)
      cuts[#cuts + 1] = cell
    end
    local drawn, failure = xpcall(function()
      Actions.begin(session, body, 5, specs.leap)
      local before = Integrity.capture(session)
      renderer:draw(session, 960, 540)
      local remote = false
      for _, source in ipairs(marks) do
        remote = remote or source ~= body
      end
      check('a bodily leap has no false remote landing promise', not remote)
      check(
        'drawing preserves simulation and RNG',
        not Integrity.difference(before, Integrity.capture(session))
      )
      Actions.begin(session, body, 2, specs['hop-back'])
      marks = {}
      require('src.render.passes.enemy_marks').draw(renderer, session)
      check('a retreat paints no damaging ground warning', #marks == 0)
      Actions.begin(session, body, 3, specs.pounce)
      Actions.execute(session, body)
      body.ai, body.phase = 'strike', 0.1
      require('src.render.effects').spells(renderer, session)
      check(
        'the physical rake uses the approved bone and ochre sequence',
        cuts[1] and cuts[1]:match('^ironCut') ~= nil
      )
    end, debug.traceback)
    HazardArt.circle, HazardArt.upright = circle, upright
    assert(drawn, failure)
  end
  do
    local Presence = require('src.audio.body_voices')
    local session, body = actor(3)
    local play, stop = Audio.playAt, Audio.stopVoice
    local calls, stops = {}, {}
    Audio.playAt = function(name, x, z)
      local cue = { name = name, x = x, z = z }
      calls[#calls + 1] = cue
      return cue, #calls
    end
    Audio.stopVoice = function(source)
      stops[#stops + 1] = source
    end
    local sounded, failure = xpcall(function()
      for _, id in ipairs({ 'claw', 'claw-late', 'leap', 'pounce' }) do
        calls, stops = {}, {}
        Feedback.handlers.AttackTelegraphed(session, { enemy = body, attack = specs[id] })
        check(
          id .. ' speaks effort and material from the actual body',
          #calls == 2
            and calls[1].name ~= calls[2].name
            and calls[1].x == body.x
            and calls[2].z == body.z
        )
        Feedback.handlers.AttackCancelled(session, { enemy = body })
        check(id .. ' cancellation stops both preparation layers', #stops == 2)
        calls, stops = {}, {}
        Feedback.handlers.AttackTelegraphed(session, { enemy = body, attack = specs[id] })
        Feedback.handlers.EnemyKilled(session, { enemy = body })
        check(id .. ' death leaves no pending effort', #stops == 2)
      end
      body.attackSpec = specs.leap
      calls = {}
      Feedback.handlers.Landed(session, { enemy = body })
      check(
        'landing sounds at physical contact, not the aimed point',
        #calls == 1
          and calls[1].name == 'ember_landing'
          and calls[1].x == body.x
          and calls[1].z == body.z
      )
      for i = 1, 31 do
        local other = session:spawn('imp', 16 + (i % 4), 21 + math.floor(i / 4))
        other.ai, other.spawnAge = 'move', 2
      end
      Presence.reset()
      calls = {}
      for _ = 1, 600 do
        Presence.update(Audio, session, 1 / 60)
      end
      check('32 bodies leave silence between presence calls', #calls >= 2 and #calls <= 9)
      for _, mode in ipairs({ 'pause', 'map', 'help', 'death', 'attack', 'distance' }) do
        Presence.reset()
        calls = {}
        session.enemies = { body }
        session.state, session.map, session.help, body.hp, body.ai, body.x =
          'playing', false, false, 360, 'move', 16
        if mode == 'pause' then
          session.state = 'paused'
        elseif mode == 'map' then
          session.map = true
        elseif mode == 'help' then
          session.help = true
        elseif mode == 'death' then
          body.hp = 0
        elseif mode == 'attack' then
          body.ai = 'windup'
        else
          body.x = 80
        end
        for _ = 1, 180 do
          Presence.update(Audio, session, 1 / 60)
        end
        check(mode .. ' suppresses ambient throat calls', #calls == 0)
      end
    end, debug.traceback)
    Presence.reset()
    Audio.playAt, Audio.stopVoice = play, stop
    assert(sounded, failure)
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T
