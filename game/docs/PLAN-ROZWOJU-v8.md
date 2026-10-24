# SIGIL: BREACH — PLAN v8: gotowość bazy do rozwoju i skalowania

Stan: analiza 2026-10-24, kod po commitach `e1b5d34` (muzyka, ślady ruchu),
`fa9d17f` (dźwięki broni) i `216b56a` (portale w katalogu poligonu). Sama
analiza nie zmieniła kodu. Uzupełnia PLAN-ROZWOJU-v7.md (trafienia), nie
zastępuje go.

Oznaczenia: **[K]** potwierdzone w kodzie, **[R]** zmierzone (`--benchmark`,
`--core-measure`, rozmiary plików), **[H]** szacunek lub hipoteza.
Ścieżki są względne do katalogu `game/`.

## 0. Werdykt

- **Baza jest gotowa do dalszego rozwoju bez przepisywania.** Nowe demony,
  bronie, wyposażenie, dźwięki i tryby na obecnej mapie dodaje się głównie
  danymi i małymi modułami.
- **Warunek dla kierunku gry (9 kręgów = wiele map):** wiedza o jedynej mapie
  (Limbo) jest rozsiana po rendererze i danych trybów. Przed drugą mapą
  potrzebny jest jeden ograniczony refaktor („mapa posiada scenografię”) oraz
  manifest zasobów per mapa.
- **Skalowanie techniczne:** gra offline dla jednego gracza ma duży zapas
  czasu klatki. Ograniczeniem przy wzroście treści będzie pamięć tekstur
  i czas ładowania, nie procesor.
- **Znaleziona regresja:** `--benchmark` wywraca się od `216b56a` (sekcja 3G).

## 1. Jak to działa (przepływ)

`main.lua` → `src/app/application.lua` → polecenia (`src/app/commands.lua`)
→ fasada sesji `src/session/game.lua` → stały krok 1/120 s
(`src/session/simulation.lua`) → harmonogram systemów (`src/systems/index.lua`)
→ zdarzenia `sim` / `present` → renderer i UI (tylko odczyt). Treść to
definicje ze schematami (`src/content/defs/`) i rejestry
(`src/core/registry.lua`); tryby to rejestr strategii (`src/run/modes.lua`).

Rozmiar [R]: `src` ok. 36,6 tys. linii (z czego `content` 12,8 tys., w tym
wygenerowane `content/art/enemy_frames.lua` i `hit_masks.lua`), testy 22,1 tys.,
QA 9,7 tys.; 3435 sprawdzeń w TEST.

## 2. Co jest dobre i warto zachować

1. **Symulacja nie zna prezentacji** [K]: haki `src/session/presentation.lua`
   (bez prezentacji są no-op), `tools/check` pilnuje 0 krawędzi symulacja →
   prezentacja, braku cykli i granic warstw. Dowód praktyczny: muzyka,
   cząstki, dźwięki broni i portale zmieniły się bez ruszania złotego wzorca
   (6/6).
2. **Treść jako dane z walidacją** [K]: `Creature.define` z `extends`,
   `Weapon.define`, `Action.build`, `Mark.move` (ślady ruchu); listy katalogu,
   galerii i bestiariusza z `A.listed('field')`. Nowy demon na istniejącym
   obrazie = jeden plik w `src/content/creatures/` (test `creature_extension`).
3. **Zachowania jako rejestry strategii** [K]: rodzaje ataków `Kinds.lunge /
   charge / strike / leap / pool / fan / bolt` (`src/enemies/actions.lua:137-361`),
   `AI.styles` / `AI.states`, mechanizmy przeładowania z głosami
   (`src/combat/reload.lua`, `content/tuning.lua reload.<m>.voices`),
   `Cast.kinds`, tryby.
4. **Determinizm i powtórki** [K][R]: stały krok, strumienie RNG `sim` /
   `present`, dziennik poleceń, snapshot. `--core-measure`: 10 s walki liczy się
   w 100 ms, snapshot 0,65 ms / 66 KiB, dziennik 27 KiB/s, 300 fal bez wycieku.
5. **Barierki jakości** [K]: złoty wzorzec, zapadka liczb bez nazw (275,
   `tools/check/literals.txt`), deklarowane pola sesji (`src/session/fields.lua`),
   KONWENCJE i ARCHITEKTURA zgodne z kodem.
6. **Nowe moduły też są danymi** [K]: dźwięk (`src/audio/recipes.lua`,
   `src/audio/score.lua`), ślady ruchu (`src/content/movement_marks.lua` ze
   schematem `src/content/defs/movement_mark.lua`).

