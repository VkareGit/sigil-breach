-- Read-only durability audit: definition math, real traced contacts and an
-- explicit weapon clock. A stationary ray sample is not a live-fight TTK.
local Fixtures = require('tests.support.fixtures')
local T = {}
local D = require('src.combat.damage')
local W = require('src.content.weapons')
local Tune = require('src.content.tuning')
local Def = require('src.content.enemy_catalog')
local B = require('src.combat.ballistics')
local Pose = require('src.enemies.pose')
local Geometry = require('src.enemies.geometry')
local kinds = { 'imp', 'stolas', 'buer', 'armored', 'boss', 'furfur' }
local distances = { 4, 8, 16, 30 }
local function finite(x)
  return type(x) == 'number' and x == x and math.abs(x) < math.huge
end
local near = Fixtures.within(1e-7, true)
local function copy(source)
  local dest = {}
  for key, value in pairs(source) do
    dest[key] = value
  end
  return dest
end
function T.schedule(hp, damageA, damageB, slot)
  if damageA + damageB <= 0 then
    return {
      reachable = false,
      shots = 0,
      reloads = 0,
      manual = math.huge,
      held = math.huge,
      ammo = 0,
      starting = false,
    }
  end
  local remaining, shots = hp, 0
  while remaining > 1e-7 and shots < 10000 do
    remaining = remaining - (shots % 2 == 0 and damageA or damageB)
    shots = shots + 1
  end
  local profile = W.profile(slot)
  local capacity = slot == 1 and 1 or profile.capacity
  local reloads = math.floor((shots - 1) / capacity)
  local cycle = profile.cycle
  local reload = slot == 1 and Tune.shotgunCycle or Tune.revolverReload
  local manual = (shots - 1) * cycle
    + (slot == 2 and reloads * (math.max(cycle, reload) - cycle) or 0)
  local held = (shots - 1) * cycle + (slot == 2 and reloads * reload or 0)
  local ammo = shots * (slot == 1 and 2 or 1)
  return {
    reachable = true,
    shots = shots,
    reloads = reloads,
    manual = manual,
    held = held,
    ammo = ammo,
    starting = ammo <= profile.capacity + profile.startReserve,
  }
end
function T.analytic(kind, slot, distance)
  local def = Def[kind]
  local attack = W.attack({ run = { glyph = 'none' } }, slot)
  local target = { armorRating = def.armor, resistances = def.resistances }
  local count = slot == 1 and Tune.shotgunPellets or 1
  local torso, head = 0, 0
  if distance <= W.profile(slot).range then
    torso = D.resolve(attack, target, distance, 'torso') * count
    head = D.resolve(attack, target, distance, 'head') * count
  end
  return {
    torso = torso,
    head = head,
    bodyClock = T.schedule(def.hp, torso, torso, slot),
    headClock = T.schedule(def.hp, head, head, slot),
  }
end
local map = {}
for z = 1, 81 do
  map[z] = {}
  for x = 1, 81 do
    map[z][x] = 0
  end
