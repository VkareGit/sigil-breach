-- The historical seals the interface shows (ui/goetic_sigils.lua): each
-- spirit's number in the Goetia, its file, where it is printed and where the
-- scan came from. See assets/art/sigils/SOURCES.txt.
local commons = 'https://commons.wikimedia.org/wiki/File:'
local S = {}
S.entries = {
  paimon = { number = 9, file = 'paimon-1904.png', source = commons .. '09-Paimon_seal01.png' },
  furfur = {
    number = 34,
    file = 'furfur-1904.png',
    source = commons .. '34-Furfur_seal.png',
  },
  asmoday = {
    number = 32,
    file = 'asmoday-1904.png',
    printedPages = '20-21',
    plateScan = 26,
    figure = 37,
    source = commons .. '32-Asmoday_seal.png',
  },
  stolas = {
    number = 36,
    file = 'stolas-1904.png',
    printedPages = '22',
    plateScan = 26,
    figure = 41,
    source = commons .. '36-Stolas_seal.png',
  },
  buer = {
    number = 10,
    file = 'buer-1904.png',
    printedPages = '15',
    plateScan = 6,
    figure = 11,
    source = commons .. '10-Buer_seal.png',
  },
}
S.edition = 'The Book of the Goetia of Solomon the King, Mathers / Crowley, 1904'
S.primary =
  'https://commons.wikimedia.org/wiki/File:The_Book_of_the_Goetia_(Mathers-Crowley,_1904).djvu'
return S