## 3. Gdzie rozwój będzie kosztował zmiany w wielu plikach

### A. Mapa nie jest właścicielem swojej scenografii (najważniejsze) [K]

`src/content/maps/limbo.lua` opisuje pokoje, kolumny, pieczęcie, bramy i strefy.
Reszta jest zaszyta gdzie indziej:

- `src/render/world_mesh.lua:80-97` — ołtarz (16, 17), łuk portalu (16, 2.9);
  `:134` — ołtarz sekretu (3.7, 20.4);
- `src/render/renderer.lua:43` — `PROP_POS`; `:666-670` — znaki strażnika
  i sekretu na sztywnych współrzędnych;
- `src/content/classic.lua` — pozycje zapasów i strażnika; `src/world/gallery.lua`
  — układ padów; `Sanctuary.shrine` — kapliczka;
- jedna wysokość podłogi na mapę, renderer rysuje od 0 (ARCHITEKTURA pkt 13);
- jeden atlas ścian i podłóg (`assets/art/textures-fresco-v12.png`) dla całej gry.

### B. Stan trybów wycieka do prezentacji i infrastruktury [K]

Routing 0.31 objął sesję (interakcje, pozwolenia, HUD). Zostały:

- renderer czyta `g.run` i `Descent.shrine` (`src/render/renderer.lua:440`,
  `623-670`, `780-800`); `src/render/lights.lua:60` czyta `g.run`;
- `src/ui/descent.lua` czyta `g.run` w 9 miejscach; `src/ui/interface.lua:69-75`;
- `src/render/effects.lua:337` czyta `g.testField.hitboxes`;
- dziennik ma sztywne „tryb → konstruktor sesji” (`src/session/journal.lua:125-128`),
  a `Modes.forSession` używa drugiego słownika (`descent` ↔ `expedition`);
- `src/world/gallery.lua` importuje `src/run/test_field.lua`;
- poligon używa kształtu rekordu wyprawy (`g.run = { phase='wave', wallet,
  pending… }`, `src/run/test_field.lua:101`).

### C. Duże moduły o wielu rolach [K][R]

- `src/render/renderer.lua`: 884 linie, 32 zależności (najwięcej w projekcie).
- `src/run/test_field.lua`: 737 linii — katalog, przywołania, stanowiska, sklep,
  pieczęcie, pozy; `F.action` to łańcuch `if id ==` (`:643`).
- Nawigacja między sesjami ad hoc: `app.fieldReturn`
  (`src/app/commands.lua:27-71`).

### D. Prezentacja ataków rozgałęzia się po nazwie rodzaju [K]

Symulacja ma rejestr `Kinds`, rysowanie nie:
`src/render/effects.lua:301-335` (`lunge` / `charge` / `leap`),
`src/enemies/animation.lua:36` i `:173`, pierścień skoku
`src/render/renderer.lua:723`, `src/enemies/hazards.lua:31` (`lightning`).
Nowy rodzaj ataku = wpis w rejestrze + 3–4 edycje prezentacji.

### E. Dane grafiki w kodzie renderera [K]

- `src/render/weapon_art.lua:8` — `A.ids = {'exorcist','judge'}` i stały układ
  arkusza 1600² 4×4 (demony i umiejętności mają to w `src/content/`);
- `src/render/weapon.lua:284` — `assert(handAtlas == 'powder')`;
- pozycje pieczęci w `src/ui/screens/help.lua`;
- `src/ui/hud.lua:119` — mapowanie `choke` → `'FOCUS'`.

### F. Drobniejsze [K][R]

- Płaski stan sesji: ok. 150 deklarowanych pól, w tym pola jednego trybu
  (`seals`, `secretFound`, `rank`, `bossDead`). Deklaracje trzymają to w ryzach.
- 112 `require` wewnątrz funkcji w 54 plikach (najwięcej `content/enemies.lua`,
  `combat/rules.lua`): głównie omijają cykle, ale ukrywają zależności.
- Ok. 100 tekstów dla gracza zaszytych w ok. 20 plikach (np. `ui/descent.lua`,
  `run/test_field.lua`, `ui/views.lua`) oraz angielski malowany napis
  `assets/art/lettering-en-v16.png`.

### G. Narzędzia QA poza TEST psują się po cichu [K][R]

