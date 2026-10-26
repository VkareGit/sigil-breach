# SIGIL: BREACH — fundament v11: pozy, stan trybów, aktorzy i obserwator

Status: PRZYJĘTY przez użytkownika 2026-10-26 (wersja 3 z doprecyzowaniami
początku nagrania, aktorów w dzienniku i pomiaru); wdrażanie od E0, nic
jeszcze nie wdrożono. Stan odniesienia: `c9334c1`, wersja 0.33 (plan v10
wykonany). Docelowa wersja wydania: 0.34. Kontrakty planu v10 i kontrakty
trafień planu v7 pozostają wymaganiami.

## Cel

Domknąć bazę przed rozbudową świata i zawartości. Dodanie broni,
umiejętności, demona albo trybu ma wymagać definicji i najwyżej lokalnego
wykonawcy, bez przebudowy niezwiązanych systemów. Nie chodzi
o obiektowość dla niej samej ani o opisanie każdego przyszłego zachowania
danymi. Chodzi o jasne odpowiedzialności, własność stanu, stabilne kontrakty
i sprawdzone w praktyce rozszerzenia.

Produkcja się nie zmienia: jeden poligon, obecny gameplay, oprawa, menu
i HUD 0.30, dwie bronie, jeden gracz. Nowe możliwości dowodzą próby
w testach i poza menu. Plan nie dodaje funkcji produktu (split-screen,
nowy tryb w menu, sieć).

## Luki potwierdzone w kodzie 0.33

Wersja 1 planu miała trzy luki. Przegląd źródeł pokazał, że dwie z nich
są głębsze: stan aktora, a nie tylko prezentacja, oraz geometria trafień
zależna od widza. Stąd pięć luk; każda ma swój etap.

| Luka | Dowód w kodzie 0.33 | Etap |
|---|---|---|
| C1 | **Pozy i reguła zwłok.** `enemies/animation.lua` wybiera klatki po numerach dwóch układów (ok. 40 stałych typu `imp and 14 or 10`; `imp` oznacza układ 6×4). Pozy liczą się w czterech różnych jednostkach: znormalizowana faza akcji (zamach, cios, powrót przez `ActionPhase`), sekundy stanu (ból `e.phase < 0.12`, powalenie, zwłoki), droga chodu (`e.walk` w metrach × 4,2 lub 3,4) i czas świata (spoczynek `Idle.sample`, lot `g.time * 7`). Tego nigdzie nie nazwano. Z animacji liczą się trafienia (`Pose.sample` → `Surface.prepare` → strzał) i wysokość oczu demona (`Pose.anchor` w `combat/rules/body.lua`), więc pozy są częścią symulacji. `Corpse.settled` (`enemies/corpse.lua`) liczy czas osiadania z długości malowanego upadku (`(last - first) × frame` z `combat_defaults.corpse`: 6×4 → 0,44 s, 4×4 → 0,33 s), a `Corpse.shields` z tego decyduje, czy zwłoki zatrzymują strzały. Dodanie klatek upadku zmieniłoby czas osłaniania. `Corpse.contactTime` i `enemies/body.lua` biorą moment uderzenia o podłogę z układu (`Anim.extended`). Animacje umiejętności mają własny, poprawny mechanizm (`AbilityPose.register`, progi w `content/ability_art.timing`) | E1 |
| C2 | **Własność stanu trybów.** Na sesji leżą pola, które nie należą tylko do classic, co sprawdzono w źródłach: `score`, `secretFound` i `kills` zapisuje checkpoint wyprawy (`run/descent.lua` 128–133, 173), `seals` wyprawa odtwarza z numeru fali, `bossSpawned`/`bossDead` piszą wyprawa, poligon, `session/encounter.lua` i classic. `rank` i `bestScore` liczy classic (`session/interactions.lua`, plik `best-score-v03.txt`). Czytają je ekrany, HUD, mapa, `render/world_art.lua` i `audio/soundscape.lua`. Mechanizmy stanu trybu są już trzy: `g.run` (wyprawa), `g.testField` (poligon) i `g.modeData` (tryby rejestrowane, dziś tylko w testach). Widoki (`run/mode_views.lua`) zwracają moduło-globalne tabele nadpisywane przy każdym wywołaniu, więc dwie sesje albo dwa zachowane wyniki przenikają się | E2 |
| C3 | **Stan aktora na sesji.** Broń w ręku, cooldown, przeładowanie (`weapon`, `cooldown`, `reload*`), bufor spustu (`fireBuffer`, `fireCommand`), statystyki (`shots`, `hits`, `kills`, `score`, `combo`, `damageTaken`) są polami sesji: 135 odwołań w 22 plikach. Arsenał należy do rycerza, ale wybór slotu do sesji (`W.idAt(g)` czyta `g.weapon`). Ruch (`Feel.update`) i spust (`Intent.fire`) działają na jednym wejściu i sterowanym rycerzu; tylko regeneracja iteruje pulę `knights`. Zdarzenia nie niosą wykonawcy (`ShotFired`, `VolleyResolved`, `EnemyKilled`, `AbilityCast`, `ReloadStage`). Licznik `g.shotSerial` jest jeden na sesję, a decyduje o wyniku strzału: parzystość odwraca wzór rozrzutu (`B.pellet`), a ziarna kontaktów to `shotSerial * 31 + i` i `* 31 + e.id` (`combat/combat.lua`). Strzał jednego aktora zmieniłby więc rozrzut drugiego. `breakKill` (`session/listeners.lua`) leczy sterowanego rycerza przy każdym zabójstwie wytrąconego z równowagi demona, bez względu na źródło. Źródłami są `weapon`, `charge`, `ability`, `effect:<id>`, `slam`, `collision` i `creature`. Ładunki nie mają właściciela, pociski mają `owner` (id demona), a efekty okresowe mają `effectSource` { side, id } | E3 |
| C4 | **Geometria trafień zależy od widza.** `Pose.sample`/`Pose.anchor` (`enemies/pose.lua`) obracają billboard do `Roles.viewer(g)`, a `Animation.pose` wybiera klatki tyłem względem widza. Z tego korzystają strzał, pocisk w locie (`combat/ballistics.lua` 339) i wysokość oczu demona. Obserwacja strzału (`combat/observation.lua`) to jedna ostatnio narysowana próbka na wejście (`app/input.lua`, `Input:present`), bez strzelca i widoku. Punkt wystrzału pochodzi z tej próbki (`origin = B.origin(shown)`), a kierunek i korytarz z bieżącego sterowanego w chwili komendy. Strzał bez obserwacji bierze oba z bieżącego stanu. Krótkie naciśnięcie zachowuje dokładną obserwację i celowanie (`fireCommand`); przytrzymany spust podąża za najnowszą (`player/intent.lua`). Wiek obserwacji: najwyżej `Tuning.observation.maxAge` = 0,32 s. Generacja obserwacji należy do sesji (`O.invalidate`). Ustawienie `g.viewer` (kamera widza) zmieniłoby dziś symulację | E4 |
| C5 | **Kontekst prezentacji.** `g.view` to jeden rekord mieszający efekty świata (cząstki, plamy, ślady, liczby obrażeń) z osobistymi (odrzut, błysk zranienia, kierunek ciosu, ruch broni, a nawet kamera pisana przez `player/feel.lua`). `render/presentation.lua` interpoluje tylko `g.player`. Kamera, słuchacz, HUD, ręce i portret czytają `g.player` (58 odwołań w 26 plikach prezentacji) | E5 |

