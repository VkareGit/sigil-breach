-- The chapel as the player meets it, one frame of each place worth looking at.
local Way = require('src.run.pilgrimage')
local K = require('src.content.pilgrimage')
local Ballistics = require('src.combat.ballistics')
local Pools = require('src.session.world')
local Review = {}
local WIDTH, HEIGHT = 1280, 720
function Review.run(Game, renderer, output)
  local UI = require('src.ui.interface')
  local lg = love.graphics
  UI.useMouse = false
  Way.forget()
  local canvas = lg.newCanvas(WIDTH, HEIGHT)
  local settings = { motion = true, hints = false, sensitivity = 1, fov = 100, music = 0 }
  local function shot(g, name)
    g.view.presentationPrevious = nil
    renderer:resize(WIDTH, HEIGHT)
    renderer:draw(g, WIDTH, HEIGHT)
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    renderer:present(g, WIDTH, HEIGHT)
    UI.draw(g, WIDTH, HEIGHT, settings)
    lg.pop()
    local data = canvas:newImageData()
    local png = data:encode('png')
    local file = assert(io.open(output .. '/look-' .. name .. '.png', 'wb'))
    file:write(png:getString())
    file:close()
    png:release()
    data:release()
  end
  local g = Game.new('pilgrimage')
  g.ephemeral = true
  shot(g, 'menu')
  g:act('start')
  g:start()
  g.state = 'playing'
  g.view.messageTimer, g.zoneTimer = 0, 0
  for _ = 1, 30 do
    g:update(1 / 120, {})
  end
  shot(g, 'first-fire')
  require('src.combat.rules').addCondition(g.player, 'staggered', 1)
  shot(g, 'off-balance')
  g.player.conditions.staggered = nil
  g.view.refusal, g.view.refusalTimer = 'hud_no_breath', 1
  g.player.resources.stamina = -5
  shot(g, 'no-breath')
  g.view.hitmarker, g.view.lastKill, g.view.killPop = 0.3, true, 0.04
  g.view.soulsGain, g.view.soulsGainTimer = 140, 1
  shot(g, 'kill-confirm')
  g.player.chainCount, g.player.chainLeft = 3, 4
  g.player.chainWeapon = g.player.loadout[1]
  g.view.medal, g.view.medalTimer = 'triptych', 1
  shot(g, 'chain')
  -- The body in the sights: its bar before the blows, then their sum and pale trail.
  local foe = Pools.of(g, 'enemies')[1]
  local dx, _, dz = Ballistics.direction(g.player.yaw, g.player.pitch)
  foe.x, foe.z = g.player.x + dx * 5, g.player.z + dz * 5
  g.view.medalTimer = 0
  shot(g, 'target-whole')
  foe.hp = foe.hp * 0.55
  shot(g, 'target-trail')
  g.player.chainCount, g.player.chainLeft, g.view.medalTimer = nil, nil, 0
  g.view.hitmarker, g.view.lastKill, g.view.killPop, g.view.soulsGainTimer = 0, false, 0, 0
  g.view.refusalTimer, g.player.resources.stamina = 0, 100
  local p = g.player
  local area = K.start()
  for _, fire in ipairs(area.fires) do
    p.x, p.z, p.yaw, p.pitch = fire.x, fire.z + 3, math.pi, 0
    g:update(1 / 120, {})
    shot(g, 'fire-' .. fire.id)
  end
  p.x, p.z = area.fires[2].x, area.fires[2].z + 1
  g:interact()
  shot(g, 'fire-menu')
  g:act('closeShop')
  for _, door in ipairs(area.doors) do
    for _, name in ipairs({ 'side', 'back' }) do
      local at = door[name]
      p.x, p.z = at.x, at.z
      p.yaw = math.atan2(at.art.x - p.x, at.art.z - p.z)
      p.pitch = 0
      g:update(1 / 120, {})
      g.view.messageTimer = 0
      shot(g, 'door-' .. door.id .. '-' .. name)
    end
    g.run.opened[door.id] = true
    p.x, p.z = door.side.x, door.side.z
    p.yaw = math.atan2(door.side.art.x - p.x, door.side.art.z - p.z)
    g:update(1 / 120, {})
    shot(g, 'door-' .. door.id .. '-open')
  end
  g.map = true
  shot(g, 'map')
  g.map = false
  g.help = true
  shot(g, 'help')
  g.help = false
  g.state = 'paused'
  shot(g, 'pause')
  g.state = 'playing'
  p.armor, p.invuln = 0, 0
  g.run.wallet = 480
  g:damagePlayer(1000)
  shot(g, 'dead')
  Way.forget()
end
return Review
