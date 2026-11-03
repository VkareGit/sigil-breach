**V01 — SIGIL: BREACH 0.43, odbiór obrazu i odczucie strzelania**

**Najpierw poprawiłbym widoczność linii Stolasa i czas potwierdzenia pękniętej gardy.** Odrzut już wyraźnie różnicuje Judge’a i Exorcista. Słabszym ogniwem jest czytelność kontaktu: krótki błysk ciała, miejscami zlewająca się sylwetka oraz znikające potwierdzenie. Zachowałbym żywy mroczny fresk, wygląd demonów i broni oraz całą kompozycję dolnego HUD-u.

To moja ocena na podstawie obrazu, kodu i pomiarów, **nie opinia przebadanych graczy**. Oznaczenia: **[P]** pomiar, **[K]** ustalenie z kodu, **[O]** ocena, **[H]** hipoteza do sprawdzenia. Propozycje są materiałem dla Claude’a; zgodnie z zakazem przekazywania zadania nie konsultowałem go z innym agentem.

**Materiały i zakres**

- [Raport V01.md](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/V01.md) — ta sama treść co odpowiedź końcowa.
- [Nagranie główne](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/nagranie.mp4): 84 s, H.264, 1280×720, 30 kl./s, 2520 klatek, 48,67 MiB.
- [Kopia poniżej 30 MiB](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/nagranie-ponizej-30MiB.mp4): ta sama długość i rozdzielczość, **22,08 MiB**.
- [Przegląd klatek odczytanych z MP4](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/checks/mp4-contact-sheet.png); pełne PNG w `checks/mp4/` — 42 sztuki; dodatkowe 9 z mniejszej kopii w `checks/mp4-small/`.
- [Porównanie dźwięków F7](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/audio/F7-comparison.wav): 63 s, 21 izolowanych próbek. **Filmy nie mają ścieżki audio.** WAV jest osobnym zestawieniem, nie dźwiękiem zsynchronizowanym z walką.
- 28 renderów `--chapel-look` w `work/visual/renders/`; klatki źródłowe, sondy i wycinki w `frames/`, `probes/`, `telegrafy/`, `crops/`. Podpisy na obrazach i filmie są po angielsku.

| Czas filmu | Zawartość |
|---|---|
| 00:00–00:04 | Spokojna nawa kaplicy |
| 00:04–00:10 | Tłok: trzy Ember Thralle, Stolas, Iron Thrall; następnie walka |
| 00:10–00:15 / 00:15–00:20 | Judge: 3 m / 8 m, tułów, głowa, zabójstwo |
| 00:20–00:26 / 00:26–00:32 | Exorcist: 2 m / 6 m; zabójstwo z bliska |
| 00:32–00:38 | Pancerz i przełamanie gardy Iron Thralla |
| 00:38–00:46 / 00:46–00:52 | Walka z Margrave’em / przełamanie gardy i chwianie |
| 00:52–01:00 / 01:00–01:06 | Walka z Furfurem / przełamanie gardy i chwianie |
| 01:06–01:11 / 01:11–01:16 | Stolas: nowa linia włóczni / trzy pociski |
| 01:16–01:20 / 01:20–01:24 | Ładunek: wybuch z 2 m / 10 m |

Badany commit: `415a9047facb8b50e531d7bcc60f304aee2fdfb6`. Wszystko wykonano lokalnie, bez sieci i commitów. Tymczasowy skrypt nagrania oraz gałąź `--film` zostały usunięte; końcowe `git status --short` jest puste. Pliki opracowania znajdują się w `work/visual/`.

Sceny są reżyserowane przez API gry, z jej rendererem i mechaniką: symulacja 120 Hz, zapis co cztery kroki, FOV 100, ruch prezentacyjny włączony. Podczas prób strzeleckich cele mają poligonowe `dummy=true`: nie inicjują ataków, lecz otrzymują normalne obrażenia, odrzut, rany i przełamania. Przed strzałem ustawiam dystans między środkami postaci oraz celowanie w namalowaną strefę. Walki prowadzi lokalny bot QA. Ładunek po rzeczywistym rzuceniu zostaje ustawiony na podłodze w zadanej odległości, z zachowaniem lontu. Film nie jest zapisem ręcznej gry ani testem trudności.