## Zasady wykonania (każdy etap)

- **Zachowanie gry.** Rozgrywka, balans, wygląd i zapisy bez zmian.
  - Złoty wzorzec v2 (playtest `07f73bfa/a9192235`, human
    `fe26df14/563c8d0f`, drill `c13bcaec/f105ca06`, kontakty
    `aab9a46e/299`, `4be34edb/671`, `663b77fc/178`) daje te same liczby
    szesnastkowe.
  - `qa/golden.lua` wolno zmienić tylko tak, by czytał przeniesione pole
    z nowego miejsca. Skrót musi wtedy wyjść identyczny.
  - Wygenerowanie nowego skrótu nie jest dowodem równoważności.
- **Rzut stanu.** Rzut stanu obserwowalnego z E0 (pkt E0) zgadza się
  z referencją 0.33 zapisaną przed zmianami. Tej referencji nie wolno
  generować ponownie. Porównanie obejmuje próbki okresowe i rzuty przy
  zdarzeniach (E0), bo próbka co 0,25 s przepuściłaby krótki błąd.
- **Rendery** showcase i audytu GUI są identyczne piksel w piksel z bazą
  0.33.
- **Bramki.** `FORMAT.ps1 -Check`, `TEST.ps1 -Suite All`, 0 naruszeń
  architektury. Zapadki v10 i liczb nie rosną.
- **Zapadki są pomocnicze.** Liczą wskaźnik w tekście kodu, więc
  zastąpienie `g.player` przez `Roles.controlled` ich nie oszuka, ale też
  nie dowodzi usunięcia założenia. Etap zamyka próba rozszerzenia
  i warunek mierzalny, nie zero w zapadce.
- **Każdy etap ma:**
  - problem z dowodem w kodzie,
  - docelowy kontrakt i właściciela stanu,
  - zakres migracji i zależności,
  - test pozytywny i negatywny,
  - próbę rozszerzenia,
  - ochronę obecnej rozgrywki i wyglądu,
  - mierzalny warunek zakończenia.
- **Koszt — protokół pomiaru.** Jeden protokół dla każdego etapu i odbioru
  końcowego:
  - ten sam profil i warunki: build, wersja LÖVE, scenariusz `qa_crowd`
    20/96/256 ciał i scena poligonu, rozdzielczość, zasilanie sieciowe,
    brak innych procesów QA (blokada `Enter-QaSession`);
  - co najmniej 5 niezależnych pomiarów **każdego** wariantu: 5 par
    „przed”/„po”, każdy pomiar w osobnym procesie z własną rozgrzewką
    (300 kroków, wyniki odrzucone); w parach kolejność się zmienia
    (przed-po, po-przed, …), żeby nagrzanie maszyny nie sprzyjało jednemu
    wariantowi;
  - wynik: mediana i rozrzut międzykwartylowy (IQR) liczone osobno dla
    „przed” i „po”, osobno krok symulacji (`--core-measure`) i klatka
    renderowania (`--benchmark`);
  - trzy możliwe wyniki porównania:
    - **brak regresji**: mediana „po” ≤ 1,05 × mediana „przed”, a IQR
      każdego wariantu ≤ 5% jego mediany;
    - **regresja**: mediana „po” > 1,05 × mediana „przed” i różnica median
      większa niż suma obu IQR;
    - **nierozstrzygnięty**: każdy inny przypadek, m.in. duży rozrzut.
      Taki wynik nie zalicza braku regresji. Pomiar powtarza się (kolejne
      5 par, wyniki łącznie). Jeśli dalej jest nierozstrzygnięty, traktuje
      się go jak regresję;
  - pojedynczy pomiar nigdy nie rozstrzyga;
  - stwierdzona albo nierozstrzygnięta regresja jednego gracza blokuje
    zamknięcie etapu, chyba że jest udokumentowana (przyczyna, koszt, zysk,
    pomiary) i zaakceptowana przez użytkownika. To jedna zasada dla etapów
    i odbioru końcowego.
- **Bez obejść.** Nie podmieniamy chwilowo globalnych `g.player`/`g.view`,
  żeby udać wielu aktorów. Nie zdejmujemy zabezpieczeń wersji dziennika
  i zapisu.
- **B2.** Odbiór B2 (gracz w normalnej grze) jest zawsze osobny.

## Zgodność zapisów i dzienników (obowiązuje każdy etap)

Rozróżniamy dwie rzeczy:

**A. Zapisy gracza.** Te pliki istnieją naprawdę i mają się wczytać:
- SIGIL06/07/08 przez adapter (`storage/run_save.lua`; fixture 0.32
  w `tests/support/legacy_save.lua`),
- SIGIL09 z 0.33.

E0 utrwala prawdziwe pliki SIGIL09 wygenerowane przez 0.33 jako fixture
(checkpoint w przygotowaniu, po porażce, po zwycięstwie, z echem
i grawerem). Gdy etap przenosi pole w pamięci, format pliku zostaje. Zmienia
się tylko `pack`/`unpack` sekcji. Zmiana struktury sekcji podnosi jej
`version` i dodaje migrację (`Save.declare.migrations`).

Dowód: każdy fixture wczytany po zmianie daje ten sam rzut stanu co
wczytany w 0.33, a ponowny zapis i odczyt są zgodne.

**B. Dzienniki.** Dzisiejsza zasada w kodzie: `Journal.replay` odrzuca
nagranie z innego wydania (`header.build`) i innego źródła
(`sourceFingerprint`). Formaty v2–v4 odtwarzają się tylko w tym samym
wydaniu: testy nagrywają w starszym formacie i od razu odtwarzają.

Plan tego nie zmienia:
- nagrania z 0.33 nie muszą odtwarzać się w 0.34 i nadal są odrzucane;
- zgodność formatu v2–v4 i nowego v5 (E3) obowiązuje w obrębie wydania;
- odtwarzanie nagrań między wydaniami wymaga osobnej decyzji (migracja
  stanu początkowego i poleceń) i nie wchodzi do v11.

**Początek nagrania i aktorzy w dzienniku (v5).** Dziś w kodzie:
- `Journal.session` buduje świeżą sesję przez `Game.new(mode, map)`;
- `header.initial` to spłaszczony opis `Integrity.capture`, którym
  `Journal.replay` sprawdza, czy sesja docelowa zgadza się ze stanem
  początkowym;
- `header.origin` sprawdza punkt startu (czas, zabójstwa, id, pozycja).

Opis Integrity nie odtwarza aktorów, tylko sprawdza zgodność. Plan to
rozdziela i nie buduje drugiego systemu serializacji:
- **Konstrukcja.** Sesję początkową buduje wyłącznie `Game.new(mode, map)`,
  jak dziś. Obsługiwany początek nagrania to chwila konstrukcji
  sesji (z deterministycznym `prepare` trybu).
  - Ograniczenie nazwane: nagranie rozpoczęte później (np. powrót do
    wstrzymanej wyprawy) nie jest obsługiwane.
  - Walidacja zostaje: `header.initial` i `header.origin` odrzucają
    odtworzenie w sesji o innym stanie, jak dziś.
