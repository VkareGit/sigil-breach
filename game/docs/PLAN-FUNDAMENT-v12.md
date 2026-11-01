# SIGIL: BREACH — fundament v12: baza pod rozwój bez przepisywania

Status: WYKONANY 1 listopada 2026 w wersji 0.36, raporty `PLAN-v12-R*-RAPORT.md`.
Stan odniesienia: `3109330`, wersja 0.35 (plan spisany na `1c297f5`, 0.34).
Podstawa: przegląd skalowalności z 31 października (kod i próby na żywej
sesji). Kontrakty v7, v10 i v11 nadal obowiązują.

## Cel

Po v12 dodanie broni, zdolności, postaci, demona, mapy, efektu albo nowego
rodzaju bytu ma wymagać nowych plików, a nie zmian w rdzeniu.

Reguła mierzalna:

> Nowa rzecz znanego rodzaju to definicja i art. Nowy rodzaj rzeczy to
> definicja, art i najwyżej jeden moduł wykonawczy. W obu przypadkach liczba
> zmienionych istniejących plików rdzenia wynosi zero.

Regułę dowodzi etap R9: kompletny pakiet treści leży poza `game/src` i działa
bez zmiany źródeł. Sam odczyt ze zwykłego kodu albo zapadka w `tools/check`
niczego nie zamyka.

Plan nie obiecuje braku kodu: zupełnie nowe zachowanie zawsze potrzebuje
wykonawcy. Nie obiecuje też braku pracy nad grafiką: nowa postać wymaga rąk
i portretu, a nowy demon atlasu i masek.

Produkcja się nie zmienia: jeden poligon, dwie bronie, obecny rycerz, obecny
HUD. Rycerz nadal jest człowiekiem bez magii. Zaklęcie, mana czy druga postać
istnieją tylko jako dowód w testach, dopóki nie zdecydujesz o treści.

## Luki potwierdzone w kodzie 0.34

