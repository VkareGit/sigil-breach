# Plan v11, etap E0: stan odniesienia 0.33

Raport odbioru E0 planu `PLAN-FUNDAMENT-v11.md`. Kod gry (`src/`) jest
w E0 bez zmian. Doszły tylko narzędzia QA, testy, referencje i zapadki.
Wszystkie referencje powstały ze starego kodu, zanim powstała pierwsza zmiana
E1. Nie wolno ich generować ponownie.

## Stan odniesienia

- Kod: `c9334c1` (0.33) plus plan `178b6f5`. Symulacja, prezentacja i zapisy
  są identyczne z 0.33.
- Złoty wzorzec v2, odtworzony również w trakcie budowania referencji:
  - playtest `07f73bfa/a9192235`;
  - human `fe26df14/563c8d0f`;
  - drill `c13bcaec/f105ca06`;
  - kontakty `aab9a46e/299`, `4be34edb/671`, `663b77fc/178`.
- Bramki:
  - `FORMAT.ps1 -Check` czysty;
  - `TEST.ps1` Architecture: 0 naruszeń;
  - Mechanics: 4131 sprawdzeń, w tym 28 nowych w zestawie `v033-reference`;
  - Input, Render i Tools przechodzą.
- Rendery:
  - baza `work/v11-render-base` ma 606 obrazów pokazu i audytu GUI;
  - względem bazy v10 (`work/v10-v3-render-base`, 596 obrazów) różni się
    tylko pięć ekranów menu z etykietą wersji 0.33, jak przy wydaniu 0.33.

## Referencje (`game/tests/fixtures/v033/`)

Generator: `lovec game --v11-reference` (`qa/v11_reference.lua`). Zapisuje do
`work/qa-v33/v11-reference/`, nigdy do `tests/`.

Determinizm sprawdzono dwoma niezależnymi procesami: wszystkie pliki, także
raport widza, są identyczne bajt w bajt.

Pliki są porównywane dokładnie, więc w `.gitattributes` mają `-text` (bez
konwersji końców linii).

| Plik | Bajty | FNV | Co zawiera |
|---|---:|---|---|
| `projection-playtest.txt` | 345211 | `7a25e372` | rzut stanu złotego playtestu (bot doskonały) |
| `projection-human.txt` | 390165 | `fa67096c` | rzut stanu modelu człowieka |
| `projection-drill.txt` | 103055 | `3890d8f3` | rzut stanu musztry na poligonie |
| `projection-expedition.txt` | 108857 | `36d064ab` | próba wyprawy z zapisem i wczytaniem |
| `projection-sources.txt` | 5852 | `6f8166d3` | próba przypisania: zabójstwo z każdego źródła |
| `attribution.txt` | 10802 | `44b8a5af` | każde zabójstwo: źródło, równowaga, leczenie, dusze, wynik |
| `pose-table.txt` | 533626 | `77d1b8f0` | tabela pozy klatki, 5200 wierszy |
| `saves/*.save` + `*.txt` | — | — | 5 zapisów SIGIL09 z 0.33 i rzut każdego po wczytaniu |

### Rzut stanu (`qa/state_projection.lua`)

Rzut posługuje się nazwami, a nie ścieżkami pól:
- **aktor:** `actor.<id>.x`, `.hp`, `.weapon`, `.ammo.<broń>.mag`,
  `.reload.stage`, `.sequence`, `.stats.kills` itd.;
- **tryb:** `mode.phase`, `.wave`, `.wallet`, `.glyph`, `.score`, `.seals`,
  `.guardian.*`, `.secret`;
- **świat:** `body.<id>.kind/variant/hp/x/z` w kolejności id, żywe ciała
  i szczątki.

Zapis rzutu:
- liczby mają 17 cyfr znaczących, czyli ten sam double daje ten sam tekst;
- co 30 kroków powstaje próbka okresowa `P <krok>` z polami zmienionymi od
  poprzedniej próbki;
- przy zdarzeniu powstaje rekord `E <krok> <rodzaj>`, tylko w zakresie
  zdarzenia.

Rekordy zdarzeń we wszystkich przebiegach:

| Rodzaj | Liczba | Zakres |
|---|---:|---|
| `shot` | 238 | strzelec: pozycja, kierunek, broń, magazynek, cooldown, licznik sekwencji |
| `volley` | 238 | promienie (ziarno, cel, część, odległość), kontakty (cel, strefa, obrażenia), trafienia (obrażenia, ziarno) |
| `reload` | 260 | etap, mechanizm, przerwanie, magazynek i zapas po przeniesieniu amunicji |
| `reload-stop` | 5 | przeładowanie przerwane przed czasem: pozostały czas, etap, amunicja |
| `death` | 100+14 | ciało, źródło, równowaga, przyczyny, leczenie, nagroda, dusze, liczniki zabójcy |
| `save` / `load` | 2 / 2 | pełny rzut przed zapisem i po wczytaniu |

