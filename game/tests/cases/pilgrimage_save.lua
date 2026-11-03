-- The save of the way: a bad file never stops the game, an old one migrates, content that
-- left is dropped, no kill waits for the disk, what matters is on it at once, and a session
-- replays from what it began with, not from what is on the disk now.
local Destruction = require('src.combat.destruction')
local Encounter = require('src.session.encounter')
local F = require('tests.support.fixtures')
local Journal = require('src.session.journal')
local K = require('src.content.pilgrimage')
local P = require('src.run.pilgrimage')
local Pools = require('src.session.world')
local Save = require('src.storage.save')
local World = require('src.world.arena')
local T = {}
local FILE = P.file()
local PREVIOUS = FILE .. '.previous'
local function clean()
  P.forget()
  for _, name in ipairs({ FILE, FILE .. '.tmp', PREVIOUS }) do
    love.filesystem.remove(name .. '.damaged')
  end
end
-- A way as 0.38 wrote it (section version 1); shape changes it.
local function old(shape)
  local data = {
    wallet = 120,
    deaths = 2,
    fire = 'west',
    lit = { narthex = true, west = true },
    owned = {},
    glyph = 'none',
    opened = {},
    ruin = {},
  }
  if shape then
    shape(data)
  end
  return data
end
local function put(path, data, sequence, version)
  local packed = { pilgrimage = { version = version or 1, data = data } }
  love.filesystem.write(path, Save.encode('pilgrimage', packed, sequence or 1))
end
local function begin(Game)
  local g = Game.new('pilgrimage')
  g:act('start')
  return g
end
local function byPost(g, post)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.post == post then
      return e
    end
  end
end
local function kill(g, post)
  local e = byPost(g, post)
  g:damageEnemy(e, e.hp + 1, 'weapon', nil, g.player.id)
end
local function run(g, seconds)
  for _ = 1, math.floor(seconds * 120) do
    g:update(1 / 120, {})
  end
end
local function ruinIds(g)
  local big
  for _, def in ipairs(Destruction.list(g.world)) do
    if require('src.content.breakables')[def.kind].collapses then
      big = big or def
    end
  end
  return big
end
local function goodFiles(check, Game)
  clean()
  local big = ruinIds(Game.new('pilgrimage'))
  clean()
  put(
    FILE,
    old(function(d)
      d.echo = { amount = 50, x = 12, z = 21 }
      d.ruin = {
        [big.id] = { damage = 1, at = 1 },
        gone_long_ago = { damage = 1, at = 1 },
      }
    end)
  )
  local g = begin(Game)
  check('an old way migrates', g.run.wallet == 120 and g.run.deaths == 2)
  check('its fire and area are known', g.run.fire == 'west' and g.run.area == 'chapel')
  check('its echo lies in its area', g.run.echo.area == 'chapel')
  check('its ruin belongs to its map', Destruction.broken(g.world, big.id))
  check('a breakable the map lost is dropped', g.world.destruction.gone_long_ago == nil)
  check('nothing reports a problem', not g.saveRecovered)
  -- Content left since the file was written.
  put(
    FILE,
    old(function(d)
      d.fire = 'a_fire_that_left'
      d.lit.a_fire_that_left = true
      d.owned = { an_engraving_that_left = true }
      d.glyph = 'an_engraving_that_left'
      d.opened = { a_door_that_left = true, west_gallery = true }
      d.vows = { a_vow_that_left = 2, vow_flask = 9 }
      d.loadout = { 'a_gun_that_left', 'exorcist' }
      d.abilities = { 'a_spell_that_left', 'powder' }
    end)
  )
  g = begin(Game)
  check('an unknown fire wakes him at the first', g.run.fire == K.start().first)
  check('and the first is lit', g.run.lit[K.start().first])
  check('an unknown lit fire is dropped', g.run.lit.a_fire_that_left == nil)
  check('an unknown door is dropped, a known kept', next(g.run.opened) == 'west_gallery')
  check('an unknown engraving is dropped', next(g.run.owned) == nil and g.run.glyph == 'none')
  check(
    'an unknown vow is dropped, a known kept to its limit',
    next(g.run.vows) == 'vow_flask' and g.run.vows.vow_flask == 2
  )
  check(
    'an unknown weapon is dropped',
    #g.player.loadout == 1 and g.player.loadout[1] == 'exorcist'
  )
  check(
    'an unknown ability is dropped, the flask stays',
    g.player.abilities[1] == 'powder' and g.player.abilities[2] == 'flask'
  )
  -- Souls where the map has no floor any more wait at the fire.
  put(
    FILE,
    old(function(d)
      d.echo = { amount = 5, x = 0.5, z = 0.5 }
    end)
  )
  g = begin(Game)
  check(
    'an echo in a wall comes to the fire',
    not World.solid(g.world, g.run.echo.x, g.run.echo.z, 0)
  )
  check('with its souls', g.run.echo.amount == 5)
