-- The meter of a fight's depth (PLAN B1; owner, 2026-11-10: a fight should reward reading
-- its blows, and a creature should not be a sponge). The same fights are given to knights
-- who differ only in what they read; each fight is counted from outside, through the
-- session's events. Nothing here changes the game, and nothing here tunes it.
--   love game --depth-meter              every fight, every knight, SEEDS seeds
--   love game --depth-meter --qa-smoke   one fight, three knights, one seed
--   SIGIL_DEPTH_FIGHTS=claws,trio        only these fights
--   SIGIL_DEPTH_SEEDS=9                  this many seeds
--   SIGIL_DEPTH_ARMS=judge               only this of what he may carry (M.arms)
-- Three readings of the table:
--   mastery   how much faster the master kills than the novice; below MASTERY the body
--             is a sponge: knowing it does not shorten it
--   reading   the harm the master takes as a share of the harm of the knight who reads
--             nothing (restless); near 1, or with both near none, reading earns nothing
--   standing  what the knight who stands and shoots gets: a fight he wins unhurt asks
--             nothing of anyone
-- and, for the fights that are judged, whether the fight is ready (M.thresholds).
local Bot = require('qa.souls_bot')
local Release = require('src.app.release')
local Rng = require('src.core.rng')
local Archetypes = require('src.content.enemies')
local Maps = require('src.content.maps.index')
local Text = require('src.content.text')
local Tooling = require('qa.tooling')
local Arena = require('src.world.arena')
local Rules = require('src.combat.rules')
local Capabilities = require('src.session.capabilities')
local Weapons = require('src.content.weapons')
local M = {}
local STEP = 1 / 120
local SEEDS = 5
M.mastery = 2
-- The knights, from the one who reads nothing to the one who reads everything.
local function human(miss)
  return function(seed)
    local stream = Rng:new(seed + 1000)
    return Bot.human(miss, function()
      return stream:random()
    end)
  end
end
local function plain(name)
  return function()
    return Bot[name]
  end
