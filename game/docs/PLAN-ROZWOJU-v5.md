# SIGIL: BREACH — PLAN v5: dopracowanie rdzenia (feeling, logika, matematyka, fizyka, silnik)

Stan: przyjęty 2026-10-22 z rekomendacjami D1–D8. **Wdrożone w 0.25: G0–G5 i G7**
(opis i pomiary: ZMIANY-0.25.txt). **G6 wdrożone w 0.26** po Twoim teście: broń
wtopiona w scenę, podskok widoku i łomot strzału, pomiar hitboxów (ZMIANY-0.26.txt).
Cele D7 po Twojej sesji: kontrola 8,5 % (spełniony), zabójstwa przełamane 43 %
(powyżej 15–25 %, decyzja w PLAN-ROZWOJU-v6.md), idealne uniki 2. Dodane ponad plan:
idealny unik przez powidok (bez niego cel D7 był nieosiągalny). Następny: plan v6.

## 0. Werdykt: czy to podejście ma sens

**Tak, ale z dwoma zastrzeżeniami.**

- Teraz jest właściwy moment. Jedna arena, dwie bronie i sześć demonów oznaczają, że poprawka fundamentu (ciała, wysokość podłoża, sterowanie, przeładowanie jako dane) kosztuje tyle co jeden plik. Po dodaniu map, broni i zaklęć ta sama poprawka objęłaby każdy z nich.
- **Zastrzeżenie 1: „perfekcja” musi mieć liczby.** Bez celów (czas kontroli, udział zabójstw przełamanych, obrażenia na falę, długość walki) strojenie nie ma końca. W etapie G0 proponuję cele do Twojej akceptacji.
- **Zastrzeżenie 2: feelingu nie zmierzą boty.** Boty mają idealną wiedzę: nigdy nie robią uniku i nie rzucają prochu (0 w każdym raporcie). Warstwy techniczne (G0–G3) da się zrobić i zweryfikować samemu. Strojenie odczucia i balansu (G4–G5) wymaga Twojego ręcznego testu. Dlatego G0 dodaje narzędzia, dzięki którym Twoja sesja zostawia dane: dziennik plus telemetrię.
- Czego nie dopracowywać teraz: ekonomii wyprawy i sklepu. Wyprawa jest ukryta w menu („The expedition waits until the combat is forged”), więc strojenie jej teraz to praca do wyrzucenia. Skupiamy się na walce: poligon, próba fal, potyczka.

## 1. Zakres przeglądu