end
local function badFiles(check, Game)
  -- Each of these stopped the game in 0.38, or would have.
  local broken = {
    function(d)
      d.opened = nil
    end,
    function(d)
      d.lit = nil
    end,
    function(d)
      d.ruin = 'stone'
    end,
    function(d)
      d.wallet = 'many'
    end,
    function(d)
      d.wallet = -1
    end,
    function(d)
      d.wallet = 1.5
    end,
    function(d)
      d.fire = 7
    end,
    function(d)
      d.glyph = 3
    end,
    function(d)
      d.echo = { amount = 'all' }
    end,
    function(d)
      d.echo = { amount = 1, x = 'west', z = 0 }
    end,
    function(d)
      d.lit = { 'narthex' }
    end,
    function(d)
      d.vows = { vow_flask = 'many' }
    end,
    function(d)
      d.loadout = { 7 }
    end,
  }
  for index, shape in ipairs(broken) do
    clean()
    put(FILE, old(shape), 3)
    local g = begin(Game)
    check(
      'a bad file #' .. index .. ' starts a new way',
      g.state == 'playing' and g.run.wallet == 0
    )
    check('and it is said', g.saveRecovered and not g.availableSave)
    check('and it is set aside, not deleted', love.filesystem.getInfo(FILE .. '.damaged') ~= nil)
    check('and the slot is free', love.filesystem.getInfo(FILE) == nil)
    check('and a save works', P.save(g) and Save.read('pilgrimage', FILE) ~= nil)
  end
  -- A bad file with a good one kept behind it.
  clean()
  put(FILE, old(broken[1]), 3)
  put(
    PREVIOUS,
    old(function(d)
      d.wallet = 70
    end),
    2
  )
  local g = begin(Game)
  check('the previous copy takes over', g.run.wallet == 70)
  check('and it is said', g.saveRecovered and g.availableSave ~= nil)
  -- A file that reads but cannot be restored leaves nothing behind it.
  clean()
  put(
    FILE,
    old(function(d)
      d.wallet, d.lit.east = 300, true
    end),
    3
  )
  put(
    PREVIOUS,
    old(function(d)
      d.wallet = 70
    end),
    2
  )
  local section, real, calls = Save.section('pilgrimage'), nil, 0
  real = section.restore
  section.restore = function(game, data)
    calls = calls + 1
    real(game, data)
    if calls == 1 then
      error('a restore that fails half way')
    end
  end
  g = begin(Game)
  section.restore = real
  check('a failed restore falls to the older copy', g.run.wallet == 70 and calls == 2)
  check('and leaves nothing of itself', not g.run.lit.east)
  check('and it is said', g.saveRecovered)
end
local function writes(check, Game)
  clean()
  local g = begin(Game)
  P.save(g)
  local text = love.filesystem.read(FILE)
  check(
    'a save over the size limit is refused',
    not Save.write(FILE, string.rep('x', Save.limits.maxBytes + 1))
  )
  check(
    'a text the reader refuses is refused',
    not Save.write(FILE, 'SIGIL09\npilgrimage\n1\n1\nx')
  )
  check(
    'a section it cannot use is refused',
    not Save.write(
      FILE,
      Save.encode('pilgrimage', { pilgrimage = { version = 2, data = { wallet = 'x' } } }, 9)
    )
  )
  check('the good save was never touched', love.filesystem.read(FILE) == text)
  -- What was read stays as it was read: a journal starts from it.
  P.save(g)
  g = begin(Game)
  g.run.lit.sanctuary, g.run.wallet = true, 1
  check('the origin shares nothing with the run', not g.run.origin.pilgrimage.lit.sanctuary)
