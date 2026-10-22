local S = {}
function S.write()
  local D = require('src.combat.damage')
  local Weapons = require('src.content.weapons')
  local Enemies = require('src.content.enemy_catalog')
  local lines = {
    'SIGIL BREACH ' .. require('src.core.build').version .. ' / LIVE CONFIGURATION DAMAGE TABLE',
    'damage = base * power * distanceFactor * zone * headMultiplier * upgrade * 100/(100+effectiveArmor) * (1-resistance) * material.wound',
    'Physical effectiveArmor = armor * (1-penetration). Astral effectiveArmor = 0.',
    'Distance is measured along each ray. Each pellet resolves its nearest target or wall.',
    'Shotgun rows assume ALL 20 pellets hit one target: upper bounds, not observed damage or DPS.',
    'Actual spread and separate ray collisions lower the delivered damage with distance.',
    'Rows below are unmodified torso/flesh upper bounds: no head, leg or material factors are applied.',
    string.format(
      'Head multipliers: Exorcist %.2fx, Judge %.2fx. Located armour and authored material also affect the actual contact.',
      Weapons.get('exorcist').attack.headMultiplier,
      Weapons.get('judge').attack.headMultiplier
    ),
    'Armor is a protection rating, not a pool consumed per hit. Stagger uses separate impact.',
    'Revolver: six physical rounds, 0.38 s interval, 1.85 s reload; reserve is consumed once at insertion.',
    'Piercing glyph: penetration 10% -> 60%; impact multiplied by 0.65.',
    'Choke glyph: spread multiplied by 0.72; no direct damage increase.',
    '',
    'target        distance   shotgun   piercing   revolver',
  }
  for _, id in ipairs({ 'imp', 'stolas', 'armored', 'boss', 'furfur' }) do
    local e = Enemies[id]
    local target = { armorRating = e.armor, resistances = e.resistances }
    for _, distance in ipairs({ 3, 8, 14, 20 }) do
      local base = { run = { glyph = 'none' } }
      local piercing = { run = { glyph = 'pierce' } }
      lines[#lines + 1] = string.format(
        '%-13s %5.1f m   %7.2f    %7.2f   %6.2f',
        id,
        distance,
        D.resolve(Weapons.attack(base, 1), target, distance) * 20,
        D.resolve(Weapons.attack(piercing, 1), target, distance) * 20,
        D.resolve(Weapons.attack(base, 2), target, distance)
      )
    end
  end
  lines[#lines + 1] =
    '\nECONOMY: start 100 souls; either ammunition type costs 3/round; charge 30; repair 35/25 shield (partial charge); glyph 100.'
  lines[#lines + 1] = 'WAVE     ENEMIES     DROPS     CLEAR BONUS'
  for i, w in ipairs(require('src.content.waves')) do
    local reward = 0
    for _, kind in ipairs(w.queue) do
      reward = reward + Enemies[kind].souls
    end
    lines[#lines + 1] = string.format(
      '%d        %2d          %3d        %3d',
      i,
      #w.queue,
      reward,
      i == 5 and 100 or 60
    )
  end
  lines[#lines + 1] =
    'Health restored after each wave. Shield and ammunition are paid; supplies: 4 shells + 20 HP/wave.'
  lines[#lines + 1] =
    'Death restores entry equipment, preserves glyphs/progress/paid-drop ledger, moves wallet into echo.'
  lines[#lines + 1] =
    'Perfect-aim playtest verifies completion only. Human difficulty and preferred run length still need playtesting.'
  local file = assert(io.open(require('qa.output').path('balance-results.txt'), 'w'))
  file:write(table.concat(lines, '\n'))
  file:close()
end
return S