TEST uruchamia 3 z 21 flag QA. `--benchmark` wywraca się na
`qa/benchmark.lua:648` („lifecycle did not enter the requested arena”): cykl
przywołuje demony akcją katalogu i oczekuje ich od razu, a od `216b56a`
przychodzą przez portal (1,2 s). `--core-measure` działa, ale jego „10 s walki”
zawiera teraz 1,2 s otwierania portali.

### H. Paczka wydania 303 MiB przy grze ok. 95 MiB [R]

`outputs/SIGIL-BREACH-0.31` zawiera dane gry trzy razy (`source/` 90 MiB,
`SIGIL-BREACH.love` 85 MiB, `SIGIL-BREACH.exe` 86 MiB) oraz ok. 50 zrzutów
i raportów QA. Po trailerze gracze powinni dostać samo EXE + DLL.

## 4. Scenariusze rozwoju

| Scenariusz | Ocena | Co trzeba zrobić / trudności |
|---|---|---|
| Nowy demon na istniejącym obrazie | Łatwe | Jeden plik `content/creatures/<id>.lua`. |
| Nowy demon z nowym atlasem | Architektura OK, drogi proces | PNG, `sources`, `enemy_art`, ręczne wielokąty anatomii (ok. 28 klatek), bake masek, punkty anatomiczne; +6–10 MiB tekstur [H]; nowy rodzaj ataku przez 3D. |
| Nowa broń | Łatwe w symulacji | Definicja, rejestr dostaw, mechanizm + głosy; HUD przewija dowolną liczbę broni (`ui/hud.lua:107-117`); nowa grafika rąk przez 3E. |
| Wyposażenie F/C | Symulacja gotowa | HUD pokazuje tylko slot Q (świadoma granica); ręce przypięte do `powder`. |
| **Nowy krąg = nowa mapa** | **Trudne dziś** | Cały punkt 3A + tekstury per krąg, światła (`lights.lua` czyta `g.run`), wczytywanie wszystkiego naraz. |
| Kampania / hub między kręgami | Średnie | Rejestr trybów dobry; brak nawigacji sesji (zamiast `fieldReturn`), zapis związany z wyprawą (`descent-v06`, SIGIL08), sztywne konstruktory w dzienniku. |
| Tłumaczenie na polski | Średnie | Wyciągnięcie ok. 100 tekstów + polski malowany napis; fonty mają polskie znaki (test). |
| Co-op / sieć | Bardzo drogie | Fundament lockstepu jest (stały krok, dziennik, RNG), ale `g.player` w 188 liniach / 62 plikach i jeden widz (ARCHITEKTURA pkt 13). Nie przygotowywać na zapas. |
| Większe bitwy (50–100 demonów) | Realne | Ograniczeniem liczba wywołań rysowania (ok. 13 na demona) [R]. |

## 5. Skalowalność techniczna [R]

- **Liczba użytkowników:** nie dotyczy — gra lokalna, bez serwera. Rankingi czy
  telemetria online wymagałyby osobnego projektu.
- **Obciążenie (`--benchmark`, 1280×720):** scena „ciężka” (20 demonów, 240 cząstek,
  12 pocisków) — pełna klatka mediana 4,9 ms, p99 6,8 ms (budżet 16,7 ms przy
  60 FPS); symulacja 0,07 ms na krok; 388 wywołań rysowania. Alokacja 17,9 KiB
  na krok: domyślny odśmiecacz dawał pauzy do 32 ms; aplikacja ma dostrojone
  tempo GC (`src/app/application.lua:41-42`), wtedy maksimum ok. 5 ms.
- **Dane i pamięć (główne ryzyko):** 529 MiB tekstur przy 83 obrazach (suma PNG
  po rozpakowaniu 393 MiB); wszystko wczytywane przy starcie
  (`src/render/assets.lua`, `fresco_enemies.loadAll`); pierwsze wejście galerii
  822 ms (etapowane). Przy 9 kręgach i ok. 30 demonach szacunkowo ponad 1,5 GiB [H].
- **Pozostałe:** maski 743 KiB w pamięci, 36 ms budowy (168 klatek); synteza
  audio ok. 0,5 s przy starcie; dziennik z limitem 64 MiB (ok. 40 minut); pełny
  TEST ok. 5 minut, showcase 551 zrzutów rośnie z treścią.

## 6. Czego nie da się ocenić bez dodatkowych informacji