| Luka | Dowód | Skutek | Etap |
|---|---|---|---|
| L1 Postać | `Rules.playerBody()`: 21 wywołań w 11 plikach, bez aktora. Odczyty `Archetypes.player`: 14 plików. Ruch z globalnego `Tuning`: 20 odczytów w 5 plikach, głównie `player/feel.lua`. Domyślne `hp 100`, `armor 40`, `dash 2` w `session/components.lua:251-273`. Rycerz nie ma `maxHp` (próba: `nil`) | Druga postać o innych statystykach wymaga przeróbki walki, ruchu, HUD-u i trybów | R1 |
| L2 Rozliczenie | Trafienia stworzeń idą równolegle przez `Volley:apply`, `strikeDemon` (`combat/projectiles.lua:121`), `X.explode` (`combat/explosives.lua:64`), `creatureBlow` (`session/damage_outcomes.lua:80`) i tyk efektu. `Combat` udostępnia tylko `counters, projectile, react, shoot, trace` (próba). `combat/combat.lua:460` pyta `kind == 'hitscan'` | Reguła trafienia wymaga zmian w kilku miejscach; nowy sposób trafiania powiela rozliczenie | R2 |
| L3 Statystyki | `Damage.core` to zamknięty wzór. Stan ma tylko `speed` i `recovery` (`content/defs/condition.lua`). `exposed` na sztywno w `combat/damage.lua:107`, `staggered` w `combat/combat.lua:54`, pancerz tylko dla `physical` w `combat/damage.lua:151`. `damageType='fyre'` przechodzi przez definicję, start sesji i trafienie (próba) | Buff, debuff i nowy typ obrażeń wymagają zmian w rdzeniu; literówka jest niewidoczna | R2 |
| L4 Reakcje | `attack.effects` działają tylko po obrażeniach przy kontakcie. Brak zaczepów: zabicie, strzał, pudło, powierzchnia, przeładowanie. `EnemyKilled` nie niesie broni | Efekty specjalne broni kończą się na trafieniu | R2 |
| L5 Broń | `capacity=0` odrzucone, `mechanism` wymagany, `reloadTime` i `fire.mode` to nieznane pola (próby). Rewolwer oddaje 6 strzałów z jednego przytrzymania (próba). `breech` i `cylinder` to bliźniacze bloki (`combat/reload.lua:41,120`). `W.newState` i `W.inventory` znają tylko pola magazynka (`content/weapons.lua:179,329`). `side='knight'` na sztywno w `combat/weapon_delivery.lua:37` | Broń biała, energetyczna, półautomat, alt-fire i własny czas przeładowania wymagają zmian w rdzeniu | R3 |
| L6 Zdolności | `Abilities.give` ma 2 argumenty, `Weapons.give` 3 (próba). `give/rest/inventory/restore/fill` działają na sterowanym. Zasoby to `uses` i `readyAt`. `bolt` ma dwa wykonawcy (`combat/abilities.lua:36` i `enemies/ranged_kinds.lua`). `combat/explosives.lua:18` ma domyślne `'powder'`. `Action.build` ma łańcuch `if` po rodzajach | Mana, czas rzucania, kanałowanie i zdolności dla aktora wymagają przeróbki | R4 |
| L7 Stworzenia | Ręczna lista w `content/enemies.lua:27-33`, identyfikatory dzielą przestrzeń z API. Zagrożenia: `values={'pool','lightning'}` w `content/defs/action.lua:188`, `pendingHazard` w `enemies/actions.lua:78`, wyjątek `leap` w `enemies/actions.lua:93`. Rotacja nazw w `content/waves.lua:4` | Nowy rodzaj zagrożenia dotyka symulacji, renderu i schematu | R5 |
| L8 Świat | Wartości pól 0/1/2 w 13 plikach (44 dopasowania). Mapa musi mieć `spawn`, `portal`, `ember`, `zones` (próba). `run/spawner.lua:25` i `session/sanctuary.lua:10` czytają `Maps.default` przy ładowaniu modułu. Przebudowa komórki działa, ale nie ma API zmiany geometrii w grze | Nowy typ pola dotyka 6 lub więcej plików; drzwi nie mają kontraktu | R6 |
| L9 Bieg | Trzy tryby na `Maps.default` (`run/modes.lua:110,219,273`). `totalWaves` globalne (`content/expedition.lua:10`, użycia w `ui/descent.lua`, `run/mode_views.lua`, `storage/run_save.lua:29`). Glif: `values={'none','choke','pierce'}` w `storage/run_save.lua:147`, jeden na bieg | Dziewięć kręgów nie ma modelu; nowy glif wymaga zmiany zapisu | R7 |
| L10 Byty | Pule to zamknięta lista (`session/world.lua:23-34`, `session/components.lua:337-359`). Kolejność systemów to stała lista (`systems/index.lua`). `WorldObjects` tylko rysuje. `Pools.of(g,'enemies')`: 51 użyć w 33 plikach, pociski i wybuchy trafiają wyłącznie w tę pulę. Rodzaje zapasów na sztywno w `render/world_art.lua:98` | Wieżyczka, beczka, NPC i drzwi wymagają zmian w około 5 miejscach | R8 |

## Zasady wykonania (każdy etap)

Obowiązują zasady v11 (sekcja „Zasady wykonania”), z dwiema zmianami.

**Referencja etapu zamiast jednej globalnej.** Codex pracuje równolegle,
a gameplay kaplicy się zmienia. Każdy etap zapisuje własną referencję na
swoim commicie startowym: skróty `qa/golden.lua`, rzut stanu, rendery showcase
i audytu GUI, pliki zapisu. Tej referencji nie wolno potem generować ponownie.
Nowy skrót nie jest dowodem równoważności.

**Równoważność oznacza to samo co w v11.** Etap migrujący produkcję daje:

- identyczne skróty złotego wzorca,
- identyczny rzut stanu w próbkach okresowych i przy zdarzeniach,
- rendery identyczne piksel w piksel,
- wczytanie zapisów SIGIL06–09 z tym samym rzutem stanu.

Ponadto:

