-- Actual rush/flight integration and swept contacts; no appearance mocks.
local Fixtures = require('tests.support.fixtures')
local Contact = require('src.combat.body_contact')
local Attacks = require('src.enemies.actions')
local Melee = require('src.combat.melee')
local Rules = require('src.combat.rules')
local Tuning = require('src.content.tuning')
local Anchor = require('src.enemies.contact_anchor')
local Action = require('src.content.defs.action')
local Schema = require('src.core.schema')
local Tests = {}
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'attack contact: ', 'attack contact: ')
  local function setup()
    local g = Fixtures.arena(Game)
    g.player.x, g.player.z = 16, 25
    local e = g:spawn('imp', 16, 22)
    e.spawnAge, e.awake = 1, true
    return g, e
  end
  local g, e = setup()
  local r = require('src.content.characters').standard().body.radius + Rules.radius(e)
  Contact.moveEnemy(g, e, 0, 6)
  check('a full body crossing stops at the first contact', math.abs(e.z - (25 - r)) < 1e-8)
  local previous = { x = 16, z = 28, jump = 0, crouch = 0 }
  g.frame = { previousPlayer = previous }
  g.player.z = 22
  Contact.knight(g)
  check('a fast knight cannot tunnel through a demon either', g.player.z >= e.z + r - 1e-8)
  local distances = {}
  for _, rate in ipairs({ 60, 120, 240 }) do
    g, e = setup()
    local flight = 2 * math.sqrt(2 * Tuning.gravity) / Tuning.gravity
    e.leapY, e.leapVY, e.leapVX, e.leapVZ, e.leaping =
      0, math.sqrt(2 * Tuning.gravity), 0, 3 / flight, true
    local largest, correction = 0, 0
    for _ = 1, rate do
      local x, z = e.x, e.z
      Attacks.flight(g, e, 1 / rate)
      local beforeX, beforeZ = e.x, e.z
      Contact.demons(g)
      correction = math.max(correction, math.sqrt((e.x - beforeX) ^ 2 + (e.z - beforeZ) ^ 2))
      largest = math.max(largest, math.sqrt((e.x - x) ^ 2 + (e.z - z) ^ 2))
      if not e.leaping then
        break
      end
    end
    check('low leap remains outside knight at ' .. rate .. ' Hz', e.z <= 25 - r + 1e-8)
    check('landing has no depenetration pop at ' .. rate .. ' Hz', correction < 1e-8)
    check(
      'no displacement exceeds its integrated flight speed at ' .. rate .. ' Hz',
      largest <= 3 / flight / rate + 1e-8
    )
    distances[#distances + 1] = e.z
  end
  check(
    'flight contact location is independent of integration sampling',
    math.abs(distances[1] - distances[2]) < 1e-8 and math.abs(distances[2] - distances[3]) < 1e-8
  )
  g, e = setup()
  e.leapY, e.leapVY, e.leapVX, e.leapVZ, e.leaping = 0.01, -5, 1, 0, true
  local landing = (-5 + math.sqrt(25 + 2 * Tuning.gravity * 0.01)) / Tuning.gravity
  local startX = e.x
  Attacks.flight(g, e, 0.2)
  check(
    'partial final flight step ends at analytical floor time',
    not e.leaping and math.abs(e.x - startX - landing) < 1e-9
  )
  local old = { x = 15, z = 25, jump = 0, crouch = 0 }
  local now = { x = 17, z = 25, jump = 0, crouch = 0 }
  local hit, time = Melee.contact(g, 16, 24, 16, 26, 1, 0.2, old, now)
  check(
    'crossing claw and dodging player paths are tested continuously',
    hit and time > 0 and time < 1
  )
  old.jump, now.jump = 3, 3
  check(
    'a jump above the same swept contact remains a miss',
    not Melee.contact(g, 16, 24, 16, 26, 1, 0.2, old, now)
  )
  old = { x = 16, z = 25, jump = 0, crouch = 0 }
  hit, time = Melee.contact(g, 16, 25, 16, 25, 3, 0.2, old, old, 1)
  check(
    'a descending contact enters the head at its actual crossing time',
    hit and time > 0 and time < 1
  )
  check(
    'a hand moving above the head never hits its projected footprint',
    not Melee.contact(g, 16, 25, 16, 25, 3, 0.2, old, old, 2.5)
  )
  for _, kind in ipairs({ 'imp', 'armored', 'furfur' }) do
    g = Fixtures.arena(Game)
    e = g:spawn(kind, 16, 22)
    if kind == 'furfur' then
      -- Keep the authored claw contract covered after the live creature's
      -- close action became a horn thrust. This fixture is not live balance.
      Rules.equip(e, require('tests.support.content.furfur_v1'))
    end
    local atk = Rules.archetype(e).attacks[1]
    e.ai, e.phase, e.spawnAge, e.attackKind, e.attackSpec = 'strike', 0.08, 1, atk.id, atk
    e.lungeX, e.lungeZ = 0, 1
    local x, y, z = Anchor.point(g, e, e.phase, e.x, e.z, atk.contactAnchor)
    local lateX = Anchor.point(g, e, atk.duration * 0.5 + 0.001, e.x, e.z, atk.contactAnchor)
    check(
      kind .. ' both active painted frames provide a contact anchor without advancing AI',
      x ~= nil and lateX ~= nil and e.phase == 0.08
    )
    local ghost = {
      x = x,
      z = z + atk.contactReach[2],
      jump = y - require('src.content.characters').standard().body.height * 0.5,
      crouch = 0,
    }
    check(
      kind .. ' contact actually follows the authored painted point',
      Melee.claw(g, e, e.x, e.z, ghost, 0.07, 0.08, atk.lungeTime, atk.active, ghost, atk)
    )
    ghost.x = ghost.x + 3
    check(
      kind .. ' clearing the painted contact path remains safe',
      not Melee.claw(g, e, e.x, e.z, ghost, 0.07, 0.08, atk.lungeTime, atk.active, ghost, atk)
    )
  end
  local authored = Schema.copy(Rules.archetype(e).attacks[1])
  authored.contactAnchor, authored.contactReach, authored.contactRadius =
    'antler', { 0.1, 0.3 }, 0.25
  local custom = Action.build(authored)
  check(
    'another contact anchor, reach and radius are action data',
    custom.contactAnchor == 'antler'
      and custom.contactReach[2] == 0.3
      and custom.contactRadius == 0.25
  )
  authored.contactReach = { 0 / 0 }
  check('invalid contact depth is rejected at load time', not pcall(Action.build, authored))
  for _, leaving in ipairs({ true, false }) do
    g, e = setup()
    local atk = Rules.archetype(e).attacks[2]
    e.leapY, e.leapVY, e.leapVX, e.leapVZ, e.leaping = 0.01, -5, 0, 0, true
    g.player.x, g.player.z, g.player.armor = leaving and 19 or 16, 22, 0
    local previousPlayer = { x = leaving and 16 or 19, z = 22, jump = 0, crouch = 0 }
    Attacks.kinds.leap.strike(g, e, atk, 0.2, { previous = previousPlayer })
    check(
      'landing samples its impact instant, player ' .. (leaving and 'leaving' or 'arriving'),
      (g.player.hp < 100) == leaving
    )
  end
  return lines
end
return Tests
