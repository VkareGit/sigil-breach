-- Offline provenance of every baked silhouette. This module is used only by
-- the baker and QA: gameplay reads immutable masks, never PNG bytes/hashes.
-- A different PNG at the same path/size, a subpixel rectangle edit, a filter
-- change or changed classifier requires a rebake. SHA-256 covers raw source
-- bytes conservatively (even a metadata-only PNG edit requires a rebake).
local Art = require('src.content.enemy_art')
local Ability = require('src.content.ability_art')
local Sources = require('src.content.art.sources')
local Truth = require('qa.hit_truth')
local Serialize = require('src.core.serialize')
local P = {}
function P.frames()
  local out = {}
  local function add(group, id, index, region, path, linear)
    out[#out + 1] = {
      group = group,
      id = id,
      index = index,
      region = region,
      path = path,
      linear = linear,
    }
  end
  for _, id in ipairs(Art.kinds) do
    for index, region in ipairs(Art.layouts[id].frames) do
      add('layouts', id, index, region, region.sourcePath, region.filter == 'linear')
    end
  end
  for id, entry in Ability.each() do
    for index, region in ipairs(entry.frames) do
      add('abilities', id, index, region, entry.path, false)
    end
  end
  return out
end
function P.digest(bytes)
  return love.data.encode('string', 'hex', love.data.hash('sha256', bytes))
end
function P.capture(frames, read)
  read = read or love.filesystem.read
  local out = {
    layouts = {},
    abilities = {},
    images = {},
    semantics = {
      grid = Truth.grid,
      cut = Truth.cut,
      contour = Truth.contour,
      classifier = P.digest(assert(read('qa/hit_truth.lua'))),
    },
  }
  for _, f in ipairs(frames) do
    if not out.images[f.path] then
      out.images[f.path] = P.digest(assert(read(f.path)))
    end
    local size, r = assert(Sources[f.path], 'unknown source: ' .. f.path), f.region.rect
    local group = out[f.group]
    group[f.id] = group[f.id] or {}
    group[f.id][f.index] = {
      f.path,
      math.floor(r[1] * size[1] + 0.5),
      math.floor(r[2] * size[2] + 0.5),
      math.floor(r[3] * size[1] + 0.5),
      math.floor(r[4] * size[2] + 0.5),
      rect = { r[1], r[2], r[3], r[4] },
      filter = f.linear and 'linear' or 'nearest',
    }
  end
  return out
end
function P.problems(stored, current)
  local out = {}
  local function mismatch(a, b, where)
    if Serialize.encode(a) ~= Serialize.encode(b) then
      out[#out + 1] = where
    end
  end
  stored = stored or {}
  mismatch(stored.semantics, current.semantics, 'mask classification semantics')
  for path, hash in pairs(current.images) do
    mismatch(stored.images and stored.images[path], hash, 'image content: ' .. path)
  end
  for _, name in ipairs({ 'layouts', 'abilities' }) do
    for id, frames in pairs(current[name]) do
      local old = stored[name] and stored[name][id] or {}
      mismatch(#old, #frames, 'frame count: ' .. name .. ' ' .. id)
      for index, frame in ipairs(frames) do
        mismatch(old[index], frame, 'frame binding: ' .. name .. ' ' .. id .. ' ' .. index)
      end
    end
  end
  return out
end
return P
