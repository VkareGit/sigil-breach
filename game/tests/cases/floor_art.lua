local Fixtures = require('tests.support.fixtures')
local Schema = require('src.content.maps.schema')
local Maps = require('src.content.maps.index')
local Copy = require('src.core.schema').copy
local Tests = {}
function Tests.run()
  local lines = {}
  local check = Fixtures.checker(lines, 'floor-art: ', 'floor-art: ')
  local function reject(edit, expected)
    local map = Copy(Maps:get('proving'))
    edit(map.decor.floorArt[1], map)
    local ok, err = pcall(Schema.check, map, 'floor-art-regression')
    return not ok and tostring(err):find(expected, 1, true) ~= nil
  end
  check(
    'published traces have complete flat support',
    pcall(Schema.check, Maps:get('proving'), 'proving')
  )
  check(
    'unknown image is rejected',
    reject(function(d)
      d.art = 'missing'
    end, 'unknown artwork')
  )
  check(
    'non-finite yaw is rejected',
    reject(function(d)
      d.yaw = 0 / 0
    end, 'invalid yaw')
  )
  check(
    'zero width is rejected',
    reject(function(d)
      d.width = 0
    end, 'invalid width')
  )
  check(
    'negative brightness is rejected',
    reject(function(d)
      d.brightness = -1
    end, 'invalid brightness')
  )
  check(
    'floating height is rejected',
    reject(function(d)
      d.y = 1
    end, 'height comes')
  )
  check(
    'trace across a wall is rejected',
    reject(function(d)
      d.z = 25
    end, 'unsupported footprint')
  )
  check(
    'trace through a pier is rejected',
    reject(function(d)
      d.x, d.z = 15, 20
    end, 'crosses a pillar')
  )
  check(
    'trace across a step is rejected',
    reject(function(d)
      d.x, d.z = 10, 9.5
    end, 'crosses a floor step')
  )
  local w = require('src.world.arena').new('proving')
  -- Public architecture is real solid geometry, not just decorative ribs.
  local Ground = require('src.physics.ground')
  local entry, nave = Ground.ceiling(w, 24, 36, 1.5), Ground.ceiling(w, 24, 20.5, 1.5)
  check('low human-scale entrance reveals the tall nave', entry > 2.8 and entry < 4 and nave > 10)
  return lines
end
return Tests