- `FORMAT.ps1 -Check`, `TEST.ps1 -Suite All`, 0 naruszeń architektury.
- Zapadki nie rosną, a zapadki danego etapu kończą go na zerze.
- Każdy etap ma test pozytywny, test negatywny i próbę rozszerzenia.
- Próba rozszerzenia leży w testach i używa tylko publicznego API. Jeśli
  potrzebuje `require` wnętrza modułu, kontrakt jest niegotowy.
- Protokół pomiaru jak w v11 (`MEASURE.ps1`, 5 par, mediana i IQR). Podstawą
  jest commit startowy etapu.
- Gorące ścieżki: bez nowych tabel na śrut lub krok w przypadku produkcyjnym.
  Brak stanów na ciele oznacza szybką ścieżkę bez iteracji.
- Bez obejść: żadnego udawania wielu aktorów przez podmianę `g.player`.
- Jeden pisarz na grupę plików. Przed etapem sprawdzić `git log`, `git status`
  i `core/build.lua`.
- B2 zostaje oceną człowieka w normalnej grze.

## Zgodność zapisów i dzienników

Zapisy gracza: SIGIL06–09 mają się wczytywać. Plik zostaje SIGIL09; sekcja
zmieniająca strukturę podnosi `version` i dodaje migrację
(`Save.declare.migrations`). R0 utrwala fixture z 0.34.

Zmiany przewidziane:

| Sekcja | Etap | Zmiana | Domyślna wartość migracji |
|---|---|---|---|
| członek puli `knights` | R1 | `character` | `'knight'` |
| członek puli `knights` | R4 | `resources` | brak |
| `run` | R3 | stan broni przez model amunicji | magazynek ma ten sam kształt |
| `run` | R7 | `stage`, lista glifów, id biegu | etap 1, jeden glif, bieg domyślny |

Dzienniki: jak w v11, odtwarzanie tylko w obrębie wydania. Nowe pola wejścia
(alt-fire, zmiana komórki, przejście etapu) tworzą format v6. `actorJoin` niesie
id postaci.

## Etapy

### R0 — referencje, zapadki, szkielet dowodów

Rozmiar: S. Bez zmian zachowania.

- Zapisać referencję 0.34: skróty, rzut stanu, rendery, fixture zapisu.
- Pomiar bazowy `MEASURE.ps1` na `1c297f5`.
- Dodać `tests/support/extension/` i pusty pakiet rozszerzeń używany przez
  kolejne etapy.
- Dodać zapadki w `tools/check`, liczone od dzisiejszych wartości:
  `player-body` (L1), `damage-entry` (L2), `damage-type-literals` (L3),
  `ammo-fields` (L5), `controlled-abilities` (L6), `creature-names` (L7),
  `tile-literals` (L8), `default-map` (L9), `enemy-pool-reads` (L10),
  `step-rate`.

Koniec: zapadki działają, All przechodzi, referencje nie wymagają ponownego
wygenerowania.

### R1 — definicja i rejestr postaci

Rozmiar: L. Zależy od R0.

**Kontrakt.** `content/defs/character.lua` i rejestr `content/characters.lua`:

- `id`, `name`, `faction`,
- `body`: dzisiejszy `Knight.schema` plus `armor` i `dashCharges`,
- `movement`: wszystkie wartości ruchu dziś czytane z `Tuning`,
- `kit`: bronie i zdolności startowe,
- `presentation`: portret, profil HUD i głos jako klucze.

Obecne wartości przechodzą do definicji `knight` bez zmiany liczb.

**Właściciel stanu.** Aktor ma `character` (id), `maxHp`, `maxArmor`.
`hp 100`, `armor 40`, `dash 2` znikają z `session/components.lua`, a
`State.new` tworzy aktora przez `Characters.spawn`.

**Migracja.**

- `Rules.playerBody(actor)` z wymaganym aktorem. Forma bez argumentu znika.
- `Archetypes.player` znika. Wszystkie odczyty idą przez postać aktora.
- `player/feel.lua`, `feedback/weapon_motion.lua`, `combat/dodge.lua`,
  `systems/knight.lua`, `run/descent.lua` czytają `movement` aktora.