Przeczytane w całości:
- sesja i systemy: game, state, simulation, systems/*, listeners, damage_outcomes, interactions, capabilities, fields, journal, presentation, event_catalog;
- rycerz: player/feel, intent, movement_gait, physics/*;
- walka: combat, ballistics, damage, rules/* (8 części), melee, projectiles, reload, abilities, explosives, telemetry;
- demony: enemies/ai, actions, body, corpse, hazards, geometry, animation;
- dane: tuning, combat_defaults, wszystkie stworzenia, knight, enemies, conditions, defs (action, creature, body), weapons, abilities, waves;
- tryby i świat: run/spawner, modes, descent, część test_field, world/arena, limbo_layout;
- aplikacja: application, input, main;
- odczucie: feedback/weight, weapon_motion, listeners, shot_feedback, world_feedback;
- rdzeń: core/events, scheduler.

Do tego raporty QA 0.24 (ai-audit, playtest-*, balance) i świeży pomiar `--benchmark`.

## 2. Stan zmierzony

| Pomiar | Wartość | Uwagi |
|---|---|---|
| Model człowieka (5 profili), fale 1–5 | wygrane 5/5, obrażenia 93–142, czas kontroli **2,1–4,5 %**, czas zabójstwa 3,9–5,4 s | zdrowie odnawiane po fali |
| Zabójstwa przełamane (model człowieka) | **1 na 39** (leczenie 7,5 HP) | bot idealny: 13 na 39 |
| Idealne uniki / ładunki prochu | **0 / 0** we wszystkich botach | mechaniki niezmierzone |
| Audyt AI 60 s | 0 utknięć, anulowania 0–1 | dobrze |
| Symulacja, 20 demonów | 0,06 ms mediana, 0,25 ms p95 na krok | zapas ogromny |
| Rysowanie, 20 demonów | 1,45 ms submit, 362 draw calls | dobrze |
| Pierwsza klatka świata | **861 ms** (shadery, atlas cieni) | przycięcie przy wejściu do gry |
| Alokacja Lua na klatkę | 5,7–8,2 KiB | ryzyko mikroprzycięć GC przy wysokim FPS |

**Wniosek balansowy (technicznie).** Pętla „przełam, potem zabij = leczenie” (0.24) prawie nie działa w grze człowieka. Strzelba zadaje Słudze 240 obrażeń z bliska przy 112 HP, więc zabija przed jakimkolwiek przełamaniem. Czas kontroli 3 % oznacza, że demony prawie nigdy nie są wybijane z akcji. To decyzja projektowa, nie błąd (punkt 8, D5).

## 3. Ustalenia

### A. Logika i spójność (bez zmiany rozgrywki)

| # | Co | Gdzie |
|---|---|---|
| A1 | Liczba ładunków uniku wpisana jako `2` w 4 miejscach, mimo że jest `Tuning.knight.dashCharges` | `session/damage_outcomes.lua:76`, `run/descent.lua:59, 385`, `run/test_field.lua:69` |
| A2 | Poligon zakłada dwie bronie (`{id=1,'EXORCIST'},{id=2,'JUDGE'}`) i `hp=100`, `armor=100` | `run/test_field.lua:26, 69` |
| A3 | Glif `choke` jest w kodzie (`spread 0.72`), a `pierce` w danych | `content/weapons.lua:256` |
| A4 | Przeładowanie: progi czasu (0,26 / 0,82 / 0,68 / 0,20…) w kodzie; symulacja tworzy łuski w `g.view.shells` (zapis prezentacji z symulacji) | `combat/reload.lua:28–97, 45–55` |
| A5 | Martwy kod mapy: atrapa `limbo_layout` (`ceiling()` zawsze false), `w.expanded` nigdy nie ustawiane, nieużywane `B.falloff` | `combat/ballistics.lua:50, 131`, `combat/explosives.lua:153`, `systems/clocks.lua:4` |
| A6 | Zapasowe wartości danych w kodzie (`pickup.amount or 25`) i liczby bez nazwy w regułach (rana 1,6 / 1,2 s, `slamLock` 0,3, tarcie 6, zasięg Żaru 2,8, znajdźka 0,7, rzut zabijający 1,35 + 0,65·n) | `session/interactions.lua:36, 175, 201`, `rules/hit_response.lua:41, 90`, `rules/knight.lua:52, 65, 70`, `combat/explosives.lua:96–97` |
| A7 | `shotAge`/`swapAge` to pola symulacji, ale czyta je tylko prezentacja; ustawiają je dwa słuchacze prezentacji | `feedback/shot_feedback.lua:17`, `feedback/weight.lua:73` |
| A8 | Ruch myszy zmienia `player.yaw` z pominięciem fasady (dziennik łapie celowanie tylko przy następnym poleceniu) | `app/input.lua:53–57` |
| A9 | Kod wyprawy pyta `if g.testField` w 10 funkcjach, choć tryby mają rejestr | `run/descent.lua` |
| A10 | Klawisze na sztywno; zaklęcia ze slotu 2+ nie mają klawisza (`Q` = tylko slot 1) | `app/input.lua:27–34, 149` |

### B. Matematyka

| # | Co | Gdzie |
|---|---|---|
| B1 | `armorLoss` (raport, iskry pancerza) ignoruje pancerz miejsca i „odsłonięcie”. Strzał w gołą czaszkę Margrabiego pokazuje pancerz. | `combat/damage.lua:162` |
| B2 | Przebicie liczy koszt z `armorRating`, a nie z pancerza trafionego miejsca | `combat/combat.lua:204` |
| B3 | Iloczyn efektów stanów w kolejności `pairs` (teoretyczne ryzyko determinizmu między wersjami LuaJIT) | `rules/conditions.lua:31` |
| B4 | Rycerz dostaje połowę obrażeń od uderzenia o mur (`* 0.5`) bez nazwy i opisu — wbrew „jednemu prawu” | `rules/knight.lua:70` |

### C. Fizyka

| # | Co | Gdzie |
|---|---|---|
| C1 | **Rycerz przechodzi przez demony.** Ruch rycerza zderza się tylko z kaflami, a rozsuwanie działa tylko demon–demon. Demon może stać „w” rycerzu. | `player/feel.lua:191`, `enemies/ai.lua:388` |
| C2 | Rozsuwanie demonów ignoruje masę: Sługa przepycha Żelaznego tak samo jak odwrotnie | `enemies/ai.lua:403–405` |
| C3 | Świat zakłada podłogę na y = 0 w 7 miejscach (skok, ładunek, pociski, zwłoki, doskok, kałuże, strzał w podłogę). Mapa z poziomami wymagałaby edycji każdego z nich. | `physics/kinematics.lua`, `combat/explosives.lua:96`, `combat/ballistics.lua:124`, `enemies/body.lua`, `enemies/actions.lua:438` |
| C4 | Pościg poza zasięgiem wzroku idzie od środka do środka kafla (schodki), a pole przepływu liczone jest osobno dla każdego demona co 0,65 s, z tablicą na węzeł | `enemies/ai.lua:107–129`, `world/arena.lua:101` |
| C5 | Wybuch sprawdza rycerza na wysokości `1` zamiast z ciała | `combat/explosives.lua:75` |
| C6 | Zatrzymanie trafienia (`impactSlow`) wstrzymuje tylko decyzje demonów; pociski, kałuże i zwłoki lecą dalej | `enemies/ai.lua:427` |

### D. Feeling

| # | Co | Gdzie |
|---|---|---|
| D-1 | Zachwiany rycerz: broń opada o 9 px („bezradność widać w dłoniach”), a mimo to strzela normalnie | `feedback/weapon_motion.lua:174`, `combat/combat.lua:61` |
| D-2 | Przeładowania Sędziego (1,85 s) nie da się przerwać spustem, nawet z 5 nabojami w bębnie | `combat/combat.lua:62` |
| D-3 | Czułość myszy niesymetryczna: pion 0,0021 vs poziom 0,0023 (−8,7 %); pochylenie ograniczone do ±0,9 rad (±52°) | `app/input.lua:53–55` |
| D-4 | 861 ms przycięcia przy pierwszej klatce świata | benchmark |
| D-5 | Pętla przełamania i leczenia niewyczuwalna (sekcja 2) | dane |

## 4. Co już istnieje i zostanie wykorzystane

- **Prawo zderzenia ciał** `physics/body_physics.lua: P.contact` (zachowuje pęd, bez tworzenia energii) — posłuży do kontaktu rycerz–demon (C1) i rozsuwania według masy (C2).
- **Prawo pchnięcia i sufit** `R.shove`, `R.addPush` — rycerz popychany przez demona używa tego samego.
- **Telemetria** `combat/telemetry.lua` i **dziennik** `session/journal.lua` (`--record`, F9) — Twoja sesja da dane bez nowego mechanizmu, wystarczy zapis automatyczny.
- **Rejestr mechanizmów przeładowania** (`Reload.mechanisms`) — progi czasu przejdą do danych mechanizmu, a nowa broń (dźwignia, magazynek) będzie jednym wpisem.
- **Glify jako dane** (`glyphs.set/scale`) — `choke` stanie się takim samym wpisem (skala rozrzutu).
- **Rejestr trybów i polityka** (`Modes`, `Capabilities`) — wyprawa przestanie znać poligon.
- **Złoty wzorzec, test headless, test rozszerzalności, zapadka liczb** — pilnują każdego etapu.
- **Modele człowieka** (`qa/scenarios/playtest.lua`) — dostaną unik na zapowiedź i rzut prochem.

## 5. Etapy

Każdy etap kończy się: FORMAT, pełne testy, porównanie złotego wzorca, krótki raport.

- **[=]** — rozgrywka bez zmian, złoty wzorzec identyczny.
- **[Δ]** — celowa zmiana rozgrywki: nowa baza złotego wzorca, wpis w ZMIANY z liczbami (czas kontroli, czas zabójstwa, obrażenia otrzymane).

### G0. Pomiar i cele [=]
- Boty: model człowieka robi unik na zapowiedź (z czasem reakcji modelu) i rzuca proch w grupę ≥ 2. Raport populacji pokazuje idealne uniki, ładunki, udział zabójstw przełamanych oraz telemetrię osobno dla każdej fali.
- Benchmark: najdłuższa pauza GC i czas pierwszej klatki jako stałe wiersze raportu.
- Twoja sesja zostawia dane: koniec próby fal, potyczki lub śmierć zapisuje `telemetry-<czas>.txt`, a z `--record` także dziennik.
- Proponowane cele (do akceptacji, D7).
- Weryfikacja: złoty wzorzec identyczny (zmiany tylko w `qa/`), nowe wiersze raportów.

### G1. Spójność i dług [=]
- A1, A2, A3: wartości z danych (ładunki uniku, broń z loadoutu, ciało rycerza, glif `choke` jako `scale.spread`).
- A4: progi przeładowania w danych mechanizmu; łuski tworzy słuchacz `ReloadStage` (prezentacja).
- A5: usunięcie atrapy `limbo_layout` i martwych ścieżek (`expanded`, `ceiling`, `B.falloff`).
- A6: nazwy dla liczb, usunięcie `or 25` (wartość domyślną daje schemat znajdźki); zapadka liczb obniżona.
- A7: `shotAge`/`swapAge` przeniesione do `g.view`.
- A8: polecenie `Game:aim(dYaw, dPitch)`; dziennik zapisuje celowanie jako polecenie i nadal czyta stare wpisy `aim`.
- B1: jedna funkcja „efektywny pancerz miejsca” dla obrażeń i raportu.
- B3: stany w kolejności katalogu.
- Weryfikacja: złoty wzorzec identyczny, zapadka liczb niższa, test „dziennik z poleceniem aim odtwarza bit w bit”, testy regresji dla A1 (3 ładunki z danych działają wszędzie) i B1.

### G2. Silnik pod rozbudowę [=]
- C3: jedno zapytanie `Ground.height(world, x, z)` w warstwie physics (na Limbo zwraca 0), użyte we wszystkich 7 miejscach.
- C4 (część techniczna): wspólna pamięć pola przepływu na (kafel celu, rewizja świata) i kolejka tablicowa — ten sam BFS, mniej alokacji.
- A9: wyprawa nie zna poligonu; obsługa poligonu przechodzi do jego trybu.
- A10: przypisania klawiszy jako dane (domyślnie identyczne) i klawisze dla slotów umiejętności 2+.
- D-4: rozgrzanie shaderów i atlasu cieni podczas ładowania menu.
- Pule gorących tablic (kontekst ciosu, zdarzenia) tylko wtedy, gdy G0 pokaże pauzy GC > 1 ms.
- Weryfikacja: złoty wzorzec identyczny, benchmark przed i po, test „druga mapa z podłogą na innej wysokości” (wysokość podłogi tylko w teście).

### G3. Fizyka ciał [Δ]
- C1: kontakt rycerz–demon tym samym prawem `P.contact` (masy: rycerz 1,5, Sługa 1, Żelazny 1,4, bossowie 8,3). Żywe ciała blokują, zwłoki nie. Wariant uniku: D1.
- C2: rozsuwanie demonów według udziału mas.
- C4 (część ruchowa): wygładzanie trasy — ruch do najdalszego widocznego kafla trasy zamiast do środka sąsiada.
- C5, B4: wysokość wybuchu z ciała; udział rycerza w uderzeniu o mur jako nazwana dana albo jedno prawo (D8).
- Weryfikacja: testy (brak nakładania rycerza i demona po 60 s naporu, zachowanie pędu, Żelazny przepycha Sługę bardziej niż odwrotnie), audyt AI (0 utknięć, 0 anulowań), populacja przed i po (czas kontroli, czas zabójstwa, obrażenia), nowa baza złotego wzorca i wpis w ZMIANY.

### G4. Odczucie walki [Δ] (według Twoich decyzji D1–D4, D6)
- D-1: zasada strzału w zachwianiu.
- D-2: przerwanie przeładowania spustem.
- C6: zakres zatrzymania trafienia.
- D-3: symetryczna czułość i zakres pochylenia.
- Weryfikacja: testy wejścia (prawdziwe callbacki), oś czasu broni (`weapon-timeline`), populacja, ZMIANY.

### G5. Matematyka i pętla nagrody [Δ] (decyzja D5 + dane z G0 i Twojej sesji)
- D-5: wybrany wariant pętli przełamania.
- B2: przebicie liczone z pancerza miejsca.
- Strojenie do celów z D7: tabele czasu zabójstwa (broń × demon × dystans × strefa) i obrażeń na falę próby; aktualizacja `docs/matematyka`.
- Weryfikacja: populacja mieści się w celach, złoty wzorzec, ZMIANY z tabelami przed i po.

### G6. Twoja sesja i strojenie
- Grasz na wersji po G3–G5 (albo równolegle na 0.24 — na tym, który wybierzesz). Pliki telemetrii i dziennika trafiają do mnie, a ja stroję według nich i Twoich uwag.

### G7. Wydanie 0.25
- Wersja w `release.lua`, `ZMIANY-0.25.txt`, ARCHITEKTURA i KONWENCJE, BUILD (testy, paczka, weryfikacja EXE, ZIP).

Kolejność: G0 → G1 → G2 → G3 → G4 → G5 → G6 → G7. Twój ręczny test 0.24 może iść równolegle z G0–G2, bo te etapy niczego w grze nie zmieniają.

## 6. Jak to zachowa się przy rozbudowie (roadmapa)

- **Mapy:** `Ground.height` i brak atrap Limbo oznaczają, że mapa z poziomami, mostem albo schodami nie wymaga zmian w 7 systemach. Wspólne pole przepływu skaluje się z rozmiarem mapy i liczbą demonów.
- **Hub/baza:** tryb poligonu odcięty od wyprawy to wzór dla trybu bazy; przypisania klawiszy jako dane obsłużą ekrany bazy i interakcje.
- **Więcej demonów:** kontakt ciał i rozsuwanie według masy działają dla każdego nowego ciała z samej definicji (masa, promień). Przyszli sojusznicy dostaną to samo prawo.
- **Więcej broni:** przeładowanie i glify jako dane: broń z dźwignią lub magazynkiem to wpis mechanizmu; modyfikator rozrzutu, obrażeń czy przebicia to wpis glifu.
- **Zaklęcia:** sloty 2+ mają klawisze; `Cast.kinds` bez zmian; mana nadal odłożona.
- **Powtórki i raporty błędów:** celowanie jako polecenie oznacza, że dziennik jest kompletny bez zgadywania.

## 7. Weryfikacja zasad punkt po punkcie

| Zasada | Jak plan ją spełnia |
|---|---|
| Odpowiedzi po polsku | Tak; komentarze w kodzie po angielsku (KONWENCJE 9) |
| Bez zatrzymywania w połowie, raport po etapie | Wszystkie decyzje zebrane z góry (sekcja 8); potem etapy idą do końca z krótkimi raportami |
| Balans opisany technicznie | Każdy etap [Δ] raportuje czas kontroli, czas zabójstwa i obrażenia otrzymane, przed i po |
| Zmiany techniczne nie zmieniają gry, wyglądu ani starych zapisów | G0–G2 = [=] ze złotym wzorcem identycznym. Format zapisu SIGIL07 bez zmian. Dziennik czyta stare wpisy `aim`. Wygląd bez zmian (rendery i audyt UI) |
| FORMAT, pełne testy, złoty wzorzec po etapie; regresje przed dalszą pracą | W definicji każdego etapu |
| Kod jako baza pod rozbudowę, wzorce, dane | Strategia (mechanizmy, glify, tryby), dane zamiast liczb, jedno zapytanie podłoża, jedno prawo ciał |
| Token HF | Nie dotykam, nie zapisuję |
| Granice warstw / 0 krawędzi symulacja → prezentacja | A4 i A7 usuwają zapisy prezentacji z symulacji; `Ground` w warstwie physics; nowe krawędzie = błąd checkera |
| Emiter dla każdego zdarzenia | Nowe zdarzenia (np. kontakt rycerz–demon) wchodzą do katalogu razem z emiterem i słuchaczem |
| Zapadka liczb (tylko maleje, nowy plik = 0) | A6 i G1 obniżają; nowe liczby trafiają do `content/` |
| Pułapki: cudzysłowy „” w PowerShell, UTF-8 bez BOM, `a and f()` | Teksty przez Edit; zapis bez BOM; wielowynikowe wywołania bez `and` |
| Szablon modułu, nazwy, `:` vs `.` | Nowe moduły (`physics/ground.lua`, przypisania) według szablonu |
| Brak fallbacków danych w kodzie | A6 usuwa `or 25`; wartości domyślne ze schematu |
| Definicje tylko do odczytu | Bez zmian; test niezmienności zostaje |
| Pole bytu w komponencie, pole sesji w `fields.lua` | Nowe pola (np. kontakt rycerza) najpierw w schemacie komponentu i katalogu pól |
| Kolejność kroku tylko w `systems/index.lua` | Kontakt rycerz–demon jako nazwany system wpisany tam |
| Losowanie tylko z `g.rng.sim` | Plan nie dodaje losowości |
| Polecenia przez fasadę | A8 domyka ostatni wyjątek (mysz) |
| Bez rozróżniania demonów po nazwie | Kontakt i rozsuwanie czytają masę i promień z ciała |
| Stan broni i umiejętności tylko w `arsenal` / `abilityState` | Przerwanie przeładowania (D-2) i ładunki uniku z danych bez nowych pól poza rekordami |
| Każdy naprawiony błąd ma test regresji | Wymienione w weryfikacji etapów |

## 8. Decyzje do podjęcia przed startem (D1–D8)

| # | Pytanie | Moja rekomendacja |
|---|---|---|
| D1 | Rycerz a ciała demonów | Żywe ciała blokują także w uniku (bez przenikania); zwłoki nie blokują |
| D2 | Strzał w zachwianiu rycerza (0,22–0,49 s) | Blokada strzału na czas zachwiania (spójne z opuszczoną bronią, zasada soulslike) |
| D3 | Przerwanie przeładowania Sędziego | Spust przerywa przeładowanie przed momentem ładowania (1,16 s), jeśli w bębnie są naboje; bęben zamyka się w 0,25 s |
| D4 | Zatrzymanie trafienia | Przełamanie gardy rycerza (0,06 s) zatrzymuje też pociski i kałuże; zamrożenie po idealnym uniku (0,25 s) zostaje tylko dla demonów |
| D5 | Pętla przełamania i leczenia | Leczenie za zabójstwo ciała przełamanego **lub zranionego w ostatniej 1,0 s**; ostateczne liczby po danych z G0 |
| D6 | Mysz | Czułość symetryczna (pion = poziom); pochylenie ±1,2 rad (±69°) |
| D7 | Cele „perfekcji” (model człowieka, próba fal) | Czas kontroli 8–12 %; zabójstwa przełamane 15–25 % zabójstw; ≥ 1 idealny unik na falę u modelu z unikami; żadna zapowiedź < 0,45 s (już spełnione) |
| D8 | Rycerz o mur: połowa obrażeń | Zostawić połowę jako nazwaną daną `knightSlamShare = 0.5` (bez zmiany gry) |

## 9. Czego świadomie nie robię

- Ekonomia wyprawy, sklep i długość wyprawy — wyprawa jest ukryta, strojenie wróci razem z nią.
- Mana i nowe rodzaje zaklęć — poza zakresem (sloty i klawisze będą gotowe).
- Hurtowe przepisywanie pętli po `g.enemies` na zapytania ECS.
- Nowa grafika — rysowanie zmienia się tylko tam, gdzie decyzja D-1 wymaga spójności broni z zasadą.
