-- The drink is a live cast. Its painting must end with that cast, whether
-- it releases, spills, is stopped or is restored with a different windup.
local F = require('tests.support.fixtures')
local T = {}
function T.run(G)
  local V = require('src.render.weapon')
  local Feedback = require('src.feedback.ability_feedback')
  local Abilities = require('src.content.abilities')
  local Equipment = require('src.content.equipment_art')
  local Cast = require('src.combat.abilities')
  local Golden = require('qa.golden')
  local Snapshot = require('src.session.snapshot')
  local lines = {}
  local check = F.checker(lines, 'flask art: ', 'flask art: ')
  local function fresh(id)
    local g = F.arena(G)
    g.player.hp, g.view.swapAge = 30, 1
    local slot = Abilities.give(g, id or 'flask')
    assert(g:cast(slot))
    return g, slot
  end
  local function advance(g, seconds)
    for _ = 1, math.floor(seconds * 120 + 0.5) do
      g:update(1 / 120, {})
    end
  end
  check('a swallow has its own sound recipe', require('src.audio.recipes').flaskSip ~= nil)
  local Audio = require('src.audio.audio')
  local play = Audio.play
  local sounds = {}
  Audio.play = function(name)
    sounds[#sounds + 1] = name
  end
  local okSound, errSound = pcall(function()
    local function count(name)
      local n = 0
      for _, id in ipairs(sounds) do
        if id == name then
          n = n + 1
        end
      end
      return n
    end
    local drink = fresh()
    advance(drink, 0.3)
    check('no gulp before sip', count('flaskSip') == 0 and count('pickup') == 0)
    advance(drink, 0.22)
    check(
      'one gulp in sip, before healing',
      count('flaskSip') == 1 and drink.player.hp == 30 and count('pickup') == 0
    )
    advance(drink, 0.12)
    check('remaining sip frames do not repeat the sound', count('flaskSip') == 1)
    advance(drink, 0.4)
    check(
      'healing success sounds once at completion',
      count('pickup') == 1 and drink.player.hp == 75
    )
    sounds = {}
    drink = fresh()
    advance(drink, 0.2)
    Cast.stop(drink, drink.player)
    advance(drink, 1)
    check(
      'interrupted before sip plays neither gulp nor success',
      count('flaskSip') == 0 and count('pickup') == 0
    )
    sounds = {}
    drink = fresh()
    advance(drink, 0.52)
    Cast.stop(drink, drink.player)
    advance(drink, 1)
    check(
      'interrupted after gulp plays no healing success',
      count('flaskSip') == 1 and count('pickup') == 0
    )
    sounds = {}
    drink = fresh()
    drink.player.hp = 100
    advance(drink, 1.1)
    check('no success sound without actual healing', count('pickup') == 0)
  end)
  Audio.play = play
  assert(okSound, errSound)
  local atlas = V.handAtlases.flask
  local canvas = love.graphics.newCanvas(960, 540)
  local function drawn(g, expected)
    local draw, found, shaded = love.graphics.draw, nil, false
    local digest = Golden.digest(g)
    love.graphics.draw = function(image, quad, ...)
      if image == atlas.image then
        found, shaded = quad, love.graphics.getShader() == V.shader
      end
      return draw(image, quad, ...)
    end
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    local ok, err = pcall(V.draw, g, 960, 540, { 0.5, 0.4, 0.3 })
    love.graphics.pop()
    love.graphics.draw = draw
    assert(ok, err)
    check('drawing leaves the simulation unchanged', digest == Golden.digest(g))
    return expected and found == atlas.quads[expected] and shaded or not expected and not found
  end
  local g = fresh()
  local duration = Abilities:get('flask').action.windup
  local elapsed = 0
  for index, phase in ipairs(Equipment.entries.flask.frames) do
    local from = index == 1 and 0 or Equipment.entries.flask.frames[index - 1].finish
    local time = (from + phase.finish) * 0.5 * duration
    advance(g, time - elapsed)
    elapsed = duration - g.player.casting.left
    local frame, _, actualDuration, id = Feedback.frame(g)
    check(
      'phase ' .. index .. ' draws its painted grip in the hands shader',
      frame == index and id == 'flask' and actualDuration == duration and drawn(g, index)
    )
  end
  advance(g, duration - elapsed + 1 / 60)
  check(
    'completion heals once and draws the weapon again',
    g.player.hp == 75
      and not g.player.casting
      and not Feedback.frame(g)
      and Feedback.weaponLowered(g) == 0
      and drawn(g)
  )
  g = fresh()
  advance(g, 0.4)
  check('the gun stands aside during the sip', Feedback.weaponLowered(g) > 0.7)
  local ending = fresh()
  advance(ending, duration - 1 / 60)
  check(
    'the final grip keeps the weapon lowered until healing actually completes',
    ending.player.casting
      and ending.player.hp == 30
      and Feedback.frame(ending) == 6
      and Feedback.weaponLowered(ending) > 0.7
      and drawn(ending, 6)
  )
  local _, down = V.equipmentPose(Equipment.atlases.flask, 0.99)
  check('the last grip stays inside the scene until completion', down <= 0.11)
  local uses = g.player.abilityState.flask.uses
  g:damageBody(
    g.player,
    5,
    g.player.x,
    g.player.z,
    require('src.content.defs.packet').new(5, 0),
    nil
  )
  check(
    'a real blow ends the painting without paying or healing',
    not g.player.casting
      and not Feedback.frame(g)
      and Feedback.weaponLowered(g) == 0
      and g.player.abilityState.flask.uses == uses
      and g.player.hp < 30
      and drawn(g)
  )
  g = fresh()
  advance(g, 0.3)
  local before = Snapshot.capture(g)
  Cast.stop(g, g.player)
  check('a stopped cast immediately returns the weapon', not Feedback.frame(g) and drawn(g))
  Snapshot.restore(g, before)
  check('restoring an in-progress cast restores its own phase', Feedback.frame(g) == 2)
  check(
    'the existing drinking rule still forbids a dodge',
    require('src.combat.attributes').forbids(g.player, 'dash')
  )
  g.player.hp = 0
  check('death cannot leave a floating flask', not Feedback.frame(g))
  local copy = require('src.core.schema').copy(Abilities:get('flask'))
  copy.id, copy.action.windup = 'qa_long_drink', duration * 2
  Abilities.define(copy)
  local ok, err = pcall(function()
    local long = fresh(copy.id)
    advance(long, copy.action.windup * 0.55)
    local frame, _, time = Feedback.frame(long)
    check(
      'a longer ability keeps the same normalized sip phase',
      frame == 4 and time == duration * 2
    )
    check('the longer cast has not healed early', long.player.hp == 30)
  end)
  Abilities:unregister(copy.id)
  Snapshot.invalidateDefinitions()
  canvas:release()
  assert(ok, err)
  return lines
end
return T
