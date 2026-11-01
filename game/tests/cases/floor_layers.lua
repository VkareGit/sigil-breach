-- Plan v10 V3: floor layers. The diagnostic map qa_bridge (256 x 128, a
-- deck 2.9 m high on stairs over open floor, 200 braziers): bodies walk over
-- and under the bridge, shots and missiles pass over and under it, thrown
-- charges land on it, routes run on both levels, every brazier near the
-- camera is lit and the deck keeps light from the other side.
local Fixtures = require('tests.support.fixtures')
local Maps = require('src.content.maps.index')
local World = require('src.world.arena')
local Ground = require('src.physics.ground')
local SphereCast = require('src.physics.sphere_cast')
local Flight = require('src.physics.ordnance_flight')
local Tuning = require('src.content.tuning')
local Rules = require('src.combat.rules')
local Roles = require('src.core.roles')
local Navigation = require('src.world.navigation')
local Bridge = require('qa.data.bridge_map')
local Tests = {}
local TOP, BOTTOM = 2.9, 2.6
local function near(a, b)
  return math.abs(a - b) < 1e-6
end
-- Walk a probe body in steps of 0.1 m toward (tx, tz).
local function walk(w, o, tx, tz, height)
  for _ = 1, 4000 do
    local dx, dz = tx - o.x, tz - o.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 1e-6 then
      return true
    end
    local s = math.min(0.1, d)
    local _, _, blocked = World.move(w, o, dx / d * s, dz / d * s, 0.3, nil, height)
    if blocked then
      return false
    end
  end
  return false
