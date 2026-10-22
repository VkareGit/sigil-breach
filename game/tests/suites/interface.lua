local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local Skin = require('src.ui.skin')
  local U = require('src.ui.interface')
  local Run = require('src.run.descent')
  local W = require('src.world.arena')
  local B = require('src.combat.ballistics')
  local lines = {}
  local check = Fixtures.checker(lines, '', '')
  local function fresh()
    return Fixtures.expedition(G)
  end
  local atlas = love.image.newImageData('assets/art/ui-v07.png')
  local _, _, _, alpha = atlas:getPixel(0, 0)
  check('UI bitmap has actual alpha outside its components', alpha < 0.05)
  local nearest = Skin.image:getFilter()
  check('UI atlas is sampled without bilinear blur', nearest == 'nearest')
  check(
    'unequal atlas row gutters exclude the next icon',
    Skin.bounds[9].y + Skin.bounds[9].h <= 916 and Skin.bounds[13].y >= 916
  )
  atlas:release()
  local armored = love.image.newImageData('assets/art/armored-v07.png')
  local w, h = armored:getDimensions()
  local _, _, _, a = armored:getPixel(0, 0)
  local oldImage, oldFeet, oldFrames = require('src.render.atlas').load(
    'assets/art/armored-v07.png',
    6,
    4,
    {
      { 0, 260, 500, 727, 1024 },
      { 0, 260, 512, 725, 1024 },
      { 0, 260, 512, 724, 1024 },
      { 0, 260, 512, 727, 1024 },
      { 0, 260, 512, 729, 1024 },
      { 0, 260, 512, 727, 1024 },
    },
    { [2] = { 0, 264, 520, 790, 1040, 1325, 1536 } }
  )
  local legacyArmored = { image = oldImage, feet = oldFeet, frames = oldFrames }
  check('armored animation keeps 24 square cells and alpha', w / 6 == h / 4 and a < 0.05)
  check('all armored poses have independent floor registration', #legacyArmored.feet == 24)
  local valid = true
  for _, foot in ipairs(legacyArmored.feet) do
    valid = valid and foot >= 0 and foot < 0.6
  end
  check('armored foot offsets remain inside each cell', valid)
  local horns, scale = true, true
  for frame = 1, 24 do
    local region = legacyArmored.frames[frame]
    local rect = region.rect
    scale = scale and math.abs(region.height / (rect[4] * h) - 4 / h) < 0.00001
    if frame >= 19 then
      local top = math.floor(rect[2] * h + 0.5)
      local pixels = 0
      for y = top, 759 do
        for x = (frame - 19) * 256, (frame - 18) * 256 - 1 do
          local _, _, _, alpha = armored:getPixel(x, y)
          if alpha > 0.65 then
            pixels = pixels + 1
          end
        end
      end
      horns = horns and top <= 731 and pixels > 100
    end
  end
  check('all six back poses retain horns above the old 768px cut', horns)
  check('unequal frame heights preserve world size per source pixel', scale)
  local foreign, visible = 0, 0
  local attack = legacyArmored.frames[10].rect
  for y = 370, 450 do
    for x = 768, 782 do
      local red, green, _, alpha = armored:getPixel(x, y)
      if alpha > 0.65 and red > green * 1.5 then
        foreign = foreign + 1
        if
          x >= attack[1] * w
          and x < (attack[1] + attack[3]) * w
          and y >= attack[2] * h
          and y < (attack[2] + attack[4]) * h
        then
          visible = visible + 1
        end
      end
    end
  end
  check(
    'strike frame excludes opaque red pixels of the neighboring claw',
    foreign > 10 and visible == 0
  )
  armored:release()
  oldImage:release()
  -- 0.14: pillars are round (radius .46); the sight line crosses the shaft itself.
  local g = fresh()
  g.player.x = 19.25
  g.player.z = 25.2
  g.player.hp = 50
  g.pickups = { { kind = 'health', x = 20.3, z = 24.35, amount = 20 } }
  check(
    'pickup test straddles an actual pillar corner',
    not W.solid(g.world, g.player.x, g.player.z, 0.22)
      and not W.visible(g.world, g.player.x, g.player.z, 20.3, 24.35)
  )
  g:update(1 / 120, {})
  check('health cannot be collected through a pillar corner', g.player.hp == 50 and #g.pickups == 1)
  g.player.x = 20.3
  g.player.z = 24.22
  g:update(1 / 120, {})
  check('the same health pickup works from its open side', g.player.hp == 70 and #g.pickups == 0)
  -- Behind the round pillar (20,25), 45 degrees off the shrine axis, still in reach.
  g = fresh()
  g.player.x = 20.66
  g.player.z = 25.22
  check(
    'shop test is within reach on the blocked side',
    not W.solid(g.world, g.player.x, g.player.z, 0.22)
      and (g.player.x - Run.shrine.x) ^ 2 + (g.player.z - Run.shrine.z) ^ 2 < 2.8 ^ 2
  )
  check('merchant cannot be opened through the pillar', not Run.openShop(g) and g:context() == nil)
  g.player.x = 18
  g.player.z = 27
  check('merchant opens from the visible side', Run.openShop(g))
  g.run.wallet = 0
  g.shopMessage = 'Done. Stale message.'
  local row = U.controls(g, {})[4]
  U.hover(row.x + 40, row.y + 20)
  local printed = {}
  local original = Skin.text
  Skin.text = function(str, ...)
    printed[#printed + 1] = tostring(str)
    return original(str, ...)
  end
  U.draw(g, 1280, 720, {})
  Skin.text = original
  local text = table.concat(printed, '\n')
  check('hover updates the selected offer in the same frame', U.focus == 4)
  check(
    'current failure reason replaces a stale purchase receipt',
    text:find('Missing 100 souls.', 1, true) and not text:find('Stale message', 1, true)
  )
  U.useMouse = false
  U.mouseX = -1
  U.mouseY = -1
  g = fresh()
  g.player.x = 11
  g.player.z = 25
  g.player.yaw = math.pi / 2
  local e = g:spawn('armored', 13, 25)
  check(
    'target inspection cannot reveal a demon behind a pillar',
    B.trace(g, g.player.yaw, 0, 25) ~= e
  )
  -- Check hitboxes after letterboxing/scaling, including the smallest supported window.
  g = fresh()
  Run.openShop(g)
  local roundTrip = true
  for _, size in ipairs({ { 960, 540 }, { 1024, 768 }, { 1720, 720 }, { 1920, 1080 } }) do
    local scale, ox, oy = U.viewport(size[1], size[2])
    for _, b in ipairs(U.controls(g, {})) do
      local x, y =
        U.toLogical(ox + (b.x + b.w / 2) * scale, oy + (b.y + b.h / 2) * scale, size[1], size[2])
      roundTrip = roundTrip and U.actionAt(g, {}, x, y) == b.id
    end
  end
  check('all shop hitboxes align in four viewport shapes', roundTrip)
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests
