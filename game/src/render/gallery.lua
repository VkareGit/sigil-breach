-- The proving-ground gallery drawn: the active art boards (by hall), the
-- statues, the pads and their name plates. The layout (halls, statues,
-- pads, interaction) is world/gallery.lua.
local W = require('src.world.arena')
local WG = require('src.world.gallery')
local Archetypes = require('src.content.enemies')
local Ritual = require('src.render.ritual_art')
local Skin = require('src.ui.skin')
local G = {}
local function dist(a, x, z)
  return math.sqrt((a.x - x) ^ 2 + (a.z - z) ^ 2)
end
-- Active art, by hall. get(r) reuses an image the game already holds.
G.boards = {
  {
    group = 'WORLD',
    name = 'Walls and floor',
    path = 'assets/art/textures-fresco-v12.png',
    get = function(r)
      return r.textures
    end,
  },
  {
    group = 'WORLD',
    name = 'Horizon',
    path = 'assets/art/horizon-fresco-v12.png',
    get = function(r)
      return r.horizon
    end,
  },
  {
    group = 'WORLD',
    name = 'Wall frescoes',
    path = 'assets/art/murals-fresco-v12.png',
    get = function(r)
      return r.frescoes
    end,
  },
  {
    group = 'WORLD',
    name = 'Props and braziers',
    path = 'assets/art/props-fresco-v12.png',
    get = function(r)
      return r.props
    end,
  },
  {
    group = 'WORLD',
    name = 'Ember shrine',
    path = 'assets/art/shrine-fresco-v12.png',
    get = function(r)
      return r.shrineImage
    end,
  },
  {
    group = 'WEAPONS',
    name = 'Exorcist shotgun',
    path = require('src.render.weapon_art').exorcist.path,
  },
  {
    group = 'WEAPONS',
    name = 'Judge revolver',
    path = require('src.render.weapon_art').judge.path,
  },
  { group = 'WEAPONS', name = 'Muzzle flash', path = 'assets/art/muzzle-fresco-v12.png' },
  { group = 'WEAPONS', name = 'Powder charge', path = 'assets/art/charge-fresco-v12.png' },
  {
    group = 'EFFECTS',
    name = 'Blood, smoke, sparks',
    path = 'assets/art/effects-fresco-v12.png',
    get = function(r)
      return r.effects
    end,
  },
  {
    group = 'EFFECTS',
    name = 'Demon spells',
    path = 'assets/art/spells-fresco-v12.png',
    get = function(r)
      return r.spells
    end,
  },
  { group = 'INTERFACE', name = 'Reliquary HUD', path = require('src.ui.reliquary').path },
  { group = 'INTERFACE', name = 'Icons and panels', path = 'assets/art/ui-fresco-v12.png' },
  { group = 'INTERFACE', name = 'Inscriptions', path = 'assets/art/lettering-en-v16.png' },
  { group = 'INTERFACE', name = 'Painted numerals', path = 'assets/art/numerals-v16.png' },
  { group = 'INTERFACE', name = 'Knight portrait', path = require('src.ui.portrait').path },
  { group = 'INTERFACE', name = 'Alphabet, capitals', path = 'assets/art/alphabet-upper-v16.png' },
  { group = 'INTERFACE', name = 'Alphabet, small', path = 'assets/art/alphabet-lower-v16.png' },
  { group = 'DEMONS', name = 'Ember Thrall atlas', path = 'assets/art/imp-fresco-v12.png' },
  { group = 'DEMONS', name = 'Iron Thrall atlas', path = 'assets/art/armored-fresco-v12.png' },
  { group = 'DEMONS', name = 'Star Acolyte atlas', path = 'assets/art/stolas-fresco-v12.png' },
  { group = 'DEMONS', name = 'Plague Gardener atlas', path = 'assets/art/buer-fresco-v12.png' },
  { group = 'DEMONS', name = 'Margrave of Ash atlas', path = 'assets/art/boss-fresco-v12.png' },
  { group = 'DEMONS', name = 'Furfur atlas', path = 'assets/art/furfur-fresco-v12.png' },
}
-- Hang the boards in their halls (world/gallery.lua).
function G.layout(world)
  return WG.layout(world, G.boards)
end
-- Rendering ---------------------------------------------------------------
local cache = {}
local function image(r, b)
  if b.get then
    local img = b.get(r)
    if img then
      return img
    end
  end
  if b.image then
    return b.image
  end
  if cache[b.path] == nil then
    local ok, img = pcall(love.graphics.newImage, b.path, { mipmaps = true })
    if ok then
      img:setFilter('linear', 'linear')
      img:setMipmapFilter('linear')
    end
    cache[b.path] = ok and img or false
  end
  return cache[b.path] or nil
end
G.image = image
-- The same cache and sampling as the gallery. Preparation is bounded to one
-- absent PNG per loading frame; already owned renderer images need no copy.
local function pending(r, b)
  return not b.image and not (b.get and b.get(r)) and cache[b.path] == nil