- `R.hitPlayer` i `R.slamPlayer` biorą ciało z postaci aktora.
- HUD liczy udział `hp / maxHp`. Próg niskiego zdrowia staje się jedną nazwaną
  wartością 0,30 udziału. Dziś powtarza się w `ui/hud.lua`, `ui/portrait.lua`,
  `ui/screens/hud.lua`, `feedback/weight.lua`, a `render/renderer.lua:550`
  ma osobne 40.

**Nie zmieniać.** Pula zostaje `knights`, prefab `knight`. Zmiana nazwy
kosztuje migrację i nic nie daje; dokumenty opisują ją jako pulę aktorów.

**Testy.** Negatywne: nieznana postać, brak pola, próba użycia `playerBody()`
bez aktora. Rycerz bez `character` w zapisie 0.34 wczytuje się jako `knight`.

**Próba.** `trial_warden`: 60 HP, inny `shieldShare`, ruch ×1,4, inne bronie.
Wchodzi przez `actorJoin`, biega, obrywa, ginie, działa zapis i odtworzenie.
Render HUD pokazuje jego udział zdrowia.

**Koniec.** Zapadka `player-body` na zerze i próba bez zmian w `game/src`.

### R2 — jedno rozliczenie, statystyki, typy obrażeń, reakcje

Rozmiar: XL. Zależy od R1. Największe ryzyko złotego wzorca.

**Kontrakt rozliczenia.** Nowy `combat/hit.lua`, dwa kroki:

- `Hit.measure(attack, target, contact, attacker)`: czysta matematyka, bez
  mutacji; zachowuje zasadę sumowania śrutu przed zastosowaniem.
- `Hit.land(g, target, tally, context)`: jedyne wejście w `damageEnemy`
  i `react` dla ciosu z kontaktem.

Przechodzą na nie: `Volley:apply`, `strikeDemon`, `X.explode`, `creatureBlow`,
tyk efektu, `combat/rules/contact.lua`. Kolejność zdarzeń `BodyHit`,
`EnemyKilled`, `BlowResolved` zostaje identyczna.

**Publiczna salwa.** `Volley` przechodzi do `combat/volley.lua` jako publiczne
API dla wykonawców dostarczania. Pytanie `kind == 'hitscan'` zastępuje
pole dostarczania `observes = true`. `side='knight'` zastępuje
`Bodies.side(g, shooter)`.

**Prawo ciała.** `Bodies.law(g, target)` wybiera `creature` albo `knight`.
`Outcomes.body` zostaje jedynym wejściem dla ciosu z dowolnej strony.

**Statystyki.** `content/attributes.lua` to rejestr nazwanych statystyk.
`combat/attributes.lua` liczy wartość z bazy i modyfikatorów. Nazwa odróżnia je
od istniejących liczników `session/stats.lua`. Schemat stanu dostaje
`modifiers = { armor = { mul = 0.5 } }` i `forbids = { 'fire' }`.
`speed` i `recovery` stają się modyfikatorami. `exposed` i `staggered` tracą
wyjątki w kodzie. Ciało bez stanów korzysta z szybkiej ścieżki.

**Typy obrażeń.** `content/damage_types.lua`: `id`, `armored`, kolor i wskazówka
dźwiękowa. Walidacja przy definicji broni, ataku, wybuchu i odporności. Znikają
`== 'fire'` w `feedback/world_feedback.lua:156`, `audio/world_cues.lua:67` oraz
`== 'physical'` w `combat/damage.lua`.

**Reakcje.** `content/defs/reaction.lua` i `combat/reactions.lua`:
`reactions = { { on = 'kill', effect = {...}, target = 'self' } }`.

- Zdarzenia: `hit`, `kill`, `shot`, `miss`, `surface`, `reload`.
- Źródła w ustalonej kolejności: broń, modyfikator biegu, postać, stany.
- Reakcja nie wywołuje kolejnej reakcji, tak jak dziś puls nie dodaje efektów.
- `EnemyKilled` niesie id broni.
- Brak reakcji oznacza brak dodatkowego kodu na ścieżce strzału.

