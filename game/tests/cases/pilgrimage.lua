-- Plan v13 O1-O3: the world stands at its posts, a rest raises it, a death leaves the
-- souls behind, a second death loses them, guardians stay down and the save holds it.
local Cast = require('src.combat.abilities')
local Effects = require('src.combat.effects')
local Encounter = require('src.session.encounter')
local F = require('tests.support.fixtures')
local K = require('src.content.pilgrimage')
local P = require('src.run.pilgrimage')
local Pools = require('src.session.world')
local Weapons = require('src.content.weapons')
local T = {}
local function session(Game)
  local g = Game.new('pilgrimage')
  g:act('start')
  g.state = 'playing'
  return g
end
local function byPost(g, post)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.post == post then
      return e
    end
  end
end
local function run(g, seconds)
  for _ = 1, math.floor(seconds * 120) do
    g:update(1 / 120, {})
  end
end
-- A rest, a retry and a journey each start him afresh: nothing of the last fight burns,
-- shoves or finishes on him after it.
local function freshStarts(check, Game)
  P.forget()
  local g = session(Game)
  local p = g.player
  Encounter.clearStage(g)
  local burn = require('src.content.enemies').get('buer').attacks[1].pool.packet.effects
  local function still(title)
    Encounter.clearStage(g)
    local hp, armor, x, z = p.hp, p.armor, p.x, p.z
    run(g, 0.6)
    check(title .. ': nothing burns', p.hp == hp and p.armor == armor)
    check(title .. ': nothing moves him', math.abs(p.x - x) + math.abs(p.z - z) < 1e-6)
  end
  -- A rest after Buer's fire, mid-shove, mid-dodge, with a drink under way.
  for _ = 1, 3 do
    Effects.apply(g, p, burn, { side = 'demons', id = 999 })
  end
  p.x, p.z = 10, 21
  p.pushX, p.pushZ = 4, 0
  p.dashTimer, p.dashX, p.dashZ = 0.2, 1, 0
  local flask
  for slot, id in ipairs(p.abilities) do
    flask = id == 'flask' and slot or flask
  end
  p.hp = 50
  check('a drink begins', Cast.cast(g, flask, p.id) and p.casting ~= nil)
  check('a fire rests him', g:interact() and g.state == 'shop')
  check('the rest ends the drink unpaid', p.casting == nil)
  local uses = p.abilityState.flask.uses
  g:act('closeShop')
  still('after a rest')
  check('the full flask stays full', p.abilityState.flask.uses == uses)
  -- A blow that kills and shoves him.
  p.armor, p.hp = 0, 1
  g:damagePlayer({ base = 100, impact = 140 }, p.x, p.z + 1)
  check('the fatal blow shoves', g.state == 'dead' and (p.pushZ or 0) ~= 0)
  check('he wakes', g:act('retry'))
  still('after a retry')
  -- A journey from a fire with the fire still on him.
  Effects.apply(g, p, burn, { side = 'demons', id = 999 })
  p.pushX = 4
  g:interact()
  check('a journey leaves', g:act('ready') and g.state == 'playing')
  still('after a journey')
  P.forget()
end
-- What struck the last wounding blow is kept for the death screen: a creature by its name, or
-- his own charge.
local function causes(check, Game)
  P.forget()
  local Queries = require('src.session.queries')
  local g = session(Game)
  local p = g.player
  local stolas = byPost(g, 'nave_4')
  p.armor, p.invuln = 0, 0
  g:damagePlayer({ base = 10, impact = 0 }, stolas.x, stolas.z, nil, stolas)
  check('a blow names the creature that struck it', Queries.lastHarm(g) == 'creature_stolas')
  p.invuln = 0
  g:damagePlayer({ base = 500, impact = 0 }, p.x, p.z, nil, 'self')
  check(
    'and a death by his own charge says so',
    g.state == 'dead' and Queries.lastHarm(g) == 'death_by_self'
  )
  P.forget()
end
-- A fire fills each reserve up to what it gives and never takes away what was gathered beyond
-- it; a new way starts with exactly what a fire gives.
local function reserves(check, Game)
  P.forget()
  local g = session(Game)
  local p = g.player
  local shells, rounds = p.arsenal.exorcist, p.arsenal.judge
  check(
    'a new way carries what a fire gives',
    shells.reserve == K.carried.exorcist and rounds.reserve == K.carried.judge
  )
  Encounter.clearStage(g)
  shells.reserve, rounds.reserve = K.carried.exorcist + 15, 3
  p.x, p.z = 10, 21
  g:interact()
  check('a rest keeps the shells gathered beyond it', shells.reserve == K.carried.exorcist + 15)
  check('and fills what is short', rounds.reserve == K.carried.judge)
  P.forget()
