-- Fit actual painted ink without splitting UTF-8 letters or inventing fonts.
-- Existing short captions are returned verbatim; overflow is visibly elided.
local utf8 = require('utf8')
local Fit = {}
function Fit.ellipsis(font, value, width)
  local text = tostring(value)
  if font:getInk(text).w <= width then
    return text
  end
  local suffix = '...'
  if font:getInk(suffix).w > width then
    return ''
  end
  local ends = {}
  for byte in utf8.codes(text) do
    ends[#ends + 1] = byte
  end
  local low, high, result = 0, #ends, suffix
  while low <= high do
    local count = math.floor((low + high) / 2)
    local prefix = count == 0 and '' or text:sub(1, (ends[count + 1] or (#text + 1)) - 1)
    local candidate = prefix:gsub('%s+$', '') .. suffix
    if font:getInk(candidate).w <= width then
      result, low = candidate, count + 1
    else
      high = count - 1
    end
  end
  return result
end
function Fit.wrap(font, value, width, maximumLines)
  local words = {}
  for word in tostring(value):gmatch('%S+') do
    words[#words + 1] = word
  end
  local lines, line = {}, ''
  for index, word in ipairs(words) do
    local candidate = line == '' and word or (line .. ' ' .. word)
    if font:getInk(candidate).w <= width then
      line = candidate
    elseif #lines + 1 >= maximumLines then
      local rest = line
      for remaining = index, #words do
        rest = rest .. (rest == '' and '' or ' ') .. words[remaining]
      end
      lines[#lines + 1] = Fit.ellipsis(font, rest, width)
      return table.concat(lines, '\n')
    else
      if line ~= '' then
        lines[#lines + 1] = line
      end
      line = Fit.ellipsis(font, word, width)
    end
  end
  if line ~= '' then
    lines[#lines + 1] = line
  end
  return table.concat(lines, '\n')
end
return Fit
