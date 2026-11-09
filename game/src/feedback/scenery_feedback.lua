-- The dust and sound of broken things. Nothing here changes the simulation.
local Impulses = require('src.feedback.impulses')
local Breakables = require('src.content.breakables')
local Audio = require('src.audio.audio')
local Context = require('src.session.context')
local FX = require('src.feedback.effects')
local Scenery = {}
local Look = require('src.content.scenery_look')
local function look(kind)
  return Look.materials[Breakables[kind].material]
end
local function sound(g, e, name, volume)
  Audio.playAt(name, e.x, e.z, Context.viewer(g), volume, 1, g.world)
end
function Scenery.attach(g, bus)
  bus:on('present', 'SceneryStruck', function(e)
    local l = look(e.thing)
    g:burst(e.x, e.y, e.z, l.color, Look.struck.fragments, Look.struck.speed)
    sound(g, e, l.sound, l.volume)
    if Breakables[e.thing].sways then
      g.view.sway = g.view.sway or {}
      g.view.sway[e.id] = g.elapsed
    end
  end)
  bus:on('present', 'SceneryBroken', function(e)
    local l = look(e.thing)
    g:burst(e.x, e.y, e.z, l.color, Look.broken.fragments, Look.broken.speed)
    sound(g, e, l.sound, l.volume * Look.broken.loudness)
  end)
  bus:on('present', 'StructureCollapsed', function(e)
    local l, C = look(e.thing), Look.collapse
    for y = C.bottom, C.top, C.every do
      g:burst(e.x, y, e.z, l.color, C.fragments, C.speed)
    end
    for i = 1, C.puffs do
      local a = i * C.turn
      local reach = C.reach + i * C.reachStep
      FX.emit(
        g,
        'dust',
        e.x + math.cos(a) * reach,
        C.height + (i % C.heights) * C.heightStep,
        e.z + math.sin(a) * reach,
        C.size + (i % C.sizes) * C.sizeStep,
        {
          vx = math.cos(a) * C.drift,
          vz = math.sin(a) * C.drift,
          tint = l.dust,
        }
      )
    end
    sound(g, e, 'thunder', C.thunder)
    sound(g, e, 'blast', C.blast)
    Impulses.react(g.view, 'collapse')
  end)
end
return Scenery
