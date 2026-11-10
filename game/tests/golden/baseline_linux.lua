-- Linux: fire takes no blow away from a small creature (owner's decision D24,
-- "the parry only", 2026-11-10), two identical native runs. Every blow of the
-- Ember Thrall (but its leap), the Star Acolyte and the Plague Gardener is
-- steady: a guard broken in it falls when it has struck, and a major wound
-- taken in a steady blow no longer stops it either; the body reels when the
-- blow ends. A shot in a blow's parry window stops it as before. The careful
-- knight's walk (playtest) is the same to the digest; the clumsy knight's walk
-- (human) and the drill meet blows that fire used to throw away, so their
-- courses and contacts change (human contacts 164 -> 160, drill 372 -> 335).
-- No health, damage, clock or timing of a creature changed. Windows remains
-- unverified (tests/golden/baseline.lua is not regenerated here).
return {
  playtest = 'caf66543/9c228f4f',
  human = 'a1a1d2c5/318a80f7',
  drill = '81318b5e/735979af',
  playtestContacts = '635ea19e/139',
  humanContacts = 'd04068d6/160',
  drillContacts = 'b247fd5e/335',
}