- **Dodatkowi aktorzy**, także „początkowi” w próbie, wchodzą poleceniem
  `actorJoin` zapisanym w dzienniku przed pierwszą aktualizacją albo
  w trakcie nagrania.
  - `actorJoin` niesie pełny rekord rycerza w formacie członka puli
    z sekcji zapisu `pools` (`session/world.lua`, `core/data_tree.lua`):
    komponenty, położenie, poziom i kierunek, wyposażenie i arsenał
    (magazynki, zapasy), zdrowie i osłonę, stronę, a po E3 także stan
    aktora (broń w ręku, przeładowanie, licznik sekwencji strzałów,
    statystyki).
  - To ten sam koder, którym zapis sesji pakuje i rozpakowuje rycerzy;
    nie powstaje osobny format.
  - Samo id i nazwa prefabu nie wystarczają, bo położenie i wyposażenie
    nie wynikają z kontraktu.
  - Walidacja jak przy wczytaniu sekcji `pools`: dekoder `data_tree`,
    zadeklarowane komponenty prefabu, istniejące definicje, id nieużyte
    w sesji.
- **Wyjście i sterowanie.** `actorLeave` (id) usuwa aktora z puli.
  `actorControl` (id) zmienia sterowanego (E3e); jest poleceniem
  dziennika, bo zmienia stan.
- **Integrity** zostaje narzędziem zgodności: stan początkowy po
  konstrukcji (`header.initial`) i końcowy (`journal.final`).

**Identyfikatory w preflight.** Preflight przechodzi wpisy w kolejności
i buduje tabelę id:
- znane od konstrukcji: lista id rycerzy w nagłówku v5 (`header.actors`),
  porównywana z sesją po `Game.new` razem z `header.initial`; albo
  znane od swojego `actorJoin`;
- usunięte od swojego `actorLeave`.

Walidacja nie jest wyłączana; nie zależy od przygotowania sesji poza
konstrukcją. Zasady:
- id złego typu albo nigdy nieznane: dziennik odrzucony w preflight,
  przed mutacją sesji;
- polecenie dla id przed jego `actorJoin` albo po `actorLeave`: dziennik
  odrzucony w preflight. Gra nie mogła go wydać, więc to uszkodzenie
  albo sfałszowanie;
- `actorJoin` z id już użytym albo z rekordem, który nie przechodzi
  walidacji: dziennik odrzucony w preflight;
- polecenie dla aktora znanego i obecnego, ale martwego: wykonywane jako
  deterministyczny brak efektu, tak samo przy nagraniu i odtworzeniu.
  Martwy aktor zostaje w puli, dopóki nie przyjdzie `actorLeave`.

Polecenia v4 i starszych należą do sterowanego aktora z nagłówka; te
formaty nie mają `actorJoin`, `actorLeave` ani `actorControl`.

**Równoważność przed i po refaktorze.** `Integrity.capture` spłaszcza całą
sesję, więc przeniesienie pola zmienia jego ścieżkę. Integrity zostaje
narzędziem porównania nagrania z odtworzeniem w obrębie jednego wydania.
Równoważność między wydaniami dowodzi rzut stanu z E0, nazwany i niezależny
od miejsca pól.

## Etapy i warunki odbioru

### E0 — stan odniesienia, rzut stanu, fixture, zapadki

**Do zrobienia:**
- Utrwalić 0.33:
  - skróty,
  - bazę renderów `work/v11-render-base`,
  - pomiar według protokołu z Zasad (`--core-measure` i `--benchmark`,
    20/96/256 ciał i scena poligonu, 5 niezależnych pomiarów na
    wariant, mediana i IQR osobno dla każdego wariantu).
- **Rzut stanu obserwowalnego** (`qa/state_projection.lua`, nazwy zamiast
  ścieżek pól):
  - na aktora: pozycja, hp, osłona, broń w ręku, magazynki i zapasy, etap
    przeładowania, cooldown, statystyki;
  - na tryb: faza, fala, sakiewka, wynik, pieczęcie, strażnik, sekret;
  - na świat: ciała w kolejności id z hp i pozycją.
- Rzut liczony co 30 kroków w trzech scenariuszach złotego wzorca
  i w próbach 0.33 (poligon, wyprawa z zapisem i wczytaniem). Zapisany jako
  referencja 0.33.
- **Rzut przy zdarzeniach**, w tych samych przebiegach, tylko w zakresie
  zdarzenia (bez kopii całej pamięci po każdym kroku):
  - wykonanie strzału: strzelec (pozycja, kierunek, broń, magazynek,
    cooldown, licznik sekwencji strzału) i kontakty salwy (cel, strefa,
    obrażenia, ziarno);
  - przeniesienie amunicji przy przeładowaniu i przerwanie przeładowania:
    magazynek, zapas, etap, czas;
  - śmierć: ciało (id, hp, przyczyna, źródło), zabójca i jego statystyki,
    leczenie, nagroda;
  - zmiana sterowania (od E3): obaj aktorzy i ważność obserwacji;
  - zapis i odczyt: pełny rzut przed zapisem i po odczycie.
  - Skrót każdego rzutu zdarzenia trafia do referencji. Pierwsza różnica
    wskazuje krok, zdarzenie i pole.
- **Referencja przypisania leczenia i nagród.** Dla każdego zabójstwa
  w przebiegach: źródło (`weapon`, `charge`, `ability`, `effect:<id>`,
  `slam`, `collision`, `creature`), czy było `offBalance`, ile wyleczono
  i ile dusz przyznano. To wzorzec dla reguły łańcucha z E3d.
- **Tabela pozy klatki.** Dla każdego stworzenia na siatce:
  - stan AI × faza × przód/tył × ruch × czas,
  - punkty tuż przed każdą granicą, dokładnie na niej i tuż za nią
    (±1e-9 w jednostce granicy).
  - Wynik ze starego kodu, zapisany jako referencja.
- **Fixture zapisów** SIGIL09 z 0.33 (pkt Zgodność A).
- **Inwentarz `g.view`.** Każde pole widoku (18 grup deklaracji
  w `session/fields.lua`) z właścicielem: świat, aktor albo widz. Dla
  każdego zasięg i reset (zmiana sterowanego, śmierć, reset sesji).
- **Pomiar wpływu widza na symulację.** Liczba zapytań symulacji
  (strzał, pocisk, wzrok demona), które w trzech scenariuszach wybrały
  klatkę tyłem albo użyły obrotu do widza.
- **Zapadki pomocnicze** (`tools/check/`, mogą tylko maleć):
  - `FRAME NUMBERS OUTSIDE SHEETS`: numery klatek w wyborze pozy
    w `src/enemies/` i odczyty `appearance.layout`;
  - `MODE STATE ON THE SESSION`: `seals`, `secretFound`, `rank`,
    `bestScore`, `bossSpawned`, `bossDead` na sesji poza właścicielem;
  - `ACTOR STATE ON THE SESSION`: `weapon`, `cooldown`, `reload*`,
    `fireBuffer`, `fireCommand`, `shots`, `hits`, `kills`, `score`,
    `combo`, `comboTimer`, `damageTaken` na sesji (dziś 135 w 22 plikach);
  - `VIEWER IN SIMULATION`: `Roles.viewer` w kodzie symulacji (dziś
    `enemies/pose.lua`, `animation.lua`, `geometry.lua`);
  - `PRESENTATION ASSUMES ONE PLAYER`: `g.player` i `Roles.controlled`
    w prezentacji poza modułem kontekstu widoku.

