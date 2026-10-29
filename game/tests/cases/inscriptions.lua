local Fixtures = require('tests.support.fixtures')
local Layout = require('src.content.maps.inscription_layout')
local Copy = require('src.core.schema').copy
local Maps = require('src.content.maps.index')
local Tests = {}
function Tests.run(Game, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'inscriptions: ', 'inscriptions: ')
  local map = Maps:get('proving')
  local function rejected(change)
    local data = Copy(map)
    change(data.decor.inscriptions[1], data.decor)
    return not pcall(require('src.content.maps.schema').check, data, 'inscription-regression')
  end
  check(
    'a caption cannot cross the painted panel edge',
    rejected(function(i)
      i.u = 0.03
    end)
  )
  check(
    'a caption cannot touch the crown or cornice',
    rejected(function(i)
      i.v = 1
    end)
  )
  check(
    'oversized text box rejected',
    rejected(function(i)
      i.width = 12
    end)
  )
  check(
    'missing painted support rejected',
    rejected(function(i)
      i.surface = 'absent'
    end)
  )
  check(
    'duplicate supporting id rejected',
    rejected(function(_, d)
      d.murals[#d.murals + 1] = Copy(Layout.surface(d, 'ash-witnesses'))
    end)
  )
  check(
    'stale independent world position rejected',
    rejected(function(i)
      i.x = 7.1
    end)
  )
  check(
    'zero margin rejected',
    rejected(function(i)
      i.margin = 0
    end)
  )
  check(
    'NaN placement rejected',
    rejected(function(i)
      i.v = 0 / 0
    end)
  )
  local decor = Copy(map.decor)
  local item = decor.inscriptions[1]
  local panel = Layout.surface(decor, item.surface)
  local place = Layout.resolve(item, decor, 0.2, {})
  panel.x, panel.z, panel.y = panel.x + 2, panel.z - 3, panel.y + 0.4
  local moved = Layout.resolve(item, decor, 0.2, {})
  check(
    'moving a painting moves its lettering in all three axes',
    math.abs(moved.x - place.x - 2) < 1e-8
      and math.abs(moved.z - place.z + 3) < 1e-8
      and math.abs(moved.y - place.y - 0.4) < 1e-8
  )
  for _, yaw in ipairs({ 0, math.pi / 2, math.pi, -math.pi / 2 }) do
    panel.yaw = yaw
    item.u = 0.6
    local p = Layout.resolve(item, decor, 0.2, {})
    local facing = (p.x - panel.x) * math.sin(yaw) + (p.z - panel.z) * math.cos(yaw)
    check('ink stays 4mm in front of its plane at yaw ' .. yaw, math.abs(facing - 0.004) < 1e-8)
  end
  local tall = Layout.resolve(item, decor, 2, {})
  check(
    'long and tall inscriptions fit without stretching',
    tall.height <= item.height + 1e-8
      and tall.width <= item.width
      and math.abs(tall.height / tall.width - 2) < 1e-8
  )
  local hidden = {}
  require('src.render.inscriptions').draw(hidden, {}, {})
  check('hidden supporting mural also hides its inscription', hidden.inscriptionPlacement == nil)
  require('src.render.inscriptions').init(renderer)
  for _, i in ipairs(map.decor.inscriptions) do
    local baked = renderer.wallInscriptions[i.id]
    local p = Layout.resolve(i, map.decor, baked.aspect, {})
    check(
      'actual glyph canvas fits reserved surface: ' .. i.surface,
      p.width <= i.width + 1e-8 and p.height <= i.height + 1e-8
    )
  end
  for index = 1, 2 do
    local seal, i = map.seals[index], map.decor.inscriptions[index]
    local p = Layout.resolve(i, map.decor, renderer.wallInscriptions[i.id].aspect, {})
    local distance = require('src.content.field').altar.reach
    local inkEdge = (math.abs(p.x - seal.x) - p.width / 2) / (seal.z + distance - p.z)
    check(
      'altar inscription clears the visible seal on approach: ' .. i.surface,
      inkEdge > 0.775 / distance
    )
  end
  local world = require('src.world.arena').new('field', 'proving')
  local Ground = require('src.physics.ground')
  for _, m in ipairs(map.decor.murals) do
    if m.z >= 34 then
      local fits = true
      for _, offset in ipairs({ -0.49, 0, 0.49 }) do
        local x = m.x + math.cos(m.yaw) * m.width * offset
        local z = m.z - math.sin(m.yaw) * m.width * offset
        local roof = Ground.ceiling(world, x, z, 1)
        fits = fits and roof and m.y + m.size < roof + 1e-8
      end
      check('entrance painting clears the real low vault at ' .. m.x .. ',' .. m.z, fits)
    end
  end
  -- A previous repeated ornament must not change a later ordinary sprite.
  local art = require('src.render.world_art')
  local shader = renderer.spriteShader
  local send, sent = shader.send, nil
  -- Native shader uniforms can be observed through a renderer-local proxy.
  renderer.spriteShader = setmetatable({
    send = function(_, name, value, ...)
      if name == 'wallRepeat' then
        sent = value
      end
      return send(shader, name, value, ...)
    end,
  }, {
    __index = function(_, key)
      return shader[key]
    end,
  })
  local ok, err = pcall(art.mural, renderer, nil, 10, 0, 10, 0, 0.24, 'chapel_frieze', 6.4, 1)
  renderer.spriteShader = shader
  assert(ok, err)
  check('repeated band restores neutral UVs for later sprites', sent == 1)
  return lines
end
return Tests
