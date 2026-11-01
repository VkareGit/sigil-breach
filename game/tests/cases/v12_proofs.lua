-- The extension proofs of plan v12: what the public registries take with no
-- change in game/src, each left as it was found. A proof that needs the inside
-- of a module means its contract is not ready.
local F = require('tests.support.fixtures')
local Proof = require('tests.support.extension.proof')
local Conditions = require('src.content.conditions')
local Characters = require('src.content.characters')
local Rules = require('src.combat.rules')
local Release = require('src.app.release')
local Save = require('src.storage.session_save')
local R2 = require('tests.support.extension.r2')
local R4 = require('tests.support.extension.r4')
local R5 = require('tests.support.extension.r5')
local T = {}
local function session(Game)
  local g = Game.new('field', 'proving', Release.sessionOptions.field)
  g.testing, g.state, g.elapsed = true, 'playing', 70
  g.enemies = {}
  return g
end
local function warden()
  local def = require('src.core.schema').copy(Characters.standard())
  def.id, def.name = 'trial_warden', nil
  def.body.hp, def.body.armor, def.body.shieldShare, def.body.dashCharges = 60, 10, 0.2, 3
  def.movement.moveSpeed = def.movement.moveSpeed * 1.4
  def.kit = { weapons = { 'judge' } }
  return def
end
function T.run(Game)
  local lines = {}
  local check = F.checker(lines, 'v12 proofs: ', 'v12 proofs: ')
  Proof.with({
    function()
      Conditions.unregister('proof_frost')
    end,
  }, function()
    Conditions.register('proof_frost', { speed = 0.6 })
    check('a new condition enters through its registry', Conditions.find('proof_frost') ~= nil)
    check('and a session starts with it present', session(Game) ~= nil)
  end)
  check('the proof leaves nothing behind', Conditions.find('proof_frost') == nil)
  check('a failing proof still fails', not pcall(Proof.with, {}, function()
    error('expected')
  end))
  -- R1: a second character is one definition.
  check('an actor is required', not pcall(Rules.playerBody))
  check('an unknown character is refused', not pcall(Characters.of, { character = 'nobody' }))
  local broken = warden()
  broken.movement.moveSpeed = nil
  broken.id = 'broken_warden'
  check('a character needs its whole movement', not pcall(Characters.define, broken))
  local knight = session(Game).player
  check(
    'the knight is the default character with his old numbers',
    knight.character == 'knight'
      and knight.hp == 100
      and knight.maxHp == 100
      and knight.maxArmor == 40
      and knight.dash == 2
  )
  Proof.with({
    function()
      Characters.unregister('trial_warden')
    end,
  }, function()
    Characters.define(warden())
    local g = session(Game)
    local w = g.ecs:create('knight', {
      id = 'warden1',
      character = 'trial_warden',
      x = 10,
      z = 20,
      yaw = 0,
      loadout = {},
      arsenal = {},
      abilities = {},
      abilityState = {},
    })
    check(
      'a new actor starts from its character',
      w.hp == 60 and w.maxHp == 60 and w.armor == 10 and w.dash == 3
    )
    check(
      'its shot leaves its own eye',
      select(2, require('src.combat.ballistics').origin(g, w)) > 1
    )
    local lost, absorbed = Rules.hitPlayer(g, { base = 20, impact = 0 }, nil, nil, w)
    check(
      'its shield share is its own',
      math.abs(absorbed - 4) < 1e-9 and math.abs(lost - 16) < 1e-9
    )
    check('and the HUD reads its share', math.abs(Characters.share(w) - 44 / 60) < 1e-9)
    local before = w.z
    for _ = 1, 60 do
      g:update(1 / 120, { actors = { warden1 = { forward = 1 } } })
    end
    local faster = math.abs(w.z - before)
    local base = Characters.standard().movement.moveSpeed
    check('it runs at its own speed ' .. faster, faster > base * 0.5 * 1.2)
    w.hp = 1
    check('it is low by its own share', Characters.low(w))
    local text = Save.encode(g)
    local other = session(Game)
    Save.restore(other, assert(Save.decode(text)))
    local back = require('src.session.world').get(other, 'warden1')
    check(
      'a save keeps its character',
      back and back.character == 'trial_warden' and back.maxHp == 60
    )
    local record = require('src.session.world').memberRecord(w)
    w.hp = 0
    check('a member record carries it', record ~= nil)
  end)
  check('the character leaves with its proof', not Characters.has('trial_warden'))
  -- A knight saved before characters existed comes back as the default one.
  local old = {}
  Characters.born(old)
  check('an old knight is born as the default', old.character == 'knight' and old.maxHp == 100)
  R2.run(Game, check, session)
  R4.run(Game, check, session)
  R5.run(Game, check, session)
  return lines
end
return T