Nie zmieniałem parametrów obrażeń, zdrowia, broni ani ataków dla filmu. Exorcist z 6 m po trzech salwach zostawia **25,56 HP** — nie wymuszałem zabójstwa. Osobne sondy przytrzymują stany znaczników lub usuwają obiekt z renderu do pomiaru tła. Warianty A/B są wyłącznie diagnostyką poza filmem bazowym.

**Czytelność przestrzeni i sylwetek**

[P] Porównuję dwa PNG tej samej zamrożonej sceny: z badanym elementem i bez niego. Po linearyzacji sRGB liczę względną luminancję Y, kontrast `(Yjaśniejsze + 0,05)/(Yciemniejsze + 0,05)` oraz bezwzględną różnicę L* w CIELAB. Maska obejmuje piksele zmienione o ponad 2/255 w dowolnym kanale, w określonym obszarze obrazu.

To lokalny pomiar sygnału względem rzeczywistego tła, **nie certyfikacja WCAG dla gry**. Próg 1,5:1 służy porównaniu wariantów, nie oznacza automatycznie „widoczne/niewidoczne”. Maska pomija piksele identyczne i prawie identyczne, więc wynik może być optymistyczny. Mediana nie opisuje całego konturu; ruch, kolor, wielkość i zasłanianie również mają znaczenie. Pomiar wykonano na PNG, przed kompresją H.264.

W komórkach poniżej: **mediana kontrastu : 1 / mediana ΔL***.

| Miejsce i dystans | Ember Thrall | Stolas | Iron Thrall |
|---|---:|---:|---:|
| Nawa, 6 m | 1,34 / 9,9 | 1,39 / 11,1 | **1,25 / 8,2** |
| Przed freskiem, 5,5 m | 1,36 / 10,1 | **1,35 / 9,9** | 1,47 / 12,8 |
| Krypta, 5 m | 1,52 / 12,1 | 1,44 / 10,6 | 1,37 / 9,5 |
| Zachodnia komnata, 6 m | 1,41 / 11,2 | **1,33 / 9,3** | **1,25 / 8,0** |

Pełne dane, obszary pomiaru i percentyle: [silhouettes.csv](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/measure/silhouettes.csv).

[O] W spokojnej kaplicy paleta jest spójna: rdza, czerń, ochra i kość tworzą fresk. W tłoku podobne barwy i podobna gęstość detalu utrudniają oddzielenie ruchomego ciała od namalowanych postaci. Najsłabsze są kaptur, tors i ramiona opancerzonego oraz skrajne partie skrzydeł i szat Stolasa. Jasna klatka piersiowa Thralla pomaga bardziej niż jego nogi i błony skrzydeł. W scenie tłoku trzy przednie ciała dodatkowo fizycznie zasłaniają dalszych przeciwników.

Konkretne miejsca:

- [Iron Thrall w nawie](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/crops/pair-nave-armored-body.png): **75,2%** zmierzonych pikseli poniżej 1,5:1. [Mapa kontrastu](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/crops/pair-nave-armored-contrast.png): czerwone piksele oznaczają niski lokalny kontrast, turkusowe wyższy.
- [Stolas przed freskiem](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/crops/pair-fresco-stolas-body.png): **61,2%** poniżej 1,5:1; szaty i skrzydła konkurują z łukami oraz namalowanymi sylwetkami.
- [Iron Thrall w zachodniej komnacie](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/crops/pair-west-armored-body.png): **70,6%** poniżej 1,5:1; ciemne partie pancerza znikają na ciemnych figurach ściany.

[P] Sprawdziłem rozjaśnienie całego opancerzonego o 10% i 18%, przy niezmienionej scenie. W nawie mediana rośnie **1,248 → 1,278 → 1,308**, ale przed freskiem spada **1,468 → 1,451 → 1,443**. [Porównanie przed freskiem](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/crops/proposal-body-fresco.png). To argument przeciw globalnemu podnoszeniu jasności przeciwników. Potrzebne są miejscowe różnice tonu wewnątrz istniejącej grafiki.

**Telegrafy**

