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

local function audit(manifest, root, reportPath, literalsPath, edgesPath)
  local sources, graph, errors, lines, numbers, crossing = {}, {}, {}, {}, {}, {}
  local function failure(message)
    errors[#errors + 1] = message
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
    sources[id] = text
    graph[id] = {}
    lines[#lines + 1] = 'COMPILE ' .. relative
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
          and not (id == 'src.app.application' and dependency == 'qa.runtime')
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
      arguments[5]
    )
  end, debug.traceback)
  if not ok then
    print(result)
  end
  love.event.quit(ok and result and 0 or 1)
end
