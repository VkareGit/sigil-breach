local Report = require('qa.report')
local Output = require('qa.output')
local Suite = {}

-- Explicit ordering preserves the original integration fixtures. Names describe
-- responsibilities; adding a test no longer requires another release/report chain.
Suite.registry = {
  {
    id = 'visual-identity',
    title = 'Owner-approved paint continuity through every creature frame',
    module = 'tests.cases.visual_identity',
  },
  {
    id = 'iron-thrall',
    title = 'Iron Thrall contact, movement and recovery',
    module = 'tests.cases.iron_thrall',
  },
  {
    id = 'iron-thrall-audio',
    title = 'Iron Thrall body voice and physical cues',
    module = 'tests.cases.iron_thrall_audio',
  },
  {
    id = 'iron-thrall-art',
    title = 'Iron Thrall physical gestures and pigments',
    module = 'tests.cases.iron_thrall_art',
  },
  {
    id = 'star-acolyte-audio',
    title = 'Distinct owl warnings and spatial teleport voices',
    module = 'tests.cases.star_acolyte_audio',
  },
  {
    id = 'star-acolyte-art',
    title = 'Painted hell rites and teleport phases',
    module = 'tests.cases.star_acolyte_art',
  },
  {
    id = 'star-acolyte',
    title = 'Owl sidesteps, distinct spell tells and live action continuity',
    module = 'tests.cases.star_acolyte',
  },
  {
    id = 'sigil-builds',
    title = 'Four-point sigil builds and event ownership',
    module = 'tests.cases.sigil_builds',
  },
  {
    id = 'fire-shop',
    title = 'Permanent fire purchases and Judge start',
    module = 'tests.cases.fire_shop',
  },
  {
    id = 'hit-feedback',
    title = 'Readable real contact and missed surface',
    module = 'tests.cases.hit_feedback',
  },
  {
    id = 'flask-art',
    title = 'Live drink phases, lit hands and interruption',
    module = 'tests.cases.flask_art',
  },
  {
    id = 'elite-art',
    title = 'Elite breath, normalized guard and storm accents',
    module = 'tests.cases.elite_art',
  },
  {
    id = 'inscriptions',
    title = 'Painted inscriptions share bounded supporting surfaces',
    module = 'tests.cases.inscriptions',
  },
  {
    id = 'floor-art',
    title = 'Painted surface traces require real flat support',
    module = 'tests.cases.floor_art',
  },
  {
    id = 'wall-mounts',
    title = 'Wall ornaments stop at actual doorways',
    module = 'tests.cases.wall_mounts',
  },
  {
    id = 'roof-cells',
    title = 'Visible vaults, point rays and finite projectiles',
    module = 'tests.cases.roof_cells',
  },
  {
    id = 'seal-motion',
    title = 'Read-only summoning animation and identity',
    module = 'tests.cases.seal_motion',
  },
  {
    id = 'creature-pressure',
    title = 'Ordinary creatures against finite ammunition and reactive movement',
    module = 'tests.cases.creature_pressure',
  },
  {
    id = 'boss-pressure',
    title = 'Public one-stock bosses and live responses',
    module = 'tests.cases.boss_pressure',
  },
  {
    id = 'attack-followups',
    title = 'Finite physical strings and distinct counterplay',
    module = 'tests.cases.attack_followups',
  },
  {
    id = 'souls-bots',
    title = 'Careless and learning knights against every encounter and every blow',
    module = 'tests.cases.souls_bots',
  },
  {
    id = 'souls-gate',
    title = 'A knight who stands and shoots loses, and fire takes no blows away',
    module = 'tests.cases.souls_gate',
  },
  {
    id = 'souls-trace',
    title = 'A blow is a path in time and goes where the body came to face',
    module = 'tests.cases.souls_trace',
  },
  {
    id = 'souls-balance',
    title = 'Guard, execution, effort, the flask and what a body answers',
    module = 'tests.cases.souls_balance',
  },
  {
    id = 'pilgrimage',
    title = 'Fires, posts, death and the save of the way through the chapel',
    module = 'tests.cases.pilgrimage',
  },
  {
    id = 'report',
    title = 'One run reports every failing suite',
    module = 'tests.cases.report',
  },
  {
    id = 'responsiveness',
    title = 'No press is lost and every refusal is told',
    module = 'tests.cases.responsiveness',
  },
  {
    id = 'chain',
    title = 'A chain of kills belongs to one weapon, and so does its edge',
    module = 'tests.cases.chain',
  },
  {
    id = 'chapel-route',
    title = 'The chapel played through for three minutes: fight, pay, death, fires, alarm',
    module = 'tests.cases.chapel_route',
  },
  {
    id = 'lessons',
    title = 'The rules page and the lessons of things first seen, out of the heat of a fight',
    module = 'tests.cases.lessons',
  },
  {
    id = 'drops',
    title = 'Creatures leave the rounds of their family; an execution always pays',
    module = 'tests.cases.drops',
  },
  {
    id = 'damage-trail',
    title = 'The damage trail is the view state of its own blows, aged by the clocks',
    module = 'tests.cases.damage_trail',
  },
  {
    id = 'pilgrimage-save',
    title = 'A bad save never stops the game, kills wait for quiet, replays read no disk',
    module = 'tests.cases.pilgrimage_save',
  },
  {
    id = 'proving',
    title = 'The real map: its data, the whole way walked, trade and the field on it',
    module = 'tests.cases.proving',
  },
  {
    id = 'souls-engine',
    title = 'Combat engine of the souls plan, each mechanic alone',
    module = 'tests.cases.souls_engine',
  },
  {
    id = 'v12-pack',
    title = 'One whole content pack through public registries',
    module = 'tests.cases.v12_pack',
  },
  {
    id = 'v12-proofs',
    title = 'Extension proofs of plan v12 through public registries',
    module = 'tests.cases.v12_proofs',
  },
  {
    id = 'destruction',
    title = 'Shots and blasts break the world, ruin changes it and a load keeps it',
    module = 'tests.cases.destruction',
  },
  {
    id = 'chapel-hall',
    title = 'A painted hall agrees with its layout, floors and routes',
    module = 'tests.cases.chapel_hall',
  },
  {
    id = 'chambers',
    title = 'Authored proving chambers and isolated trials',
    module = 'tests.cases.chambers',
  },
  {
    id = 'encounters',
    title = 'Attack choices and boss life stocks',
    module = 'tests.cases.encounters',
  },
  {
    id = 'attack-volumes',
    title = 'Finite attack heights, floors and activation instants',
    module = 'tests.cases.attack_volumes',
  },
  {
    id = 'field-access',
    title = 'Public proving ground and retained mode tools',
    module = 'tests.cases.field_access',
  },
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
    id = 'cylinder-cast',
    title = 'Finite projectile and melee body contacts',
    module = 'tests.cases.cylinder_cast',
  },
  {
    id = 'contact-receipts',
    title = 'Event-only incoming contact provenance',
    module = 'tests.cases.contact_receipts',
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
    id = 'entity-lifecycle',
    title = 'Pools, ids, remains, knights and sealed definitions (plan v10 V1)',
    module = 'tests.cases.entity_lifecycle',
  },
  {
    id = 'factions',
    title = 'Sides, targets and one damage path (plan v10 V2)',
    module = 'tests.cases.factions',
  },
  {
    id = 'space-scale',
    title = 'Rectangular maps and costs independent of world size (plan v10 V3)',
    module = 'tests.cases.space_scale',
  },
  {
    id = 'floor-layers',
    title = 'Decks over floors: movement, shots, charges, routes and light (plan v10 V3)',
    module = 'tests.cases.floor_layers',
  },
  {
    id = 'fight-recording',
    title = 'Recording big fights: shot corridors, geometry deltas, replay (plan v10 V5)',
    module = 'tests.cases.fight_recording',
  },
  {
    id = 'runtime-contracts',
    title = 'Failed commands, named ammunition, single deaths, fallback attacks',
    module = 'tests.cases.runtime_contracts',
  },
  {
    id = 'creature-pipeline',
    title = 'Sheets, anatomy tools and a demon from data alone (plan v10 V7)',
    module = 'tests.cases.creature_pipeline',
  },
  {
    id = 'open-presentation',
    title = 'World objects by registration, HUD slots, switching languages (plan v10 V6)',
    module = 'tests.cases.open_presentation',
  },
  {
    id = 'named-poses',
    title = 'Named poses, refused sheets, reordered frames and the corpse rule (plan v11 E1)',
    module = 'tests.cases.named_poses',
  },
  {
    id = 'actors',
    title = 'Independent actors, journal v5 and shot sequences (plan v11 E3)',
    module = 'tests.cases.actors',
  },
  {
    id = 'damage-chain',
    title = 'Damage chains: owners of kills, healing and rewards (plan v11 E3d)',
    module = 'tests.cases.damage_chain',
  },
  {
    id = 'damage-origin',
    title = 'Periodic effect ownership, charge receipts and reset lifetimes',
    module = 'tests.cases.damage_origin',
  },
  {
    id = 'observer',
    title = 'The observer of geometry and shot observations by actor (plan v11 E4)',
    module = 'tests.cases.observer',
  },
  {
    id = 'input-geometry-contracts',
    title = 'Substep actor input, owned volume buffers and teleport observations',
    module = 'tests.cases.input_geometry_contracts',
  },
  {
    id = 'flinch-observers',
    title = 'Source-facing painted flinch and presentation interpolation',
    module = 'tests.cases.flinch_observers',
  },
  {
    id = 'view-context',
    title = 'Two canvases, independent personal feedback and viewers (plan v11 E5)',
    module = 'tests.cases.view_context',
  },
  {
    id = 'mode-state',
    title = 'Mode state owners, per-session views and an altars mode (plan v11 E2)',
    module = 'tests.cases.mode_state',
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
function Suite.run(G, renderer, getGame, output, selected, getLoading)
  if selected then
    local found = false
    for _, entry in ipairs(Suite.registry) do
      found = found or entry.id == selected
    end
    assert(found, 'unknown test suite: ' .. tostring(selected))
  end
  Suite.contentAtStart = Suite.contentText()
  -- Strict mode: an entity field no component declares is an error, and so
  -- is a changed content definition (src/session/definitions.lua): sealed
  -- here, verified after every suite and sealed again with what it added.
  require('src.core.strict').enabled = true
  local Definitions = require('src.session.definitions')
  Definitions.seal()
  local initial = getGame()
  initial.ephemeral = true
  -- A focused run must not replace evidence from the last complete run. Only
  -- registered suite ids reach this path, never arbitrary command-line paths.
  local filename = selected and ('suite-' .. selected .. '-results.txt') or 'test-results.txt'
  local report = Report.new((output or Output.directory()) .. '/' .. filename)
  report:write()
  for _, entry in ipairs(Suite.registry) do
    if not selected or entry.id == selected then
      report:run(entry.id, entry.title, function()
        local test = require(entry.module)
        local lines
        if entry.application then
          lines = test.run(G, initial, renderer, getGame, getLoading)
        else
          lines = test.run(G, renderer)
        end
        Definitions.verify('suite ' .. entry.id)
        Definitions.seal()
        return lines
      end)
    end
  end
  return report:finish()
end

return Suite