| Sygnał w sondzie | Kontrast medianowy | ΔL* | Piksele poniżej 1,5:1 |
|---|---:|---:|---:|
| Margrave w fazie błysku ciosu, względem ściany | 1,25:1 | 7,6 | 77,4% |
| Ostrzeżenie pioruna Furfur, względem podłogi | 1,86:1 | 19,0 | 32,9% |
| Aktywny piorun | 3,46:1 | 35,2 | 17,7% |
| Pocisk gwiazdy Stolasa | 1,53:1 | 11,8 | 47,6% |
| Linia włóczni, wycinek do A/B | **1,29:1** | **8,8** | **70,3%** |

Pierwszy wiersz opisuje całą widoczną sylwetkę podczas telegrafu, nie izolowaną zmianę jasności samego błysku. Pozostałe sondy izolują rysowany sygnał. Dane: [isolated-telegraphs.csv](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/measure/isolated-telegraphs.csv) i [proposals.csv](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/measure/proposals.csv).

[O] [Błysk Margrave’a](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/crops/telegraph-cleave-flash.png) potrzebuje rozpoznawalnej pozy ciała, ponieważ sam kolor słabo oddziela go od ściany. [Pierścień Furfur](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/crops/telegraph-lightning-warning.png) ma czytelną jasną krawędź, ale pod stopami może znaleźć się pod bronią albo poza kadrem. Sonda pokazuje go po odsunięciu się i spojrzeniu w dół; wysoki kontrast nie rozwiązuje zasłaniania.

[O] [Gwiazda Stolasa](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/crops/telegraph-star-projectile.png) ma wyraźniejszy rdzeń niż otoczkę: 90. percentyl kontrastu wynosi 4,91:1. Najsłabszym ostrzeżeniem jest cienka linia włóczni, biegnąca po ochrowo-czarnych płytach i częściowo za lufą.

[K] Włócznia ma 0,60 s zamachu, następnie 0,45 s ostrzeżenia na podłodze i 0,30 s aktywności. [P] Podniesienie wyłącznie `ray.warned` z 0,30 do 0,48 daje w tym samym wycinku **1,29 → 1,52:1**, **ΔL* 8,8 → 13,8**, udział słabych pikseli **70,3% → 49,0%**. [Obraz A/B](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/crops/proposal-lance.png). Geometria i czas ataku pozostają takie same.

**Celownik, trafienie i nagroda**

[P] [Plansza znaczników na trzech tłach](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/checks/markers-grid.png) pokazuje powiększenia 4× bez wygładzania. Poniższa tabela mierzy kolorowe wnętrze kreski lub dodatkowego symbolu, osobno od ciemnego obrysu.

| Element | Fragment fresku | Ciemna nisza | Jasny płomień |
|---|---:|---:|---:|
| Kość słoniowa celownika | 8,66:1 | 15,47:1 | 1,22:1 |
| Zwykłe trafienie | 8,16:1 | 15,12:1 | **1,25:1** |
| Pancerz — niebieskie kreski | 3,67:1 | 6,79:1 | 1,78:1 |
| Głowa — biały romb | 7,48:1 | 15,86:1 | 1,67:1 |
| Zabójstwo — zgaszona czerwień | **2,00:1** | 3,61:1 | **3,31:1** |
| Pęknięta garda — złote narożniki | 7,40:1 | 9,32:1 | 2,37:1 |

[P/O] Celownik pozostaje czytelny dzięki dwóm tonom: na płomieniu jego czarny podkład ma **13,32:1**, a w niszy działa jasne wnętrze. Sam niski wynik jasnej kreski na ogniu nie oznacza niewidocznego celownika. Podkład znacznika trafienia jest słabszy: alfa 0,55. Na płomieniu **88,3%** pikseli jego jasnego wnętrza ma kontrast poniżej 1,5:1. Czerwień zabójstwa działa tam dobrze, natomiast na fresku **38,2%** jej pikseli jest poniżej 1,5:1.

[K] Obecny znacznik respektuje decyzję właściciela: cztery cienkie kreski, `markGap=4`, `hitReach=8` z dodatkiem do 2 px zależnym od ciężaru trafienia, szerokość 1,5 px. Zabójstwo ma zasięg 9 px i krótki wzrost o 10%. Pancerz dodaje ikonę 18 px obok środka; głowa romb 8×8 px powyżej; garda cztery złote narożniki odsuwające się z promienia 17 do 24 px.

