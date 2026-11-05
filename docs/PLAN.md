# SIGIL: BREACH — plan rozwoju

Jeden bieżący plan. Gdy powstaje nowy plan, ten plik w całości trafia jako rozdział do `docs/HISTORIA.md`, a tutaj zostaje tylko nowy. Stan punktów jest w rozdziale „Postęp”.

## Spis rozdziałów

- Postęp (stan punktów)
- Raport końcowy: czytelność walki, ekran, ogniska jako sklep, dźwięk, animacje, znajdźki (2026-11-03)
- Plan następnych kroków
- Przeniesione z poprzedniego planu

## Postęp (stan punktów)

**Audyt tekstur, 2026-11-05 — zakończony:** przejrzano 158/158
początkowych obrazów. Powstała biblioteka `baza/` (44 wzorce, wyłącznie do
porównań) i pełny katalog 152 wynikowych tekstur. Iron Thrall wrócił do
oryginalnych pikseli wskazanego arkusza 6×4; siedem odrzuconych dodatków
usunięto. Przywrócono 22 tekstury sprzed spłaszczającego przemalowania,
w tym stojący ogień. Regresja obejmuje sumy wszystkich obrazów oraz każde
kopiowane piksele Iron Thralla. Wykonano trzy przeglądy: obrazy i klatki,
natywne sceny 3/6/12 m oraz przejścia animacji. Pełna brama Linux PASS:
6878 sprawdzeń mechaniki/zasobów, Input 50, Architecture, Render i Tools;
dziewięć stabilnych świadectw, exitCode=0. Dwa identyczne golden przed
aktualizacją Linux; 173 maski innych stworów pozostały identyczne.
Windows niesprawdzony. Szczegóły w najnowszym ZMIANY/ODBIOR-0.45
i `baza/catalog.json`; obrazy przed/po zachowano w wynikach audytu.

Obowiązkowe przed commitem grafiki: trzy kontrole spójności opisane w
AGENTS/STYLU oraz test regresji odrzucający niewłaściwy wariant. Wzorzec
Iron Thralla potwierdzony przez właściciela: bazowy arkusz 6×4 v12; osobna
klatka strike-matte v12 także odrzucona i usunięta. Korekta używa oryginalnych
pikseli; techniczny PASS nadal nie stanowi akceptacji nowego projektu.


**Odrzucony odbiór grafiki, 2026-11-05:** właściciel odrzucił nowe klatki
Iron Thralla z 18c25e0: podczas animacji zmieniają się faktura i wygląd
postaci. Zielona brama poniżej nie oznacza akceptacji stylu. Obowiązuje
nienaruszalna ciągłość zatwierdzonych zasobów (AGENTS/STYL/WIZJA).
Kolejność zlecona: (1) poprawić Iron Thralla na podstawie oryginalnych
arkuszy; (2) przejrzeć każdą teksturę, jej historię i wcześniejsze podmiany,
ze szczególnym uwzględnieniem odrzuconego ognia; naprawić stwierdzone
niespójności i pokazać porównania w grze. Oba punkty zamknięto audytem
opisanym powyżej; wcześniejsze wyniki poniżej są zapisem sprzed korekty.

**IRON THRALL, 2026-11-05:** dopracowano pięć obecnych ataków: 15 nowych malowanych póz, rozróżnione gesty, widoczne zaparcie nawrotu, niski grzbiet odłamków do przeskoczenia, ślad pazura i ciemny znak żelaza. Naprawiono rzeczywisty kontakt pazura (0 → 30 obrażeń stojącemu celowi bez zwiększania zasięgu, HP i pakietów obrażeń). Własny głos ciała, pięć wysiłków i kroki szarży, ze wspólnym limitem dla tłumu. Celowane 89 PASS, hit-landmarks 521 PASS, dwa identyczne golden Linux. Koszt 128 atakujących/25 fal: około 5,0–5,3 → 7,8–8,3 ms w naprzemiennym porównaniu (dodatkowe końcowe sesje 7,1–7,3 ms); szczegóły w ODBIOR. Pełna brama Linux PASS: 6977 mechaniki/zasobów, Input 50, Architecture, Render i Tools; dziewięć stabilnych świadectw, exitCode=0. Kontrast nawy nadal wymaga odbioru; bot kaplicy nadal nie kończy mapy. Klon pomiarowy usunięty, dowody zachowane. Odbiór artystyczny i odsłuch należą do właściciela; Windows niesprawdzony.

**Brama Linux naprawiona, 2026-11-05:** wcześniejsze FAIL-e `weight` i cienia w Render miały wspólną przyczynę w shaderze: próbkowanie mipmap wewnątrz rozbieżnego warunku alfa. Odczyty konturu i pigmentu przeniesiono przed warunek oraz `discard`, zachowując filtrowanie i kryteria testów. Nieruchoma scena jest teraz identyczna piksel po pikselu przy powtórzeniu oraz przy rysowaniu pojedynczym/grupowym. Pełne `TEST.sh All --timeout 1800` na natywnym GPU: Architecture PASS, Mechanics 6677 PASS (w tym golden), Input 50 PASS, Render PASS, Tools PASS; potwierdzony kod wyjścia 0. Windows niesprawdzony. Następny zlecony zakres: dopracowanie Iron Thralla według uwag do Stolasa; analiza i pierwsze projekty grafiki w izolowanym klonie. Szczegóły naprawy i pomiaru w najnowszym ODBIOR-0.45.

