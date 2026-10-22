-- The simulation's only door to presentation (0.24 F1, dependency inversion).
-- Simulation code never requires feedback, render, ui or audio (tools/check):
-- it calls a named hook here, and presentation registers the hooks when it is
-- loaded (src/feedback/install.lua, from the application). Without a
-- presentation (a headless simulation, a server, a fast bot) every hook is a
-- no-op and the simulation runs the same, bit for bit.
--   hook(name, fn)          presentation: fn(g, ...) answers call(g, name, ...)
--   call(g, name, ...)      simulation: run the hook now, if any
--   stage(name)             a scheduler entry that calls hook name(g, dt)
--   attacher(fn)            presentation: fn(g) attaches its event listeners
--   attach(g)               a new session gets every attacher
--   cue(g, sound, volume, x, z)  a sound, at a place when x and z are given
-- Hooks run at the moment they are called (not deferred like 'present'
-- events), so effects keep their exact timing inside a step. A record with
-- no presentation state (no g.view: a hand-made fixture) is not presented.
local Presentation = { hooks = {}, attachers = {} }
function Presentation.hook(name, fn)
  Presentation.hooks[name] = fn
end
function Presentation.call(g, name, ...)
  local fn = Presentation.hooks[name]
  if fn and g and g.view then
    return fn(g, ...)
  end
end
function Presentation.stage(name)
  return {
    name = name,
    run = function(g, dt)
      local fn = Presentation.hooks[name]
      if fn and g.view then
        fn(g, dt)
      end
    end,
  }
end
function Presentation.attacher(fn)
  Presentation.attachers[#Presentation.attachers + 1] = fn
end
function Presentation.attach(g)
  for _, fn in ipairs(Presentation.attachers) do
    fn(g)
  end
end
function Presentation.cue(g, sound, volume, x, z)
  return Presentation.call(g, 'cue', sound, volume, x, z)
end
-- Leave or take the mouse (the screen decides; app/screens.lua captureMouse).
function Presentation.capture(g, captured)
  return Presentation.call(g, 'capture', captured)
end
return Presentation