[O] Te kształty pozwalają odróżniać znaczenia bez dużego X. Zwykłe trafienie i głowa nadal wymagają zauważenia małego dodatkowego rombu. Nie wykazałem, że człowiek zawsze rozpozna je w ułamku sekundy — wymaga to próby z ludźmi. Na bliskim celu znaczniki nie są głównym źródłem zasłaniania; przy małej odległej głowie konkurują z krwią, błyskiem i lufą. Nie proponuję powiększenia kresek ani zmiany czerwieni zabójstwa.

[P/K] Trafienie Judge’a trwa tu **128 ms**, mocna salwa Exorcista **140 ms**, zabójstwo **300 ms**. W zapisie daje to odpowiednio 4, 5 i około 9 klatek. Potwierdzenie gardy ma własne **220 ms**, lecz kod rysuje je wewnątrz `hitMarks()`, wywoływanego tylko podczas zwykłego hitmarkera. W obu próbach elit narożniki są widoczne **5 zamiast 7 klatek**. To konkretny problem warunku rysowania.

[O] Dolny HUD zachowuje własny charakter i czytelne duże wartości. [Wycinek nisz](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/crops/hud-niches.png) wskazuje jedynie miejsce do opcjonalnego strojenia wyblakłego napisu nieaktywnej broni. Nie proponuję zmiany kształtu, układu, ornamentów ani proporcji paska.

**Odczucie strzelania: co już działa i co osłabia kontakt**

[K/P] `feedback/weight.lua` liczy impuls jako `momentum / mass`: Judge **9/1,5 = 6**, Exorcist **96/4 = 24**. Parametry pochodzą z `content/weapons.lua`. Pomiar pierwszego strzału przy 120 Hz:

| Wielkość | Judge | Exorcist |
|---|---:|---:|
| Maksimum stanu `recoil`, jednostki wewnętrzne | 0,160 po 66,7 ms | 0,638 po 66,7 ms |
| Maksimum `kickBack`, jednostki wewnętrzne | 0,546 po 41,7 ms | 0,917 po 41,7 ms |
| Uniesienie widoku | 1,02° po 33,3 ms | 2,00° po 41,7 ms |
| Odchylenie nadgarstka | 3,40° po 75 ms | 0,47° po 66,7 ms |
| Powrót widoku poniżej 10% maksimum | 150 ms | 225 ms |
| Powrót `recoil` poniżej 10% maksimum | 242 ms | 242 ms |
| Maksymalne zejście punktu transformacji broni, pierwsze 120 ms | 5,0 px | 22,6 px |
| Przesunięcie projekcji celownika w dół | 9,6 px | 18,7 px |

Piksele dotyczą kadru 1280×720; punkt transformacji broni nie jest końcem lufy. Pełne wyniki: [timing.csv](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/measure/timing.csv).

[K] Judge ma `back=5`, `wrist=0.31`, sprężynę nadgarstka 210/20; Exorcist `back=2.1`, `wrist=0.014`, 280/28. Wspólna sprężyna odrzutu wynosi 270/25, osiowego cofnięcia 900/30. `weapon_motion.lua` dodatkowo daje Exorcistowi wolniejsze prowadzenie: `aim=0.78` wobec 1,00 Judge’a; sprężyna prowadzenia to `196×aim / 28×√aim`, limity 7 i 5 px przy wysokości sceny 450 px.

[O] Ta różnica jest sensowna: Judge obraca się w dłoni, Exorcist mocniej cofa i porusza widokiem. Nie znalazłem podstaw, żeby zaczynać od zwiększenia odrzutu lub losowego wstrząsu. Obie bronie mają już zdecydowany impuls i powrót przed następnym strzałem. Cykl Judge’a wynosi **380 ms**, Exorcista **940 ms**.

[K/P] Błysk oświetlenia trwa **45 ms / 65 ms** dla Judge’a / Exorcista. To inny zegar niż namalowany błysk lufy: jego jasna faza wynosi **55 ms / 45 ms**, po niej są słabsze fazy do 150 ms; automatyczne przeładowanie może zakończyć prezentację ognia Exorcista wcześniej. Dym ma siłę **0,17 / 0,30** i czas **420 / 620 ms**, czyli około 13 / 19 klatek. [Sekwencja Judge’a](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/checks/judge_near-sequence.png) i [Exorcista](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/checks/exorcist_near-sequence.png).

