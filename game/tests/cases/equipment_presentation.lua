local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local Abilities = require('src.content.abilities')
  local Schema = require('src.core.schema')
  local Integrity = require('src.session.integrity')
  local Snapshot = require('src.session.snapshot')
  local Journal = require('src.session.journal')
  local Weapon = require('src.render.weapon')
  local UI = require('src.ui.interface')
  local Skin = require('src.ui.skin')
  local lines = {}
  local check = Fixtures.checker(lines, 'equipment presentation: ', 'equipment presentation: ')
  local id, boltId = 'trial_hand_charge', 'trial_hand_bolt'
  local originalText = Skin.text
  local ok, problem = xpcall(function()
    local trial = Schema.copy(Abilities:get('powder'))
    trial.id, trial.name, trial.tag = id, 'TRIAL CHARGE', 'ASH'
    trial.action.id, trial.action.cooldown = id, 1.8
    Abilities.define(trial)
    Abilities.define({
      id = boltId,
      name = 'TRIAL BOLT',
      tag = 'BOLT',
      empty = 'No trial bolts.',
      capacity = 2,
      start = 2,
      action = require('src.content.defs.action').bolt({
        id = boltId,
        range = 20,
        windup = 0,
        cooldown = 0.2,
        speed = 30,
        packet = { base = 1, impact = 1 },
      }),
    })
    Snapshot.invalidateDefinitions()
    local function ready(mode)
      local g = mode == 'descent' and Fixtures.expedition(G) or Fixtures.arena(G)
      if g.run then
        require('src.run.descent').ready(g)
        g.run.phase, g.run.spawnTimer = 'wave', 100
        g.enemies = {}
      end
      Abilities.give(g, id)
      g.view.messageTimer, g.zoneTimer = 0, 0
      return g
    end
    local recorded = ready()
    local journal = Journal.record(recorded)
    check('second slot casts through the unchanged public API', recorded:cast(2))
    local cast = recorded.view.abilityCast
    check(
      'actual cast selects its authored hand gesture',
      cast.id == id and cast.slot == 2 and Weapon.throwFrame(recorded) == 3
    )
    check(
      'casting second slot leaves Q inventory and cooldown untouched',
      recorded.player.abilityState.powder.uses == 2
        and recorded.player.abilityState.powder.readyAt == 0
    )
    check(
      'rejected repeat cast cannot restart the hand gesture',
      not recorded:cast(2) and recorded.view.abilityCast == cast
    )
    for _ = 1, 15 do
      recorded:update(1 / 120, {})
    end
    check(
      'gesture advances independently of longer equipment cooldown',
      Weapon.throwFrame(recorded) == 4
        and recorded.player.abilityState[id].readyAt > recorded.elapsed + 1
    )
    Journal.stop(recorded)
    local replayed = ready()
    Journal.replay(replayed, Journal.decode(Journal.encode(journal)))
    check(
      'journal reproduces second-slot cast and authoritative state',
      not Integrity.difference(Integrity.capture(recorded), Integrity.capture(replayed))
    )
    check(
      'journal replay produces the same visible hand phase',
      replayed.view.abilityCast.slot == 2
        and Weapon.throwFrame(replayed) == Weapon.throwFrame(recorded)
    )
    for _ = 1, 24 do
      recorded:update(1 / 120, {})
    end
    check(
      'hand gesture ends while its own cooldown continues',
      Weapon.throwFrame(recorded) == nil
        and recorded.player.abilityState[id].readyAt > recorded.elapsed
    )
    local noHands = ready()
    Abilities.give(noHands, boltId)
    noHands:cast(2)
    noHands:cast(3)
    check(
      'an item without hand artwork never borrows a powder throw',
      noHands.view.abilityCast.id == boltId and Weapon.throwFrame(noHands) == nil
    )
    -- Extra equipment remains a content/API fixture. The approved production
    -- HUD is intentionally unchanged; this verifies the existing renderer and
    -- UI can present its hand feedback without mutating simulation state.
    local labels = {}
    Skin.text = function(text, ...)
      labels[text] = true
      return originalText(text, ...)
    end
    for _, mode in ipairs({ 'classic', 'descent' }) do
      local g = ready(mode)
      check(
        mode .. ' cast reaches the second-slot animation',
        g:cast(2) and Weapon.throwFrame(g) == 3
      )
      local before = Integrity.capture(g)
      renderer:draw(g, 1280, 720)
      UI.draw(g, 1280, 720, { motion = true, sensitivity = 1, music = 0, fov = 100, hints = false })
      check(
        mode .. ' full rendering preserves authoritative state',
        not Integrity.difference(before, Integrity.capture(g))
      )
    end
    check('content fixture does not introduce another production HUD label', not labels['F ASH'])
  end, debug.traceback)
  Skin.text = originalText
  Abilities:unregister(id)
  Abilities:unregister(boltId)
  Snapshot.invalidateDefinitions()
  assert(ok, problem)
  return lines
end
return Tests