**Odbiór:**
- referencje w repozytorium (`tests/fixtures/v033/`): rzut okresowy
  i przy zdarzeniach, tabela pozy klatki, przypisanie leczenia i nagród,
  fixture zapisów;
- raport wpływu widza;
- pomiar bazowy z rozrzutem;
- wartości zapadek z listą plików.
- Warunek końca: referencje odtwarzają się dwukrotnie z tym samym
  wynikiem (deterministyczne) i są zapisane, zanim powstanie pierwsza
  zmiana kodu E1.

### E1 — nazwane pozy i reguła zwłok (C1)

**Kontrakt.** Arkusz atlasu (`content/art/sheets/<id>.lua`) dostaje
`poses`: nazwa → `{ clock, frames, bounds }`.
- Zegar pozy jest jawny:
  - `action`: znormalizowana faza akcji 0..1 z `ActionPhase`;
  - `seconds`: czas od początku stanu;
  - `stride`: droga chodu w metrach × tempo kroku;
  - `world`: czas świata.
- `bounds` to granice przedziałów półotwartych `[a, b)`. Wartość równa
  granicy należy do następnej klatki, jak dziś przy `<`.
- Pozy w użyciu: `walk`, `walkRear`, `watchRear`, `quiet`, `windup`,
  `strike` (z wariantami ataku zamiast `strikeFrames`), `recover`, `pain`,
  `painHeavy`, `knockdown`, `collapse`, `hover`.
- Animacja, zwłoki i ciało pytają o pozę po nazwie.
- `appearance.layout` znika. Dzisiejsze układy 6×4 i 4×4 stają się
  szablonami danych narzędzia arkusza (`EXPORT-SHEET.ps1 -Spec`).

**Walidacja przy rejestracji arkusza** (`Sheet.problems`):
- granice ściśle rosnące, w dziedzinie zegara (`action` ≤ 1);
- liczba klatek = liczba przedziałów;
- klatki istnieją w arkuszu;
- brak pustych sekwencji;
- zastępniki (`painHeavy` → `pain`, `walkRear` → `walk`) wskazują
  istniejące pozy, bez cykli (wykrywanie DFS);
- każda wymagana poza istnieje albo ma łańcuch zastępników zakończony
  istniejącą pozą.

**Spójność z walką.** Każda klatka, której używa jakakolwiek poza, ma
kotwicę głowy, klatkę anatomii i upieczoną maskę. Sprawdzają to
`CHECK-CREATURE.ps1` i test arkusza.

**Reguła zwłok.** Symulacja dostaje własne liczby, a obraz zostaje obrazem:
- `body.corpse.settle` (s): najkrótszy czas osiadania, w miejsce długości
  upadku. Zastępuje tylko zależność od animacji. Warunek zakończenia lotu
  zostaje bez zmian: zwłoki osiadły dopiero, gdy minął `settle`
  **i** ciało leży (`fallY <= 0`, `fallVY <= 0`, jak dziś
  w `Corpse.settled`). Sam upływ czasu nie oznacza osiadania podrzuconego
  ciała;
- `body.corpse.landing` (s): moment uderzenia o podłogę, w miejsce
  `Corpse.contactTime(extended)`.
- Wartości przechodzą 1:1:
  - 6×4: osiadanie 0,44 s, uderzenie 0,22 s;
  - 4×4: osiadanie 0,33 s, uderzenie 0,14 s.
- Poza `collapse` decyduje tylko o tym, która klatka jest narysowana
  i spotyka strzał w trakcie upadku (obecna zasada „klatki upadku leżą
  tam, gdzie są narysowane”). O długości osłony nie decyduje.

**Umiejętności.** Mechanizm `AbilityPose.register` i progi
`content/ability_art.timing` zostają jedynym systemem animacji umiejętności.
E1 stosuje do nich tylko ten sam walidator (progi, klatki). Nie tworzy
drugiego mechanizmu.

**Widz w wyborze klatek tyłem.** Do E4 zostaje bez zmian (`Roles.viewer`).
Jego źródło zmienia E4.

**Odbiór:**
- tabela pozy klatki z E0 identyczna, łącznie z punktami na granicach;
  złoty wzorzec, rzut stanu i rendery bez zmian;
- test negatywny: arkusz z nierosnącą granicą, klatką spoza arkusza, pustą
  sekwencją, cyklem zastępników lub brakiem wymaganej pozy jest odrzucony
  z nazwą błędu przed rejestracją;
- próba przestawienia: arkusz testowy z odwróconą kolejnością klatek
  (z poprawionymi pozami, anatomią i maskami) daje w scenariuszu ten sam
  rzut stanu i te same kontakty;
- próba zwłok:
  - dodanie dwóch klatek do `collapse` stworzenia testowego nie zmienia
    czasu osłaniania ani momentu uderzenia;
  - zwłoki podrzucone tak, że są w powietrzu po upływie `settle`,
    nadal osłaniają (dzisiejsza reguła); lądowanie kończy osłonę
    w kroku, w którym jest spełniony warunek leżenia. Wynik jest ten sam
    z dodatkowymi klatkami `collapse` i bez nich;
- próba rozszerzenia: demon o nowym układzie, dodany samymi danymi
  i narzędziami:
  - 3 klatki chodu, bez tyłu (zastępnik), osobna poza ciężkiego bólu,
    4 fazy zamachu;
  - animuje się, CHECK-CREATURE jest kompletny;
  - strzał trafia w malowaną część każdej używanej pozy.
- Warunek końca: zapadka `FRAME NUMBERS OUTSIDE SHEETS` = 0 i wszystkie
  próby zielone.

### E2 — własność stanu trybów i kontrakt widoków (C2)

**Tabela własności** (z kodu 0.33; „etap” mówi, kto przenosi):

| Pole | Właściciel docelowy | Zapisują dziś | Czytają dziś | Zapis / odtworzenie | Reset | Etap |
|---|---|---|---|---|---|---|
| `bossSpawned`, `bossDead` | strażnik spotkania: rekord `session/encounter.lua`, wspólny dla trybów, zmieniany tylko jego API | descent, spawner, test_field, encounter, interactions | soundscape, world_art, mode_views, HUD (oba), mapa, descent | wyprawa: odtwarzane z fazy (`won` → poległ) | `state.lua`, encounter, test_field, descent | E2 |
| `secretFound` | świat mapy (sekret odkryty), pytany przez widok świata | interactions | world_art, descent, test_field | sekcja `run` checkpointu (`secret`), format bez zmian | `state.lua`, test_field | E2 |
| `seals` | wyliczane ze świata (`world.seals[i].active`), bez osobnego licznika | descent, interactions | mode_views, ending, test_field, descent | wyprawa: odtwarzane z fali | `state.lua`, test_field | E2 |
| `rank`, `bestScore` | rekord classic w `g.modeData` | interactions | ending | `bestScore` w `best-score-v03.txt` (poza testami), bez zmian | `state.lua` | E2 |
| `score`, `kills`, `damageTaken`, `combo`, `comboTimer` | statystyki aktora (E3); sesja i tryb dostają sumę przez zapytanie | listeners, descent, interactions | ending, descent, test_field, session_report, telemetria, HUD | sekcja `run` (`score`, `kills`, `damage`), format bez zmian | `state.lua`, test_field, descent | E3 |

