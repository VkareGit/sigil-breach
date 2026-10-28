local Fixtures = require('tests.support.fixtures')
local Schema = require('src.content.maps.schema')
local Copy = require('src.core.schema').copy
local Maps = require('src.content.maps.index')
local Tests = {}
function Tests.run()
  local lines = {}
  local check = Fixtures.checker(lines, 'wall-mounts: ', 'wall-mounts: ')
  check(
    'current wall ornaments have backing across their complete width',
    pcall(Schema.check, Maps:get('proving'), 'proving')
  )
  local function reject(item, prop)
    local map = Copy(Maps:get('proving'))
    local list = prop and map.decor.props or map.decor.murals
    list[#list + 1] = item
    local ok, error = pcall(Schema.check, map, 'mount-regression')
    return not ok and tostring(error):find('unsupported wall ornament', 1, true) ~= nil
  end
  for _, face in ipairs({ { 17.36, -math.pi / 2 }, { 30.64, math.pi / 2 } }) do
    check(
      'frieze across entrance rejected at x=' .. face[1],
      reject({
        art = 'chapel_frieze',
        x = face[1],
        z = 27.65,
        yaw = face[2],
        width = 3.65,
        size = 0.24,
        y = 0.12,
        brightness = 0.8,
        wallMounted = true,
      })
    )
    check(
      'shelf floating in entrance rejected at x=' .. face[1],
      reject({
        art = 'funerary_shelf',
        x = face[1],
        z = 26.6,
        yaw = face[2],
        size = 0.66,
        y = 1,
        brightness = 0.9,
        wallMounted = true,
      }, true)
    )
  end
  check(
    'centre on masonry does not excuse an edge crossing a doorway',
    reject({
      art = 'chapel_mourners',
      x = 14.38,
      z = 10,
      yaw = -math.pi / 2,
      width = 3.5,
      size = 3.6,
      y = 0.18,
      brightness = 0.8,
      wallMounted = true,
    })
  )
  check(
    'outside map is not an invisible supporting wall',
    reject({
      art = 'chapel_mourners',
      x = 0,
      z = 0,
      yaw = 0,
      width = 2,
      size = 2,
      y = 0.18,
      brightness = 0.8,
      wallMounted = true,
    })
  )
  return lines
end
return Tests
