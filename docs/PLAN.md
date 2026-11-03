# SIGIL: BREACH — plan rozwoju

Jeden bieżący plan. Gdy powstaje nowy plan, ten plik w całości trafia jako rozdział do `docs/HISTORIA.md`, a tutaj zostaje tylko nowy. Stan punktów jest w rozdziale „Postęp”.

## Spis rozdziałów

- Postęp (stan punktów)
- Plan z audytu 2026-11-03

## Postęp (stan punktów)

_Dawniej: `docs/audyt-2026-11-03/POSTEP.md`_

### Postęp planu po audycie z 3 listopada 2026

Plan: `RAPORT-KONCOWY.md`, decyzje właściciela: `DECYZJE.md`. Zakres zatwierdzony 2026-11-03: całość planu (Etapy 0–3) z R01 (laser), D02 (próbkowany dźwięk z odsłuchem A/B), D05 (mikro-zatrzymanie do testu); C02 (wariant bez ognisk) po próbie właściciela. Wersja 0.43.

Uwaga dla edycji z PowerShell 5.1: pliki są w UTF-8 bez BOM; czytać przez `[IO.File]::ReadAllText`, nie `Get-Content -Raw`.

| ID | Punkt | Stan | Dowód |
|---|---|---|---|
| A01 | Zielona brama i prawdziwe testy | zrobione | 4 asercje dopasowane do reguł 0.42; render menu ognia; drop ≠ skrytka; bot bierze tylko potrzebny zapas. souls-gate/souls-bots czerwone do B01 |
| A05 | Zegary AI i reakcja na unik | zrobione | `attack_followups.lua`: cios i odpowiedź po pełnej regeneracji (było 0,7 s), gore-return na unik w serii; oba czerwone bez naprawy |
| A03 | Bezpieczny odpoczynek | zrobione | `pilgrimage.lua` safeRest: plama po martwym Buerze nie rani po odpoczynku (bez naprawy rani), pocisk w drodze = odmowa |
| A06 | HUD, teksty, podpowiedź w ramie | zrobione | grawer broni w ręku; teksty bez odradzania; audyt 3 podpowiedzi × 5 rozdzielczości; komunikat sklepu poligonu w polu |
| A02 | Continue wznawia w miejscu (D9) | zrobione po przeglądzie Astry | pierwsza wersja (01dfef8) miała luki (wyjście bez zabójstwa, pociski, ciosy, resztki, dropy, rany); poprawione zapisem sekcji pools i flagą moved. Odłożone: niezabezpieczeni zabici innego obszaru (przed dodaniem obszarów) |
| A07 | Reguła procesu | zrobione | `game/docs/DEVELOPMENT.txt`, DODAWANIE TESTU 6–8 |
| A04 | Znajdźki | rozstrzygnięte (D10) | nie wracają po odpoczynku z decyzji właściciela; tylko teksty (A06) |
| B01 | Elity | częściowo: stanie i cofanie przegrywają; boty odruchowe i połowiczne wygrywają, ocena w B02 | patrz tabela niżej; souls-gate i souls-bots zielone |
| C01 | Rozwój w świecie (D8) | zrobione | relikwie w kaplicy, 2 miejsca na pieczęcie, śluby za dusze 1378 |
| D03 | Wstrząs wybuchu z odległością | zrobione | rules.lua: 2 / 10 / 20 m |
| R01 | Atak z laserem (Stolas, star-lance) | zrobione | attack_followups: linia przed uderzeniem, trafia stojącego, nie tego, kto zszedł |
| D05 | Mikro-zatrzymanie (do testu) | wycofane | wstrzymanie SI łamało creature-pressure; wersja wizualna do V01 |
| D02 | Próbkowany dźwięk A/B | zrobione, czeka na wybór właściciela | Astra: paczka B1/B2; F7 w grze przełącza zestawy |
| D04 | Nisza ARSENAL: broń w ręku czytelna | zrobione, czeka na zgodę właściciela | gui/arsenal-przed.png, arsenal-po.png |
| B01b | Elita otwarta: krócej i widocznie | zrobione | 1,6/1,5 s zamiast 2,8/2,6; chwianie i mocniejszy puls |
| V01 | Analiza obrazu i strzelania (Astra) | analiza zrobiona; P0 wdrożone | V01-ASTRA.md; linia włóczni 1,29 -> 1,52:1, narożniki gardy pełne 0,22 s; P1/P2 i grafika czekają na właściciela |
| D01 | Nagranie bazowe (Astra) | zrobione | Astra (high), 54 s, 6 scen; `work/film-baseline/` (baseline.mp4, baseline-phone.mp4, README, klatki kontrolne); czeka na ocenę właściciela |
| 0.44 | Czytelność trafienia, V01 P1/P2, picie z flaski (Astra ultra, przegląd Claude) | zrobione, czeka na ocenę właściciela | `RAPORT-ASTRY-044.md`; sonda 576 salw: 0 całych pudeł; ΔL* błysku po 33 ms 5,6–6,2 → 8,2–9,1; golden bez zmian |
| V01 tony | Rozjaśnienie Iron Thralla i Stolasa | otwarte | warianty Astry zmieniały sylwetkę i alfę; nie podmienione |

