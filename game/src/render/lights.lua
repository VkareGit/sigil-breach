-- Stable world-light identities prevent lamps popping as the camera moves.
local Queries = require('src.run.queries')
local Ground = require('src.physics.ground')
local Visibility = require('src.render.light_visibility')
local Resources = require('src.render.resources')
local Pools = require('src.session.world')
local Grid = require('src.physics.grid')
local L = { budget = 16 }
function L.new()
  local l = setmetatable({ positions = {}, colors = {}, tiles = {}, sources = {} }, { __index = L })
  for i = 1, L.budget do
    l.positions[i] = { 0, 0, 0 }
    l.colors[i] = { 0, 0, 0 }
    l.tiles[i] = { -1, -1 }
  end
  return l
end
function L:prepare(w)
  if self.world == w and self.revision == w.geometryRevision then
    return
  end
  local sources = {}
  for _, lamp in ipairs(w.lamps) do
    if #sources < L.budget - 2 then
      sources[#sources + 1] = { x = lamp.x, y = lamp.y, z = lamp.z, lamp = lamp }
    end
  end
  for _, seal in ipairs(w.seals) do
    if #sources < L.budget - 2 then
      sources[#sources + 1] =
        { x = seal.x, y = Ground.height(w, seal.x, seal.z) + 2, z = seal.z, seal = seal }
    end
  end
  if w.ember and #sources < L.budget - 2 then
    sources[#sources + 1] = {
      x = w.ember.x,
      y = Ground.height(w, w.ember.x, w.ember.z) + 1.55,
      z = w.ember.z,
      shrine = true,
    }
  end
  local previous = self.resources
  local resources = Resources.new('world light visibility')
  local visibility = Visibility.build(w, sources, resources)
  -- Commit only a complete replacement. Failed native allocation leaves the
  -- previous world's atlas usable and this revision eligible for a retry.
  self.world, self.revision, self.sources = w, w.geometryRevision, sources
  self.visibility = visibility
  self.resources = resources
  if previous then
    previous:release()
  end
  for i = 1, L.budget do
    local s = self.sources[i]
    local pos, tile = self.positions[i], self.tiles[i]
    if s then
      pos[1], pos[2], pos[3] = s.x, s.y, s.z
      tile[1], tile[2] = ((i - 1) % 4) * 0.25, math.floor((i - 1) / 4) * 0.25
    else
      tile[1], tile[2] = -1, -1
    end
  end
end
function L:release()
  if self.resources then
    self.resources:release()
  end
  self.resources, self.visibility, self.world, self.revision = nil, nil, nil, nil
  self.sources = {}
end
function L:update(g)
  self:prepare(g.world)
  local view = Queries.world(g)
  for i = 1, L.budget do
    local c = self.colors[i]
    c[1], c[2], c[3] = 0, 0, 0
  end
  for i, s in ipairs(self.sources) do
    local c = self.colors[i]
    if s.lamp then
      local lamp = s.lamp
      local t = g.time + lamp.phase * 1.7
      local f = 1 + math.sin(t * 1.3) * 0.045 + math.sin(t * 2.3 + 1.1) * 0.025
      c[1], c[2], c[3] =
        (lamp.color and lamp.color[1] or 1.65) * f,
        (lamp.color and lamp.color[2] or 1.02) * f,
        (lamp.color and lamp.color[3] or 0.57) * f
    elseif s.seal then
      local f = s.seal.active and 0.18 or 0.52
      for k = 1, 3 do
        c[k] = (0.38 + s.seal.color[k] * 0.45) * f
      end
    elseif view.shrine then
      local f = view.shrineActive and 1.1 or 0.25
      c[1], c[2], c[3] = 0.72 * f, 1.02 * f, 0.82 * f
    end
  end
  -- Two short-radius projectile lights. Muzzle flash is a separate camera light.
  local best, second, bestD, secondD = nil, nil, 36, 36
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    local d = (b.x - g.player.x) ^ 2 + (b.z - g.player.z) ^ 2
    if d < bestD then
      second, secondD, best, bestD = best, bestD, b, d
    elseif d < secondD then
      second, secondD = b, d
    end
  end
  for j = 1, 2 do
    local b = j == 1 and best or second
    local c, p = self.colors[14 + j], self.positions[14 + j]
    if b then
      local color = b.color or { 1, 0.4, 0.1 }
      p[1], p[2], p[3] = b.x, b.y, b.z
      c[1], c[2], c[3] = color[1] * 0.75, color[2] * 0.75, color[3] * 0.75
    end
  end
end
function L:bind(shader)
  shader:send('lights', unpack(self.positions))
  shader:send('lightColors', unpack(self.colors))
  shader:send('shadowTiles', unpack(self.tiles))
  shader:send('shadowAtlas', self.visibility.image)
  shader:send('worldSize', Grid.span(self.world))
end
function L:send(shader, g)
  self:update(g)
  self:bind(shader)
end
function L:sample(x, y, z)
  local r, g, b = 0.51, 0.53, 0.57
  local lx, lz = 0, 0
  local dominant, strongest = 0, 0
  for i, s in ipairs(self.sources) do
    local dx, dy, dz = s.x - x, s.y - y, s.z - z
    local d2 = dx * dx + dy * dy + dz * dz
    if d2 < 72 and Visibility.visible(self.world, s.x, s.z, x, z) then
      local c = self.colors[i]
      local f = 0.40 * (1 - d2 / 72) / (1 + d2 * 0.22)
      r, g, b = r + c[1] * f, g + c[2] * f, b + c[3] * f
      local weight = f * (c[1] + c[2] + c[3]) / 3
      local d = math.sqrt(dx * dx + dz * dz) + 1e-6
      lx, lz = lx + dx / d * weight, lz + dz / d * weight
      if weight > strongest then
        dominant, strongest = i, weight
      end
    end
  end
  return math.min(1.08, r), math.min(1.06, g), math.min(1.02, b), lx, lz, dominant, strongest
end
return L
