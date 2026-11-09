-- Literal-only reader for core.serialize's stable bracketed-table format.
-- No Lua source is compiled or evaluated, even when the input is malformed.
local Reader = {}
-- The bytes the reader tells apart, named by their characters.
local BACKSLASH = ('\\'):byte()
local CLOSE = ('}'):byte()
local DOT = ('.'):byte()
local DQUOTE = ('"'):byte()
local LOWER_E = ('e'):byte()
local MINUS = ('-'):byte()
local NEWLINE = ('\n'):byte()
local NINE = ('9'):byte()
local OPEN = ('{'):byte()
local PLUS = ('+'):byte()
local RETURN = ('\r'):byte()
local SPACE = (' '):byte()
local SQUOTE = ("'"):byte()
local TAB = ('\t'):byte()
local UPPER_E = ('E'):byte()
local ZERO = ('0'):byte()
local DOUBLE_SPECIAL = '[' .. string.char(BACKSLASH, DQUOTE, NEWLINE, RETURN) .. ']'
local SINGLE_SPECIAL = '[' .. string.char(BACKSLASH, SQUOTE, NEWLINE, RETURN) .. ']'
local DEFAULTS = {
  maxBytes = 128 * 1024 * 1024, -- constant: reader limit, 128 MiB
  -- A normal recording may approach 64 MiB plus its final command. This
  -- ceiling must not reject that archive merely because its keys are short.
  maxValues = 32 * 1024 * 1024, -- constant: reader limit, 32 Mi values
  maxDepth = 128, -- constant: reader limit
  maxString = 16 * 1024 * 1024, -- constant: reader limit, 16 MiB
}
Reader.depthLimit = DEFAULTS.maxDepth
local escapes = {
  a = '\a',
  b = '\b',
  f = '\f',
  n = '\n',
  r = '\r',
  t = '\t',
  v = '\v',
  ['\\'] = '\\',
  ['"'] = '"',
  ["'"] = "'",
}
local function finite(n)
  return type(n) == 'number' and n == n and math.abs(n) < math.huge
