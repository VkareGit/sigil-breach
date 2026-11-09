-- The pilgrimage's screens (ui/chapel.lua): the menu's buttons, the place
-- and the warning in play, the shop, the map, death and the confirmation
-- of a new run. Pixels of the 1280 by 720 frame; a box is { x, y, w, h };
-- a text is { x, y, font } or, centred, { y, font }.
return {
  font = 18,
  panelCorner = 14,
  -- The shop's pages: a row is plain or detailed (two lines), and is
  -- detailed when its name or description does not fit plain.
  rows = { plain = 56, detailed = 80, nameFont = 20, descFont = 16, width = 648 },
  -- The shop's buttons: buy beside each row (first row, its x and size),
  -- travel and back, the pages, and a tab per weapon of the loadout (two
  -- side by side, else sharing their width; a gap between).
  buy = { x = 881, y = 189, w = 270, h = 42 },
  travel = { 824, 593, 328, 48 },
  back = { 128, 593, 310, 48 },
  previous = { 450, 593, 170, 48 },
  next = { 638, 593, 170, 48 },
  weaponTab = { x = 640, y = 137, h = 40, pair = 262, span = 524, gap = 12 },
  -- The main menu's buttons, by id; a saved run splits the second row.
  menu = {
    start = { 72, 390, 400, 54 },
    restart = { 72, 455, 194, 44 },
    fieldShort = { 270, 455, 194, 44 },
    field = { 72, 455, 400, 44 },
    help = { 72, 514, 194, 44 },
    settings = { 270, 514, 194, 44 },
    quit = { 72, 573, 194, 40 },
    skirmish = { 270, 573, 194, 40 },
    slot = { 300, 648, 236, 38 },
  },
  confirmButtons = { yes = { 440, 405, 400, 48 }, keep = { 440, 470, 400, 44 } },
  deadButtons = { retry = { 410, 524, 460, 50 }, menu = { 410, 591, 460, 42 } },
  -- The place in play: its plate, zone, the chapel's name and the place
  -- (smaller where it is wider than the plate); the save warning.
  place = {
    plate = { 20, 16, 378, 64, corner = 9 },
    zone = { 32, 26, 354, 44 },
    title = { 35, 27, 348, 20, font = 14 },
    name = { 35, 48, 348, 22, font = 16, small = 14 },
  },
  saveWarning = { 448, font = 18 },
  shop = {
    veil = 0.9,
    page = { 96, 44, 1088, 628, corner = 14 },
    writing = { 128, 78, 1024, 562 },
    ring = { 129, 84, size = 36 },
    merchant = { 188, 82, 420, 52 },
    soul = { 844, 84, size = 31 },
    wallet = { 892, 84, font = 28 },
    title = { 130, 150, font = 20 },
    buying = { 650, 120, font = 14 },
    -- A row: its top (first, then by row height), the rule over it, the
    -- highlight, the icon, the zone and its text (title, fonts tried when
    -- detailed, description lines).
    row = { y = 183, x = 128, w = 1024, ruleAlpha = 0.22 },
    highlight = { x = 132, inset = 3, w = 730, alpha = 0.22 },
    icon = { x = 145, y = 7, size = 40 },
    zone = { x = 208, w = 650 },
    rowTitle = { x = 209, y = 7, font = 20, fonts = { 20, 18, 16, 14 } },
    description = { y = 32, step = 22, font = 16, lines = 2 },
    -- The purchase message (a long one steps down to smallest), the balance
    -- after a purchase, and the rest message.
    message = {
      zone = { 128, 530, 680, 32 },
      x = 129,
      y = 536,
      font = 18,
      smallest = 14,
      wide = 676,
    },
    balance = { zone = { 824, 530, 328, 28 }, x = 825, y = 536, font = 16 },
    rest = { zone = { 128, 565, 1024, 26 }, x = 129, y = 567, font = 16 },
    warning = { 679, font = 16 },
  },
  map = {
    veil = 0.96,
    page = { 100, 40, 1080, 640 },
    writing = { 132, 76, 1016, 570 },
    fires = { 136, 131, font = 20 },
    -- The fires listed: first row, step, name and state.
    fire = { x = 136, y = 163, step = 39, font = 22, state = { x = 420, y = 5, font = 14 } },
    -- The map: its side and corner; the knight (dot, heading), an enemy, a
    -- lit fire's ring, the Ember's ring and icon, the echo and its name.
    side = 420,
    origin = { 652, 121 },
    knight = { radius = 4, heading = 15 },
    enemy = 4,
    fireRing = 7,
    line = 2,
    ember = { radius = 13, icon = 16 },
    echo = { radius = 7, label = { x = -18, y = -25, font = 14 } },
    legend = { 132, 622, font = 16 },
    marks = { 652, 558, font = 14 },
    pause = { 652, 585, font = 14 },
  },
  ending = {
    veil = 0.95,
    page = { 96, 42, 1088, 628 },
    skull = { 612, 52, size = 56 },
    writing = { 128, 110, 1024, 402 },
    died = { 116, font = 48 },
    kept = { 188, font = 22 },
    echo = { 260, font = 36 },
    warning = { 326, font = 18 },
    harm = { 364, font = 22 },
    stats = { 412, font = 22 },
    saveWarning = { 490, font = 16 },
  },
  confirm = {
    veil = 0.95,
    page = { 250, 144, 780, 432 },
    writing = { 282, 176, 716, 180 },
    inscription = { 410, 185, 460, 54 },
    question = { 273, font = 22 },
    kept = { 315, font = 20 },
  },
}
