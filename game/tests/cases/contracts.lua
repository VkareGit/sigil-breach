-- PLAN F5: contracts proven on data, generated from the definitions. Every
-- attack of every creature lives its whole life in one plain room: it begins,
-- releases, ends and leaves nothing of itself; a body that dies in the middle
-- of one lets go of what it marked. Every creature's package holds what its
-- definition names: its atlas, anatomy, words and voices.
local T = {}
function T.run(Game)
  local F = require('tests.support.fixtures')
  local A = require('src.content.enemies')
  local Actions = require('src.enemies.actions')
  local World = require('src.world.arena')
  local Tiles = require('src.core.tiles')
  local Pools = require('src.session.world')
  local lines, failures = {}, {}
  local function check(name, ok)
    lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. 'contracts: ' .. name
    if not ok then
      failures[#failures + 1] = name
    end
  end
  local function room(id, distance)
    local g = F.arena(Game)
    for z = 8, 30 do
      for x = 8, 26 do
        World.setCell(g.world, x, z, Tiles.floor)
      end
    end
    local p = g.player
    p.x, p.z, p.yaw, p.armor, p.hp, p.maxHp = 16, 15 + distance, math.pi, 0, 1e6, 1e6
    local e = g:spawn(id, 16, 15)
    e.target, e.awake, e.visible, e.memory, e.spawnAge, e.facing, e.sense =
      p.id, true, true, 60, 2, 0, 10
    g.rng.sim:seed(1)
    return g, e
  end
  local busy = { windup = true, strike = true, recover = true }
  local function step(g, e)
    e.attack, e.chain = 999, nil
    e.answered =
      { dodged = 999, behind = 999, hugging = 999, drinking = 999, reloading = 999, sniped = 999 }
    g:update(1 / 120, {})
  end
  local function finite(v)
    return type(v) == 'number' and v == v and v > -math.huge and v < math.huge
  end
  local function owned(g, e)
    local foreign, waiting = 0, 0
    for _, pool in ipairs({ 'hazards', 'projectiles' }) do
      for _, thing in ipairs(Pools.of(g, pool)) do
        if thing.owner ~= nil and thing.owner ~= e.id then
          foreign = foreign + 1
        elseif pool == 'hazards' and thing.owner == e.id and (thing.delay or 0) > 0 then
          waiting = waiting + 1
        end
      end
    end
    return foreign, waiting
  end
  for _, id in ipairs(A.creatures) do
    for _, spec in ipairs(A.get(id).attacks) do
      local name = id .. '/' .. spec.id
      local distance = math.max(spec.minRange or 0, math.min(spec.range or 2, 2.5))
      -- Its whole life: it runs to its end, or it declines at once (a harvest
      -- with nothing sown), and it leaves only what it owns.
      local g, e = room(id, distance)
      local struck, left, declined = false, false, false
      local ran, err = pcall(function()
        Actions.begin(g, e, distance, spec)
        for i = 1, 120 * 15 do
          step(g, e)
          struck = struck or e.ai == 'strike'
          if not busy[e.ai] then
            left, declined = struck, not struck and i <= 120
            break
          end
        end
      end)
      local foreign = owned(g, e)
      check(
        name .. ' (' .. spec.kind .. ') runs its life or declines, and leaves only its own',
        ran and (left or declined) and foreign == 0 and finite(e.x) and finite(e.z)
      )
      if not ran then
        lines[#lines + 1] = 'FAIL contracts: ' .. name .. ': ' .. tostring(err)
      end
      -- Struck down in its windup or at its release: what it marked is let
      -- go, nothing it owns waits to strike.
      for _, moment in ipairs({ 'windup', 'strike' }) do
        g, e = room(id, distance)
        local dead, waiting = pcall(function()
          Actions.begin(g, e, distance, spec)
          for _ = 1, 120 * 15 do
            step(g, e)
            if moment == 'windup' and e.ai == 'windup' and e.windup <= e.windupDuration * 0.5 then
              break
            elseif e.ai == 'strike' then
              break
            end
          end
          g:damageEnemy(e, e.hp + 1, 'weapon', nil, g.player.id)
          for _ = 1, 120 * 3 do
            g:update(1 / 120, {})
          end
          return select(2, owned(g, e))
        end)
        check(
          name .. ' struck down in its ' .. moment .. ' leaves no mark waiting',
          dead and waiting == 0
        )
      end
    end
  end
  -- Every creature's package holds what its definition names (PLAN F4).
  local Atlases = require('src.content.art.atlases')
  local Anatomy = require('src.content.art.anatomy.index')
  local Masks = require('src.content.art.hit_masks')
  local Text = require('src.content.text')
  for _, id in ipairs(A.creatures) do
    local def = A.get(id)
    local atlas = def.appearance and def.appearance.atlas or id
    check(
      id .. ' has its atlas, anatomy, masks and words',
      Atlases.sheets[atlas] ~= nil
        and Anatomy[atlas] ~= nil
        and Masks.layouts[atlas] ~= nil
        and Text.has('creature_' .. id)
    )
  end
  if #failures > 0 then
    error(table.concat(lines, '\n'), 0)
  end
  return lines
end
return T
