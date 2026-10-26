-- Bodies: the archetype behind an enemy record, its body data, the knight's
-- body, footprint and stability.
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
local Archetypes = require('src.content.enemies')
local Body = require('src.content.defs.body')
local Ground = require('src.physics.ground')
local World = require('src.world.arena')
local Pose = require('src.enemies.pose')
local Surface = require('src.enemies.surface')
local sqrt = math.sqrt
return function(R)
  -- Archetype of an enemy record (variant first: the Iron Thrall shares the
  -- Ember Thrall's atlas and AI but not its body).
  function R.archetype(e)
    if e == nil then
      return nil
    end
    return Archetypes.of(e)
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
  -- The movement footprint is coarse and independent of anatomical shot
  -- surfaces. On a heightfield its vertical intervals must overlap before
  -- crowd separation or momentum transfer can make horizontal contact.
  -- The knight: his height less his crouch. A creature: its own height when
  -- its body states one, else up to its painted body as posed now (its leap
  -- is in the painting; a falling corpse's drop is not).
  local function interval(g, o)
    local ground = Ground.of(g.world, o)
    if o.jump ~= nil then
      local base = ground + o.jump
      return base, base + R.playerBody().height - (o.crouch or 0)
    end
    local base = ground + ((o.hp <= 0 and o.fallY or o.leapY) or 0)
    local height = R.body(o).height
    if height then
      return base, base + height
    end
    return base, ground + Surface.top(g, o) + (o.hp <= 0 and o.fallY or 0)
  end
  R.interval = interval
  -- The height of body o over its feet on a world with decks (what a deck
  -- above stops and what room its routes need, plan v10 V3): the knight's
  -- less his crouch, a creature's stated or its stature's; nil on a world
  -- without decks.
  function R.tall(g, o)
    if not (g.world and g.world.decks) then
      return nil
    end
    if o.jump ~= nil then
      return R.playerBody().height - (o.crouch or 0)
    end
    local stated = R.body(o).height
    if stated then
      return stated
    end
    local a = R.archetype(o)
    local large = a and a.appearance and a.appearance.stature == 'large'
    return large and Archetypes.defaults.stature.large or Archetypes.defaults.stature.standing
  end
  -- A body rising air m over its floor at velocity under a deck: the deck's
  -- underside stops it (plan v10 V3). Returns the height and velocity kept.
  function R.ceiling(g, o, air, velocity)
    local floor = Ground.of(g.world, o)
    local top = Ground.ceiling(g.world, o.x, o.z, floor)
    if not top then
      return air, velocity
    end
    local room = top - floor - R.tall(g, o)
    if air > room then
      return math.max(0, room), math.min(0, velocity)
    end
    return air, velocity
  end
  function R.bodiesOverlap(g, a, b)
    if not g.world or not g.world.elevations then
      return true
    end
    local a1, a2 = interval(g, a)
    local b1, b2 = interval(g, b)
    return a1 < b2 and b1 < a2
  end
  -- Where a body's sight starts, in world height over the floor under it.
  -- The knight: his eye, his jump, less his crouch. A creature: its own eye
  -- when its body states one (with its leap), else its painted head as posed
  -- now (enemies/pose 'head' anchor: its stature, leap, crouch and lunge).
  function R.eye(g, o)
    local base = Ground.of(g.world, o)
    if o.jump ~= nil then
      return base + o.jump + R.playerBody().eye - (o.crouch or 0)
    end
    local eye = R.body(o).eye
    if eye then
      return base + (o.leapY or 0) + eye
    end
    local _, head = Pose.anchor(g, o, 'head')
    return base + head
  end
  -- Whether body o sees the body t (plan v10 V2: any body, any side): where
  -- t is now (its jump, crouch or leap included), or standing at (x, z) (a
  -- predicted or remembered place) with its own eye height over that floor.
  function R.sees(g, o, t, x, z)
    local world = g.world
    if not world.elevations then
      -- A flat map has no heights for sight to compare: no eye to pose.
      return World.visible(world, o.x, o.z, x or t.x, z or t.z)
    end
    local target
    if not x then
      target = R.eye(g, t)
    elseif t.jump ~= nil then
      target = Ground.height(world, x, z, t.level) + R.playerBody().eye
    else
      target = Ground.height(world, x, z, t.level) + R.eye(g, t) - Ground.of(world, t)
    end
    return World.visible(world, o.x, o.z, x or t.x, z or t.z, R.eye(g, o), target)
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
