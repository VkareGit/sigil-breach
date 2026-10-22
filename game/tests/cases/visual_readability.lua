local T = {}
function T.run(check)
  local N = require('src.render.numbers')
  local FX = require('src.render.effects')
  local function world()
    local w = { size = 31, map = {} }
    for z = 1, 31 do
      w.map[z] = {}
      for x = 1, 31 do
        w.map[z][x] = 0
      end
    end
    return w
  end
  local r = { camera = { 16, 1.38, 27 }, w = 1280, h = 600 }
  function r:project(x, y, z)
    local d = self.camera[3] - z
    if d <= 0.1 then
      return
    end
    return self.w * 0.5 - (x - self.camera[1]) * 500 / d,
      self.h * 0.5 - (y - self.camera[2]) * 500 / d,
      d
  end
  local function number(x, y, z, value, age, side)
    return {
      x = x or 16,
      y = y or 1.38,
      z = z or 21,
      value = value or 42,
      age = age or 0.1,
      side = side or 1,
    }
  end
  local function fresh()
    return { state = 'playing', world = world(), view = { damageNumbers = {} } }
  end
  local function measure(text, h)
    return #text * h * 0.55
  end
  local g = fresh()
  g.view.damageNumbers = { number() }
  local items = N.layout(r, g, 0, 0, 1280, 600, measure)
  check(
    'confirmed damage uses a painted-number layout without changing the contact',
    #items == 1
      and items[1].text == '42'
      and g.view.damageNumbers[1].y == 1.38
      and g.view.damageNumbers[1].age == 0.1
  )
  check(
    'the complete number clears the centre aim box',
    not N.overlap(items[1].x, items[1].y, items[1].w, items[1].h, 615, 275, 50, 50)
  )
  g.world.map[24][16] = 1
  check(
    'a wall hides a damage number at its original contact',
    #N.layout(r, g, 0, 0, 1280, 600, measure) == 0
  )
  g.world.map[24][16] = 2
  check(
    'a round pillar hides contacts behind its shaft',
    #N.layout(r, g, 0, 0, 1280, 600, measure) == 0
  )
  g.view.damageNumbers = { number(17.5, 1.38, 21) }
  check(
    'a visible contact beside a round pillar remains visible',
    #N.layout(r, g, 0, 0, 1280, 600, measure) == 1
  )
  g = fresh()
  g.view.damageNumbers = { number(16, 1.38, 28) }
  check(
    'contacts behind the camera do not produce numbers',
    #N.layout(r, g, 0, 0, 1280, 600, measure) == 0
  )
  g.view.damageNumbers = { number(40, 1.38, 21) }
  check(
    'offscreen contacts do not stick damage numbers to the frame edge',
    #N.layout(r, g, 0, 0, 1280, 600, measure) == 0
  )
  g.view.damageNumbers = {
    number(nil, nil, nil, nil, 0.7),
    number(nil, nil, nil, nil, -0.1),
    number(0 / 0),
    number(nil, nil, nil, math.huge),
  }
  check(
    'expired negative-age and nonfinite damage entries are ignored',
    #N.layout(r, g, 0, 0, 1280, 600, measure) == 0
  )
  for _, mode in ipairs({ 'map', 'help', 'showDamageNumbers' }) do
    g = fresh()
    g.view.damageNumbers = { number() }
    g[mode] = mode ~= 'showDamageNumbers'
    check('damage numbers respect ' .. mode, #N.layout(r, g, 0, 0, 1280, 600, measure) == 0)
  end
  g = fresh()
  g.view.damageNumbers = { number() }
  g.state = 'paused'
  check(
    'damage numbers disappear on paused and menu screens',
    #N.layout(r, g, 0, 0, 1280, 600, measure) == 0
  )
  local sizes = {
    { 1280, 600, 0, 0 },
    { 960, 450, 0, 0 },
    { 1024, 480, 0, 144 },
    { 1920, 900, 0, 0 },
    {
      1280,
      600,
      220,
      0,
    },
  }
  for _, v in ipairs(sizes) do
    g = fresh()
    for i = 1, 8 do
      g.view.damageNumbers[i] =
        number(16 + (i % 3) * 0.04, 1.1, 21, 35 + i, 0.06 + i * 0.015, i % 2 == 0 and 1 or -1)
    end
    items = N.layout(r, g, v[3], v[4], v[1], v[2], measure)
    local bounded, clear = true, true
    for i, a in ipairs(items) do
      bounded = bounded
        and a.x >= v[3]
        and a.y >= v[4]
        and a.x + a.w <= v[3] + v[1]
        and a.y + a.h <= v[4] + v[2]
      clear = clear
        and not N.overlap(
          a.x,
          a.y,
          a.w,
          a.h,
          v[3] + v[1] * 0.5 - 25 * v[2] / 600,
          v[4] + v[2] * 0.5 - 25 * v[2] / 600,
          50 * v[2] / 600,
          50 * v[2] / 600
        )
      for j = i + 1, #items do
        local b = items[j]
        clear = clear and not N.overlap(a.x, a.y, a.w, a.h, b.x, b.y, b.w, b.h)
      end
    end
    check(
      string.format(
        '%dx%d damage numbers stay inside the scene, clear aim and each other',
        v[1],
        v[2]
      ),
      #items == 8 and bounded and clear
    )
  end
  g = fresh()
  local a = number()
  local b = number(16, 1.38, 21, 77, 0.02)
  b.head = true
  g.view.damageNumbers = { a }
  items = N.layout(r, g, 0, 0, 1280, 600, measure)
  local ax, ay = items[1].x, items[1].y
  g.view.damageNumbers[2] = b
  items = N.layout(r, g, 0, 0, 1280, 600, measure)
  check(
    'a new contact does not move an older number',
    items[1].source == a and items[1].x == ax and items[1].y == ay
  )
  check(
    'precision retains its distinct pigment and size',
    items[2].kind == 'head' and items[2].h > items[1].h and items[2].color[2] == 0.86
  )
  b.kill, b.broke, b.wound = true, true, true
  items = N.layout(r, g, 0, 0, 1280, 600, measure)
  check(
    'kill confirmation retains priority over wound guard and head colour',
    items[2].kind == 'kill'
  )
  local reused = items[1]
  N.layout(r, g, 0, 0, 1280, 600, measure)
  check('repeated layout reuses pooled boxes and colour tables', r.numberLayout.items[1] == reused)
  g.view.damageNumbers = {}
  for i = 1, 100 do
    g.view.damageNumbers[i] = number(16, 1.38, 21, i, 0.1)
  end
  items = N.layout(r, g, 0, 0, 1280, 600, measure)
  local recent = true
  for _, item in ipairs(items) do
    recent = recent and item.source.value >= 77
  end
  check(
    'damage-number layout caps work at the last 24 contacts',
    #items <= 24 and #r.numberLayout.pool <= 24 and recent
  )
  g.view.damageNumbers = { number(nil, nil, nil, 1e15) }
  items = N.layout(r, g, 0, 0, 1280, 600, measure)
  check(
    'large finite values stay decimal digits supported by the painted atlas',
    #items == 1 and items[1].text == '1000000000000000'
  )
  check(
    'Buer shoulder debug volumes use the torso pigment',
    FX.zoneColor('torso') ~= nil
      and FX.zoneColor('torso') ~= FX.zoneColor('head')
      and FX.zoneColor('unknown') == FX.zoneColor('torso')
  )
  local Gallery = require('src.render.gallery')
  local font = {
    getInk = function(_, text)
      return { x = -2, y = 3, w = #text * 8, h = 18 }
    end,
  }
  local text = '[E] SPAWN STAR ACOLYTE'
  local box = Gallery.labelBox(font, text, 280, 200, 0, 0, 1280, 600)
  check(
    'gallery plates contain actual painted ink with padding',
    box
      and box.textX - 2 == box[1] + 8
      and box.textY + 3 == box[2] + 5
      and box[3] == #text * 8 + 16
      and box[4] == 28
  )
  check(
    'gallery labels near the right edge disappear whole',
    Gallery.labelBox(font, text, 1260, 200, 0, 0, 1280, 600) == nil
  )
  check(
    'gallery labels near the left edge disappear whole',
    Gallery.labelBox(font, text, 20, 200, 0, 0, 1280, 600) == nil
  )
  check(
    'gallery labels leave the header and context strip clear',
    Gallery.labelBox(font, text, 280, 85, 0, 0, 1280, 600) == nil
      and Gallery.labelBox(font, text, 280, 560, 0, 0, 1280, 600) == nil
  )
  check(
    'gallery captions never cover the aiming centre',
    Gallery.labelBox(font, text, 640, 300, 0, 0, 1280, 600) == nil
  )
  check(
    'gallery containment respects letterboxed scene offsets',
    Gallery.labelBox(font, text, 450, 330, 200, 100, 960, 450) ~= nil
      and Gallery.labelBox(font, text, 220, 330, 200, 100, 960, 450) == nil
  )
end
return T
