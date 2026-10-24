-- Bounded windows into content lists. Page state belongs to the requesting
-- view, not to these helpers or to the underlying gameplay definitions.
local Pages = {}
function Pages.range(count, page, size)
  assert(
    type(count) == 'number' and count >= 0 and count % 1 == 0,
    'page item count must be a nonnegative integer'
  )
  assert(
    type(size) == 'number' and size >= 1 and size % 1 == 0,
    'page size must be a positive integer'
  )
  local total = math.max(1, math.ceil(count / size))
  page = math.max(1, math.min(total, math.floor(page or 1)))
  return (page - 1) * size + 1, math.min(count, page * size), page, total
end
return Pages