end
function Reader.decode(text, options)
  if type(text) ~= 'string' then
    return nil, 'serialized input must be a string'
  end
  local limits = {}
  if options ~= nil and type(options) ~= 'table' then
    return nil, 'invalid reader limits'
  end
  for key, value in pairs(DEFAULTS) do
    limits[key] = options and options[key]
    if limits[key] == nil then
      limits[key] = value
    end
    if not finite(limits[key]) or limits[key] < 1 or limits[key] % 1 ~= 0 then
      return nil, 'invalid reader limit: ' .. key
    end
  end
  if #text > limits.maxBytes then
    return nil, 'serialized input exceeds byte limit'
  end
  local position, values, length = 1, 0, #text
  local function fail(message)
    error(message .. ' at byte ' .. position, 0)
  end
  local function white()
    while position <= length do
      local b = text:byte(position)
      if b ~= SPACE and (b < TAB or b > RETURN) then
        break
      end
      position = position + 1
    end
  end
  local function expect(character)
    white()
    if text:sub(position, position) ~= character then
      fail('expected ' .. character)
    end
    position = position + 1
  end
  local function quoted()
    local quote = text:byte(position)
    position = position + 1
    local nextSpecial = text:find(quote == DQUOTE and DOUBLE_SPECIAL or SINGLE_SPECIAL, position)
    if nextSpecial and text:byte(nextSpecial) == quote then
      if nextSpecial - position > limits.maxString then
        fail('string exceeds byte limit')
      end
      local value = text:sub(position, nextSpecial - 1)
      position = nextSpecial + 1
      return value
    end
    local segment, size, chunks = position, 0, {}
    local function add(value)
      size = size + #value
      if size > limits.maxString then
        fail('string exceeds byte limit')
      end
      chunks[#chunks + 1] = value
    end
    while position <= length do
      local b = text:byte(position)
      if size + position - segment > limits.maxString then
        fail('string exceeds byte limit')
      end
      if b == quote then
        add(text:sub(segment, position - 1))
        position = position + 1
        return table.concat(chunks)
      elseif b == BACKSLASH then
        add(text:sub(segment, position - 1))
        position = position + 1
        local escaped = text:sub(position, position)
        local byte = text:byte(position)
        if escapes[escaped] then
          add(escapes[escaped])
          position = position + 1
        elseif byte and byte >= ZERO and byte <= NINE then
          local start = position
          repeat
            position = position + 1
            byte = text:byte(position)
          until position - start == 3 or not byte or byte < ZERO or byte > NINE -- constant: \ddd
          local code = tonumber(text:sub(start, position - 1))
          if code > 255 then -- constant: the largest byte
            fail('invalid decimal string escape')
          end
          add(string.char(code))
        elseif escaped == 'x' then
          local hex = text:sub(position + 1, position + 2)
          if #hex ~= 2 or not hex:match('^%x%x$') then
            fail('invalid hexadecimal string escape')
          end
          add(string.char(tonumber(hex, 16))) -- constant: hexadecimal
          position = position + 3
        elseif byte == NEWLINE or byte == RETURN then
          position = position + 1
          if byte == RETURN and text:byte(position) == NEWLINE then
            position = position + 1
          end
          add('\n')
        else
          fail('invalid string escape')
        end
        segment = position
      elseif b == NEWLINE or b == RETURN then
        fail('unescaped line break in string')
      else
        position = position + 1
      end
    end
    fail('unterminated string')
  end
  local function scanDigits()
    local start = position
    while position <= length do
      local byte = text:byte(position)
      if byte < ZERO or byte > NINE then
        break
      end
      position = position + 1
    end
    return position - start
  end
  local function number()
    local start = position
    local b = text:byte(position)
    if b == PLUS or b == MINUS then
      position = position + 1
    end
    local digits = scanDigits()
    if text:byte(position) == DOT then
      position = position + 1
      digits = digits + scanDigits()
    end
    if digits == 0 then
      fail('invalid number')
    end
    b = text:byte(position)
    if b == UPPER_E or b == LOWER_E then
      position = position + 1
      b = text:byte(position)
      if b == PLUS or b == MINUS then
        position = position + 1
      end
      digits = scanDigits()
      if digits == 0 then
        fail('invalid exponent')
      end
    end
    local value = tonumber(text:sub(start, position - 1))
    if not finite(value) then
      fail('non-finite number')
    end
    return value
  end
  local parse
  parse = function(depth)
    white()
    values = values + 1
    if values > limits.maxValues then
      fail('value count exceeds limit')
    end
    if depth > limits.maxDepth then
      fail('nesting exceeds limit')
    end
    local byte = text:byte(position)
    if byte == DQUOTE or byte == SQUOTE then
      return quoted()
    end
    if byte == MINUS or byte == PLUS or byte == DOT or (byte and byte >= ZERO and byte <= NINE) then
      return number()
    end
    if byte == OPEN then
      position = position + 1
      local result, seen = {}, {}
      white()
      while text:byte(position) ~= CLOSE do
        expect('[')
        local key = parse(depth + 1)
        if type(key) ~= 'string' and type(key) ~= 'number' and type(key) ~= 'boolean' then
          fail('invalid table key')
        end
        if seen[key] then
          fail('duplicate table key')
        end
        seen[key] = true
        expect(']')
        expect('=')
        result[key] = parse(depth + 1)
        white()
        if text:byte(position) == CLOSE then
          break
        end
        expect(',')
        white()
      end
      position = position + 1
      return result
    end
    for _, keyword in ipairs({ 'true', 'false', 'nil' }) do
      if text:sub(position, position + #keyword - 1) == keyword then
        position = position + #keyword
        if keyword == 'nil' then
          return nil
        end
        return keyword == 'true'
      end
    end
    fail('expected a data literal')
  end
  local ok, value = pcall(function()
    white()
    -- A single optional return is a file wrapper, never a Lua statement parser.
    if
      text:sub(position, position + 5) == 'return'
      and not text:sub(position + 6, position + 6):match('[%w_]')
    then
      position = position + 6
    end
    local result = parse(0)
    white()
    if position <= length then
      fail('trailing input')
    end
    return result
  end)
  if not ok then
    return nil, value
  end
  return value
end
return Reader