[O] Błysk daje wyraźny początek strzału. W Exorciście już około 67 ms obraz przechodzi do chwytania/powrotu broni, kiedy krew dopiero rozwija swój kształt. To kandydat do niewielkiego wydłużenia pozy strzału. Dym pozostaje przezroczysty; nie uzasadnia to ogólnego usunięcia ani silnego skrócenia efektu.

[P/K] Wstrząs po pierwszym trafieniu osiąga **0,065 / 0,080**, przy bazowym wstrząsie wystrzału **0,018 / 0,050**. Silniejsze potwierdzenie trafienia dominuje więc nad samym wystrzałem. Są to wartości stanu efektu, nie piksele; kamera zamienia je m.in. na oscylację przechyłu. W próbce efekt obejmuje 2 / 3 klatki filmu.

**Najbardziej mierzalne osłabienie kontaktu to zanik błysku trafionego ciała.** [K] `hitFlash=0.065`, lecz siła jest dalej skalowana przez `min(1, hit×13)` i ciepłe mieszanie w shaderze. [P] Dla Judge’a z 3 m różnica między tym samym ciałem z błyskiem i bez niego wynosi:

| Czas od pierwszej próbki trafienia | Kontrast błysk / ciało bez błysku | ΔL* |
|---|---:|---:|
| 0 ms | 1,46:1 | 10,9 |
| 16,7 ms | 1,30:1 | 8,0 |
| 33,3 ms | **1,16:1** | **4,9** |
| 50 ms | 1,04:1 | 1,4 |
| 58,3 ms | Brak zmienionych pikseli | — |

[O] Przy 30 kl./s druga próbka błysku jest już słaba. Na tle podobnie ciepłego fresku reakcja może wyglądać mniej zdecydowanie niż sam ruch broni.

[K/P] D05 ustawia `impactSlow` na **25 ms** po salwie zabierającej co najmniej **120 HP**, a po zabójstwie na **30 ms**. Judge za 70 HP nie uruchamia pierwszej reguły; Exorcist z 2 m za 192 HP ją uruchamia, pierwsza salwa z 6 m za 115,14 HP już nie. To mniej niż jedna klatka filmu przy 30 Hz.

D05 **nie zatrzymuje całego obrazu**: ogranicza decyzje/fazy przeciwników, a ruch od pchnięcia i reakcja ciała nadal trwają. W pierwszych 16,7 ms aktywnego `impactSlow` trafiony Thrall przesunął się o **1,74 cm**. Dlatego brak wyraźnej „zamrożonej klatki” w MP4 nie dowodzi braku działania D05. Odrębne `hitPause`, rany i zabójstwa mają własne czasy; ich nakładanie nie jest tym samym co globalny stop. Nie proponuję zmiany tych reguł walki w ramach strojenia prezentacji.

[P] Chwianie elit po pęknięciu gardy działa w 0.43. Margrave pozostaje odsłonięty przez około **1,60 s**, Furfur **1,50 s**. `exposedReel` ma częstotliwość kątową 6 rad/s, amplitudę pochylenia 0,06 i opadania 0,04. Zmierzony parametr pochylenia zmienia się mniej więcej od **−0,09 do +0,03**, wysokość do **95,8–96,0%** podstawowej. To parametr deformacji, nie kąt w stopniach. [Margrave](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/checks/margrave_break-sway.png), [Furfur](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/checks/furfur_break-sway.png). [O] Obecne amplitudy wystarczają do pokazania, że ciało nie zawisło; zachowałbym je.

[P/K] Ładunek daje czysty impuls wybuchu **0,09 z 2 m** i **0,05123 z 10 m**, zgodnie z tłumieniem odległości w `content/tuning.lua`. Z bliska końcowy stan wstrząsu rośnie do **0,16**, bo dochodzą własne obrażenia i reakcja rycerza: HP **100 → 88,91**, osłona **40 → 26,44**. Z 10 m pozostaje 100 HP / 40 osłony. Większego bliskiego wstrząsu nie należy interpretować jako błędu samego tłumienia wybuchu.