**Mechanizm stanu trybu.** Wybór pada na `g.modeData`, istniejący
i opisany (`run/modes.lua`), z zapisem i odtworzeniem w mementach
(test `mode-lifecycle`). Classic i każdy nowy tryb trzymają w nim stan
prywatny. Nie powstaje nowy mechanizm.
- `g.run` (wyprawa) i `g.testField` (poligon) to dziś rekordy tego samego
  rodzaju: deklarowane pola sesji, którymi rządzi tryb, zamknięte
  zapadką `mode-records` = 0.
- Przeniesienie ich pod `modeData` zmieniłoby 114 odwołań w kodzie
  i ok. 760 w testach i QA bez zysku architektonicznego. E2 nie zmienia
  więc nazw, ale ujednolica obsługę: snapshot, reset, zapis i odczyt
  wszystkich trzech rekordów idą przez te same haki `Modes`.

**Kontrakt widoków** (`run/queries`, `run/mode_views.lua`):
- Właściciel: widok należy do sesji. Pamięć podręczna jest na sesję
  (słabo trzymana tabela kluczowana sesją), nie moduło-globalna.
- Ważność: do następnego kroku symulacji albo polecenia tej sesji.
  Kolejne wywołanie w tym samym kroku zwraca ten sam obiekt.
- Zachowanie: widoku nie wolno trzymać dłużej niż przez klatkę.
  Do zachowania służy `Queries.copy(view)` (kopia, nie współdzielona).
- Kilka widoków i sesji: zapytanie dostaje sesję i, gdzie to potrzebne,
  aktora (HUD aktora). Dwie sesje nigdy nie dzielą tabeli wynikowej.
- Klasyczne pola czytane dziś wprost (strażnik, sekret, pieczęcie) idą do
  widoku świata i celu. `render/world_art.lua` (wyjście, sekret)
  i `audio/soundscape.lua` czytają widok.
- Logika areny classic z `session/interactions.lua` przechodzi do trybu
  classic (`run/classic.lua`). Interakcje ogólne (zapasy) zostają.

**Odbiór:**
- zapadka `MODE STATE ON THE SESSION` = 0 poza właścicielami z tabeli;
- złoty wzorzec (classic, czyta `g.score`: po E3 przez zapytanie, z tym
  samym skrótem), rzut stanu, fixture zapisów i rendery bez zmian;
- test przeplatania: widoki dwóch sesji (wyprawa i classic, potem dwie
  wyprawy) czytane na przemian zachowują swoje wartości. Widok trzymany
  przez następny krok jest wykrywany jako nieważny (test negatywny);
- próba rozszerzenia, pełny cykl trybu „ołtarze” (test, nie menu):
  - uruchomienie; postęp (zniszcz 3 ołtarze, obiekt świata przez
    `WorldObjects.register`);
  - zapis własnej sekcji (`Save.declare`) i odtworzenie z pliku;
  - zakończenie; ponowne uruchomienie od czystego stanu;
  - odtworzenie dziennika;
  - stan tylko w `modeData`, cel w HUD i znaczniki mapy przez widoki;
    bez nowych pól sesji i bez gałęzi w ekranach.
- Warunek końca: tabela zrealizowana dla wierszy E2, próby zielone.

### E3 — niezależny stan aktora (C3)

Aktor to rycerz w puli `knights`. Stan aktora należy do jego rekordu.
Sesja trzyma tylko stan świata i trybu. Pięć podetapów, każdy z osobnym
commitem i testem:

- **E3a — broń, przeładowanie, intencja.**
  - Do rekordu aktora przechodzą: slot w ręku, cooldown,
    `reload`/`reloadWeapon`/`reloadStage`/`reloadDuration`/`reloadOffset`,
    `fireBuffer`/`fireCommand`, `shots`/`hits`.
  - Moduły pytają aktora: `content/weapons.lua` (`idAt`/`inHand`/`state`),
    `combat/combat.lua`, `combat/reload.lua`, `player/intent.lua`.
  - Licznik strzału rozdziela się na dwa:
    - **id strzału** świata: rośnie przy każdym strzale dowolnego aktora;
      używany w dzienniku, zdarzeniach i obserwacjach
      (`report.shotSerial`, `ObservationUsed`);
    - **licznik sekwencji aktora**: rośnie przy strzale tego aktora;
      wybiera orientację rozrzutu (`B.pellet`) i ziarna kontaktów
      (`* 31 + i`, `* 31 + e.id`).
    - Dla jednego gracza oba liczniki są równe dzisiejszemu `shotSerial`
      w każdym strzale, więc rozrzut, ziarna i skrót zostają.
    - Licznik aktora jest częścią jego rekordu: zapis i odczyt idą przez
      memento i sekcję zapisu, reset przy resecie aktora (dziś
      `player/feel.lua` zeruje `shotSerial`).
  - Hit-stop świata (`impactSlow`, `worldStop`) zostaje w świecie.
- **E3b — ruch i polecenia w jednym kroku.**
  - `systems/knight` (ruch, kontakt, spust, przeładowanie) iteruje
    aktorów w kolejności id.
  - Każdy aktor ma swoją intencję z kontrolera (wejście, dziennik, bot).
  - `Game:look/shoot/reloadGun/switchWeapon/cast/dash/interact` przyjmują
    aktora (domyślnie sterowany).
  - Dziennik v5 zapisuje id aktora (pkt Zgodność B).
- **E3c — wykonawca i cel w zdarzeniach.**
  - `ShotFired`, `VolleyResolved`, `BlowResolved`, `BodyHit`,
    `EnemyKilled`, `AbilityCast`, `ReloadStage`, `ChargeExploded` niosą
    id wykonawcy i celu.
  - `PlayerHit` zostaje dla sterowanego (prezentacja). Każde zdarzenie
    rycerza niesie jego id.
