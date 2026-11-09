-- The score of the circles as data (PLAN G7: music is content); audio/soundscape.lua
-- renders and mixes it.
-- A chant in the first mode (D) sung by a small choir of men over a held
-- ison, an organum a fifth below with an organ under it, a frame drum's
-- heartbeat, and the knell of bells over the organ's open fifths. Every layer
-- loops in the chant's own time, so all of them stay aligned while the mood
-- brings them in and out. Nothing here is a recording: all of it is sung by
-- audio/synth.lua when the game starts.
--
-- The chant's first line is the Dies irae (13th c., public domain); the other
-- lines are the game's own, sung on the sequence's words.
local Score = {}
-- One unit of the chant (s) and the rate the score renders at (Hz). The loop
-- lasts the chant's units.
Score.unit = 0.75
Score.rate = 22050
-- Pythagorean tuning from D3, pure fifths as the chant was sung: a note's
-- frequency is the tonic x 2^(octave - 3) x its ratio (C lies below D).
Score.tonic = 146.832
Score.ratios = {
  C = 8 / 9,
  D = 1,
  E = 9 / 8,
  F = 32 / 27,
  G = 4 / 3,
  A = 3 / 2,
  Bb = 128 / 81,
  B = 27 / 16,
}
-- A man's vowels: formants {Hz, dB, bandwidth Hz}. A syllable sings its last
-- vowel ('y' as 'i'). The choir is heard up to ceiling Hz.
Score.ceiling = 4200
Score.vowels = {
  a = { { 600, 0, 60 }, { 1040, -7, 70 }, { 2250, -9, 110 }, { 2450, -9, 120 }, { 2750, -20, 130 } },
  e = {
    { 400, 0, 40 },
    { 1620, -12, 80 },
    { 2400, -9, 100 },
    { 2800, -12, 120 },
    { 3100, -18, 120 },
  },
  i = {
    { 250, 0, 60 },
    { 1750, -30, 90 },
    { 2600, -16, 100 },
    { 3050, -22, 120 },
    { 3340, -28, 120 },
  },
  o = {
    { 400, 0, 40 },
    { 750, -11, 80 },
    { 2400, -21, 100 },
    { 2600, -20, 120 },
    { 2900, -40, 120 },
  },
  u = {
    { 350, 0, 40 },
    { 600, -20, 80 },
    { 2400, -32, 100 },
    { 2675, -28, 120 },
    { 2950, -36, 120 },
  },
}
-- An organ's principal with its octave, fifth and a small mixture (harmonic
-- amplitudes 1..16).
Score.organ = { 1, 0.45, 0.22, 0.18, 0.08, 0.10, 0, 0.08, 0, 0.03, 0, 0.04, 0, 0, 0, 0.02 }
-- The chant: notes ('F3', 'D3:2' for two units, '-' a breath of one unit) and
-- the words sung on them, one syllable a note.
Score.chant = {
  { notes = 'F3 E3 F3 D3 E3 C3 D3 D3:2 -', words = 'Di es i rae di es il la' },
  { notes = 'F3 F3 G3 F3 E3 D3 C3 D3:2 -', words = 'sol vet sae clum in fa vil la' },
  { notes = 'A3 G3 A3 F3 G3 E3 D3 D3:2 -', words = 'tes te Da vid cum Si byl la' },
  { notes = 'D3 C3 D3 F3 E3 D3 C3 D3:2 -', words = 'quan tus tre mor est fu tu rus' },
}
-- A sung voice: cents between singers, their entries (s apart), vibrato
-- (share of the pitch) and its rate (Hz, + per singer), breath riding the
-- voice, attack and release (s), legato (s a note overlaps the next).
Score.voice = {
  spread = 6,
  stagger = 0.017,
  vibrato = 0.004,
  vibratoRate = 4.8,
  vibratoStep = 0.45,
  breath = 0.18,
  attack = 0.07,
  release = 0.22,
  legato = 0.06,
}
-- The layers, each a loop of the whole chant. kind: how it is rendered
-- (soundscape: kinds); level: its loudness (RMS) before the mood's gain;
-- hall: the nave it rings in (Synth.hall: time RT60 s, wet mix).
Score.layers = {
  -- The ison: the choir holds the final and its fifth under everything,
  -- each singer breathing at his own time.
  {
    id = 'ison',
    kind = 'drone',
    notes = { 'D2', 'A2' },
    vowel = 'o',
    singers = 3,
    breaths = 4,
    level = 0.12,
    hall = { time = 4.2, mix = 0.45 },
  },
  -- The chant, the small choir in unison.
  { id = 'chant', kind = 'chant', singers = 3, level = 0.13, hall = { time = 3.8, mix = 0.4 } },
  -- Organum: a second choir a fifth below the chant; the organ doubles the
  -- chant an octave under.
  {
    id = 'organum',
    kind = 'chant',
    interval = 2 / 3,
    singers = 3,
    organ = { ratio = 0.5, gain = 0.45 },
    level = 0.12,
    hall = { time = 4.0, mix = 0.45 },
  },
  -- The heartbeat: a frame drum each unit, a deeper stroke on each line.
  {
    id = 'heart',
    kind = 'pulse',
    beat = { pitch = 44, dub = 0.24, length = 0.9 },
    line = { pitch = 34, dub = 0.3, length = 1.2, gain = 0.9 },
    level = 0.10,
    hall = { time = 2.2, mix = 0.22 },
  },
  -- The knell: the great bell every fourth unit, a smaller one answering,
  -- over the organ's open fifths, one chord a line (i - VI - VII - i).
  {
    id = 'knell',
    kind = 'knell',
    bells = {
      { prime = 'D3', every = 4, at = 0, ring = 6, gain = 1 },
      { prime = 'A3', every = 8, at = 6, ring = 4, gain = 0.5 },
    },
    chords = { 'D2 A2 D3', 'Bb1 F2 Bb2', 'C2 G2 C3', 'D2 A2 D3' },
    organ = 0.35,
    level = 0.12,
    hall = { time = 4.6, mix = 0.5 },
  },
}
-- Each mood's layer gains (x the player's music volume; a missing layer is
-- silent). 'battle' is not a mood of its own: it blends calm into fight by
-- the danger near the knight (soundscape: intensity).
Score.moods = {
  menu = { ison = 0.5, chant = 0.6 },
  calm = { ison = 0.5, chant = 0.55, organum = 0.15 },
  fight = { ison = 0.42, chant = 0.38, organum = 0.55, heart = 0.65 },
  guardian = { ison = 0.3, chant = 0.3, organum = 0.5, heart = 0.8, knell = 0.6 },
  rest = { ison = 0.45, chant = 0.3 },
  death = { ison = 0.45, knell = 0.4 },
  victory = { ison = 0.5, chant = 0.6, organum = 0.45, knell = 0.2 },
}
-- The mood of a session state other than play (soundscape.mood decides play).
Score.states = {
  menu = 'menu',
  dead = 'death',
  won = 'victory',
  paused = 'rest',
  shop = 'rest',
  settings = 'rest',
}
-- Danger: the summed threat that is a full fight, and how fast the intensity
-- follows it (per second, rising / falling).
Score.danger = { full = 3, rise = 1.6, fall = 0.5 }
-- How fast a layer's gain follows its mood (per second, rising / falling).
Score.follow = { rise = 0.9, fall = 0.4 }
-- How the score is performed (audio/soundscape.lua): the music's level
-- before the settings are read; how fast it ducks under a warning (and to
-- what) and follows a scene; a singer's breath (how long the dip lasts, how
-- deep, the slow sway, and the steps that place each singer's breaths); a
-- drone's vibrato share; a chant line's swell (base and rise); the organ
-- under a chant and under a knell (attack, release); the heartbeat's level;
-- the knell organ's detuned double (cents).
Score.performance = {
  music = 0.65,
  duck = 0.48,
  duckRates = { rise = 2.5, fall = 18 },
  sceneRates = { rise = 0.8, fall = 1.5 },
  breath = { dip = 0.45, deep = 0.8, sway = 0.12, singerStep = 2.3, noteStep = 1.1 },
  droneVibrato = 0.6,
  swell = { base = 0.82, rise = 0.18 },
  chantOrgan = { attack = 0.05, release = 0.18 },
  knellOrgan = { attack = 0.12, release = 0.4, detune = 3 },
  pulse = 0.75,
}
return Score
