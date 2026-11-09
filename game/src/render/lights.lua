local Context = require('src.session.context')
-- The map's lights in the world shader's slots. A map may have any number
-- of lights (braziers, seals, the Ember); capacity slots hold the ones
-- nearest the camera that can reach what it sees (plan v10 V3). A light
-- keeps its slot while it stays chosen, so lamps never pop or swap as the
-- camera moves; one leaving the choice fades out over fade m before the one
-- taking its place. A choice that leaves lights out is reported (report),
-- never silent. Two more slots carry the nearest projectiles.
local Queries = require('src.session.queries')
local Ground = require('src.physics.ground')
local Visibility = require('src.render.light_visibility')
local Resources = require('src.render.resources')
local Pools = require('src.session.world')
local Grid = require('src.physics.grid')
local LightLook = require('src.content.art.light_look')
-- The world shader has 16 light slots; the last two carry projectiles.
local L = { budget = 16, capacity = Visibility.capacity, fade = 2 } -- constant: the shader's slots
local PROJECTILE_SLOT = L.budget - 2
-- A light reaches reach m (the shader's falloff: 1 - d^2 / 72).
local REACH2 = 72 -- constant: the shader's falloff
L.reach = math.sqrt(REACH2)
function L.new()
  local l = setmetatable({
    positions = {},
    colors = {},
    tiles = {},
    origins = {},
    sources = {},
    slots = {},
    report = { sources = 0, wanted = 0, lit = 0, left = 0, frames = 0, most = 0 },
  }, { __index = L })
  for i = 1, L.budget do
    l.positions[i] = { 0, 0, 0 }
    l.colors[i] = { 0, 0, 0 }
    l.tiles[i] = { -1, -1 }
    l.origins[i] = { 0.5, 0.5 }
  end
  return l
end
local function occupy(self, i, s)
  local pos, tile, origin = self.positions[i], self.tiles[i], self.origins[i]
  self.slots[i] = s
  if s then
    pos[1], pos[2], pos[3] = s.x, s.y, s.z
    tile[1], tile[2] = ((i - 1) % 4) / 4, math.floor((i - 1) / 4) / 4
    origin[1], origin[2] = Visibility.frame(self.world, s.x, s.z)
  else
    tile[1], tile[2] = -1, -1
  end
end
-- The ground image (contact shade and walls) and how a world point maps
-- into it; a map that fits the window reads the first tile of the atlas.
-- The image, the world span it covers on each axis, the scale into it and
-- the lowest and highest texel centres (u, v) a lookup may reach.
local function ground(w, v)
  if Visibility.whole(w) then
    local span, n = Grid.span(w), Visibility.resolution * Visibility.columns
    local low, high = 0.5 / n, (Visibility.resolution - 0.5) / n
    return {
      image = v.image,
      span = { span, span },
      scale = 1 / Visibility.columns,
      low = { low, low },
      high = { high, high },
    }
  end
  local width, depth = v.ground:getDimensions()
  return {
    image = v.ground,
    span = { Grid.width(w), Grid.depth(w) },
    scale = 1,
    low = { 0.5 / width, 0.5 / depth },
    high = { (width - 0.5) / width, (depth - 0.5) / depth },
  }
end
-- The decks of the world as an image (plan v10 V3): per cell the underside
-- (r) and top (g) of its lowest deck as shares of the highest top; one
-- empty texel for a world without decks.
local function decks(w, owner)
  local width, depth = w.decks and Grid.width(w) or 1, w.decks and Grid.depth(w) or 1
  local data = love.image.newImageData(width, depth)
  local highest = 0
  for z = 1, w.decks and depth or 0 do
    for x = 1, width do
      local list = Ground.decks(w, x, z)
      if list then
        highest = math.max(highest, list[#list][2])
      end
    end
  end
  for z = 1, w.decks and depth or 0 do
    for x = 1, width do
      local list = Ground.decks(w, x, z)
      if list then
        data:setPixel(x - 1, z - 1, list[1][1] / highest, list[1][2] / highest, 0, 1)
      end
    end
  end
  local image = owner:own(love.graphics.newImage(data))
  image:setFilter('nearest', 'nearest')
  data:release()
  return {
    image = image,
    span = { width, depth },
    height = math.max(highest, 1),
    datum = w.floor or 0,
  }
end
function L:prepare(w, checkpoint)
  if self.world == w and self.revision == (w.viewRevision or w.geometryRevision) then
    return
  end
  local sources = {}
  for _, lamp in ipairs(w.lamps) do
    sources[#sources + 1] = { x = lamp.x, y = lamp.y, z = lamp.z, lamp = lamp }
  end
  for _, seal in ipairs(w.seals) do
    sources[#sources + 1] = { x = seal.x, y = Ground.of(w, seal) + 2, z = seal.z, seal = seal }
  end
  if w.ember then
    sources[#sources + 1] = {
      x = w.ember.x,
      y = Ground.height(w, w.ember.x, w.ember.z) + LightLook.emberHeight,
      z = w.ember.z,
      shrine = true,
    }
  end
  -- The first sources take the slots in order (all of them, when they fit).
  local first = {}
  for i = 1, math.min(#sources, L.capacity) do
    first[i] = sources[i]
  end
  local previous = self.resources
  local resources = Resources.new('world light visibility')
  local visibility = Visibility.build(w, first, resources, #sources > L.capacity, checkpoint)
  if checkpoint and #sources > L.capacity then
    -- Bound preparation even for authoring maps with hundreds of lamps.
    for i = 1, math.min(#sources, Visibility.cacheCapacity) do
      Visibility.prime(visibility, sources[i])
      checkpoint('light tile ' .. i)
    end
  end
  local preparedGround, preparedDecks = ground(w, visibility), decks(w, resources)
  -- Commit only a complete replacement. Failed native allocation leaves the
  -- previous world's atlas usable and this revision eligible for a retry.
  self.world, self.revision, self.sources = w, w.viewRevision or w.geometryRevision, sources
  self.visibility = visibility
  self.resources = resources
  self.ground, self.decks = preparedGround, preparedDecks
  self.tileSpan = select(3, Visibility.frame(w, 0, 0))
  if previous then
    previous:release()
  end
  for i = 1, L.capacity do
    occupy(self, i, first[i])
  end
  for i = L.capacity + 1, L.budget do
    self.tiles[i][1], self.tiles[i][2] = -1, -1
  end
end
function L:release()
  if self.resources then
    self.resources:release()
  end
  self.resources, self.visibility, self.world, self.revision = nil, nil, nil, nil
  self.sources = {}
  self.slots = {}
end
-- Choose the lights for this frame when the map has more than the slots:
-- the nearest to the camera at (x, z) that are not wholly behind it.
-- Returns the fade of every chosen light by source (nil: all fully lit).
function L:choose(x, z, fx, fz)
  local sources, report = self.sources, self.report
  report.sources, report.lit, report.left = #sources, math.min(#sources, L.capacity), 0
  report.wanted = #sources
  if #sources <= L.capacity then
    return nil
  end
  -- The capacity + 1 nearest (the last one sets where the fading starts).
  local near, distance = {}, {}
  local wanted = 0
  for _, s in ipairs(sources) do
    local dx, dz = s.x - x, s.z - z
    if dx * fx + dz * fz > -L.reach or dx * dx + dz * dz < L.reach * L.reach then
      wanted = wanted + 1
      local d = math.sqrt(dx * dx + dz * dz)
      local k = #near + 1
      if k > L.capacity + 1 then
        k = L.capacity + 1
        if d >= distance[k] then
          k = nil
        end
      end
      if k then
        while k > 1 and distance[k - 1] > d do
          near[k], distance[k] = near[k - 1], distance[k - 1]
          k = k - 1
        end
        near[k], distance[k] = s, d
      end
    end
  end
  local cut = distance[L.capacity + 1] or math.huge
  local chosen = {}
  for i = 1, math.min(#near, L.capacity) do
    chosen[near[i]] = math.max(0, math.min(1, (cut - distance[i]) / L.fade))
  end
  -- Lights that stay keep their slots; the newly chosen take the free ones.
  for i = 1, L.capacity do
    if self.slots[i] and chosen[self.slots[i]] == nil then
      occupy(self, i, nil)
    end
  end
  local free = 1
  for i = 1, math.min(#near, L.capacity) do
    local s = near[i]
    local placed = false
    for j = 1, L.capacity do
      placed = placed or self.slots[j] == s
    end
    if not placed then
      while self.slots[free] do
        free = free + 1
      end
      Visibility.place(self.visibility, free, s)
      occupy(self, free, s)
    end
  end
  report.wanted, report.lit = wanted, math.min(#near, L.capacity)
  report.left = math.max(0, wanted - L.capacity)
  if report.left > 0 then
    report.frames = report.frames + 1
    report.most = math.max(report.most, report.left)
  end
  return chosen
end
-- camera, forward (optional): the view's eye and direction; by default the
-- context viewer's place.
function L:update(g, camera, forward)
  self:prepare(g.world)
  local view = Queries.world(g)
  local cx, cz =
    camera and camera[1] or Context.viewer(g).x, camera and camera[3] or Context.viewer(g).z
  local fade = self:choose(cx, cz, forward and forward[1] or 0, forward and forward[3] or 0)
  for i = 1, L.budget do
    local c = self.colors[i]
    c[1], c[2], c[3] = 0, 0, 0
  end
  for i = 1, L.capacity do
    local s, c = self.slots[i], self.colors[i]
    if s and s.lamp then
      local lamp, look = s.lamp, LightLook.lamp
      local t = g.time + lamp.phase * look.phase
      local f = 1
        + math.sin(t * look.rate) * look.depth
        + math.sin(t * look.rate2 + look.offset2) * look.depth2
      local color = lamp.color or look.color
      c[1], c[2], c[3] = color[1] * f, color[2] * f, color[3] * f
    elseif s and s.seal then
      local look = LightLook.seal
      local f = s.seal.active and look.active or look.waiting
      for k = 1, 3 do
        c[k] = (look.base + s.seal.color[k] * look.own) * f
      end
    elseif s and view.shrine then
      local look = LightLook.shrine
      local f = view.shrineActive and look.lit or look.resting
      c[1], c[2], c[3] = look.color[1] * f, look.color[2] * f, look.color[3] * f
    end
    if s and fade then
      local k = fade[s] or 0
      c[1], c[2], c[3] = c[1] * k, c[2] * k, c[3] * k
    end
  end
  -- Two short-radius projectile lights. Muzzle flash is a separate camera light.
  local P = LightLook.projectile
  local best, second, bestD, secondD = nil, nil, P.reach2, P.reach2
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    local d = (b.x - Context.viewer(g).x) ^ 2 + (b.z - Context.viewer(g).z) ^ 2
    if d < bestD then
      second, secondD, best, bestD = best, bestD, b, d
    elseif d < secondD then
      second, secondD = b, d
    end
  end
  for j = 1, 2 do
    local b = j == 1 and best or second
    local c, p = self.colors[PROJECTILE_SLOT + j], self.positions[PROJECTILE_SLOT + j]
    if b then
      local color = b.color or P.color
      p[1], p[2], p[3] = b.x, b.y, b.z
      c[1], c[2], c[3] = color[1] * P.share, color[2] * P.share, color[3] * P.share
    end
  end
end
function L:bind(shader)
  local look = self.world.decor and self.world.decor.atmosphere
  shader:send('ambientLight', look and look.ambient or LightLook.ambient)
  shader:send('lights', unpack(self.positions))
  shader:send('lightColors', unpack(self.colors))
  shader:send('shadowTiles', unpack(self.tiles))
  shader:send('lightOrigins', unpack(self.origins))
  shader:send('shadowAtlas', self.visibility.image)
  shader:send('tileSpan', self.tileSpan)
  local floor = self.ground
  shader:send('groundAtlas', floor.image)
  shader:send('groundSpan', floor.span)
  shader:send('groundScale', floor.scale)
  shader:send('groundLow', floor.low)
  shader:send('groundHigh', floor.high)
  local deck = self.decks
  shader:send('deckAtlas', deck.image)
  shader:send('deckSpan', deck.span)
  shader:send('deckHeight', deck.height)
  shader:send('deckDatum', deck.datum)
end
function L:send(shader, g, camera, forward)
  self:update(g, camera, forward)
  self:bind(shader)
end
-- The light at a world point from the lights in the slots.
function L:sample(x, y, z)
  local r, g, b = unpack(LightLook.figures)
  local S = LightLook.sample
  local look = self.world and self.world.decor and self.world.decor.atmosphere
  if look then
    r, g, b = unpack(look.figures)
  end
  local lx, lz = 0, 0
  local dominant, strongest = 0, 0
  for i = 1, L.capacity do
    local s = self.slots[i]
    if s then
      local dx, dy, dz = s.x - x, s.y - y, s.z - z
      local d2 = dx * dx + dy * dy + dz * dz
      if d2 < REACH2 and Visibility.visible(self.world, s.x, s.z, x, z) then
        local c = self.colors[i]
        local f = S.share * (1 - d2 / REACH2) / (1 + d2 * S.falloff)
        r, g, b = r + c[1] * f, g + c[2] * f, b + c[3] * f
        local weight = f * (c[1] + c[2] + c[3]) / 3
        local d = math.sqrt(dx * dx + dz * dz) + 1e-6
        lx, lz = lx + dx / d * weight, lz + dz / d * weight
        if weight > strongest then
          dominant, strongest = i, weight
        end
      end
    end
  end
  local most = S.brightest
  return math.min(most[1], r),
    math.min(most[2], g),
    math.min(most[3], b),
    lx,
    lz,
    dominant,
    strongest
end
return L