- **E3d — łańcuch obrażeń i własność skutków.**
  - Każdy cios niesie trzy rzeczy:
    - **właściciela**: aktor, który zapoczątkował łańcuch, czyli id ciała
      i jego strona;
    - **bezpośrednie źródło**: broń, ładunek, pocisk, efekt okresowy,
      zderzenie, zagrożenie;
    - **cel**.
  - Sam napis źródła (`'charge'`) nie wyznacza beneficjenta.
  - Właściciel jest przenoszony przez cały łańcuch:
    - ładunek dostaje właściciela przy rzucie, dziś go nie ma;
    - pocisk ma już `owner`;
    - efekt okresowy ma już `effectSource`;
    - wybuch dziedziczy po ładunku;
    - uderzenie o ścianę (`slam`) i zderzenie ciał (`collision`) dostają
      właściciela impulsu, który je wywołał (ciało zapamiętuje
      właściciela ostatniego ciosu z pchnięciem do końca tego pchnięcia);
    - cios odbity idealnym unikiem należy do unikającego rycerza.
  - Statystyki (`kills`, `score`, `combo`, `damageTaken`, telemetria) na
    aktora-właściciela. Sesja i tryb liczą sumy przez zapytanie.
  - Nagroda trybu (dusze wyprawy) idzie do sakiewki trybu z odnotowanym
    właścicielem.
  - Leczenie `breakKill` dostaje właściciel łańcucha, jeśli jest rycerzem.
    Nigdy „ten, kto akurat jest sterowany”.
  - Po śmierci albo usunięciu właściciela:
    - statystyka i nagroda trybu zostają przypisane jego id (rekord
      zostaje w statystykach sesji);
    - leczenie nie trafia do nikogo, bo martwego się nie leczy,
      a usuniętego nie ma.
  - **Zgodność jednoosobowa.** Dziś `breakKill` leczy sterowanego przy
    każdym źródle. W grze jednoosobowej właścicielem każdego łańcucha,
    który zabija demona, jest ten jedyny rycerz: broń, ładunek, efekty,
    zderzenia po jego ciosie, unik. Wyjątek: demon zabity bez udziału
    rycerza, np. zderzeniem z innym demonem, którego żaden cios rycerza
    nie pchnął.
    - Referencja E0 pokazuje, czy takie przypadki istnieją w przebiegach.
    - Jeśli tak, nowa reguła zmienia leczenie i jest to zmiana balansu.
      Etap staje i przedstawia ją do decyzji, zamiast ukrywać ją pod
      refaktorem. Domyślnie zachowujemy dzisiejszy wynik: łańcuch bez
      właściciela w grze jednoosobowej leczy jedynego rycerza.
  - Efekty i stany już należą do ciała, bez zmian.
- **E3e — zmiana sterowanego, śmierć, usunięcie.**
  - `Roles.control` przełącza sterowanie; w dzienniku to polecenie
    `actorControl`. Zakres unieważnienia opisuje E4.
  - Bufor spustu (`fireBuffer`, `fireCommand`) aktora, który traci
    sterowanie, jest czyszczony.
  - Śmierć sterowanego kończy walkę tak jak dziś; o tym decyduje tryb.
    Śmierć innego to `KnightFell`, bez zmian w drugim.
  - Martwy aktor zostaje w puli. Jego polecenia nie mają efektu (pkt
    Zgodność B).
  - Usunięcie z puli to `actorLeave` (zapisany w dzienniku). Później jego
    id nie przyjmuje poleceń.
  - Pociski, ładunki i efekty aktora żyją dalej z jego id jako
    właścicielem (E3d; geometria pocisku: E4).

**Odbiór:**
- zapadka `ACTOR STATE ON THE SESSION` = 0;
- złoty wzorzec, rzut stanu, fixture zapisów i rendery bez zmian
  (jeden aktor);
- testy negatywne:
  - polecenie dla nieistniejącego id odrzucone;
  - polecenie dla martwego bez efektu;
  - zmiana broni A nie zmienia slotu B.
- próba dwóch aktorów (cele z `hit = 'volumes'`, niezależne od widza,
  do czasu E4), sprawdzana po każdym kroku na rzucie obu aktorów:
  - A przeładowuje strzelbę, B strzela rewolwerem, obaj się poruszają;
  - przerwanie przeładowania A spustem;
  - zmiana broni B;
  - śmierć B;
  - dziennik v5 odtwarza całość bit w bit.
- test dziennika aktorów (pkt Zgodność B):
  - nagranie z dwoma aktorami o różnych pozycjach i wyposażeniu (drugi
    wchodzi przez `actorJoin` przed pierwszą aktualizacją);
  - zapis dziennika do tekstu (`Journal.encode`) i odczyt
    (`Journal.decode`);
  - odtworzenie w świeżej sesji z `Journal.session`, bez ręcznego
    tworzenia drugiego aktora przez test;
  - zgodność stanu początkowego (`header.initial`) i końcowego
    (`journal.final`);
  - wariant z dołączeniem i odejściem aktora w trakcie nagrania oraz ze
    zmianą sterowanego (`actorJoin`, `actorLeave`, `actorControl`);
  - testy negatywne: polecenie przed `actorJoin` albo po `actorLeave`,
    `actorJoin` z użytym id i z niepoprawnym rekordem są odrzucane
    w preflight bez mutacji sesji.
- test licznika strzałów: przy tych samych warunkach dodatkowe strzały B
  między strzałami A nie zmieniają orientacji rozrzutu ani ziaren
  kolejnych strzałów A. Licznik A po zapisie, odczycie i resecie jest
  zgodny z oczekiwanym;
- test łańcucha:
  - A rzuca ładunek, zmienia broń, ładunek zabija wytrąconego z równowagi
    demona: zabójstwo, wynik, leczenie i nagroda należą do A, a nie do
    sterowanego B;
  - wariant: A ginie przed wybuchem, statystyka i nagroda dla id A, bez
    leczenia;
  - wariant: A usunięty przed wybuchem, to samo;
  - wariant: efekt okresowy i uderzenie o ścianę po strzale A;
  - każdy wariant odtwarza się z dziennika;
- referencja przypisania leczenia i nagród z E0 bez zmian (jeden gracz);
- Warunek końca: próby i testy zielone, podetapy domknięte.

### E4 — obserwator geometrii i obserwacje strzałów (C4)

**Kontrakt obserwatora.** Symulacja nigdy nie pyta widza kamery. Każde
zapytanie o geometrię malowanego ciała (`Pose.sample`, `Pose.anchor`,
`Surface.prepare`, wybór klatek tyłem) dostaje jawnego obserwatora: punkt,
do którego obraca się billboard. Kamera obserwatora (prezentacja) i kontekst
rozliczania walki to dwie różne rzeczy: pierwsza tylko rysuje, drugi
wyznacza obserwatora z danych strzału lub ciała.

**Dane strzału natychmiastowego.** Zachowany kontrakt: trafia się w pozę
widoczną dla strzelca.

| Dana | Źródło i czas — strzał z obserwacją | Strzał bez obserwacji (bot, test, pocisk) |
|---|---|---|
| punkt wystrzału | oko strzelca w narysowanej próbce jego widoku (`observation.origin`), z czasu próbki | oko strzelca w bieżącym kroku |
| geometria celów | ta sama obserwacja: pozy z tej samej próbki, obrócone do tego samego oka | bieżący stan, obserwator = oko strzelca w kroku |
| kierunek | `yaw`/`pitch` strzelca w chwili komendy, zapisane w komendzie (mysz nie czeka na krok) | bieżący kierunek strzelca |
| wiek | czas kroku − czas próbki ≤ `Tuning.observation.maxAge` (0,32 s), inaczej strzał odrzucony bez zużycia amunicji, jak dziś (`C.shoot`) | — |
| buforowane naciśnięcie | komenda (obserwacja i kierunek) z chwili naciśnięcia, wykonana, gdy broń będzie gotowa, o ile obserwacja jest nadal ważna | — |
| przytrzymany spust | każdy strzał bierze najnowszą obserwację tego strzelca | — |

- Punkt wystrzału i geometria celów pochodzą zawsze z jednej obserwacji
  jednego strzelca. Złączenie geometrii z jednej próbki z punktem
  wystrzału z innej (innego aktora albo innej chwili) jest odrzucane.
  Obserwacja przechowuje id strzelca, a komenda sprawdza zgodność.
