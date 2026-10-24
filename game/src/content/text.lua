-- Text content is data: named parameters assemble existing painted glyphs.
-- Templates are compiled once; changing counters never creates a string cache.
local Registry = require('src.core.registry')
local Text = {}
local registry = Registry:new('text key')
function Text.register(id, template)
  assert(not registry:has(id), 'text key already registered: ' .. tostring(id))
  assert(type(template) == 'string', 'text key ' .. tostring(id) .. ': expected template')
  local tokens, position, dynamic = {}, 1, false
  while position <= #template do
    local first, last, name = template:find('{([%a_][%w_]*)}', position)
    local literal = template:sub(position, first and first - 1 or #template)
    assert(not literal:find('[{}]'), 'text key ' .. tostring(id) .. ': invalid placeholder')
    tokens[#tokens + 1] = { literal = literal }
    if not first then
      break
    end
    tokens[#tokens + 1] = { parameter = name }
    dynamic = true
    position = last + 1
  end
  return registry:register(id, { template = template, tokens = tokens, dynamic = dynamic })
end
function Text.unregister(id)
  return registry:unregister(id)
end
function Text.each()
  return registry:each()
end
function Text.get(id, parameters)
  local entry = registry:get(id)
  if not entry.dynamic then
    return entry.template
  end
  local out = {}
  for _, token in ipairs(entry.tokens) do
    if token.literal then
      out[#out + 1] = token.literal
    else
      local value = parameters and parameters[token.parameter]
      assert(
        type(value) == 'string'
          or (type(value) == 'number' and value == value and math.abs(value) < math.huge),
        'text key ' .. id .. ': missing/invalid parameter ' .. token.parameter
      )
      out[#out + 1] = tostring(value)
    end
  end
  return table.concat(out)
end
local definitions = {
  { 'health', 'HEALTH' },
  { 'ward', 'WARD' },
  { 'arsenal', 'ARSENAL' },
  { 'souls', 'SOULS' },
  { 'echo', 'ECHO' },
  { 'none', 'NONE' },
  { 'shift', 'SHIFT' },
  { 'ammo', 'AMMO' },
  { 'reserve', 'RES. {count}' },
  { 'ability_key', 'Q {tag}' },
  { 'uses', '{uses} / {capacity}' },
  { 'souls_amount', 'SOULS  {amount}' },
  { 'wave', 'WAVE {wave} / {total}' },
  { 'guardian', 'LIMBO GUARDIAN' },
  { 'preparing', 'Preparation / {wave}' },
  { 'countdown', 'The rite begins in {seconds}' },
  { 'remaining', '{wave} / Remaining: {count}' },
  { 'fragment_recovered', 'Ring fragment recovered.' },
  { 'help_back', 'BACK  [ F1 / ESC ]' },
  { 'help_previous', 'PREVIOUS PAGE' },
  { 'help_next', 'NEXT PAGE' },
  { 'previous_short', 'PREV {page}/{pages}' },
  { 'next_short', 'NEXT' },
  { 'page_count', '{page} / {pages}' },
  { 'help_field', 'PROVING GROUND / [F2] Targets, poses, guns and seals. Never saves the run.' },
  {
    'help_descent',
    '4 waves + guardian. [E] Ember merchant. [ENTER] Ready. Reclaim souls from the echo.',
  },
  {
    'help_classic',
    'Break three seals [E], defeat the defenders and the guardian. Return to the gate.',
  },
  { 'help_reload', 'R: reload. TAB: map. Judge: six rounds.' },
  { 'help_charge', 'Q: powder charge. 1 s fuse. The blast hurts you too.' },
  { 'help_ward', 'Ward: remaining pool. Absorbs 55% of damage until spent.' },
  { 'shop_buying', 'BUYING FOR: {weapon} / WARD {ward}/100' },
  { 'shop_after', 'AFTER: {amount} SOULS' },
  { 'shop_engraving_tip', 'Owned engravings switch for free. One is active.' },
  { 'shop_rest_tip', 'Health restored. The Ember shields you until the wave begins.' },
  { 'weapon_slot', '{slot} {name}' },
}
for _, entry in ipairs(definitions) do
  Text.register(entry[1], entry[2])
end
return Text
