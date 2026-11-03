local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local Skin = require('src.ui.skin')
  local U = require('src.ui.interface')
  local Sanctuary = require('src.session.sanctuary')
  local W = require('src.world.arena')
  local B = require('src.combat.ballistics')
  local lines = {}
  local check = Fixtures.checker(lines, '', '')
  local function fresh()
    return Fixtures.started(G)
  end
  local atlas = love.image.newImageData(Skin.path)
  local _, _, _, alpha = atlas:getPixel(0, 0)
  check('UI bitmap has actual alpha outside its components', alpha < 0.05)
  local nearest = Skin.image:getFilter()
  check('UI atlas is sampled without bilinear blur', nearest == 'nearest')
  check(
    'unequal atlas row gutters exclude the next icon',
    Skin.bounds[9].y + Skin.bounds[9].h <= 916 and Skin.bounds[13].y >= 916
  )
  atlas:release()
  -- The atlas loader on a sheet the game cuts with uneven gutters: the spells
  -- (render/fresco_effects: row bands per column, authored column cuts in row 2).
  local spells = require('src.render.fresco_effects').spells
  local sheet = love.image.newImageData(spells.path)
  local w, h = sheet:getDimensions()
  local _, _, _, a = sheet:getPixel(0, 0)
  local image, feet, frames = require('src.render.atlas').load(
    spells.path,
    spells.columns,
    spells.rows,
    spells.bands,
    spells.columnBands
  )
  image:release()
  local cells = spells.columns * spells.rows
  check('spell sheet keeps its 16 cells and alpha', #frames == cells and a < 0.05)
  check('every spell pose has its own floor registration', #feet == cells)
  local valid = true
  for _, foot in ipairs(feet) do
    valid = valid and foot >= 0 and foot < 1
  end
  check('spell foot offsets remain inside each cell', valid)
  local painted, scale = true, true
  for frame = 1, cells do
    local rect = frames[frame].rect
    scale = scale and math.abs(frames[frame].height / (rect[4] * h) - spells.rows / h) < 0.00001
    local pixels = 0
    for y = math.floor(rect[2] * h + 0.5), math.floor((rect[2] + rect[4]) * h + 0.5) - 1, 4 do
      for x = math.floor(rect[1] * w + 0.5), math.floor((rect[1] + rect[3]) * w + 0.5) - 1, 4 do
        local _, _, _, alpha = sheet:getPixel(x, y)
        if alpha > 0.65 then
          pixels = pixels + 1
        end
      end
    end
    painted = painted and pixels > 20
  end
  check('every spell cell keeps its painted pigment inside its bands', painted)
  check('unequal frame heights preserve world size per source pixel', scale)
  local cuts, honoured = spells.columnBands[2], true
  for column = 1, spells.columns do
    local rect = frames[spells.columns + column].rect
    honoured = honoured
      and math.abs(rect[1] * w - cuts[column]) < 0.5
      and math.abs((rect[1] + rect[3]) * w - cuts[column + 1]) < 0.5
  end
  check('authored column cuts bound each frame, not the even grid', honoured)
  sheet:release()
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
      and (g.player.x - g.world.ember.x) ^ 2 + (g.player.z - g.world.ember.z) ^ 2 < 2.8 ^ 2
  )
  check(
    'merchant cannot be opened through the pillar',
    not Sanctuary.openShop(g) and g:context() == nil
  )
  g.player.x = 18
  g.player.z = 27
  check('merchant opens from the visible side', Sanctuary.openShop(g))
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
    -- The price is the focused offer's own (0.42 engravings cost 180 and 220), all of it missing.
    text:find(
      'Missing ' .. require('src.run.economy').quote(g, row.id:sub(5)) .. ' souls.',
      1,
      true
    ) and not text:find('Stale message', 1, true)
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
  Sanctuary.openShop(g)
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
