-- The dust and sound of broken things. Nothing here changes the simulation.
local Audio = require('src.audio.audio')
local Context = require('src.session.context')
local Effects = require('src.feedback.effects')
local Scenery = {}
local LOOK = {
  stone = { color = { 0.46, 0.37, 0.26 }, dust = { 0.62, 0.5, 0.38 }, sound = 'thud', volume = 0.3 },
  clay = { color = { 0.5, 0.26, 0.13 }, sound = 'graze', volume = 0.4 },
  wood = { color = { 0.3, 0.2, 0.12 }, sound = 'thud', volume = 0.3 },
  wax = { color = { 0.7, 0.58, 0.36 }, sound = 'graze', volume = 0.14 },
  cloth = { color = { 0.42, 0.09, 0.07 }, sound = 'whoosh', volume = 0.2 },
  iron = { color = { 0.3, 0.27, 0.24 }, sound = 'shell', volume = 0.4 },
}
local function look(kind)
  return LOOK[require('src.content.breakables')[kind].material]
end
local function sound(g, e, name, volume)
  Audio.playAt(name, e.x, e.z, Context.viewer(g), volume, 1, g.world)
end
function Scenery.attach(g, bus)
  bus:on('present', 'SceneryStruck', function(e)
    local l = look(e.thing)
    g:burst(e.x, e.y, e.z, l.color, 8, 1.3)
    sound(g, e, l.sound, l.volume)
    if require('src.content.breakables')[e.thing].sways then
      g.view.sway = g.view.sway or {}
      g.view.sway[e.id] = g.elapsed
    end
  end)
  bus:on('present', 'SceneryBroken', function(e)
    local l = look(e.thing)
    g:burst(e.x, e.y, e.z, l.color, 16, 1.8)
    sound(g, e, l.sound, l.volume * 1.4)
  end)
  bus:on('present', 'StructureCollapsed', function(e)
    local l = look(e.thing)
    for y = 0.5, 8, 1.5 do
      g:burst(e.x, y, e.z, l.color, 22, 3.2)
    end
    for i = 1, 16 do
      local a = i * 2.4
      local reach = 0.6 + i * 0.28
      Effects.emit(
        g,
        'dust',
        e.x + math.cos(a) * reach,
        0.5 + (i % 4) * 0.8,
        e.z + math.sin(a) * reach,
        2.6 + (i % 3) * 1.1,
        {
          vx = math.cos(a) * 0.7,
          vz = math.sin(a) * 0.7,
          tint = l.dust,
        }
      )
    end
    sound(g, e, 'thunder', 1)
    sound(g, e, 'blast', 0.8)
    g.view.shake = math.max(g.view.shake or 0, 0.55)
  end)
end
return Scenery
