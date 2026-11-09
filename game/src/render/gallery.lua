local Weapons = require('src.content.weapons')
local RenderNumbers = require('src.render.numbers')
local Ink = require('src.ui.ink')
local Context = require('src.session.context')
-- The proving-ground pads drawn, and their name plates. Where they stand and what
-- they do is world/gallery.lua.
local Arena = require('src.world.arena')
local WorldGallery = require('src.world.gallery')
local Archetypes = require('src.content.enemies')
local Ritual = require('src.render.ritual_art')
local Skin = require('src.ui.skin')
local Queries = require('src.session.queries')
local Text = require('src.content.text')
local GalleryLook = require('src.content.art.gallery_look')
local G = {}
local function dist(a, x, z)
  return math.sqrt((a.x - x) ^ 2 + (a.z - z) ^ 2)
end
function G.draw(r, g)
  local tools = Queries.tools(g)
  if not (tools and tools.gallery) then
    return
  end
  -- Painted, fixed floor medallions.
  for _, p in ipairs(WorldGallery.padsFor(g.world)) do
    if not p.altar then
      Ritual.pad(r, p, g.world.floor)
    end
  end
end
-- Bounds use painted ink, rather than the advance width of a font. A plate
-- near a screen edge is hidden whole: cropping a label changes its meaning.
function G.labelBox(font, text, sx, sy, ox, oy, vw, vh, box)
  local ink = font:getInk(text)
  local L = GalleryLook
  local unit = vh / L.referenceHeight
  local margin = math.max(L.margin.least, L.margin.unit * unit)
  local padX, padY = L.pad.x, L.pad.y
  local w, h = ink.w + padX * 2, ink.h + padY * 2
  local x, y = math.floor(sx - w * 0.5), math.floor(sy - h * 0.5)
  -- Leave the actual proving-ground header and bottom context strip clear.
  if
    x < ox + margin
    or x + w > ox + vw - margin
    or y < oy + L.header * unit
    or y + h > oy + vh - L.footer * unit
  then
    return
  end
  local half = L.aimHalf * unit
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
  local tools = Queries.tools(g)
  if not (tools and tools.gallery) or g.state ~= 'playing' or g.map or g.help then
    return
  end
  local font = Skin.font(GalleryLook.font)
  if not font then
    return
  end
  local lg = love.graphics
  local state = r.galleryLabelLayout
  local stationLabels = tools.labels
  if not state or state.world ~= g.world or state.labels ~= stationLabels then
    state = { world = g.world, labels = stationLabels, items = {}, taken = {}, boxes = {} }
    r.galleryLabelLayout = state
    for _, p in ipairs(WorldGallery.padsFor(g.world)) do
      local name = Text.get(
        p.spawn and Archetypes.get(p.spawn).name
          or (p.weapon and Weapons.get(p.weapon).name or 'gallery_refill')
      )
      state.items[#state.items + 1] = {
        x = p.x,
        y = p.altar and p.y - GalleryLook.altarDrop or GalleryLook.floorHeight,
        focusY = p.altar and p.y + GalleryLook.altarFocus or GalleryLook.floorFocus,
        z = p.z,
        text = name:upper(),
        reach = p.altar and GalleryLook.altarReach or GalleryLook.floorReach,
        kind = 'pad',
      }
    end
    -- Station captions (range distances, physics drills) from the proving ground.
    for _, l in ipairs(stationLabels or {}) do
      state.items[#state.items + 1] =
        { x = l.x, y = l.y, z = l.z, text = l.text, reach = GalleryLook.stationReach }
    end
  end
  local items, taken = state.items, state.taken
  for i = #taken, 1, -1 do
    taken[i] = nil
  end
  local p = Context.viewer(g)
  local overlap = RenderNumbers.overlap
  -- Only one nearby pad gets a caption. Station
  -- rulers retain their separate distance labels for actual measurement drills.
  local focused, scores = {}, {}
  for _, it in ipairs(items) do
    it.d = dist(p, it.x, it.z)
    if
      it.kind
      and it.d < (it.reach or GalleryLook.defaultReach)
      and Arena.visible(g.world, p.x, p.z, it.x, it.z)
    then
      local x, y = r:project(it.x, it.focusY, it.z)
      if x then
        local dx, dy = x / r.w - 0.5, y / r.h - 0.5
        local score = dx * dx + dy * dy + it.d * it.d * GalleryLook.distanceWeight
        if
          math.abs(dx) < GalleryLook.across
          and math.abs(dy) < GalleryLook.up
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
  lg.setShader(Ink.ink(false))
  for _, it in ipairs(items) do
    local d = it.d
    if
      (not it.kind or focused[it.kind] == it)
      and d < (it.reach or GalleryLook.defaultReach)
      and Arena.visible(g.world, p.x, p.z, it.x, it.z)
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
          lg.setShader(Ink.ink(true))
          font:draw(it.text, box.textX, box.textY, GalleryLook.ink)
        end
      end
    end
  end
  lg.pop()
end
return G
