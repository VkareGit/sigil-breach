-- A weapon's delivery is independent of its damage, reload and painted hands.
-- New delivery algorithms register their data schema here and their executor in
-- combat/weapon_delivery. Definitions never import simulation or presentation.
local Schema = require('src.core.schema')
local Registry = require('src.core.registry')
local Delivery = { kinds = Registry:new('weapon delivery schemas') }
function Delivery.defineKind(id, fields)
  local specs = { kind = { type = 'string', required = true } }
  for key, spec in pairs(fields or {}) do
    specs[key] = spec
  end
  return Delivery.kinds:register(id, Schema:new('weapon delivery ' .. id, specs))
end
Delivery.defineKind('hitscan', {})
Delivery.defineKind('projectile', {
  speed = { type = 'number', required = true, min = 0.001 },
  radius = { type = 'number', default = 0.04, min = 0 },
  color = { type = 'table', default = { 0.7, 0.3, 0.12 } },
  big = { type = 'boolean', default = false },
})
function Delivery.build(def, path)
  local built = Delivery.kinds:get(def.kind):build(def, path)
  if built.color then
    for i = 1, 3 do
      local value = built.color[i]
      assert(
        type(value) == 'number' and value >= 0 and value <= 1,
        (path or 'delivery') .. '.color: expected RGB channels in [0, 1]'
      )
    end
  end
  return built
end
return Delivery