Pierwszą różnicę `Projection.compare` podaje z rekordem, krokiem i polem.
Testy negatywne zestawu sprawdzają to dla zmienionej wartości i dla brakującego
rekordu.

### Próba wyprawy (`qa/scenarios/expedition_trial.lua`)

Przebieg próby:
1. Rycerz ze skryptu czyści falę 1, dochodzi do kapliczki i kupuje grawer
   `pierce`.
2. Punkt kontrolny jest zapisywany i wczytywany do nowej sesji, jak CONTINUE
   w menu.
3. Po 12 s fali 2 rycerz pada; zapis porażki zostawia echo.
4. Zapis porażki jest wczytywany, potem następuje ponowna próba i 5 s walki.

Fixture zapisów:

| Zapis | Faza | Fala | Sakiewka | Grawer | Echo | Zabójstwa |
|---|---|---:|---:|---|---|---:|
| `start` | preparing | 1 | 100 | brak | brak | 0 |
| `preparing` | preparing | 2 | 92 | pierce | brak | 7 |
| `defeated` | defeated | 2 | 0 | pierce | 100 @ fala 2 | 14 |
| `end-playtest` | complete | 5 | 321 | pierce | brak | 39 |
| `end-human` | complete | 5 | 392 | pierce | brak | 39 |

Każdy fixture spełnia trzy warunki:
- wczytuje się do rzutu z 0.33;
- zapisany ponownie wczytuje się do tego samego rzutu;
- uszkodzony jest odrzucony.

### Przypisanie leczenia i nagród

| Przebieg | Źródło | Wytrącony | Zabójstwa | Wyleczono | Dusze |
|---|---|---|---:|---:|---:|
| playtest | weapon | tak / nie | 15 / 24 | 15,55 / 0 | 76 / 298 |
| human | weapon | tak / nie | 6 / 33 | 7,50 / 0 | 44 / 330 |
| drill | weapon | tak / nie | 4 / 2 | 0 / 0 | 0 / 0 |
| expedition | weapon | tak / nie | 10 / 6 | 19,44 / 0 | 40 / 36 |
| sources | każde źródło | tak / nie | 7 / 7 | 9 każde / 0 | 11–24 |

Przebiegi złote zabijają tylko bronią. Dlatego próba
`qa/scenarios/attribution_trial.lua` zabija przez wspólne wejście obrażeń
po jednym demonie z każdego źródła: `weapon`, `charge`, `ability`,
`effect:burning`, `slam`, `collision` i `creature`. Każde źródło ma wariant
z ciałem stabilnym i wytrąconym z równowagi.

Dzisiejsza reguła 0.33: każde zabójstwo wytrąconego demona leczy sterowanego
rycerza (9 HP przy 40/100), bez względu na źródło, także `creature`. To wzorzec
dla reguły łańcucha z E3d.

### Tabela pozy klatki (`qa/pose_table.lua`)

Tabela obejmuje 6 stworzeń 0.33. Dla każdego zawiera klatkę i ułożenie
(bounce, lean, sx, sy). Ciała martwe mają dodatkowo `settled` i `shields`
oraz moment uderzenia o podłogę.

Siatka obejmuje granice obu układów (6×4 i 4×4) dla każdego stworzenia.
Każda granica ma punkty b−1e-9, b i b+1e-9 w jednostce granicy.

| Grupa | Wiersze |
|---|---:|
| windup | 102 |
| strike | 208 |
| recover | 42 |
| hurt | 336 |
| knockdown | 234 |
| falter | 6 |
| walk | 2478 |
| watch (przód/tył) | 120 |
| quiet | 90 |
| flight | 504 |
| dead | 1032 |
| landing | 6 |
| modifier | 42 |

Zegar `action` ma akcję długości 50 s, więc granice 0,22, 0,42 i 0,6 leżą
dokładnie na całych sekundach.

## Wpływ widza na symulację (C4)

Raport tworzy `qa/viewer_influence.lua` przez instrumentację w QA, w złotych
scenariuszach bez renderera. Każde zapytanie o pozę jest tam zapytaniem
symulacji.

| Scenariusz | Zapytania obrócone do widza | Klatka zależna od widza | Pytający |
|---|---:|---:|---|
| playtest | 610 | 8 | strzał `ballistics` 435 (8 tyłem), kotwica `ballistics` 77, kontakt pazura `contact_anchor` 98 |
| human | 371 | 0 | `ballistics` 225 + 30, `contact_anchor` 116 |
| drill | 129 | 5 | `ballistics` 65 (5 tyłem), `contact_anchor` 64 |

