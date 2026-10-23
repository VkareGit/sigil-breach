-- AI behaviour audit (0.24): watches every demon's state machine from the
-- outside and reports loops â€” wind-ups cancelled before a strike, attacks
-- that never connect, long orbits without attacking, bodies stuck in place.
-- Report only; the player is invincible and never shoots.
local S = {}
local function run(G, label, steer)
  local Field = require('src.run.test_field')
  local g = Field.new(G)
  g.testing = true
  Field.reset(g)
  Field.close(g)
  g.testField.invincible = true
  local p = g.player
  p.x, p.z, p.yaw = 16, 17, math.pi
  local spawn = {
    { 'imp', 16, 11 },
    { 'imp', 10, 17 },
    { 'armored', 22, 17 },
    { 'stolas', 16, 23 },
    { 'buer', 12, 12 },
  }
  local stats, watch = {}, {}
  for _, s in ipairs(spawn) do
    local e = g:spawn(s[1], s[2], s[3])
    e.awake, e.memory, e.spawnAge = true, 60, 1
    local key = e.variant or e.kind
    stats[key] = stats[key]
      or { windups = 0, strikes = 0, cancels = 0, hits = 0, orbit = 0, stuck = 0, longestOrbit = 0 }
    watch[#watch + 1] =
      { e = e, key = key, prev = e.ai, orbit = 0, lastX = e.x, lastZ = e.z, still = 0 }
  end
  local hitsBefore = 0
  local seconds = 60
  for tick = 1, seconds * 120 do
    local input = steer(g, tick / 120) or {}
    g:update(1 / 120, input)
    for _, w in ipairs(watch) do
      local e, st = w.e, stats[w.key]
      if e.hp > 0 then
        if w.prev ~= 'windup' and e.ai == 'windup' then
          st.windups = st.windups + 1
        end
        if w.prev == 'windup' and e.ai == 'strike' then
          st.strikes = st.strikes + 1
        end
        if w.prev == 'windup' and (e.ai == 'recover' or e.ai == 'move' or e.ai == 'idle') then
          st.cancels = st.cancels + 1
        end
        -- Orbit: moving near the player without beginning an attack.
        local d = math.sqrt((e.x - p.x) ^ 2 + (e.z - p.z) ^ 2)
        if e.ai == 'move' and d < 4 then
          w.orbit = w.orbit + 1 / 120
          st.longestOrbit = math.max(st.longestOrbit, w.orbit)
          st.orbit = st.orbit + 1 / 120
        elseif e.ai ~= 'move' then
          w.orbit = 0
        end
        -- Stuck: in 'move' but not displaced for a while.
        local moved = math.abs(e.x - w.lastX) + math.abs(e.z - w.lastZ)
        if e.ai == 'move' and moved < 1e-4 then
          w.still = w.still + 1 / 120
          if w.still > 0.5 then
            st.stuck = st.stuck + 1 / 120
          end
        else
          w.still = 0
        end
        w.lastX, w.lastZ, w.prev = e.x, e.z, e.ai
      end
    end
  end
  local lines = { 'AI AUDIT / ' .. label .. ' / ' .. seconds .. ' s, invincible idle player' }
  for _, key in ipairs({ 'imp', 'armored', 'stolas', 'buer' }) do
    local st = stats[key]
    if st then
      lines[#lines + 1] = string.format(
        '%-8s windups %3d  strikes %3d  cancelled %3d  orbit %.1f s (longest %.1f s)  stuck %.1f s',
        key,
        st.windups,
        st.strikes,
        st.cancels,
        st.orbit,
        st.longestOrbit,
        st.stuck
      )
    end
  end
  lines[#lines + 1] = string.format('attacks begun: %d', g.attackStarts or 0)
  return lines, stats
end
function S.run(G)
  local all, results = {}, {}
  local scenarios = {
    {
      'standing',
      function()
        return {}
      end,
    },
    {
      'circling',
      function(g, t)
        local p = g.player
        p.yaw = math.pi + t * 0.6
        return { strafe = 1 }
      end,
    },
  }
  for _, s in ipairs(scenarios) do
    local lines, stats = run(G, s[1], s[2])
    results[s[1]] = stats
    for _, line in ipairs(lines) do
      all[#all + 1] = line
    end
    all[#all + 1] = ''
  end
  local f = assert(io.open(require('qa.output').path('ai-audit.txt'), 'w'))
  f:write(table.concat(all, '\n'))
  f:close()
  print(table.concat(all, '\n'))
  return results
end
return S