**Dźwięk F7**

[P/K] Zestawienie WAV korzysta z rzeczywistych receptur `classic` oraz pierwszych dostarczonych próbek `iron` i `stone`, z poziomami odtwarzania gry. Classic zawiera warstwy hall/thud; nagrane zestawy mają je już w plikach, więc kod prawidłowo ich nie dokłada. Nie normalizowałem zestawienia. Użyłem stałego wariantu 1 i bez losowego przesunięcia wysokości; zwykła gra korzysta z trzech wariantów i zmienności wysokości.

RMS dotyczy pierwszych 100 ms. T90 to czas zebrania 90% energii próbki, **nie czas słyszalności ani długość pliku**.

| Broń / zestaw | RMS 100 ms | T90 | Energia poniżej 150 Hz |
|---|---:|---:|---:|
| Judge classic | −18,63 dBFS | 114 ms | 47,8% |
| Judge iron | −18,25 dBFS | 68 ms | **87,1%** |
| Judge stone | −18,17 dBFS | 50 ms | 71,2% |
| Exorcist classic | −9,83 dBFS | 146 ms | 45,3% |
| Exorcist iron | −9,13 dBFS | 84 ms | 75,6% |
| Exorcist stone | −8,90 dBFS | 66 ms | 79,3% |

[P] W obrębie jednej broni różnice początkowego RMS mieszczą się w około 1 dB. Izolowane próbki nie osiągają przesterowania. Iron i stone skupiają energię strzału wcześniej i niżej w paśmie. Dla potwierdzeń trafienia w ciało/głowę T90 wynosi około **8–11 ms**, pancerza **13–16 ms**, zabójstwa **25–58 ms**.

[K] `weight.lua` wybiera jeden najważniejszy głos potwierdzenia salwy; przełamanie ma pierwszeństwo przed głową i zwykłym trafieniem, zabójstwo jest obsługiwane osobno. [H] Tak krótki sygnał trafienia może konkurować z początkiem strzału, a basowy Judge iron może tracić charakter na małym głośniku. To hipotezy z analizy sygnału, **nie wynik odsłuchu na słuchawkach ani pomiar maskowania w gotowym miksie**. Nie wskazuję zwycięskiego zestawu F7.

W WAV kolejno: Judge 0–9 s, Exorcist 9–18 s, ciało 18–27 s, pancerz 27–36 s, głowa 36–45 s, zabójstwo 45–54 s, ładunek 54–63 s. W każdej grupie: classic, iron, stone, po 3 s. [Pełne dane audio](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/measure/audio-sets.csv).

**Odniesienia gatunkowe — zasady projektowe**

[O] Traktuję te gry jako odniesienia interpretacyjne, bez nowych badań z sieci i bez przypisywania im zmierzonych tutaj parametrów:

| Odniesienie | Zasada przydatna SIGIL |
|---|---|
| Doom 2016 / Eternal | Czytelny ciąg: kontakt → reakcja → śmierć lub okazja do dalszego działania |
| Dusk | Krótki, jednoznaczny impuls i szybki powrót, który pozwala czytać rytm kolejnych strzałów |
| Amid Evil | Rozpoznawalny rdzeń pocisku i odrębny kształt zagrożenia na bogatym tle |
| Hunt: Showdown | Rozdzielenie początku wystrzału, mechanizmu i odpowiedzi przestrzeni |
| Bloodborne | Reakcja ciała komunikuje utratę równowagi i otwarcie na dalszy atak |
| CoD | Wyłącznie potwierdzenie trafienia i nagroda; bez przejmowania stylu HUD-u |

Dla SIGIL najważniejsza jest spójność czasu tych sygnałów. Mocniejszy ruch kamery nie zastąpi widocznej reakcji celu.

**Propozycje strojenia dla Claude’a**

Ścieżki poniżej są względem `game/src/`. Wszystkie zmiany poza wskazanym A/B linii są hipotezami do porównania; nie zostały wdrożone.