Wnioski:
- każde zapytanie obraca billboard do `Roles.viewer`;
- 13 strzałów spotkało klatkę tyłem, wybraną względem widza;
- wzrok demona nie pyta o kotwicę na mapie płaskiej (`R.sees` bez wysokości),
  więc w tych scenariuszach 0.

## Inwentarz `g.view` (`session/fields.lua`, 19 grup deklaracji)

Plan mówił o 18 grupach; deklaracji jest 19, bo `world_feedback.lua`
deklaruje dwie grupy.

**Punkty resetu w 0.33:**
- **sesja:** nowa sesja to nowy `g.view` (wszystko);
- **F.init** (`player/feel.lua`): konstrukcja sesji oraz wczytanie, ponowna
  próba i odtworzenie wyprawy. Zeruje kamerę, zegary strzału, ślady, plamy,
  zwłoki, łuski, efekty i ruch broni;
- **clearMotion:** zmiana ustawień. Zeruje kamerę i ruch, zachowuje chód;
- **śmierć:** nic nie zeruje (`Presentation.capture`);
- **zmiana sterowanego:** w 0.33 nie istnieje w grze (`Roles.control` tylko
  przy odtwarzaniu zapisu sesji), więc nic nie zeruje.

| Grupa (właściciel deklaracji) | Pola | Właściciel docelowy | Zasięg | Reset dziś |
|---|---|---|---|---|
| `run/modes.lua` | fieldReturnLabel | widz (interfejs nawigacji) | sesja | sesja |
| `session/game.lua` | message, messageTimer | aktor (komunikat dla gracza) | osobisty | sesja |
| `feedback/damage_numbers.lua` | damageNumbers, numberSerial | świat | wszyscy widzowie | sesja |
| `app/commands.lua` | motion, fov, confirmReturn, presentationPrevious | widz (ustawienia, dialog, poprzednia próbka) | widz | sesja; presentationPrevious: clearMotion, descent |
| `app/input.lua` | swayX, swayY | aktor (ręce od urządzenia wejścia) | osobisty | F.init (kamera) |
| `feedback/listeners.lua` | feedback, feedbackTimer, hurt, surge, hitmarker, shake, muzzle, damageDir, killPunch, breakKill, perfectDodge, lastDamage, lastKill, precisionHit | aktor | osobisty | F.init częściowo (shake, lastDamage, lastKill, precisionHit), descent (muzzle, hurt, surge, hitmarker) |
| `feedback/shot_feedback.lua` | armorHit, flashColor, hitWeight, shotPower, shotReport | aktor | osobisty | F.init |
| `feedback/world_feedback.lua` (1) | staggerFlash | aktor (błysk zachwiania rycerza) | osobisty | wygasa |
| `feedback/weight.lua` | breakConfirm … aimKickRate (17 pól) | aktor (kamera i ręce) | osobisty | F.init, clearMotion |
| `feedback/effects.lua` | effects, effectPool, decals, decalPool | świat | wszyscy | F.init |
| `feedback/surface_marks.lua` | surfaceMarks, surfaceMarkPool | świat | wszyscy | F.init |
| `feedback/shot_trails.lua` | traces, tracePool | świat | wszyscy | F.init |
| `feedback/death_response.lua` | particles, corpses, shells | świat | wszyscy | F.init (corpses, shells) |
| `feedback/movement_marks.lua` | markClocks | aktor (zegary śladów kroków) | osobisty | sesja |
| `feedback/world_feedback.lua` (2) | interruptedClose | aktor (zamykanie broni) | osobisty | F.init, transients |
| `feedback/movement_impact.lua` | lastLandingImpact, lastMovementImpact, lastWallImpact, movementContact, movementImpactSerial | aktor | osobisty | F.init (Motion.init) |
| `player/feel.lua (camera)` | bank, bobWeight, fovKick, land, landV, moving, recoil, recoilV, stepSound, shotAge, swapAge | aktor (kamera ciała; widz dziedziczy przez kontekst E5) | osobisty | F.init, clearMotion |
| `player/movement_gait.lua` | gaitPhase, gaitSteps | aktor | osobisty | F.init (zachowany w clearMotion) |
| `feedback/weapon_motion.lua` | weaponAimVX … weaponStride (29 pól) | aktor | osobisty | F.init, clearMotion |

## Zapadki pomocnicze (`tools/check/`, mogą tylko maleć)

