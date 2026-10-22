-- Bodies: the archetype behind an enemy record, its body data, the knight's
-- body, footprint and stability.
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
local Archetypes = require('src.content.enemies')
local Body = require('src.content.defs.body')
local sqrt = math.sqrt
return function(R)
  -- Archetype of an enemy record (variant first: the armoured servant shares
  -- the imp's atlas and AI but not its body).
  function R.archetype(e)
    if e == nil then
      return nil
    end
    if e.archetype then
      return e.archetype
    end
    return Archetypes.get(e.kind, e.armored and 'armored' or nil)
  end
  function R.body(e)
    local a = R.archetype(e)
    -- A record without an archetype (fixture, catalogue) gets the neutral,
    -- complete body: rules never need fallbacks for body fields.
    return a and a.body or Body.neutral
  end
  -- The knight's body (the player under the same rules).
  function R.playerBody()
    return Archetypes.player.body
  end
  function R.radius(e)
    return R.body(e).radius or 0.25
  end
  -- Stability against losing balance: heavier bodies stagger and lie down
  -- shorter. A body may state its own (bosses keep their feet longer).
  function R.stability(e)
    local b = R.body(e)
    return b.stability or sqrt(b.mass)
  end
end
