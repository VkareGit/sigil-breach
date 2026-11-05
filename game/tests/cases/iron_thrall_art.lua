-- The heavy body communicates each commitment through its actual pose and clocks.
local T = {}
function T.run(Game, renderer)
  local F = require('tests.support.fixtures')
  local A = require('src.content.enemies')
  local Actions = require('src.enemies.actions')
  local Anim = require('src.enemies.animation')
  local Integrity = require('src.session.integrity')
  local Snapshot = require('src.session.snapshot')
  local Contract = require('src.enemies.art_contract')
  local HazardArt = require('src.render.hazard_art')
  local lines, failures = {}, {}
  local function check(label, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'iron art: ' .. label
    if not ok then
      failures[#failures + 1] = label
    end
  end
  local g = F.arena(Game)
  local e = g:spawn('armored', 16, 20)
  e.target, e.awake, e.visible, e.memory = g.player.id, true, true, 60
  local silhouettes, attacks = {}, {}
  local incomplete = require('src.core.schema').copy(A.armored)
  for index, attack in ipairs(incomplete.attacks) do
    if attack.id == 'shoulder' then
      table.remove(incomplete.attacks, index)
      break
    end
  end
  local problems = table.concat(Contract.problems(incomplete), '\n')
  for _, name in ipairs({ 'recover.shoulder', 'turn.shoulder' }) do
    check(
      'an orphan ' .. name .. ' is rejected before rendering',
      problems:find('action pose ' .. name, 1, true) ~= nil
    )
  end
  for _, spec in ipairs(A.armored.attacks) do
    attacks[spec.id] = spec
    Actions.begin(g, e, 4, spec)
    e.holdSpan, e.holdLeft = 0, 0
    e.windup = e.windupDuration * 0.15
    local frame = Anim.pose(g, e)
    check(spec.id .. ' has a distinct late preparation silhouette', not silhouettes[frame])
    silhouettes[frame] = true
    local before = Integrity.capture(g)
    renderer:draw(g, 960, 540)
    check(
      spec.id .. ' painting cannot advance a clock or the random stream',
      not Integrity.difference(before, Integrity.capture(g))
    )
  end
  local charge = attacks.shoulder
  Actions.begin(g, e, 5, charge)
  Actions.execute(g, e)
  e.ai, e.phase = 'strike', 0.02
  local first = Anim.pose(g, e)
  e.phase = 0.2
  local second = Anim.pose(g, e)
  check('the running charge advances its feet during travel', first ~= second)
  e.turnAt, e.phase = 1.4, 1.02
  local brace = Anim.pose(g, e)
  check(
    'the return pause plants a different pose from either running foot',
    brace ~= first and brace ~= second
  )
  e.attackSpec = nil
  check(
    'a named charge without a cached definition keeps its planted pose',
    Anim.pose(g, e) == brace
  )
  check('reading that planted pose does not populate the simulation cache', e.attackSpec == nil)
  e.attackSpec = charge
  local saved = Snapshot.capture(g)
  Snapshot.restore(g, saved)
  e = g.enemies[1]
  check('Continue keeps the exact planted charge pose', Anim.pose(g, e) == brace)
  local slam = attacks['ground-slam']
  Actions.begin(g, e, 3, slam)
  Actions.execute(g, e)
  e.ai, e.phase = 'strike', 0.02
  local contact = Anim.pose(g, e)
  e.ai, e.phase, e.recover = 'recover', 0.02, 0.3
  local rising = Anim.pose(g, e)
  e.phase, e.recover = 0.29, 0.01
  local ready = Anim.pose(g, e)
  check(
    'the fist leaves its floor-contact pose through a recovery pose before standing',
    contact ~= rising and rising ~= ready and contact ~= ready
  )
  local upright, ribbon, circle = HazardArt.upright, HazardArt.ribbon, HazardArt.circle
  local seen = {}
  HazardArt.upright = function(_, _, _, _, name)
    seen[#seen + 1] = name
  end
  HazardArt.ribbon = function(_, _, _, name, _, _, _, height)
    seen[#seen + 1] = { name = name, height = height }
  end
  HazardArt.circle = function(_, _, _, name)
    seen[#seen + 1] = name
  end
  local ok, err = xpcall(function()
    local h = g.hazards[#g.hazards]
    check('the floor strike records its own painted style', h and h.art == 'iron')
    if h then
      local kinds = require('src.render.hazard_kinds')
      h.delay, h.radius = -0.12, 2
      kinds.of(h).air(renderer, g, h)
      check(
        'the airborne ridge ends at the real damaging height',
        type(seen[#seen]) == 'table' and seen[#seen].height == h.volume.top
      )
      local names = {}
      for _, age in ipairs({ 0.02, 0.12, 0.22 }) do
        h.delay = -age
        seen = {}
        kinds.of(h).air(renderer, g, h)
        local v = seen[#seen]
        if type(v) == 'table' then
          names[v.name] = true
        end
      end
      local n = 0
      for _ in pairs(names) do
        n = n + 1
      end
      check('the travelling ridge has three painted phases', n == 3)
    end
    Actions.begin(g, e, 3, attacks.cleave)
    e.ai, e.phase = 'strike', attacks.cleave.active[1] + 0.03
    seen = {}
    require('src.render.effects').spells(renderer, g)
    local painted = false
    for _, name in ipairs(seen) do
      if type(name) == 'string' and name:match('^ironCut') then
        painted = true
      end
    end
    check('the physical sweep uses its painted claw sequence', painted)
    Actions.begin(g, e, 3, attacks.cleave)
    seen = {}
    require('src.render.passes.enemy_marks').draw(renderer, g)
    local mark = false
    for _, name in ipairs(seen) do
      if name == 'ironMark' then
        mark = true
      end
    end
    check('preparation uses the dark iron imprint', mark)
  end, debug.traceback)
  HazardArt.upright, HazardArt.ribbon, HazardArt.circle = upright, ribbon, circle
  if not ok then
    error(err, 0)
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T
