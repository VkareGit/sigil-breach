-- Sampled sounds to set against the synthesised ones (0.43, D02, the owner's A/B: Codex Astra's
-- pack, work/sound-ab). A set names a family of recordings; classic is the synthesis
-- (audio/recipes.lua). Each cue a set replaces has its event folder under root and three takes
-- (B1-1..3 for iron, B2-1..3 for stone), played in turn at random, never the same twice running.
-- gain: the pack's integration gain, so a take stands as loud as the cue it replaces.
-- baked: a shot whose takes carry their own low thump and hall; the shot plays no other layers.
return {
  order = { 'classic', 'iron', 'stone' },
  default = 'classic',
  root = 'assets/sounds/',
  takes = 3,
  prefix = { iron = 'B1', stone = 'B2' },
  names = { classic = 'sound_set_classic', iron = 'sound_set_iron', stone = 'sound_set_stone' },
  cues = {
    revolver = { event = 'judge', gain = 1.76, baked = true },
    shot = { event = 'exorcist', gain = 1.204, baked = true },
    hit_tick = { event = 'cialo', gain = 0.760 },
    hit_armor = { event = 'pancerz', gain = 0.772 },
    hit_head = { event = 'glowa', gain = 0.751 },
    kill_confirm = { event = 'zabojstwo', gain = 0.761 },
    blast = { event = 'ladunek', gain = 1.144 },
  },
}
