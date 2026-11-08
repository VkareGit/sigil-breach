local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local Anim = require('src.enemies.animation')
  local Weapon = require('src.render.weapon')
  local Portrait = require('src.ui.portrait')
  local Reload = require('src.combat.reload')
  local lines = {}
  local check = Fixtures.checker(lines, 'v08 art ', '')
  local near = Fixtures.within(1e-5)
  local function data(path)
    return love.image.newImageData('assets/art/' .. path .. '.png')
  end
  local function matchTexture(image, source)
    local w, h = source:getDimensions()
    if image:getWidth() ~= w or image:getHeight() ~= h then
      return false
    end
    -- Compare the texture actually loaded by the game with the shipped source.
    -- No golden screenshot or fixed art colors: artist revisions remain valid.
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setDepthMode()
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1)
    love.graphics.setBlendMode('replace', 'premultiplied')
    love.graphics.draw(image)
    love.graphics.pop()
    local rendered = canvas:newImageData()
    local ok = true
    local compared = 0
    for y = 8, h - 1, math.max(1, math.floor(h / 40)) do
      for x = 8, w - 1, math.max(1, math.floor(w / 40)) do
        local r, g, b, a = source:getPixel(x, y)
        local rr, gg, bb, aa = rendered:getPixel(x, y)
        if a > 0.65 then
          compared = compared + 1
          ok = ok
            and near(r, rr, 0.009)
            and near(g, gg, 0.009)
            and near(b, bb, 0.009)
            and near(a, aa, 0.009)
        end
      end
    end
    rendered:release()
    canvas:release()
    return ok and compared > 100, compared
  end
  local function rectOf(quad, source)
    local x, y, w, h = quad:getViewport()
    return {
      rect = {
        x / source:getWidth(),
        y / source:getHeight(),
        w / source:getWidth(),
        h / source:getHeight(),
      },
      height = 1,
      width = 1,
    }
  end
  local function stats(source, region)
    local w, h = source:getDimensions()
    local r = region.rect
    local x0, y0 = math.floor(r[1] * w + 0.5), math.floor(r[2] * h + 0.5)
    local x1, y1 =
      math.floor((r[1] + r[3]) * w + 0.0001) - 1, math.floor((r[2] + r[4]) * h + 0.0001) - 1
    local s = {
      opaque = 0,
      clear = 0,
      minX = x1,
      maxX = x0,
      minY = y1,
      maxY = y0,
      top = 0,
      bottom = 0,
      left = 0,
      right = 0,
      signature = {},
    }
    for y = y0, y1 do
      for x = x0, x1 do
        local _, _, _, a = source:getPixel(x, y)
        if a > 0.65 then
          s.opaque = s.opaque + 1
          s.minX = math.min(s.minX, x)
          s.maxX = math.max(s.maxX, x)
          s.minY = math.min(s.minY, y)
          s.maxY = math.max(s.maxY, y)
          if y == y0 then
            s.top = s.top + 1
          end
          if y == y1 then
            s.bottom = s.bottom + 1
          end
          if x == x0 then
            s.left = s.left + 1
          end
          if x == x1 then
            s.right = s.right + 1
          end
        elseif a < 0.05 then
          s.clear = s.clear + 1
        end
      end
    end
    for iy = 0, 23 do
      for ix = 0, 23 do
        local x = math.floor(x0 + (x1 - x0) * ix / 23)
        local y = math.floor(y0 + (y1 - y0) * iy / 23)
        local r, g, b, a = source:getPixel(x, y)
        s.signature[#s.signature + 1] = string.char(
          math.floor(r * 255 + 0.5),
          math.floor(g * 255 + 0.5),
          math.floor(b * 255 + 0.5),
          math.floor(a * 255 + 0.5)
        )
      end
    end
    s.signature = love.data.hash('sha256', table.concat(s.signature))
    s.x0, s.y0, s.x1, s.y1 = x0, y0, x1, y1
    s.width, s.height = s.maxX - s.minX + 1, s.maxY - s.minY + 1
    return s
  end
  local function fresh()
    local g = G.new('floor')
    g.ephemeral = true
    g:start()
    g.player.yaw = math.pi
    g.enemies = {}
    return g
  end
  local Catalog = require('src.render.fresco_enemies')
  for _, kind in ipairs({ 'imp', 'armored', 'stolas', 'buer', 'boss' }) do
    local entry = Catalog.entries[kind]
    local source = love.image.newImageData(entry.path)
    local image = renderer.animations[kind]
    local columns = entry.columns
    local frameSources, extraSources = {}, {}
    for _, replacement in ipairs(entry.replacements or {}) do
      local extra = love.image.newImageData(replacement.path)
      extraSources[#extraSources + 1] = extra
      for _, frame in pairs(replacement.targets) do
        frameSources[frame] = extra
      end
    end
    local _, _, _, alpha = source:getPixel(0, 0)
    local regions = renderer.frames[kind]
    local all, unique, seen, measurements = true, true, {}, {}
    check(
      kind .. ' uses the active fresco texture with sharp nearest sampling',
      image:getFilter() == 'nearest' and matchTexture(image, source)
    )
    for i, region in ipairs(regions) do
      local actual = frameSources[i] or source
      local s = stats(actual, region)
      s.displayHeight = s.height / (s.y1 - s.y0 + 1) * region.height
      measurements[i] = s
      all = all and s.opaque > 300 and s.clear > 300
      if frameSources[i] then
        check(
          kind .. ' repaired frame ' .. i .. ' uses its actual source texture',
          matchTexture(renderer.frameImages[kind][i], actual)
        )
      end
      -- Multiple named states may reuse one authored cell. Two different
      -- source cells must still contain genuinely different paintings.
      local cell = region.sourcePath .. ':' .. table.concat(region.rect, ',')
      unique = unique and (not seen[s.signature] or seen[s.signature] == cell)
      seen[s.signature] = cell
    end
    check(
      kind .. ' has every required opaque pose and distinct paintings in distinct source cells',
      #regions == Catalog.frameCount(kind) and alpha < 0.05 and all and unique
    )
    local grounded = true
    local groundProblems = {}
    for i, s in ipairs(measurements) do
      local cropHeight = s.y1 - s.y0 + 1
      local measuredBottom = (s.y1 - s.maxY) / cropHeight
      local error = math.abs(renderer.feet[kind][i] - measuredBottom) * cropHeight
      -- Single-pixel claw tips and isolated antialiased flecks do not define the
      -- supporting foot. Allow up to 3% of a cell, but reject detached baselines.
      local tolerance = math.max(4, cropHeight * 0.03) + 1e-6
      if error > tolerance then
        groundProblems[#groundProblems + 1] = i .. ':' .. error
      end
      grounded = grounded
        and renderer.feet[kind][i] >= 0
        and renderer.feet[kind][i] < 0.8
        and error <= tolerance
    end
    check(
      kind
        .. ' floor registration follows opaque feet in every pose ['
        .. table.concat(groundProblems, ', ')
        .. ']',
      grounded
    )
    local gutterProblems = {}
    for i, s in ipairs(measurements) do
      if i > columns and s.top > 3 then
        gutterProblems[#gutterProblems + 1] = i .. ' top:' .. s.top
      end
      if i <= columns * 3 and s.bottom > 3 then
        gutterProblems[#gutterProblems + 1] = i .. ' bottom:' .. s.bottom
      end
    end
    check(
      kind
        .. ' internal row crops preserve horns, wings and corpse edges ['
        .. table.concat(gutterProblems, ', ')
        .. ']',
      #gutterProblems == 0
    )
    local columnProblems = {}
    for i, s in ipairs(measurements) do
      if (i - 1) % columns > 0 and s.left > 6 then
        columnProblems[#columnProblems + 1] = i .. ' left:' .. s.left
      end
      if i % columns > 0 and s.right > 6 then
        columnProblems[#columnProblems + 1] = i .. ' right:' .. s.right
      end
    end
    check(
      kind
        .. ' column crops isolate adjacent claws and wings ['
        .. table.concat(columnProblems, ', ')
        .. ']',
      #columnProblems == 0
    )
    local death = columns == 6 and 18 or 12
    check(
      kind .. ' finished corpse has a lower silhouette than its living stance',
      measurements[death].displayHeight < measurements[1].displayHeight * 0.80
    )
    for _, extra in ipairs(extraSources) do
      extra:release()
    end
    source:release()
    local g = fresh()
    local e = g:spawn(kind, 16, 23)
    e.awake = true
    e.memory = 3
    e.facing = 0
    e.walkSpeed = 2
    e.ai = 'move'
    local front, back = {}, {}
    for i = 0, 100 do
      g.elapsed = i * 0.025
      e.walk = i * 0.025
      e.facing = 0
      front[Anim.pose(g, e)] = true
      e.facing = math.pi
      back[Anim.pose(g, e)] = true
    end
    local frontCount, backCount = 0, 0
    for frame in pairs(front) do
      frontCount = frontCount + 1
      all = all and frame >= 1 and frame <= columns
    end
    for frame in pairs(back) do
      backCount = backCount + 1
      all = all and frame > columns * 3 and frame <= columns * 4
    end
    check(
      kind .. ' animation reaches all forward and rear locomotion poses',
      frontCount == columns and backCount == columns and all
    )
    local states = {}
    e.facing = 0
    e.walkSpeed = 0
    e.ai = 'windup'
    e.windupDuration = 0.74
    for _, t in ipairs({ 0.73, 0.38, 0.02 }) do
      e.windup = t
      states[#states + 1] = Anim.pose(g, e)
    end
    e.ai = 'strike'
    e.phase = 0.01
    local strike = Anim.pose(g, e)
    e.ai = 'recover'
    e.phase = 0.1
    local recover = Anim.pose(g, e)
    e.ai = 'hurt'
    e.phase = 0.1
    local hurt = Anim.pose(g, e)
    e.hp = 0
    e.deathTime = 0
    local falling = Anim.pose(g, e)
    e.deathTime = 8
    local settled = Anim.pose(g, e)
    check(
      kind .. ' telegraph, impact, recovery, pain and death use separate authored states',
      states[1] ~= strike
        and strike ~= recover
        and recover ~= hurt
        and hurt ~= falling
        and falling ~= settled
        and settled == death
    )
  end
  local g = fresh()
  local stolas = g:spawn('stolas', 16, 23)
  stolas.ai = 'idle'
  stolas.walkSpeed = 0
  stolas.walk = 0
  stolas.awake = true
  stolas.memory = 2
  stolas.facing = 0
  local poses = {}
  local low, high = math.huge, -math.huge
  for i = 0, 600 do
    g.elapsed = i / 120
    local frame, height = Anim.pose(g, stolas)
    poses[frame] = true
    low = math.min(low, height)
    high = math.max(high, height)
  end
  local count = 0
  for _ in pairs(poses) do
    count = count + 1
  end
  check(
    'stationary Stolas has four watchful gestures and a restrained hover',
    count == 4 and poses[25] and poses[28] and high - low > 0.03 and high - low < 0.15
  )
  stolas.hp = 0
  stolas.deathTime = 8
  local dead, bounce = Anim.pose(g, stolas)
  g.elapsed = g.elapsed + 10
  local later, laterBounce = Anim.pose(g, stolas)
  check(
    'dead Stolas stops hovering and remains in its final corpse pose',
    dead == 18 and later == 18 and bounce == 0 and laterBounce == 0
  )
  local selected
  local oldSprite, oldShader, oldDraw = renderer.sprite, renderer.spriteShader, love.graphics.draw
  renderer.sprite = {
    setTexture = function(_, image)
      selected = image
    end,
  }
  renderer.spriteShader = { send = function() end }
  love.graphics.draw = function() end
  local boss = g:spawn('boss', 16, 23)
  boss.hp = 0
  boss.deathTime = 0
  renderer:enemy(g, boss)
  local startImage = selected
  boss.deathTime = 0.16
  renderer:enemy(g, boss)
  local fallImage = selected
  boss.deathTime = 3
  renderer:enemy(g, boss)
  local corpseImage = selected
  boss.hp = 100
  boss.ai = 'idle'
  boss.walkSpeed = 0
  renderer:enemy(g, boss)
  local livingImage = selected
  renderer.sprite, renderer.spriteShader, love.graphics.draw = oldSprite, oldShader, oldDraw
  local function bossImage(frame)
    return renderer.frameImages.boss[frame] or renderer.animations.boss
  end
  check(
    'boss living, falling and settled states use their catalogued active images',
    startImage == bossImage(10)
      and livingImage == bossImage(Anim.pose(g, boss))
      and fallImage == bossImage(11)
      and corpseImage == bossImage(12)
  )
  local source = love.image.newImageData(Portrait.path)
  local faceStates = {}
  for i, q in ipairs(Portrait.quads) do
    faceStates[i] = stats(source, rectOf(q, source))
  end
  check(
    'HUD portrait uses the active fresco atlas with six painted states and stable linear reduction',
    #faceStates == 6
      and faceStates[1].opaque > 1000
      and matchTexture(Portrait.image, source)
      and Portrait.image:getFilter() == 'linear'
  )
  source:release()
  g = fresh()
  g.view.shotAge = 10
  g.view.hurt = 0
  g.time = 0
  local idle = Portrait.frame(g)
  g.time = 3 / 0.65
  local left = Portrait.frame(g)
  g.time = 5 / 0.65
  local right = Portrait.frame(g)
  g.view.shotAge = 0.01
  local fire = Portrait.frame(g)
  g.view.hurt = 0.8
  local hurt = Portrait.frame(g)
  g.player.hp = 18
  local critical = Portrait.frame(g)
  check(
    'portrait reacts to glances, firing, pain and critical health with explicit priority',
    idle == 1 and left == 2 and right == 3 and fire == 6 and hurt == 4 and critical == 5
  )
  check(
    'portrait reactions contain genuinely different painted frames',
    faceStates[1].signature ~= faceStates[2].signature
      and faceStates[1].signature ~= faceStates[3].signature
      and faceStates[4].signature ~= faceStates[5].signature
      and faceStates[5].signature ~= faceStates[6].signature
  )
  local portraitClipped = true
  local window = assert(Portrait.bounds)
  local poseInputs = {
    { 0, 10, 0, 100 },
    { 3 / 0.65, 10, 0, 100 },
    { 5 / 0.65, 10, 0, 100 },
    { 0, 10, 0.8, 100 },
    { 0, 10, 0, 18 },
    { 0, 0.01, 0, 100 },
  }
  for _, state in ipairs(poseInputs) do
    g.time, g.view.shotAge, g.view.hurt, g.player.hp = unpack(state)
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setDepthMode()
    love.graphics.setShader()
    love.graphics.setBlendMode('replace', 'premultiplied')
    love.graphics.clear(0, 0, 0, 0)
    Portrait.draw(g, 565, 584, 150)
    love.graphics.pop()
    local pixels = canvas:newImageData()
    local insideCount = 0
    for y = 580, 719 do
      for x = 566, 714 do
        local _, _, _, alpha = pixels:getPixel(x, y)
        if x < window.x or x >= window.x + window.w or y < window.y or y >= window.y + window.h then
          portraitClipped = portraitClipped and alpha < 0.009
        elseif alpha > 0.25 then
          insideCount = insideCount + 1
        end
      end
    end
    portraitClipped = portraitClipped and insideCount > 500
    pixels:release()
    canvas:release()
  end
  check('all six portrait expressions stay inside the arched HUD window', portraitClipped)
  for slot, art in ipairs(require('src.render.weapon_art').ids) do
    local name = Weapon.paths[art]
    source = love.image.newImageData(name)
    local image = Weapon.images[art]
    local signatures, valid = {}, true
    for i, q in ipairs(Weapon.quads[art]) do
      local s = stats(source, rectOf(q, source))
      local _, _, qw, qh = q:getViewport()
      valid = valid
        and s.opaque > 500
        and s.clear > 500
        and Weapon.origins[art][i] > 0
        and Weapon.origins[art][i] <= qh
      signatures[i] = s.signature
    end
    local meta = require('src.content.weapon_art').get(art)
    local distinct = signatures[meta.frameNames.ready] ~= signatures[meta.frameNames.recoil]
      and signatures[meta.frameNames.recoil] ~= signatures[meta.frameNames.settle]
    check(
      name
        .. ' keeps its active texture, alpha and distinct firing poses; open-hold aliases are intentional',
      valid and distinct and matchTexture(image, source) and image:getFilter() == 'nearest'
    )
    source:release()
  end
  g = fresh()
  g.player.weapon = 1
  g.player.arsenal.exorcist.reserve = 8
  g:shoot()
  local used = {}
  local stable = true
  local opened, loadedOpen = false, false
  for i = 0, 114 do
    local frame = Weapon.frame(g)
    used[frame] = true
    stable = stable and Weapon.quads.exorcist[frame] ~= nil
    opened = opened or g.player.arsenal.exorcist.open
    loadedOpen = loadedOpen
      or (g.player.arsenal.exorcist.open and g.player.arsenal.exorcist.mag == 2)
    g.view.shotAge = g.view.shotAge + 1 / 120
    Reload.update(g, 1 / 120)
  end
  used[Weapon.frame(g)] = true
  count = 0
  for _ in pairs(used) do
    count = count + 1
  end
  check(
    'fired shotgun renders real firing, open and loaded-open poses through the latch transaction',
    stable
      and used[1]
      and used[2]
      and used[3]
      and opened
      and loadedOpen
      and not g.player.arsenal.exorcist.open
      and g.player.arsenal.exorcist.mag == 2
      and g.player.arsenal.exorcist.reserve == 6
  )
  g = fresh()
  g.player.weapon = 2
  used = {}
  for i = 0, 36 do
    g.view.shotAge = i / 120
    used[Weapon.frame(g)] = true
  end
  count = 0
  for frame in pairs(used) do
    count = count + 1
    stable = stable and Weapon.quads.judge[frame] ~= nil
  end
  check(
    'revolver renders recoil catch and ready without an unused logical phase',
    stable and count == 3 and used[2] and used[3] and Weapon.frame(g) == 1
  )
  source = data('shrine-fresco-v12')
  local shrineDistinct, shrineValid, seen = true, true, {}
  for _, region in ipairs(renderer.shrineFrames) do
    local s = stats(source, region)
    shrineValid = shrineValid and s.opaque > 1000 and s.clear > 1000
    shrineDistinct = shrineDistinct and not seen[s.signature]
    seen[s.signature] = true
  end
  check(
    'shrine uses four separate transparent flame frames without filtered blur',
    #renderer.shrineFrames == 4
      and shrineValid
      and shrineDistinct
      and renderer.shrineImage:getFilter() == 'nearest'
      and matchTexture(renderer.shrineImage, source)
  )
  source:release()
  -- The renderer selects all four flame frames and dims the same silhouette
  -- during a live wave. Inspect uniforms, not a fragile screenshot brightness.
  local sent = {}
  local proxy = {
    send = function(_, key, value)
      sent[key] = value
    end,
  }
  local WorldArt = require('src.render.world_art')
  local originalShader = renderer.spriteShader
  local originalDraw = love.graphics.draw
  renderer.spriteShader = proxy
  love.graphics.draw = function() end
  g = fresh()
  used = {}
  for i = 0, 3 do
    g.time = i * 0.2 + 0.01
    WorldArt.shrine(renderer, g)
    used[sent.frameRect] = true
  end
  local lit = sent.brightness
  renderer.spriteShader = originalShader
  love.graphics.draw = originalDraw
  count = 0
  for _ in pairs(used) do
    count = count + 1
  end
  -- v11 paints the cold flame already light; the altar must stay near full brightness.
  check('shrine cycles every flame pose', count == 4 and lit >= 0.9)
  local reliquary = require('src.ui.reliquary')
  reliquary.init()
  source = love.image.newImageData(reliquary.path)
  check(
    'live GUI uses the authored fresco surface with stable linear reduction',
    reliquary.image:getFilter() == 'linear' and matchTexture(reliquary.image, source)
  )
  local _, barY, _, barH = reliquary.bar:getViewport()
  local separate = true
  for _, piece in ipairs(reliquary.frames) do
    local _, y = piece.q:getViewport()
    separate = separate and y > barY + barH
  end
  check(
    'HUD bar and nine menu pieces are cropped from separate artwork regions',
    #reliquary.frames == 9 and separate
  )
  source:release()
  source = love.image.newImageData(reliquary.path)
  local px, py, pw, ph = reliquary.paperQuiet:getViewport()
  check(
    'painted lime ground is active and stays inside the quiet source interior',
    matchTexture(reliquary.paper, source)
      and reliquary.paper:getFilter() == 'linear'
      and px >= 200
      and py >= 500
      and px + pw <= 1300.001
      and py + ph <= 826.001
  )
  local oldDraw = love.graphics.draw
  local groundCorrect = true
  local groundDraws = 0
  love.graphics.draw = function(image, quad, x, y, angle, sx, sy, ...)
    if image == reliquary.image and quad == reliquary.paperQuiet then
      local qx, qy, qw, qh = quad:getViewport()
      groundDraws = groundDraws + 1
      groundCorrect = groundCorrect
        and near(sx, sy)
        and qx >= 200
        and qy >= 500
        and qx + qw <= 1300.001
        and qy + qh <= 826.001
    end
    return oldDraw(image, quad, x, y, angle, sx, sy, ...)
  end
  love.graphics.push('all')
  for _, size in ipairs({ { 440, 536 }, { 1024, 564 }, { 320, 44 } }) do
    reliquary.plaster(0, 0, size[1], size[2])
  end
  love.graphics.pop()
  love.graphics.draw = oldDraw
  check(
    'tall, wide and button lime grounds preserve pigment aspect and exclude painted borders',
    groundDraws == 3 and groundCorrect
  )
  local Skin = require('src.ui.skin')
  local iconSource = data('ui-fresco-v12')
  local iconsValid, iconSeen, iconCount = true, {}, 0
  for _, entry in pairs(Skin.icons) do
    local ix, iy, iw, ih = entry.q:getViewport()
    local sample = stats(iconSource, rectOf(entry.q, iconSource))
    iconsValid = iconsValid
      and ix >= 0
      and iy >= 0
      and ix + iw <= iconSource:getWidth()
      and iy + ih <= iconSource:getHeight()
      and sample.opaque > 100
      and sample.clear > 100
      and not iconSeen[sample.signature]
    iconSeen[sample.signature] = true
    iconCount = iconCount + 1
  end
  check(
    'twelve separate fresco interface emblems use their actual transparent authored atlas',
    iconCount == 12 and iconsValid and matchTexture(Skin.image, iconSource)
  )
  iconSource:release()
  source:release()
  source = data('murals-fresco-v12')
  local frescoSeen = {}
  local frescoValid = true
  for i = 0, 3 do
    local s = stats(source, { rect = { i % 2 * 0.5, math.floor(i / 2) * 0.5, 0.5, 0.5 } })
    frescoValid = frescoValid and s.opaque > 1000 and not frescoSeen[s.signature]
    frescoSeen[s.signature] = true
  end
  check(
    'four distinct wall frescoes use the active pigment texture with stable reduction',
    frescoValid
      and matchTexture(renderer.frescoes, source)
      and renderer.frescoes:getFilter() == 'linear'
  )
  source:release()
  local Titles = require('src.ui.fonts.painted_titles').init()
  source = love.image.newImageData(Titles.path)
  local lettersValid, letterSeen = true, {}
  for _, name in ipairs({
    'sigil',
    'breach',
    'merchant',
    'settings',
    'new_run',
    'interrupted',
  }) do
    local entry = Titles.entries[name]
    local x, y, w, h = entry.q:getViewport()
    local s = stats(source, rectOf(entry.q, source))
    lettersValid = lettersValid
      and x >= 0
      and y >= 0
      and x + w <= source:getWidth()
      and y + h <= source:getHeight()
      and s.opaque > 500
      and s.clear > 500
      and not letterSeen[s.signature]
    letterSeen[s.signature] = true
  end
  check(
    'all eight literal English heading crops preserve separate painted ink and transparency',
    lettersValid
  )
  check(
    'literal headings use their active nearest-filtered PNG artwork',
    Titles.image:getFilter() == 'nearest' and matchTexture(Titles.image, source)
  )
  -- A light writing ground needs the painted strokes, not the source's wide
  -- dark drop-rim. Compare actual GPU alpha against dark / light source samples.
  local title = Titles.entries.merchant
  local tx, ty, tw, th = title.q:getViewport()
  local titleCanvas = love.graphics.newCanvas(tw, th)
  love.graphics.push('all')
  love.graphics.setCanvas(titleCanvas)
  love.graphics.origin()
  love.graphics.setScissor()
  love.graphics.setShader()
  love.graphics.setDepthMode()
  love.graphics.setBlendMode('replace', 'premultiplied')
  love.graphics.clear(0, 0, 0, 0)
  Titles.draw('merchant', 0, 0, tw, th, 1, true)
  love.graphics.pop()
  local titlePixels = titleCanvas:newImageData()
  local darkSamples, lightSamples, clearSamples, inkValid = 0, 0, 0, true
  for y = 0, th - 1, 3 do
    for x = 0, tw - 1, 3 do
      local r, gc, b, a = source:getPixel(tx + x, ty + y)
      local l = r * 0.30 + gc * 0.59 + b * 0.11
      local rr, rg, rb, ra = titlePixels:getPixel(x, y)
      if a > 0.9 and l < 0.10 then
        darkSamples = darkSamples + 1
        inkValid = inkValid and ra < 0.02
      end
      if a > 0.9 and l > 0.75 then
        lightSamples = lightSamples + 1
        inkValid = inkValid and ra > 0.8 and rr < 0.4 and rg < 0.4 and rb < 0.4
      end
      if a < 0.01 then
        clearSamples = clearSamples + 1
        inkValid = inkValid and ra < 0.02
      end
    end
  end
  check(
    'light-ground title preserves dark readable strokes and transparent counters',
    inkValid and clearSamples > 100 and lightSamples > 100
  )
  titlePixels:release()
  titleCanvas:release()
  source:release()
  local Numbers = require('src.ui.fonts.painted_numbers').init()
  source = love.image.newImageData(Numbers.path)
  local numberValid, numberSeen = true, {}
  for c in ('0123456789%/'):gmatch('.') do
    local entry = Numbers.glyphs[c]
    local x, y, w, h = entry.q:getViewport()
    local s = stats(source, rectOf(entry.q, source))
    numberValid = numberValid
      and x >= 0
      and y >= 0
      and x + w <= source:getWidth()
      and y + h <= source:getHeight()
      and s.opaque > 500
      and s.clear > 100
    numberValid = numberValid and not numberSeen[s.signature]
    numberSeen[s.signature] = true
  end
  check('twelve illustrated numerical glyphs have separate ink, valid crops and alpha', numberValid)
  check(
    'illustrated numbers use the actual generated PNG with sharp sampling',
    Numbers.image:getFilter() == 'nearest' and matchTexture(Numbers.image, source)
  )
  source:release()
  for _, value in ipairs({ '000', '100%', '999999999', '0/9' }) do
    local old = love.graphics.draw
    local count, x1, y1, x2, y2, undistorted = 0, math.huge, math.huge, -math.huge, -math.huge, true
    love.graphics.draw = function(image, quad, x, y, rotation, sx, sy, ...)
      if image == Numbers.image then
        local _, _, w, h = quad:getViewport()
        count = count + 1
        undistorted = undistorted and sx == sy and rotation == 0
        x1 = math.min(x1, x)
        y1 = math.min(y1, y)
        x2 = math.max(x2, x + w * sx)
        y2 = math.max(y2, y + h * sy)
      end
      return old(image, quad, x, y, rotation, sx, sy, ...)
    end
    love.graphics.push('all')
    love.graphics.setColor(0.2, 0.4, 0.6, 0.8)
    local x, y, w, h = Numbers.draw(value, 640, 650, 126, 36, { 1, 0.8, 0.6, 0.7 })
    local r, gc, b, a = love.graphics.getColor()
    love.graphics.pop()
    love.graphics.draw = old
    check(
      'illustrated ' .. value .. ' stays readable, proportional and inside its numeric field',
      count == #value
        and undistorted
        and w <= 126.001
        and h <= 36.001
        and x1 >= 640 - 63 - 0.5
        and x2 <= 640 + 63 + 0.5
        and y1 == 650
        and y2 <= 686.001
        and near(x1, x)
        and near(y1, y)
        and near(x2 - x1, w)
        and near(y2 - y1, h)
        and near(r, 0.2)
        and near(gc, 0.4)
        and near(b, 0.6)
        and near(a, 0.8)
    )
  end
  local Sigils = require('src.ui.goetic_sigils').init()
  local historical = {
    asmoday = { 32, '732bf72097d1c6a3d1659104a7965d5f715e38e3b7fa40305983df6d259a5b29' },
    stolas = { 36, '4d6e79eb80f4bbf5c9bab862769c3ce72aa40ac3a7056c53fce9ec641d5f627b' },
    buer = { 10, 'eae7654b052dd384a78c29a03b9d44eba861b50b8bd4784358cef784ac6c4231' },
  }
  -- These historical source images are intentionally immutable. Verify identity
  -- as well as the actual GPU result: a generic seal must never replace a name.
  local sentinel = love.graphics.newShader(
    'vec4 effect(vec4 c, Image t, vec2 uv, vec2 p) { return Texel(t,uv)*c; }'
  )
  for _, name in ipairs({ 'asmoday', 'stolas', 'buer' }) do
    local entry = Sigils.entries[name]
    local path = 'assets/art/sigils/' .. entry.file
    local bytes = assert(love.filesystem.read(path))
    local digest = love.data.encode('string', 'hex', love.data.hash('sha256', bytes))
    source = love.image.newImageData(path)
    local image = Sigils.image(name)
    local w, h = source:getDimensions()
    local textureMatches, compared = matchTexture(image, source)
    check(
      name
        .. ' uses its own unaltered historical seal and correct Goetia number [number='
        .. entry.number
        .. ', hash='
        .. digest
        .. ', texture='
        .. tostring(textureMatches)
        .. ', samples='
        .. compared
        .. ']',
      entry.number == historical[name][1]
        and digest == historical[name][2]
        and image == Sigils.image(name:upper())
        and image:getFilter() == 'nearest'
        and textureMatches
    )
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setDepthMode()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode('replace', 'premultiplied')
    love.graphics.setShader(sentinel)
    love.graphics.setColor(0.2, 0.4, 0.6, 0.8)
    local drawn = Sigils.draw(name, 0, 0, w, { 0.8, 0.3, 0.1, 0.7 }, 0.5)
    local r, gc, b, a = love.graphics.getColor()
    local restored = love.graphics.getShader() == sentinel
      and near(r, 0.2)
      and near(gc, 0.4)
      and near(b, 0.6)
      and near(a, 0.8)
    love.graphics.pop()
    local rendered = canvas:newImageData()
    local correct, white, ink = true, 0, 0
    for y = 0, h - 1, 7 do
      for x = 0, w - 1, 7 do
        local sr, sg, sb, sa = source:getPixel(x, y)
        local expected = (1 - math.min(sr, sg, sb)) * sa * 0.35
        local rr, rg, rb, ra = rendered:getPixel(x, y)
        correct = correct and near(ra, expected, 0.009)
        if expected < 0.001 then
          white = white + 1
          correct = correct and ra < 0.009
        end
        if expected > 0.25 then
          ink = ink + 1
          correct = correct
            and near(rr, 0.8, 0.009)
            and near(rg, 0.3, 0.009)
            and near(rb, 0.1, 0.009)
        end
      end
    end
    check(
      name .. ' removes scanned paper while preserving and tinting the original ink',
      drawn and correct and white > 100 and ink > 5
    )
    check(name .. ' draw restores the caller shader and color', restored)
    rendered:release()
    canvas:release()
    source:release()
  end
  sentinel:release()
  check(
    'unknown or empty seal names never fall back to another demon',
    Sigils.image('unknown') == nil
      and Sigils.image(nil) == nil
      and Sigils.draw('unknown', 0, 0, 80) == false
      and Sigils.draw('buer', 0, 0, 0) == false
  )
  -- Physical floor/altar seals are verified against the actual source PNGs.
  for _, line in ipairs(require('tests.cases.ritual_art').run(G, renderer)) do
    lines[#lines + 1] = line
  end
  local Plates = require('src.ui.occult_plates').init()
  source = love.image.newImageData(Plates.path)
  local plateHash = love.data.encode(
    'string',
    'hex',
    love.data.hash('sha256', assert(love.filesystem.read(Plates.path)))
  )
  check(
    'Clavicula plate uses the unchanged historical PNG and active sharp texture',
    plateHash == '3beaf2cfd99aab9fb4af86b136fac8c480ee77d847de3d9129ac1a185a02e0f2'
      and Plates.image:getFilter() == 'nearest'
      and matchTexture(Plates.image, source)
  )
  -- Approved regions of the immutable source plate include the planetary sign
  -- above each circle, and exclude captions and the separate figures 6–10.
  local regions = { { 291, 34, 289, 324 }, { 7, 433, 288, 322 }, { 291, 433, 289, 323 } }
  local intact = true
  local signatures = {}
  for i, name in ipairs({ 'saturn_1', 'saturn_2', 'saturn_3' }) do
    local entry = Plates.entries[name]
    local x0, y0, w, h = entry.q:getViewport()
    local ref = regions[i]
    local sample = stats(source, rectOf(entry.q, source))
    intact = intact
      and entry.figure == 10 + i
      and x0 >= ref[1]
      and y0 >= ref[2]
      and x0 + w <= ref[1] + ref[3]
      and y0 + h <= ref[2] + ref[4]
      and not signatures[sample.signature]
    signatures[sample.signature] = true
    for y = ref[2], ref[2] + ref[4] - 1 do
      for x = ref[1], ref[1] + ref[3] - 1 do
        local r, gc, b, a = source:getPixel(x, y)
        if (1 - math.min(r, gc, b)) * a > 0.55 then
          intact = intact and x >= x0 and x < x0 + w and y >= y0 and y < y0 + h
        end
      end
    end
    local canvas = love.graphics.newCanvas(w + 16, h + 16)
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setDepthMode()
    love.graphics.setShader()
    love.graphics.setBlendMode('replace', 'premultiplied')
    love.graphics.clear(0, 0, 0, 0)
    Plates.draw(name, 8, 8, w, h, { 0.8, 0.6, 0.3 })
    love.graphics.pop()
    local pixels = canvas:newImageData()
    local error, mirrorError, n = 0, 0, 0
    for y = 0, h - 1, 3 do
      for x = 0, w - 1, 3 do
        local r, gc, b, a = source:getPixel(x0 + x, y0 + y)
        local expected = (1 - math.min(r, gc, b)) * a
        local mr, mg, mb, ma = source:getPixel(x0 + w - 1 - x, y0 + y)
        local _, _, _, actual = pixels:getPixel(x + 8, y + 8)
        error = error + math.abs(actual - expected)
        mirrorError = mirrorError + math.abs(actual - (1 - math.min(mr, mg, mb)) * ma)
        n = n + 1
      end
    end
    check(
      string.format(
        '%s archive GPU drawing preserves original ink orientation [error %.4f, mirrored %.4f]',
        name,
        error / n,
        mirrorError / n
      ),
      error / n < 0.009 and mirrorError / n > error / n + 0.01
    )
    pixels:release()
    canvas:release()
  end
  check(
    'three distinct Clavicula figure crops retain complete circles and markers without neighboring figures or captions',
    intact
  )
  source:release()
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests
