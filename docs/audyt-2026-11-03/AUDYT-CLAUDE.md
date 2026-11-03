# Audyt Claude (Opus 5.5), SIGIL: BREACH 0.42, commit `f69a19b`

Zapisany przed odczytem wyniku Astry. Prompt: `PROMPT-AUDYTU.md` (SHA-256 `CBCA92B8…25B1`). Praca w osobnym klonie `sigil-audit-claude-1103` na `f69a19b`.

## 0. Co uruchomiłem, a co tylko przeczytałem

| Uruchomione | Wynik |
|---|---|
| `TEST.ps1 -Suite All` | format OK, 649 plików, 0 uwag architektury; **Mechanics: FAILED, 6 przypadków** (niżej, U01) |
| `love game --chapel-look` (1280×720) | 28 renderów `look-*.png` w `work/look` klonu; obejrzałem 4 |
| pomiary z selftestu (`MEASURE …`) | odczytane z `work/qa/source-selftest.stdout.txt` |

Przeczytane: dokumenty wejściowe, poprzedni audyt i jego POSTEP, analizy z 2026-11-02, sekcja ZMIANY-0.42; kod: `combat/projectiles, dodge, weapon_delivery`, `session/game (dash), damage_outcomes`, `enemies/ai, styles, actions, ranged_kinds`, `content/knight, creatures/*, pilgrimage, shop, ammo/magazine`, `run/pilgrimage`, `render/renderer (tell)`, `feedback/weight, flinch`, `physics/collision`, `content/art/anatomy/*` (wybiórczo).

Nie sprawdzałem: grania ręcznego, odsłuchu, pomiaru klatek (w tym czasie Astra mogła obciążać maszynę; cytuję pomiary z ZMIANY-0.42), renderów 960×540 i 4K, `render/kit`, `ui/*` od środka, `journal`, `storage`, `tools`, nawigacji.

## 1. Ocena stanu (krótko)