end
function Tests.run(Game, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'floor layers: ', 'floor layers: ')
  Maps:register(Bridge.id, Bridge)
  local ok, problem = pcall(function()
    local g = Game.new('floor', Bridge.id)
    g.ephemeral = true
    local w = g.world
    check(
      'a cell may carry a deck over its floor: the ground depends on the height asked from',
      w.decks ~= nil
        and near(Ground.height(w, 120, 64), 0)
        and near(Ground.height(w, 120, 64, 3), TOP)
        and near(Ground.ceiling(w, 120, 64, 0), BOTTOM)
        and #w.lamps == 200
    )
    -- Over: up the west stairs, along the deck.
    local over = { x = 83, z = 64, jump = 0 }
    local walked = walk(w, over, 130, 64, 1.8)
    check(
      'a body climbs the stairs and walks the bridge, standing on the deck',
      walked and near(Ground.of(w, over), TOP) and over.jump == 0 and near(over.level, TOP)
    )
    walk(w, over, 130, 58, 1.8)
    check(
      'walking off the side of the bridge it falls to the floor beneath',
      near(Ground.of(w, over), 0) and near(over.jump, TOP)
    )
    -- Under: along the floor beneath the deck.
    local under = { x = 120, z = 56, jump = 0 }
    walked = walk(w, under, 120, 64, 1.8) and walk(w, under, 150, 64, 1.8)
    check(
      'a body walks the floor under the bridge and keeps that floor',
      walked and near(Ground.of(w, under), 0) and under.jump == 0
    )
    local tall = { x = 120, z = 56, jump = 0 }
    check(
      'a body taller than the room under the deck is stopped at its edge',
      not walk(w, tall, 120, 64, 3.4) and tall.z < 61.5
    )
    local knight = Roles.controlled(g)
    knight.x, knight.z, knight.jump, knight.level = 120, 64, 0, 0
    local air, velocity = Rules.ceiling(g, knight, 1.5, 4)
    check(
      "the deck's underside stops a jump beneath it",
      near(air, BOTTOM - require('src.content.characters').standard().body.height) and velocity == 0
    )
    -- Shots and missiles: rays over the deck, under it, into it.
    local floor = Tuning.floorSurface
    local _, _, along = SphereCast.world(w, 100, TOP + 1.38, 64, 1, 0, 0, 50, 0, floor)
    local _, _, beneath = SphereCast.world(w, 100, 1.38, 64, 1, 0, 0, 50, 0, floor)
    local up, upNormal = SphereCast.world(w, 120, 1, 64, 0, 1, 0, 5, 0, floor)
    local down, _, downKind = SphereCast.world(w, 120, 6, 64, 0, -1, 0, 6, 0.1, floor)
    check(
      'a shot runs the length of the bridge over it, and of the hall under it',
      along == 'range' and beneath == 'range'
    )
    check(
      'a shot rising under the bridge meets its underside; a missile falling on it its top',
      near(up, BOTTOM - 1)
        and upNormal[2] == -1
        and downKind == 'wall'
        and near(down, 6 - TOP - floor - 0.1)
    )
    -- A thrown charge lands on the deck; one thrown up beneath it falls back.
    local K = Tuning.explosives
    local onDeck = { x = 120, y = 4, z = 64, vx = 0.5, vy = 0, vz = 0 }
    Flight.advance(w, onDeck, 2, Tuning.gravity, floor, K)
    local beneathDeck = { x = 120, y = 1, z = 64, vx = 0, vy = 9, vz = 0 }
    Flight.advance(w, beneathDeck, 2, Tuning.gravity, floor, K)
    check(
      'a thrown charge comes to rest on the deck, one thrown up under it falls back to the floor',
      onDeck.grounded and math.abs(onDeck.y - TOP - floor) < 1e-3 and beneathDeck.y < 0.1
    )
    -- Routes on both levels: the field around a goal on the deck.
    local field = World.flow(w, 100, 64, 0, TOP)
    local onTop, below = field[World.node(w, 110, 64, 1)], field[World.node(w, 110, 64, 0)]
    check(
      'a field reaches a goal on the deck along the deck, and from the floor below by the stairs',
      onTop == 10 and below ~= nil and below > 40
    )
    local fieldBelow = World.flow(w, 130, 64, 0)
    check(
      'a goal on the floor under the bridge is reached along that floor',
      fieldBelow[World.node(w, 110, 64, 0)] == 20 and fieldBelow[World.node(w, 110, 64, 1)] ~= nil
    )
    check(
      'beyond the window the regions lead from the far hall up onto the bridge',
      Navigation.distance(w, 30, 64, 130, 64, 0, nil, TOP) ~= nil
    )
    -- A demon on the floor reaches the knight standing on the bridge.
    knight.x, knight.z, knight.level, knight.jump = 128, 64, TOP, 0
    g.state = 'playing'
    local demon = g:spawn('imp', 70, 58)
    demon.awake, demon.memory, demon.attack, demon.spawnAge = true, 1e9, 1e9, 1
    for _ = 1, 120 * 60 do
      demon.lastX, demon.lastZ, demon.lastLevel, demon.visible =
        knight.x, knight.z, knight.level, false
      demon.sense, demon.attack = 1, 1e9
      g:update(1 / 120, {})
      knight.x, knight.z, knight.level, knight.jump = 128, 64, TOP, 0
      if math.abs(demon.x - knight.x) + math.abs(demon.z - knight.z) < 3 then
        break
      end
    end
    check(
      'a demon on the floor climbs the stairs and reaches a knight on the bridge',
      math.abs(demon.x - knight.x) + math.abs(demon.z - knight.z) < 3
        and near(Ground.of(w, demon), TOP)
    )
    -- Every brazier near the camera burns in a light slot.
    local Lights = require('src.render.lights')
    local lighting = Lights.new()
    local lit = true
    for _, at in ipairs({ { 40, 64 }, { 128, 64 }, { 200, 30 }, { 100, 100 } }) do
      lighting:update(g, { at[1], 1.6, at[2] }, { 1, 0, 0 })
      for _, lamp in ipairs(w.lamps) do
        local dx, dz = lamp.x - at[1], lamp.z - at[2]
        if dx * dx + dz * dz < Lights.reach * Lights.reach then
          local found = false
          for i = 1, Lights.capacity do
            local s = lighting.slots[i]
            found = found or (s and s.lamp == lamp and lighting.colors[i][1] > 0)
          end
          lit = lit and found
        end
      end
    end
    check(
      'all braziers near the camera are lit, the rest reported',
      lit and #lighting.sources >= 200 and lighting.report.left > 0
    )
    -- The deck keeps the light of a brazier on the bridge from the floor
    -- under it; the deck's top and the floor beside the bridge receive it.
    local deckLamp
    for _, lamp in ipairs(w.lamps) do
      if lamp.x == 100 and lamp.z == 64 then
        deckLamp = lamp
      end
    end
    local Mesh = require('src.render.mesh')
    local lg = love.graphics
    local target = lg.newCanvas(128, 128)
    local s = renderer.shader
    local function shade(y, z1, z2, enabled)
      lighting:update(g, { 100, 1.6, 64 }, { 1, 0, 0 })
      for i = 1, 16 do
        local slot = lighting.slots[i]
        if not (enabled and slot and slot.lamp == deckLamp) then
          lighting.colors[i] = { 0, 0, 0 }
        end
      end
      local vertices = {}
      Mesh.quad(
        vertices,
        { 98, y, z1 },
        { 98, y, z2 },
        { 102, y, z2 },
        { 102, y, z1 },
        { 0.3, 0.3, 0.3 }
      )
      local mesh = Mesh.finish(vertices)
      lg.push('all')
      lg.setCanvas(target)
      lg.origin()
      lg.setShader(s)
      lg.setDepthMode()
      lg.clear(0, 0, 0, 1)
      lg.setColor(1, 1, 1)
      s:send('camera', { 100, y + 8, (z1 + z2) / 2 })
      s:send('rightDir', { 1, 0, 0 })
      s:send('upDir', { 0, 0, -1 })
      s:send('forwardDir', { 0, -1, 0 })
      s:send('aspect', 1)
      s:send('projectionScale', 4)
      s:send('objectPos', { 0, 0, 0 })
      s:send('objectYaw', 0)
      s:send('objectScale', 1)
      s:send('flash', 0)
      s:send('flashColor', { 1, 1, 1 })
      s:send('tint', { 1, 1, 1 })
      s:send('objectAlpha', 1)
      lighting:bind(s)
      lg.draw(mesh)
      lg.pop()
      local data = target:newImageData()
      local r, green, b = data:getPixel(64, 64)
      data:release()
      mesh:release()
      return r * 0.3 + green * 0.59 + b * 0.11
    end
    local underLit, underDark = shade(0, 62.2, 65.8, true), shade(0, 62.2, 65.8, false)
    local topLit, topDark = shade(TOP, 62.2, 65.8, true), shade(TOP, 62.2, 65.8, false)
    local besideLit, besideDark = shade(0, 57.5, 61.5, true), shade(0, 57.5, 61.5, false)
    check(
      'a brazier on the bridge lights its deck and the floor beside it, not the floor beneath',
      deckLamp ~= nil
        and topLit - topDark > 0.04
        and besideLit - besideDark > 0.01
        and math.abs(underLit - underDark) < 0.004
    )
    target:release()
    lighting:release()
    -- The whole frame of the bridge map draws.
    renderer:draw(g, 320, 180)
    check('the renderer draws the bridge map (decks in the world mesh)', true)
  end)
  Maps:unregister(Bridge.id)
  assert(ok, problem)
  return lines
end
return Tests