end
function G.pending(r)
  local count = 0
  for _, b in ipairs(G.boards) do
    if pending(r, b) then
      count = count + 1
    end
  end
  return count
end
function G.preloadStep(r)
  for _, b in ipairs(G.boards) do
    if pending(r, b) then
      assert(image(r, b), 'gallery artwork failed to load: ' .. b.path)
      return G.pending(r)
    end
  end
  return 0
end
local WHITE = { 1, 1, 1 }
local PLATE = { 0.11, 0.075, 0.055 }
local UV = { 0, 0, 1, 1 }
local function billboard(r, g, img, x, y, z, width, height, tint, alpha, toward)
  local s = r.spriteShader
  r.sprite:setTexture(img)
  -- The sprite mesh is authored mirrored (see the seal note in render_shaders):
  -- boards restore the reading orientation of the sheet.
  s:send('silhouette', 0)
  s:send('soft', 0)
  s:send('mirror', 1)
  s:send('lean', 0)
  s:send('pain', 0)
  s:send('effectAlpha', alpha or 1)
  s:send('effectTint', tint or WHITE)
  s:send('brightness', 1)
  s:send('frameRect', UV)
  s:send('spriteStretch', r:vec2(width / height, 1))
  local yaw = math.atan2(g.player.x - x, g.player.z - z)
  x, z = x - math.sin(yaw) * (toward or 0), z - math.cos(yaw) * (toward or 0)
  s:send('objectPos', r:vec3(x, y, z))
  s:send('objectYaw', yaw)
  s:send('objectScale', height)
  love.graphics.draw(r.sprite)
end
function G.draw(r, g)
  if not g.testField then
    return
  end
  local lg = love.graphics
  local time = g.time or 0
  if not G.placed or G.world ~= g.world then
    G.placed = G.layout(g.world)
    G.world = g.world
  end
  -- Painted, fixed floor medallions; no floating geometry obscures exhibits.
  for _, p in ipairs(WG.pads) do
    Ritual.pad(r, p, g.world.floor)
  end
  lg.setShader(r.spriteShader)
  -- Boards: a dark plate behind the atlas so transparent sheets stay readable.
  for _, b in ipairs(G.placed) do
    local img = image(r, b)
    if img then
      local w, h = img:getDimensions()
      local aspect = w / h
      local height = 1.15
      if aspect * height > 1.75 then
        height = 1.75 / aspect
      end
      billboard(
        r,
        g,
        r.blank,
        b.x,
        1.15 - 0.07,
        b.z,
        aspect * height + 0.14,
        height + 0.14,
        PLATE,
        0.94,
        0.035
      )
      billboard(r, g, img, b.x, 1.15, b.z, aspect * height, height, WHITE, 1, 0)
    end
  end
  r.spriteShader:send('effectTint', WHITE)
  r.spriteShader:send('effectAlpha', 1)
  r.spriteShader:send('mirror', 0)
  -- Statues: real demon sprites breathing with their idle cycle.
  local Idle = require('src.enemies.idle')
  for i, s in ipairs(WG.statues) do
    local e = s.record
      or {
        hp = 1,
        maxHp = 1,
        ai = 'idle',
        phase = 0,
        walk = 0,
        facing = 0,
        conditions = {},
        hit = 0,
        flinch = 0,
      }
    s.record = e
    e.kind, e.variant, e.x, e.z, e.id = s.kind, Archetypes.get(s.id).variant, s.x, s.z, 900 + i
    e.previewFrame = Idle.sample(Idle.kind(e), time, e.id)
    r:enemy(g, e)
  end
end
-- Bounds use painted ink, rather than the advance width of a font. A plate
-- near a screen edge is hidden whole: cropping a label changes its meaning.
function G.labelBox(font, text, sx, sy, ox, oy, vw, vh, box)
  local ink = font:getInk(text)
  local unit = vh / 600
  local margin = math.max(8, 10 * unit)
  local padX, padY = 8, 5
  local w, h = ink.w + padX * 2, ink.h + padY * 2
  local x, y = math.floor(sx - w * 0.5), math.floor(sy - h * 0.5)
  -- Leave the actual proving-ground header and bottom context strip clear.
  if
    x < ox + margin
    or x + w > ox + vw - margin
    or y < oy + 92 * unit
    or y + h > oy + vh - 64 * unit
  then
    return
  end
  local half = 25 * unit
  local cx, cy = ox + vw * 0.5, oy + vh * 0.5
  if x < cx + half and x + w > cx - half and y < cy + half and y + h > cy - half then
    return
  end
  box = box or {}
  box[1], box[2], box[3], box[4] = x, y, w, h
  box.textX, box.textY = x + padX - ink.x, y + padY - ink.y
  return box