1. **P0 — linia włóczni.** Problem: zlewanie z płytami. Sytuacja: gracz patrzy na Stolasa przez lufę, a ostrzeżenie biegnie po osi celowania. Zmiana: `content/art/rites.lua:19`, `ray.warned 0.30 → 0.48`. Efekt: w sprawdzonej próbce kontrast 1,29 → 1,52:1 bez zmiany pola rażenia. Sprawdzenie: nawa, jasne płyty, nisza, tłok i ruch boczny; w powtórzonym wycinku najwyżej 50% pikseli poniżej 1,5:1. Obejrzeć również mniejszy MP4.

2. **P0 — pełne potwierdzenie gardy.** Problem: własny licznik 220 ms jest ucinany przez hitmarker. Sytuacja: trzecia salwa przełamuje elitę, a nagroda znika po około 140 ms. Zmiana: `ui/hud.lua:351` i wywołanie w `aimMarks`: wydzielić rysowanie narożników i uruchamiać je niezależnie przy `breakConfirm > 0`; efektywny czas **140 → 220 ms**. Efekt: 5 → 7 próbek przy 30 Hz. Sprawdzenie: oba bossy, zwykły pancerz, głowa, zabójstwo i szybki kolejny strzał; bez zmiany rozmiaru X.

3. **P1 — podkład znaczników.** Problem: jasne kreski giną na płomieniu, czerwień miejscami na fresku. Sytuacja: cel stoi przed jasnym ołtarzem lub czerwonym malowidłem. Zmiana: `ui/hud.lua:341`, alfa ciemnego podkładu **0.55 → 0.85**; szerokość, długość, kolory i czas kresek bez zmian. Efekt oczekiwany: stabilniejszy kontur przy zachowaniu małego znacznika. Sprawdzenie: trzy tła, zwykłe trafienie/pancerz/głowa/zabójstwo, wersja skompresowana. Osobno próba z właścicielem: 20 losowanych ekspozycji po 200 ms, cel co najmniej 18 poprawnych rozpoznań; to proponowane kryterium, nie uzyskany wynik.

4. **P1 — błysk trafionego ciała.** Problem: w drugiej klatce 30 Hz pozostaje tylko ΔL* 4,9. Sytuacja: Judge trafia ciemny tors na ciepłym fresku. Zmiana: `content/combat_defaults.lua:94`, `hitFlash 0.065 → 0.080 s`, z obecnym kolorem i shaderem. Efekt oczekiwany: czytelniejsze pierwsze dwie klatki kontaktu. Sprawdzenie: powtórzyć sondę 120 Hz i porównać ΔL* po 33 ms, cel około 7 lub więcej; kontrolować, czy pigment i poza ciała pozostają widoczne. Zmiana wydłuża też obecną obwiednię jasności, więc wymaga oceny A/B.

5. **P2 — krótko dłuższa poza strzału Exorcista.** Problem: przejście do powrotu zaczyna się bardzo wcześnie względem reakcji celu. Sytuacja: salwa z 2 m i 6 m. Zmiana: `content/art/weapon_frames.lua:149`, końce faz **0.065/0.12 → 0.080/0.14 s**; dodatkowo nadpisać `automaticFireUntil` **0.12 → 0.14 s wyłącznie dla Exorcista**, po wspólnej konfiguracji. Efekt oczekiwany: nieco dłuższy moment przyjęcia impulsu. Sprawdzenie: porównanie sekwencji 0–300 ms, zachowany cykl 0,94 s i moment zatrzaśnięcia mechanizmu; bez pogorszenia widoczności środka celu. Najpierw A/B, nie równoczesne zwiększanie odrzutu i wstrząsu.

6. **P2, opcjonalnie — treść niszy broni.** Problem: mały napis nieaktywnej broni jest mocno wyblakły. Sytuacja: szybkie sprawdzenie drugiej broni. Zmiana: `ui/hud.lua:27`, alfa `quietInk 0.42 → 0.55`. Efekt oczekiwany: łatwiejszy odczyt nazwy. Sprawdzenie: nazwa nadal wyraźnie mniej dominująca od aktywnej; bez zmiany geometrii, kroju, kompozycji i ornamentu HUD-u.

**Osobne zadania grafiki i dźwięku dla Codexa**

To propozycje nowych wariantów zasobów, nie gotowe poprawione pliki.