**Testy.** Negatywne: literówka w typie obrażeń, nieznana statystyka,
nieznane zdarzenie, reakcja w reakcji. Regresja: każda ścieżka trafienia daje
dziś i po migracji ten sam paragon.

**Próby.** Wiązka i rykoszet tylko przez publiczną salwę. Pocisk przebijający
ciała. Stan zmniejszający pancerz. Broń wybuchająca przy zabiciu, broń lecząca
przy strzale, nowy typ `frost` bez zmian w `game/src`.

**Koniec.** Zapadki `damage-entry` i `damage-type-literals` na zerze.
Znika zakaz przebijania z `content/defs/weapon.lua:183` dla pocisków.

### R3 — model broni

Rozmiar: L. Zależy od R2.

**Amunicja.** Definicja `ammo = { kind = 'magazine', capacity, ... }`.
Rejestr modeli z jednym interfejsem:

| Metoda | Znaczenie |
|---|---|
| `newState(def)` | stan początkowy |
| `canFire(def, state)` | czy spust może zadziałać |
| `spend(def, state, count)` | wydatek strzału |
| `refill(def, state, amount)` | uzupełnienie |
| `meter(def, state)` | wartości dla HUD-u |
| `pack(state)`, `unpack(data)` | zapis |

Modele produkcyjne: `magazine`. Modele w próbach: `none`, `heat`, `charge`.
Osiem wywołań `Weapons.ammo` w UI przechodzi na `meter`. Sklep w
`run/economy.lua` pyta model, czy broń ma co kupić.

**Spust.** `trigger = { mode = 'auto' }`, rejestr trybów. `player/intent.lua`
przekazuje zdarzenie trybowi. Obie bronie produkcyjne zostają `auto`, więc
zachowanie się nie zmienia.

**Przeładowanie.** Mechanizm staje się danymi: `stages`, `duration`, `resume`,
`interruptBefore`, `labels`. Jeden interpreter zastępuje `breech` i `cylinder`.
Broń dostaje `reload = { mechanism = 'breech', speed = 1 }`. Nieznany mechanizm
odpada już przy `Weapon.define`, nie przy starcie sesji. `reload` jest
opcjonalny dla modeli bez magazynka.

**Tryb drugi.** Pole `secondary` dziedziczy po głównym i może podmienić
`fire`, `attack`, `delivery`. Komenda `altFire` w wejściu i dzienniku.
Produkcja nie ma przypisanego klawisza ani elementu HUD.

**Testy.** Negatywne: pole spoza modelu, broń bez `reload` na magazynku, zły
tryb. Zapis magazynka ma ten sam kształt co 0.34.

**Próby.** Ostrze bez amunicji i z dostarczaniem `melee`, karabin energetyczny
z ciepłem, półautomat, seria 3, ładowany strzał, własny czas przeładowania,
alt-fire. Wszystko przez zapis, dziennik i render HUD.

**Koniec.** Zapadka `ammo-fields` na zerze poza modelem `magazine`.

### R4 — zdolności, zasoby, jedno wykonanie akcji

Rozmiar: L. Zależy od R1, R2. Równolegle do R3 tylko bez wspólnych plików.

**Aktor.** `give`, `rest`, `inventory`, `restore`, `fill` przyjmują aktora.
Zapadka `controlled-abilities` schodzi do zera.

**Zasoby.** `character.resources = { mana = { max, start, regen } }`, moduł
`combat/resources.lua`, stan `actor.resources`. Definicja zdolności ma
`cost`; dzisiejsze `uses` to koszt domyślny.

**Rzucanie.** `windup`, `channel`, `toggle` jako maszyna stanów
`actor.casting` w systemie po `Knight.trigger`. `windup = 0` wykonuje się w tym
samym kroku co dziś, co chroni złoty wzorzec. Przerwanie wynika z `forbids`
stanu (R2).