end
M.knights = {
  { id = 'careless', reads = 'nothing: stands and shoots', make = plain('careless') },
  { id = 'restless', reads = 'nothing: hops, slides, dodges', make = plain('restless') },
  { id = 'reflex', reads = 'the end of a windup', make = plain('reflex') },
  { id = 'novice', reads = 'half the blows', make = human(0.5) },
  { id = 'able', reads = 'four blows in five', make = human(0.2) },
  { id = 'master', reads = 'every blow', make = plain('learning') },
}
-- What he carries. A new way begins with the Judge alone (owner, D12), and that is the
-- knight most fights are met by; the proving ground arms him with both guns.
M.arms = {
  { id = 'judge', weapons = { 'judge' }, note = 'the Judge alone, as a new way begins (D12)' },
  { id = 'both', note = 'both guns, as the proving ground arms him' },
}
-- When a fight is ready (owner, 2026-11-10, docs/WIZJA.md: D25 and the meter's
-- thresholds), as shares of the fights fought. A duellist is a body that asks to be read
-- alone (the Iron Thrall, the elites); three small ones are judged together; a small one
-- alone, and the six, are measured and not judged.
--   standing  the knight who stands and shoots wins at most this share
--   blind     the knight who reads nothing wins at most this share
--   master    the master wins at least this share
--   harm      and takes at most this much
--   mastery   and kills at least this many times as fast as the novice
M.thresholds = {
  duel = { standing = 1 / 5, blind = 2 / 5, master = 1, harm = 25, mastery = 1.5 },
  three = { blind = 2 / 5, master = 4 / 5 },
}
-- What a fight still lacks of its thresholds: nothing when it is ready, nil when it is
-- not judged. by: the knights' sums of M.measure, by id.
function M.lacks(fight, by, seeds)
  local need = M.thresholds[fight.judged]
  if not need then
    return nil
  end
  local lacks = {}
  local function lack(text, ...)
    lacks[#lacks + 1] = string.format(text, ...)
  end
  local careless, restless, novice, master = by.careless, by.restless, by.novice, by.master
  if need.standing and careless and careless.wins / seeds > need.standing then
    lack('standing wins %d/%d', careless.wins, seeds)
  end
  if need.blind and restless and restless.wins / seeds > need.blind then
    lack('reading nothing wins %d/%d', restless.wins, seeds)
  end
  if need.master and master and master.wins / seeds < need.master then
    lack('the master wins %d/%d', master.wins, seeds)
  end
  if need.harm and master and master.harm > need.harm then
    lack('the master takes %.0f harm', master.harm)
  end
  if need.mastery and master and novice then
    local gain = master.time and novice.time and novice.time / master.time
    if not gain or gain < need.mastery then
      lack('mastery %s', gain and string.format('%.2f', gain) or 'not comparable')
    end
  end
  return lacks
end
-- The fights: each creature alone in its chamber of the proving ground, then the groups a
-- way is made of (owner, D21: three to six awake), in the open nave of the same map. Every
-- fight is fought where effort is paid (stamina, the flask): the plain test floor charges
-- nothing for a dodge, and a knight who dodges for nothing proves nothing.
M.fights = {
  { id = 'claws', trial = 'claws', seconds = 240 },
  { id = 'iron', trial = 'iron', seconds = 240, judged = 'duel' },
  { id = 'stars', trial = 'stars', seconds = 240 },
  { id = 'resin', trial = 'resin', seconds = 240 },
  { id = 'ash', trial = 'ash', seconds = 240, judged = 'duel' },
  { id = 'storm', trial = 'storm', seconds = 240, judged = 'duel' },
  {
    id = 'trio',
    judged = 'three',
    knight = { 24, 31 },
    pack = { { 'imp', 21, 25 }, { 'imp', 27, 25 }, { 'stolas', 24, 21 } },
    seconds = 180,
  },
  {
    id = 'pack',
    knight = { 24, 31 },
    pack = {
      { 'imp', 21, 25 },
      { 'imp', 27, 25 },
      { 'imp', 24, 23 },
      { 'stolas', 20, 21 },
      { 'buer', 28, 21 },
      { 'armored', 24, 20 },
    },
    seconds = 180,
  },
}
local function named(list, id)
  for _, entry in ipairs(list) do
    if entry.id == id then
      return entry
    end
  end
end
-- Who stands in a fight, in words.
function M.cast(fight)
  local ids = {}
  if fight.trial then
    ids[1] = named(Maps:get('proving').proving.trials, fight.trial).creature
  else
    for _, body in ipairs(fight.pack) do
      ids[#ids + 1] = body[1]
    end
  end
  local names = {}
  for i, id in ipairs(ids) do
    names[i] = Text.get(Archetypes.get(id).name)
  end
  return table.concat(names, ', ')
end
-- The session of a fight, and whether it is over and won.
local function chamber(G, fight, seed)
  local g = G.new('field', 'proving', Release.sessionOptions.field)
  g.ephemeral = true
  g.rng.sim:seed(seed)
  assert(g:act('catalog', 'field_chamber_' .. fight.trial))
  return g,
    function()
      return g.testField.roomTrial.status ~= 'active'
    end,
    function()
      return g.testField.roomTrial.status == 'complete'
    end
end
local function open(G, fight, seed)
  local g = G.new('field', 'proving', Release.sessionOptions.field)
  g.ephemeral, g.state, g.testField.invincible = true, 'playing', false
  g.rng.sim:seed(seed)
  local p = g.player
  p.x, p.z, p.yaw = fight.knight[1], fight.knight[2], math.pi
  assert(
    not Arena.solid(g.world, p.x, p.z, Rules.radius(p)),
    fight.id .. ': the knight stands in stone'
  )
  for _, body in ipairs(fight.pack) do
    local radius = Archetypes.get(body[1]).body.radius
    assert(
      not Arena.solid(g.world, body[2], body[3], radius),
      fight.id .. ': a body stands in stone'
    )
    local e = g:spawn(body[1], body[2], body[3])
    e.awake, e.visible, e.memory, e.spawnAge, e.target = true, true, 60, 2, p.id
  end
  local function fallen()
    for _, e in ipairs(g.enemies) do
      if e.hp > 0 then
        return false
      end
    end
    return true
  end
  return g, fallen, fallen
end
-- One fight of one knight: what happened, counted from the session's own events.
function M.fight(G, fight, knight, seed, arms)
  local g, over, won = (fight.trial and chamber or open)(G, fight, seed)
  assert(
    Capabilities.attrition(g) and Capabilities.vulnerable(g),
    fight.id .. ': a fight is measured where effort is paid and a blow hurts'
  )
  local p = g.player
  if arms and arms.weapons then
    Weapons.restore(g, arms.weapons, nil, p)
    p.weapon = 1
  end
  local carried = {}
  for _, id in ipairs(p.loadout) do
    local state = p.arsenal[id]
    carried[#carried + 1] = string.format('%s %d+%d', id, state.mag or 0, state.reserve or 0)
  end
  local tally = {
    carried = table.concat(carried, ', '),
    shots = 0,
    dodges = 0,
    perfect = 0,
    executions = 0,
    kills = 0,
    breakKills = 0,
    blows = 0,
    hits = 0,
    jumps = 0,
    slides = 0,
    harm = 0,
  }
  local function count(event, field, when)
    g.bus:on('sim', event, function(payload)
      if not when or when(payload) then
        tally[field] = tally[field] + 1
      end
    end)
  end
  count('ShotFired', 'shots')
  count('Dashed', 'dodges')
  count('PerfectDodge', 'perfect')
  count('Executed', 'executions')
  count('EnemyKilled', 'kills')
  count('EnemyKilled', 'breakKills', function(event)
    return event.offBalance
  end)
  count('AttackReleased', 'blows')
  count('PlayerHit', 'hits')
  local act, memory = knight.make(seed), {}
  local whole, jumping, sliding = p.hp + p.armor, false, false
  for _ = 1, fight.seconds / STEP do
    local input = act(g, memory)
    tally.jumps = tally.jumps + ((input.jump and not jumping) and 1 or 0)
    tally.slides = tally.slides + ((input.slide and not sliding) and 1 or 0)
    jumping, sliding = input.jump or false, input.slide or false
    g:update(STEP, input)
    local now = p.hp + p.armor
    tally.harm, whole = tally.harm + math.max(0, whole - now), now
    if g.state ~= 'playing' or over() then
      break
    end
  end
  tally.time = g.elapsed
  tally.outcome = g.state == 'dead' and 'died' or (won() and 'won' or 'time')
  tally.hp = math.max(0, p.hp)
  return tally
end
local function median(values)
  if #values == 0 then
    return nil
  end
  table.sort(values)
  local middle = (#values + 1) / 2
  return (values[math.floor(middle)] + values[math.ceil(middle)]) / 2
end
-- One knight's fights over the seeds, summed up.
function M.measure(G, fight, knight, seeds, arms)
  local sum = { runs = seeds, wins = 0, deaths = 0, blows = 0, hits = 0 }
  local times, harms, counts = {}, {}, {}
  local counted = { 'shots', 'dodges', 'perfect', 'jumps', 'slides', 'executions', 'breakKills' }
  for seed = 1, seeds do
    local result = M.fight(G, fight, knight, seed, arms)
    sum.carried = result.carried
    sum.wins = sum.wins + (result.outcome == 'won' and 1 or 0)
    sum.deaths = sum.deaths + (result.outcome == 'died' and 1 or 0)
    sum.blows, sum.hits = sum.blows + result.blows, sum.hits + result.hits
    if result.outcome == 'won' then
      times[#times + 1] = result.time
    end
    harms[#harms + 1] = result.harm
    for _, field in ipairs(counted) do
      counts[field] = counts[field] or {}
      counts[field][#counts[field] + 1] = result[field]
    end
  end
  -- The time of a won fight only: a death is not a quick kill.
  sum.time, sum.harm = median(times), median(harms)
  for _, field in ipairs(counted) do
    sum[field] = median(counts[field])
  end
  sum.landed = sum.blows > 0 and sum.hits / sum.blows or nil
  return sum
end
local function shown(value, format)
  return value and string.format(format, value) or '-'
end
-- The table of one fight and its two readings.
function M.table(G, fight, knights, seeds, arms)
  local lines, by = {}, {}
  lines[#lines + 1] = string.format(
    'FIGHT %s: %s; %d seeds, at most %d s',
    fight.id,
    M.cast(fight),
    seeds,
    fight.seconds
  )
  lines[#lines + 1] =
    '  knight    won  died  time s   harm  blows landed  shots  dodges perfect  jumps slides  exec  break'
  for _, knight in ipairs(knights) do
    local sum = M.measure(G, fight, knight, seeds, arms)
    by[knight.id] = sum
    lines[#lines + 1] = string.format(
      '  %-8s %2d/%d  %2d/%d  %6s %6s  %5d %6s %6s  %6s %7s %6s %6s %5s %6s',
      knight.id,
      sum.wins,
      seeds,
      sum.deaths,
      seeds,
      shown(sum.time, '%.1f'),
      shown(sum.harm, '%.0f'),
      sum.blows,
      shown(sum.landed and sum.landed * 100, '%.0f%%'),
      shown(sum.shots, '%.0f'),
      shown(sum.dodges, '%.0f'),
      shown(sum.perfect, '%.0f'),
      shown(sum.jumps, '%.0f'),
      shown(sum.slides, '%.0f'),
      shown(sum.executions, '%.0f'),
      shown(sum.breakKills, '%.0f')
    )
  end
  local novice, master, restless = by.novice, by.master, by.restless
  if novice and master then
    if novice.time and master.time then
      local gain = novice.time / master.time
      lines[#lines + 1] = string.format(
        '  mastery: the master kills %.2f times as fast as the novice%s',
        gain,
        gain < M.mastery and ' (a sponge: under ' .. M.mastery .. ')' or ''
      )
    else
      lines[#lines + 1] = string.format(
        '  mastery: not comparable (novice won %d, master won %d of %d)',
        novice.wins,
        master.wins,
        seeds
      )
    end
  end
  if restless and master then
    lines[#lines + 1] = string.format(
      '  reading: the master takes %.0f harm and wins %d/%d; reading nothing takes %.0f and wins %d/%d%s',
      master.harm,
      master.wins,
      seeds,
      restless.harm,
      restless.wins,
      seeds,
      restless.harm > 0 and string.format(' (share %.2f)', master.harm / restless.harm) or ''
    )
  end
  local careless = by.careless
  if careless then
    lines[#lines + 1] = string.format(
      '  standing: the knight who stands and shoots wins %d/%d%s, taking %.0f harm',
      careless.wins,
      seeds,
      careless.time and string.format(' in %.1f s', careless.time) or '',
      careless.harm
    )
  end
  local lacks = M.lacks(fight, by, seeds)
  if lacks then
    lines[#lines + 1] = '  ready: '
      .. (#lacks == 0 and 'yes' or 'no (' .. table.concat(lacks, '; ') .. ')')
  end
  return lines, by
end
local function chosen(list, spec)
  if not spec or spec == '' then
    return list
  end
  local out = {}
  for id in (spec .. ','):gmatch('%s*([%w_-]+)%s*,') do
    out[#out + 1] = assert(named(list, id), 'depth meter knows no ' .. id)
  end
  return out
end
-- The whole report as lines; smoke: one fight, three knights, one seed.
function M.report(G, smoke)
  local fights = chosen(M.fights, os.getenv('SIGIL_DEPTH_FIGHTS'))
  local knights = M.knights
  local seeds = tonumber(os.getenv('SIGIL_DEPTH_SEEDS')) or SEEDS
  local armed = chosen(M.arms, os.getenv('SIGIL_DEPTH_ARMS'))
  if smoke then
    fights, seeds, armed = { M.fights[1] }, 1, { M.arms[1] }
    knights =
      { named(M.knights, 'careless'), named(M.knights, 'restless'), named(M.knights, 'master') }
  end
  local lines = Tooling.header('THE DEPTH OF A FIGHT', smoke)
  lines[#lines + 1] = 'Knights, by what they read:'
  for _, knight in ipairs(knights) do
    lines[#lines + 1] = string.format('  %-8s %s', knight.id, knight.reads)
  end
  lines[#lines + 1] =
    'Columns: time is the median of won fights; harm, shots and the moves are medians of all; '
  lines[#lines + 1] =
    "blows are the creatures' attacks released, landed the share that hit the knight; break is a kill of a body off its balance."
  lines[#lines + 1] =
    'Bots are not players: the table compares knights, it does not grade the game.'
  for _, arms in ipairs(armed) do
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'ARMED ' .. arms.id .. ': ' .. arms.note
    for _, fight in ipairs(fights) do
      local rows, by = M.table(G, fight, knights, seeds, arms)
      lines[#lines + 1] = ''
      for _, line in ipairs(rows) do
        lines[#lines + 1] = line
      end
      lines[#lines + 1] = '  he carries: ' .. by[knights[1].id].carried
    end
  end
  return lines
end
function M.run(G, output, smoke)
  local lines = M.report(G, smoke)
  Tooling.write(output, 'depth-meter.txt', lines, smoke)
  for _, line in ipairs(lines) do
    print(line)
  end
end
return M