- **Lokalne rozdzielenie tonów demonów.** Problem: kaptur i ramiona Iron Thralla oraz skraje Stolasa zlewają się z malowidłem. Sytuacja: 5–8 m, przeciwnik przed freskiem. Zmiana: warianty `game/assets/art/armored-fresco-v12.png`, `stolas-fresco-v12.png` i odpowiadających im póz; miejscowo zwiększyć różnicę jasności wybranych płaszczyzn o **5–8 L*** względem obecnej wersji, bez zmiany sylwetki i bez równomiernej poświaty. Efekt oczekiwany: łatwiejsze śledzenie barku, głowy i skrzydła. Sprawdzenie: cztery pary tła; cel dla opancerzonego w nawie mediana **1,25 → co najmniej 1,50:1**, bez pogorszenia przed jasnym freskiem. To cel odbioru wariantu, nie obietnica.

- **Opcjonalny rdzeń linii włóczni.** Problem: sama większa alfa nadal zostawia prawie połowę słabych pikseli w próbce. Sytuacja: jasna płyta i linia blisko lufy. Zmiana: wariant pola promienia w `game/assets/art/rites-fresco-v36.png`, z czytelniejszym rdzeniem w kolorze kości i ciemną krawędzią wewnątrz obecnego pasa; zachować jego rozmiar. Efekt oczekiwany: odcięcie na jasnych i ciemnych płytach. Sprawdzenie: udział pikseli poniżej 1,5:1 **70% bazowo → docelowo poniżej 40%**, po porównaniu z samym strojeniem alfa. Nie zmieniać szerokości zagrożenia.

- **Wariant ataku dźwięku Judge iron.** Problem: 87,1% energii leży poniżej 150 Hz. Sytuacja: mały głośnik oraz jednoczesne potwierdzenie trafienia. Zmiana: alternatywne `game/assets/sounds/judge/B1-1.wav`–`B1-3.wav`: krótki komponent **1,5–4 kHz przez 4–8 ms**, z celem zmniejszenia udziału basu do około **70–78%**. Zachować RMS pierwszych 100 ms w granicy **±1 dB**, szczyt poniżej **0,95**; nie podnosić globalnej głośności. Efekt oczekiwany: bardziej rozpoznawalny początek strzału. Sprawdzenie: ślepy odsłuch A/B na słuchawkach i małym głośniku, także w miksie z trafieniem oraz przełamaniem gardy. Wybór zestawu pozostaje decyzją właściciela.

Nie proponuję wariantu naruszającego design dolnego HUD-u. Zwiększanie znacznika, globalne rozjaśnianie demonów i dodanie pełnego zatrzymania świata nie wynikają z tych pomiarów.

**Weryfikacja i granice wniosków**

[P] Sprawdziłem oba kontenery MP4: H.264, po 2520 próbek obrazu i 84 s. Odczytałem klatki z gotowych plików; w głównym filmie porównanie 42 próbek z sąsiednimi klatkami źródłowymi nie wykazało zamiany kanałów RGB/BGR. Mediana błędu RGB po kompresji wyniosła około **3,68/255**. Weryfikacja plików i sumy SHA-256: [media-validation.json](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/logs/media-validation.json).

Przy 30 kl./s nie da się rozstrzygać czasów 25 ms samym oglądaniem filmu; dlatego czasy pochodzą także z logów 120 Hz. Liczba widocznych klatek zależy od fazy próbkowania. Brak badania reakcji ludzi, kalibracji monitora i odsłuchu końcowego miksu ogranicza wnioski o odbiorze człowieka.

Dostępne klatki bazowe 0.42 i ich README służą orientacji jakościowej. Nie są dopasowane do obecnych kamer i chwil zdarzeń, więc nie wyprowadzam z nich procentowej poprawy między wersjami.

[Skrypt odtworzenia](C:/Users/nahiko/Documents/dev/sigil-visual-1103/work/visual/scripts/reproduce.ps1) zachowuje i przywraca dwa dozwolone punkty QA, ustawia APPDATA przed uruchomieniami LÖVE i uruchamia okna ukryte. Jego etapy wykorzystano podczas audytu; całego skryptu od początku do końca nie uruchamiano ponownie po złożeniu.

