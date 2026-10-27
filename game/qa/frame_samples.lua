-- Paired frame timings, written before independent percentile sorts destroy
-- their common index. Serialization runs after the measured interval only.
local Samples = {}
Samples.phases = { 'update', 'world', 'ui', 'submit', 'readback', 'total' }
local detail = { 'sample', 'hud', 'observation', 'flush', 'heapBefore', 'heapAfter' }
function Samples.csv(samples)
  local columns = {}
  for _, key in ipairs(Samples.phases) do
    columns[#columns + 1] = key
  end
  for _, key in ipairs(detail) do
    if samples[key] then
      columns[#columns + 1] = key
    end
  end
  local count = #samples.total
  local header = { 'frame' }
  for _, key in ipairs(columns) do
    assert(type(samples[key]) == 'table' and #samples[key] == count, 'unpaired frame phase ' .. key)
    header[#header + 1] = key .. (key:match('^heap') and '_KiB' or '_ms')
  end
  local lines = { table.concat(header, ',') }
  for i = 1, count do
    local row = { tostring(i) }
    for _, key in ipairs(columns) do
      local value = samples[key][i]
      assert(
        type(value) == 'number' and value == value and math.abs(value) < math.huge,
        'invalid frame sample'
      )
      row[#row + 1] = string.format('%.6f', value)
    end
    lines[#lines + 1] = table.concat(row, ',')
  end
  return table.concat(lines, '\n') .. '\n'
end
function Samples.write(output, label, samples)
  assert(label:match('^[%w_%-]+$'), 'invalid frame series label')
  local csv = Samples.csv(samples)
  local file = assert(io.open(output .. '/frames-' .. label .. '.csv', 'wb'))
  file:write(csv)
  file:close()
end
return Samples