**Akcje.** Rodzaj akcji ma jedną definicję (`Action.defineKind` z hakami
`build` i `validate`) i jednego wykonawcę z kontekstem `Caster` (początek, cel,
strona, właściciel). `Attacks.kinds` i `Cast.kinds` przechodzą na jeden rejestr
sprawdzany przy kompozycji sesji, a cykl życia demona zostaje w
`enemies/actions.lua`. Reakcja może wykonać akcję w punkcie. Znika
`defaultAction`.

**Testy.** Negatywne: brak zasobu, przerwany rzut bez kosztu, nieznany koszt,
rodzaj akcji bez wykonawcy.

**Próby.** Zaklęcie dwusekundowe z maną, kanałowany promień, przełączana aura,
ta sama akcja `bolt` u demona i aktora. Dwaj aktorzy mają oddzielne zasoby.

**Koniec.** Jedna implementacja każdego rodzaju, zapadka na zerze.

### R5 — stworzenia i zagrożenia

Rozmiar: M. Zależy od R4.

- `content/enemies.lua` staje się rejestrem. Dodanie demona to plik i
  rejestracja. Testy przestają wstrzykiwać `A.trial_plated`.
- Zagrożenia: definicja, wykonawca symulacji i rysunek w trzech rejestrach ze
  sprawdzaną kompletnością. `pendingHazard` zastępuje hak `kind.commit`.
- `leap` traci wyjątki w `enemies/actions.lua:93`, `enemies/animation.lua:144`,
  `render/passes/enemy_marks.lua:53` na rzecz właściwości rodzaju.
- `look.motion` to rejestr.
- Znikają nazwy w `run/field/trials.lua`, `run/field/station_layout.lua`,
  `run/test_field.lua`, `render/ritual_art.lua`, `ui/goetic_sigils.lua`,
  `ui/screens/help.lua`, `render/gallery.lua`, `run/field/catalog.lua`.
- `rotation` z `content/waves.lua` przechodzi do danych starcia.

**Próba.** Demon z pola gazowego, nowym rodzajem ruchu i zagrożeniem liniowym.
Pojawia się w katalogu poligonu bez zmian w `game/src`.

**Koniec.** Zapadka `creature-names` na zerze.

### R6 — pola, geometria, opcjonalne elementy mapy

Rozmiar: M. Zależy od R0. Może iść równolegle do R3 i R4 w osobnej sesji.

- `content/tiles.lua`: rejestr z właściwościami `solid`, `blocksShots`,
  `blocksSight`, `walkable` i sposobem budowy siatki. Tablice właściwości są
  wyliczane przy budowie świata, więc koszt odczytu zostaje stały.
- Migracja 13 plików z dosłownych 0/1/2.
- `W.setCell(g, x, z, tile)` zmienia geometrię, podnosi rewizję i trafia do
  dziennika jako delta. Dziś rewizję śledzą nawigacja, światła i siatka.
- `spawn` zostaje wymagany. `portal`, `ember`, `zones` są opcjonalne, a tryb
  deklaruje `requires`. Niespełnienie blokuje kompozycję sesji.
- `Spawner` i `Sanctuary` czytają świat sesji zamiast `Maps.default` przy
  ładowaniu modułu.
- Znikają dane mapy w kodzie: `feedback/surface_marks.lua:52-63`,
  `ui/screens/map.lua:71-72`, `content/text.lua:383`.
- Krok 120 Hz: jedna stała w `core`, zamiast powtórzeń w 5 plikach.

**Próba.** Pole płytkiej wody, które nie blokuje ruchu i spowalnia. Drzwi
przez `W.setCell`, działające z nawigacją, zapisem i odtworzeniem. Mapa bez
ołtarza dla trybu, który go nie żąda.

**Koniec.** Zapadki `tile-literals`, `step-rate` na zerze.

### R7 — bieg, etapy, glify, oferty

Rozmiar: L. Zależy od R3, R5, R6.

