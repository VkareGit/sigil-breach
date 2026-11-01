-- Native frames of the moves of the souls plan: a real session in the painted hall,
-- one blow of one creature, seen by a knight who stands and watches it come.
local Review = {}
local MOVES = {
  { 'imp', 'claw-late', 3 },
  { 'imp', 'hop-back', 2 },
  { 'armored', 'cleave', 2.4 },
  { 'armored', 'ground-slam', 3 },
  { 'stolas', 'star-trio', 6 },
  { 'stolas', 'star-ray', 6 },
  { 'stolas', 'slip', 2.5 },
  { 'buer', 'late-bloom', 5 },
  { 'buer', 'root-brace', 2.6 },
  { 'boss', 'cleave', 3 },
  { 'boss', 'overhead', 3.6 },
  { 'boss', 'ash-grip', 2.4 },
  { 'boss', 'ash-ring', 5 },
  { 'boss', 'burning-cut', 3 },
  { 'boss', 'call-embers', 6 },
  { 'boss', 'apse-wave', 7 },
  { 'furfur', 'gore', 2.6 },
  { 'furfur', 'crown', 3 },
  { 'furfur', 'charge', 7 },
  { 'furfur', 'storm-steps', 6 },
  { 'furfur', 'whole-sky', 6 },
}
function Review.run(Game, renderer, output)
  local UI = require('src.ui.interface')
  local Actions = require('src.enemies.actions')
  local Archetypes = require('src.content.enemies')
  local Pools = require('src.session.world')
  local release = require('src.app.release')
  local lg = love.graphics
  UI.useMouse = false
  local function capture(g, name)
    local w, h = 1280, 720
    local canvas = lg.newCanvas(w, h)
    g.view.presentationPrevious = nil
    renderer:resize(w, h)
    renderer:draw(g, w, h)
    lg.push('all')
    lg.setCanvas(canvas)
    lg.origin()
    renderer:present(g, w, h)
    UI.draw(g, w, h, { motion = false, hints = false })
    lg.pop()
    local data = canvas:newImageData()
    local png = data:encode('png')
    local file = assert(io.open(output .. '/' .. name .. '.png', 'wb'))
    file:write(png:getString())
    file:close()
    png:release()
    data:release()
    canvas:release()
  end
  for _, move in ipairs(MOVES) do
    local id, attackId, distance = move[1], move[2], move[3]
    local g = Game.new('field', release.sessionMaps.field, release.sessionOptions.field)
    g.ephemeral, g.state, g.elapsed, g.view.messageTimer = true, 'playing', 70, 0
    g.view.motion = false
    g.time = 12
    local p = g.player
    p.x, p.z, p.yaw, p.pitch = 10, 16 + distance, math.pi, -0.04
    local e = g:spawn(id, 10, 16)
    e.awake, e.visible, e.memory, e.spawnAge, e.target = true, true, 60, 2, p.id
    local attack
    for _, a in ipairs(Archetypes.of(e).attacks) do
      attack = a.id == attackId and a or attack
    end
    Actions.begin(g, e, distance, assert(attack, attackId))
    local shot = 0
    local function step(seconds, label)
      for _ = 1, math.floor(seconds * 120 + 0.5) do
        e.attack = 99
        p.yaw = math.pi
        g:update(1 / 120, {})
      end
      shot = shot + 1
      capture(g, string.format('%s-%s-%d-%s', id, attackId, shot, label))
    end
    step(attack.windup * 0.6, 'windup')
    step(attack.windup * 0.42 + (e.holdLeft or 0), 'release')
    step(0.12, 'strike')
    step(0.45, 'after')
    if #Pools.of(g, 'hazards') > 0 or #Pools.of(g, 'projectiles') > 0 then
      step(0.7, 'late')
    end
  end
end
return Review
