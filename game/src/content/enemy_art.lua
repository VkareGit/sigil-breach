-- Authored sprite sources and immutable frame placement, shared by simulation
-- and drawing: the catalogue entry of each atlas (its action atlas and cuts,
-- the other sources and the frames they paint, originalCount, totalFrames)
-- and its layout, both derived from its sheet (content/art/atlases.lua,
-- plan v10 V7). No image allocation or collision calibration belongs here.
local Atlases = require('src.content.art.atlases')
local EnemyArt = { kinds = Atlases.kinds, entries = Atlases.entries }
function EnemyArt.frameCount(kind)
  return assert(EnemyArt.entries[kind]).totalFrames
end

EnemyArt.layouts = require('src.content.art.enemy_frames')
return EnemyArt
