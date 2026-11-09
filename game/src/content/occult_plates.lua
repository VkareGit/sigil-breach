-- The Clavicula plate the interface shows (ui/occult_plates.lua): the
-- original figure regions of the page, in pixels of the scan.
local P = {}
P.entries = {
  saturn_1 = { figure = 11, page = '58', rect = { 291, 34, 289, 324 } },
  saturn_2 = { figure = 12, page = '59', rect = { 7, 433, 288, 322 } },
  saturn_3 = {
    figure = 13,
    page = '59',
    rect = { 291, 433, 289, 323 },
  },
}
P.path = 'assets/art/sigils/clavicula-saturn-plate-ii.png'
return P