- Ruch i obrót strzelca między narysowaniem klatki a wykonaniem komendy
  nie przesuwają punktu wystrzału ani geometrii, bo obie pochodzą z próbki.
  Kierunek jest tym z chwili komendy. To dzisiejsze zachowanie, teraz
  zapisane.

**Pocisk w locie.** Obserwator to bieżące oko właściciela, gdy ten jest
**żywy**. Gdy właściciel jest **martwy** (nadal w puli) albo **usunięty**,
obserwatorem jest punkt wystrzału zapamiętany w pocisku.
- Dla pocisków rycerza w grze jednoosobowej (żywy właściciel) to
  dzisiejsze zachowanie.
- **Kompromis, nazwany jawnie:** obracanie billboardu do bieżącego
  położenia właściciela zachowuje obecne wyniki, ale nie jest fizyką
  niezależną od obserwatora. Dwóch obserwatorów zobaczyłoby inną sylwetkę
  w tym samym punkcie. Demon pozostaje billboardem z maską w płaszczyźnie;
  geometria 3D ciała jest poza v11.

**Wzrok i wysokość oczu stworzenia.** Obserwatorem jest jego bieżący cel.
W produkcji to sterowany rycerz, jak dziś.

**Prezentacja.** Widz kamery, wyłącznie do obrazu.

Raport E0 pokazuje, czy któraś reguła zmienia dzisiejsze wyniki. Jeśli tak,
etap staje i wraca do użytkownika z pomiarem, zamiast zmieniać złoty wzorzec.

**Zakresy unieważniania obserwacji.** Dziś generacja należy do sesji
(`O.invalidate`). Po E4 są dwa zakresy:
- **generacja świata**: reset sesji, zmiana mapy; unieważnia wszystkie
  obserwacje;
- **generacja obserwacji aktora**: jego teleport, śmierć, utrata lub
  przejęcie sterowania, `actorLeave`; unieważnia tylko jego obserwacje.
- Obserwacja jest ważna, gdy zgadzają się: sesja, generacja świata,
  generacja aktora-strzelca, mapa, wiek i strzelec komendy.
- Przy zmianie sterowanego z A na B: obserwacje A i B tracą ważność
  (zmienia się sterowanie obu). Obserwacje innych aktorów zostają.
- Usunięcie widoku (zamknięcie płótna) nie unieważnia obserwacji. Aktor
  bez widoku po prostu nie dostaje nowych; ostatnia gaśnie z wiekiem.
- `app/input.lua` trzyma obserwację na aktora, nie jedną na wejście.
  Komenda bierze korytarz z broni strzelca.

**Odbiór:**
- zapadka `VIEWER IN SIMULATION` = 0;
- złoty wzorzec, rzut stanu (okresowy i przy zdarzeniach) i rendery bez
  zmian;
- testy:
  - strzał A nie korzysta z ostatnio narysowanej obserwacji B (test
    negatywny: komenda A z obserwacją B jest odrzucona bez zużycia
    amunicji);
  - zmiana kolejności rysowania A/B nie zmienia trafień;
  - uruchomienie i przesunięcie dodatkowej kamery nie zmienia rzutu stanu
    ani skrótu;
  - dwa widoki nie dają dwóch kroków świata (licznik kroków);
  - ruch i obrót strzelca między narysowaniem klatki a wykonaniem komendy:
    trafienia jak przy punkcie i geometrii z próbki oraz kierunku
    z komendy; złączenie próbki z innym punktem wystrzału odrzucone;
  - buforowane naciśnięcie po przekroczeniu `maxAge` odrzucone bez
    zużycia amunicji; przytrzymany spust używa najnowszej obserwacji;
  - pocisk: właściciel żywy (oko bieżące), martwy w puli i usunięty
    (punkt wystrzału), każdy wariant z dziennika;
  - śmierć i teleport A nie unieważniają obserwacji B; zmiana sterowanego
    unieważnia obserwacje obu, a reset i zmiana mapy wszystkich.
- próba dwóch aktorów z E3 powtórzona na malowanych demonach (B trafia
  w głowę demona widzianego ze swojej strony), dziennik bit w bit;
- Warunek końca: testy i próba zielone, bez zmiany złotego wzorca.

### E5 — kontekst prezentacji, widoki i wejście (C5)

**Kontrakt.** Prezentacja rysuje kontekst widoku: `{ widz, aktor, stan
osobisty }`, przekazywany przez renderer, HUD i feedback. Nie czyta
globalnego `g.player` ani jednego `g.view`.
- **Stan widoku** według inwentarza z E0, bez kopiowania całego `g.view`
  na aktora:
  - **świat**, jeden na sesję: cząstki, plamy, ślady strzałów, liczby
    obrażeń, efekty;
  - **aktor**: odrzut, błysk i kierunek zranienia, ruch broni, kamera
    pisana przez `player/feel.lua`, znacznik trafienia, napisy walki;
  - **widz**: interpolacja, poprzednia próbka, FOV.
  - Każde pole ma reset przy zmianie sterowanego, śmierci i resecie
    sesji. `g.view` zostaje widokiem sterowanego dla zgodności.
- **Interpolacja.** `render/presentation.lua` interpoluje wszystkich
  aktorów, z poprzednią próbką na widz.
- **Kamera i odbiór.** Kamera, słuchacz dźwięku, światła i etykiety pytają
  widza. HUD, ręce i portret pytają aktora kontekstu.
- **Wejście.** `app/input.lua` przypisuje urządzenie (klawiatura+mysz,
  kolejne) do aktora; obserwacja i komenda idą do tego aktora.

**Odbiór:**
- zapadka `PRESENTATION ASSUMES ONE PLAYER` = 0 poza modułem kontekstu;
- rendery piksel w piksel z bazą (jeden widok);
- próby (testy, nie menu):
  - **(a) kamera widza:** wolna kamera i drugi rycerz jako widz;
    billboardy, tył demonów, słuchacz i światła od widza, HUD
    sterowanego; symulacja bez zmian (E4);
  - **(b) dwa widoki:** dwóch rycerzy na dwóch płótnach, każdy z własnym
    HUD, rękami, odrzutem i błyskiem zranienia; wspólne plamy i krew
    widoczne w obu; dziennik v5;
- pomiar według protokołu z Zasad: klatka i krok dla jednego i dwóch
  widoków; jeden widok bez stwierdzonej regresji wobec bazy E0 (albo
  z zaakceptowanym odstępstwem); koszt drugiego widoku opisany.
- Warunek końca: próby zielone, pomiar opisany w DEVELOPMENT.

### E6 — zgodność, zasoby, odbiór końcowy

- Fixture zapisów 0.33 i adaptery SIGIL06–08: wczytanie, rzut stanu
  równy referencji, ponowny zapis i odczyt.
- Dzienniki v2–v5 w obrębie wydania: odtworzenie bit w bit (Integrity).
- Zasoby: brak wycieków po resetach, zmianie sesji (menu → poligon →
  wyprawa → menu) i odtworzeniu (test `resources`, `--resource-plateau`:
  liczba zasobów i pamięć wracają do poziomu po pierwszym cyklu).
- Dokumenty: ARCHITEKTURA, ROZSZERZANIE, DEVELOPMENT, ODBIOR 0.34 i plan
  „Wykonano”.

