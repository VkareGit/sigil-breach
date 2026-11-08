local F = require('tests.support.fixtures')
local P = require('src.run.pilgrimage')
local E = require('src.run.economy')
local Save = require('src.storage.save')
local T = {}
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'sigils: ', 'sigils: ')
  local g = Game.new('pilgrimage', nil, { origin = false })
  g.ephemeral, g.state = true, 'playing'
  local p = g.player
  P.takeRelic(g, { offer = 'sigil_stolas', rewardId = 'relic_stolas' })
  check('a found sigil stays unequipped', not E.wearing(g.run, { id = 'sigil_stolas' }))
  P.takeRelic(g, { offer = 'sigil_stolas', rewardId = 'relic_stolas' })
  check('one reward cannot grant two copies', g.run.vows.sigil_stolas == 1)
  local S = require('src.combat.sigils')
  check('capacity is four', require('src.content.sigils').capacity == 4)
  local Encounter = require('src.session.encounter')
  Encounter.clearStage(g)
  p.x, p.z = 27, 35
  check('equipping outside shop is refused', not E.buy(g, 'sigil_stolas'))
  g:interact()
  g.run.wallet = 777
  for _, id in ipairs(require('src.content.sigils').order) do
    g.run.vows[id] = 3
  end
  check(
    'one Stolas copy equips free',
    g:act('buy', 'sigil_stolas') and p.sigilRanks.sigil_stolas == 1 and g.run.wallet == 777
  )
  check(
    'three copies occupy three points',
    g:act('buy', 'sigil_stolas') and g:act('buy', 'sigil_stolas') and E.sigilsWorn(g.run) == 3
  )
  check('a fourth copy is refused', not g:act('buy', 'sigil_stolas'))
  check('two-point Furfur does not fit beside three Stolas', not g:act('buy', 'sigil_furfur'))
  check('Buer fits the last point', g:act('buy', 'sigil_buer') and E.sigilsWorn(g.run) == 4)
  check('a second Buer exceeds capacity', not g:act('buy', 'sigil_buer'))
  check(
    'remove one copy, not the whole stack',
    g:act('removeSigil', 'sigil_stolas') and p.sigilRanks.sigil_stolas == 2
  )
  g:act('closeShop')
  check('removal outside fire is refused', not g:act('removeSigil', 'sigil_stolas'))
  g.state = 'shop'
  p.x, p.z = 24, 25
  check(
    'forged open shop away from fire cannot equip/remove',
    not E.buy(g, 'sigil_stolas') and not E.unequip(g, 'sigil_stolas')
  )
  p.x, p.z = 27, 35
  local decoded =
    Save.decode('pilgrimage', Save.encode('pilgrimage', Save.capture('pilgrimage', g), 1))
  local continued = Game.new('pilgrimage', nil, { origin = decoded })
  continued.ephemeral = true
  check(
    'Continue keeps collection and equipped counts',
    continued.run.vows.sigil_stolas == 3 and continued.player.sigilRanks.sigil_stolas == 2
  )
  -- A save outlives a retuned sigil (PLAN G1): what it wears beyond the places,
  -- the copies found or the sigil's limit comes off in catalogue order; the
  -- file is never refused for it.
  local bad = Save.capture('pilgrimage', g)
  bad.pilgrimage.data.sigils = { sigil_stolas = 3, sigil_furfur = 3 }
  local fitted, worn = pcall(Save.section('pilgrimage').unpack, bad.pilgrimage.data)
  check(
    'a save wearing more than the places hold takes sigils off until it fits',
    fitted
      and worn.sigils.sigil_stolas == 3
      and worn.sigils.sigil_furfur == nil
      and E.sigilsWorn(worn) <= require('src.content.shop').sigilSlots
  )
  local offer = require('src.content.shop').get('sigil_stolas')
  local limit = offer.limit
  offer.limit = 2
  bad.pilgrimage.data.sigils = { sigil_stolas = 3 }
  local lowered, kept = pcall(Save.section('pilgrimage').unpack, bad.pilgrimage.data)
  offer.limit = limit
  check(
    'a sigil whose limit fell sheds the copies above it',
    lowered and kept.sigils.sigil_stolas == 2 and kept.vows.sigil_stolas == 2
  )
  bad.pilgrimage.data.sigils = { sigil_buer = 1.5 }
  check(
    'fractional copies are refused',
    not pcall(Save.section('pilgrimage').unpack, bad.pilgrimage.data)
  )
  g.state = 'playing'
  require('src.content.weapons').give(g, 'exorcist')
  local old = Save.capture('pilgrimage', g)
  old.pilgrimage.version = 2
  local oldData = old.pilgrimage.data
  oldData.loadout = { 'exorcist', 'judge' }
  oldData.sigils = { sigil_stolas = true, sigil_buer = true }
  local Tree = require('src.core.data_tree')
  local actors = Tree.decode(oldData.field.pools.data.pools)
  local oldKnight = actors.knights[oldData.field.pools.data.controlled]
  oldKnight.sigilRanks, oldKnight.sigilState = nil, nil
  oldKnight.rallyRate = 0.12
  oldData.field.pools.data.pools = Tree.encode(actors)
  oldData.field.pools.version = 3
  local legacy = Save.decode('pilgrimage', Save.encode('pilgrimage', old, 2))
  check('version two save decodes without compensation', legacy and legacy.pilgrimage.wallet == 777)
  local migrated = Game.new('pilgrimage', nil, { origin = legacy })
  migrated.ephemeral = true
  check(
    'legacy field restores equipped sigils from collection',
    migrated.player.sigilRanks
      and migrated.player.sigilRanks.sigil_stolas == 1
      and migrated.player.sigilRanks.sigil_buer == 1
  )
  check('legacy passive rally cannot remain active', migrated.player.rallyRate == nil)
  local near = F.within(1e-8)
  local attack = { base = 100, impact = 60, push = 10 }
  local target = { id = 55 }
  local function shot(id, rank)
    p.sigilRanks = { [id] = rank }
    S.reset(p)
    return S.shot(g, p, 'judge', attack, 1)
  end
  for rank, bonus in ipairs({ 0.15, 0.25, 0.35 }) do
    local a = shot('sigil_stolas', rank)
    check('Stolas ' .. rank .. ' torso cost', near(S.contact(a, target, 'torso').base, 90))
    check(
      'Stolas ' .. rank .. ' is not a passive head bonus',
      S.contact(a, target, 'head').base == 100
    )
    local hit = { hitTargets = { { id = 55, headHits = 0, healthDamage = 10 } } }
    S.resolved(p, a, hit)
    S.resolved(p, a, hit)
    check('repeated volley cannot count as two hits', not p.sigilState.verdictReady)
    local b = S.shot(g, p, 'judge', attack, 1)
    S.resolved(p, b, hit)
    local c = S.shot(g, p, 'judge', attack, 1)
    check(
      'two hits arm only the same target',
      near(S.contact(c, target, 'head').base, 100 * (1 + bonus))
        and S.contact(c, { id = 56 }, 'head').base == 100
    )
    hit.hitTargets[1].headHits = 1
    S.resolved(p, c, hit)
    check('successful verdict is spent', not p.sigilState.verdictReady)
  end
  for rank, bonus in ipairs({ 0.2, 0.3, 0.35 }) do
    shot('sigil_furfur', rank)
    S.perfect(g, p)
    local a = S.shot(g, p, 'exorcist', attack, 10)
    check(
      'Furfur ' .. rank .. ' same bonus for each pellet',
      near(S.contact(a, target, 'torso').base, 100 * (1 + bonus))
    )
    check(
      'Furfur miss spends first shot',
      S.contact(S.shot(g, p, 'judge', attack, 1), target, 'head').base == 100
    )
    S.perfect(g, p)
    g.elapsed = g.elapsed + 2
    check(
      'Furfur expires at two seconds',
      S.contact(S.shot(g, p, 'judge', attack, 1), target, 'head').base == 100
    )
    check('Furfur costs thirty stamina', S.dodgeCost(p, 26) == 30)
  end
  p.sigilRanks = { sigil_stolas = 1, sigil_furfur = 1 }
  S.reset(p)
  p.sigilState = { verdictTarget = 55, verdictReady = true }
  S.perfect(g, p)
  check(
    'combined damage caps at thirty-five percent',
    near(S.contact(S.shot(g, p, 'judge', attack, 1), target, 'head').base, 135)
  )
  for rank, hp in ipairs({ 8, 12, 16 }) do
    shot('sigil_buer', rank)
    p.hp, p.rally, p.x, p.z = 40, 30, 0, 0
    local injury = { info = { lost = 20 } }
    S.hurt(p, injury)
    local far = { health = 100, enemy = { x = 4.01, z = 0 } }
    S.rally(p, far)
    check('Buer ' .. rank .. ' waits for close hit', p.hp == 40)
    local hit = { health = 100, enemy = { x = 4, z = 0 } }
    S.rally(p, hit)
    S.hurt(p, injury)
    S.rally(p, hit)
    check(
      'Buer ' .. rank .. ' recovers once from actual pool',
      p.hp == 40 + hp and p.rally == 30 - hp
    )
    S.rally(p, { health = 100, enemy = { x = 1, z = 0 } })
    check('spent Buer does not also grant passive rally', p.hp == 40 + hp)
    check('Buer flask penalty', S.flask(p, 45) == 35)
    S.hurt(p, { info = { lost = 4 } })
    p.rally = 2
    S.rally(p, { health = 100, enemy = { x = 1, z = 0 } })
    check('Buer cannot exceed recoverable pool', p.hp == 42 + hp and p.rally == 0)
  end
  local Reload = require('src.combat.reload')
  local W = require('src.content.weapons')
  for rank, impact in ipairs({ 20, 35, 50 }) do
    local q = F.arena(Game)
    local knight = q.player
    knight.sigilRanks = { sigil_paimon = rank }
    knight.weapon = 2
    knight.arsenal.judge.mag = 0
    check('Paimon ' .. rank .. ' reload starts', Reload.start(q, false))
    local duration = Reload.mechanism(q, 2, knight).duration
    check('Paimon adds 0.2 seconds', near(knight.reloadDuration, duration + 0.2))
    Reload.update(q, knight.reloadDuration)
    local a = S.shot(q, knight, 'judge', attack, 1)
    check(
      'Paimon ' .. rank .. ' complete empty reload arms first shot',
      near(a.impact, 60 + impact) and a.base == 100 and a.push == 10
    )
    check('Paimon first miss spends charge', S.shot(q, knight, 'judge', attack, 1).impact == 60)
    knight.arsenal.judge.mag = 3
    Reload.start(q, false)
    Reload.update(q, knight.reloadDuration)
    check('partial reload does not arm Paimon', S.shot(q, knight, 'judge', attack, 1).impact == 60)
    knight.arsenal.judge.mag = 0
    Reload.start(q, false)
    Reload.cancel(q)
    check(
      'cancelled reload does not arm Paimon',
      S.shot(q, knight, 'judge', attack, 1).impact == 60
    )
    knight.weapon = 1
    knight.arsenal.exorcist.mag = 0
    Reload.start(q, false)
    Reload.update(q, knight.reloadDuration)
    a = S.shot(q, knight, 'exorcist', attack, 10)
    check('Paimon extra impact is shared over ten pellets', near((a.impact - 60) * 10, impact))
    S.reset(knight)
    check('rest clears pending charges', knight.sigilState == nil)
  end
  check(
    'all relic positions are reachable',
    #P.problems(require('src.content.pilgrimage').start()) == 0
  )
  return lines
end
return T