#### B01: pomiar elit (sonda 4 strategii, komnaty poligonu, bot z idealnym celem)

| Strategia | Margrave przed | Margrave po | Furfur przed | Furfur po |
|---|---|---|---|---|
| stoi i strzela | wygrana 13,5 s, 86% HP | porażka (2/2) | wygrana 10,6 s, 16% HP | porażka (2/2) |
| cofa się | wygrana, 84–89% HP | porażka (2/2) | wygrana, 15% HP | porażka (2/2) |
| okrąża | porażka po A05 | porażka (2/2) | wygrana, 88% HP | wygrana, 71% HP |
| czyta ciosy | wygrana 11–15 s | wygrana 12–13 s, 83–100% HP | wygrana 10 s | wygrana 15–17 s, 79–93% HP |

Zmiany: styl duel idzie trasą (Furfur stał zablokowany 9,3 s z 12 s), zasięg dystansowy elit 16–18 m (rycerz strzela do 42 m), HP 2700 / 2250. Sonda: `sonda-elity-main.lua` w tym katalogu.
#### Przegląd Astry (ultra, tylko odczyt) i odpowiedź

Pełny tekst: `PRZEGLAD-ASTRY.md`. P1 (Continue bez zabójstwa, wznowienie walki, resztki/dropy/rany, odpoczynek pod błyskawicą 18 m) naprawione i zakryte testami czerwonymi bez naprawy. P2: kwota w teście sklepu, przywracanie `spare`, komentarze — naprawione; obszary — odłożone; jedna zmienna na commit w B01 — złamana, odnotowane.

#### 0.44: przegląd zmian Astry

Astra (ultra) pracowała w osobnym klonie bez commitów; Claude przejrzał diff, przeniósł go łatką i puścił pełne `-Suite All` na `main`. Uwagi z przeglądu: osobne nadpisanie `automaticFireUntil` Exorcista dostało komentarz; nowy rdzeń promienia Stolasa czyta się lepiej (udział pikseli < 1,5:1 39 → 32%), ale jest płaski i szary wobec malowanego pola — osobny commit, łatwy do cofnięcia po ocenie właściciela; Judge IRON też osobno. Nie zrobiono: zamrożenia pozy trafionego (błysk spełnił cel), dźwięku łyku. Picie nadal blokuje unik (reguła stanu `drinking`), przerywa je cios, anulowanie i śmierć.

#### Uwagi właściciela 2026-11-03 (do zrobienia po reszcie planu)

- **B01b, elita „zacięta”**: elita z pękniętą gardą (EXPOSED) stoi i wygląda jak zawieszona; wskaźnik ogłuszenia ma być wyraźniejszy, a ogłuszenie trwa za długo, także przy ładowaniu czaru, co ułatwia walkę.
- **V01, analiza z Astrą po naprawach**: odbiór obrazu przez człowieka (kolorystyka, kontrasty, czy rzeczy się zlewają), znaczniki (zabójstwo, celownik) i — bardzo ważne — odczucie strzelania.

