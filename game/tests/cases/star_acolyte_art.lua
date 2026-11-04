-- Real presentation entry points must show separate phases while leaving the
-- authoritative body, projectile and hazard clocks untouched.
local F = require('tests.support.fixtures')
local T = {}
function T.run(Game, renderer)
  local Effects = require('src.render.effects')
  local HazardArt = require('src.render.hazard_art')
  local HazardKinds = require('src.render.hazard_kinds')
  local Rites = require('src.content.art.rites')
  local Actions = require('src.enemies.actions')
  local A = require('src.content.enemies')
  local Integrity = require('src.session.integrity')
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'star art: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local function distinct(values)
    local seen, n = {}, 0
    for _, value in ipairs(values) do
      if not seen[value] then
        seen[value], n = true, n + 1
      end
    end
    return n
  end
  local upright, band, strip, circle, spell =
    HazardArt.upright, HazardArt.band, HazardArt.strip, HazardArt.circle, Effects.spell
  local cells = {}
  HazardArt.upright = function(_, _, _, _, name)
    cells[#cells + 1] = name
  end
  HazardArt.band = function(_, _, _, name)
    cells[#cells + 1] = name
  end
  HazardArt.strip = function(_, _, _, name)
    cells[#cells + 1] = name
  end
  Effects.spell = function()
    cells[#cells + 1] = 'legacy-glow'
  end
  local ok, err = xpcall(function()
    -- Check actual pigment against the unchanged collision sphere, not merely
    -- a metadata claim about the atlas's visible extent.
    local style = Rites.projectiles.styles.astral
    for _, sheet in ipairs(Rites.supplements) do
      if sheet.cells[style.prefix .. '1'] then
        check(
          'the painted spell atlas is loaded before combat',
          renderer.resources:hasImage(sheet.path)
        )
        local data = love.image.newImageData(sheet.path)
        local w, h = data:getWidth() / sheet.columns, data:getHeight() / sheet.rows
        for frame = 1, 4 do
          local cell, solid = sheet.cells[style.prefix .. frame], true
          local radius = style.core * math.min(w, h) * 0.5
          for y = -math.ceil(radius), math.ceil(radius) do
            for x = -math.ceil(radius), math.ceil(radius) do
              if x * x + y * y <= radius * radius then
                local _, _, _, alpha = data:getPixel(
                  math.floor((cell[1] + 0.5) * w + x),
                  math.floor((cell[2] + 0.5) * h + y)
                )
                solid = solid and alpha >= 0.95
              end
            end
          end
          check('projectile ' .. frame .. ' contains its collision core in opaque pigment', solid)
        end
        data:release()
      end
    end
    local g = F.arena(Game)
    local sequences = {}
    for _, arriving in ipairs({ false, true }) do
      g.view.blinkBursts = { { x = 16, z = 18, starts = 0, arriving = arriving } }
      cells = {}
      for i = 0, 7 do
        g.elapsed = (i + 0.5) / 8 * Rites.blink.duration
        Effects.spells(renderer, g)
      end
      check(
        (arriving and 'arrival' or 'departure') .. ' has four painted phases',
        distinct(cells) >= 4
      )
      sequences[#sequences + 1] = table.concat(cells, '/')
    end
    check('arrival gathers what departure scatters', sequences[1] ~= sequences[2])
    cells = {}
    g.elapsed = Rites.blink.duration
    Effects.spells(renderer, g)
    check('teleport has no surviving visual after its view lifetime', #cells == 0)
    local Feedback = require('src.feedback.rite_feedback')
    for i = 1, 100 do
      Feedback.blinked(g, { fromX = 16, fromZ = 18, toX = 18, toZ = 16 })
    end
    check(
      'many teleports keep a bounded presentation record',
      #g.view.blinkBursts <= Rites.blink.limit
    )
    g.elapsed = g.elapsed + Rites.blink.duration + 0.01
    Feedback.update(g)
    check('expired teleport records are removed', #g.view.blinkBursts == 0)
    g.view.blinkBursts = nil
    local e = g:spawn('stolas', 16, 18)
    e.target, e.spawnAge = g.player.id, 2
    HazardArt.circle = function(_, _, _, name)
      cells[#cells + 1] = name
    end
    local beam
    for _, attack in ipairs(A.stolas.attacks) do
      if attack.id == 'star-lance' then
        beam = attack
      end
    end
    Actions.begin(g, e, 7, beam)
    e.windup = beam.parry / 2
    renderer:draw(g, 960, 540)
    cells = {}
    require('src.render.passes.enemy_marks').draw(renderer, g)
    check(
      'the owl uses demonic floor pigment for preparation and its counter window',
      cells[1] == 'owlCounter' and cells[2] == 'owlMark'
    )
    HazardArt.circle = circle
    for _, attack in ipairs(A.stolas.attacks) do
      if attack.kind ~= 'blink' then
        Actions.begin(g, e, math.min(7, attack.range), attack)
        e.windup = e.windupDuration * 0.25
        cells = {}
        local before = Integrity.capture(g)
        Effects.spells(renderer, g)
        check(
          attack.id .. ' gathers its painted spell in both hands',
          #cells == 2
            and cells[1]:sub(1, #Rites.projectiles.styles.astral.prefix)
              == Rites.projectiles.styles.astral.prefix
        )
        check(
          attack.id .. ' drawing never changes the fight',
          not Integrity.difference(before, Integrity.capture(g))
        )
      end
    end
    for _, attack in ipairs(A.stolas.attacks) do
      if attack.kind ~= 'blink' then
        Actions.begin(g, e, math.min(7, attack.range), attack)
        Actions.execute(g, e)
        e.ai, e.phase, e.released = 'strike', 0.04, 1
        cells = {}
        require('src.render.cast_accents').draw(renderer, g, e, Effects)
        check(attack.id .. ' retains hand pigment through release', #cells == 2)
      end
    end
    g.hazards = {}
    local hazard =
      { kind = 'sweepline', x = 16, z = 18, angle = 0, radius = 6, maxDelay = 0.55, delay = 0.55 }
    local stages = {}
    for _, remaining in ipairs({ 0.55, 0.15, 0 }) do
      hazard.delay, cells = remaining, {}
      HazardKinds.of(hazard).ground(renderer, g, hazard)
      stages[#stages + 1] = cells[1]
    end
    check(
      'the ground ritual separates closed crack, opening and dangerous release',
      distinct(stages) == 3
    )
    local footprint
    HazardArt.strip = function(_, _, at, name, length, width)
      footprint = { x = at.x, z = at.z, name = name, length = length, width = width }
    end
    hazard.width, hazard.delay = 1.2, 0
    HazardKinds.of(hazard).ground(renderer, g, hazard)
    check(
      'one connected painting covers the actual line width and length',
      math.abs(footprint.width * Rites.ray.pigmentWidth - hazard.width) < 1e-6
        and math.abs(footprint.length * Rites.ray.pigmentLength - hazard.radius) < 1e-6
    )
    local wave
    for _, attack in ipairs(A.stolas.attacks) do
      if attack.id == 'star-ray' then
        wave = attack
      end
    end
    Actions.begin(g, e, 6, wave)
    Actions.execute(g, e)
    local h = g.hazards[#g.hazards]
    h.delay, h.radius = -0.4, 6
    local state = Integrity.capture(g)
    HazardKinds.of(h).air(renderer, g, h)
    local mesh = renderer.hazardArt.ribbon
    local first, count = mesh:getDrawRange()
    local valid, tallest, outer = true, 0, 0
    for i = first, first + count - 1 do
      local x, y, z, u, v = mesh:getVertex(i)
      valid = valid and u >= 0 and u <= 1 and v >= 0 and v <= 1
      tallest, outer = math.max(tallest, y), math.max(outer, math.sqrt(x * x + z * z))
    end
    check(
      'wave pigment reaches its real height and leading edge',
      math.abs(tallest - h.volume.top) < 1e-6 and math.abs(outer - h.radius) < 1e-5
    )
    check(
      'the bounded wave mesh cannot sample adjacent atlas cells',
      valid and count <= Rites.ribbon.segments * 6
    )
    check(
      'sampling a moving wave leaves simulation unchanged',
      not Integrity.difference(state, Integrity.capture(g))
    )
    local marker = g.view.riteBursts[#g.view.riteBursts]
    check(
      'wave residue starts only after the last damaging crest',
      marker.kind == 'wave'
        and marker.radius == wave.reach
        and marker.starts > g.elapsed + wave.delay
    )
    local restored = require('src.session.snapshot').capture(g)
    require('src.session.snapshot').restore(g, restored)
    local savedWave = g.hazards[#g.hazards]
    check(
      'restoring a wave preserves its painting and physical height',
      savedWave.art == h.art and savedWave.volume.top == h.volume.top
    )
    local ribbon = HazardArt.ribbon
    local calls = {}
    HazardArt.ribbon = function(_, _, _, name, shape, reach, width, height)
      calls[#calls + 1] = { name = name, shape = shape, height = height }
    end
    local tall = {
      kind = 'sweepline',
      art = 'hell',
      x = 16,
      z = 18,
      angle = 0,
      radius = 6,
      width = 1.2,
      volume = beam.volume,
      delay = 0.45,
    }
    HazardKinds.of(tall).air(renderer, g, tall)
    check('a newly marked fissure has no false active column', #calls == 0)
    tall.delay = 0.075
    HazardKinds.of(tall).air(renderer, g, tall)
    local opening = calls[#calls]
    tall.delay = 0
    HazardKinds.of(tall).air(renderer, g, tall)
    local active = calls[#calls]
    check(
      'the fissure visibly rises before its full-height strike',
      opening
        and active
        and opening.height < active.height
        and active.height == beam.volume.top
        and opening.name ~= active.name
    )
    HazardArt.ribbon = ribbon
    local data = love.image.newImageData('assets/art/stolas-ground-rites-v45.png')
    local spill = 0
    for y = 0, data:getHeight() - 1, 2 do
      for x = 0, data:getWidth() - 1, 2 do
        local red, green, blue, alpha = data:getPixel(x, y)
        if alpha > 0.05 and green > math.max(red, blue) * 1.08 then
          spill = spill + 1
        end
      end
    end
    check('the ground atlas has no visible chroma-key fringe', spill == 0)
    data:release()
  end, debug.traceback)
  HazardArt.upright, HazardArt.band, HazardArt.strip, HazardArt.circle, Effects.spell =
    upright, band, strip, circle, spell
  assert(ok, err)
  for _, line in ipairs(lines) do
    print(line)
  end
  assert(#failures == 0, table.concat(failures, '; '))
  return lines
end
return T
