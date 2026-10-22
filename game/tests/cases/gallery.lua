-- The proving-ground gallery (src/world/gallery.lua): every exhibit is placed in
-- open floor, every board shows a real active asset, pads act through the
-- normal test-field tools and statues never enter combat.
local Tests = {}
function Tests.run(G, check)
  local Gallery = require('src.world.gallery')
  local Art = require('src.render.gallery')
  local Field = require('src.run.test_field')
  local W = require('src.world.arena')
  local g = Field.new(G)
  Field.close(g)
  local placed = Art.layout(g.world)
  check('every gallery board finds a free slot in its hall', #placed == #Art.boards)
  local open, files = true, true
  for _, b in ipairs(placed) do
    open = open and not W.solid(g.world, b.x, b.z, 0.3)
    files = files and love.filesystem.getInfo(b.path) ~= nil
  end
  check('gallery boards stand on open floor and show existing assets', open and files)
  local groups = {}
  for _, b in ipairs(Art.boards) do
    groups[b.group] = true
  end
  check(
    'the gallery covers world, weapons, effects, interface and demons',
    groups.WORLD and groups.WEAPONS and groups.EFFECTS and groups.INTERFACE and groups.DEMONS
  )
  local kinds = {}
  for _, s in ipairs(Gallery.statues) do
    kinds[s.armored and 'armored' or s.kind] = true
  end
  check(
    'a statue stands for every demon of the catalogue',
    kinds.imp and kinds.armored and kinds.stolas and kinds.buer and kinds.boss and kinds.furfur
  )
  local padsOpen = true
  for _, p in ipairs(Gallery.pads) do
    padsOpen = padsOpen and not W.solid(g.world, p.x, p.z, 0.3)
  end
  check('every pad lies on open floor', padsOpen)
  -- A spawn pad: context prompt, then [E] puts the demon on the field.
  local pad
  for _, p in ipairs(Gallery.pads) do
    if p.spawn == 'buer' then
      pad = p
    end
  end
  g.player.x, g.player.z, g.player.yaw = pad.x, pad.z, math.pi / 2
  check('standing on a pad shows its prompt', g:context() == '[E] SPAWN PLAGUE GARDENER')
  local before = #g.enemies
  g:interact()
  check(
    '[E] on a spawn pad spawns that demon through the test field',
    #g.enemies == before + 1 and g.enemies[#g.enemies].kind == 'buer'
  )
  local statue = false
  for _, e in ipairs(g.enemies) do
    for _, s in ipairs(Gallery.statues) do
      if s.record == e then
        statue = true
      end
    end
  end
  check('statues are never combat bodies', not statue)
  for _, p in ipairs(Gallery.pads) do
    if p.weapon == 'judge' then
      pad = p
    end
  end
  g.player.x, g.player.z = pad.x, pad.z
  g.weapon = 1
  g:interact()
  check(
    '[E] on a weapon pad puts that weapon in hand',
    g.weapon == require('src.content.weapons').slotOf(g, 'judge')
  )
  for _, p in ipairs(Gallery.pads) do
    if p.refill then
      pad = p
    end
  end
  g.player.x, g.player.z = pad.x, pad.z
  g.player.hp = 20
  g.player.arsenal.judge.reserve = 0
  g:interact()
  check(
    '[E] on the refill pad restores health and ammunition',
    g.player.hp == 100 and g.player.arsenal.judge.reserve == 72
  )
  g.testField = nil
  g.player.x, g.player.z = pad.x, pad.z
  check(
    'outside the proving ground the pads do nothing',
    Gallery.context(g) ~= nil and g:context() ~= Gallery.padLabel(pad)
  )
end
return Tests