Technicznie projekt jest dojrzały: stały krok symulacji (`app/application.lua:382-394`), determinizm z dziennikiem i złotym wzorcem, 150 przypadków testów, 389 modułów bez cykli, dane stworów i broni walidowane schematami. Słabe miejsca nie leżą w silniku, tylko w **tempie zmian projektu**: 2 listopada w jeden dzień wprowadzono ok. 10 zmian ekonomii i walki (skrytki, znajdźki, grawery, hartowanie, pieczęcie, krótkie elity, ognisko zabezpieczające, odnawianie Judge'a), bez próby człowieka pomiędzy, a ostatnie commity zostawiły **czerwoną bramkę Mechanics**. Kierunek (hybryda souls + znajdźki) jest sensowny, ale łączny efekt nie został zmierzony i ma dwie twarde niespójności (U02, U03).

## 2. Filary (decyzje właściciela vs moja interpretacja)

**Decyzje** (z prompta, nie powtarzam): FPS souls-like, rycerz bez magii, Judge + Exorcist, Q, F; żywy fresk; chroniony dolny pasek; elity zamiast bossów; kaplica = poligon; CoD tylko dla potwierdzeń; D1–D4, D7.

**Pętla (stan kodu):** ognisko (zapis, leczenie, zakupy, podróż, zabezpieczenie oczyszczonego) → wyjście w kaplicę → walka z grupami i elitami → zbieranie dusz, amunicji i łyków z podłogi i stworów → śmierć: echo dusz, powrót do ogniska, wraca tylko to, co nie było zabezpieczone (`run/pilgrimage.lua:323-341, 435-458`).

**Moja interpretacja zamierzonego doświadczenia:** trudność z czytania ciosów i okien (telegraf, przytrzymanie, kontra strzałem, doskonały unik), nie z paska HP; broń palna jako „miecz” z kosztem ciała po strzale; ryzyko powrotu z duszami. Niepewne: czy zakupy przy ognisku mają zostać głównym torem rozwoju (właściciel sam to podważa) — to blokuje projekt ekonomii, nie blokuje reszty audytu.

### Logika kodu (mapa)

`app` (pętla, stały krok, ekrany) → `session/game` (stan sesji `g`, zdarzenia `Signal`, pule obiektów) → systemy w kolejności (`systems/*`: rycerz, zegary, walka) → `combat` (strzał: `volley` + `weapon_delivery`, `ballistics` po namalowanych bryłach, `projectiles`, `damage`, `rules/*`) i `enemies` (AI: czucie, alarm, sloty, style ruchu, akcje-rodzaje) → `run` (tryby: kaplica `pilgrimage`, poligon) → `feedback` (słuchacze zdarzeń: waga, błyski, dźwięk, lekcje) → `render` i `ui`. Treść w `content/*` (definicje ze schematami). Dobra separacja: reguły nie znają rysowania, rysowanie czyta stan.

### Fizyka świata — spójna?

- Świat to siatka kafli z wysokościami pokładów, okrągłe filary jako walce (`physics/collision.lua:13-90`), ruch ciał jako ciągła kolizja okręgu z poślizgiem. Jedna grawitacja `Tuning.gravity = 18.5` dla skoku rycerza, skoku impa, upadku ciał i lotu ładunku Q (`player/feel.lua:355`, `enemies/melee_kinds.lua:340`, `enemies/body.lua:59-77`, `combat/explosives.lua:183`). Jedyny inny stały `GRAVITY = 4.9` jest w `render/kit/halls.lua:17` i dotyczy tylko spadających odłamków w rysunku.
- Trafienia w ciała liczone są w malowanych maskach anatomii (głowa / tułów / dół, materiał), ten sam model dla strzału, pocisku i egzekucji (`enemies/surface.lua`, `combat/area_contact.lua`).
- **Wniosek:** fizyka jest spójna i wystarczająca dla gry 2,5D. Nie wymaga przepisania. Do dopracowania tylko tam, gdzie gra tego potrzebuje (U06: broń jako część ciała).

### Czy każdy pocisk jest osobny?

Tak. Każdy pocisk stwora to obiekt puli `projectiles` z `x,y,z,vx,vy,vz`, promieniem i czasem życia (`enemies/ranged_kinds.lua:27-44`). Co krok jest przeciągany kulą przez świat i walcem przez ciało rycerza z uwzględnieniem skoku i kucnięcia (`combat/projectiles.lua:49-74, 306-350`); zdarzenia są sortowane w czasie. Pocisk leci prosto (bez grawitacji), ma wysokość (wystrzał z `spec.height` ciała, celowanie w wysokość celu) i da się go: obejść krokiem, przeskoczyć/zejść pod niego, przeciąć unikiem (doskonały unik przez „afterimage”, `projectiles.lua:254-261`). Bliskie minięcie daje sygnał `NearMiss`. Strzały rycerza są domyślnie śledzone natychmiast (`hitscan`), ale silnik ma też dostawę pociskiem (`combat/weapon_delivery.lua`).

## 3. Ustalenia

Oznaczenia: **B** potwierdzony błąd, **R** ryzyko, **H** hipoteza, **P** preferencja projektowa. Pewność: wysoka / średnia / niska.

| ID | Rodzaj | Ustalenie | Dowód | Pewność |
|---|---|---|---|---|
| U01 | B | **Bramka Mechanics czerwona na `f69a19b`**: 6 FAIL. `weapons` („an empty revolver cannot … regenerate ammunition”) i `weapon-art-review` („partial reserve fabricated ammunition”) przeczą celowej zmianie 0.42 (odnawianie Judge'a); `weight/enemy_durability` („substantial boss endurance”) przeczy celowo skróconym elitom; `souls-gate`/`souls-bots` („ash kills a knight who stands and shoots”) — Margrave już nie wygrywa z botem stojącym i strzelającym; `interface:119` („current failure reason replaces a stale purchase receipt”) — możliwa prawdziwa regresja komunikatu sklepu po `73c1431`. Commity hybrydy i astra-fix weszły bez zielonego Mechanics | `work/qa/test-results.txt` klonu | wysoka |
| U02 | B (projekt) | **Elity po skróceniu nie egzaminują**: bot „careless” (stoi i strzela) zabija Margrave'a w 13,5 s, zostaje mu 86 HP; bezczynny rycerz ginie w 11,2 s. Cel z KIERUNEK-HYBRYDA: 20–35 s dobrej walki | `MEASURE souls ash/careless: 13.5s won, HP 86`, `MEASURE ash/still: 11.175s` | wysoka dla bota na poligonie, średnia dla kaplicy |
| U03 | B (projekt) | **Ekonomia dusz nie domyka się po „ognisku, które zabezpiecza”**: pełne oczyszczenie kaplicy daje 1420 dusz (7×4 + 2×8 + 2×12 + 2×12 + 2×25 = 142 × `souls = 10`), katalog trwałych zakupów kosztuje ok. 4760 (śluby 1220, trzy pieczęcie 3×713, grawery 800, hartowanie 600). Odpoczynek już nie odradza świata, więc jedyne źródła dalszych dusz to celowa śmierć (wraca niezabezpieczone) i U04 | `content/pilgrimage.lua:26,136-176`, `content/shop.lua`, `content/creatures/*.lua: souls`, `run/pilgrimage.lua:323-341` | wysoka (arytmetyka z kodu) |
| U04 | B | **Wyjście do menu i Continue = darmowy odpoczynek i farma dusz**: zabójstwo ustawia `dirty`, zapis przychodzi w spokojnej chwili albo przy wyjściu (`P.update:478-483`, `P.flush`); Continue woła `refresh(g, true)` (pełne HP, flaska, amunicja), budzi przy ognisku i `P.populate` przywraca wszystkie stwory spoza `r.slain` (`P.init:242-264`). Portfel zostaje. Pomija też D1 (odmowę w pościgu) | kod; scenariusz: zabij 3 Ember Thralle, Esc → menu → Continue → te same stwory stoją, dusze +120 | wysoka (kod), nieodtworzone w oknie |
| U05 | B (GUI) | **Podpowiedź przy ognisku wychodzi poza ramę** w 1280×720: „Narthex Fire / NO REST WHILE YOU ARE HUNTED” ma uciętą pierwszą literę i dotyka prawej krawędzi; to samo „Sanctuary Fire / …”. Reguła ELIDED łapie tylko wielokropek | `look-medal-crowded.png`, `look-target-trail.png`, `look-fire-menu.png` | wysoka |
| U06 | R (QA) | Render `look-fire-menu` pokazuje dziś odmowę odpoczynku („Something is awake…”), nie menu ognia: scenariusz renderu nie pokrywa już sklepu po D1 | `look-fire-menu.png` | wysoka |
| U07 | P | Broń stwora jest dziś częścią malowanego ciała i ewentualnie przeszkodą: tasak Margrave'a to obszar `metal` bez strefy obrażeń (`content/art/anatomy/boss.lua:242-247`, `zone=false` blokuje strzał). Cios jest osobnym obiektem danych (akcja z pakietem, zasięgiem, śladem), niezależnym od ciała. Brak warstwy „uzbrojenia” wspólnej dla kilku ciosów | kod | wysoka |
| U08 | H | Uniki: `dashTime 0,155 s`, nietykalność uniku `rollIframes 0,32 s`, po ciosie `iframes 0,32 s` (`content/knight.lua:34-73`). Doskonały unik = cios w trakcie 0,155 s (także w miejsce startu), zwraca **całą** wytrzymałość uniku i mrozi świat 0,25 s (`combat/dodge.lua`). Okna są w normie souls-like; hojność bierze się raczej z przesunięcia 2,5 m (16 m/s × 0,155) i pełnego zwrotu. Bramka „dodging by habit is no answer” już istnieje w `souls_gate` | kod | średnia |
| U09 | H | Pociski stworów są wolne względem kroku w bok: gwiazda Stolasa 11 m/s, bełt Buera 8,5, ciężkie 10,5, Margrave 16, Furfur 14. Rycerz idzie 5,25 m/s, w bok 4,46; do zejścia z linii wystarcza ok. 0,1 s. Celowanie z wyprzedzeniem (`aimLead`, `enemies/actions.lua:129-149`) karze stały ruch w jedną stronę, zmiana kierunku po zamachu zawsze unika. To zgodne z komentarzem projektu („a change of direction dodges it”), ale sprawia, że pocisk zagraża tylko w połączeniu z presją wręcz | kod | średnia (brak gry ręcznej) |
| U10 | H | Kite'owanie po prostej **nie działa** na walczących wręcz: cofanie się to 0,6 prędkości (3,15 m/s, tylko w trybie z wysiłkiem, `player/feel.lua:152-162`), Ember Thrall 4,6 m/s ze skokiem 2,05–7,5 m i wyprzedzeniem 0,9, opancerzony 3,8, Margrave 4,6. Style ruchu to `flank`, `keep`, `duel` i unik spod celownika (`enemies/styles.lua`), są strefy (trucizna Buera, fale, błyskawice). Hipoteza właściciela częściowo nie potwierdza się w kodzie | kod | średnia |
| U11 | H | „Soczystość” istnieje w kodzie: odrzut broni z pędu i masy, cofnięcie i obrót nadgarstka, kopnięcie widoku, błysk lufy, wstrząs, dudnienie basu `thud` (`feedback/weight.lua:69-102`), błysk trafienia stwora 0,065 s (`content/combat_defaults.lua:94`, `render/renderer.lua:299-312`), sprężyna drgnięcia ciała (`enemies/flinch.lua`), zatrzymanie świata tylko przy pękniętej gardzie 0,06 s, egzekucji 0,18 s i doskonałym uniku 0,25 s. Na zwykłe trafienie nie ma zatrzymania. **Cały dźwięk jest syntezowany w kodzie** (`audio/recipes.lua`, 0 plików audio w `assets`) — najbardziej prawdopodobne źródło „płaskiego” strzału | kod | wysoka (istnienie), siła odczucia nieznana |
| U12 | R | Zmiany tego samego dnia nakładają się: odnawianie Judge'a + 19 skrytek (126 naboi, 28 łusek, 3 łyki) + drop ze stworów + krótkie elity. Poprzedni problem („ciągły brak naboi”) mógł przejść w nadmiar, a zasób przestał być decyzją. Nie zmierzone po wszystkich zmianach | ZMIANY-0.42; brak pomiaru | średnia |
| U13 | R (wydajność) | Skala dziś: 15 stworów, pomiar 0.42 (astra-fix, Arc): mediana 3,93 ms, p99 9,76 ms. Pętle O(n²): sloty ataku (`enemies/ai.lua:85-98`), wybór celu (`enemies/target.lua:43`), alarm. Przy 256 ciałach wcześniejszy pomiar 34–45 ms. Dla planowanych sal (do ok. 30 ciał) to nie problem | kod; pamięć projektu | średnia |
| U14 | R (GUI) | Nisza ARSENAL: dwie nazwy broni drobnym pismem plus pieczęć serii „x3” przy pierwszej; nie widać od razu, która broń jest w ręku (różnica tylko kolorem/stopniem). Rząd SHIFT ma pasek wytrzymałości kilka px wysokości | rendery 1280×720 | średnia |
| U15 | P | Ogniska po 0.42 to już nie „teleport leczący”: zabezpieczają postęp i nie odradzają świata, odmawiają w pościgu do 14 m. Funkcjonalnie stały się punktami kontrolnymi ze sklepem | `run/pilgrimage.lua:314-369` | wysoka |

### Co z poprzedniego audytu (0.41)

- **Naprawione i potwierdzone kodem:** R01 (zapis), R02 (reset aktora), R03 (seria z broni zdarzenia), R04 (egzekucja), R05 (procenty), R07, G01–G06, L02 (D1), L03 (D2), L04 (strona zasad, lekcje), L05 (alarm D4), L07 (przyczyna śmierci), L09 (D3), E01–E03.
- **Straciło aktualność:** „amunicja nie zabija najtwardszych” (elity skrócone 5×), „ognisko jak teleport” (ognisko zabezpiecza), „widoczna kolejka stworów” (alarm).
- **Nadal otwarte:** L01 (próba właściciela według scenariusza — brak notatki), L06/L08 (balans po próbie), E04 (odsłuch), etap 4 (odłożony decyzją).
- **Nowe przez 0.42:** U01–U06, U12.

## 4. Odbiór gry (z kodu i renderów; nie jest to playtest)

- **Pierwsze minuty:** cel na tabliczce („Walk the chapel. Rest at its fires.”), F1 ze stroną zasad, lekcje po pierwszym zdarzeniu. Dobrze. Niewiadoma: czy nowy gracz zrozumie znaczenie pieczęci, grawerów i hartowania (sporo pojęć naraz w menu ognia).
- **Zwykła walka:** grupa z alarmem, sloty atakujących, odpowiedzi na przeładowanie i picie, przytrzymane ciosy z uczciwym błyskiem. Projekt czytelny.
- **Walka z elitą:** dziś za krótka (U02) — trudność zamieniła się z „gąbki” w „szybki DPS-check”, którego bot zdaje bez nauki ciosów.
- **Porażka i retry:** ekran śmierci mówi, co zabiło, ile dusz w echu, że wraca to, co niezabezpieczone (`look-dead.png`). Dobrze.
- **Progresja:** zakupy zablokowane ekonomią (U03) albo dostępne obejściem (U04). To dziś najsłabsze miejsce pętli.
- **Trudność zamierzona vs nieczytelna:** nieczytelności dziś głównie w GUI (U05, U14) i niezmierzonej sumie zasobów (U12). Brak dowodów na „nieuczciwe” ciosy po 0.42.

### Ogniska czy Doom?

Moje stanowisko: **zostawić ognisko jako kotwicę (zapis, odrodzenie, echo, wybór ryzyka), a rozwój przenieść w świat**. Uzasadnienie: (1) po 0.42 ognisko już nie odradza świata, więc główny zarzut „reset kasuje postęp” zniknął; (2) usunięcie ognisk usuwa echo i decyzję „wrócić czy iść dalej”, czyli rdzeń souls; (3) to, co właściciel lubi z Dooma (znajdźki, sekrety, wzmocnienia z ziemi), da się dodać bez usuwania ognisk — część już jest (19 skrytek, łyki). Proponowany kierunek do decyzji właściciela (D8): pieczęcie i grawery jako **znaleziska w świecie** (sekrety, nagrody za elity), ognisko tylko do zakładania/wymiany i do ślubów za dusze; dusze kupują mniej, ale każdy zakup jest odczuwalny. To jednocześnie domyka U03. Pełna pętla doomowa (bez ognisk, z automatycznym punktem kontrolnym) to wariant L, który wymaga osobnej próby i przebudowy zapisu, echa i ekonomii.

## 5. GUI (dolny pasek chroniony)

Pasek w 1280×720 jest czytelny: duże liczby AMMO/HEALTH/WARD/SOULS, kontrast tuszu na pergaminie wysoki, nisze stałe. Zmiany tylko treści:

| # | Problem → sytuacja → poprawka → efekt → sprawdzenie |
|---|---|
| G-1 | Podpowiedź ogniska wychodzi poza ramę (U05) → gracz przy ognisku w pościgu czyta „arthex Fire…” → skrócić tekst („Narthex Fire — hunted, no rest”) lub zmniejszyć czcionkę tylko tej linii do szerokości ramy; rozszerzyć audyt układu o kontrolę szerokości tekstu wobec ramy (nie tylko wielokropka) → tekst w ramie w każdej rozdzielczości → audyt układu 5 rozdzielczości, render `look-*-hunted` |
| G-2 | Nisza ARSENAL: która broń w ręku (U14) → w walce przełączenie broni nie jest potwierdzone na pasku → broń w ręku pełną kością słoniową i większym stopniem, druga przygaszona; pieczęć serii zostaje przy swoim wierszu → odczyt w 200 ms → render przed/po, zgoda właściciela |
| G-3 | Pasek wytrzymałości przy SHIFT kilka px → gracz nie widzi, że czwarty unik się nie uda → ten sam pasek, wysokość jak paski HEALTH/WARD w tej niszy, bez zmiany kompozycji → odczyt „ile uników” → render `look-no-breath` |
| G-4 | Render menu ognia nie pokazuje menu (U06) → regresje sklepu przejdą niezauważone → scenariusz renderu usypia stwory przed zrzutem → menu znów w przeglądzie → `look-fire-menu.png` |

Nie proponuję zmian kształtu, kompozycji ani stylu paska.

## 6. Mechaniki i spójność inspiracji

- **Wzmacnia się:** souls (telegraf, przytrzymanie, kontra, egzekucja, echo) + CoD (potwierdzenie trafienia, medale serii) + Doom (znajdźki na trasie). Odrzut broni i koszt ciała po strzale dobrze łączą FPS z souls.
- **Konflikt 1:** krótkie elity (z myślą o „gęstej mapie” jak w Doomie) kontra souls-owa nauka ciosów (U02). Rozwiązanie: nie wracać do gąbek, tylko przywrócić kary: pancerz w trakcie zamachu częściowy (np. 60–70% zamiast 100%), więcej HP do celu 25–35 s dla bota, bramka `souls_gate` z nowymi progami.
- **Konflikt 2:** obfitość amunicji (Judge odnawia + skrytki + dropy) kontra D2 „amunicja ze stworów jako decyzja” (U12). Do zmierzenia, nie do zgadywania.
- **Konflikt 3:** ognisko-checkpoint kontra sklep zbudowany pod odradzanie (U03).
- **Spostrzeżenia właściciela:** kite'owanie — w kodzie przeciwdziałane (U10); szybkie pociski / hitscan z laserem — sensowne jako **jeden** nowy rodzaj ataku dla jednej rodziny, nie globalne przyspieszenie (U09); i-frames — nie są przesadne, hojność to pełny zwrot i dystans (U08); soczystość — jest, ale zwykłe trafienie nie ma zatrzymania, a strzał to synteza (U11).

## 7. Plan (moja propozycja)

Priorytet: P1 konieczne, P2 usprawnienie, P3 rozwój. Nakład S/M/L.

| ID | P | Problem i dowód | Zmiana i zakres | Korzyść | Zależy | Nakład / ryzyko | Ukończone, gdy |
|---|---|---|---|---|---|---|---|
| N01 | P1 | U01: Mechanics czerwone | rozdzielić 6 FAIL: zaktualizować testy przeczące celowym zmianom (Judge, elity), naprawić `interface:119` jeśli to regresja; `souls_gate` zostawić czerwone do M01 albo zmienić próg świadomie | brama znów chroni | – | S / niskie | `TEST.ps1 -Suite All` zielone; opis każdej zmiany testu |
| N02 | P1 | U04: Continue = odpoczynek i farma | zapis „w polu” zapisuje też, co zginęło od ostatniego ogniska, i Continue budzi w miejscu ostatniego ogniska z **tym samym** stanem zasobów i świata (bez `refresh(fresh)`) albo traktuje wyjście jak śmierć bez echa — decyzja właściciela D9 | koniec obejścia D1 i farmy | – | M / średnie (zapis) | test: zabij, wyjdź, Continue → stwory martwe, HP jak przy wyjściu |
| N03 | P1 | U05 | G-1 + reguła szerokości w audycie układu | czytelność | – | S / niskie | audyt 0 uwag w 5 rozdzielczościach |
| N04 | P2 | U06 | G-4 | QA sklepu | – | S / niskie | render pokazuje menu |
| M01 | P1 | U02: elity za krótkie | jedna zmienna naraz: pancerz zamachu 100% → ok. 60–70%, potem ewentualnie HP; cel: bot careless przegrywa lub kończy z <30% HP, bot „learning” wygrywa 3/3, walka 25–35 s | elita znów uczy ciosów | N01 | S / średnie | `souls_gate` ash i storm zielone z uzasadnionymi progami |
| M02 | P1 | U03: ekonomia | decyzja D8 (rozwój w świecie vs sklep); minimalnie: ceny pod 1420 dusz na przejście albo dusze za pierwsze zabicie elity jednorazowo wyższe; tabela „co kupię po pierwszym przejściu” | progresja bez farmy | D8, N02 | M / średnie | arkusz w docs + test sumy; ocena właściciela |
| M03 | P1 | U12, L01 | **próba właściciela** po N01–M02 według PROBA-WLASCICIELA, plus sonda: czas z pustymi broniami, nadwyżka naboi przy wejściu do elity, liczba zgonów | fakty zamiast domysłów | N01, M01 | S / brak | notatka z próby i liczby sondy |
| M04 | P2 | U11: dźwięk | zlecenie Codexowi: próbkowane warstwy strzału Judge/Exorcist (bas, mechanizm, ogon kaplicy) i dźwięk trafienia w ciało/pancerz/broń; podmiana syntezy tylko dla tych kilku zdarzeń | strzał „waży” | M03 (odsłuch) | M / niskie | odsłuch właściciela A/B |
| M05 | P2 | U11: zwykłe trafienie | mikro-zatrzymanie 0,02–0,03 s tylko dla trafienia Exorcista z bliska i zabójstwa, jedna stała w `tuning.feel`; nie dla każdego śrutu | trafienie czuć | M03 | S / średnie (rytm) | nagranie 30 s, ocena właściciela |
| M06 | P2 | U09, uwagi właściciela | jeden atak z celownikiem-laserem (hitscan po 0,4–0,6 s telegrafu) dla jednej rodziny (np. Margrave „włócznia” albo nowy stwór), przerywalny kontrą | zagrożenie dystansowe wymaga uniku, nie kroku | M03 | M / średnie | bot „learning” wygrywa, „careless” traci HP; test kontry |
| M07 | P3 | U07: broń jako część | warstwa `arms` w definicji stwora (materiał, dźwięk zderzenia, czy blokuje strzał, które ciosy jej używają); pierwsze użycie: trafienie w broń daje osobny znak i dźwięk, strzał w broń w oknie kontry działa jak kontra | broń ma własne właściwości bez osobnej fizyki | M04 | M / niskie | test danych, render trafienia w tasak |
| T01 | P2 | jakość procesu | reguła: commit dopiero po zielonym `-Suite Mechanics`; zmiany balansu jedna zmienna na commit z sondą przed/po | koniec nakładania | N01 | S / brak | wpis w DEVELOPMENT, przestrzegane |
| T02 | P3 | U13 | gdy sala > 30 ciał: licznik atakujących na cel zamiast pętli, siatka przestrzenna dla celu | skala | treść | S–M / niskie | pomiar 64 ciał < 8 ms update |
| R01 | P3 | D8 | znaleziska w świecie (pieczęcie, grawery) w sekretach i za elity | Doom bez utraty souls | M02 | M / średnie | 3 znaleziska, zapis, ocena |

**Kolejność:** N01 → N03, N04 → M01 → N02 → (decyzje D8, D9) → M02 → M03 (próba) → M04/M05/M06 → M07, R01, T02.

## 8. Ograniczenia i pytania

- Nie grałem ręcznie, nie słuchałem, nie mierzyłem klatek w tej sesji.
- U02 zmierzone na poligonie (`proving`), nie w kaplicy; elita w kaplicy ma grupę wokół siebie.
- U04 nieodtworzone w oknie gry; ścieżka kodu jednoznaczna.
- Pytania do właściciela: D8 (gdzie rozwój: sklep czy świat), D9 (co znaczy wyjście z gry w trakcie: zapis stanu czy powrót do ogniska bez nagrody), cel długości walki z elitą, czy Judge ma zostać nieskończony.

## Dopisek: weryfikacja U04 (po pierwszym zapisie tego pliku, SHA-256 `D642D744…4F3`, nadal przed odczytem Astry)

Sonda w klonie (`game/tests/cases/probe_continue.lua`, zestaw `probe-continue`): nowy slot, zabicie `nave_1..3`, HP rycerza 20, `flush` (jak przy wyjściu), nowa gra z tego slotu. Wynik: `wallet before 120 after 120; hp before 20 after 100 of 100; killed standing again 3 of 3; fire narthex`. **U04 potwierdzone w działaniu silnika** (bez okna).