end
local function timing(check, Game)
  clean()
  local g = begin(Game)
  kill(g, 'nave_1')
  check('a kill pays at once', g.run.wallet > 0 and g.run.dirty)
  check('and writes nothing', love.filesystem.getInfo(FILE) == nil)
  local e = byPost(g, 'crypt_1')
  e.leash = math.huge
  for _ = 1, (K.saveEvery + 1) * 120 do
    e.awake, e.memory, g.player.hp = true, 1, g.player.maxHp
    g:update(1 / 120, {})
  end
  check('no fight stops for the disk', love.filesystem.getInfo(FILE) == nil and g.run.dirty)
  -- The fight is over: everyone back at its post, asleep; the alarm (owner, D4) had brought
  -- some of them round him, and a patrol may walk into his sight.
  for _, body in ipairs(Pools.of(g, 'enemies')) do
    body.awake, body.alertRange, body.patrol = false, 0, nil
    body.x, body.z = body.home.x, body.home.z
  end
  -- What he looks at wakes: quiet means nothing in front of him.
  g.player.yaw = 0
  run(g, 0.1)
  check('the first quiet moment saves', love.filesystem.getInfo(FILE) ~= nil and not g.run.dirty)
  local wallet = g.run.wallet
  check('with the souls', Game.new('pilgrimage').run.wallet == wallet)
  kill(g, 'nave_2')
  g:act('flush')
  check('a stopped game saves at once', Game.new('pilgrimage').run.wallet == g.run.wallet)
  check('and flushing twice writes once', not g:act('flush'))
  -- Each durable event is on the disk the moment it happens.
  local function stored()
    return Game.new('pilgrimage').run
  end
  kill(g, 'nave_3')
  g.player.x, g.player.z = 10, 21
  -- A fire takes in only a knight nobody hunts (owner, D1).
  for _, body in ipairs(Pools.of(g, 'enemies')) do
    body.awake = false
  end
  g:interact()
  check('a rest is stored', stored().fire == 'west' and stored().wallet == g.run.wallet)
  g.run.wallet = 500
  check('a purchase is stored', g:act('buy', 'vow_vigor') and stored().wallet == 340)
  check('with its vow', stored().vows.vow_vigor == 1)
  g:act('closeShop')
  g.player.x, g.player.z = 12, 21
  g.run.wallet = 40
  g:damagePlayer(500)
  check('a death is stored', stored().echo ~= nil and stored().wallet == 0)
  g:act('retry')
  g.player.x, g.player.z = 12, 21
  run(g, 0.1)
  check('souls taken back are stored', stored().echo == nil and stored().wallet > 0)
  local door = K.start().doors[1]
  g.player.x, g.player.z = door.side.x, door.side.z
  g:interact()
  check('a door opened is stored', stored().opened[door.id])
  g.player.x, g.player.z = 24, 10
  g:interact()
  g:act('closeShop')
  g:act('ready')
  check('a journey is stored', stored().fire == g.run.fire and g.run.fire ~= 'sanctuary')