end
-- Name plates over the nearest exhibits (screen space, after the frame).
function G.labels(r, g, ox, oy, vw, vh)
  if not g.testField or g.state ~= 'playing' or g.map or g.help or not G.placed then
    return
  end
  local ui = require('src.ui.interface')
  if not ui.fonts then
    return
  end
  local font = ui.fonts[14]
  local lg = love.graphics
  local state = r.galleryLabelLayout
  local stationLabels = g.testField.labels
  if not state or state.placed ~= G.placed or state.labels ~= stationLabels then
    state = { placed = G.placed, labels = stationLabels, items = {}, taken = {}, boxes = {} }
    r.galleryLabelLayout = state
    for _, b in ipairs(G.placed) do
      state.items[#state.items + 1] = {
        x = b.x,
        -- The plate sits below the artwork's 1.15 m base, so its caption cannot
        -- cover an atlas and stays visible when the top approaches the header.
        y = 0.95,
        focusY = 1.7,
        z = b.z,
        text = b.group .. ' / ' .. b.name,
        kind = 'exhibit',
      }
    end
    for _, s in ipairs(WG.statues) do
      local a = Archetypes.get(s.id)
      local tall = a.appearance.stature == 'large' and 4.1 or 2.7
      state.items[#state.items + 1] = {
        x = s.x,
        y = tall,
        focusY = tall * 0.5,
        z = s.z,
        kind = 'exhibit',
        text = a.name
          .. ' / HP '
          .. a.body.hp
          .. (a.body.armor > 0 and (' / ARMOUR ' .. a.body.armor) or ''),
      }
    end
    for _, p in ipairs(WG.pads) do
      local name = p.spawn and Archetypes.get(p.spawn).name
        or (
          p.weapon and require('src.content.weapons').get(p.weapon).name or 'HEALTH / WARD / AMMO'
        )
      state.items[#state.items + 1] =
        { x = p.x, y = 0.35, focusY = 0.1, z = p.z, text = name:upper(), reach = 3, kind = 'pad' }
    end
    -- Station captions (range distances, physics drills) from the proving ground.
    for _, l in ipairs(stationLabels or {}) do
      state.items[#state.items + 1] = { x = l.x, y = l.y, z = l.z, text = l.text, reach = 24 }
    end
  end
  local items, taken = state.items, state.taken
  for i = #taken, 1, -1 do
    taken[i] = nil
  end
  local p = g.player
  local overlap = require('src.render.numbers').overlap
  -- Only the exhibit under the gaze and one nearby pad get captions. Station
  -- rulers retain their separate distance labels for actual measurement drills.
  local focused, scores = {}, {}
  for _, it in ipairs(items) do
    it.d = dist(p, it.x, it.z)
    if it.kind and it.d < (it.reach or 8) and W.visible(g.world, p.x, p.z, it.x, it.z) then
      local x, y = r:project(it.x, it.focusY, it.z)
      if x then
        local dx, dy = x / r.w - 0.5, y / r.h - 0.5
        local score = dx * dx + dy * dy + it.d * it.d * 0.0006
        if
          math.abs(dx) < 0.25
          and math.abs(dy) < 0.4
          and (not scores[it.kind] or score < scores[it.kind])
        then
          scores[it.kind], focused[it.kind] = score, it
        end
      end
    end
  end
  table.sort(items, function(a, b)
    if a.d == b.d then
      return a.text < b.text
    end
    return a.d < b.d
  end)
  lg.push('all')
  lg.setScissor(ox, oy, vw, vh)
  lg.setShader(require('src.ui.ink').ink(false))
  for _, it in ipairs(items) do
    local d = it.d
    if
      (not it.kind or focused[it.kind] == it)
      and d < (it.reach or 8)
      and W.visible(g.world, p.x, p.z, it.x, it.z)
    then
      local px, py = r:project(it.x, it.y, it.z)
      if px then
        local sx, sy = ox + px * vw / r.w, oy + py * vh / r.h
        local slot = #taken + 1
        local box = G.labelBox(font, it.text, sx, sy, ox, oy, vw, vh, state.boxes[slot])
        local free = box ~= nil
        if box then
          state.boxes[slot] = box
          for _, o in ipairs(taken) do
            if overlap(box[1], box[2], box[3], box[4], o[1], o[2], o[3], o[4], 4) then
              free = false
              break
            end
          end
          -- A catalogue caption cannot conceal feedback from a live hit.
          for _, o in ipairs(r.numberLayout and r.numberLayout.items or {}) do
            if overlap(box[1], box[2], box[3], box[4], o.x, o.y, o.w, o.h, 4) then
              free = false
              break
            end
          end
        end
        if free then
          taken[#taken + 1] = box
          lg.setShader()
          Skin.panel(box[1], box[2], box[3], box[4], 7, 6)
          lg.setShader(require('src.ui.ink').ink(true))
          font:draw(it.text, box.textX, box.textY, { 0.93, 0.87, 0.72, 1 })
        end
      end
    end
  end
  lg.pop()
end
return G
