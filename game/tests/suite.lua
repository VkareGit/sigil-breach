local Report = require('qa.report')
local Output = require('qa.output')
local Suite = {}

-- Explicit ordering preserves the original integration fixtures. Names describe
-- responsibilities; adding a test no longer requires another release/report chain.
Suite.registry = {
  {
    id = 'shot-observation',
    title = 'Explicit displayed shot observations',
    module = 'tests.cases.shot_observation',
  },
  {
    id = 'sphere-cast',
    title = 'Finite projectile world contacts',
    module = 'tests.cases.sphere_cast',
  },
  {
    id = 'painted-surfaces',
    title = 'Semantic painted contacts',
    module = 'tests.cases.painted_surfaces',
  },
  {
    id = 'attack-contact',
    title = 'Continuous rush and leap contact',
    module = 'tests.cases.attack_contact',
  },
  {
    id = 'telemetry',
    title = 'Combat timing and healing receipts',
    module = 'tests.cases.telemetry',
  },
  {
    id = 'aim-truth',
    title = 'Presented aim and resolved shots',
    module = 'tests.cases.aim_truth',
  },
  {
    id = 'summoning-art',
    title = 'Painted portal animation',
    module = 'tests.cases.summoning_art',
  },
  { id = 'ability-art', title = 'Painted ability poses', module = 'tests.cases.ability_art' },
  {
    id = 'charge-presentation',
    title = 'Visible physical charge handoff',
    module = 'tests.cases.charge_presentation',
  },
  {
    id = 'ritual-art',
    title = 'Matte ritual source, orientation, light and depth',
    module = 'tests.cases.ritual_art',
  },
  {
    id = 'gallery-loading',
    title = 'Bounded gallery loading transition',
    module = 'tests.cases.gallery_loading',
  },
  {
    id = 'art-extension',
    title = 'Registered painted sequence and effect',
    module = 'tests.cases.art_extension',
  },
  {
    id = 'equipment-presentation',
    title = 'Equipped slots and cast presentation',
    module = 'tests.cases.equipment_presentation',
  },
  {
    id = 'core',
    title = 'Core combat and application regressions',
    module = 'tests.suites.core',
    application = true,
  },
  {
    id = 'behavior',
    title = 'Enemy behavior',
    module = 'tests.suites.behavior',
    application = true,
  },
  {
    id = 'movement',
    title = 'Movement, presentation and effects',
    module = 'tests.suites.movement',
    application = true,
  },
  {
    id = 'shotgun',
    title = 'Shotgun, reload transactions and reactions',
    module = 'tests.suites.shotgun',
    application = true,
  },
  { id = 'waves', title = 'Waves, damage, economy and saves', module = 'tests.suites.waves' },
  {
    id = 'interface',
    title = 'Interface, assets and visibility',
    module = 'tests.suites.interface',
  },
  { id = 'geometry', title = 'Ray geometry, viewport and world', module = 'tests.suites.geometry' },
  {
    id = 'weapons',
    title = 'Physical weapons and evadable attacks',
    module = 'tests.suites.weapons',
  },
  {
    id = 'collision',
    title = 'Movement, ordnance and enemy collision',
    module = 'tests.suites.collision',
  },
  { id = 'fresco', title = 'Fresco art and geometry', module = 'tests.suites.fresco' },
  {
    id = 'weight',
    title = 'Light, bearing, durability and weight',
    module = 'tests.suites.weight',
  },
  { id = 'intent', title = 'Body physics and player intent', module = 'tests.suites.intent' },
  {
    id = 'animation',
    title = 'Weapon animation and illustrated typography',
    module = 'tests.suites.animation',
  },
  {
    id = 'details',
    title = 'Powder trails and physical surface marks',
    module = 'tests.suites.details',
  },
  {
    id = 'reporting',
    title = 'Fresh test aggregation and failure diagnostics',
    module = 'qa.tests_report',
  },
  {
    id = 'firing-feedback',
    title = 'Visible discharge, recovery and physical firing clocks',
    module = 'tests.cases.firing_feedback',
  },
  {
    id = 'death-feedback',
    title = 'Mortal reaction, landing and persistent corpse',
    module = 'tests.cases.death_feedback',
  },
  {
    id = 'session',
    title = 'Session ownership, reset and fixed simulation',
    module = 'tests.cases.session',
  },
  {
    id = 'architecture',
    title = 'Module boundaries and state ownership',
    module = 'tests.cases.architecture',
  },
  {
    id = 'foundation',
    title = 'Core foundation (src/core)',
    module = 'tests.cases.core_foundation',
  },
  {
    id = 'entities',
    title = 'ECS world, prefabs and strict entities',
    module = 'tests.cases.entities',
  },
  {
    id = 'replay',
    title = 'Session memento and command journal',
    module = 'tests.cases.replay',
  },
  {
    id = 'recording-budget',
    title = 'Bounded optional command recording',
    module = 'tests.cases.recording_budget',
  },
  {
    id = 'extension',
    title = 'Extension points: a demon, an attack, a mode and a screen',
    module = 'tests.cases.extension',
  },
  {
    id = 'consistency',
    title = 'One source for repeated values (plan v5 G1)',
    module = 'tests.cases.consistency',
  },
  {
    id = 'engine',
    title = 'Ground, shared paths, mode commands and keys (plan v5 G2)',
    module = 'tests.cases.engine',
  },
  {
    id = 'bodies',
    title = 'The knight and the demons as bodies (plan v5 G3)',
    module = 'tests.cases.bodies',
  },
  {
    id = 'fight-rules',
    title = 'Stagger, reload, hit-stop, view and the afterimage (plan v5 G4)',
    module = 'tests.cases.fight_feel',
  },
  {
    id = 'break-loop',
    title = 'Break it, then finish it (plan v5 G5)',
    module = 'tests.cases.break_loop',
  },
  {
    id = 'session-report',
    title = 'Real-play measurements for the playtest',
    module = 'tests.cases.session_report',
  },
  {
    id = 'headless',
    title = 'Simulation without presentation',
    module = 'tests.cases.headless',
  },
  {
    id = 'anatomy-data',
    title = 'Painted hit data bound to its sources',
    module = 'tests.cases.anatomy_data',
  },
  {
    id = 'creature-extension',
    title = 'A creature over existing art: annotation, abilities, material',
    module = 'tests.cases.creature_extension',
  },
  {
    id = 'falling-bodies',
    title = 'A killed body in the way of shots and missiles',
    module = 'tests.cases.falling_bodies',
  },
  {
    id = 'hit-landmarks',
    title = 'Shots at anatomical landmarks in live poses (plan v7 H0)',
    module = 'tests.cases.hit_landmarks',
  },
  {
    id = 'weapon-extension',
    title = 'Weapon transport, inheritance and complete content path',
    module = 'tests.cases.weapon_extension',
  },
  {
    id = 'weapon-contracts',
    title = 'Weapon definition failures and arbitrary pellet counts',
    module = 'tests.cases.weapon_contracts',
  },
  -- Last: the simulation must reproduce the golden master bit for bit.
  {
    id = 'impact-origin',
    title = 'Physical source of impulses',
    module = 'tests.cases.impact_origin',
  },
  {
    id = 'content-contracts',
    title = 'Content definition contracts',
    module = 'tests.cases.content_contracts',
  },
  {
    id = 'qa-tools',
    title = 'QA lifecycle, profiles and observed recording contracts',
    module = 'tests.cases.qa_tools',
  },
  {
    id = 'hand-art-extension',
    title = 'Named firearm frames and independent equipment atlases',
    module = 'tests.cases.hand_art_extension',
  },
  {
    id = 'mode-lifecycle',
    title = 'Session factories, navigation and mode extension',
    module = 'tests.cases.mode_lifecycle',
  },
  {
    id = 'action-presentation',
    title = 'Independent action clocks and contact diagnostics',
    module = 'tests.cases.action_presentation',
  },
  {
    id = 'terrain-motion',
    title = 'Terrain movement and flight',
    module = 'tests.cases.terrain_motion',
  },
  {
    id = 'world-support',
    title = 'Shared support, risers and map-owned decoration',
    module = 'tests.cases.world_support',
  },
  {
    id = 'load-plan',
    title = 'Staged loading lifecycle',
    module = 'tests.cases.load_plan',
  },
  {
    id = 'resources',
    title = 'Native resource ownership and sampling variants',
    module = 'tests.cases.resources',
  },
  {
    id = 'serialization',
    title = 'Bounded literal data decoding without evaluation',
    module = 'tests.cases.serialization',
  },
  {
    id = 'weapon-rounds',
    title = 'Painted ammunition follows the live reload transaction',
    module = 'tests.cases.weapon_rounds',
  },
  {
    id = 'weapon-art-review',
    title = 'Live firearm cycles, partial load and interruptions',
    module = 'tests.cases.weapon_art_review',
  },
  {
    id = 'journal-values',
    title = 'Shared observations and restricted replay commands',
    module = 'tests.cases.journal_values',
  },
  {
    id = 'ui-content-extension',
    title = 'Parameterized bitmap text and paged content growth',
    module = 'tests.cases.ui_content_extension',
  },
  {
    id = 'foundation-contracts',
    title = 'Definition ownership and executable references',
    module = 'tests.cases.foundation_contracts',
  },
  {
    id = 'contact-effects',
    title = 'Contact effects, pulse clocks and complete replay',
    module = 'tests.cases.contact_effects',
  },
  {
    id = 'hazard-art',
    title = 'Painted hazard phases and depth',
    module = 'tests.cases.hazard_art',
  },
  {
    id = 'runtime-contracts',
    title = 'Failed commands, named ammunition, single deaths, fallback attacks',
    module = 'tests.cases.runtime_contracts',
  },
  { id = 'golden', title = 'Golden master of the simulation', module = 'tests.suites.golden' },
}