**STAR ACOLYTE — trzecia iteracja, 2026-11-05:** właściciel wybrał niską falę do przeskoczenia i wysokie rozdarcie do ominięcia bokiem. Wdrożone: fala 0,35 m/8 m/s, pionowy pigment rozdarcia, nieszkodliwy popiół, czary przy dłoniach z wygasaniem po wypuszczeniu oraz cztery głosy ciała obok dźwięku czaru. Pozostają wcześniejsze poprawki ruchu, teleportu, pozostałych czarów i demoniczny wieniec. Celowane 135 PASS, sonda skoku i dwa identyczne golden Linux; okno skoku ok. 0,25–0,30 s. Bot kaplicy 6 zabójstw/4 śmierci, nadal nie kończy mapy. Pomiar 128 równoczesnych rytuałów 9,13 → 17,58 ms — koszt nowego pionowego pigmentu jest jawny. Końcowa brama: Architecture PASS, Mechanics 5818 PASS i wcześniejszy FAIL weight, Input 50 PASS, Render wcześniejszy FAIL cienia, Tools PASS. Wszystkie 9 świadectw ma stabilne źródła. Windows niesprawdzony. Własny klon i jego wyniki usunięte, dowody zachowane. Właściciel 2026-11-05 wyraźnie polecił commit całego zakresu mimo dwóch opisanych wcześniejszych błędów bramy; odstępstwo zapisane, push niezamówiony. Związek błędów z samym Linuxem nie został potwierdzony. Odbiór klimatu i trudności przez właściciela pozostaje osobny. Szczegóły i dowody w najnowszym ODBIOR-0.45 w HISTORII.

**Aktualizacja 2026-11-04, Omarchy:** przegląd na `d10e5e1` zakończony bez zmian gry. Architecture, Input, golden i Tools przeszły; brama Linux pozostaje czerwona na `weight` oraz kontroli cienia w Render. Pełny zapis na górze `ODBIOR-0.45.txt` w `docs/HISTORIA.md`. Ustalenia właściciela są w `docs/AGENTS.md`, a punktem wejścia jest `START-HERE.txt`. Usunięto zbędny prompt, lokalny NOWY-KOMPUTER i wygenerowane work/; wyniki Linuxa przeniesiono do Work/tries. Test behavior uwzględnia proporcje kafelka Omarchy (sonda 960×1080: FAIL → PASS 39). Końcowa weryfikacja całego zakresu jest w najnowszym wpisie ODBIOR.


**Porządki zakończone 2026-11-04:** zasady tymczasowych klonów i kafelkowania Omarchy zapisane; wszystkie domyślne wyniki Linuxa poza repozytorium. Końcowy przebieg: Architecture 663 pliki / 0 naruszeń, ścieżki QA PASS, Mechanics 5639 zaliczonych (FAIL tylko wcześniejszy weight), Input 50 PASS, Tools PASS; Render zatrzymuje wcześniejszy test cienia. Dziewięć zgodnych świadectw źródeł, bez zmian Windows. Po przedstawieniu wyników właściciel polecił zatwierdzić cały obecny zakres, wraz z nowymi plikami, i wysłać go na origin/main mimo dwóch opisanych wcześniejszych błędów. Następny zakres wybierze właściciel.

Plan zatwierdzany punkt po punkcie przez właściciela. Każdy punkt: test lub sonda czerwona przed zmianą, zmiana, sekcje `ZMIANY-<wersja>.txt` / `ODBIOR-<wersja>.txt` w `docs/HISTORIA.md`, wiersz tutaj. Obecnie pracujemy na Linuxie: `scripts/linux/TEST.sh All --timeout 1800`; każdy zakończony zakres domykaj commitem po wymaganej weryfikacji, zgodnie z `docs/AGENTS.md`; push wymaga polecenia właściciela.

| Punkt | Co | Stan | Dowód / uwagi |
|---|---|---|---|
| P0 | Decyzje właściciela (lista w raporcie, rozdział 9) | zrobione 2026-11-03 | D11–D20 w `docs/WIZJA.md`; elity: animacja i od razu krótsze okna |
| P1 | Błędy: duplikowanie relikwii przez śmierć; czas animacji `storm`/`salvo` | zrobione (0.45) | P1a: test pilgrimage czerwony → zielony, golden „human” odświeżony; P1b: test attack-followups, golden bez zmian |
| P1c | Elity: krótsze okna (D11) — odsłonięcie 1,5/1,6 → 1,2 s, regeneracje 1,5 → 1,2 s | zrobione (0.45), do oceny w grze | sonda 4 strategii: okrążanie z wygranej do 3/4 porażek, czytanie ciosów bez zmian |
| P2 | Dźwięk: cztery suwaki i kategorie | zrobione (0.45), do odsłuchu | test w `app`; łyk podłączony do `sip` 2026-11-04, potwierdzenie tylko za leczenie |
| P3 | Ekran: hierarchia informacji, bez SHIFT w niszy | zrobione (0.45), do akceptacji | testy interfejsu i audyt układu |
| P4 | Animacje i efekty (Astra): elity, flaska, promień Stolasa, amunicja | kolejna wersja malarska 2026-11-04, do oceny | `work/reszta/RAPORT.md`; 55 arkuszy efektów, audyt stylu; czasy elit i maski bez zmian |
| P5 | Sklep przy ognisku: start z Judge'em, Exorcist za dusze, hartowanie +I | zaimplementowane; odbiór tras NIEZALICZONY | zakup i migracje przetestowane; 3/3 porażki bota przed i po, bez braku amunicji; `work/reszta/RAPORT.md` |
| P6 | Sigile: pojemność, zakładanie przy ognisku, pierwsze cztery | zaimplementowane 2026-11-04 | Stolas/Furfur/Buer/Paimon, 4 punkty, ręczny wybór, migracja starych pasywów, testy naliczeń; `work/reszta/RAPORT.md` |
| P7 | Próba właściciela i pomiary; potem +II, kolejne sigile, ewentualne okna elit | wstępna ocena 2026-11-04: „na razie dobrze”; pełny odbiór otwarty | właściciel chce jednego celu naraz i sam poda następny zakres; +II, nowe sigile i zmiany elit niezatwierdzone |

