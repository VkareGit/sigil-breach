-- Rewrite serialized definition paths before decoding the old pool section.
-- A committed legacy action completes once; future choices use current content.
local Paths = require('src.content.migrations.pool_definitions')
local Migration = {}
function Migration.pools(data, version)
  local function visit(value)
    if type(value) ~= 'table' then
      return
    end
    local path = value['$def']
    if path then
      for _, rule in ipairs(Paths) do
        local matches = not version or version <= rule.through
        for i, word in ipairs(rule.from) do
          matches = matches and path[i] == word
        end
        if matches then
          local replacement = {}
          for _, word in ipairs(rule.to) do
            replacement[#replacement + 1] = word
          end
          for i = #rule.from + 1, #path do
            replacement[#replacement + 1] = path[i]
          end
          value['$def'] = replacement
          break
        end
      end
      return
    end
    for _, child in pairs(value) do
      visit(child)
    end
  end
  visit(data.pools)
  return data
end
return Migration