end
function T.sample(kind, slot, distance, aim, frame, serial)
  local def = Def[kind]
  local e = {
    kind = def.kind,
    variant = def.variant,
    id = 1,
    x = 41,
    z = 41,
    hp = def.hp,
    maxHp = def.hp,
    armorRating = def.armor,
    resistances = def.resistances,
    walk = 0,
    walkSpeed = 0,
    phase = 0,
    ai = 'idle',
    facing = math.pi,
    awake = true,
    memory = 60,
    previewFrame = frame or 1,
  }
  local g = {
    world = { size = 81, map = map },
    player = { x = 41, z = 41 + distance, yaw = math.pi, pitch = 0, jump = 0, crouch = 0 },
    enemies = { e },
    testField = {},
    time = 0,
    weapon = slot,
    run = { glyph = 'none' },
  }
  local p = g.player
  -- Independent source-pixel aim, measured on the current paintings. Collider
  -- centres cannot prove that their own head region is actually reachable.
  local marks = {
    imp = { [1] = { head = { 174, 50 }, torso = { 140, 101 } }, [25] = { head = { 430, 110 } } },
    armored = { [1] = { head = { 179, 45 }, torso = { 149, 94 } }, [25] = { head = { 533, 107 } } },
    stolas = { [1] = { head = { 130, 96 }, torso = { 131, 148 } }, [25] = { head = { 405, 99 } } },
    buer = { [1] = { head = { 207, 125 }, torso = { 172, 181 } }, [17] = { head = { 428, 182 } } },
    boss = { [1] = { head = { 205, 55 }, torso = { 168, 104 } }, [17] = { head = { 417, 125 } } },
    furfur = { [1] = { head = { 250, 115 }, torso = { 176, 137 } }, [25] = { head = { 596, 218 } } },
  }
  local art = Pose.sample(g, e)
  local point = assert(marks[kind][art.frame][aim], 'missing independent source aim')
  local image = love.image.newImageData(art.sourcePath)
  local iw, ih = image:getDimensions()
  assert(
    select(4, image:getPixel(point[1], point[2])) > 0.65,
    'durability aim must lie on source pigment'
  )
  image:release()
  local r = art.region.rect
  local u, v =
    (point[1] + 0.5 - r[1] * iw) / (r[3] * iw), (point[2] + 0.5 - r[2] * ih) / (r[4] * ih)
  local up = (1 - v) * art.sy * art.size
  local tx = e.x + (u - 0.5) * art.sx * art.size + up * art.lean
  local ty = art.baseY + up
  local _, eye = B.origin(g)
  local dx, dz = tx - p.x, e.z - p.z
  p.yaw = math.atan2(dx, dz)
  p.pitch = math.atan2(ty - eye, math.sqrt(dx * dx + dz * dz))
  local attack = W.attack(g, slot)
  local bodies = B.prepare(g)
  local result = { damage = 0, hits = 0, heads = 0, parts = {} }
  for i = 1, slot == 1 and Tune.shotgunPellets or 1 do
    local ox, oy = 0, 0
    if slot == 1 then
      ox, oy = B.pellet(i, serial or 1, Tune.shotgunPellets)
    end
    local rx, ry, rz = B.spreadDirection(p.yaw, p.pitch, ox, oy)
    local hit, d, _, _, _, _, _, part = B.traceVector(g, rx, ry, rz, W.profile(slot).range, bodies)
    if hit then
      result.damage = result.damage + D.resolve(attack, hit, d, part)
      result.hits = result.hits + 1
      result.heads = result.heads + (part == 'head' and 1 or 0)
      result.parts[part] = (result.parts[part] or 0) + 1
    end
  end
  return result
end
local function number(n)
  return n == math.huge and '--' or string.format('%.2f', n)
end
local function clock(c)
  if not c.reachable then
    return '--'
  end
  return string.format(
    '%d / %d / %s / %s%s',
    c.shots,
    c.reloads,
    number(c.manual),
    number(c.held),
    c.starting and '' or ' !ZAPAS'
  )
