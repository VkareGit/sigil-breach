-- Independent painted landmarks, measured in source pixels on magnified crops.
-- Both coordinates come from artwork: no collider supplies its own aim height.
local T = {}
function T.run(Game, check)
  local Pose = require('src.enemies.pose')
  local B = require('src.combat.ballistics')
  local g = require('src.run.test_field').new(Game)
  g.ephemeral = true
  for _, p in ipairs({
    { 'buer', 5, 176, 410 },
    { 'buer', 6, 475, 400 },
    { 'buer', 9, 128, 694 },
    { 'armored', 5, 1133, 51 },
    { 'armored', 6, 1403, 49 },
    { 'armored', 13, 98, 539 },
    { 'imp', 13, 114, 539 },
    { 'boss', 15, 757, 981 },
  }) do
    g.enemies = {}
    local e = g:spawn(p[1], 16, 24)
    e.previewFrame = p[2]
    g.player.x, g.player.z = e.x, e.z + 3
    local art = Pose.sample(g, e)
    local data = love.image.newImageData(art.sourcePath)
    local iw, ih = data:getDimensions()
    local r = art.region.rect
    check(
      p[1] .. ' pose ' .. p[2] .. ' independent skull landmark is real pigment',
      select(4, data:getPixel(p[3], p[4])) > 0.65
    )
    local u, v = (p[3] + 0.5 - r[1] * iw) / (r[3] * iw), (p[4] + 0.5 - r[2] * ih) / (r[4] * ih)
    local y = art.baseY + (1 - v) * art.sy * art.size
    local x = e.x + (u - 0.5) * art.sx * art.size + (1 - v) * art.sy * art.size * art.lean
    local hits = true
    for _, range in ipairs({ 3, 8, 16 }) do
      g.player.z = e.z + range
      local distance, part, surface = B.body(g, e, x, y, e.z + range, 0, 0, -1, 20)
      hits = hits and distance ~= nil and part == 'head' and surface.shapeId == 'head'
    end
    check(p[1] .. ' pose ' .. p[2] .. ' painted skull accepts head rays at 3/8/16 m', hits)
    data:release()
  end
end
return T
