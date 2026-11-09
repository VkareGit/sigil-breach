-- Linux: one way of travelling a step and one landing for every body (PLAN
-- E2e, 2026-11-09, owner's decision), two identical native runs. A creature's
-- stride travels its step exactly for its constant acceleration, as the
-- knight's does, and keeps its own velocity projected by the walls (it was the
-- distance over the step): a start from rest goes about 2 cm less in its first
-- second (imp 4.090 -> 4.071 m, Ember 3.092 -> 3.073 m), the same speed after.
-- A knight landing inside a step flies until his feet meet the floor and is on
-- the ground for the rest of it: the same landing step, under 5 mm. The
-- scenarios are long fights, so their courses and contacts diverge from these
-- small changes; no AI clock, damage or balance changed. Windows remains
-- unverified (tests/golden/baseline.lua is not regenerated here).
return {
  playtest = 'caf66543/9c228f4f',
  human = '5b8fbefe/4d8899a6',
  drill = '43178c10/40423647',
  playtestContacts = '635ea19e/139',
  humanContacts = '31a2dcc9/164',
  drillContacts = 'cf90111b/372',
}
