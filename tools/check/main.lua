-- Compile without executing the application or creating a window.
local function read(path)
  local file = assert(io.open(path, 'rb'))
  local text = file:read('*a')
  file:close()
  return text
end

-- Unnamed numbers in simulation code (0.24 E9). Tunable values belong in
-- content (tuning, combat_defaults, waves, the mode data) under a name. A
-- simulation file may not hold more unnamed numbers than its line in
-- tools/check/literals.txt (a ratchet: the count only goes down), and a new
-- one holds none. Counted: decimals and integers of two or more digits in
-- code, not in comments or strings; 0.5 and exponents (epsilons) are free.
local simulation =
  { 'app', 'combat', 'enemies', 'physics', 'player', 'run', 'session', 'systems', 'world' }
local function governed(relative)
  for _, dir in ipairs(simulation) do
    if relative:sub(1, #dir + 5) == 'src/' .. dir .. '/' then
      return true
    end
  end
  return false
end
local function unnamedNumbers(text)
  text = text:gsub('%-%-%[(=*)%[.-%]%1%]', ''):gsub('%[(=*)%[.-%]%1%]', "''")
  text = text:gsub('"[^"\n]*"', "''"):gsub("'[^'\n]*'", "''"):gsub('%-%-[^\n]*', '')
  -- Scientific notation is one token, including the signed exponent. Without
  -- this, the 12 in an allowed geometric epsilon 1e-12 was counted as tuning.
  text = text:gsub('%d[%d%.]*[eE][%+%-]?%d+', '0')
  local count = 0
  for position, token in text:gmatch('()(%.?%d[%w%.]*)') do
    local before = position > 1 and text:sub(position - 1, position - 1) or ''
    if
      not before:match('[%w_%.]')
      and not token:match('[eExX]')
      and token ~= '0.5'
      and (token:find('.', 1, true) or #token >= 2)
    then
      count = count + 1
    end
  end
  return count
end
-- Direction (0.24 F0): simulation code never imports presentation. The
-- edges still present are listed in tools/check/presentation-edges.txt (a
-- ratchet: no new edge; a removed edge must leave the list).
local simulationLayers =
  { 'combat', 'enemies', 'physics', 'player', 'run', 'session', 'systems', 'world' }
local presentationLayers = { 'feedback', 'render', 'ui', 'audio', 'app' }
local function layerOf(id, layers)
  for _, layer in ipairs(layers) do
    if id:sub(1, #layer + 5) == 'src.' .. layer .. '.' then
      return layer
    end
  end
end
local function readLines(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local set = {}
  for line in file:read('*a'):gmatch('[^\r\n]+') do
    set[line] = true
  end
  file:close()
  return set
end
local function readBaseline(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local baseline = {}
  for relative, count in file:read('*a'):gmatch('([^%s]+)%s+(%d+)') do
    baseline[relative] = tonumber(count)
  end
  file:close()
  return baseline
end

-- Lua source split into code and short string literals. Comments vanish,
-- every string becomes '' in the code, and each short string keeps the code
-- just before it (to tell a call's argument). Long strings count as code ''.
local function longBracket(text, i)
  local level = text:match('^%[(=*)%[', i)
  if level then
    local close = text:find(']' .. level .. ']', i, true)
    return close and close + #level + 1 or #text
  end
end
local function scan(text)
  local code, strings, i, n, tail = {}, {}, 1, #text, ''
  local function emit(piece)
    code[#code + 1] = piece
    tail = (tail .. piece):sub(-16)
  end
  while i <= n do
    local c = text:sub(i, i)
    if c == '-' and text:sub(i + 1, i + 1) == '-' then
      local last = longBracket(text, i + 2)
      i = (last or (text:find('\n', i, true) or n + 1) - 1) + 1
    elseif c == '[' and longBracket(text, i) then
      local last = longBracket(text, i)
      emit("''")
      i = last + 1
    elseif c == '"' or c == "'" then
      local j, value = i + 1, {}
      while j <= n do
        local d = text:sub(j, j)
        if d == '\\' then
          value[#value + 1] = text:sub(j, j + 1)
          j = j + 2
        elseif d == c or d == '\n' then
          break
        else
          value[#value + 1] = d
          j = j + 1
        end
      end
      strings[#strings + 1] = { value = table.concat(value), before = tail }
      emit("''")
      i = j + 1
    else
      local stop = text:find('[%-%[\'"]', i + 1) or n + 1
      emit(text:sub(i, stop - 1))
      i = stop
    end
  end
  return table.concat(code), strings
end

-- Scaling ratchets (plan v10 V0): per-file counts of the single-arena
-- assumptions the plan removes, recorded in tools/check/<name>.txt. Like the
-- numbers, a file may not exceed its recorded count and a new file holds
-- none; the stage that removes an assumption drives its count to 0. Counts
-- are proxies read from the code, not proof of a design.
local sessionNames = { 'g', 'self', 'game', 'session', 'shown' }
local function fieldAccesses(code, fields)
  local count = 0
  for _, owner in ipairs(sessionNames) do
    for _, field in ipairs(fields) do
      for _ in code:gmatch('%f[%w_]' .. owner .. '%.' .. field .. '%f[^%w_]') do
        count = count + 1
      end
    end
  end
  return count
end
-- Text the player reads: an ALL-CAPS literal of three or more letters (the
-- game's lettering), not an identifier (no '_', no digits without a space),
-- or any literal given straight to notify(). Musical notation (pitch names:
-- 'D2 A2 D3', 'Bb1', 'D3:2', '-') is not lettering.
local function occurrences(code, patterns)
  local count = 0
  for _, pattern in ipairs(patterns) do
    for _ in code:gmatch(pattern) do
      count = count + 1
    end
  end
  return count
end
local function notation(value)
  for token in value:gmatch('%S+') do
    if token ~= '-' and not token:match('^%u[b#]?%d:?%d*$') then
      return false
    end
  end
  return true
end
local function playerText(strings)
  local count = 0
  for _, s in ipairs(strings) do
    local value = s.value
    local _, capitals = value:gsub('%u', '')
    if s.before:match('notify%(%s*$') then
      count = count + 1
    elseif
      capitals >= 3
      and not notation(value)
      and not value:find('%l')
      and not value:find('_', 1, true)
      and (value:find(' ', 1, true) or not value:find('%d'))
    then
      count = count + 1
    end
  end
  return count
end
local simulationAndContent =
  { 'combat', 'content', 'enemies', 'physics', 'player', 'run', 'session', 'systems', 'world' }
local scalingRatchets = {
  {
    name = 'knight-references',
    label = 'KNIGHT AS THE ONLY TARGET',
    hint = 'ask for the target or the controlled knight (plan v10 V2)',
    layers = simulationAndContent,
    -- core/roles.lua is the one place that names the controlled knight
    -- and the viewer; every other rule asks it.
    exempt = { 'src/player/', 'src/combat/rules/knight.lua', 'src/core/roles.lua' },
    count = function(code)
      return fieldAccesses(code, { 'player' })
    end,
  },
  {
    name = 'pool-arrays',
    label = 'DIRECT POOL ARRAYS',
    hint = 'query the entity world (plan v10 V1)',
    exempt = { 'src/session/world.lua', 'src/session/state.lua' },
    count = function(code)
      return fieldAccesses(code, { 'enemies', 'bullets', 'hazards', 'pickups', 'charges' })
    end,
  },
  {
    name = 'mode-records',
    label = 'MODE RECORDS READ OUTSIDE THEIR MODE',
    hint = 'ask the mode (Modes, run/queries; plan v10 V6)',
    exempt = {
      'src/run/descent.lua',
      'src/run/economy.lua',
      'src/run/pilgrimage.lua',
      'src/run/test_field.lua',
      'src/run/field/',
      'src/run/modes.lua',
    },
    count = function(code)
      return fieldAccesses(code, { 'run', 'testField' })
    end,
  },
  {
    name = 'player-text',
    label = 'PLAYER TEXT OUTSIDE THE TEXT TABLE',
    hint = 'move it to content/text (plan v10 V6)',
    -- The package smoke check's report is console output for QA.
    exempt = { 'src/content/text.lua', 'src/app/package_smoke.lua' },
    count = function(_, strings)
      return playerText(strings)
    end,
  },
  -- Plan v11 (E0): the assumptions the stages E1-E5 remove.
  {
    name = 'frame-numbers',
    label = 'FRAME NUMBERS OUTSIDE SHEETS',
    hint = 'ask the sheet for a named pose (plan v11 E1)',
    layers = { 'enemies' },
    exempt = {},
    -- The layout flag a pose is chosen by (imp, extended) and every read of
    -- a creature's painted layout.
    count = function(code)
      local count = 0
      for _, pattern in ipairs({ '%f[%w_]imp%f[^%w_]', '%f[%w_]extended%f[^%w_]', '%.layout%s*==' }) do
        for _ in code:gmatch(pattern) do
          count = count + 1
        end
      end
      return count
    end,
  },
  {
    name = 'mode-state',
    label = 'MODE STATE ON THE SESSION',
    hint = 'keep it with its owner: the encounter, the world, the mode (plan v11 E2)',
    exempt = {},
    count = function(code)
      return fieldAccesses(
        code,
        { 'seals', 'secretFound', 'rank', 'bestScore', 'bossSpawned', 'bossDead' }
      )
    end,
  },
  {
    name = 'actor-state',
    label = 'ACTOR STATE ON THE SESSION',
    hint = 'keep it on the actor (plan v11 E3)',
    exempt = {},
    count = function(code)
      return fieldAccesses(code, {
        'weapon',
        'cooldown',
        'reload',
        'reloadWeapon',
        'reloadStage',
        'reloadDuration',
        'reloadOffset',
        'fireBuffer',
        'fireCommand',
        'shots',
        'hits',
        'kills',
        'score',
        'combo',
        'comboTimer',
        'damageTaken',
      })
    end,
  },
  {
    name = 'viewer-in-simulation',
    label = 'VIEWER IN SIMULATION',
    hint = 'ask the observer of the query (plan v11 E4)',
    layers = simulationAndContent,
    exempt = {},
    count = function(code)
      local count = 0
      for _ in code:gmatch('%f[%w_]Roles%.viewer%f[^%w_]') do
        count = count + 1
      end
      return count
    end,
  },
  {
    name = 'one-player-presentation',
    label = 'PRESENTATION ASSUMES ONE PLAYER',
    hint = 'read the presentation context (plan v11 E5)',
    layers = { 'app', 'audio', 'feedback', 'render', 'ui' },
    exempt = {},
    count = function(code)
      local count = fieldAccesses(code, { 'player' })
      for _ in code:gmatch('%f[%w_]Roles%.controlled%f[^%w_]') do
        count = count + 1
      end
      return count
    end,
  },
  -- Plan v12 (R0): the assumptions its stages remove. Counted from 0.35; a
  -- stage ends with its own rule at zero (enemy-pool-reads ends as a justified
  -- list, plan v12 in git history).
  {
    name = 'player-body',
    label = 'BODY OF THE ONE PLAYER',
    hint = 'read the body of the actor (plan v12 R1)',
    exempt = { 'src/content/knight.lua' },
    count = function(code)
      return occurrences(code, { '%.playerBody%(%)', 'Archetypes%.player', 'Knight%.body' })
    end,
  },
  {
    name = 'damage-entry',
    label = 'SECOND DAMAGE ENTRY',
    hint = 'land a blow through combat/hit.lua (plan v12 R2)',
    exempt = { 'src/combat/rules/hit_response.lua', 'src/session/damage_outcomes.lua' },
    count = function(code)
      return occurrences(code, { '[:%.]damageEnemy%(', 'Outcomes%.enemy%(' })
    end,
  },
  {
    name = 'damage-type-literals',
    label = 'DAMAGE TYPE IN CODE',
    hint = 'describe the damage type in content/damage_types.lua (plan v12 R2)',
    -- Hazards and commands have kinds of their own under the same words.
    exempt = {
      'src/content/',
      'src/enemies/hazards.lua',
      'src/render/effects.lua',
      'src/render/passes/hazards.lua',
      'src/player/intent.lua',
    },
    count = function(_, strings)
      local count = 0
      local types = { physical = true, fire = true, astral = true, poison = true, lightning = true }
      for _, s in ipairs(strings) do
        if types[s.value] and s.before:match('[=~]=%s*$') then
          count = count + 1
        end
      end
      return count
    end,
  },
  {
    name = 'ammo-fields',
    label = 'MAGAZINE FIELDS OUTSIDE THE AMMO MODEL',
    hint = 'ask the ammunition model (plan v12 R3)',
    exempt = {
      'src/content/ammo/',
      'src/content/weapons.lua',
      'src/content/tuning.lua',
      'src/render/resources.lua',
    },
    count = function(code)
      return occurrences(code, {
        '%.mag%f[%W]',
        '%.reserve%f[%W]',
        '%f[%w]maxReserve%f[%W]',
        '%f[%w]startReserve%f[%W]',
        '%f[%w]packSize%f[%W]',
        '%f[%w]unitPrice%f[%W]',
      })
    end,
  },
  {
    name = 'controlled-abilities',
    label = 'ABILITIES OF THE CONTROLLED ONLY',
    hint = 'name the actor (plan v12 R4)',
    exempt = {},
    count = function(code)
      return occurrences(code, { 'Abilities%.give%([^,%)]*,[^,%)]*%)', 'defaultAction%(' })
    end,
  },
  {
    name = 'creature-names',
    label = 'CREATURE NAME IN CODE',
    hint = 'describe it in the creature, not the code (plan v12 R5)',
    exempt = { 'src/content/' },
    count = function(_, strings)
      local count = 0
      local names =
        { imp = true, armored = true, stolas = true, buer = true, boss = true, furfur = true }
      for _, s in ipairs(strings) do
        if names[s.value] then
          count = count + 1
        end
      end
      return count
    end,
  },
  {
    name = 'tile-literals',
    label = 'TILE NUMBER IN CODE',
    hint = 'ask core/tiles.lua (plan v12 R6)',
    exempt = { 'src/core/tiles.lua' },
    count = function(code)
      return occurrences(code, { 'map%[[^%]]+%]%[[^%]]+%]%s*[=~]=%s*%d', 'tile%s*[=~><]=?%s*%d' })
    end,
  },
  {
    name = 'default-map',
    label = 'DEFAULT MAP ASSUMED',
    hint = 'read the map of the run (plan v12 R7)',
    exempt = { 'src/content/maps/index.lua' },
    count = function(code)
      return occurrences(code, { 'Maps%.default', 'totalWaves' })
    end,
  },
  {
    name = 'enemy-pool-reads',
    label = 'ENEMY POOL READ',
    hint = 'a target goes through Bodies.targets (plan v12 R8)',
    exempt = { 'src/combat/bodies.lua' },
    count = function(_, strings)
      local count = 0
      for _, s in ipairs(strings) do
        if s.value == 'enemies' and s.before:match('Pools%.of%(g,%s*$') then
          count = count + 1
        end
      end
      return count
    end,
  },
  {
    name = 'step-rate',
    label = 'STEP RATE IN CODE',
    hint = 'one constant in core (plan v12 R6)',
    exempt = { 'src/core/rate.lua' },
    count = function(code)
      return occurrences(code, { '1%s*/%s*120%f[^%d]', '%f[%d]120%f[^%d%.]%s*[%*/]' })
    end,
  },
}
local function inScope(rule, relative)
  if relative:sub(1, 4) ~= 'src/' then
    return false
  end
  for _, prefix in ipairs(rule.exempt) do
    if relative:sub(1, #prefix) == prefix then
      return false
    end
  end
  if not rule.layers then
    return true
  end
  for _, layer in ipairs(rule.layers) do
    if relative:sub(1, #layer + 5) == 'src/' .. layer .. '/' then
      return true
    end
  end
  return false
end
local function scalingAudit(rule, counts, directory, failure, lines)
  local path = directory .. '/' .. rule.name .. '.txt'
  local files, total = {}, 0
  for relative, count in pairs(counts) do
    if count > 0 then
      files[#files + 1] = relative
    end
    total = total + count
  end
  table.sort(files)
  local baseline = readBaseline(path)
  if not baseline then
    local recorded = {}
    for _, relative in ipairs(files) do
      recorded[#recorded + 1] = relative .. ' ' .. counts[relative]
    end
    local file = assert(io.open(path, 'wb'))
    file:write(table.concat(recorded, '\n') .. (#recorded > 0 and '\n' or ''))
    file:close()
    baseline = counts
  end
  for relative, allowed in pairs(baseline) do
    if (counts[relative] or 0) < allowed then
      lines[#lines + 1] = 'RATCHET '
        .. rule.name
        .. ' '
        .. relative
        .. ' can drop to '
        .. (counts[relative] or 0)
    end
  end
  for _, relative in ipairs(files) do
    local allowed = baseline[relative] or 0
    if counts[relative] > allowed then
      failure(
        rule.label
          .. ' '
          .. relative
          .. ' has '
          .. counts[relative]
          .. ' (allowed '
          .. allowed
          .. '): '
          .. rule.hint
      )
    end
  end
  lines[#lines + 1] = rule.label .. ' ' .. total
end

local function audit(manifest, root, reportPath, literalsPath, edgesPath, filesPath)
  local sources, graph, errors, lines, numbers, crossing = {}, {}, {}, {}, {}, {}
  local scaling = {}
  local function failure(message)
    errors[#errors + 1] = message
  end
  lines[#lines + 1] = require('directory_test')(root, reportPath:match('^(.*)[/\\][^/\\]+$'))
  if filesPath then
    local problems, count = require('asset_paths')(root, filesPath)
    for _, problem in ipairs(problems) do
      failure('ASSET PATH ' .. problem)
    end
    lines[#lines + 1] = 'ASSET PATHS: '
      .. count
      .. ' constructed sound paths; 2 checker regressions.'
  end
  for relative in read(manifest):gmatch('[^\r\n]+') do
    local text = read(root .. '/' .. relative)
    local chunk, err = loadstring(text, '@' .. relative)
    if not chunk then
      failure('SYNTAX ' .. tostring(err))
    end
    local id = relative:gsub('%.lua$', ''):gsub('/', '.')
    if governed(relative) then
      numbers[relative] = unnamedNumbers(text)
    end
    local scanned, strings
    for _, rule in ipairs(scalingRatchets) do
      if inScope(rule, relative) then
        if not scanned then
          scanned, strings = scan(text)
        end
        scaling[rule.name] = scaling[rule.name] or {}
        scaling[rule.name][relative] = rule.count(scanned, strings)
      end
    end
    sources[id] = text
    graph[id] = {}
    lines[#lines + 1] = 'COMPILE ' .. relative
  end
  -- One name per module (PLAN F1): a whole src module is required under the
  -- same local name in every src file, and one name never stands for two
  -- modules. A reader meets Arena, Pools or Tuning and knows which file it is.
  local nameOf, moduleOf = {}, {}
  for id, text in pairs(sources) do
    if id:match('^src%.') then
      for line in text:gmatch('[^\n]+') do
        local name, module =
          line:match("^%s*local%s+([%a_][%w_]*)%s*=%s*require%(%s*'(src%.[%w_%.]+)'%s*%)%s*$")
        if not name then
          name, module =
            line:match("^%s*local%s+([%a_][%w_]*)%s*=%s*require%(%s*'(src%.[%w_%.]+)'%s*%)%s*%-%-")
        end
        if name then
          if #name < 2 then
            failure('MODULE NAME ' .. id .. ': ' .. module .. ' needs a word, not ' .. name)
          end
          local known = nameOf[module]
          if known and known.name ~= name then
            failure(
              'MODULE NAME '
                .. module
                .. ' is '
                .. known.name
                .. ' in '
                .. known.at
                .. ' but '
                .. name
                .. ' in '
                .. id
            )
          end
          nameOf[module] = known or { name = name, at = id }
          local other = moduleOf[name]
          if other and other.module ~= module then
            failure(
              'MODULE NAME '
                .. name
                .. ' stands for '
                .. other.module
                .. ' in '
                .. other.at
                .. ' and '
                .. module
                .. ' in '
                .. id
            )
          end
          moduleOf[name] = other or { module = module, at = id }
        end
      end
    end
  end
  for id, text in pairs(sources) do
    local seen = {}
    -- Registries use literal IDs as well as direct require calls.
    for dependency in text:gmatch('[\'"]([%w_%.]+)[\'"]') do
      if
        dependency:match('^src%.')
        or dependency:match('^tests%.')
        or dependency:match('^qa%.')
      then
        if not sources[dependency] then
          failure('MISSING ' .. id .. ' -> ' .. dependency)
        elseif not seen[dependency] then
          seen[dependency] = true
          graph[id][#graph[id] + 1] = dependency
        end
        if
          id:match('^src%.')
          and not dependency:match('^src%.')
          and not (id == 'src.app.runtime' and dependency == 'qa.runtime')
        then
          failure('DEVELOPMENT DEPENDENCY ' .. id .. ' -> ' .. dependency)
        end
        -- src.core is the foundation: every layer may use it, it uses nothing
        -- but itself.
        local core = dependency:match('^src%.core%.')
        if id:match('^src%.core%.') and not core then
          failure('CORE DEPENDENCY ' .. id .. ' -> ' .. dependency)
        end
        if id:match('^src%.content%.') and not dependency:match('^src%.content%.') and not core then
          failure('CONTENT DEPENDENCY ' .. id .. ' -> ' .. dependency)
        end
        if layerOf(id, simulationLayers) and layerOf(dependency, presentationLayers) then
          crossing[id .. ' -> ' .. dependency] = true
        end
        if id:match('^src%.physics%.') and not dependency:match('^src%.physics%.') and not core then
          failure('PHYSICS DEPENDENCY ' .. id .. ' -> ' .. dependency)
        end
        if id:match('^src%.session%.') and dependency:match('^src%.run%.') then
          failure('SESSION DEPENDENCY ' .. id .. ' -> ' .. dependency)
        end
      end
    end
    if
      (id:match('^src%.physics%.') or id == 'src.world.arena')
      and text:match('love%.graphics')
    then
      failure('GPU IN SIMULATION DATA ' .. id)
    end
    table.sort(graph[id])
  end
  local reachable = {}
  local function visit(id)
    if reachable[id] then
      return
    end
    reachable[id] = true
    for _, dependency in ipairs(graph[id] or {}) do
      visit(dependency)
    end
  end
  visit('main')
  visit('conf')
  for id in pairs(sources) do
    if (id:match('^src%.') or id:match('^tests%.') or id:match('^qa%.')) and not reachable[id] then
      failure('UNREACHABLE MODULE ' .. id)
    end
  end
  local visiting, complete = {}, {}
  local function cycle(id, route)
    if visiting[id] then
      failure('RUNTIME CYCLE ' .. route .. ' -> ' .. id)
      return
    end
    if complete[id] or not id:match('^src%.') then
      return
    end
    visiting[id] = true
    for _, dependency in ipairs(graph[id] or {}) do
      cycle(dependency, route .. ' -> ' .. id)
    end
    visiting[id], complete[id] = nil, true
  end
  local names = {}
  for id in pairs(sources) do
    names[#names + 1] = id
  end
  table.sort(names)
  for _, id in ipairs(names) do
    cycle(id, '')
  end
  -- Every event of the catalogue has an emitter (Signal(g, 'Kind') or
  -- bus:emit('Kind')) somewhere else in the source.
  local catalog = sources['src.session.event_catalog']
  if catalog then
    for kind in catalog:gmatch("{%s*'(%w+)',") do
      local emitted = false
      for id, text in pairs(sources) do
        if
          id ~= 'src.session.event_catalog'
          and (
            text:find("[%w_]+%([%w_%.]+, '" .. kind .. "'") or text:find("emit%('" .. kind .. "'")
          )
        then
          emitted = true
          break
        end
      end
      if not emitted then
        failure('EVENT NEVER EMITTED ' .. kind)
      end
    end
  end
  -- Simulation -> presentation edges against their recorded list.
  local edges = {}
  for edge in pairs(crossing) do
    edges[#edges + 1] = edge
  end
  table.sort(edges)
  local allowed = edgesPath and readLines(edgesPath)
  if edgesPath and not allowed then
    local file = assert(io.open(edgesPath, 'wb'))
    file:write(table.concat(edges, '\n') .. (#edges > 0 and '\n' or ''))
    file:close()
    allowed = crossing
  end
  if allowed then
    for _, edge in ipairs(edges) do
      if not allowed[edge] then
        failure('SIMULATION IMPORTS PRESENTATION ' .. edge .. ' (send an event instead)')
      end
    end
    for edge in pairs(allowed) do
      if not crossing[edge] then
        failure('STALE PRESENTATION EDGE ' .. edge .. ' (remove it from presentation-edges.txt)')
      end
    end
  end
  lines[#lines + 1] = 'SIMULATION -> PRESENTATION EDGES ' .. #edges
  -- The ratchet: no file above its recorded count; the first run records it.
  local governedFiles = {}
  for relative in pairs(numbers) do
    governedFiles[#governedFiles + 1] = relative
  end
  table.sort(governedFiles)
  local current = {}
  for _, relative in ipairs(governedFiles) do
    current[#current + 1] = relative .. ' ' .. numbers[relative]
  end
  local baseline = literalsPath and readBaseline(literalsPath)
  if literalsPath and not baseline then
    local file = assert(io.open(literalsPath, 'wb'))
    file:write(table.concat(current, '\n') .. '\n')
    file:close()
    baseline = numbers
  end
  local unnamed = 0
  for _, relative in ipairs(governedFiles) do
    unnamed = unnamed + numbers[relative]
    local allowed = baseline and baseline[relative] or 0
    if baseline and numbers[relative] > allowed then
      failure(
        'UNNAMED NUMBERS '
          .. relative
          .. ' has '
          .. numbers[relative]
          .. ' (allowed '
          .. allowed
          .. '): name them in content (tuning, combat_defaults, mode data)'
      )
    elseif baseline and numbers[relative] < allowed then
      lines[#lines + 1] = 'RATCHET ' .. relative .. ' can drop to ' .. numbers[relative]
    end
  end
  lines[#lines + 1] = 'UNNAMED NUMBERS IN SIMULATION CODE ' .. unnamed
  if literalsPath then
    local directory = literalsPath:gsub('[\\/][^\\/]*$', '')
    for _, rule in ipairs(scalingRatchets) do
      scalingAudit(rule, scaling[rule.name] or {}, directory, failure, lines)
    end
  end
  table.sort(lines)
  lines[#lines + 1] = ''
  for _, id in ipairs(names) do
    lines[#lines + 1] = id .. ' -> ' .. table.concat(graph[id], ', ')
  end
  for _, message in ipairs(errors) do
    lines[#lines + 1] = 'FAIL ' .. message
  end
  local summary = #names .. ' Lua files compiled; ' .. #errors .. ' architecture issues.'
  lines[#lines + 1] = summary
  local report = assert(io.open(reportPath, 'w'))
  report:write(table.concat(lines, '\n') .. '\n')
  report:close()
  print(summary)
  for _, message in ipairs(errors) do
    print(message)
  end
  return #errors == 0
end

function love.load(arguments)
  local ok, result = xpcall(function()
    return audit(
      assert(arguments[1]),
      assert(arguments[2]),
      assert(arguments[3]),
      arguments[4],
      arguments[5],
      arguments[6]
    )
  end, debug.traceback)
  if not ok then
    print(result)
  end
  love.event.quit(ok and result and 0 or 1)
end
