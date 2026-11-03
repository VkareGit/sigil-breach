-- Test the atlas actually used by the renderer, not the legacy logical reload
-- frame. A perfectly valid firing transaction can still draw a static weapon.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local V = require('src.render.weapon')
  local Art = require('src.render.weapon_art')
  local Weapons = require('src.content.weapons')
  local B = require('src.combat.ballistics')
  local lines = {}
  local check = Fixtures.checker(lines, 'firing feedback: ', '')
  local function fresh(slot, stock)
    local g = G.new('floor')
    g.ephemeral, g.state, g.run = true, 'playing', nil
    g.enemies, g.pickups, g.bullets, g.hazards = {}, {}, {}, {}
    g.player.weapon, g.view.swapAge, g.view.shotAge = slot, 1, 10
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 27, math.pi, 0
    if stock ~= nil then
      Weapons.state(g, slot).reserve = stock
    end
    return g
  end
  local function advance(g, seconds)
    local remaining = seconds
    while remaining > 1e-9 do
      local dt = math.min(1 / 120, remaining)
      g:update(dt, {})
      remaining = remaining - dt
    end
  end
  for slot = 1, 2 do
    local prefix = 'weapon ' .. slot .. ': '
    local g = fresh(slot, 0)
    local mag = Weapons.meter(g)
    local yaw, pitch = g.player.yaw, g.player.pitch
    local ox, oy, oz = B.origin(g)
    check(prefix .. 'ready pose is distinct from a successful discharge', V.sourceFrame(g) == 1)
    assert(g:shoot())
    check(prefix .. 'real shot immediately selects painted recoil', V.sourceFrame(g) == 2)
    check(
      prefix .. 'the same real shot consumes its ordinary ammunition',
      Weapons.meter(g) == mag - (slot == 1 and 2 or 1)
    )
    local fire = Art[Art.ids[slot]].fire
    advance(g, fire[1][1] + 0.003)
    check(
      prefix .. 'recoil has an authored catch instead of snapping to idle',
      V.sourceFrame(g) == 3
    )
    advance(g, fire[2][1] - fire[1][1] + 0.003)
    check(
      prefix .. 'empty reserve does not leave recoil stuck',
      V.sourceFrame(g) == 1 and g.player.reload == 0
    )
    local ax, ay, az = B.origin(g)
    check(
      prefix .. 'discharge art leaves the physical firing origin and aim unchanged',
      ox == ax and oy == ay and oz == az and yaw == g.player.yaw and pitch == g.player.pitch
    )
    check(prefix .. 'visual recovery does not shorten the firing interval', not g:shoot())

    for _, hz in ipairs({ 30, 60, 144 }) do
      g = fresh(slot, 0)
      assert(g:shoot())
      local seen = { [V.sourceFrame(g)] = true }
      local peakSamples = 0
      for _ = 1, math.ceil(0.27 * hz) do
        g:update(1 / hz, {})
        local frame = V.sourceFrame(g)
        seen[frame] = true
        if frame == 2 then
          peakSamples = peakSamples + 1
        end
      end
      check(
        prefix .. 'recoil/catch/ready are all visible at ' .. hz .. ' Hz',
        seen[1] and seen[2] and seen[3] and peakSamples > 0
      )
    end
    g = fresh(slot)
    g.view.motion = false
    assert(g:shoot())
    check(prefix .. 'reduced motion retains the actual discharge picture', V.sourceFrame(g) == 2)
    local frame, age, shots, ammo =
      V.sourceFrame(g), g.view.shotAge, g.player.shots, Weapons.meter(g)
    for _ = 1, 60 do
      V.sourceFrame(g)
      V.transform(g, 800, 450)
    end
    check(
      prefix .. 'render queries cannot advance recoil or create a second shot',
      V.sourceFrame(g) == frame
        and g.view.shotAge == age
        and g.player.shots == shots
        and Weapons.meter(g) == ammo
    )
    assert(g:switchWeapon(slot == 1 and 2 or 1))
    check(
      prefix .. 'switching cannot replay the previous gun discharge',
      V.sourceFrame(g) == 1 and V.muzzlePhase(g) == nil
    )

    g = fresh(slot)
    Weapons.state(g, slot).mag = 0
    assert(g:reloadGun())
    check(
      prefix .. 'a manual reload cannot manufacture recoil or flash',
      V.sourceFrame(g) ~= 2 and V.sourceFrame(g) ~= 3 and V.muzzlePhase(g) == nil
    )
  end
  local g = fresh(1)
  assert(g:shoot())
  check(
    'automatic shotgun cycle preserves its discharge before opening',
    g.player.reload > 0 and V.sourceFrame(g) == 2
  )
  advance(g, 0.083)
  check(
    'automatic shotgun cycle visibly catches the recoil',
    V.sourceFrame(g) == 3 and not g.player.arsenal.exorcist.open
  )
  advance(g, 0.05)
  check('automatic shotgun cycle holds its painted catch through 0.13 s', V.sourceFrame(g) == 3)
  advance(g, 0.01)
  check('automatic shotgun cycle reaches for the breech after recovery', V.sourceFrame(g) == 4)
  return lines
end
return Tests
