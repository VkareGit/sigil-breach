local Fixtures = require('tests.support.fixtures')
local Field = require('src.run.test_field')
local Chambers = require('src.run.field.chambers')
local Maps = require('src.content.maps.index')
local W = require('src.world.arena')
local Gallery = require('src.world.gallery')
local Integrity = require('src.session.integrity')
local Snapshot = require('src.session.snapshot')
local Journal = require('src.session.journal')
local Pools = require('src.session.world')
local Schema = require('src.core.schema')
local Release = require('src.app.release')
local Tests = {}
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'chambers: ', 'chambers: ')
  local function fresh()
    local g = Game.new('field', Release.sessionMaps.field, Release.sessionOptions.field)
    g.testing = true
    return g
  end
  local function arrive(g)
    for _ = 1, 600 do
      if #g.run.pending == 0 then
        return
      end
      g:update(1 / 120, {})
    end
    error('trial portals never arrived')
  end
  local g = fresh()
  local app = {
    sessionMaps = Release.sessionMaps,
    sessionOptions = Release.sessionOptions,
    input = { reset = function() end },
    adopt = function(self, session)
      self.game = session
    end,
  }
  local Navigation = require('src.app.navigation')
  Navigation.replace(app, 'field')
  check('public navigation uses the authored map', app.game.world.mapId == 'proving')
  Navigation.replace(app, 'field', 'limbo')
  check('explicit map remains authoritative for tools', app.game.world.mapId == 'limbo')
  local layout = Chambers.layout(g)
  local Queries = require('src.run.queries')
  local pads = Gallery.padsFor(g.world)
  check(
    'boss summoning resolves to elevated altars, not separate floor pads',
    pads[1].x == g.world.seals[1].x
      and pads[2].x == g.world.seals[2].x
      and pads[1].y > 1
      and pads[2].y > 1
      and pads[2].altar == 'furfur'
  )
  check('quiet basilica has no battle perimeter', not Queries.world(g).arenaFire)
  check(
    'public map has four authored chambers and six trials',
    #layout.chambers == 4 and #layout.trials == 6
  )
  -- Reachability uses the real footprint against walls/pillars, not the
  -- author's rectangle list. Doorways connect all entry/pad positions.
  local start = layout.stations.start
  local seen, queue = {}, { { start.x, start.z } }
  local function key(x, z)
    return x .. ':' .. z
  end
  seen[key(start.x, start.z)] = true
  local index = 1
  while queue[index] do
    local at = queue[index]
    index = index + 1
    for _, offset in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local x, z = at[1] + offset[1], at[2] + offset[2]
      if not seen[key(x, z)] and not W.solid(g.world, x, z, 0.22) then
        seen[key(x, z)] = true
        queue[#queue + 1] = { x, z }
      end
    end
  end
  for _, room in ipairs(layout.chambers) do
    check(
      room.id .. ' reachable from nave',
      seen[key(math.floor(room.entry.x + 0.5), math.floor(room.entry.z + 0.5))]
    )
    local clear = true
    for _, spot in ipairs(room.slots) do
      for _, lamp in ipairs(g.world.lamps) do
        clear = clear and (spot.x - lamp.x) ^ 2 + (spot.z - lamp.z) ^ 2 > 1.3 ^ 2
      end
    end
    check(room.id .. ' summons are visually clear of braziers', clear)
  end
  check(
    'court wall blocks a shot; doorway is genuinely open',
    not W.visible(g.world, 10, 18, 24, 18) and W.visible(g.world, 10, 28, 24, 28)
  )
  local Ground = require('src.physics.ground')
  for _, x in ipairs({ 16, 32 }) do
    check(
      'burial gallery is reachable and lower than nave ' .. x,
      seen[key(x, 4)] and Ground.ceiling(g.world, x, 4, 1.7) == 3
    )
  end
  local invalidArt = Schema.copy(Maps:get('proving'))
  invalidArt.decor.murals[1].art = 'missing-panel'
  check(
    'unknown environment artwork rejected before rendering',
    not pcall(require('src.content.maps.schema').check, invalidArt, 'invalid-art')
  )
  local Ballistics = require('src.combat.ballistics')
  for _, location in ipairs({ { 24, 25 }, { 10, 16 }, { 38, 16 }, { 16, 4 }, { 32, 4 } }) do
    local x, z = location[1], location[2]
    local roof = Ground.ceiling(g.world, x, z, 1.7)
    local distance, _, hit = Ballistics.world(g.world, x, 1.7, z, 0, 1, 0, 20)
    check(
      'enclosed roof is actual projectile geometry ' .. x .. ':' .. z,
      roof < 10 and hit ~= 'range' and math.abs(distance - (roof - 1.7)) < 0.001
    )
  end
  local unsupported = {}
  for _, arch in ipairs(g.world.decor.arches) do
    for side = -1, 1, 2 do
      local x = arch.x + side * arch.halfSpan * math.cos(arch.yaw or 0)
      local z = arch.z + side * arch.halfSpan * math.sin(arch.yaw or 0)
      if not W.solid(g.world, x, z, 0.25) then
        unsupported[#unsupported + 1] = string.format('(%.2f,%.2f)', x, z)
      end
    end
  end
  check(
    'basilica ribs spring from physical walls or columns ' .. table.concat(unsupported, ', '),
    #unsupported == 0
  )
  check(
    'basilica presbytery has two real shallow steps',
    Ground.height(g.world, 24, 6) == 0
      and Ground.height(g.world, 24, 4.5) == 0.16
      and Ground.height(g.world, 24, 2.5) == 0.32
  )
  check(
    'chapel duel lanes no longer contain the old central pillars',
    not W.solid(g.world, 10, 14, 0.55)
      and not W.solid(g.world, 10, 24, 0.55)
      and not W.solid(g.world, 38, 14, 0.55)
      and not W.solid(g.world, 38, 24, 0.55)
  )
  check(
    'combat layout omits exhibition boards and statues, keeps painted pads',
    #Gallery.layout(g.world, {}) == 0
      and #Gallery.statuesFor(g.world) == 0
      and #Gallery.padsFor(g.world) == 9
  )
  local original = Game.new('field')
  check(
    'library gallery and its original map remain available',
    original.world.mapId == 'limbo'
      and #Gallery.statuesFor(original.world) == 6
      and Gallery.padsFor(original.world) == Gallery.pads
  )
  for _, trial in ipairs(layout.trials) do
    g = fresh()
    check(
      trial.id .. ' starts through public command',
      g:act('catalog', 'field_chamber_' .. trial.id)
    )
    check(
      trial.id .. ' opens actual portal, not an instant enemy',
      #g.run.pending == 1
        and #g.enemies == 0
        and g.run.pending[1].kind == trial.creature
        and g.state == 'playing'
    )
    check(
      trial.id .. ' has no new central overlay or entry tutorial',
      g.view.messageTimer == 0 and require('src.run.queries').tools(g).combatTrial
    )
    arrive(g)
    local fire = Queries.world(g).arenaFire
    check(
      trial.id .. ' boundary belongs to the active room only',
      (trial.chamber == 'ash' or trial.chamber == 'storm') == (fire ~= nil)
    )
    local body = g.enemies[1]
    check(
      trial.id .. ' registers the real spawned identity',
      body
        and require('src.content.enemies').of(body).id == trial.creature
        and g.testField.roomTrial.actors[1] == body.id
        and g.testField.roomTrial.status == 'active'
    )
    local def = require('src.content.enemies').of(body)
    if def.phases then
      g:damageEnemy(body, body.hp, 'weapon')
      Field.update(g, 0.01)
      check(
        trial.id .. ' second life does not complete the room',
        body.hp > 0
          and g.testField.roomTrial.status == 'active'
          and Queries.world(g).arenaFire == fire
      )
    end
    g:damageEnemy(body, body.hp, 'weapon')
    Field.update(g, 0.01)
    local finished = g.testField.roomTrial.finished
    Field.update(g, 0.01)
    check(
      trial.id .. ' completes once after final death',
      g.testField.roomTrial.status == 'complete'
        and g.testField.roomTrial.finished == finished
        and not Queries.world(g).arenaFire
    )
  end
  -- Replacing a trial cancels pending arrivals and all released attacks.
  g = fresh()
  assert(g:act('catalog', 'field_chamber_ash'))
  local oldGate = g.run.pending[1]
  g.bullets[1] = { life = 5 }
  g.hazards[1] = { life = 5 }
  g.player.conditions = { exposed = 3 }
  g.player.jump, g.player.jumpV = 1, -4
  assert(g:act('catalog', 'field_chamber_storm'))
  check(
    'replacement leaves only the new trial and clears dangerous remnants',
    g.testField.roomTrial.id == 'storm'
      and #g.run.pending == 1
      and g.run.pending[1] ~= oldGate
      and #g.bullets == 0
      and #g.hazards == 0
      and g.player.jump == 0
      and (not g.player.conditions or not next(g.player.conditions))
  )
  arrive(g)
  local oldId = g.enemies[1].id
  assert(g:act('catalog', 'field_spawn_boss_3'))
  check(
    'existing catalogue requests a fresh three-target trial',
    g.testField.roomTrial.id == 'ash'
      and g.testField.roomTrial.count == 3
      and not Pools.get(g, oldId)
      and #g.run.pending == 3
  )
  arrive(g)
  check('all three portals report their actors', #g.testField.roomTrial.actors == 3)
  local before = Integrity.capture(g)
  check(
    'invalid trial or count has no partial reset',
    not Field.chamber(g, 'missing', 1)
      and not Field.chamber(g, 'ash', 4)
      and not Field.chamber(g, 'ash', 0)
      and not Field.summon(g, 'absent', 1)
      and not Field.summon(g, 'boss', 2)
      and not Integrity.difference(before, Integrity.capture(g))
  )
  local context = Field.context(g)
  g.testField.selected = 'imp'
  check('browsing a different creature does not relabel the trial', Field.context(g) == context)
  for _, station in ipairs({ 'range', 'physics' }) do
    Field[station](g)
    local clear = not g.testField.roomTrial and #g.run.pending == 0
    for _, enemy in ipairs(g.enemies) do
      clear = clear
        and not W.solid(
          g.world,
          enemy.x,
          enemy.z,
          require('src.content.enemies').of(enemy).body.radius
        )
    end
    check(station .. ' fits the real public geometry and replaces the trial', clear)
  end
  -- The pad uses ordinary E interaction and cannot be activated through stone.
  g = fresh()
  g.state = 'playing'
  g.player.x, g.player.z = 10, 8.5
  check('walk-up E starts the named room', g:interact() and g.testField.roomTrial.id == 'ash')
  -- This unsaved mode uses snapshots and journals, including real portals.
  -- SIGIL09's existing map/pools export is not a full session checkpoint.
  local snap = Snapshot.capture(g)
  before = Integrity.capture(g)
  arrive(g)
  Snapshot.restore(g, snap)
  check(
    'snapshot restores a pending room exactly',
    not Integrity.difference(before, Integrity.capture(g))
  )
  g = fresh()
  local journal = Journal.record(g)
  g:act('catalog', 'field_chamber_stars')
  arrive(g)
  g:shoot()
  g:act('catalog', 'field_chamber_storm')
  arrive(g)
  Journal.stop(g)
  local decoded = Journal.decode(Journal.encode(journal))
  local replay = Journal.session(Game, decoded)
  replay.testing = true
  Journal.replay(replay, decoded)
  check(
    'journal replays entry, portal arrival, shot and replacement exactly',
    not Integrity.difference(Integrity.capture(g), Integrity.capture(replay))
  )
  -- Death/retry owns one encounter, not a different mode or a campaign save.
  g = fresh()
  g:act('catalog', 'field_chamber_ash')
  arrive(g)
  g.testField.invincible = false
  g:damagePlayer(10000)
  check(
    'death marks the active trial failed',
    g.state == 'dead'
      and g.testField.roomTrial.status == 'failed'
      and not Queries.world(g).arenaFire
  )
  g:act('retry')
  check(
    'retry returns to the same encounter with fresh actors',
    g.state == 'playing'
      and g.testField.roomTrial.id == 'ash'
      and #g.run.pending == 1
      and #g.enemies == 0
      and Queries.world(g).arenaFire ~= nil
  )
  Field.reset(g)
  check(
    'full reset returns to nave and drops trial ownership',
    not g.testField.roomTrial
      and #g.run.pending == 0
      and g.player.x == start.x
      and g.player.z == start.z
      and not Queries.world(g).arenaFire
  )
  -- Invalid authoring fails before a playable session; registry remains intact.
  local function reject(edit)
    local data = Schema.copy(Maps:get('proving'))
    data.id = 'qa_chamber_bad'
    edit(data)
    local ok = pcall(function()
      Maps:register(data.id, data)
      Game.new('field', data.id)
    end)
    Maps:unregister(data.id)
    return not ok
  end
  check(
    'blocked authored station rejected',
    reject(function(d)
      d.proving.stations.start = { x = 1, z = 1 }
    end)
  )
  check(
    'fractional domino count rejected',
    reject(function(d)
      d.proving.stations.physics.domino.count = 1.5
    end)
  )
  check(
    'negative domino spacing rejected',
    reject(function(d)
      d.proving.stations.physics.domino.step = -1
    end)
  )
  check(
    'unknown chamber rejected',
    reject(function(d)
      d.proving.trials[1].chamber = 'absent'
    end)
  )
  check(
    'missing altar rejected',
    reject(function(d)
      d.proving.pads[1].altar = 'absent'
    end)
  )
  check(
    'two owners of altar position rejected',
    reject(function(d)
      d.proving.pads[1].x = 3
    end)
  )
  check(
    'invalid darkness rejected',
    reject(function(d)
      d.decor.atmosphere.ambient[1] = -1
    end)
  )
  check(
    'unbounded boundary rejected',
    reject(function(d)
      for i = 1, 97 do
        d.proving.chambers[1].fire[i] = { x = 3, z = 11 }
      end
    end)
  )
  check(
    'duplicate trial rejected',
    reject(function(d)
      d.proving.trials[2].id = 'ash'
    end)
  )
  check(
    'unknown creature rejected',
    reject(function(d)
      d.proving.trials[1].creature = 'absent'
      d.proving.pads[1].spawn = 'absent'
    end)
  )
  check(
    'spawn in stone rejected',
    reject(function(d)
      d.proving.chambers[1].slots[1].x = 1
    end)
  )
  check(
    'nonfinite coordinates rejected',
    reject(function(d)
      d.proving.chambers[1].entry.x = 0 / 0
    end)
  )
  check(
    'nonfinite arcade orientation rejected',
    reject(function(d)
      d.decor.arches[1].yaw = math.huge
    end)
  )
  check(
    'sparse trials rejected',
    reject(function(d)
      d.proving.trials[9] = d.proving.trials[1]
    end)
  )
  check(
    'pad action mismatch rejected',
    reject(function(d)
      d.proving.pads[1].weapon = 'judge'
    end)
  )
  check(
    'unaddressable trial id rejected',
    reject(function(d)
      d.proving.trials[1].id = 'trial-with-hyphen'
    end)
  )
  -- An additional use of a creature is authored without another dispatch branch.
  local extension = Schema.copy(Maps:get('proving'))
  extension.id = 'qa_chamber_extension'
  extension.proving.trials[#extension.proving.trials + 1] =
    { id = 'ash_alternate', chamber = 'storm', creature = 'boss' }
  Maps:register(extension.id, extension)
  local ok, err = pcall(function()
    local extra = Game.new('field', extension.id, Release.sessionOptions.field)
    check(
      'first authored trial stays the creature default',
      Chambers.forCreature(extra, 'boss') == 'ash'
    )
    check(
      'data-only extra trial uses another chamber',
      extra:act('catalog', 'field_chamber_ash_alternate')
        and extra.testField.roomTrial.id == 'ash_alternate'
        and extra.player.x == extension.proving.chambers[2].entry.x
    )
  end)
  Maps:unregister(extension.id)
  assert(ok, err)
  return lines
end
return Tests
