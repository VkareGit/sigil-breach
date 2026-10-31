-- The halls of a world as GPU meshes. A hall replaces the grid's drawing of the
-- cells in its footprint; collision and routes stay the map's. Everything a
-- ruin needs is prepared with the hall, so a fall costs no mesh building and a
-- part only asks the world whether it is shown. A new kind of hall is one
-- builder here and its art catalogue.
local B = require('src.render.kit.builder')
local Catalogue = require('src.content.art.halls')
local Debris = require('src.render.kit.debris')
local Destruction = require('src.combat.destruction')
local Halls = {
  kits = {
    chapel = require('src.render.kit.chapel'),
    rooms = require('src.render.kit.rooms'),
  },
}
local exp, sin, max = math.exp, math.sin, math.max
local GRAVITY = 4.9
local ZERO = { 0, 0, 0, 1 }
local covered = setmetatable({}, { __mode = 'k' })
local function footprint(w)
  local set = covered[w]
  if not set then
    set = {}
    for _, hall in ipairs((w.decor or {}).halls or {}) do
      for _, rect in ipairs(hall.footprint) do
        for z = rect[2], rect[4] do
          set[z] = set[z] or {}
          for x = rect[1], rect[3] do
            set[z][x] = true
          end
        end
      end
    end
    covered[w] = set
  end
  return set
end
-- Is cell (x, z) drawn by a hall instead of the grid?
function Halls.covers(w, x, z)
  local row = footprint(w)[z]
  return row ~= nil and row[x] == true
end
-- One loading job per image of this world's halls not yet in the renderer.
function Halls.loadingJobs(r, w)
  local jobs, seen = {}, {}
  local function add(path, options)
    if not seen[path] and not r.resources:hasImage(path, options) then
      seen[path] = true
      jobs[#jobs + 1] = {
        label = 'loading_gallery',
        run = function()
          r.resources:image(path, options)
        end,
      }
    end
  end
  for _, hall in ipairs((w.decor or {}).halls or {}) do
    local art = Catalogue[hall.kit]
    for _, path in pairs(art.images) do
      add(path, art.imageOptions)
    end
    for _, path in pairs(art.tiles) do
      add(path, art.tileOptions)
    end
  end
  return jobs
end
-- owner: the scope of this world's geometry; art: the renderer's image scope.
function Halls.prepare(w, owner, art)
  local entries = {}
  local function mesh(vertices, path, options)
    local built = owner:own(love.graphics.newMesh(B.format, vertices, 'triangles', 'static'))
    built:setTexture(art:image(path, options))
    return built
  end
  for _, hall in ipairs((w.decor or {}).halls or {}) do
    for _, part in ipairs(Halls.kits[hall.kit].build(w, hall)) do
      entries[#entries + 1] = {
        mesh = mesh(part.vertices, part.path, part.options),
        group = part.group,
        show = part.show,
        rise = part.rise,
        sway = part.sway,
      }
    end
  end
  if #Destruction.list(w) > 0 then
    local chapel = Catalogue.chapel
    entries.debris = mesh(Debris.vertices(), chapel.tiles.rubble, chapel.tileOptions)
  end
  return entries
end
-- Is a part shown, and how far below its place: stage and seconds since the fall.
local function placed(entry, stage, t)
  local show = entry.show
  if show == 'whole' then
    return stage == 0, 0
  elseif show == 'flame' then
    return stage < 2, 0
  elseif show == 'hanging' then
    return stage == 2, 0
  elseif show == 'cracked' then
    return stage == 1 or (stage == 2 and t < 1.1), stage == 2 and GRAVITY * t * t * 0.7 or 0
  elseif show == 'gone' then
    return stage < 2 or t < 0.22, 0
  elseif show == 'fall' then
    return stage < 2 or t < 0.8, stage == 2 and GRAVITY * t * t or 0
  end
  -- after
  if stage ~= 2 then
    return false, 0
  end
  return true, entry.rise and entry.rise * max(0, 1 - t / 1.4) or 0
end
function Halls.draw(r, g, entries)
  if not entries or #entries == 0 then
    return
  end
  local s, world, elapsed = r.shader, g.world, g.elapsed or 0
  s:send('painted', 1)
  for _, entry in ipairs(entries) do
    if entry.group then
      local stage, at = Destruction.stage(world, entry.group)
      local shown, drop = placed(entry, stage, at and elapsed - at or 0)
      if shown then
        local struck = entry.sway and g.view.sway and g.view.sway[entry.group]
        local t = struck and elapsed - struck or 9
        if t < 7 then
          local push = 0.5 * exp(-1.1 * t) * sin(t * 3.4)
          s:send('sway', { push, push * 0.4, entry.sway[1], entry.sway[2] })
        end
        r:object(entry.mesh, 0, -drop, 0)
        if t < 7 then
          s:send('sway', ZERO)
        end
      end
    else
      r:object(entry.mesh)
    end
  end
  if entries.debris then
    Debris.draw(r, g, entries.debris)
  end
  s:send('painted', 0)
end
return Halls
