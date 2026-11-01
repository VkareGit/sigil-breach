local Fixtures = require('tests.support.fixtures')
local Weapons = require('src.content.weapons')
local Tuning = require('src.content.tuning')
local Tests = {}
function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'v16 ', '')
  require('tests.cases.animation').run(G, check)
  require('tests.cases.typography').run(check)
  local Art = require('src.content.weapon_art')
  local V = require('src.render.weapon')
  local Reload = require('src.combat.reload')
  for slot = 1, 2 do
    local m = Art[Art.ids[slot]]
    local data = love.image.newImageData(m.path)
    check(
      'weapon ' .. slot .. ' uses its explicit active atlas manifest',
      V.paths[Art.ids[slot]] == m.path
        and data:getWidth() == m.width
        and data:getHeight() == m.height
        and #m.frames > 0
        and #V.quads[Art.ids[slot]] == #m.frames
    )
    for index, frame in ipairs(m.frames) do
      local r = frame.rect
      local grip = frame.grip
      local muzzle = frame.muzzle
      check(
        'weapon ' .. slot .. ' frame ' .. index .. ' has registered anchors inside its crop',
        r[1] >= 0
          and r[2] >= 0
          and r[1] + r[3] <= m.width
          and r[2] + r[4] <= m.height
          and grip[1] >= 0
          and grip[1] < r[3]
          and grip[2] > 0
          and grip[2] <= r[4]
          and (
            not muzzle
            or (muzzle[1] >= 0 and muzzle[1] < r[3] and muzzle[2] >= 0 and muzzle[2] < r[4])
          )
      )
      local top, bottom = 0, 0
      for x = r[1], r[1] + r[3] - 1 do
        local _, _, _, a = data:getPixel(x, r[2])
        top = top + (a > 0.6 and 1 or 0)
        local _, _, _, b = data:getPixel(x, r[2] + r[4] - 1)
        bottom = bottom + (b > 0.6 and 1 or 0)
      end
      check(
        'weapon ' .. slot .. ' frame ' .. index .. ' row gutters do not cut the painted silhouette',
        top < 4 and bottom < 4
      )
    end
    local firing = { m.ready }
    for _, phase in ipairs(m.phases.fire) do
      firing[#firing + 1] = phase.frame
    end
    for _, name in ipairs(firing) do
      local index = Art.frame(m, name)
      local definition = Weapons.get(Art.ids[slot])
      for rounds = 0, definition.ammo.capacity do
        check(
          'weapon ' .. slot .. ' firing pose ' .. name .. ' rounds ' .. rounds .. ' has a muzzle',
          m.frames[Art.variant(m, index, rounds)].muzzle ~= nil
        )
      end
    end
    data:release()
    local g = G.new('floor')
    g.ephemeral = true
    g.state = 'playing'
    g.player.weapon = slot
    g.view.shotAge = 10
    g.player.arsenal.exorcist.mag = 0
    g.player.arsenal.exorcist.reserve = 1
    g.player.arsenal.judge.mag = 0
    g.player.arsenal.judge.reserve = 3
    assert(Reload.start(g, true))
    local physical = slot == 1
        and {
          close = Tuning.reload.breech.close,
          load = Tuning.reloadLoadTime,
        }
      or { close = Tuning.revolverCloseTime, load = Tuning.revolverLoadTime }
    local beforePhase, afterPhase
    for index, phase in ipairs(m.phases.reload) do
      if math.abs(phase.finish - physical.close) < 1e-9 then
        beforePhase, afterPhase = phase, m.phases.reload[index + 1]
      end
    end
    check(
      'weapon ' .. slot .. ' artwork has a boundary at its physical latch',
      beforePhase ~= nil and afterPhase ~= nil
    )
    Reload.update(g, physical.close - Reload.age(g) - 1e-5)
    local state = Weapons.state(g)
    local before, wasOpen = V.sourceFrame(g), state.open
    Reload.update(g, 2e-5)
    local after = V.sourceFrame(g)
    check(
      'weapon ' .. slot .. ' visual latch changes at the physical commit',
      wasOpen
        and not state.open
        and before == Art.variant(m, Art.frame(m, beforePhase.frame), state.mag)
        and after == Art.variant(m, Art.frame(m, afterPhase.frame), state.mag)
        and before ~= after
    )
    Reload.cancel(g)
    state.open = true
    local openName = Reload.mechanism(g, slot).primed(state) and m.open.primed or m.open.empty
    check(
      'weapon ' .. slot .. ' cancelled open reload keeps its actual round count visible',
      V.sourceFrame(g) == Art.variant(m, Art.frame(m, openName), state.mag)
    )
    g.player.arsenal.exorcist.open = false
    g.player.arsenal.judge.open = false
    g.view.shotAge = 0.02
    check(
      'weapon ' .. slot .. ' discharge selects the authored recoil and attached powder',
      V.sourceFrame(g) == Art.variant(m, Art.frame(m, m.phases.fire[1].frame), state.mag)
        and V.muzzlePhase(g) ~= nil
    )
    g.player.reload = 0
    g.player.reloadWeapon = nil
    g.view.shotAge = 10
    g.player.arsenal.exorcist.mag = 0
    g.player.arsenal.exorcist.reserve = 2
    g.player.arsenal.judge.mag = 0
    g.player.arsenal.judge.reserve = 6
    assert(Reload.start(g, true))
    -- The painted rounds a pose shows (content/weapon_art.lua roundsSource):
    -- the chambers' for 'magazine'; for a reload in progress only what this
    -- transaction can transfer, min(capacity - mag, reserve): all of it in a
    -- held loader ('pending'), or pushed home but for inHand ('loading').
    local function shown(name, state)
      local index = Art.frame(m, name)
      local frame, count = m.frames[index], state.mag
      local pending = math.min(Weapons.inHand(g).ammo.capacity - state.mag, state.reserve)
      if frame.roundsSource == 'pending' then
        count = pending
      elseif frame.roundsSource == 'loading' then
        count = state.mag + math.max(0, pending - frame.inHand)
      end
      return Art.variant(m, index, count)
    end
    local honest, visited = true, {}
    for _ = 1, math.ceil(Reload.mechanism(g, slot).duration * 240) + 2 do
      local frame = V.sourceFrame(g)
      local age = Reload.age(g)
      local state = Weapons.state(g)
      local expectedName = m.reloadComplete
      for _, phase in ipairs(m.phases.reload) do
        if age < phase.finish then
          expectedName = phase.frame
          break
        end
      end
      if g.player.reload > 0 then
        visited[expectedName] = true
        honest = honest
          and frame == shown(expectedName, state)
          and (age < physical.load or state.mag == Weapons.inHand(g).ammo.capacity)
          and (age < physical.close or not state.open)
        if m.frames[frame].action == 'loaded' then
          honest = honest and age >= physical.load and Reload.mechanism(g, slot).primed(state)
        end
      end
      Reload.update(g, 1 / 240)
    end
    for _, phase in ipairs(m.phases.reload) do
      honest = honest and visited[phase.frame] == true
    end
    check(
      'weapon '
        .. slot
        .. ' reaches every full reload phase without preceding ammunition or latch transactions',
      honest
    )
  end
  return lines
end
return Tests