- `content/runs.lua`: definicja biegu jako lista etapów, każdy z mapą,
  starciem, opiekunem i sanktuarium. Dzisiejsza wyprawa to bieg jednoetapowy.
- `totalWaves` staje się danymi etapu. Interfejs czyta widok biegu.
- Przejście etapu: budowa nowego świata, aktorzy zostają, pule przejściowe
  czyszczone. Polecenie zapisane w dzienniku.
- Glify: `content/glyphs.lua`, lista w biegu, produkcja ma limit 1.
  Modyfikator może dać `set`, `scale`, `spread`, modyfikatory statystyk i
  reakcje. Schemat zapisu czyta rejestr. Ikony z `ui/skin.lua:21-22` idą za
  definicją.
- Oferty sanktuarium i zapasy jako rejestry. `render/world_art.lua:98` czyta
  art z definicji zapasu.

**Testy.** Negatywne: etap z nieistniejącą mapą, zapis z nieznanym glifem,
przejście poza listę. Zapis SIGIL09 z 0.34 wchodzi jako etap 1.

**Próba.** Trzy etapy na dwóch mapach, zapis między nimi, porażka i powrót,
dwa glify naraz, nowy zapas. Dziewięć kręgów staje się kwestią danych.

**Koniec.** Zapadka `default-map` na zerze.

### R8 — ogólny byt świata

Rozmiar: L. Zależy od R2, R6.

Jedna deklaracja `Entities.define`:

| Pole | Znaczenie |
|---|---|
| `pool`, `components`, `prefab` | stan i rejestracja w ECS |
| `system = { after = '...', step = fn }` | miejsce w kroku |
| `hittable`, `health` | czy pocisk i wybuch może trafić |
| `collides` | blokowanie ruchu |
| `interact` | akcja `E` i podpowiedź |
| `draw` | wpis `WorldObjects` |
| `save` | sekcja zapisu |

- Kolejność wbudowanych pul i systemów zostaje jawna, nowe wchodzą względem
  nazwanego sąsiada, więc determinizm się nie zmienia.
- `Pools.of(g,'enemies')` tam, gdzie znaczy „cel”, przechodzi na
  `Bodies.targets(g)`. Szybka ścieżka dla braku bytów `hittable` chroni koszt.
  Odczyty 51 miejsc są klasyfikowane: „demon” zostaje, „cel” przechodzi.
- `enemy-pool-reads` nie schodzi do zera; kończy się listą uzasadnionych użyć.

**Próby.** Wieżyczka strzelająca do demonów, beczka wybuchająca po trafieniu,
NPC z interakcją, drzwi przełączane dźwignią. Każde z zapisem i dziennikiem.

**Koniec.** Wszystkie cztery próby tylko przez `Entities.define` i bez zmian
w `game/src`.

### R9 — pakiet treści i odbiór

Rozmiar: M. Zależy od wszystkich.

**Dowód końcowy.** `tests/support/extension/pack/` to jedna kompletna treść:
postać, broń bez amunicji, broń z alt-fire, zaklęcie, demon, typ obrażeń, stan,
glif, pole, mapa, bieg dwuetapowy, wieżyczka.

Test wczytuje pakiet przez publiczne rejestry i wykonuje pełną drogę: start,
walka, zapis, wczytanie, odtworzenie, render, wyrejestrowanie. Warunek twardy:
odcisk źródeł `game/src` jest taki sam z pakietem i bez niego.

**Dokumenty.** `ROZSZERZANIE.txt` przepisany na przepisy dla każdego scenariusza,
`ARCHITEKTURA.txt`, `INSTRUKCJA.txt`, `ZMIANY.txt`, `ODBIOR.txt`,
`docs/KONTEKST.txt`, numer 0.35.

**Odbiór.** All, showcase, 606 renderów względem referencji R0, plateau
zasobów, pięć par pomiaru względem `1c297f5`, osobne B2.

## Kolejność i zależności

