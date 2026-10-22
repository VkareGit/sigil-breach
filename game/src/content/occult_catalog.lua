-- Catalogue and selection shared by the test field and its visual archive.
local A = {}
A.entries = {
  {
    id = 'asmoday',
    name = 'ASMODAY',
    source = 'GOETIA / MATHERS AND CROWLEY / 1904',
    detail = 'Spirit 32 / figure 37 / second plate',
  },
  {
    id = 'stolas',
    name = 'STOLAS',
    source = 'GOETIA / MATHERS AND CROWLEY / 1904',
    detail = 'Spirit 36 / figure 41 / second plate',
  },
  {
    id = 'buer',
    name = 'BUER',
    source = 'GOETIA / MATHERS AND CROWLEY / 1904',
    detail = 'Spirit 10 / figure 11 / first plate',
  },
  {
    id = 'saturn_1',
    name = 'SATURN / PENTAKL I',
    source = 'KEY OF SOLOMON / MATHERS / 1889',
    detail = 'Clavicula Salomonis / plate II / figure 11',
  },
  {
    id = 'saturn_2',
    name = 'SATURN / PENTAKL II',
    source = 'KEY OF SOLOMON / MATHERS / 1889',
    detail = 'Clavicula Salomonis / plate II / figure 12',
  },
  {
    id = 'saturn_3',
    name = 'SATURN / PENTAKL III',
    source = 'KEY OF SOLOMON / MATHERS / 1889',
    detail = 'Clavicula Salomonis / plate II / figure 13',
  },
}
function A.action(g, id)
  if not g.testField then
    return false
  end
  local index = tonumber(tostring(id):match('^archive_(%d+)$'))
  if not index or not A.entries[index] then
    return false
  end
  g.testField.archiveSelection = index
  return true
end
return A