end
function T.report(output)
  local lines = {
    'WYTRZYMAŁOŚĆ PRZECIWNIKÓW '
      .. require('src.app.release').version
      .. ' — AUDYT BEZ ZMIANY BALANSU',
    '',
    'METODA I GRANICE',
    'Dystans 4/8/16/30 m w pierwszej tabeli jest odległością kontaktu przekazaną do Damage.resolve.',
    'Obrażenia rewolweru są dla jednej kuli. Strzelba: teoretyczny sufit 20 śrucin trafiających dokładnie jedną strefę.',
    'W drugiej tabeli odległość oznacza położenie gracza względem środka celu. Każdy promień wykonuje prawdziwy traceVector; powierzchnia ciała może być bliżej niż środek.',
    'Próbka geometryczna: poza 24 m strzelba nie trafia. Cel stoi, poza pętlą AI; gracz celuje w niezależnie zmierzony piksel głowy lub klatki piersiowej, bez innych przeciwników lub ścian.',
    'To pomiar trafień promieni i oszacowanie czasu broni. NIE jest to zmierzony czas pokonania poruszającego się przeciwnika w walce.',
    'TTK zaczyna się od pierwszego trafienia w chwili 0: pojedyncze śmiertelne trafienie ma TTK=0, bez czasu celowania.',
    'Wszystkie czasy zakładają brak spóźnienia wejścia, uniku, przerwania przeładowania i przestrzelonych strzałów.',
    'Format harmonogramu: liczba strzałów / liczba przeładowań / TTK ręcznie [s] / TTK sam spust [s].',
    'Rewolwer: ręcznie można zacząć reload od razu po opróżnieniu. Sam spust czeka na koniec cyklu .38 s, potem 1.85 s przeładowania.',
    'Strzelba: jedna salwa zużywa dwa naboje; auto-reload mieści się w jej cyklu .94 s.',
    '!ZAPAS oznacza więcej niż startowe 2+28 nabojów strzelby lub 6+24 rewolweru: bez uzupełnienia dany plan zabójstwa nie jest osiągalny.',
    'Poligon F2 po uzupełnieniu daje większe zapasy. Oznaczenie !ZAPAS odnosi się do wyposażenia startowego, nie limitu poligonu.',
    'Pancerz przeciwników to rating, nie drugi pasek HP ani procent redukcji. D = baza * spadek * strefa * 100/(100+rating*(1-penetracja)).',
    'Pancerz gracza ma inną zasadę: zużywa punkty, pochłaniając 55% trafienia do wyczerpania. Napis 40% w HUD nie oznacza 40% redukcji.',
    '',
    '1. IDEALNE TRAFIENIA — TORSO / GŁOWA',
  }
  for _, kind in ipairs(kinds) do
    local def = Def[kind]
    lines[#lines + 1] =
      string.format('\n%s: HP %d, rating pancerza %d', def.name, def.hp, def.armor)
    for slot = 1, 2 do
      for _, distance in ipairs(distances) do
        local a = T.analytic(kind, slot, distance)
        lines[#lines + 1] = string.format(
          '%-11s %2dm | D torso %7s / głowa %7s | T %s | G %s',
          slot == 1 and 'STRZELBA20' or 'REWOLWER',
          distance,
          number(a.torso),
          number(a.head),
          clock(a.bodyClock),
          clock(a.headClock)
        )
      end
    end
  end
  lines[#lines + 1] = '\n2. PRAWDZIWE PROMIENIE W STABILNEJ POZIE 1 — BEZ SYMULACJI ŻYWEJ WALKI'
  lines[#lines + 1] =
    'Każdy wynik łączy dwa naprzemienne seryjne układy śrutu. Podane są oba wyniki obrażeń i trafień; zegar sumuje je naprzemiennie do aktualnego HP.'
  lines[#lines + 1] =
    'Strzelba wycelowana w małą głowę może stracić więcej śrucin, niż zyska dzięki mnożnikowi 1.15. Każde trafienie głowy jest silniejsze, ale cała salwa nie ma gwarancji przewagi nad strzałem w szeroki tułów. Rewolwer otrzymuje czytelniejszą rolę precyzyjną.'
  lines[#lines + 1] =
    'To próba pojedynczego celu: nie uwzględnia przewagi śrutu, który może zranić lub zabić dwa sąsiednie demony jednym wystrzałem.'
  for _, kind in ipairs(kinds) do
    lines[#lines + 1] = '\n' .. Def[kind].name
    for slot = 1, 2 do
      for _, distance in ipairs(distances) do
        for _, aim in ipairs({ 'torso', 'head' }) do
          local a, b =
            T.sample(kind, slot, distance, aim, 1, 1), T.sample(kind, slot, distance, aim, 1, 2)
          local c = T.schedule(Def[kind].hp, a.damage, b.damage, slot)
          lines[#lines + 1] = string.format(
            '%-8s %2dm cel %-5s | D %6s/%6s | trafień %2d/%2d głowa %2d/%2d | %s',
            slot == 1 and 'STRZELBA' or 'REWOLWER',
            distance,
            aim,
            number(a.damage),
            number(b.damage),
            a.hits,
            b.hits,
            a.heads,
            b.heads,
            clock(c)
          )
        end
      end
    end
  end
  lines[#lines + 1] = '\n3. OKNA BOSSÓW I UNIK — WARUNKI Z KODU AI, NIE EMPIRYCZNY TTK GRACZA'
  lines[#lines + 1] =
    'Margrabia: .90 s przygotowania; .23 s fazy strike; .75 s bezruchu odzyskiwania. Poniżej 50% HP wachlarz rośnie z 5 do 7 pocisków, prędkość 4.6 -> 5.3. Po ataku timer wynosi 1.6 s; obejmuje też odzyskiwanie.'
  lines[#lines + 1] =
    'Furfur: .75 s melee / .95 s szarża / 1.10 s piorun; szarża trwa .30-.85 s, zależnie od dystansu; odzyskiwanie .75 s. Kierunek celu zamrożony na początku przygotowania. Piorun obejmuje koło 1.25 m.'
  lines[#lines + 1] =
    'Odwrócony od kamery atak dostaje dodatkowe .26 s ostrzeżenia. Bossowie pozostają ranliwi także podczas przygotowania i ataku: nie ma sztucznego wymogu strzelania wyłącznie w oknie.'
  lines[#lines + 1] =
    'W samym .75 s odzyskiwania mieszczą się 2 kule rewolweru co .38 s lub 1 salwa strzelby, jeżeli broń jest gotowa. To ograniczenie okna, nie gwarantowane bezpieczne DPS, bo mogą pozostać pociski i strefy.'
  lines[#lines + 1] =
    'Unik przesuwa o ok.2.48 m (.155 s *16 m/s), daje .20 s niewrażliwości i odnawia jeden ładunek przez ok.1.28 s (0.78/s). Aktywne okno pazura wynosi .055-.18 s. Dłuższej szarży nie należy tankować samą niewrażliwością: trzeba zejść z toru.'
  lines[#lines + 1] = '\n4. WNIOSKI BALANSOWE — BEZ ARBITRALNEGO SKALOWANIA'
  lines[#lines + 1] =
    'Role 0.20 (playtest: mięso armatnie padało od każdej salwy): Akolita 76 HP pada od salwy z 8 m (~81) lub jednej głowy z rewolweru (94.5), nie od korpusu (70); Sługa 112 HP przeżywa salwę z 8 m (~102), ginie z przyłożenia i w ciasnej parze (~120 każdy); Ogrodnik 150 HP; Żelazny Sługa 170/60 wymaga penetracji, głowy lub bliskiej strzelby; bossowie 1000/30 i 1400/35 mają gardę 300 i 400 (zachwianie).'
  lines[#lines + 1] =
    'Bliski rewolwer 0.20: Akolita 2/1, Sługa 2/2 (głowa + korpus), Ogrodnik 3/2, Żelazny Sługa 4/3 strzały torso/głowa. Progi ran: Sługa 50.4, Ogrodnik 60, Żelazny 68 — korpus z rewolweru (70) rani mięso, nie pancerz (53.8), głowa (72.7) rani pancerz.'
  lines[#lines + 1] =
    'Strzelba jest deterministyczna (bez losowania), więc marginesy kilku HP nie przełączają się między strzałami. Para rozstawiona 1.2 m na 3–5 m dostaje 96–108 na ciało: oba ciała blisko śmierci, dobicie kończy. Zmiany wynikają z obserwacji gry, nie z arbitralnego skalowania.'
  lines[#lines + 1] =
    'Nie należy ratować niecelnego śrutu lub zasłoniętej głowy obniżeniem HP. Najpierw poprawna kalibracja widocznej anatomii i rozrzutu, dopiero potem test fal. Bardzo daleki Furfur może wymagać więcej niż startowych 30 kul w tors; precyzja, podejście bliżej lub zapas mają realne znaczenie.'
  lines[#lines + 1] =
    'Wiarygodna końcowa decyzja o HP bossów wymaga pomiaru aktywnej walki: liczby pełnych cykli, odsetka trafień, czasu poza linią ognia i pozostałego zapasu. Sam statyczny TTK nie mierzy trudności ani frajdy.'
  if output then
    local file = assert(io.open(output .. '/DURABILITY-REVIEW.txt', 'w'))
    file:write(table.concat(lines, '\n'))
    file:close()
  end
  return lines
end
function T.run(G, check, renderer, output)
  if renderer and renderer.frames then
    for kind, frames in pairs(renderer.frames) do
      Geometry.register(kind, frames, renderer.feet[kind])
    end
  end
  local signatures = {}
  local maxNormalHP = 0
  for _, kind in ipairs(kinds) do
    local def = Def[kind]
    check(
      'durability ' .. kind .. ' has finite positive HP and nonnegative armor',
      finite(def.hp) and def.hp > 0 and finite(def.armor) and def.armor >= 0
    )
    signatures[def.hp .. '/' .. def.armor] = true
    if kind ~= 'boss' and kind ~= 'furfur' then
      maxNormalHP = math.max(maxNormalHP, def.hp)
    end
    for slot = 1, 2 do
      local last = math.huge
      local sensible = true
      for _, distance in ipairs(distances) do
        local a = T.analytic(kind, slot, distance)
        sensible = sensible
          and finite(a.torso)
          and finite(a.head)
          and a.head >= a.torso
          and a.torso <= last + 1e-7
        if a.torso > 0 then
          sensible = sensible and a.head > a.torso and a.headClock.shots <= a.bodyClock.shots
        end
        last = a.torso
      end
      check(
        'durability '
          .. kind
          .. ' weapon '
          .. slot
          .. ' rewards precision and never gains power at distance',
        sensible
      )
      local attack = W.attack({}, slot)
      local low, high = copy(attack), copy(attack)
      low.penetration = 0
      high.penetration = 1
      local target = { armorRating = def.armor, resistances = def.resistances }
      local a, blockedA, impulse = D.resolve(low, target, 8, 'torso')
      local b, blockedB = D.resolve(high, target, 8, 'torso')
      local _, _, headImpulse = D.resolve(low, target, 8, 'head')
      check(
        'durability '
          .. kind
          .. ' weapon '
          .. slot
          .. ' penetration changes protection, not momentum',
        b >= a
          and blockedB <= blockedA
          and near(impulse, headImpulse)
          and (def.armor > 0 and b > a or def.armor == 0 and near(a, b))
      )
    end
  end
  local count = 0
  for _ in pairs(signatures) do
    count = count + 1
  end
  check(
    'durability roles retain six distinct HP/armor pairs and substantial boss endurance',
    count == #kinds and Def.boss.hp > maxNormalHP * 3 and Def.furfur.hp > Def.boss.hp
  )
  local R = require('src.combat.reload')
  local A = require('src.audio.audio')
  local muted = A.muted
  A.muted = true
  for slot = 1, 2 do
    local g = {
      weapon = slot,
      reload = 0,
      player = {
        loadout = { 'exorcist', 'judge' },
        arsenal = select(
          2,
          require('tests.support.fixtures').arsenal({
            exorcist = { 0, 72, spent = 2 },
            judge = { 0, 72 },
          })
        ),
      },
      view = { shells = {} },
    }
    check('durability clock starts the real reload for weapon ' .. slot, R.start(g, true))
    local duration = g.reload
    R.update(g, duration)
    local rounds = W.ammo(g)
    check(
      'durability clock agrees with the real refill transaction for weapon ' .. slot,
      g.reload == 0
        and rounds == W.profile(slot).capacity
        and near(duration, slot == 1 and Tune.shotgunCycle or Tune.revolverReload)
    )
  end
  A.muted = muted
  local seven = T.schedule(7, 1, 1, 2)
  check(
    'durability seven-shot revolver includes the seventh round reload explicitly',
    seven.shots == 7
      and seven.reloads == 1
      and near(seven.manual, 5 * Tune.revolverInterval + Tune.revolverReload)
      and near(seven.held, 6 * Tune.revolverInterval + Tune.revolverReload)
  )
  check(
    'durability strzelba cannot invent hits beyond its 24 metre range',
    not T.analytic('imp', 1, 30).bodyClock.reachable
  )
  check(
    'durability ammunition limit is separate from theoretical TTK',
    not T.schedule(31, 1, 1, 2).starting and T.schedule(30, 1, 1, 2).starting
  )
  check(
    'durability alternating salvos are accumulated rather than rounded from mean damage',
    T.schedule(101, 100, 1, 1).shots == 2 and T.schedule(102, 100, 1, 1).shots == 3
  )
  if renderer and renderer.frames then
    local Idle = require('src.enemies.idle')
    for _, kind in ipairs(kinds) do
      local exposed = true
      for _, frame in ipairs({ 1, Idle.entries[kind].first }) do
        for _, distance in ipairs({ 4, 8, 16, 30 }) do
          local sample = T.sample(kind, 2, distance, 'head', frame)
          exposed = exposed and sample.hits == 1 and sample.heads == 1
        end
      end
      check(
        'durability '
          .. kind
          .. ' head advantage is reachable by a real centre ray in front and watchful poses',
        exposed
      )
    end
    local measured = true
    for _, kind in ipairs(kinds) do
      local nearShot = T.sample(kind, 1, 4, 'torso', 1, 1)
      local farShot = T.sample(kind, 1, 16, 'torso', 1, 1)
      measured = measured and nearShot.damage > farShot.damage and nearShot.hits >= farShot.hits
    end
    check(
      'durability real shotgun contacts preserve a meaningful approach-distance advantage',
      measured
    )
  end
  if output then
    T.report(output)
  end
end
return T
