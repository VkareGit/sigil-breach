-- Catalogue and selection shared by the test field and its visual archive.
-- name, source and detail are text keys (content/text.lua).
local A = {}
-- The historical seals the interface carries.
A.seals = { 'asmoday', 'stolas', 'buer', 'furfur', 'paimon' }
-- Those in the margins of the help parchment, and where.
A.margins = { { 'asmoday', 110, 326 }, { 'buer', 110, 426 }, { 'stolas', 1134, 370 } }
-- Those a proving ground can visit (names: text keys).
A.visits = {
  { id = 'asmoday', name = 'seal_asmoday' },
  { id = 'stolas', name = 'seal_stolas' },
  { id = 'buer', name = 'seal_buer' },
}
A.entries = {
  {
    id = 'asmoday',
    name = 'archive_asmoday',
    source = 'archive_goetia',
    detail = 'archive_asmoday_detail',
  },
  {
    id = 'stolas',
    name = 'archive_stolas',
    source = 'archive_goetia',
    detail = 'archive_stolas_detail',
  },
  {
    id = 'buer',
    name = 'archive_buer',
    source = 'archive_goetia',
    detail = 'archive_buer_detail',
  },
  {
    id = 'saturn_1',
    name = 'archive_saturn_1',
    source = 'archive_clavicula',
    detail = 'archive_saturn_1_detail',
  },
  {
    id = 'saturn_2',
    name = 'archive_saturn_2',
    source = 'archive_clavicula',
    detail = 'archive_saturn_2_detail',
  },
  {
    id = 'saturn_3',
    name = 'archive_saturn_3',
    source = 'archive_clavicula',
    detail = 'archive_saturn_3_detail',
  },
}

return A
