local Test = {}
function Test.run()
  local Serialize = require('src.core.serialize')
  local lines = {}
  local check =
    require('tests.support.fixtures').checker(lines, 'serialization: ', 'serialization: ')
  local bytes = {}
  for code = 0, 255 do
    bytes[#bytes + 1] = string.char(code)
  end
  local data = {
    bytes = table.concat(bytes),
    text = 'Zażółć gęślą jaźń / "quotes" / \\ / \n',
    numbers = { 0, -0.0, -42.5, 1.2345678901234567, 1.1e-220, -1.1e220 },
    nested = { [false] = true, [true] = false, [1.5] = 'fractional key', array = { 'one', 'two' } },
  }
  local encoded = Serialize.encode(data)
  local decoded, problem = Serialize.decode(encoded)
  check(
    'all256 bytes, Polish text, escapes, booleans and numeric precision round trip',
    decoded and not problem and Serialize.encode(decoded) == encoded
  )
  local value, err = Serialize.decode('false')
  check(
    'top-level false is preserved rather than confused with failure',
    value == false and err == nil
  )
  value, err = Serialize.decode('nil')
  check('nil literal has no parse diagnostic', value == nil and err == nil)
  value, err = Serialize.decode('  return { ["x"] = -2.5e+2, [true] = "ok", } \n')
  check(
    'literal file wrapper and whitespace need no execution',
    value and value.x == -250 and value[true] == 'ok' and not err
  )
  value, err = Serialize.decode([["\x41\065\n\r\t\a\b\f\v\\\"\'"]])
  check('Lua byte escapes are read as data', value == 'AA\n\r\t\a\b\f\v\\"\'' and not err)
  for _, text in ipairs({
    '(function() return {} end)()',
    'setmetatable({}, {})',
    '1 + 2',
    '0/0',
    'os.execute("x")',
    'while true do end',
    '{["x"]=function() end}',
    'return {} return {}',
    'true garbage',
    'nan',
    'inf',
    '1e999',
    '1e+',
    '.',
    '[[]]',
    '{[nil]=1}',
    '{[{}]=1}',
    '{["same"]=1,["same"]=2}',
    '{[1]=1,[1.0]=2}',
    '{[2]=}',
    '{[1]=true',
    '"unterminated',
    [["\999"]],
    [["\q"]],
    [["\x0z"]],
    '"raw\nnewline"',
  }) do
    local rejected, diagnostic = Serialize.decode(text)
    check(
      'rejects non-data or malformed literal ' .. text:gsub('\n', '\\n'),
      rejected == nil and type(diagnostic) == 'string'
    )
  end
  check(
    'input bytes are bounded before parsing',
    select(2, Serialize.decode('"123456"', { maxBytes = 4 })) ~= nil
  )
  check(
    'decoded string length is bounded including escapes',
    select(2, Serialize.decode([["\065\066\067"]], { maxString = 2 })) ~= nil
  )
  check(
    'value count bounds broad tables',
    select(2, Serialize.decode('{[1]=1,[2]=2}', { maxValues = 3 })) ~= nil
  )
  check(
    'depth bounds nesting without overflowing the Lua stack',
    select(2, Serialize.decode('{[1]={[1]={[1]=true}}}', { maxDepth = 1 })) ~= nil
  )
  check(
    'non-finite configured limits are rejected',
    select(2, Serialize.decode('{}', { maxValues = math.huge })) ~= nil
  )
  local Preferences = require('src.storage.preferences')
  local prefs =
    Preferences.decode('sensitivity=1.5\nmotion=false\nfov=107\nmusic=0.2\nhints=true\nmuted=false')
  local reread = Preferences.decode(Preferences.encode(prefs))
  check(
    'independent settings text remains round-trip compatible',
    reread.sensitivity == 1.5
      and reread.motion == false
      and reread.fov == 107
      and reread.music == 0.2
      and reread.hints == true
      and reread.muted == false
  )
  return lines
end
return Test