## Kolejność i zależności

E0 → E1 → E2 → E3 → E4 → E5 → E6

- E0 przed wszystkim: referencje (rzut, pozy, zapisy) powstają ze starego
  kodu i nie mogą powstać później.
- E1 jest niezależny od E2–E5 (treść i animacja). Źródło obserwatora
  w wyborze klatek tyłem zmienia dopiero E4.
- E2 przed E3: pola wspólne (strażnik, sekret, pieczęcie) dostają
  właściciela, zanim statystyki przejdą na aktora; nic nie jest
  przenoszone dwa razy.
- E3 przed E4: obserwacja potrzebuje id strzelca i jego broni.
- E4 przed E5: osobne widoki są bezpieczne dopiero, gdy żaden nie wpływa
  na symulację.
- E6 na końcu.

Po każdym etapie: commit z dowodami (bramki, złoty wzorzec, rzut stanu,
pomiary) i wpis w sekcji ZMIANY-0.34.txt.

## Warunek zakończenia całego planu

Plan jest zamknięty, gdy w jednym przebiegu `TEST.ps1 -Suite All` na tym
samym drzewie zachodzi jednocześnie:

1. **Złoty wzorzec v2** daje te same liczby (bez przeliczenia). Rzut stanu
   w scenariuszach i próbach 0.33, okresowy i przy zdarzeniach, jest równy
   referencji E0. To samo dotyczy przypisania leczenia i nagród. Rendery
   showcase i audytu GUI są identyczne z bazą 0.33.
2. **Próba demona o innym układzie póz** (E1) przechodzi, z poprawnymi
   trafieniami w każdej używanej pozie. Próba przestawienia klatek
   i próba zwłok też przechodzą.
3. **Próba trybu „ołtarze”** (E2) przechodzi w pełnym cyklu: start,
   postęp, zapis, odczyt, koniec, ponowny start, dziennik.
4. **Próba dwóch aktorów** (E3, E4) przechodzi na malowanych demonach,
   z dziennikiem v5 bit w bit.
5. **Dodatkowy widok** (E4, E5) nie zmienia symulacji, a dwa widoki
   rysują się z osobnym stanem osobistym.
6. **Brak wycieków** stanu i zasobów po resetach, zmianie sesji
   i odtworzeniu (E6).
7. **Pomiar** według protokołu z Zasad (5 par przed/po, rozgrzewka
   w każdym procesie, mediana i IQR osobno dla każdego wariantu, osobno
   symulacja i render): jeden gracz bez regresji wobec bazy E0 (wynik
   „brak regresji”, nie „nierozstrzygnięty”) albo z odstępstwem
   udokumentowanym i zaakceptowanym przez użytkownika; koszt dwóch
   widoków opisany.
8. **Zapadki pomocnicze** E0 osiągnęły cele.
9. **Wydanie 0.34** z ODBIOR, w którym B2 (feeling, czytelność, wydajność
   w normalnej grze) zostaje do oceny człowieka.

## Reprezentatywne rozszerzenia po v11 (miejsce implementacji)

| Rozszerzenie | Gdzie | Rdzeń bez zmian |
|---|---|---|
| broń | `Weapons.define` (+ ewentualnie wykonawca dostawy `combat/weapon_delivery`) | aktor, HUD ze slotów, zapis |
| umiejętność / wyposażenie | `Abilities.define` (+ `Cast.kinds` dla nowej dostawy) | caster, sloty |
| demon o obecnych lub nowych pozach | arkusz z pozami, anatomia, bake, definicja (+ sampler `AbilityPose.register` dla nowej sekwencji) | animacja, trafienia |
| rodzaj ataku | `Action.defineKind` + wpis w `melee_kinds`/`ranged_kinds` | AI, kontakt |
| tryb z celami | `Modes:register` + stan w `modeData` + widoki + `Save.declare` | ekrany, renderer |
| obiekt świata | `WorldObjects.register` | renderer |
| aktor innej strony / drugi rycerz | strona, prefab, kontroler (wejście, dziennik, bot) | walka, obserwacje |

## Co plan świadomie zmienia w dotychczasowych dokumentach

- ARCHITEKTURA.txt, sekcja 13: znika punkt o rycerzach bez własnego
  sterowania. Dochodzą kontrakty obserwatora geometrii (E4), stanu aktora
  (E3), widoków (E2) i kontekstu prezentacji (E5).
- ROZSZERZANIE.txt: przepisy na pozy (E1), tryb z własnym stanem (E2),
  drugiego aktora i dodatkowy widok (E3–E5).
- `appearance.layout` znika z definicji stworzeń (E1).
- ODBIOR.txt 0.34: ograniczenie o drugim rycerzu przechodzi do B2
  (split-screen nie jest w menu).

## Ryzyka

- **Rzut stanu.** Musi zostać zapisany ze starego kodu w E0. Bez tego
  „równoważność” byłaby porównaniem nowego z nowym. Etapy E1–E5 nie
  zaczynają się przed jego utrwaleniem.
- **E1.** Błąd przepisania granicy zmienia trafienia. Zabezpieczenie:
  tabela pozy klatki z punktami na granicach.
- **E2/E3.** Classic to scenariusz złotego wzorca, a skrót czyta
  `g.score` i `g.weapon`. `qa/golden.lua` może je czytać z nowego miejsca
  tylko z identycznym wynikiem.
- **E3a.** Rozdzielenie licznika strzału dotyka rozrzutu i ziaren
  kontaktów. Zabezpieczenie: rzut przy każdym strzale z licznikiem
  sekwencji i ziarnem.
- **E3d.** Reguła łańcucha może zmienić leczenie w przypadkach, w których
  dziś leczy się „ktokolwiek sterowany”. Referencja E0 to wykrywa; zmiana
  balansu wraca do decyzji użytkownika, a nie przechodzi pod refaktorem.
- **E4.** Może się okazać, że obecny wybór klatek tyłem względem
  sterowanego wpływa na wyniki w sposób, którego żadna jawna reguła nie
  odtwarza. Wtedy etap staje z pomiarem i propozycją; nie obniżamy
  kryterium.
- **E5.** Dotyka ok. 30 plików prezentacji. Zabezpieczeniem są rendery
  piksel w piksel i podetapy z osobnymi commitami.
- **Koszt drugiego widoku.** Mierzony według protokołu; nie jest progiem
  produkcji.

## Świadome granice gotowej bazy

Po v11 baza nie obiecuje, że każda przyszła funkcja obejdzie się bez zmian
w kodzie. Nowe zachowanie (nowa dostawa, nowy rodzaj ataku, nowa reguła
AI, nowy sampler sekwencji) dostaje mały lokalny wykonawcę w rejestrze.
Pozostają poza v11 i wymagają osobnej decyzji:

- sieć (transport, predykcja, autorytet);
- odtwarzanie nagrań między wydaniami;
- automatyczny układ UI (dziś współrzędne 1280×720) i drugi język treści
  z malowanymi napisami;
- split-screen, nowy tryb i drugi rycerz w menu;
- głębia sprite'ów: demon pozostaje billboardem z maską w płaszczyźnie.
  Trafienie zależy od obserwatora, ale reguła jest jawna (E4).