| Etap | Zależy od | Rozmiar | Może iść równolegle z |
|---|---|---|---|
| R0 | — | S | — |
| R1 | R0 | L | R6 |
| R2 | R1 | XL | R6 |
| R3 | R2 | L | R4 (bez wspólnych plików), R6 |
| R4 | R1, R2 | L | R3, R6 |
| R5 | R4 | M | R6 |
| R6 | R0 | M | R1–R5 |
| R7 | R3, R5, R6 | L | R8 |
| R8 | R2, R6 | L | R7 |
| R9 | wszystkie | M | — |

Każdy etap kończy się osobnym commitem z raportem
`game/docs/PLAN-v12-Rn-RAPORT.md`. Etap można odłożyć po dowolnym zamknięciu,
a gra pozostaje wtedy w pełni działająca.

## Stan scenariuszy po v12

| Scenariusz | Dziś | Po v12 |
|---|---|---|
| Broń palna | definicja | definicja |
| Broń bez amunicji, alt-fire, tryb ognia | zmiany w rdzeniu | definicja, ewentualnie model |
| Nowy sposób trafiania | powielone rozliczenie | jeden wykonawca dostarczania |
| Efekt przy zabiciu, strzale, pudle | zmiany w rdzeniu | definicja reakcji |
| Buff, debuff | zmiany w rdzeniu | definicja stanu |
| Zaklęcie z maną i czasem rzucania | przeróbka | definicja, ewentualnie wykonawca |
| Postać grywalna | przeróbka | definicja i art |
| Demon | definicja i art | definicja i art |
| Nowy rodzaj zagrożenia | 3 warstwy | jeden zestaw wpisów |
| Nowy typ pola | 6+ plików | definicja |
| Kolejna mapa w biegu | brak modelu | dane biegu |
| Wieżyczka, beczka, NPC | około 5 miejsc | `Entities.define` |

## Ryzyka

| Ryzyko | Ochrona |
|---|---|
| R2 zmienia kolejność zdarzeń i wynik walki | Migracja po jednej ścieżce, skrót złotego wzorca po każdej |
| Modyfikatory spowalniają strzał | Szybka ścieżka bez stanów, pomiar po R2 przed R3 |
| Codex zmienia pliki walki w trakcie | Jeden pisarz na grupę plików, referencja na commicie startowym |
| Rejestry bez użycia gniją | Każdy kontrakt ma próbę działającą w All |
| Przerost danych | Jeśli zachowanie jest algorytmem, zostaje wykonawcą; nie tworzymy języka skryptowego w tabelach |
| Migracja zapisu niszczy postęp | Fixture 0.34 w każdym etapie, zapis atomowy bez zmian |
| Plan okaże się za duży na jedno podejście | Każdy etap dostarcza wartość samodzielnie; R1, R2, R3 pokrywają najdroższe luki |

## Poza planem

- Nowa treść produkcyjna: bronie, postacie, mapy, kręgi, fabuła.
- Zamknięcie otwartej bramki wydajności. Regresja 20 żywych ciał z
  `docs/PUNKT-1-WYDAJNOSC.md` to osobne zadanie; v12 jej nie ukrywa i nie
  może jej pogłębić.
- Kooperacja, split-screen, sieć i kamera drugiego gracza.
- Ładowanie modów z dysku. R9 dowodzi kontraktu, nie dodaje funkcji gracza.
- Modele 3D, drugi język, zmiana nazw puli i prefabu.
- Zmiana HUD-u i menu, poza tym że pokazują te same wartości z nowych źródeł.

## Warunek zakończenia planu

1. Pakiet R9 przechodzi pełną drogę bez zmian w `game/src`.
2. Zapadki etapów są na zerze, a `enemy-pool-reads` ma uzasadnioną listę.
3. Referencje produkcji zgadzają się dla każdego etapu.
4. Zapisy SIGIL06–09 i fixture 0.34 wczytują się z tym samym rzutem stanu.
5. Pomiar nie pokazuje regresji względem `1c297f5` albo regresja jest opisana
   i zaakceptowana przez użytkownika.
6. Dokumenty opisują rzeczywisty kod.
7. B2 odbiera człowiek, osobno od powyższego.