## Plan z audytu 2026-11-03

_Dawniej: `docs/audyt-2026-11-03/RAPORT-KONCOWY.md`_

### Raport końcowy: SIGIL: BREACH 0.42, commit `f69a19b` (2026-11-03)

Synteza dwóch niezależnych audytów: `AUDYT-CLAUDE.md` i `AUDYT-ASTRA.md` w tym katalogu. Surowe dane Astry: `dane-astry/`, moja sonda: `sonda-continue.lua`. Plan jest propozycją modeli, **właściciel go nie zatwierdził**.

#### 1. Stan projektu i zakres weryfikacji

0.42 to grywalny poligon: kaplica, 15 stanowisk (2 elity), 4 ogniska, 2 bronie, Q, F, zapis w 3 slotach. 2 listopada wprowadzono w jeden dzień ok. 10 zmian pętli (znajdźki jak w Doomie, grawery i hartowanie na broń, pieczęcie Goecji, krótkie elity 1680/1400 HP, ognisko zabezpieczające zamiast odradzania, odnawianie Judge'a do 6 naboi, poprawki AI). **Pełne QA na `f69a19b` nie przechodzi** (6 FAIL w Mechanics, oba audyty niezależnie).

| | Claude | Astra |
|---|---|---|
| Model i poziom | Opus 5.5 | `gpt-6-astra`, `reasoning_effort: ultra` (potwierdzone w `turn_context` logu sesji Codexa; dostępne też `max`) |
| Prompt | `PROMPT-AUDYTU.md`, SHA-256 `CBCA92B8B1C12977…25B1` | ten sam plik bajt w bajt (stdin) |
| Kod | klon `sigil-audit-claude-1103` na `f69a19b` | klon `sigil-audit-astra-1103` na `f69a19b`, piaskownica workspace-write, bez sieci |
| Materiały | te same: repo + podręczniki właściciela + pliki `.md` z `work/*-consult`, `work/brainstorm`, `work/sounds/notes.md` | identyczne kopie |
| Niezależność | audyt zapisany przed odczytem Astry (SHA `D642D744…`, z dopiskiem sondy `1FFD9AD4…`, 10:20); wynik Astry otwarty po jej zakończeniu (10:48) | nie widziała mojego wyniku |
| Uruchomione | `TEST -Suite All`, `--chapel-look` 1280×720, sonda Continue | `-Suite All`, `Input`, `Render`, `Tools`, rendery w 5 rozdzielczościach, benchmark, core-measure, 2× frame-watch, zimny start ×3, sonda stanu, 48 walk w komnatach, 6 przebiegów kaplicy po 180 s |

Różnice w dostępie: znałem brief sesji nadrzędnej (streszczony w prompcie dla obu). Mój `-Suite All` szedł równolegle z pierwszą częścią pracy Astry, więc jej pomiary czasu mogły częściowo nakładać się na moje testy; jej mediany (4,15–4,55 ms) zgadzają się z pomiarem z ZMIANY-0.42 (3,93 ms), maksima 982/1000 ms są niewyjaśnione. Żaden model nie grał ręcznie i nie słuchał dźwięku.

#### 2. Porównanie

##### Wskazane przez oba modele

| Temat | Claude | Astra | Stanowisko |
|---|---|---|---|
| Czerwona bramka | U01 | F05 | potwierdzone; 4 testy są nieaktualne wobec celowych zmian (cena Focus 100 → 180, odnawianie Judge'a, wytrzymałość elit, zapas w trakcie przeładowania), 2 (`souls-gate`, `souls-bots`) to prawdziwy sygnał projektowy |
| Elity przegrywają z prostymi strategiami | U02: bot stojący wygrywa z Margrave'em w 13,5 s | F06: 48/48 walk wygranych przez 4 strategie, Furfur nieruchomy 10,6 s | potwierdzone; wniosek dotyczy bota z idealnym celem, nie ludzi |
| Continue = darmowy odpoczynek i farma | U04, sonda: portfel 120 zostaje, HP 20 → 100, 3/3 zabitych wraca | F01, sonda z prawdziwym plikiem: to samo plus pełna amunicja i łyki | potwierdzone dwiema sondami |
| Podpowiedź ogniska poza ramą | U05 (1280×720) | F07: x 19–476 wobec bezpiecznego 32–464, wszystkie 5 formatów | potwierdzone |
| Render `fire-menu` pokazuje odmowę | U06 | F05 | potwierdzone |
| Dusze: 1420 za przejście, katalog 4759 | U03 | ta sama arytmetyka | fakt; ocena różna (niżej) |
| Fizyka spójna, nie przepisywać | tak | tak | zgoda, potwierdzona kodem |
| Pociski stworów to osobne obiekty x/y/z, v, promień | tak | tak; strzały rycerza to hitscan | zgoda |
| Broń stwora: częściowo oddzielona (ciosy jako dane, tasak jako blokująca część maski) | U07 | O02 | zgoda: rozwijać tylko przy konkretnym zastosowaniu |
| Uniki nie są „darmową ucieczką” | U08 | tak | zgoda |
| Soczystość istnieje w kodzie | U11 | tak | zgoda; ocena siły wymaga nagrania i odsłuchu |
| Ogniska: zostawić, rozwój przesuwać w świat / porównać wariant | tak | tak, z eksperymentem O01 | zgoda |

##### Tylko Astra (wszystkie sprawdziłem w kodzie)

| Ustalenie | Weryfikacja |
|---|---|
| F02: odpoczynek przy ognisku przy żywej plamie trucizny po martwym Buerze; po odpoczynku 100 → 92,8 HP | `fighting` sprawdza tylko ciała (`run/pilgrimage.lua:314-319`), `interact` nie czyści zagrożeń; sonda Astry. **Potwierdzone** |
| F03: zebrane znajdźki nie wracają ani po odpoczynku, ani po śmierci, choć właściciel wybrał wariant „wracają przy odpoczynku i śmierci” (ZMIANY-0.42, commit `0747889`) | `secure` wpisuje je do `run.taken` (`:338-340`), `populate` ich nie kładzie (`:82-86`); zmienił to późniejszy krok hybrydy `1268d37`. **Potwierdzone**; przeoczyłem to |
| F04: skrócona regeneracja po ciosie i nieosiągalna reakcja na unik | `Attacks.rest` (`enemies/actions.lua:205-209`): `recover` ≤ 0,7 s, reszta w `attack`, oba liczą równolegle. **Doprecyzowanie:** przed `f043139` też liczyły równolegle (odstęp = max(recover, cooldown)); teraz odstęp zwykłego ciosu kurczy się zależnie od danych (cleave 1,2 → 1,1 s; przy małym cooldownie do 0,5 s krócej), a **odpowiedzi pilne** (przeładowanie, picie) czekają tylko na `recover`, czyli ≤ 0,7 s zamiast 1,2 s (`ai.lua:351-385`). Commit obiecywał, że okno zostaje. Reakcja `dodged` nieosiągalna — opisana już 2 listopada, nadal otwarta |
| F07: HUD pokazuje grawer drugiej broni | `P.hud` nie przekazuje `worn` (`run/pilgrimage.lua:635-639`), HUD bierze `run.glyph` (`ui/hud.lua:184-191`). **Potwierdzone** |
| Teksty obiecują odradzanie przy ognisku | `content/text.lua:148, 282` („raise every creature”, „rises when you do”), `:171` „One is active”. **Potwierdzone** |
| F08: pierwsza klatka menu po zimnym starcie ok. 0,92 s | pomiar Astry ×3; przyczyna niepewna. Nie sprawdzałem |
| Wstrząs prochu bez zależności od dystansu | `feedback/world_feedback.lua:154-158` (stałe `K.blastShake`). **Potwierdzone** |
| Kaplica dla bota: 12–17 śmierci / 180 s, 0 odpoczynków, 20–28 s przy paczce, której nie podniesie (pełny zapas), 0 s z pustymi broniami | dane Astry; bot ma ograniczenia (`qa/souls_bot.lua:174`), test trasy przyjmuje paczkę z mapy za drop |
| Benchmark: 20 żywych 7,4 ms, 48 → 9,5 ms, 96 → 11,5 ms (p99 23,6); tekstury ok. 749 MiB | dane Astry |

##### Tylko Claude

| Ustalenie | Stanowisko |
|---|---|
| Cały dźwięk syntezowany w kodzie, 0 plików audio | fakt (`audio/recipes.lua`); Astra dodaje, że receptury mają warstwy basu 48/85 Hz. Bez odsłuchu nic nie wiadomo o „płaskości” |
| Nisza ARSENAL: nie widać od razu broni w ręku; pasek SHIFT bardzo niski | do potwierdzenia renderem przed/po; Astra mierzy podpisy ok. 9 px w 960×540 |
| Łączny efekt zmian 0.42: zasób mógł przejść z braku w nadmiar | wsparte danymi Astry: 0 s z pustymi broniami w 6 przebiegach |
| Proces: commity hybrydy weszły bez zielonego Mechanics | fakt z U01/F05 |

##### Rozbieżności i rozstrzygnięcia

| Spór | Claude | Astra | Rozstrzygnięcie i dowód |
|---|---|---|---|
| Ekonomia 1420 / 4759 | błąd projektu | nie błąd: wymusza wybór | **Astra ma rację co do samej liczby.** Niespójność jest w połączeniu: odpoczynek nie odradza, więc dodatkowe dusze dają tylko F01 (do naprawy) i celowa śmierć (wraca niezabezpieczone). To decyzja właściciela D8, nie naprawa |
| Jak przywrócić elitom egzamin | pancerz w zamachu 60–70%, ewentualnie HP | najpierw F04, potem strojenie ciosów, domykania i ryzyka wymiany; nie wracać do gąbek | **Kolejność Astry.** Pancerz zamachu przywraca „nic mu nie robię”, które właściciel zgłosił. Moje progi przyjmuję jako kryteria odbioru |
| Atak z celownikiem-laserem | jeden nowy atak | niepotrzebny teraz | **Odłożyć.** Najpierw F04 i strojenie; jeśli pociski dalej nie zagrażają, wrócić do pomysłu właściciela |
| Mikro-zatrzymanie przy trafieniu | opcja dla bliskiego Exorcista i zabójstwa | ostrzega przed ogłuszeniem każdego śrutu | zgodne po doprecyzowaniu: zatrzymanie prezentacji, nie ogłuszenie; tylko po nagraniu i ocenie właściciela |
| F04 jako P1 | – | P1 | **P1**: wczorajsza zmiana skraca okna kary wbrew własnemu opisowi, a strojenie elit bez tej naprawy mierzyłoby błędny zegar |

**Nierozstrzygnięte:** odczucie strzału, odrzutu i trafienia; miks; trudność nawy dla człowieka (bot nie rozróżnia ograniczeń bota od ściany trudności); czy znajdźki mają wracać (F03 — wybór właściciela kontra późniejszy krok hybrydy); przyczyna zatrzymania F08 i maksimów 1 s w frame-watch; co ma znaczyć wyjście z gry (D9).

#### 3. Wnioski

1. **Fundament jest dobry i nie wymaga przepisywania**: stały krok, determinizm i powtórki, schematy treści, spójna fizyka 2,5D, osobne pociski z ciągłym przeciąganiem, modularny potok trafienia. Wydajność z zapasem dla obecnej skali (20 żywych ok. 7,4 ms).
2. **Najsłabsze są granice reguł po 0.42**: zapis/Continue (F01), odpoczynek a zagrożenia świata (F02), cykl znajdziek (F03), zegary AI (F04), informacja HUD i teksty (F07). Każde podważa zaufanie gracza do reguł, które gra właśnie wprowadziła.
3. **Bramka jakości przestała chronić** (6 FAIL, testy potwierdzające inne scenariusze niż w nazwie). Zanim cokolwiek się stroi, QA musi znów mówić prawdę.
4. **Trudność się odwróciła**: pojedynek z elitą jest za łatwy dla prostych strategii, grupa w nawie bardzo trudna dla bota. Zasoby z deficytu przeszły prawdopodobnie w nadmiar. Bez próby człowieka nie wiadomo, gdzie leży prawda.
5. **Ogniska zostają (rekomendacja obu modeli)**: po 0.42 już nie odradzają świata, więc są punktami kontrolnymi. Rozwój z Dooma (wzmocnienia z ziemi) można dodać bez ich usuwania. Usunięcie ognisk nie naprawia F01–F04; ewentualny wariant porównać później na tej samej treści (C02).
6. **Spostrzeżenia właściciela**: kite'owanie po prostej nie działa na walczących wręcz (cofanie 3,15 m/s wobec 3,8–4,6 m/s stworów i skoku Thralla), ale bot wygrywa okrążaniem i cofaniem z elitami — problem jest w strojeniu i zegarach, nie w braku stylów AI. Pociski są wolne celowo (zmiana kierunku unika), globalne przyspieszenie nie ma dowodu. I-frames w normie. Soczystość jest w kodzie, ale siła nieoceniona; dźwięk w całości syntezowany.

**Efekt łączny zasad planu:** jedna zmienna balansu na raz z sondą przed/po; nad sceną najwyżej jeden komunikat i jeden napis pod celownikiem; dolny pasek bez zmian kompozycji; zmiany oprawy dopiero po nagraniu bazowym, żeby nie zatrzeć fresku nadmiarem błysków i wstrząsów.

#### 4. Plan rozwoju i poprawek (propozycja, niezatwierdzona)

P1 konieczne, P2 usprawnienie, P3 opcjonalne. Nakład: S lokalna zmiana, M kilka modułów i testy integracyjne, L seria iteracji z grą.

**Decyzje właściciela potrzebne do planu:** D8 gdzie żyje rozwój (sklep przy ognisku czy znaleziska w świecie, ile ma kosztować katalog); D9 co znaczy wyjście z gry w trakcie (wznowienie dokładnie tam / powrót do ogniska bez leczenia i z zachowaniem zabitych); D10 czy znajdźki wracają przy odpoczynku i śmierci (jego wybór z 2.11) czy zostają zabrane po odpoczynku (późniejszy krok hybrydy).

##### Etap 0: wiarygodne QA i uczciwe reguły

| ID | P | Problem i dowód | Zmiana i zakres | Korzyść | Zależy | Nakład / ryzyko | Ukończone, gdy |
|---|---|---|---|---|---|---|---|
| A01 | P1 | 6 FAIL (U01/F05); render sklepu pokazuje odmowę; test trasy liczy paczki mapy jako drop; bot idzie do paczek, których nie podniesie | zaktualizować 4 nieaktualne asercje z uzasadnieniem; `souls-gate`/`souls-bots` zostają kryterium B01 (opisane jako znane czerwone do B01); `chapel_look` usypia stwory przed `fire-menu` i sprawdza stan; `chapel_route` odróżnia drop od zapasu; bot bierze paczkę tylko przy potrzebie | brama znów chroni | – | M / średnie (osłabienie testów) | `-Suite All`: tylko 2 znane FAIL z opisem; render pokazuje menu ognia; test dropu czerwony bez dropu |
| A02 | P1 | F01/U04: Continue leczy, odnawia i przywraca zabitych, portfel zostaje | jedna reguła zapisu wg D9; zalecane minimum: zapis przy wyjściu utrwala zasoby i zabitych od ostatniego ogniska, Continue budzi przy ognisku bez `refresh` | stawka śmierci i odpoczynku | D9 | M / wysokie (zapis, migracja) | sonda `sonda-continue.lua` odwrócona: brak darmowego leczenia i ponownej nagrody; testy pauzy, wyjścia, śmierci, błędu zapisu |
| A03 | P1 | F02: odpoczynek przy żywej plamie/pocisku | odmowa z powodem przy aktywnym zagrożeniu w zasięgu albo przyjęty odpoczynek usuwa wrogie zagrożenia przy ognisku | odpoczynek bezpieczny | – | S–M / średnie | sonda Astry: 0 obrażeń po przyjętym odpoczynku; brak leczenia pod ostrzałem |
| A04 | P1 | F03: znajdźki nie wracają | wg D10; przy wariancie właściciela rozdzielić `taken` (zapasy, wracają) od `slain` (zabezpieczeni zabici), migracja starych zapisów | zgodność z decyzją | D10, A02 | M / średnie | zebrane wracają po odpoczynku i śmierci, zabici zostają martwi, brak duplikatów po wczytaniu |
| A05 | P1 | F04: okna kary krótsze, `dodged` nieosiągalne | pełna regeneracja blokuje zwykłe ciosy i odpowiedzi; stanie ≤ 0,7 s zostaje (ruch bez ciosu); cooldown po regeneracji; kolejność sekwencji vs reakcji na unik | uczciwe okna kary | – | M / wysokie (trudność) | test zegarów: cleave nie uderza przed 1,2 s, odpowiedź na przeładowanie też; `dodged` osiągalne w sekwencji |
| A06 | P1 | F07/U05: zły grawer w HUD, teksty o odradzaniu, podpowiedź poza ramą | `P.hud` przekazuje `worn`; teksty 148/171/282; krótsza odmowa w istniejącej ramie; audyt układu sprawdza szerokość tekstu wobec wnętrza ramy | gracz ufa UI | A04 (treść tekstów) | S / niskie | dwa grawery na dwóch broniach pokazują swoje; 5 formatów bez wyjścia poza ramę; pasek bez zmian |
| A07 | P2 | proces: commity bez zielonego Mechanics | reguła w DEVELOPMENT: commit tylko po zielonym `-Suite All` (lub znanych FAIL z A01); balans jedna zmienna na commit z sondą | koniec nakładania | A01 | S / brak | wpis i przestrzeganie |

##### Etap 1: walka po naprawach

| ID | P | Problem i dowód | Zmiana | Korzyść | Zależy | Nakład / ryzyko | Ukończone, gdy |
|---|---|---|---|---|---|---|---|
| B01 | P1 | U02/F06: elity przegrywają z bezmyślnymi strategiami | stroić istniejące ciosy elit: domykanie dystansu, kara za stanie i cofanie, przerwania; bez powrotu do gąbek; pancerz zamachu dopiero jako ostatnia dźwignia | elita znów uczy ciosów | A05, A01 | M–L / wysokie | `souls-gate` zielone: careless/backpedal/orbit nie wygrywają pewnie (≥1 z 2 ziaren porażka albo <30% HP), learning 3/3 z >70% HP, walka 20–35 s; ocena właściciela |
| B02 | P1 | L01 nadal niezrobione; bot w nawie 12–17 śmierci, nie rozróżnia własnych ograniczeń | próba właściciela wg `docs/audyt-2026-11-02/PROBA-WLASCICIELA.md` uzupełnionej o: elity, nawa, Continue, znajdźki; notatka zgonów | fakty o trudności dla człowieka | A01–A06, B01 | S / brak | notatka z próby w tym katalogu |
| B03 | P2 | U12: 0 s z pustymi broniami, odnawianie Judge'a + 126 naboi na mapie | po B02: sonda zasobów (nadwyżka przy wejściu do elity, czas pustych broni), jedna zmienna (np. liczba skrytek) | amunicja znów decyzją (D2) | B02 | S / średnie | liczby przed/po, ocena właściciela |
| B04 | P2 | grupa w nawie a pojedynek | po B02: jeśli człowiek też ginie w nawie, rozstawienie progów sal i `seenRange` (L06 z poprzedniego planu) | uczciwy pierwszy próg | B02 | M / średnie | bot i właściciel: śmierci w nawie z jasną przyczyną |

##### Etap 2: progresja i kierunek

| ID | P | Problem i dowód | Zmiana | Korzyść | Zależy | Nakład / ryzyko | Ukończone, gdy |
|---|---|---|---|---|---|---|---|
| C01 | P2 | U03: 1420 dusz na przejście, katalog 4759, odpoczynek nie odradza | wg D8: ceny pod realny dochód albo część katalogu jako znaleziska w świecie (pieczęcie, grawery za elity i sekrety), ognisko do wymiany; tabela „co kupię po pierwszym przejściu” | progresja bez farmy | D8, A02 | M / średnie | tabela w docs, test sumy, ocena właściciela |
| C02 | P3 | pytanie właściciela o Doom bez ognisk | eksperyment: naprawiona hybryda kontra automatyczny punkt kontrolny i więcej wzmocnień z ziemi, na tej samej treści | wybór kierunku z gry, nie z teorii | Etap 0, B01, B02 | M / wysokie projektowo | krótkie porównywalne próby: przestoje, zgony, zrozumienie progresji; decyzja właściciela |
| C03 | P3 | U07/O02: broń stwora jako osobna warstwa | mała warstwa `arms` (materiał, dźwięk zderzenia, które ciosy, czy blokuje strzał) dopiero przy mechanice: blok, rozbrojenie, dwa warianty uzbrojenia | właściwości broni bez osobnej fizyki | A05, konkretna potrzeba | S–M / średnie | jeden stwór z dwoma wariantami oręża bez duplikacji AI |

##### Etap 3: oprawa i czytelność (bez zmiany designu paska)

| ID | P | Problem i dowód | Zmiana | Korzyść | Zależy | Nakład / ryzyko | Ukończone, gdy |
|---|---|---|---|---|---|---|---|
| D01 | P2 | brak nagrania bazowego; ocena odrzutu, błysku, wstrząsu tylko z kodu | **Codex**: nagranie bazowe `f69a19b` (patrz prompt) | właściciel ocenia z obrazu | – | S / brak | nagrania i klatki kontrolne w `work/`, ocena właściciela |
| D02 | P2 | U11: dźwięk syntezowany, „płaski” bez odsłuchu | odsłuch A/B właściciela (E04); jeśli płaski: **Codex** przygotowuje próbkowane warstwy strzału Judge/Exorcist i trafienia (ciało, pancerz, broń) | strzał „waży” | D01 | M / niskie | ocena właściciela przy równej głośności |
| D03 | P2 | wstrząs prochu bez dystansu; hierarchia efektów w tłoku | spadek siły z odległością, sprawdzenie wyłączenia ruchu kamery | zagrożenie widoczne | D01 | S / niskie | daleki wybuch nie dominuje bliskiego; nagranie |
| D04 | P2 | nisza ARSENAL, pasek SHIFT, podpisy ok. 9 px w 960×540 | broń w ręku pełną kością słoniową, druga przygaszona; pasek wytrzymałości wyższy w tej samej niszy; grubość/kontrast najmniejszych podpisów | szybki odczyt | A06 | S–M / niskie | rendery przed/po w 5 formatach, **zgoda właściciela na wygląd** |
| D05 | P3 | opcjonalnie mikro-zatrzymanie 0,02–0,03 s przy bliskim Exorcist i zabójstwie | jedna stała w `tuning.feel`, bez ogłuszenia | trafienie czuć | D01, ocena właściciela | S / średnie (rytm) | nagranie przed/po |
| D06 | P2 | F08: ok. 0,9 s pierwszej klatki po zimnym starcie | dokończyć przygotowanie pod stroną ładowania, zmierzyć przyczynę | brak pozornego zawieszenia | – | M / średnie | 3 zimne starty: pierwsza gotowa klatka < 100 ms |

##### Etap 4: opcjonalny rozwój

| ID | P | Zmiana | Warunek |
|---|---|---|---|
| R01 | P3 | atak z celownikiem-laserem (hitscan po 0,4–0,6 s telegrafu) dla jednej rodziny, przerywalny kontrą — pomysł właściciela | po B01 i B02, jeśli pociski nadal nie zagrażają |
| R02 | P3 | skalowanie AI (licznik atakujących na cel, siatka dla wyboru celu) | gdy sala ma > 30 ciał |
| R03 | – | etap 4 z poprzedniego planu (koniec kaplicy, mapa, druga droga) | **odłożony decyzją właściciela**, nie zaczynać bez zgody |

**Kolejność:** A01 → (D9, D10 od właściciela) → A05, A03, A06 → A02 → A04 → A07 → B01 → B02 (próba) → B03, B04 → C01 (D8) → D01 równolegle od początku (Codex), D02–D06 po nagraniu → C02, C03, R01 według wyników.
