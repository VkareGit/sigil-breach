-- Compare catch-up rendering with the former capture-before-every-tick path.
-- Real worlds, moving/casting creatures, shots, a second actor and a detached
-- camera exercise the geometry and view histories that must stay identical.
local T = {}
function T.run(check)
  local Application = require('src.app.application')
  local Game = require('src.session.game')
  local Field = require('src.run.test_field')
  local P = require('src.render.presentation')
  local Context = require('src.session.context')
  local Pools = require('src.session.world')
  local Weapons = require('src.content.weapons')
  local Abilities = require('src.content.abilities')
  local Observation = require('src.combat.observation')
  local Serialize = require('src.core.serialize')
  local Fields = require('src.session.fields')
  local Golden = require('qa.golden')
  local frame = 0
  local function fixture()
    local app = Application.new()
    local g = Field.new(Game)
    g.ephemeral = true
    Field.close(g)
    g.player.x, g.player.z, g.player.yaw = 16, 24, math.pi
    for i, kind in ipairs({ 'imp', 'stolas', 'boss' }) do
      local e = g:spawn(kind, 12 + i * 2, 18)
      e.awake, e.spawnAge = true, 2
    end
    local kit = { 'exorcist', 'judge' }
    local b = g.ecs:create('knight', {
      id = 'catchup_b',
      x = 18,
      z = 24,
      yaw = math.pi,
      hp = 80,
      loadout = kit,
      arsenal = Weapons.arsenal(kit),
      weapon = 2,
      abilities = { 'powder' },
      abilityState = Abilities.kit({ 'powder' }),
    }, false)
    assert(g:actorJoin(Pools.memberRecord(b)))
    b = Pools.get(g, 'catchup_b')
    Context.watch(g, b)
    local camera = { x = 21, y = 1.6, z = 22, yaw = 3.8, pitch = 0 }
    Context.of(g, b, camera)
    app.game = g
    app.input.sample = function(input)
      return {
        forward = frame % 3 == 0 and 1 or 0,
        strafe = frame % 2 == 0 and 1 or -1,
        turn = 0,
        shoot = frame % 4 == 0,
        fireCommand = input:command(g),
        jump = frame % 11 == 0,
        dash = frame % 13 == 0,
        slide = frame % 7 == 0,
      }
    end
    return app, b, camera
  end
  local current, b, camera = fixture()
  local old, oldB, oldCamera = fixture()
  local function previousUpdate(app, dt)
    local input = app.input:sample(app.game)
    app.accumulator = math.min(0.20, app.accumulator + dt)
    while app.accumulator >= 1 / 120 do
      P.capture(app.game)
      app.game:update(1 / 120, input)
      app.input:consumeEdges(input)
      app.accumulator = app.accumulator - 1 / 120
    end
  end
  local function describe(g, shown, actor)
    local observation = Observation.capture(shown, g, actor)
    local view = {}
    for _, group in ipairs(Fields.viewGroups) do
      for _, key in ipairs(group.names) do
        local value = shown.view[key]
        if type(value) == 'number' or type(value) == 'string' or type(value) == 'boolean' then
          view[key] = value
        end
      end
    end
    return Serialize.encode({
      origin = observation.origin,
      bodies = observation.bodies,
      view = view,
    })
  end
  local poses, state, histories = true, true, true
  local deltas = { 1 / 240, 1 / 120, 1 / 60, 1 / 30, 0.20, 1 / 144 }
  for i = 1, 48 do
    frame = i
    local dt = deltas[1 + (i - 1) % #deltas]
    current:update(dt)
    previousUpdate(old, dt)
    local g, h = current.game, old.game
    for index, pair in ipairs({
      { g, h, g.player, h.player },
      { Context.of(g, b), Context.of(h, oldB), b, oldB },
      { Context.of(g, b, camera), Context.of(h, oldB, oldCamera), b, oldB },
    }) do
      local shown = P.sample(pair[1], current.accumulator * 120)
      local previous = P.sample(pair[2], old.accumulator * 120)
      poses = poses and describe(g, shown, pair[3]) == describe(h, previous, pair[4])
      if index == 1 then
        current.input:present(g, shown)
        old.input:present(h, previous)
      end
      histories = histories
        and (pair[1].view.presentationPrevious == nil)
          == (pair[2].view.presentationPrevious == nil)
    end
    state = state
      and Golden.digest(g) == Golden.digest(h)
      and current.accumulator == old.accumulator
  end
  check(
    'catch-up and per-tick captures give identical painted hit surfaces and all scalar view fields in three views',
    poses
  )
  check('catch-up capture scheduling preserves real movement, firing and simulation digests', state)
  check('catch-up capture scheduling preserves view-history lifetime', histories)
end
return T