-- The content definitions as text: they must leave the test run unchanged.
function Suite.contentText()
  local Serialize = require('src.core.serialize')
  local Weapons = require('src.content.weapons')
  local parts = { Serialize.encode(require('src.content.enemies')) }
  for slot = 1, Weapons.count() do
    parts[#parts + 1] = Serialize.encode(Weapons.profile(slot))
  end
  return table.concat(parts, '|')
end
function Suite.run(G, renderer, getGame, output, selected)
  if selected then
    local found = false
    for _, entry in ipairs(Suite.registry) do
      found = found or entry.id == selected
    end
    assert(found, 'unknown test suite: ' .. tostring(selected))
  end
  Suite.contentAtStart = Suite.contentText()
  -- Strict mode: an entity field no component declares is an error.
  require('src.core.strict').enabled = true
  local initial = getGame()
  initial.testing = true
  -- A focused run must not replace evidence from the last complete run. Only
  -- registered suite ids reach this path, never arbitrary command-line paths.
  local filename = selected and ('suite-' .. selected .. '-results.txt') or 'test-results.txt'
  local report = Report.new((output or Output.directory()) .. '/' .. filename)
  report:write()
  for _, entry in ipairs(Suite.registry) do
    if not selected or entry.id == selected then
      report:run(entry.id, entry.title, function()
        local test = require(entry.module)
        if entry.application then
          return test.run(G, initial, renderer, getGame)
        end
        return test.run(G, renderer)
      end)
    end
  end
  return report:finish()
end

return Suite