end
-- What lies about: a knight takes only what he has room for and the rest stays on the floor;
-- a rest secures what was taken, a death brings back only what was taken since (0.42).
local function caches(check, Game)
  P.forget()
  local g = session(Game)
  local p = g.player
  local function lying(id)
    for _, pickup in ipairs(Pools.of(g, 'pickups')) do
      if pickup.rewardId == id then
        return pickup
      end
    end
  end
  local cache = lying('nave_left')
  local rounds = p.arsenal.judge
  rounds.reserve = Weapons.get('judge').ammo.maxReserve - 4
  p.x, p.z = cache.x, cache.z
  require('src.session.interactions').collectSupplies(g)
  check('he takes what he has room for', rounds.reserve == Weapons.get('judge').ammo.maxReserve)
  check('and the rest stays on the floor', lying('nave_left') and lying('nave_left').amount == 10)
  require('src.session.interactions').collectSupplies(g)
  check('a full gun takes nothing', lying('nave_left').amount == 10)
  Pools.remove(g, 'pickups', lying('nave_left'))
  P.update(g, 120)
  check('a cache taken stays taken', lying('nave_left') == nil)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    e.awake = false
  end
  p.x, p.z = 10, 21
  g:interact()
  check('a rest secures it', lying('nave_left') == nil and g.run.taken.nave_left)
  g:act('closeShop')
  Pools.remove(g, 'pickups', lying('nave_right'))
  P.lose(g)
  P.retry(g)
  check('a death brings back what was taken since', lying('nave_right') ~= nil)
  check('but not what a rest secured', lying('nave_left') == nil)
  check('every other one, once', #Pools.of(g, 'pickups') == #K.start().supplies - 1)
  local draught = lying('nave_draught')
  p.abilityState.flask.uses = 1
  p.x, p.z = draught.x, draught.z
  require('src.session.interactions').collectSupplies(g)
  check('a draught fills the flask by one', p.abilityState.flask.uses == 2)
  P.forget()
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'pilgrimage: ', 'pilgrimage: ')
  freshStarts(check, Game)
  reserves(check, Game)
  caches(check, Game)
  causes(check, Game)
  P.forget()
  local g = session(Game)
  local p = g.player
  check(
    'the knight wakes at the first fire',
    P.fireHere(g) ~= nil and P.fireHere(g).id == K.start().first
  )
  check('every post stands', #Pools.of(g, 'enemies') == #K.start().garrison)
  check('rounds lie about where the way says', #Pools.of(g, 'pickups') == #K.start().supplies)
  check('every one of them can be reached', #P.problems(K.start()) == 0)
  check('nobody knows he is here', byPost(g, 'nave_1').awake == false)
  check('no waves, effort is paid', require('src.session.capabilities').attrition(g))
  check('the flask is carried', p.abilityState.flask.uses == 3)
  -- A rest raises the creatures, heals, refills.
  local victim = byPost(g, 'nave_1')
  g:damageEnemy(victim, victim.hp + 1, 'weapon', nil, p.id)
  check('a kill pays souls', g.run.wallet > 0)
  check('the post is empty', victim.hp <= 0)
  local second = byPost(g, 'nave_2')
  g:damageEnemy(second, second.hp + 1, 'weapon', nil, p.id)
  p.hp, p.abilityState.flask.uses = 20, 0
  local wallet = g.run.wallet
  -- No fire takes him in while something hunts him (owner, D1), and it says so.
  local hunter = byPost(g, 'nave_3')
  local postX, postZ = hunter.x, hunter.z
  hunter.awake, hunter.x, hunter.z = true, p.x, p.z - 5
  check('no rest while something is awake', g:interact() and g.state == 'playing' and p.hp == 20)
  check('and the fire says why', g:context():find('HUNTED', 1, true) ~= nil)
  check('nor a journey', not P.travel(g))
  -- 0.42: only a fight near him counts; one far off in a crowded map does not.
  hunter.x, hunter.z = p.x, p.z - K.huntReach - 1
  check('one awake far off keeps no fire from him', not P.fighting(g))
  hunter.awake, hunter.x, hunter.z = false, postX, postZ
  check('[E] rests at a fire', g:interact() and g.state == 'shop')
  check('it heals', p.hp == 100)
  check('it fills the flask', p.abilityState.flask.uses == 3)
  -- 0.42: a rest secures what he cleared; nothing stands again at a fire.
  check('the fallen stay fallen', byPost(g, 'nave_1').hp <= 0 and g.run.slain.nave_1)
  check('the living are not slain', not g.run.slain.nave_3 and byPost(g, 'nave_3').hp > 0)
  check('souls stay', g.run.wallet == wallet)
  -- A fire sells what a rest cannot give.
  local Economy = require('src.run.economy')
  local Shop = require('src.content.shop')
  for _, offer in ipairs(Economy.offersFor(g)) do
    check(offer.id .. ' is no field offer', offer.sold ~= 'field')
  end
  check('rounds are not sold at a fire', not g:act('buy', 'ammo'))
  local vow = Shop.get('vow_flask')
  check('a vow costs souls', g.run.wallet < vow.price and not g:act('buy', 'vow_flask'))
  g.run.wallet = vow.price + 1
  check('the fire trades', g:act('buy', 'vow_flask') and g.run.wallet == 1)
  check('the flask holds one more', p.abilityState.flask.uses == 4)
  check('the rank is kept', g.run.vows.vow_flask == 1)
  g.run.wallet = vow.price
  check('the next rank costs more', not g:act('buy', 'vow_flask'))
  g.run.wallet = Shop.maxWallet
  check('a vow of health holds', g:act('buy', 'vow_vigor') and p.maxHp == 115 and p.hp == 115)
  check('the ward is no vow any more', not g:act('buy', 'vow_ward') and p.maxArmor == 40)
  -- The status bar measures against his maxima: full is 100% however many vows he swore.
  local Characters = require('src.content.characters')
  check('full health is 100%', Characters.percent(Characters.share(p)) == 100)
  check('a full ward is a full bar', Characters.wardShare(p) == 1)
  p.hp, p.armor = 100, 20
  check('100 of 115 is 87%', Characters.percent(Characters.share(p)) == 87)
  check('half the ward is half', Characters.percent(Characters.wardShare(p)) == 50)
  p.hp, p.armor = 0.2, 0
  check('alive is at least 1%', Characters.percent(Characters.share(p)) == 1)
  check('no ward is 0, never -0', tostring(Characters.percent(Characters.wardShare(p))) == '0')
  p.hp, p.armor = p.maxHp, p.maxArmor
  g:act('buy', 'vow_flask')
  check('a vow ends', not g:act('buy', 'vow_flask') and g.run.vows.vow_flask == 2)
  -- Each gun wears its own engraving, and tempering is the gun's for good (0.42).
  check('an engraving for the Judge', g:act('buy', 'breaker') and g.run.worn.judge == 'breaker')
  check('and one for the Exorcist', g:act('buy', 'choke') and g.run.worn.exorcist == 'choke')
  check('the first stays on its gun', g.run.worn.judge == 'breaker')
  check('the Judge is tempered', g:act('buy', 'temper_judge'))
  local worn = table.concat(Economy.modifiers(g.run), ' ')
  check('the guns change by what they wear', worn == 'choke breaker temper_judge')
  local Weapons = require('src.content.weapons')
  local judge = Weapons.slotOf(g, 'judge', p)
  local hit = Weapons.attack(g, judge, Economy.modifiers(g.run), p)
  check('a tempered Breaker', hit.base > 70 and hit.impact > 44)
  -- Sigils: a glyph on top of an engraving, or a trait of the knight (0.42).
  check('a sigil of Buer', g:act('buy', 'sigil_buer') and p.rallyRate == 0.08)
  check('a second copy is stronger', g:act('buy', 'sigil_buer') and p.rallyRate == 0.10)
  check('a sigil of Furfur', g:act('buy', 'sigil_furfur') and p.dodgeEdge == 0.35)
  g:act('buy', 'precision')
  check('a sigil of Stolas', g:act('buy', 'sigil_stolas'))
  local head = Weapons.attack(g, judge, Economy.modifiers(g.run), p).headMultiplier
  check('adds to PRECISION, whatever the order', math.abs(head - 1.72) < 1e-9)
  local kept = session(Game)
  check('vows outlive the session', kept.player.maxHp == 115 and kept.player.maxArmor == 40)
  check('and the flask', kept.player.abilityState.flask.uses == 5)
  check(
    'and what each gun wears',
    kept.run.worn.judge == 'precision' and kept.run.worn.exorcist == 'choke'
  )
  check(
    'the kit outlives it',
    kept.player.loadout[1] == p.loadout[1] and kept.player.abilities[1] == p.abilities[1]
  )
  g.run.vows, p.maxHp, p.maxArmor = {}, 100, 40
  g.run.worn, g.run.owned, g.run.glyph = {}, {}, 'none'
  p.abilityState.flask.extra = 0
  P.save(g)
  g.run.wallet = wallet
  g:act('closeShop')
  check('the menu closes', g.state == 'playing')
  -- A body follows, gives up, and goes home.
  local e = byPost(g, 'nave_5')
  e.x, e.z = 24, 39
  e.awake, e.memory, e.visible = true, 1, false
  p.x, p.z = 24, 36
  e.dummy = nil
  run(g, 0.2)
  check('too far from its post it gives up', e.awake == false)
  -- Death: the souls stay.
  p.x, p.z = 24, 30
  p.armor = 0
  g:damagePlayer(500)
  check('he falls', g.state == 'dead')
  check('the souls lie where he fell', g.run.echo and g.run.echo.amount == wallet)
  check('and his purse is empty', g.run.wallet == 0)
  check('he wakes at his fire', g:act('retry') and g.state == 'playing')
  check('at the fire', P.fireHere(g) ~= nil)
  check('what a rest secured stays dead', byPost(g, 'nave_1') == nil or byPost(g, 'nave_1').hp <= 0)
  local post = byPost(g, 'nave_3')
  g:damageEnemy(post, post.hp + 1, 'weapon', nil, p.id)
  p.x, p.z = 24, 31
  p.armor = 0
  g:damagePlayer(500)
  check('a second death loses them', g.run.echo.amount < wallet and g.run.echo.z == 31)
  g:act('retry')
  p.x, p.z = g.run.echo.x, g.run.echo.z
  run(g, 0.02)
  check('what lies there is taken back', g.run.echo == nil and g.run.wallet > 0)
  -- Fires are lit by resting at them, and travel goes between the lit ones.
  p.x, p.z = 10, 21
  check('a far fire waits', P.fireHere(g) ~= nil and P.fireHere(g).id == 'west')
  -- What the deaths above woke has given up by now: a fire only takes in a knight nobody hunts.
  for _, body in ipairs(Pools.of(g, 'enemies')) do
    body.awake = false
  end
  g:interact()
  check('the hardest bodies rise like the rest', byPost(g, 'west_hall').hp > 0)
  check('travel leaves its menu', g:act('ready') and g.state == 'playing')
  check('and leads to a lit fire', P.fireHere(g).id ~= 'west')
  -- A hard body is a body: it stays in its leash and pays like any other.
  local hard = byPost(g, 'west_hall')
  check('it has a leash', hard.leash ~= nil)
  local before = g.run.wallet
  g:damageEnemy(hard, hard.hp + 1, 'weapon', nil, p.id)
  check('it pays and ends nothing', g.run.wallet > before and g.state == 'playing')
  -- Every creature that stands at a post pays; the two hardest pay alike.
  local Archetypes = require('src.content.enemies')
  for _, entry in ipairs(K.start().garrison) do
    check(entry.creature .. ' pays souls', (Archetypes.get(entry.creature).souls or 0) > 0)
  end
  check(
    'Furfur pays as the Margrave',
    Archetypes.get('furfur').souls == Archetypes.get('boss').souls
  )
  -- A door stays barred until it is opened from its side, then it leads through.
  local World = require('src.world.arena')
  local door = K.start().doors[1]
  check('the wall behind a door is stone', World.solid(g.world, 14, 6, 0.3))
  p.x, p.z = door.back.x, door.back.z
  g:interact()
  check('barred from the far side', not g.run.opened[door.id] and p.x == door.back.x)
  p.x, p.z = door.side.x, door.side.z
  g:interact()
  check('it opens from its own', g.run.opened[door.id] and p.x == door.side.x)
  g:interact()
  check('then it leads through', p.x == door.back.x and p.z == door.back.z)
  g:interact()
  check('and back', p.x == door.side.x and p.z == door.side.z)
  -- The save holds the way.
  local saved = session(Game)
  check('a new session knows the lit fires', saved.run.lit.west)
  check('an open door stays open', saved.run.opened[door.id])
  check('the other is still shut', not saved.run.opened[K.start().doors[2].id])
  -- What collapsed stays down through a rest and a save; small things stand again.
  local Destruction = require('src.combat.destruction')
  local Kinds = require('src.content.breakables')
  local big, small
  for _, def in ipairs(Destruction.list(saved.world)) do
    if Kinds[def.kind].collapses then
      big = big or def
    else
      small = small or def
    end
  end
  Destruction.restore(saved.world, {
    [big.id] = { damage = Kinds[big.kind].health, at = 1 },
    [small.id] = { damage = Kinds[small.kind].health, at = 1 },
  })
  saved.player.x, saved.player.z = 24, 10.5
  saved:interact()
  check('a rest keeps what collapsed', Destruction.broken(saved.world, big.id))
  check('and stands the small things again', not Destruction.broken(saved.world, small.id))
  check('the save keeps the ruin', Destruction.broken(session(Game).world, big.id))
  P.forget()
  return lines
end
return T
