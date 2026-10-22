-- The proving-ground gallery drawn: the active art boards (by hall), the
-- statues, the pads and their name plates. The layout (halls, statues,
-- pads, interaction) is world/gallery.lua.
local W = require('src.world.arena')
local WG = require('src.world.gallery')
local Archetypes = require('src.content.enemies')
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
  -- Pads: floor rings and a slow sigil, coloured by what they give.
  lg.setShader(r.shader)
  for _, p in ipairs(WG.pads) do
    local near = dist(g.player, p.x, p.z) < 1.05
    local color = p.spawn and { 0.85, 0.32, 0.18 }
      or (p.weapon and { 0.86, 0.66, 0.30 } or { 0.45, 0.80, 0.62 })
    r:object(r.warning, p.x, 0.03, p.z, 0, near and 1.0 or 0.85, color)
    r:object(r.warning, p.x, 0.035, p.z, 0, near and 0.62 or 0.5, color)
    r:object(
      r.sigil,
      p.x,
      0.75 + math.sin(time * 2 + p.x) * 0.06,
      p.z,
      time * 0.8,
      near and 0.5 or 0.4,
      color
    )
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
    e.kind, e.armored, e.x, e.z, e.id = s.kind, s.armored, s.x, s.z, 900 + i
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
      state.items[#state.items + 1] =
        { x = b.x, y = 2.62, z = b.z, text = b.group .. ' / ' .. b.name }
    end
    for _, s in ipairs(WG.statues) do
      local a = Archetypes.get(s.kind, s.armored and 'armored' or nil)
      local tall = a.appearance.stature == 'large' and 4.1 or 2.7
      state.items[#state.items + 1] = {
        x = s.x,
        y = tall,
        z = s.z,
        text = a.name
          .. ' / HP '
          .. a.body.hp
          .. (a.body.armor > 0 and (' / ARMOUR ' .. a.body.armor) or ''),
      }
    end
    for _, p in ipairs(WG.pads) do
      state.items[#state.items + 1] = { x = p.x, y = 1.05, z = p.z, text = WG.padLabel(p) }
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
  -- Nearest first; a plate that would overlap a nearer one is skipped.
  for _, it in ipairs(items) do
    it.d = dist(p, it.x, it.z)
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
    if d < (it.reach or 8) and W.visible(g.world, p.x, p.z, it.x, it.z) then
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
          local alpha = math.min(1, ((it.reach or 8) - d) / 2)
          lg.setShader()
          lg.setColor(0.04, 0.03, 0.025, 0.78 * alpha)
          lg.rectangle('fill', box[1], box[2], box[3], box[4])
          lg.setShader(require('src.ui.ink').ink(false))
          font:draw(it.text, box.textX, box.textY, { 0.93, 0.87, 0.72, alpha })
        end
      end
    end
  end
  lg.pop()
end
return G