| Zapadka | Plik | Wartość | Pliki |
|---|---|---:|---|
| FRAME NUMBERS OUTSIDE SHEETS | `frame-numbers.txt` | 25 | enemies/animation 16, corpse 8, body 1 |
| MODE STATE ON THE SESSION | `mode-state.txt` | 53 | 12 plików: interactions 14, descent 12, test_field 6, … |
| ACTOR STATE ON THE SESSION | `actor-state.txt` | 172 | 22 pliki: reload 39, descent 19, test_field 13, listeners 13, combat 12, intent 12, … |
| VIEWER IN SIMULATION | `viewer-in-simulation.txt` | 3 | enemies/animation, geometry, pose |
| PRESENTATION ASSUMES ONE PLAYER | `one-player-presentation.txt` | 73 | 26 plików: world_feedback 11, effects 6, world_art 6, … |

Uwagi do liczenia:
- ACTOR STATE liczy szerzej niż szacunek planu (135): obejmuje wszystkie pola
  `reload*`, a także dostęp przez `self` i `game`;
- PRESENTATION liczy `g.player` i `Roles.controlled` w warstwach app, audio,
  feedback, render i ui.

Jak w planie, te liczby są wskaźnikiem, a nie dowodem. Etap zamyka próba
i warunek mierzalny.

## Pomiar bazowy (protokół z Zasad)

Narzędzie: `MEASURE.ps1` (`-Before <drzewo> [-After <drzewo>] -Pairs 5`).
- Każdy pomiar to osobny proces z rozgrzewką 300 kroków lub klatek
  (`SIGIL_CORE_WARMUP`, `SIGIL_BENCH_WARMUP`).
- Mapa `qa_crowd`, 20/96/256 ciał; dla `--benchmark` dochodzą sceny
  `complete_*`.
- Pary zmieniają kolejność.
- Wynik: mediana i IQR osobno dla każdego wariantu oraz werdykt według
  protokołu.

Dla porównań w E1–E6 wariantem „przed” jest drzewo z commitu E0 (worktree),
a „po” bieżące `game`.

Pierwsza próba (240 kroków i 240 klatek na próbkę) dała zbyt duży rozrzut
kroku symulacji, przy którym każde porównanie byłoby nierozstrzygnięte:

| Metryka | Mediana | IQR |
|---|---:|---:|
| krok, 20 ciał | 0,1065 ms | 33,5 % |
| krok, 96 ciał | 0,4073 ms | 12,6 % |
| krok, 256 ciał | 1,1428 ms | 6,5 % |
| klatka, populacja 20 | 6,34 ms | 4,4 % |
| klatka, populacja 96 | 11,73 ms | 5,5 % |
| klatka, populacja 256 | 20,50 ms | 3,6 % |
| klatka, scena normal | 4,04 ms | 4,9 % |
| klatka, scena heavy | 5,44 ms | 4,4 % |

Protokół próbkuje więc teraz 2400 kroków (`SIGIL_CORE_STEPS`) i 720 klatek
(`SIGIL_BENCH_FRAMES`) na pomiar.

Pomiar bazowy z drzewa commitu E0 (worktree, wariant „przed” dla E1–E6):
`work/v11-measure/e0-base/summary.txt`. Wyniki zapisuje sekcja
„Pomiar bazowy — wynik” poniżej.

### Pomiar bazowy — wynik

Drzewo `work/v11-base` (commit E0 `710d1ac`, kod gry identyczny z 0.33).
Każda liczba pochodzi z 5 osobnych procesów:

| Metryka | Mediana | IQR | Wartości |
|---|---:|---:|---|
| krok, 20 ciał | 0,1138 ms | 9,8 % | 0,1027–0,1259 |
| krok, 96 ciał | 0,5574 ms | 3,5 % | 0,5282–0,5789 |
| krok, 256 ciał | 2,3779 ms | 6,8 % | 1,9792–2,6683 |
| klatka, scena normal | 4,2908 ms | 0,5 % | 4,1540–4,3460 |
| klatka, scena heavy | 5,6409 ms | 2,6 % | 5,4570–5,9037 |
| klatka, populacja 20 | 6,5938 ms | 9,5 % | 6,0226–6,8746 |
| klatka, populacja 96 | 12,2956 ms | 12,6 % | 10,4470–13,1648 |
| klatka, populacja 256 | 21,5423 ms | 7,0 % | 19,7683–23,1549 |

Mimo dłuższego próbkowania część metryk przekracza 5% IQR. Rozrzut między
procesami wynika z maszyny (taktowanie, procesy tła), a nie z obciążenia gry,
które jest deterministyczne.

Według protokołu porównanie takich metryk wychodzi nierozstrzygnięte.
Wymaga wtedy kolejnych 5 par, a jeśli dalej jest nierozstrzygnięte, liczy się
jak regresja i wymaga decyzji użytkownika.
