-- Review-only art direction. No release map, shader, asset or score is
-- replaced. Each pair uses the same camera, clock and ordinary game HUD.
local Copy = require('src.core.schema').copy
local Review = {}
function Review.run(g, capture, renderer)
  local original = g.world
  local object = renderer.object
  local function shots(prefix)
    capture(prefix .. '-nave', 24, 36, 24, 3.8, 15)
    capture(prefix .. '-threshold', 21.5, 27.6, 13, 1.3, 27.6)
    capture(prefix .. '-apse', 10, 25, 10, 3.2, 10)
    capture(prefix .. '-apse-small', 10, 25, 10, 3.2, 10, 960, 540)
    capture(prefix .. '-apse-4by3', 10, 25, 10, 3.2, 10, 1024, 768)
    capture(prefix .. '-crypt', 18, 4, 13.64, 1.4, 3.5)
  end
  shots('21-current')
  local ok, err = pcall(function()
    g.world = Copy(original)
    local decor = g.world.decor
    -- Cool reflected fill permits a dimmer foreground without erasing the
    -- route. Saturated warmth belongs to actual fires and ritual accents.
    decor.atmosphere.ambient = { 0.17, 0.195, 0.24 }
    decor.atmosphere.figures = { 0.46, 0.45, 0.44 }
    local lamps = {}
    for _, lamp in ipairs(g.world.lamps) do
      local nave = lamp.x >= 18 and lamp.x <= 30
      -- Let an unlit bay separate pools of light; retain fire at the turns.
      if not (nave and (lamp.z == 38 or lamp.z == 22)) then
        local altar = lamp.z < 11
        lamp.color = altar and { 1.28, 1.02, 0.72 } or { 0.76, 0.53, 0.32 }
        lamp.scale = altar and 1.0 or 0.88
        lamp.brightness = altar and 0.80 or 0.49
        lamp.y = lamp.y * lamp.scale / (altar and 1.35 or 1.20)
        lamps[#lamps + 1] = lamp
      end
    end
    g.world.lamps = lamps
    local murals = {}
    for _, panel in ipairs(decor.murals) do
      -- No repeated scene on every bay. The Judgment ends the route; side
      -- procession leads towards it and burial niches mark the crypt.
      local emptyBay = panel.art == 'chapel_procession' and panel.z == 22.3
      local entryWall = panel.art == 'chapel_procession' and panel.z == 29.38
      if not emptyBay and not entryWall then
        if panel.art == 'chapel_witnesses' then
          panel.brightness = 1.26
        elseif panel.art == 'chapel_judgment_crown' then
          panel.brightness = 1.12
        elseif panel.art == 'chapel_procession' or panel.art == 'chapel_mourners' then
          panel.brightness = 0.62
        end
        murals[#murals + 1] = panel
      end
    end
    decor.murals = murals
    -- Review of the stone/floor colour relationship, not a post-process or
    -- a recolouring of demons, weapon, fonts, fire, or HUD.
    renderer.object = function(self, mesh, x, y, z, yaw, scale, tint, alpha)
      return object(
        self,
        mesh,
        x,
        y,
        z,
        yaw,
        scale,
        mesh == self.worldMesh and { 0.82, 0.91, 1.02 } or tint,
        alpha
      )
    end
    shots('22-proposal')
  end)
  renderer.object, g.world = object, original
  assert(ok, err)
end
return Review