Aktualizacja 2026-11-04: cały zakres kodu, grafiki i dźwięku wykonała Astra sama, bez delegacji i bez commitów, zgodnie z bieżącym poleceniem właściciela. Historyczny podział wykonawców poniżej nie opisuje tej realizacji. Pełny wynik testów i ograniczenia są w `work/reszta/RAPORT.md`.

## Raport końcowy (2026-11-03): czytelność walki, ekran, ogniska jako sklep, dźwięk, animacje, znajdźki

Wersja 0.44, commit `5fecf90`. Dwie niezależne analizy na tym samym prompcie: Claude (Opus 5.5) i Codex Astra (`gpt-6-astra`, xhigh), w osobnych klonach. Astra uruchomiła pełne testy (zielone: 6044 + 50), własne sondy 120 Hz i 110 klatek PNG; Claude czytał kod i rendery z pełnego przebiegu. Pełne teksty obu analiz są w `docs/HISTORIA.md` (rozdziały „Analiza 2026-11-03b: Claude” i „…: Astra”); dowody Astry (PNG, CSV, sondy) leżą w jej klonie `C:\Users\nahiko\Documents\dev\sigil-analiza-astra\work\analiza\` (poza gitem, do usunięcia po przeczytaniu). Nikt nie grał ręcznie ani nie słuchał dźwięku: odczucia właściciela są danymi, ocena obrazu przez modele jest hipotezą.

**Wniosek główny (zgodny w obu analizach):** gra często nie pokazuje *przyczyny przed skutkiem*. Zdarzenia są poprawne w symulacji, ale ciało stwora, ręka rycerza albo efekt nie opowiadają, co się dzieje. Lekarstwem nie są nowe napisy, tylko jedna zasada dla każdego ataku i czynności: **źródło → napięcie → wypuszczenie → skutek → powrót**. Do tego dwa prawdziwe błędy, brak funkcji w dźwięku i porządki na ekranie. Sklep przy ognisku jest dobrym kierunkiem, jeśli role rozwoju będą rozdzielone.

### 1. Promień (włócznia) Stolasa — klimat zamiast taśmy

**Stan.** `star-lance` (`content/creatures/stolas.lua:132`): windup 0,6 s, ostrzeżenie 0,45 s, długość 14 m. Pole z `rites-fresco-v36.png` (komórka `ray`, alfa ostrzeżenia 0,48, kafel co 1,5 m). Pomiar Astry: pas pojawia się w 0,600 s, zagrożenie w 1,042 s, ciało wraca do ruchu w 1,600 s. Obie analizy: rdzeń z 0.44 jest czytelny, ale płaski i nieruchomy — „namalowana szyna”. Mechanika jest poprawna.

**Inne gry.** Halo i Destiny 2: ładowany atak ma świecące źródło, ścieżkę i błysk wyzwolenia. Returnal: rodziny kształtów i ruchu pocisków. Hades: zapowiedź obszaru, której wypełnienie pokazuje czas. Doom Eternal: groźne pociski odróżniają się sylwetką od dekoracji.

**Rekomendacja (obie analizy).** Zostaje rytuał na ziemi; zmienia się materiał i dochodzą trzy fazy na *istniejących* zegarach:
- gest i punkt skupienia przy dziobie Stolasa przez 0,6 s windupu;
- tor z narastającymi pęknięciami przez 0,45 s ostrzeżenia, czyli postęp widać;
- krótki płomień przy aktywacji i gasnące odłamki.
Materiał: nadpalone złoto i kość z ciemnym pęknięciem, z nieregularnością pigmentu, która maskuje powtórzenie kafla. Odrzucone: włócznia lecąca z dłoni (inny atak, zmiana złotego wzorca).

**Odbiór.** Czasy i trafienia identyczne co do kroku, złoty wzorzec bez zmian. Kontrast lokalny rdzenia ≥ 3:1 (luminancja z PNG). Ostrzeżenie i uderzenie rozróżnialne na jednym kadrze. Ocena klimatu: właściciel.

### 2. Furfur i Margrave — „zacinanie się”, brak zapowiedzi, odsłonięta garda

**Ustalenia.**
- **Furfur nie strzela lecącymi pociskami.** `lightning` znaczy miejsce pod rycerzem i po 0,72 s spada tam piorun (`ranged_kinds.lua` `Kinds.strike`). `storm-steps` to pięć znaków co 0,42 s, każdy z opóźnieniem 0,62 s. Pociskiem jest `cinder-spear` Margrave'a (16 m/s, windup 0,62 s). Zmierzone czasy (Astra, 120 Hz):

  | Atak | Wypuszczenie | Pierwsze zagrożenie | Ciało rusza się |
  |---|---|---|---|
  | `lightning` | 0,725 s | 0,725 s | 1,750 s |
  | `storm-steps` | 0,600 s | 1,225 s | 3,383 s |
  | `ash-lance` | 0,650 s | 1,292 s | 1,383 s |
  | `cinder-spear` | 0,625 s | 0,625 s | 1,608 s |

- **Błąd prezentacji (Astra, potwierdzony w kodzie).** Animacja `storm-steps` liczy postęp względem `spec.duration` 0,4 s (`enemies/action_phase.lua:36`, `:52`), a atak trwa `(count−1)×interval+duration` = 2,08 s (`ranged_kinds.lua:261`). Furfur stoi na jednej klatce `strike` (11) przez **1,875 s**, a pięć wyładowań pada bez gestu. Ten sam wzorzec grozi rodzajowi `salvo` (`ranged_kinds.lua:236`). To jest „zacinanie się”, nie zawieszona SI.
- **Brak gestu źródła.** Błyskawica używa ogólnych klatek zamachu porożem (`windup = {7,8,9}`, `strike = {10,11}`, `content/art/sheets/furfur.lua`). Nie ma pozy rzucania, ładunku na porożu ani linii do znaku. Znak leży pod nogami, a w FPS gracz patrzy na stwora, więc „nic z niczego nie wynika”. Dźwięki `storm_warning`/`storm_release` istnieją, ale w miksie ginie ich rola (zob. punkt 5).
- **Odsłonięta garda** trwa 1,5 s (Furfur) i 1,6 s (Margrave), zmierzone 1,508/1,608 s. Przez całe okno widać *jedną* klatkę bólu (`pain = {13}` / `{9}`) z kołysaniem `sin(t×6)×0,06` (`combat_defaults.exposedReel`, `enemies/animation.lua:101–111`). Kołysanie jednej klatki czyta się jak drganie, nie jak cierpienie.
- **Regeneracja po ciosie.** Ciało stoi najwyżej 0,7 s (`combat_defaults.lua:56`, `actions.lua:202`), potem może iść, ale nie atakuje, dopóki nie wyda pełnego `recover` (decyzja 0.43, okno kary). Margrave ma po jednej klatce `recover`/`strike`/`pain`; okna są celowe, ale nieruchome.
- **Ryzyko architektury (Astra).** Klatka pozy wybiera maskę trafień (`enemies/pose.lua:28`, `enemies/surface.lua:84`). Zmiana postępu pozy albo atlasu może przesunąć trafienia przy tych samych zegarach. Każdą zmianę pozy elity trzeba sprawdzić trafieniami w głowę, korpus i krawędź w każdej fazie.

**Inne gry.** Monster Hunter: ciężar, osadzenie nóg i uniesienie poroża przed wyładowaniem; okno zmęczenia *wygląda* jak zmęczenie. Sekiro i Bloodborne: utrata równowagi i klęk to animacja kilku klatek, a okno jest krótkie i czytelne. Elden Ring: opóźnione ciosy (przytrzymania) są treścią walki. Darktide: charakterystyczne dźwięki zagrożeń słychać poza polem widzenia.

**Rekomendacja (obie analizy).** Najpierw naprawić prezentację, nie skracać okien:
1. **Kod (Claude).** Jedno autorytatywne źródło długości akcji dla animacji `storm` i `salvo`. Zegary SI, zdarzenia i złoty wzorzec bez zmian.
2. **Grafika (Astra).**
   - Furfur: gest `windup/strike.lightning` z uniesionym porożem i rosnącymi wyładowaniami; w ostatnich ~0,25 s drgająca nić od poroża do znaku; akcent przy każdym z pięciu piorunów `storm-steps`.
   - Odsłonięta garda obu elit: mocne ugięcie w pierwszych 0,15–0,25 s, potem osłabiona poza z oddechem (2–4 klatki zamiast kołysania jednej) i powrót w ostatnich ~0,2 s.
   - Margrave: wyraźniej rozdzielone gesty przygotowania i powrotu. Regeneracja z ruchem (oddech, opadające ostrze).
3. **Dopiero potem, jeśli właściciel nadal widzi za długie okno.** Osobna próba jednej liczby (np. Furfur exposed 1,5 → 1,3 s) z pomiarem egzekucji. To świadomie trudniejsza walka, nie poprawka animacji.

**Odbiór.**
- Żadna poza nie trwa ponad 0,45 s bez akcentu (test na danych: najdłuższy odcinek jednej klatki w każdej pozie i ataku).
- Czasy z tabeli i trafienia bez przesunięć większych niż krok; `creature-pressure` i złoty wzorzec zielone.
- Właściciel rozpoznaje „ładuje / wypuścił / odsłonięty”.

### 3. Ekran — za dużo informacji

**Stan.** Render `17-combat-wide.png` i ujęcia Astry: w spokoju nad sceną widać trzy panele (lokacja, „TAB MAP / F1 HELP” z zegarem, interakcja), a przy zmęczeniu pięć grup nad dolnym HUD-em. Wytrzymałość występuje dwa razy: pasek 280 px nad HUD-em (gdy < 100%, `ui/hud.lua:293`) i w niszy narzędzi ikona + napis „SHIFT” + miernik 32 px (`ui/hud.lua:266–273`). Do tego centralne napisy stanu (`OUT OF BREATH`, `OFF BALANCE`, `DRINKING`, odmowy, `:387`), pasek i suma obrażeń zwykłego celu (`:425`), medal z opisem efektu (`:521`), panel braku amunicji (`:488`), hinty (`:554`, `:573`), DEATHS w niszy dusz.

**Inne gry.** Dark Souls i Elden Ring: zasoby zawsze w jednym miejscu, paski zwykłych wrogów pojawiają się po trafieniu i gasną. Dead Space: ręka i sprzęt opowiadają czynność. God of War: kierunek i priorytet ostrzeżenia ważniejsze niż ilość tekstu. Call of Duty: nagroda krótka i natychmiastowa.

**Rekomendacja (obie analizy; dolny pasek kompozycyjnie bez zmian).**
- Usunąć napis „SHIFT” i miniwskaźnik z niszy; pasek nad HUD-em zostaje jedynym wskaźnikiem wytrzymałości. Pustego miejsca nie zapełniać.
- Panel pomocy i zegar: tylko w pauzie, na mapie i w pierwszych minutach nauki; zegar jako opcja. Nazwa miejsca pojawia się przy wejściu i gaśnie.
- Pasek zwykłego celu: po trafieniu, gaśnie po zejściu z celu. Garda i ślad straty zostają, bo uczą skutku strzału. Suma obrażeń domyślnie ukryta.
- Jedna kolejka wiadomości: naraz jedna przyczyna lub ostrzeżenie i najwyżej jedna krótka nagroda. Medal bez prozy efektu w walce. `OUT OF BREATH` tylko po nieudanej próbie. `DRINKING` znika, gdy gest flaski sam będzie czytelny (zostaje jako opcja pomocy).
- DEATHS i statystyki do podsumowania lub menu.
- Trzy ustawienia: `Tutorial hints`, `Combat details`, `Timer`.

**Odbiór.**
- Ilustracje i ramy dolnego HUD-u identyczne; zmienia się tylko uzgodniona treść.
- W eksploracji zero stałych paneli nad sceną po wygaśnięciu nazwy miejsca. W walce najwyżej dwie wiadomości prozą.
- Rendery w 5 formatach do akceptacji właściciela.

### 4. Ognisko jako sklep — bronie, ulepszenia, sigile

**Stan (Astra, z kodu).**
- Nowa gra zaczyna z Exorcistem i Judge'em, portfel 0. Judge: 70 obrażeń, bęben 6, bezpiecznik amunicji: poniżej 6 nabojów odzyskuje 1/s (`tuning.lua:118`).
- Przy ogniu: Flaska I/II 150/338, Wigor I/II 120/270, hartowanie jednej z dwóch broni 250 (×1,08); razem 1378 dusz.
- Grawery (po jednym na broń) i sigile (2 miejsca, do 3 rang) znajduje się w świecie i *zakładają się same* (`run/pilgrimage.lua:45`).
- Dochód z jednego przejścia: nawa 320, krypta 200, zachód 160, wschód 240, Margrave 250, Furfur 250, razem 1420. Na mapie leży 19 pakietów amunicji: 13 do Judge'a (126 nabojów) i 6 do Exorcista (28 łusek).

**Błąd (Astra, odtworzony sondą).** Tę samą unikalną relikwię można podnieść, zginąć i podnieść ponownie: ranga `relic_stolas` rośnie 1 → 2 → 3, a `run.taken` nadal jest false. Przyczyna: trwała zmiana `vows` przy podniesieniu (`run/pilgrimage.lua:51`), a zabranie utrwala się dopiero w `secure` (`:469`). Do naprawy przed jakimkolwiek stakowaniem.

**Uwaga projektowa.** Niezabezpieczeni wrogowie wracają po śmierci, więc dusze można odrabiać (40 → śmierć → echo → 80). 1420 to dochód z jednego czyszczenia, nie twardy limit. Obie analizy: zostawić ryzykowne odrabianie (souls-like), nie projektować obowiązkowego grindu. Granicą buildu ma być pojemność sigili i wybór graweru.

**Inne gry.**
- Killing Floor 2: waluta za walkę, sklep i ulepszenia broni w chwili oddechu.
- Bloodborne: rozwijasz ulubioną broń zamiast ją wyrzucać.
- Resident Evil 4: kupiec, kupno i ulepszanie konkretnych broni, jasny skutek zakupu.
- Hollow Knight: amulety zużywają różną liczbę miejsc, a koszt miejsca jest przeciwwagą.
- Hades: efekty zależne od sposobu gry.
- Elden Ring: waluta przy śmierci zostaje do odzyskania, kupione rzeczy nie przepadają.

**Rekomendacja (połączona).** Pomysł właściciela łączy filary: Doom w biegu i Souls przy ogniu. Role rozwoju rozdzielone, tak żeby każda warstwa miała jedno zadanie:

| Warstwa | Rola | Jak się zdobywa |
|---|---|---|
| Waluta | dusze (nazwa do decyzji; rekomendacja: SOULS) | zabójstwa; po śmierci echo jak dziś |
| Bronie | nowy sposób walki | kupno przy ognisku; trwałe, nie przepadają po śmierci |
| Hartowanie | moc konkretnej broni | dusze; +I 250 (×1,08), +II 350 dopiero po teście +I |
| Śluby | odporność na błędy (HP, łyki) | dusze; zostają Wigor i Flaska jak dziś |
| Grawery | charakter konkretnej broni | znajdźki; jeden na broń, darmowa wymiana przy ogniu |
| Sigile | zachowanie rycerza, decyzje buildu | tylko znajdźki; stakują się fizycznymi kopiami; zakładane i zdejmowane *wyłącznie* przy ognisku |

- **Start:** nowy zapis ma tylko Judge'a (z bezpiecznikiem amunicji, jak w KF pistolet z nieskończoną amunicją).
- **Exorcist za 300** przy każdym zapalonym ogniu. Po nawie (320 dusz) wybór: strzelba (zostaje 20) albo Wigor I + Flaska I (zostaje 50).
- **Pierwsza iteracja tylko na dwóch istniejących broniach.** Trzecia broń wymaga osobnej roli i budżetu grafiki.
- Stare zapisy zachowują obie bronie.
- Odnowienie zapasów przy odpoczynku pozostaje darmowe.
- **Ognisko jako jedno miejsce z trzema stacjami:** `Arsenal` (zakup, hartowanie, grawer na karcie broni), `Vows`, `Sigils` (kolekcja i pojemność). Każda oferta pokazuje „przed → po” i powód blokady („brakuje 8 dusz”).

**Sigile: katalog do prototypów (Astra; liczby to nowy balans do testu).**

Zasady:
- 4 punkty pojemności. Pierwsza kopia kosztuje 1–2 punkty, każda następna tego samego rodzaju +1, maksimum 3 kopie.
- Premie obrażeń z sigili sumują się do +35% na jedno trafienie.
- Każdy efekt sprawdza zdarzenie, żeby nie naliczyć go dwa razy.

| Sigil | Efekt I / II / III | Punkty | Przeciwwaga |
|---|---|---|---|
| Stolas — *Measured Verdict* | 2 trafienia Judge'a w ten sam cel uzbrajają trafienie w głowę: +15/25/35% | 1/2/3 | korpus Judge'a −10% |
| Furfur — *Storm's Reply* | po doskonałym uniku pierwszy strzał w 2 s: +20/30/35% | 2/3/4 | unik +4 wytrzymałości (26 → 30) |
| Buer — *Red Reprisal* | pierwsze trafienie z ≤ 4 m po otrzymaniu ciosu odzyskuje 8/12/16 HP z puli do odzyskania | 1/2/3 | flaska leczy o 10 mniej |
| Paimon — *Last Chamber* | po przeładowaniu pustej broni pierwszy strzał +20/35/50 impetu | 2/3/4 | przeładowanie +0,2 s |
| Andrealphus — *Narrow Mercy* | po doskonałym uniku Exorcist zwęża stożek do 85/75/65% kosztem 2/3/4 śrucin | 1/2/3 | mniej łącznych trafień |
| Valefor — *Tithe of Iron* | egzekucja daje 1/2/3 naboje Judge'a albo 1/1/2 łuski | 1/2/3 | −20% dusz |
| Sabnock — *Rooted Oath* | po ≥ 0,4 s bez ruchu następny cios ma −20/30/40 impetu (co 3 s) | 2/3/4 | unik +6 wytrzymałości |
| Marbas — *Bitter Draught* | udana flaska odnawia 12/18/24 ward | 1/2/3 | picie +0,15 s |

Propozycje Claude'a do rozważenia później:
- *Pokuta*: +25% dusz, ale echo po śmierci przepada w całości; nie stakuje się.
- *Cisza*: stwory budzą się później.
- *Ostatni dech*: przy HP < 25% ataki +20%, flaska nie leczy ponad 50%.

Pierwszy test: Stolas, Furfur, Buer, Paimon i dwie dodatkowe kopie w sekretach. Na mapie jest dziś 7 relikwii, więc trzeba trzech nowych miejsc i przeglądu tempa eksploracji.

**Odbiór.**
- Nowy zapis ma tylko Judge'a. Zakup Exorcista pomniejsza portfel raz i przetrwa śmierć, odpoczynek, podróż i Continue.
- Ten sam `rewardId` nie podnosi rangi po śmierci ani po restarcie.
- Sigil nie działa, dopóki nie zostanie założony przy ogniu.
- Łańcuch portfela i echa daje znane kwoty.
- Kaplicę da się ukończyć bez farmienia i bez obowiązkowego Exorcista (trzy trasy bota).
- Każda zmiana balansu osobno.

### 5. Dźwięk — osobny suwak efektów

**Stan (obie analizy, kod).** Jest jedna wartość `music` (etykieta „Music and ambience”, `storage/preferences.lua:10`) i `muted`. Efekty grają z masterem 0,7 (`audio/audio.lua:232`) i własnym poziomem (`:174`), bez suwaka. Suwak muzyki mnoży tylko pętle score (`soundscape.lua:323`). Część odgłosów pomieszczeń (`crypt_drip`, `stone_creak`, `chain_settle`, `audio/world_cues.lua:93`) idzie torem efektów, więc nie reaguje nawet na suwak „ambience”. Pomiar Astry: przy muzyce 0 strzał, kroki, warczenie i burza mają nadal gain ok. 0,65.

**Inne gry.** God of War Ragnarök ma osobno ogólną, efekty, dialogi i muzykę, plus opcje dostępności. Hunt: Showdown traktuje dźwięk otoczenia i kierunek jako informację. Elden Ring ma BGM, SFX i głos. Wniosek: rozdzielać to, co w grze rzeczywiście istnieje.

**Rekomendacja.** Cztery suwaki: **Master, Effects, Music, Ambience** (interfejs i ostrzeżenia pod Effects, odgłosy pomieszczeń pod Ambience). Poziom końcowy = master × kategoria × gain zdarzenia × przestrzeń × ściszenie kontekstowe, liczone od wartości bazowej. Zmiana działa też na grające pętle. Migracja: stary `music` przechodzi do Music i Ambience. Miks (do odsłuchu): ostrzeżenia mają pierwszeństwo, muzyka jest ściszana jak dziś (~−6 dB), ambient w walce o 3–6 dB ciszej. Wybór zestawu brzmień (F7) to osobna sprawa.

**Odbiór.** Effects = 0 daje dokładne zero strzałów, kroków, stworów i ostrzeżeń. Ambience = 0 wycisza krople i łańcuchy, a nie pioruny ataku. Master = 0 wycisza wszystko, także po restarcie i recyklingu źródeł.

### 6. Picie z flaski — „wylewa za siebie”

**Stan.** Atlas `flask-hands-v44.png`: 6 klatek, ręka idzie w lewo do −0,14 wysokości ekranu i obraca się do −0,20 rad (`content/equipment_art.lua:124`). Fazy zmierzone przez Astrę: held 0–0,15, raise –0,32, mouth –0,44, sip 0,45–0,65, recover –0,79, lower –0,95 s; leczenie 45 HP przy 0,958 s. Obie analizy: przedramię przechodzi przez środek kadru, flaska obraca się w płaszczyźnie obrazu, a szyjka kieruje się w bok. Brak skrótu perspektywicznego ku ustom pod kamerą, stąd wrażenie wylewania. **Dodatkowy błąd (Astra):** około 0,9 s ręka z flaską już znika i broń wraca, choć picie i blokada jeszcze trwają.

**Inne gry (pierwsza osoba).** Resident Evil 7/Village i Hunt: Showdown pokazują przedmiot blisko kamery i sekwencję „przygotuj → użyj → odłóż”. Dark Souls i Elden Ring (trzecia osoba) uczą, że uniesienie i przechył uzasadniają okno podatności, ale poza kamery się nie przenosi. Monster Hunter: leczenie jako decyzja taktyczna.

**Rekomendacja.**
- Przemalować klatki mouth/sip/recover (ta sama rękawica i naczynie). Szyjka zbliża się do ust tuż pod kamerą i częściowo wychodzi poza kadr, dno unosi się ku górze ekranu.
- Tor ręki bez wyjazdu w lewo.
- Gest kończy się razem z faktycznym końcem picia.
- Dźwięk łyku. „Sukces” (światło, dźwięk) dopiero przy leczeniu, bo cios w 0,8 s nadal przerywa picie.
- Czas 0,95 s bez zmian.

**Odbiór.** Bez napisu DRINKING obserwator rozpoznaje picie. Klatki w 0,2/0,4/0,5/0,7/0,9 s w 5 formatach. Leczenie, zużycie, przerwanie, śmierć i Continue jak dziś; złoty wzorzec bez zmian.

### 7. Znajdźki amunicji — klimat i widoczność

**Stan.** Dwa obrazy 128×128 (trzy czerwone łuski, papierowy pakiet nabojów), rozmiar w świecie 0,48, jasność 0,85 × światło pomieszczenia, bez unoszenia i poświaty (`content/supplies.lua:9`, `render/world_art.lua:105`). Ujęcia Astry: z 4 m kształty są rozróżnialne, z 8–12 m zlewają się z brązową posadzką. Wyglądają użytkowo, bez związku z rytuałem.

**Inne gry.** Doom: natychmiastowa sylwetka i szybkie podniesienie. Resident Evil 4: przedmiot ma „ciało” i opakowanie. Prey i Dishonored: ustawienie w przestrzeni prowadzi wzrok. Destiny 2: rodziny amunicji rozróżnialne kolorem, czego jednak nie przenosimy wprost do fresku. Souls: świecące znaleziska widać z daleka.

**Rekomendacja.**
- **A (najpierw):** wyraźniejszy materiał i sylwetka w obecnym rozmiarze. Łuski spięte ciemnym drutem z jasnymi denkami. Naboje Judge'a w lnianym zawiniątku z czerwonym znakiem (nie okrągłym, żeby nie mylić z sigilem). Cień kontaktowy. Ułożenie obok martwego pielgrzyma, skrzynki albo zgasłej świecy.
- **B (po obejrzeniu A):** minimalny poziom własnego światła albo delikatny nimb świecy.
- Bez słupów światła, konturów i napisów AMMO.
- Później w tym samym stylu: leżące grawery i flaska (dziś używają ikon sklepu).

**Odbiór.** Pakiet widoczny w ≤ 2 s z 8 m, broń rozpoznawalna z 4 m, kontrast lokalny sylwetki ≥ 2,5:1 w większości miejsc. Próg podniesienia 0,7 m i zapasy bez zmian.

### 8. Pomysły i uwagi spoza listy

1. **Zasada sygnałów ataku** „źródło → napięcie → wypuszczenie → skutek → powrót” jako reguła w `docs/STYL.md` i test danych. Każdy atak ma pozę `windup.<id>` albo uzasadniony wyjątek. Żadna klatka nie trwa ponad 0,45 s bez akcentu. Każdy atak dystansowy ma źródło na ciele.
2. **Zagrożenie pod nogami a kamera FPS** (Astra, hipoteza). Gracz patrzy na stwora, nie na posadzkę. Wzmacniać gest sprawcy i kierunkowy dźwięk, zanim urosną znaki na ziemi. Rozważyć wskaźnik krawędzi ekranu dla ciosu zza pleców (jak w Halo i Destiny), bez nowej ściany HUD.
3. **Dźwięk jako informacja.** Wiele ataków dzieli te same zapowiedzi (`return_warning`, `antler_warning`). Rozróżnić rodzaje ataków brzmieniem.
4. **HP elit po naprawie prezentacji** (Margrave 2700, Furfur 2250). Zmierzyć cykle ataków do zwycięstwa, przełamania, egzekucje i czas bez własnej decyzji. Nie „naprawiać” monotonii większym DPS ze sklepu.
5. **Ognisko jako plan dalszej drogi.** Po zakupie krótko efekt, odkryte ogniska i kolekcja znalezisk. Decyzja typu „idę na wschód po sigil / wracam na elitę z nową bronią”.
6. **Znajdźki rozróżnialne formą przed podniesieniem:** pakiet / płytka graweru / okrągła pieczęć sigila.
7. **Testy znaczenia, nie tylko reguł.** 6044 sprawdzenia nie wychwyciły ani kompozycji picia, ani duplikowania relikwii. Potrzebne konkretne kontrakty: czas prezentacji obejmuje cały czas ataku, trwała nagroda nie wraca po cofnięciu świata. Dla grafiki: arkusz klatek zatwierdzany przez właściciela.
8. **Sklep potrzebuje treści.** Zanim powstanie więcej niż dwie bronie, zaprojektować 1–2 nowe o wyraźnych rolach (np. kusza z przebijającymi bełtami, ciężka broń do gardy). To największy koszt grafiki (Astra) i balansu.

### 9. Decyzje właściciela (przed startem)

**Rozstrzygnięte 3 listopada wieczorem: D11–D20 w `docs/WIZJA.md`.** Różnice wobec rekomendacji: elity dostają od razu także krótsze okna (D11); licznik DEATHS zostaje w niszy dusz (D18); kolejne bronie tylko na wyraźne polecenie właściciela (D20). Lista poniżej to pytania w brzmieniu z raportu.

1. Elity: najpierw naprawa prezentacji przy tych samych czasach okien (rekomendacja: tak). Skrócenie okien dopiero po obejrzeniu, jako osobna próba.
2. Promień Stolasa: rytuał na ziemi z nowym materiałem (rekomendacja), nie latająca włócznia.
3. Ekran: usunąć SHIFT z niszy; pomoc i zegar tylko w pauzie i na początku; suma obrażeń domyślnie ukryta; DRINKING tylko w pomocy (rekomendacja: tak dla wszystkich).
4. Dźwięk: cztery suwaki Master / Effects / Music / Ambience (rekomendacja: tak); możliwość pełnego wyciszenia Effects.
5. Sklep:
   - start tylko z Judge'em; Exorcist 300;
   - kupione bronie trwałe;
   - śluby i grawery zostają;
   - hartowanie +I teraz, +II po teście;
   - waluta pozostaje „SOULS”;
   - dopuszczamy ryzykowne odrabianie dusz.
6. Sigile:
   - tylko znajdźki, zakładane wyłącznie przy ognisku;
   - pojemność 4 punkty, kopie płatne pojemnością;
   - pierwsza czwórka do testu.
   - Znaleziony unikalny przedmiot zostaje po śmierci (rekomendacja), a nie wraca do świata.
7. Flaska: przemalowanie trzech klatek i szyjka częściowo poza kadrem (rekomendacja: tak).
8. Amunicja: wariant A, potem decyzja o B.
9. Trzecia broń: kiedy i jaka rola (nie blokuje P1–P6).

## Plan następnych kroków

Podział: **Claude** — kod gry, walka, testy, integracja i przegląd. **Astra** (xhigh, osobny klon, bez commitów) — grafika, animacje, dźwięk. Claude przegląda jej zmiany i commituje. Bez nagrań wideo; klatki PNG do oceny. Jedna zmiana balansu na commit. Golden zmieniany tylko świadomie.

| Krok | Co i kto | Zależy od | Nakład | Odbiór |
|---|---|---|---|---|
| P0 | Właściciel: decyzje z rozdziału 9 | — | — | zapis w `WIZJA.md` |
| P1a | Claude: atomowe nadanie i zużycie unikalnej znajdźki (`rewardId`), test śmierci, restartu i Continue | — | 0,5–1,5 dnia | sonda `relic-cycle` czerwona przed, zielona po; stare zapisy działają |
| P1b | Claude: autorytatywny czas animacji `storm`/`salvo`, audyt hold i cancel | — | 0,5–1,5 dnia | 1,875 s na jednej klatce znika; zdarzenia i golden identyczne |
| P1c | Claude: krótsze okna elit (D11): Furfur exposed 1,5 → 1,2 s, Margrave 1,6 → 1,2 s, regeneracje ≥ 1,5 s (overhead, ash-grip, ash-catch, crown) → 1,2 s; każda zmiana osobnym commitem | P1b | 1 dzień + sondy | `souls-gate`, `creature-pressure`, egzekucja nadal osiągalna; nowy golden świadomie |
| P2 | Claude: cztery suwaki, kategorie, routing ambience, migracja ustawień | P0.4 | 1–2 dni | macierz zer; pętle i pula głosów; odsłuch właściciela |
| P3 | Claude: hierarchia wiadomości, SHIFT poza niszą, kontekstowe panele i paski | P0.3 | 1–2 dni | 5 renderów do akceptacji; chroniony HUD identyczny |
| P4 | Astra: Furfur (gest błyskawicy i burzy, akcenty piorunów), odsłonięta garda obu elit, Margrave regeneracja; flaska (3 klatki + tor); promień Stolasa (3 fazy); znajdźki amunicji A. Claude: integracja i kontrola masek trafień | P1b dla burzy | 3–6 dni grafiki + 1–2 integracji | arkusze klatek do oceny; brak klatki > 0,45 s bez akcentu; trafienia bez przesunięć; golden bez zmian |
| P5 | Claude: sklep — start z Judge'em, Exorcist 300, migracja zapisów, stacje Arsenal/Vows/Sigils, hartowanie +I. Astra: karty broni | P1a, P0.5, bazowy przebieg bota z samym Judge'em | 2–4 dni | ukończenie bez grindu i bez blokady amunicji; zakup przetrwa śmierć i Continue |
| P6 | Claude: pojemność 4, ręczne zakładanie przy ogniu, pierwsze cztery sigile; Astra: ikony i leżące pieczęcie | P5 | 3–6 dni | każdy efekt osobno; brak podwójnych naliczeń; brak nowego panelu HUD |
| P7 | Właściciel gra; Claude mierzy ekonomię i walkę; Astra ocenia czytelność gestów i miks. Potem: +II, kolejne sigile, ewentualna próba okien elit, trzecia broń | P1–P6 | 2–4 sesje | jedna zmiana na próbę; wyniki gry właściciela jako osobny dowód |

**Równolegle:** P1a, P1b, P2, P3 i grafika flaski i amunicji. **Nie łączyć:** pomiaru nowych cen ze zmianą obrażeń elit, odzysku amunicji albo kosztu uniku. Przy dwóch wykonawcach pierwszy spójny pakiet (P1–P4) to ok. 1–2 tygodnie robocze, sklep i sigile (P5–P6) kolejne 1–2.

## Przeniesione z poprzedniego planu (niezrobione)

- **B02, próba właściciela** (elity, nawa, Continue, relikwie, chwianie elity, linia włóczni) — wchodzi w P7.
- **B03 / B04:** sonda zasobów i nawa, jedna zmienna — po P5, bo start z Judge'em zmienia zasoby.
- **C02:** wariant bez ognisk tylko po próbie właściciela; przy sklepie mało prawdopodobny.
- **Wybór zestawu dźwięku (F7: classic / iron / stone),** potem usunięcie przełącznika — razem z odsłuchem w P2.
- **Kontrast Iron Thralla w nawie** (cel ≥ 1,5:1; warianty Astry z 0.44 naruszały styl) — do P4 albo osobno.
- **Niezabezpieczeni zabici w innych obszarach** — przed dodaniem nowych obszarów.
- **Linux:** docelowo natywny Linux z prawdziwą kartą graficzną; WSL służył tylko do sprawdzenia skryptów. Tam przechodzi całość poza testem `weight`: WSL rysuje programowo (`llvmpipe`), a różni się 947 z 864 000 sprawdzonych pikseli, tylko jeden o więcej niż 2% jasności. Przy pierwszym `scripts/linux/TEST.sh All --timeout 1800` na nowym komputerze sprawdź, czy `weight` przechodzi; test zostaje ostry.