end
-- A disk that refuses keeps the duty to save: the next quiet moment tries again, and no
-- sooner, so a refusal never becomes a write every frame.
local function refusals(check, Game)
  clean()
  local g = begin(Game)
  local real, calls, refuse = Save.write, 0, true
  Save.write = function(...)
    calls = calls + 1
    if refuse then
      return false, 'a disk that refuses'
    end
    return real(...)
  end
  local ok, problem = pcall(function()
    kill(g, 'nave_1')
    Encounter.clearStage(g)
    run(g, K.saveEvery + 0.1)
    check('a refused save is said', calls == 1 and g.saveWarning ~= nil)
    check('and its souls still wait for the disk', g.run.dirty)
    check('a stopped game that cannot write says so', not g:act('flush') and calls == 2)
    run(g, K.saveEvery - 0.5)
    check('a refusal is not tried every frame', calls == 2)
    refuse = false
    run(g, 1)
    check('the next quiet moment tries again', calls == 3 and not g.run.dirty)
    check('and the warning goes', g.saveWarning == nil)
    check('with the souls', Game.new('pilgrimage').run.wallet == g.run.wallet)
    -- A durable event refused is owed as well.
    refuse = true
    g.player.x, g.player.z = 10, 21
    g:interact()
    g:act('closeShop')
    Encounter.clearStage(g)
    check('a refused rest is owed', g.run.dirty and Game.new('pilgrimage').run.fire ~= 'west')
    refuse = false
    run(g, K.saveEvery + 0.1)
    check('and stored at the next quiet moment', Game.new('pilgrimage').run.fire == 'west')
  end)
  Save.write = real
  check('a refusing disk holds' .. (ok and '' or ': ' .. tostring(problem)), ok)
end
local function play(g)
  g:act('start')
  run(g, 0.5)
  g:interact()
  g:act('closeShop')
  run(g, 0.5)
end
local function replays(check, Game)
  local function replay(title, g, journal)
    Journal.stop(g)
    local read = Journal.decode(Journal.encode(journal))
    -- The disk has moved on; a replay must not notice.
    local wrong = old(function(d)
      d.wallet = 999
    end)
    put(FILE, wrong, 50)
    local fresh = Journal.session(Game, read)
    local ok, problem = pcall(Journal.replay, fresh, read)
    check(title .. (ok and '' or ': ' .. tostring(problem)), ok)
  end
  clean()
  local g = Game.new('pilgrimage')
  local journal = Journal.record(g)
  play(g)
  replay('a session begun from nothing replays', g, journal)
  clean()
  P.save(Game.new('pilgrimage'))
  g = Game.new('pilgrimage')
  check('a session can begin from a save', g.run.saved and g.run.saves == 1)
  journal = Journal.record(g)
  play(g)
  replay('a session begun from a save replays', g, journal)
