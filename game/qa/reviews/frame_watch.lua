-- A fight in the chapel, drawn for real: what a frame costs while it is played, the worst frames
-- and why, and how often the knight wanted to act and could not, by reason.
local Attributes = require('src.combat.attributes')
local Bot = require('qa.souls_bot')
local Pools = require('src.session.world')
local Reload = require('src.combat.reload')
local Way = require('src.run.pilgrimage')
local Profile = require('jit.profile')
local Review = {}
local WIDTH, HEIGHT = 1280, 720
local TICK = 1 / 120
local SECONDS = 60
local function reason(g, p)
  if p.hp <= 0 then
    return 'dead'
  elseif Attributes.forbids(p, 'fire') then
    return 'staggered or drinking'
  elseif Reload.left(g, p) > 0 then
    return 'reloading'
  elseif p.cooldown > 0 then
    return 'cooldown'
  end
end
local function percentile(sorted, share)
  return sorted[math.max(1, math.ceil(#sorted * share))]
end
function Review.run(Game, renderer, output)
  local UI = require('src.ui.interface')
  local lg = love.graphics
  local clock = love.timer.getTime
  love.window.setVSync(0)
  if os.getenv('SIGIL_WATCH_NOGC') then
    collectgarbage('collect')
    collectgarbage('stop')
  end
  UI.useMouse = false
  Way.forget()
  local settings = { motion = true, hints = false, sensitivity = 1, fov = 100, music = 0 }
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  g:act('start')
  g.state = 'playing'
  renderer:resize(WIDTH, HEIGHT)
  -- What the loading page does before play.
  renderer:prepareCreatures(require('src.session.modes').act(g, 'creatures') or {})
  renderer:prepareWorld(g)
  local seed = 7
  local function roll()
    seed = seed * 16807 % 2147483647
    return seed / 2147483647
  end
  local knight, memory = Bot.walker(Bot.human(0.2, roll)), {}
  -- Each system of the step timed, and the dearest of this frame kept.
  local Scheduler = require('src.core.scheduler')
  local World = require('src.world.arena')
  local Navigation = require('src.world.navigation')
  local dearest, dearestName, routes, routeTime = 0, '', 0, 0
  local perSystem, calls = {}, {}
  local plainRun = Scheduler.run
  Scheduler.run = function(self, ...)
    for _, system in ipairs(self.systems) do
      local at = clock()
      local result = system.enabled and system.fn(...)
      local spent = (clock() - at) * 1000
      perSystem[system.name] = (perSystem[system.name] or 0) + spent
      if spent > dearest then
        dearest, dearestName = spent, system.name
      end
      if system.enabled and result == false then
        return false, system.name
      end
      local after = self.after[system.name]
      if after then
        after(...)
      end
    end
    return true
  end
  local function timed(owner, name)
    local plain = owner[name]
    owner[name] = function(...)
      local at = clock()
      local a, b, c, d = plain(...)
      local spent = (clock() - at) * 1000
      routes, routeTime = routes + 1, routeTime + spent
      local entry = calls[name] or { count = 0, total = 0, worst = 0 }
      calls[name] = entry
      entry.count, entry.total = entry.count + 1, entry.total + spent
      entry.worst = math.max(entry.worst, spent)
      return a, b, c, d
    end
    return function()
      owner[name] = plain
    end
  end
  local restoreFlow, restoreWaypoint = timed(World, 'flow'), timed(Navigation, 'waypoint')
  local frames, refused, shots, wanted = {}, {}, 0, 0
  local lastShots = g.player.shots
  local sampled, states, hot = 0, {}, {}
  if os.getenv('SIGIL_WATCH_PROFILE') then
    Profile.start('fi5', function(thread, samples, vmstate)
      sampled = sampled + samples
      states[vmstate] = (states[vmstate] or 0) + samples
      local name = Profile.dumpstack(thread, 'f:l', 1)
      hot[name] = (hot[name] or 0) + samples
    end)
  end
  -- Only frames of play are measured: a death retries, a fire's menu closes at once (the bot
  -- rests when it tries an execution at a fire), and the watch runs until it has a minute of
  -- play or twice as long. The other states are counted, never mixed in.
  local playing, passed, counted = 0, 0, {}
  while playing < SECONDS * 60 and passed < SECONDS * 120 do
    passed = passed + 1
    if g.state == 'dead' then
      g:act('retry')
      memory = {}
    elseif g.state == 'shop' then
      g:act('closeShop')
    end
    dearest, routes, routeTime = 0, 0, 0
    local startedAt, bot = clock(), 0
    local heap = collectgarbage('count')
    for _ = 1, 2 do
      local thinking = clock()
      local input = knight(g, memory, 24, 10.5)
      bot = bot + clock() - thinking
      if input.shoot then
        wanted = wanted + 1
        local why = reason(g, g.player)
        if why then
          refused[why] = (refused[why] or 0) + 1
        end
      end
      g:update(TICK, input)
    end
    local updatedAt = clock()
    g.view.presentationPrevious = nil
    renderer:draw(g, WIDTH, HEIGHT)
    local drawnAt = clock()
    lg.push('all')
    lg.origin()
    renderer:present(g, WIDTH, HEIGHT)
    UI.draw(g, WIDTH, HEIGHT, settings)
    lg.pop()
    lg.present()
    local doneAt = clock()
    shots = shots + (g.player.shots - lastShots)
    lastShots = g.player.shots
    counted[g.state] = (counted[g.state] or 0) + 1
    if g.state == 'playing' then
      playing = playing + 1
      frames[playing] = {
        index = passed,
        total = (doneAt - startedAt - bot) * 1000,
        update = (updatedAt - startedAt - bot) * 1000,
        bot = bot * 1000,
        system = dearestName,
        systemMs = dearest,
        routes = routes,
        routeMs = routeTime,
        collected = heap - collectgarbage('count'),
        draw = (drawnAt - updatedAt) * 1000,
        ui = (doneAt - drawnAt) * 1000,
        bodies = #Pools.of(g, 'enemies'),
        state = g.state,
      }
    end
  end
  if os.getenv('SIGIL_WATCH_PROFILE') then
    Profile.stop()
  end
  Scheduler.run = plainRun
  restoreFlow()
  restoreWaypoint()
  local totals, updates, draws = {}, {}, {}
  for i, f in ipairs(frames) do
    totals[i], updates[i], draws[i] = f.total, f.update, f.draw
  end
  table.sort(totals)
  table.sort(updates)
  table.sort(draws)
  table.sort(frames, function(a, b)
    return a.total > b.total
  end)
  local seen = {}
  for state, count in pairs(counted) do
    seen[#seen + 1] = state .. ' ' .. count
  end
  table.sort(seen)
  local lines = {
    string.format(
      'STATES after each frame: %s (only playing is measured)',
      table.concat(seen, ', ')
    ),
    string.format(
      'PLAY %s: %d frames of play, %d shots',
      playing >= SECONDS * 60 and 'complete' or 'INCOMPLETE',
      playing,
      shots
    ),
    string.format(
      'FRAME ms median %.2f p95 %.2f p99 %.2f max %.2f over %d frames of play',
      percentile(totals, 0.5),
      percentile(totals, 0.95),
      percentile(totals, 0.99),
      totals[#totals],
      #totals
    ),
  }
  lines[#lines + 1] = string.format(
    'PHASES update median %.2f p95 %.2f p99 %.2f; draw median %.2f p95 %.2f p99 %.2f; over 16.7 ms: %d',
    percentile(updates, 0.5),
    percentile(updates, 0.95),
    percentile(updates, 0.99),
    percentile(draws, 0.5),
    percentile(draws, 0.95),
    percentile(draws, 0.99),
    (function()
      local over = 0
      for _, value in ipairs(totals) do
        over = over + (value > 16.7 and 1 or 0)
      end
      return over
    end)()
  )
  for i = 1, 8 do
    local f = frames[i]
    lines[#lines + 1] = string.format(
      'WORST frame %d total %.1f update %.1f (%s %.1f; %d routes %.1f) draw %.1f ui %.1f bodies %d %s',
      f.index,
      f.total,
      f.update,
      f.system,
      f.systemMs,
      f.routes,
      f.routeMs,
      f.draw,
      f.ui,
      f.bodies,
      f.state
    )
  end
  for state, count in pairs(states) do
    lines[#lines + 1] = string.format('VMSTATE %s %.1f%%', state, count * 100 / sampled)
  end
  local spots = {}
  for name, count in pairs(hot) do
    spots[#spots + 1] = { name, count }
  end
  table.sort(spots, function(a, b)
    return a[2] > b[2]
  end)
  for i = 1, math.min(24, #spots) do
    lines[#lines + 1] = string.format('HOT %.1f%% %s', spots[i][2] * 100 / sampled, spots[i][1])
  end
  local names = {}
  for name in pairs(perSystem) do
    names[#names + 1] = name
  end
  table.sort(names, function(a, b)
    return perSystem[a] > perSystem[b]
  end)
  for i = 1, 7 do
    lines[#lines + 1] = string.format('SYSTEM %s %.0f ms in all', names[i], perSystem[names[i]])
  end
  for name, entry in pairs(calls) do
    lines[#lines + 1] = string.format(
      'CALL %s %d calls, %.0f ms in all, worst %.1f',
      name,
      entry.count,
      entry.total,
      entry.worst
    )
  end
  lines[#lines + 1] = string.format('TRIGGER held %d ticks, %d shots', wanted, shots)
  for why, count in pairs(refused) do
    lines[#lines + 1] =
      string.format('REFUSED %s %d ticks (%.0f%%)', why, count, count * 100 / wanted)
  end
  local file = assert(io.open(output .. '/frame-watch.txt', 'w'))
  file:write(table.concat(lines, '\n') .. '\n')
  file:close()
  for _, line in ipairs(lines) do
    print(line)
  end
  Way.forget()
end
return Review
