-- Plan v12 R5: a creature with its own gas, its own way of moving and a line of
-- marked ground, listed in the proving ground, through public registries alone.
local Proof = require('tests.support.extension.proof')
local A = require('src.content.enemies')
local AI = require('src.enemies.ai')
local Action = require('src.content.defs.action')
local Anim = require('src.enemies.animation')
local Catalog = require('src.run.field.catalog')
local Contracts = require('src.session.content_contracts')
local Creature = require('src.content.defs.creature')
local HazardKinds = require('src.content.hazards')
local Hazards = require('src.enemies.hazards')
local Packet = require('src.content.defs.packet')
local Pools = require('src.session.world')
local R = {}
function R.run(Game, check, session)
  check('an unknown hazard kind is refused', not pcall(Action.build, {
    kind = 'pattern',
    id = 'proof_wrong',
    range = 5,
    windup = 0.5,
    hazard = 'nothing',
    radius = 1,
    life = 1,
    pulse = 0.5,
    marks = { { forward = 0, lateral = 0, delay = 0.5 } },
    packet = Packet.new(1, 0),
  }))
  Proof.with({
    function()
      A.unregister('proof_marsh')
      AI.styles.proof_drift = nil
      Anim.motions:unregister('proof_tremor')
      Hazards.kinds:unregister('proof_gas')
      HazardKinds:unregister('proof_gas')
      require('src.render.hazard_kinds'):unregister('proof_gas')
    end,
  }, function()
    HazardKinds:register('proof_gas', { volume = 'pool' })
    check('a hazard kind without an executor stops a session', not pcall(Contracts.validate))
    Hazards.kinds:register('proof_gas', Hazards.kinds:get('pool'))
    local Art = require('src.render.hazard_kinds')
    Art:register('proof_gas', Art:get('pool'))
    check('with one it composes', pcall(Contracts.validate))
    local drifted = 0
    function AI.styles.proof_drift(g, e, d, dt)
      drifted = drifted + dt
      return g, e, d
    end
    Anim.motions:register('proof_tremor', function(_, _, frame, bounce, lean)
      return frame, bounce, lean + 0.01
    end)
    check('an unknown motion stops a creature', not pcall(Contracts.creature, {
      id = 'proof_none',
      move = { style = 'keep', targeting = 'nearest' },
      appearance = { motion = 'nothing' },
      attacks = {},
    }))
    local def = Creature.define({
      extends = A.imp,
      id = 'proof_marsh',
      kind = 'imp',
      variant = 'proof_marsh',
      name = 'creature_imp',
      catalog = { field = 9 },
      appearance = { motion = 'proof_tremor' },
      move = { speed = 2, style = 'proof_drift' },
      attacks = {
        Action.pattern({
          id = 'proof_breath',
          origin = 'caster',
          range = 8,
          windup = 0.3,
          hazard = 'proof_gas',
          radius = 0.8,
          life = 1,
          pulse = 0.4,
          marks = {
            { forward = 1, lateral = 0, delay = 0.2 },
            { forward = 2, lateral = 0, delay = 0.3 },
            { forward = 3, lateral = 0, delay = 0.4 },
          },
          packet = Packet.new(3, 0, 'poison'),
        }),
      },
    })
    A.register(def)
    check('it joins the catalogue', Catalog.contains('proof_marsh'))
    check('and a session accepts it', pcall(Contracts.creature, def))
    local g = session(Game)
    local p = g.player
    local e = g:spawn('proof_marsh', p.x + 4, p.z)
    e.awake, e.memory, e.attack, e.spawnAge = true, 5, 1, 1
    local seen, marks = 0, 0
    for _ = 1, 480 do
      g:update(1 / 120, {})
      seen = math.max(seen, #Pools.of(g, 'hazards'))
      for _, h in ipairs(Pools.of(g, 'hazards')) do
        marks = marks + (h.kind == 'proof_gas' and 1 or 0)
      end
    end
    check('it moves its own way', drifted > 0)
    check('it lays its own ground in a line ' .. seen, seen >= 2 and marks > 0)
  end)
  check('it leaves with its proof', A.proof_marsh == nil and not HazardKinds:has('proof_gas'))
end
return R