- Docelowy sprzęt i budżet pamięci karty graficznej (np. Steam Deck).
- Planowana skala treści: ile map (kręgów) i demonów.
- Czy w planach są co-op lub funkcje online.
- Czy będzie polska wersja językowa.
- Wielkość zespołu (wpływa na potrzebę CI i podziału modułów).

## 7. Plan zmian

### Teraz

| # | Zmiana | Uzasadnienie | Zakres | Korzyść |
|---|---|---|---|---|
| T1 | Naprawić `--benchmark`; dodać szybki przebieg narzędzi QA (benchmark, core-measure, step-study, audio-export) do TEST lub BUILD | Regresja istnieje (3G); narzędzia gniją niezauważone | 1–2 pliki QA + skrypt | Wiarygodne pomiary wydajności |
| T2 | Paczka dla graczy (EXE + DLL, ok. 95 MiB) oddzielnie od paczki deweloperskiej | Po trailerze gracze pobierają grę; dziś 303 MiB (3H) | `tools/build.ps1`, `tools/verify.ps1` | Paczka ok. 3× mniejsza, bez materiałów QA |
| T3 (opcj.) | Dziennik pyta rejestr trybów o konstruktor sesji zamiast `if` w `journal.lua:125` | Każdy nowy tryb uderza w infrastrukturę | ok. 20 linii | Nowy tryb nie dotyka dziennika |

### Przed drugą mapą (krąg)

| # | Zmiana | Uzasadnienie | Zakres | Korzyść |
|---|---|---|---|---|
| M1 | „Mapa posiada scenografię”: rekwizyty, ołtarze, łuk portalu, znaki strażnika i sekretu, zapasy i strażnik, pady galerii, kapliczka trafiają do `content/maps/<id>.lua`; renderer rysuje ogólną listę `decor`; tryby i renderer pytają o miejsca mapę lub tryb | 3A blokuje wizję 9 kręgów | Średni: renderer, world_mesh, classic, gallery. Dowód: zrzuty Limbo identyczne bajt w bajt przed i po | Nowy krąg = głównie plik danych |
| M2 | Manifest zasobów per mapa + wczytywanie i zwalnianie przy przejściu (rozszerzyć etapowe ładowanie galerii) | 529 MiB tekstur już dziś, wszystko naraz | Średni | Pamięć rośnie z mapą, nie z całą grą |
| M3 | Podłoga ≠ 0 w rendererze — dopiero gdy mapa tego wymaga | ARCHITEKTURA pkt 13 | Mały–średni | Poziomy, schody |

### Przy konkretnej potrzebie

| # | Kiedy | Zmiana | Korzyść |
|---|---|---|---|
| P1 | Nowy rodzaj ataku | Rejestr prezentacji ataków obok `Kinds` zamiast `if` w `effects.lua`, `animation.lua`, rendererze (3D) | Atak = symulacja + jeden wpis prezentacji |
| P2 | Trzecia grafika broni | Rejestracja arkuszy broni w `content/` (jak `ability_art`) (3E) | Broń bez edycji renderera |
| P3 | Nowe narzędzia poligonu | Stanowiska jako dane, akcje katalogu jako tabela, podział `test_field.lua` (3C) | Mniejszy plik o jednej roli |
| P4 | Kampania / hub | Nawigacja sesji („skąd i dokąd wraca”) zamiast `fieldReturn`; zapis niezwiązany z samą wyprawą | Spójne przejścia i zapisy |
| P5 | Każdy dotknięty ekran (zasada skauta) | Ekrany i renderer pytają tryb zamiast czytać `g.run` (3B) | Tryby niezależne od siebie |

### Odłożyć (brak konkretnej potrzeby)

Lokalizacja (do decyzji o polskiej wersji), co-op i sieć, kompresja tekstur
(DDS/BC — gdy pamięć stanie się problemem), sprzątanie `require` w funkcjach,
spłaszczanie pól sesji.

## 8. Czego nie robić

Nie przepisywać renderera od zera, nie budować nowego silnika i nie dokładać
warstw abstrakcji przed realną drugą mapą. Każda zmiana z punktu 7 ma być
weryfikowana pełnym TEST, złotym wzorcem i — gdy dotyka obrazu — porównaniem
zrzutów przed i po.

## 9. Postęp

- [ ] T1 — `--benchmark` + przebieg narzędzi QA
- [ ] T2 — paczka dla graczy
- [ ] T3 — konstruktor sesji z rejestru trybów
- [ ] M1 — mapa posiada scenografię
- [ ] M2 — manifest zasobów per mapa
- [ ] M3 — podłoga ≠ 0