end
-- A second area on another map: a fire, a post and a door between the two.
local function areas(check, Game)
  clean()
  K.areas:register('annex', {
    id = 'annex',
    map = 'floor',
    first = 'annex_fire',
    fires = { { id = 'annex_fire', name = 'fire_west', x = 16, z = 14 } },
    doors = {},
    garrison = { { id = 'annex_1', creature = 'imp', x = 16, z = 20, yaw = 0 } },
  })
  local link = {
    id = 'annex_door',
    leads = 'annex',
    side = { x = 27, z = 31, yaw = 0, art = { x = 27, z = 30, yaw = 0 } },
    back = { x = 16, z = 17.5, yaw = 0, art = { x = 16, z = 18, yaw = 0 } },
  }
  local chapel = K.start()
  chapel.doors[#chapel.doors + 1] = link
  local ok, problem = pcall(function()
    check('a second area fits its map', #P.problems(K.areas:get('annex')) == 0)
    local g = begin(Game)
    local world = g.world
    local big = ruinIds(g)
    g.world.destruction = { [big.id] = { damage = 1, at = 1 } }
    g.player.x, g.player.z = link.side.x, link.side.z
    g:interact()
    check('its door opens', g.run.opened.annex_door)
    g:interact()
    check('and leads onto its map', g.world.mapId == 'floor' and g.run.area == 'annex')
    check('at the far side', g.player.x == link.back.x and g.player.z == link.back.z)
    check(
      'where its own garrison stands',
      byPost(g, 'annex_1') ~= nil and #Pools.of(g, 'enemies') == 1
    )
    check(
      'its door is painted on the far side',
      #require('src.session.queries').world(g).doors == 1
    )
    check('and what fell behind is remembered', g.run.ruins.proving[big.id] ~= nil)
    -- A death beyond the door before any rest there: he wakes at his own fire, on its map, and
    -- the souls wait where he fell.
    g.run.wallet, g.player.armor, g.player.invuln = 30, 0, 0
    g:damagePlayer(500)
    check('he can die beyond the door', g.state == 'dead' and g.run.echo.area == 'annex')
    g:act('retry')
    check(
      'and wakes at his own fire, on its map',
      g.run.area == 'chapel' and g.world.mapId == 'proving' and P.fireHere(g) ~= nil
    )
    check('with what fell there still fallen', Destruction.broken(g.world, big.id))
    g.player.x, g.player.z = link.side.x, link.side.z
    g:interact()
    check('the door leads back', g.run.area == 'annex' and g.world.mapId == 'floor')
    g.player.x, g.player.z = g.run.echo.x, g.run.echo.z
    run(g, 0.05)
    check('to the souls he left there', g.run.echo == nil and g.run.wallet == 30)
    for _, body in ipairs(Pools.of(g, 'enemies')) do
      body.awake = false
    end
    g.player.x, g.player.z = 16, 15
    g:interact()
    check('a fire of the far area lights', g.run.lit.annex_fire and g.state == 'shop')
    g:act('closeShop')
    local saved = Game.new('pilgrimage')
    check(
      'a save stands on the far map',
      saved.world.mapId == 'floor' and saved.run.area == 'annex'
    )
    check('and wakes at its fire', P.fireHere(saved).id == 'annex_fire')
    g:act('ready')
    check('travel crosses areas', g.world.mapId == 'proving' and g.run.area == 'chapel')
    check('onto a new world, not the old one', g.world ~= world)
    check('the ruin is back', Destruction.broken(g.world, big.id))
    g:act('ready')
    check('and back', g.world.mapId == 'floor')
    g.player.x, g.player.z = link.back.x, link.back.z
    g:interact()
    check('the door leads home', g.world.mapId == 'proving' and g.player.x == link.side.x)
    local read = Save.read('pilgrimage', FILE)
    check('the file keeps both ruins', read.pilgrimage.ruins.proving ~= nil)
  end)
  chapel.doors[#chapel.doors] = nil
  K.areas:unregister('annex')
  check('the second area holds' .. (ok and '' or ': ' .. tostring(problem)), ok)
end
-- Slots are separate ways.
local function slots(check, Game)
  clean()
  P.forget(nil, 2)
  local one = Game.new('pilgrimage', nil, { slot = 1 })
  one.run.wallet = 11
  P.save(one)
  local two = Game.new('pilgrimage', nil, { slot = 2 })
  check('a slot starts empty', two.run.wallet == 0 and not two.run.saved)
  two.run.wallet = 22
  P.save(two)
  check('each keeps its own', Game.new('pilgrimage', nil, { slot = 1 }).run.wallet == 11)
  check('and the other', Game.new('pilgrimage', nil, { slot = 2 }).run.wallet == 22)
  check('a slot has its own file', love.filesystem.getInfo(P.file(2)) ~= nil)
  check('the first keeps the old name', P.file(1) == 'pilgrimage.save')
  P.forget(nil, 2)
  check(
    'forgetting one leaves the other',
    Game.new('pilgrimage', nil, { slot = 1 }).run.wallet == 11
  )
end
-- 0.43 (owner, D9; audit F01): a way is taken up where it was left. Health, rounds and
-- draughts as they were, what fell since the fire stays fallen, what hunted him hunts him
-- still; a quit is no rest and no second payment for the same kills.
local function resumes(check, Game)
  clean()
  local g = begin(Game)
  local p = g.player
  for _, post in ipairs({ 'nave_1', 'nave_2', 'nave_3' }) do
    kill(g, post)
  end
  local hunter = byPost(g, 'nave_5')
  hunter.awake, hunter.memory, hunter.x, hunter.z, hunter.hp = true, 5, p.x + 3, p.z, 200
  p.hp, p.x = 20, p.x + 0.5
  local judge = p.arsenal.judge
  judge.mag, judge.reserve = 2, 5
  local uses = p.abilityState.flask.uses - 1
  p.abilityState.flask.uses = uses
  local wallet, x, z = g.run.wallet, p.x, p.z
  g:act('flush')
  local again = begin(Game)
  local q = again.player
  local standing = 0
  for _, post in ipairs({ 'nave_1', 'nave_2', 'nave_3' }) do
    local body = byPost(again, post)
    standing = standing + ((body and body.hp > 0) and 1 or 0)
  end
  local hunted = byPost(again, 'nave_5')
  check('the souls are kept', again.run.wallet == wallet and wallet > 0)
  check('he stands where he left', math.abs(q.x - x) < 1e-6 and math.abs(q.z - z) < 1e-6)
  check('with the health he had', q.hp == 20)
  check(
    'and the rounds and draughts he had',
    q.arsenal.judge.mag == 2 and q.arsenal.judge.reserve == 5 and q.abilityState.flask.uses == uses
  )
  check('what he cut down since the fire stays down', standing == 0)
  check(
    'what hunted him hunts him still, from where it was',
    hunted and hunted.awake and math.abs(hunted.x - (x + 2.5)) < 1 and hunted.hp == 200
  )
  check('no fire takes him in now', P.fighting(again))
  -- A death is still a death: the fire, what it secured, and the rest standing again.
  q.hp, q.armor = 1, 0
  again:damagePlayer({ base = 100, impact = 10 }, q.x, q.z + 1)
  again:act('flush')
  local after = begin(Game)
  check(
    'a way left dead wakes at the fire',
    P.fireHere(after) ~= nil and after.player.hp == after.player.maxHp
  )
  check('and what fell since the fire stands again', byPost(after, 'nave_1') ~= nil)
  -- The audit review (2026-11-03): a quit with no kill since the last write, and the fight
  -- in the middle of itself. A missile in the air, a blow begun, the rest of a cache, a
  -- creature's drop and a wounded body asleep all come back as they were.
  clean()
  g = begin(Game)
  p = g.player
  local Spawn = require('src.session.spawn')
  local Interactions = require('src.session.interactions')
  for _, body in ipairs(Pools.of(g, 'enemies')) do
    body.awake = false
  end
  p.x, p.z = 19.5, 35
  p.arsenal.judge.reserve = p.arsenal.judge.reserve - 5
  Interactions.collectSupplies(g)
  local rest
  for _, pickup in ipairs(Pools.of(g, 'pickups')) do
    rest = pickup.rewardId == 'narthex_left' and pickup.amount or rest
  end
  Spawn.make(g, 'pickup', { x = 24, z = 31, kind = 'ammo', weapon = 'judge', amount = 3 })
  local wounded = byPost(g, 'nave_5')
  wounded.hp = 123
  run(g, 0.2)
  p.x, p.z = 24, 32
  Spawn.make(g, 'projectile', {
    x = p.x + 4,
    y = 1.2,
    z = p.z,
    vx = -9,
    vy = 0,
    vz = 0,
    life = 2,
    side = 'demons',
    packet = { base = 20, impact = 20 },
    radius = 0.12,
  })
  local striker = byPost(g, 'nave_2')
  striker.awake, striker.memory, striker.ai, striker.windup = true, 5, 'windup', 0.4
  g:act('flush')
  local back = begin(Game)
  local missiles, drop, cache = #Pools.of(back, 'projectiles'), false, nil
  for _, pickup in ipairs(Pools.of(back, 'pickups')) do
    drop = drop or (not pickup.rewardId and pickup.amount == 3)
    cache = pickup.rewardId == 'narthex_left' and pickup.amount or cache
  end
  check('a quit with no kill since the last write is written', back.player.x == 24)
  check('the missile in the air flies on', missiles == 1)
  check(
    'the blow begun goes on',
    byPost(back, 'nave_2').ai == 'windup' and byPost(back, 'nave_2').windup == striker.windup
  )
  check('what was left of a cache is left', rest ~= nil and cache == rest)
  check('a creature drop still lies there', drop)
  check('a wounded body asleep keeps its wound', byPost(back, 'nave_5').hp == 123)
  check('the clock goes on from where it stood', back.elapsed == g.elapsed)
  clean()
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'pilgrimage save: ', 'pilgrimage save: ')
  areas(check, Game)
  resumes(check, Game)
  slots(check, Game)
  goodFiles(check, Game)
  badFiles(check, Game)
  writes(check, Game)
  timing(check, Game)
  refusals(check, Game)
  replays(check, Game)
  clean()
  return lines
end
return T
