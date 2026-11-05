-- Reusable bodily streams, physical sowing and consumption of owned ground.
local Schema = require('src.core.schema')
local Area = require('src.content.defs.area')
local Packet = require('src.content.defs.packet')
local Conditions = require('src.content.conditions')
return function(Action)
  local Deposit = Schema:new('ground deposit', {
    group = { type = 'string', required = true },
    limit = { type = 'number', required = true, min = 1 },
    radius = { type = 'number', required = true, min = 0 },
    life = { type = 'number', required = true, min = 0 },
    delay = { type = 'number', required = true, min = 0 },
    pulse = { type = 'number', required = true, min = 0 },
    volume = Area.field('pool'),
    packet = { type = 'table', required = true, schema = Packet.schema },
    art = { type = 'string' },
    condition = { type = 'string' },
  })
  local Landing = Schema:new('seed destination', {
    forward = { type = 'number', required = true },
    lateral = { type = 'number', required = true },
  })
  local sow = {
    anchor = { type = 'string', required = true },
    gravity = { type = 'number', required = true, min = 0 },
    deposit = { type = 'table', required = true, schema = Deposit },
    marks = { type = 'table', required = true, list = Landing },
    needsSpace = { type = 'boolean', default = false },
    art = { type = 'string' },
  }
  for name, field in pairs(Action.projectile) do
    sow[name] = field
  end
  Action.defineKind('sow', sow, { 'speed', 'packet' }, {
    validate = function(a, path)
      assert(a.speed > 0 and a.gravity > 0, path .. ': positive flight speed and gravity required')
      assert(#a.marks > 0 and #a.marks <= 3, path .. ': requires 1..3 seeds')
      local d = a.deposit
      assert(
        d.limit % 1 == 0 and d.radius > 0 and d.life > 0 and d.pulse > 0,
        path .. ': invalid ground deposit'
      )
      Area.validate(d.volume, path .. '.deposit.volume')
      assert(
        not d.condition or Conditions.find(d.condition),
        path .. '.deposit.condition: unknown condition'
      )
    end,
  })
  Action.defineKind('harvest', {
    group = { type = 'string', required = true },
    mature = { type = 'number', required = true, min = 0 },
    radius = { type = 'number', required = true, min = 0 },
    life = { type = 'number', required = true, min = 0 },
    volume = Area.field('lightning'),
    art = { type = 'string' },
  }, { 'packet' }, {
    validate = function(a, path)
      assert(a.radius > 0 and a.life > 0, path .. ': positive eruption required')
      Area.validate(a.volume, path .. '.volume')
    end,
  })
  Action.defineKind('stream', {
    anchor = { type = 'string', required = true },
    height = { type = 'number', required = true },
    reach = { type = 'number', required = true, min = 0 },
    startWidth = { type = 'number', required = true, min = 0 },
    endWidth = { type = 'number', required = true, min = 0 },
    startHeight = { type = 'number', required = true, min = 0 },
    endHeight = { type = 'number', required = true, min = 0 },
    fall = { type = 'number', required = true, min = 0 },
    art = { type = 'string' },
  }, { 'packet' }, {
    validate = function(a, path)
      assert(
        a.reach > 0 and a.duration > 0 and a.endWidth > 0 and a.endHeight > 0,
        path .. ': positive stream extent required'
      )
    end,
  })
end
