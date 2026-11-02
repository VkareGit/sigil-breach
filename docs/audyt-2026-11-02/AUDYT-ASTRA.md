# Niezależny audyt SIGIL: BREACH

**Stan: commit `489e3a51355dd79062c4bbc8607fc12f5fedcfea`, wersja 0.41. Audyt: 2 listopada 2026.** Wszystkie numery linii odnoszą się do tego commitu. Skrót `src/` oznacza poniżej `game/src/`.

## Ocena i filary projektu

Gra ma wyraźną tożsamość, działającą pętlę wyprawy i rozbudowany warsztat techniczny. Największym problemem nie jest brak kolejnej warstwy architektury. Są nim niedomknięte połączenia istniejących mechanik: reset postaci, pochodzenie zabójstwa, ponawianie zapisu i komunikowanie ograniczeń działania. **Najpierw naprawiłbym te połączenia, następnie dopracował pierwsze spotkania i naukę walki.** Nie znalazłem podstaw do przepisywania silnika ani przeprojektowania HUD-u.

To obecnie grywalny wycinek Souls-like z jedną autorską kaplicą oraz poligonem, nie ukończona kampania. Brak bossów jako osobnego etapu rozwoju nie jest uchybieniem: Margrave i Furfur pełnią funkcję najtrudniejszych zwykłych przeciwników.

**Decyzje właściciela:** FPS w LÖVE 11.5/LuaJIT, rycerz bez magii, Exorcist i Judge, ogniska, żywy mroczny fresk. Styl demonów, broni oraz charakter, kształt i kompozycja dolnego paska pozostają chronione. Souls określa walkę i ryzyko; Call of Duty jest odniesieniem dla potwierdzenia strzału. Strzał nie zużywa wytrzymałości, lecz ogranicza przez chwilę unik. Serie mają należeć do konkretnej broni. Widoczni przeciwnicy nie powinni sprawiać wrażenia kolejki oczekującej. Tekst gry jest angielski.

**Stan potwierdzony kodem:** przejście od ogniska przez posterunki, zdobywanie dusz, otwieranie skrótów, odpoczynek i zakup trwałych ulepszeń; śmierć pozostawia echo, kolejna może je utracić. Odpoczynek odnawia przeciwników i zasoby. Są cztery ogniska, trzy sloty zapisu i piętnaście posterunków (`src/content/pilgrimage.lua:9`, `:57`, `:92`). Kaplica uzupełnia rezerwę do 20 nabojów Exorcista i 44 Judge’a, oprócz magazynków (`:25`). Rejestr obszarów istnieje, ale publiczna zawartość obejmuje jeden obszar.

**Moja interpretacja:** najmocniejsza obietnica gry to nauka odczytywania namalowanego ciała, wybór chwili strzału i świadome przygotowanie kolejnego podejścia. Inspiracja Doomem wspiera fizyczność trafienia, słabe punkty i rozróżnialne sylwetki; nie wymaga powrotu do nieustannego pędu. Nie ustalono docelowej długości kampanii, minimalnego sprzętu ani oczekiwanej skuteczności początkującego. Nie blokuje to wskazania błędów, ale blokuje ostateczną ocenę balansu i wymagań wydajnościowych.

## Zakres i wykonane sprawdzenia

Audyt wykonałem samodzielnie, bez delegowania i bez dostępu do wyników równoległego audytu. Przeczytałem wskazane instrukcje, bieżące sekcje zmian i odbioru, plany Souls/strzelania, historyczne audyty oraz dziennik napraw. Dokumentację historyczną, burzę mózgów, notatki dźwiękowe i podręczniki konfrontowałem z kodem; podręczników nie czytałem semantycznie strona po stronie.

Inwentaryzacja obejmuje **385 plików w `game/src`, 57 846 linii**, w tym duże deklaracje i dane grafiki; ponadto 181 plików testowych, 67 QA, 36 plików kodu narzędzi oraz 10 głównych skryptów PowerShell. Pełna lista: `work/audit-astra/inventory.csv`.

| Obszar kodu | Odpowiedzialność i głębokość przeglądu |
|---|---|
| `app`, `player` | Uruchomienie, wejście, buforowanie, przejścia ekranów i ruch; szczegółowo najważniejsze ścieżki. |
| `core`, `session`, `systems` | Stan, pule, kolejność symulacji, zdarzenia, konteksty, snapshot i replay; szczegółowo własność i granice, wybiórczo wszystkie implementacje serializacji. |
| `combat`, `physics`, `enemies` | Strzał, obrażenia, unik, egzekucja, efekty, AI, geometria kontaktu i nawigacja; szczegółowo ścieżki wysokiego ryzyka, wybrane algorytmy geometryczne. |
| `run`, `storage`, `world`, `content` | Cała pętla kaplicy, zapis, ekonomia, katalogi i walidacja; dane generowane oceniane przez format, producentów i konsumentów, nie każdą liczbę. |
| `render`, `feedback`, `ui`, `audio` | Przebieg klatki, zasoby, HUD, potwierdzenia i priorytety dźwięków; renderowanie sprawdzone także obrazem i pomiarem. Bez odsłuchu miksu. |
| `tests`, `qa`, `tools`, skrypty | Mapa zestawów, kontrakty i ważne scenariusze, wiarygodność pomiarów, checker, blokady i pakowanie. Generatory grafiki i pakowanie: przegląd statyczny, bez uruchamiania. |

To mapa całego projektu i przegląd według ryzyka, **nie deklaracja sprawdzenia każdej linii**.

**Uruchomione przeze mnie:**

- `TEST.ps1 -Suite All -TestTimeoutSeconds 1200`: kod wyjścia 0; format poprawny, 641 plików Lua skompilowanych, 0 uwag checkera; **5780 sprawdzeń mechaniki/zasobów i 50 wejścia** zakończonych powodzeniem. To liczby asercji, nie niezależnych scenariuszy.
- Render: 144 sceny w 960×540, 1024×768, 1280×720, 1720×720 i 1920×1080; 5306 kontroli granic elementów, brak zgłoszonych problemów układu. Testy narzędzi w `All` są typu smoke; `startup-check` ma pełny przebieg.
- Osobne `--chapel-look`: 23 PNG. Obejrzałem sceny pierwszego ogniska, sklepu, pomocy, mapy, śmierci, pauzy, serii, śladu obrażeń i utraty równowagi. Dodatkowo obejrzałem rendery rozszerzonego HUD-u w 960×540, 1024×768 i 1920×1080. Nie obejrzałem ręcznie wszystkich 144 scen.
- Pełne `--benchmark`, `--core-measure` oraz `--frame-watch`; zakończone kodem 0. Własne sondy wywołujące produkcyjne moduły, w tym wstrzyknięty błąd zapisu, rzeczywisty wybuch i powtórka zachowania bota.
- Zapisy i wyniki skierowane do `work/`. Źródła pozostały niezmienione; raporty QA potwierdzają niezmienność ich odcisku. Nie zbudowałem EXE/ZIP i nie wykonałem commitów.

Dowody: `work/audit-astra/test-all.log`, `work/qa/test-results.txt`, `work/qa/input-results.txt`, `work/qa/render-results.txt`, `work/qa/ui-layout-audit.txt`, `work/audit-astra/chapel/`, `work/audit-astra/probes.stdout.txt`. Sondy można powtórzyć przez `work/audit-astra/run-probes.ps1`; ich kod znajduje się w `work/audit-astra/probe/main.lua`.

**Granica playtestu:** nie wykonałem ręcznej rozgrywki. Dla uruchomionego przeze mnie ukrytego procesu zwykłej gry nie uzyskałem sterowalnego okna w dostępnym interfejsie automatyzacji; zakończyłem go. Nie jest to dowód błędu uruchamiania gry. Gra działała w testach i rendererze. Oceny doświadczenia poniżej są analizą kodu, oględzinami i wynikami automatów, nie relacją rzeczywistych graczy.

## Co działa dobrze i co zostało naprawione

Należy zachować:

- **Spójny fresk i charakter dolnego paska.** Duże liczby zdrowia i amunicji, jasne pola na ciemnej scenie, ornamenty i centralny hełm tworzą rozpoznawalny interfejs. Ekrany śmierci i ogniska mają czytelną hierarchię. Śmierć wprost wyjaśnia utratę poprzedniego echa.
- **Rozdział wejścia i ciężaru działania.** Symulacja 120 Hz, interpolacja bez opóźniania surowej myszy, obserwacja faktycznie pokazanego celu oraz bufory 350 ms strzału i 250 ms uniku są przemyślane (`src/app/input.lua:100`, `src/player/intent.lua:134`, `src/content/tuning.lua:98`). Testy obejmują prawdziwe callbacki LÖVE i czyszczenie wejścia przy utracie fokusu.
- **Kontakt zgodny z obrazem i czasem ciosu.** Maski malowanych ciał, strefy trafień, ścieżki aktywnych ataków, przeszkody i wysokość tworzą dużo solidniejszą podstawę niż sam test odległości. Wyjątek egzekucji opisuję osobno.
- **Walkę opartą na decyzjach.** Ograniczony unik, okna kontry, równowaga, egzekucja, odzysk zdrowia i przerwanie picia strzałem wzajemnie się uzupełniają. Koszt po strzale wynosi 220 ms dla Exorcista i 120 ms dla Judge’a (`src/content/weapons.lua:52`, `:126`).
- **Warsztat rozszerzeń.** Rejestry ze schematami, jawna kolejność systemów, osobne fazy zdarzeń, poligon, odtwarzanie i kontrakty zasobów ułatwiają dodawanie treści. `Registry.register` odrzuca duplikaty, a zamierzona podmiana ma osobne API (`src/core/registry.lua:22`).

Poprzednie audyty nie opisują już w całości obecnego stanu:

| Wcześniejszy temat | Ocena na tym commicie |
|---|---|
| Uszkodzony zapis, migracja, start gry i replay zależny od dysku | Istotnie poprawione: ograniczony parser, walidacja, kopie i odzyskiwanie, zapis pochodzenia sesji, izolacja replaya. Zestaw `pilgrimage-save` przeszedł 131 sprawdzeń. Pozostał inny błąd obsługi nieudanego zapisu — F01. |
| Zapis przy każdym zabójstwie | Poprawione: nagroda ustawia `dirty`, zapis czeka na ciszę albo trwałe zdarzenie/wyjście (`src/run/pilgrimage.lua:357`, `:379`). |
| Brak prawdziwej mapy w testach | Poprawione częściowo w sensie pokrycia: `proving` ma 56 sprawdzeń na rzeczywistej mapie. Przejścia do ognisk są jednak badane po usunięciu przeciwników (`game/tests/cases/proving.lua:16`, `:83`), więc nie dowodzą balansu całej wyprawy. |
| Jedna struktura obszaru, jeden slot, nietrwały ekwipunek, bezużyteczny sklep amunicji | Rejestr obszarów, trzy sloty, utrwalanie wyposażenia i śluby działają. Sklep ogniska sprzedaje trwałą progresję. Nie domknięto śmierci po przekroczeniu granicy obszaru — F05. |
| Koszt wyszukiwania celów, nieograniczone pozostałości i cache | Poprawione dla obecnego układu stron: `target.nearest` nie przegląda całej puli demonów, jeśli żaden nie może być wrogim celem (`src/enemies/target.lua:25`). Pozostałości mają limit 128, pola nawigacji 64. Renderer odcina ciała za kamerą. Nie oznacza to pełnego odcinania zasłoniętej sceny ani dowolnej skali tłumu. |
| Zależności trybów, sloty sklepu, klucze siatki, bramka pomiarów i raportowanie | Rejestr trybów oddzielony, dynamiczne sloty sprawdzane także dla numeru 12, wcześniejsze klucze poprawione. `MEASURE.ps1:140` zwraca błąd przy regresji lub wyniku nierozstrzygniętym. CI istnieje, ale uruchamia architekturę i format; jego zdalnego wykonania nie sprawdzałem. |

Nie odtwarzałem historycznego BUILD 0.39. Stare uwagi o falach i pełnych bossach nie są automatycznie zadaniami dla obecnej kaplicy. Wcześniejsze problemy izolacji obserwacji, pochylenia i jawnych podmian rejestrów mają obecnie dedykowane, przechodzące zestawy testowe; nie powtarzam ich jako aktualnych błędów.

## Ustalenia wymagające działania

P1 oznacza naprawę przed dalszym rozbudowywaniem głównej pętli; P2 — istotną poprawkę w najbliższym cyklu. Nie znalazłem podstaw do zgłoszenia P0.

**F01 — P1, nieudany zapis gubi obowiązek ponowienia. Pewność wysoka; kod i sonda.** `P.save` zeruje `r.dirty` przed wynikiem `Save.write` (`src/run/pilgrimage.lua:107–120`). Po zasymulowanej odmowie zapisu następne `flush` i aktualizacja przez 10 s nie wykonały ponownej próby: licznik wywołań pozostał 1, `dirty=false`. Ostrzeżenie istnieje, więc nie jest to całkowicie cicha awaria. Jednak po ustąpieniu przejściowego błędu najnowszy postęp może pozostać niezapisany aż do kolejnego trwałego zdarzenia. Poprzedni plik nie musi zostać uszkodzony.

**F02 — P1, odpoczynek i ponowna próba nie resetują całego stanu chwilowego. Pewność wysoka; kod i sondy.** `refresh` czyści warunki, zasoby i serię, ale pozostawia efekty okresowe oraz część fizyki; `retry` nie wykonuje pełnego resetu ruchu (`src/run/pilgrimage.lua:82–106`, `:274`, `:342`). Po zastosowaniu efektu Buera i odpoczynku sonda straciła w 0,6 s 2,7 HP oraz 3,3 wardu. Po rzeczywistym śmiertelnym ciosie zachowany impuls przesunął odrodzoną postać o około 0,18 m bez wejścia. Śmierć sama czyści efekty (`src/session/damage_outcomes.lua:219`); nie twierdzę, że trucizna przeżywa śmierć. Problem dotyczy różnych niepełnych ścieżek resetu.

**F03 — P2, seria przypisuje zabójstwo broni trzymanej, zamiast broni będącej źródłem. Pewność wysoka; rzeczywisty wybuch w sondzie.** `session/listeners.chain` ignoruje źródło i broń zdarzenia, a `Chain.kill` odczytuje bieżący slot (`src/session/listeners.lua:80–85`, `src/combat/chain.lua:20–24`). Jeden wybuch zabił trzy cele; przy zerowej liczbie strzałów powstała seria 3 przypisana Judge’owi. To narusza uzgodnioną zasadę. Samo nakładanie bonusu przez `Chain.edge` poprawnie sprawdza identyfikator broni — naprawa dotyczy pochodzenia zabójstwa, nie całego systemu.

**F04 — P2, egzekucja omija przeszkody i wysokość. Pewność wysoka; sztucznie przygotowane scenariusze geometryczne.** `Execution.target` sprawdza dystans w X/Z i kierunek, bez widoczności i pionowego zasięgu (`src/combat/execution.lua:14–33`). Produkcyjne `perform` zadało 216 obrażeń przez komórkę ściany rozpoznaną przez balistykę; osobno wykonało egzekucję przy różnicy wysokości 8 m. To potwierdza błąd API, nie częstość jego napotkania w normalnym przejściu kaplicy.

**F05 — P2 przed drugim obszarem, retry nie wraca na mapę ostatniego ogniska. Pewność wysoka; sonda rozszerzenia.** Drzwi zmieniają `run.area`, lecz po śmierci `P.retry` bierze tylko współrzędne ogniska, bez `enter` do jego obszaru (`src/run/pilgrimage.lua:245–254`, `:342–351`). Po przejściu do testowego aneksu na `floor` i śmierci bez odpoczynku gracz został na `floor`, w obszarze aneksu, ze współrzędnymi Narthex 27/33,5. Obecna pojedyncza kaplica tego nie ujawnia; jest to konkretna blokada rozbudowy, nie aktualny błąd każdej śmierci.

**F06 — P2, procent zdrowia jest surową liczbą HP. Pewność wysoka; kod i sonda.** `src/ui/hud.lua:136` dopisuje `%` do `p.hp`, podczas gdy pasek niżej używa udziału w maksimum. Po trzech ślubach zdrowia pełne 130/130 daje 130%; 100/130 daje 100% mimo niepełnego paska. Wystarczy poprawić znaczenie liczby w istniejącej niszy. Nie wymaga to zmiany paska ani oprawy.

**F07 — P2, ślad obrażeń zależy od rysowania i współdzieli stan między widokami. Pewność wysoka dla mechanizmu; kod i sonda funkcji.** `trail` jest globalną tabelą modułu, a jej czas maleje tylko w `follow`, wywoływanym podczas celowania w żywy cel (`src/ui/hud.lua:346–361`, `:385–402`). Odwrócenie wzroku wstrzymuje wygaszanie; powrót może pokazać starą sumę jak świeże trafienie. Osobne sesje/widoki używają tej samej tabeli. Pierwszy strzał bez wcześniejszego śledzenia celu może nie dać sumy. Stan powinien należeć do widoku, a jego czas do aktualizacji prezentacji.

**F08 — P2, nowe komunikaty konkurują o ten sam obszar. Pewność wysoka z geometrii kodu; bez osobnego renderu tej kombinacji.** Medal zajmuje Y=84–160, tytuł zaczyna się przy Y=162; powiadomienie ma panel Y=91–137, a podpowiedź niskiego zdrowia Y=139–185. Powiadomienia i podpowiedzi są rysowane po medalu (`src/ui/layout.lua:19`, `src/ui/hud.lua:457–507`, `:528–531`). Zabójstwo przy niskim HP i domyślnie włączonych podpowiedziach zasłania nagrodę. Oglądane sceny medalu miały podpowiedzi wyłączone, więc zielony raport układu nie zamyka tego przypadku.

**F09 — P2, niekompletna informacja o odmowie uniku. Pewność wysoka; kod i sonda.** `Game.canDodge` sprawdza `recoverAt`, ale `Intent.refusal` nie ma odpowiedniego powodu; celownik sprawdza blokadę strzelania (`src/session/game.lua:192`, `src/player/intent.lua:35–49`, `src/ui/hud.lua:310–324`). Natychmiast po strzale Exorcista unik został odrzucony na 220 ms, zbuforowany, lecz `refusal=nil`. Nie proponuję usuwania kosztu strzału. Potrzebny jest czytelny sygnał tego konkretnego ograniczenia.

**F10 — P2, widoczna kolejka przeciwników nadal istnieje. Pewność wysoka co do stanu; interpretacja wizualna osobno.** `watched` budzi widocznych wrogów tylko przy liczbie obudzonych mniejszej od `seenPack` (`src/enemies/ai.lua:193–229`). Sonda początku kaplicy po 0,5 s: 2 obudzonych, 6 w przednim stożku z linią widzenia, z tego 4 czekających. Render pierwszego ogniska pokazuje ustawione w nawie ciała. Stożek/LOS nie jest dokładnym testem widocznych pikseli, ale zgadza się z oględzinami. Limit dotyczy tego sposobu budzenia; hałas i bliskość mogą obudzić więcej niż dwóch. Nie należy po prostu usuwać limitu i zamieniać początku w szturm całej kaplicy.

**F11 — P2, `frame-watch` mierzy głównie sklep. Pewność wysoka; wykonanie i powtórka sterowania.** Pętla obsługuje śmierć, lecz nie wyjście ze sklepu (`game/qa/reviews/frame_watch.lua:108–156`). Bot używa `interact` przy próbie egzekucji, co przy ognisku może otworzyć handel (`game/qa/souls_bot.lua:151`). W przebiegu były 4 strzały; odtworzenie bez renderera dało 444 klatki gry i 3156 sklepu, czas symulacji 7,408 s. Mediana całego przebiegu nie jest wiarygodnym pomiarem minutowej walki. To błąd narzędzia diagnostycznego, nie dowód wadliwego sterowania człowieka.

**F12 — P2, powrót z poligonu do menu ma ciężką pierwszą klatkę bez przygotowania. Pewność wysoka; pomiar i zgodna ścieżka kodu.** Sześć powrotów benchmarku dało około 1,65–1,72 s na pierwszą kompletną klatkę menu. `Navigation.back` wywołuje `adopt(previous)` (`src/app/navigation.lua:45–60`); dla stanu `menu` `adopt` pomija przygotowanie (`src/app/application.lua:87–92`), a `Renderer.draw` przygotowuje świat synchronicznie (`src/render/renderer.lua:545–565`). To powtarzalny moment mogący wyglądać jak zawieszenie. Czas zależy od sprzętu; nie przypisuję całych 1,6 s konkretnej funkcji bez jej profilowania. Należy objąć ten powrót istniejącym planem ładowania.

## Wydajność, skalowalność i doświadczenie

Pełny benchmark: Intel Arc Graphics, OpenGL 3.3, sterownik 32.0.101.8826, okno 1280×720, wewnętrzna wysokość sceny 900, VSync wyłączony. Poniżej **czas kompletnej próbki z odczytem końcowego canvasu**, nie FPS ekranu ani opóźnienie wejścia. Po 240 próbek na wariant:

| Scenariusz | Mediana | p95 | p99 |
|---|---:|---:|---:|
| 4 ciała, zamrożone efekty, bez kroku symulacji | 5,60 ms | 6,77 ms | 7,63 ms |
| 20 ciał, dużo zamrożonych efektów, bez kroku symulacji | 7,97 ms | 9,71 ms | 10,99 ms |
| Przygotowany tłum 20, z aktualizacją | 8,28 ms | 10,70 ms | 13,23 ms |
| Przygotowany tłum 48, z aktualizacją | 11,70 ms | 17,18 ms | 35,10 ms |
| Przygotowany tłum 96, z aktualizacją | 14,09 ms | 18,62 ms | 22,30 ms |

Rdzeń: krok symulacji 15 obudzonych ciał kaplicy miał medianę **0,268 ms**, p95 **0,664 ms**; samo ponowne obsadzenie posterunków **7,19 ms**, bez pełnej transakcji odpoczynku i zapisu. Dla 20 ciał w scenariuszu rdzenia: mediana **0,460 ms**, p95 **0,845 ms**. Po przeniesieniu 19 zwłok do pozostałości: p95 **0,036 ms**. To mocne argumenty za zachowaniem obecnej architektury dla kilkunastu przeciwników.

**Skalowalność wydajnościowa:** warianty 48/96 pokazują rosnący koszt i ogony rozkładu. Nie jest to obietnica takiej liczby przeciwników w gotowym poziomie. Wyniki nie są monotoniczne i pochodzą z pojedynczego przebiegu na współdzielonym komputerze. Nie wykonywałem porównania A/A ani A/B przez `MEASURE.ps1`; nie rozstrzygam regresji względem starszych commitów. `frame-watch` miał medianę 5,66 ms i maksimum 966 ms, lecz z powodu F11 oraz zimnej pierwszej klatki nie traktuję tych liczb jako oceny płynności walki.

Po rozgrzaniu benchmark raportował około **740–742 MiB tekstur**, 113–114 obrazów i 5 canvasów; liczby zasobów pozostawały stabilne podczas kolejnych powrotów. To nie dowód wycieku, ale istotny budżet przy kolejnych atlasach. Krótkie 300 cykli rdzenia nie wykazało narastania sterty; nie zastępuje to wielogodzinnej sesji. Raporty: `work/audit-astra/benchmark/benchmark.txt`, `work/audit-astra/core20/core-measure.txt`, `work/audit-astra/frames/frame-watch.txt`.

**Skalowalność architektury:** dane przeciwnika/broni można dodawać przez istniejące kontrakty; nowy rodzaj zachowania nadal wymaga wykonawcy, prezentacji i testów. To właściwa granica, nie wada. Najbardziej zagrożone są skrzyżowania własności: aktor–broń–zdarzenie oraz sesja–obszar–zapis–widok. F02, F03, F05 i F07 wskazują właśnie te miejsca. Nie ma uzasadnienia dla nowego ECS, wielowątkowości czy przebudowy wszystkich fasad. Wystarczą wspólne kontrakty resetu i pochodzenia zdarzeń oraz usunięcie stanu z rysowania.

**Skalowalność produkcji treści:** poligon, schematy, maski i kontrola prawdziwej mapy pomagają. Kosztem nowego demona będą głównie kompletna animacja, anatomia trafień, czytelność ciosów i odbiór, nie samo dopisanie rekordu. Drugą lokację należy sprawdzić jako pełną drogę z zapisem i śmiercią, nie tylko rejestrację mapy. Dokumentacja wejściowa wymaga aktualizacji: `START-HERE.txt:1` nadal opisuje 0.33, `INSTRUKCJA.txt:49` nazywa F/C przyszłymi slotami, a `ROZSZERZANIE.txt:634` odsyła do usuniętego `Execution.read`. Notatki dźwiękowe o niepodłączonych głosach też są historyczne — `src/audio/recipes.lua:580–582` już je importuje.

**Pierwsze minuty:** cel „przejdź kaplicę, odpoczywaj przy ogniskach” i podstawowe klawisze są widoczne. Pomoc nie wyjaśnia jednak dostatecznie kontry strzałem, egzekucji, odzysku zdrowia, kosztu po strzale ani utraty ochrony uniku po strzale (`src/ui/screens/help.lua:76–92`, `src/combat/combat.lua:89–92`). To ryzyko uczenia się przez niezrozumiałą karę, nie wynik badania początkujących. Proponuję krótkie wskazówki uruchamiane przez zdarzenie i jedną aktualną stronę zasad; bez zatrzymywania każdej walki.

**Trudność i spójność:** świeże testy pokazują, że stojący i strzelający bot ginie z Margrave’em po 9,9 s, z Furfur po 5,5 s; proste odruchy też przegrywają. Zwykłe ciała są znacznie łatwiejsze w izolacji. To wspiera zróżnicowanie ról, ale nie dowodzi czytelnej krzywej dla człowieka. Bot zna fazy i parametry ataku. Nie rekomenduję automatycznego obniżania HP, skracania ciosów ani zwiększania amunicji. Obecne zapasy trzeba ocenić na trasie między ogniskami przy chybieniach i używaniu obu broni; seria z limitem sześciu sekund nie powinna skłaniać początkującego do samobójczej pogoni kosztem zasad Souls.

**Porażka i dalsza progresja:** echo, ponowna próba, stałe skróty i trwałe śluby tworzą spójną pętlę. Ekran śmierci dobrze wyjaśnia karę. Niesprawiedliwe są zachowane efekty/impulsy po odpoczynku i ewentualna utrata niezapisanego postępu, nie sama utrata dusz. Brak finału kampanii i kolejnych obszarów to zakres obecnej treści, nie błąd techniczny.

### Małe poprawki czytelności bez zmiany designu

| Problem → sytuacja gracza | Poprawka → spodziewany efekt | Sprawdzenie |
|---|---|---|
| F06: liczba zdrowia przeczy paskowi po ulepszeniu. | Liczyć procent względem maksimum w tej samej niszy → jednoznaczny stan zdrowia. | 0/100, 100/130 i 130/130; zachowana geometria i ornament. |
| F08: medal, informacja i rada walczą o uwagę przy niskim HP. | Ustalić priorytety i rozłączne miejsca w górnej części; odroczyć mniej pilny komunikat → nagroda nie zasłania zagrożenia. | Jednocześnie medal, niskie HP, egzekucja, echo i komunikat; pięć rozdzielczości. |
| F09: kliknięty unik czeka po strzale bez wyjaśnienia. | Krótki znak/podpis gotowości uniku przy obecnym celowniku, pokazany po próbie → widoczny koszt bez rozwadniania walki. | Próby tuż przed i po 120/220 ms; żadnego wydłużenia blokady. |
| Drobne opisy wyposażenia/serii tracą szczegóły w 960×540; font 11 skaluje się do około 8 px. Ocena wizualna, nie pomiar rozpoznawalności. | W obrębie obecnych pól dobrać grubsze glify, odstępy i krótsze etykiety; pełna ceremonialna nazwa pozostaje na medalu → szybszy odczyt. | Odczyt F/Q, liczby użyć, rezerwy i serii w ruchu, także na najmniejszym oknie; porównanie przed/po. |
| Seria jest związana z bronią, ale po zmianie slotu jej stały znak nie wyjaśnia właściciela (`src/ui/hud.lua:139–159`). | Dyskretne powiązanie znaku z właściwym wierszem broni → wiadomo, kiedy bonus działa. | Seria Exorcista, zmiana na Judge’a, powrót; bez nowego stałego panelu. |

Nie proponuję zmiany kształtu, wysokości, podziału ani kompozycji dolnego paska. Nie ma tu wariantu wymagającego naruszenia chronionego designu. Kontrast demonów z freskami i rozróżnianie sygnałów audio wymagają próby w ruchu oraz odsłuchu. Bez tego nie uzasadniam zmiany palety, stylu demonów ani głośności całego miksu.

## Plan napraw i rozwoju

Nakład: **S** — lokalna zmiana z ukierunkowaną weryfikacją; **M** — kilka powiązanych ścieżek i zestawów testowych; **L** — kilka iteracji zawartości i odbioru. To względna skala pracy, nie obietnica terminu. Dowody Fxx są częścią opisu zadań.

### Konieczne naprawy

| ID / priorytet / problem | Zmiana i korzyść | Kolejność, nakład, ryzyko | Sprawdzalne ukończenie |
|---|---|---|---|
| N01 / P1 / F01 | Czyścić `dirty` dopiero po sukcesie; zachować oczekującą próbę i ograniczyć częstotliwość ponowień. Chroni postęp. | Pierwsze; S; ryzyko średnie, zapis/replay. | Przejściowa odmowa, późniejszy sukces, flush i ponowne uruchomienie zachowują najnowszy stan; brak pętli zapisu co klatkę. |
| N02 / P1 / F02 | Ustalić wspólny reset stanu chwilowego aktora dla odpoczynku, retry i podróży; wykorzystać istniejących właścicieli efektów/ruchu. Przywraca uczciwe podejście. | Po N01; M; ryzyko średnie. | Testy efektu Buera, śmiertelnego impulsu, równowagi i aktywnej akcji; po resecie brak obrażeń/ruchu bez nowej przyczyny, wyposażenie i progresja zachowane. |
| N03 / P2 / F03 | Przenosić źródłową broń ze zdarzenia zabójstwa do serii; jawnie obsłużyć granat, egzekucję i opóźnione trafienia. Przywraca regułę właściciela. | Niezależne od N01–02; M; ryzyko średnie. | Prawdziwe strzały budują właściwą serię; trzy zabójstwa granatem przy zerze strzałów jej nie budują; zmiana broni nie przepina pochodzenia. |
| N04 / P2 / F04 | Dodać przeszkody i pionowy zasięg do wspólnego wyboru celu egzekucji oraz promptu. Przywraca spójność kontaktu. | Niezależne; S/M; ryzyko średnie przy geometrii. | Brak wykonania przez ścianę i między niedostępnymi poziomami; legalna egzekucja po kontrze nadal działa przy krawędzi zasięgu. |
| N05 / P2 / F05 | Retry przełącza na obszar ogniska przed odrodzeniem i zachowuje ruiny/echo właściwych map. Odblokowuje kolejną lokację. | Po N02, przed nowym obszarem; M; ryzyko średnie. | Wejście do B bez odpoczynku, śmierć, retry w A, powrót po echo w B; także zapis i ponowny start. |
| N06 / P2 / F06 | Poprawić obliczenie procentu HP bez zmiany oprawy. Eliminuje sprzeczne wskazania. | Niezależne; S; ryzyko niskie. | Liczba i pasek zgadzają się dla wszystkich rang ślubu; pełne zdrowie to 100%. |
| N07 / P2 / F07 | Przenieść historię obrażeń do stanu widoku i aktualizacji prezentacji, zasilanej wynikami trafień. Odczyt przestaje zależeć od liczby rysowań. | Przed końcowym odbiorem GUI; M; ryzyko średnie. | Pierwsze trafienie, odwrócenie wzroku na ponad 0,7 s, zmiana celu, dwie sesje i dwa widoki nie mieszają ani nie zamrażają historii. |
| N08 / P2 / F08–09 | Rozdzielić komunikaty nad sceną i pokazać powód oczekiwania na unik; pozostawić istniejące reguły czasu. Poprawia czytelność intensywnej walki. | Po N03 i N07 do odbioru łącznego; M; ryzyko niskie/średnie. | Przypadki z tabeli GUI przechodzą testy geometrii i oględziny; koszt strzału i bufor wejścia nie zmieniają się. |
| N09 / P2 / F11 | Naprawić scenariusz bota pomiarowego; raportować czas i percentyle osobno dla walki, menu, śmierci i ładowania. Zapobiega fałszywym wnioskom. | Przed strojeniem wydajności; S/M; ryzyko niskie. | Pełne 60 s aktywnej symulacji scenariusza; jawne liczby strzałów/ciosów i stanów; sklep nie może po cichu zastąpić walki. |
| N10 / P2 / F12 | Przy powrocie do menu przygotować jego świat przez istniejący LoadPlan, zanim nastąpi ciężkie rysowanie. Usuwa pozorne zawieszenie przejścia. | Po N09 dla odbioru; M; ryzyko średnie, nawigacja/zasoby. | Kilka powrotów z poligonu pokazuje postęp przygotowania; pierwsza klatka menu nie przebudowuje synchronicznie świata. Porównać czasy i liczbę zasobów przed/po. |

### Usprawnienia

| ID / priorytet / problem | Zmiana i korzyść | Kolejność, nakład, ryzyko | Sprawdzalne ukończenie |
|---|---|---|---|
| U01 / P2 / F10 | Zmienić ustawienie posterunków, patrole i zasłanianie widoków na początku kaplicy. Widoczny świat przestaje wyglądać jak kolejka. Bez automatycznego zwiększania presji ani zmiany mechanik mobów. | Po N02, N03, N08; M/L; ryzyko średnie dla trudności. | Oględziny początku i podejść z kilku kierunków; brak widocznej biernej kolejki, nadal możliwe świadome rozdzielenie spotkań; pomiar aktywnych zagrożeń i prób nowych graczy. |
| U02 / P2 / nauka i czytelność | Wprowadzić krótkie objaśnienia kontry, egzekucji, odzysku i kosztu strzału; poprawić drobne opisy w istniejących niszach. Zaktualizować instrukcję, wejście do repo i odsyłacze API. | Po N08, razem z U01; M; ryzyko niskie. | Nowy gracz potrafi wyjaśnić odmowę uniku i sposób otwarcia egzekucji; odczytuje zasoby w 960×540; instrukcja zgadza się z callbackami i kodem. |
| U03 / P2 / nieustalony budżet sprzętu i miksu | Po N09 wykonać kontrolowane pomiary na sprzęcie docelowym oraz odsłuch zwykłego trafienia, pancerza, zabójstwa, multikilla i ostrzeżeń w walce. Profilować konkretną drogą fazę przed optymalizacją. | Po N09–10; M; ryzyko niskie dla pomiaru. | Ustalony sprzęt odniesienia, aktywny scenariusz, stabilność A/A, p95/p99 i zasoby; ostrzeżenia rozróżnialne pod ogniem. Osobno udokumentowany odbiór dźwięku. |

### Opcjonalny rozwój

**O01 / P3 — druga krótka droga z istniejących elementów.** Dopiero po N05 oraz odbiorze U01–02. Problem do rozwiązania: sprawdzenie produkcji treści poza jedną kaplicą, nie brak kolejnej abstrakcji. Zakres: obszar, ognisko, skrót i spotkania z obecnymi przeciwnikami; bez bossów i nowych systemów. Korzyść: realny test rejestrów, zapisów i tempa progresji. Nakład L, ryzyko średnie. Ukończenie: pełne przejście w obie strony, śmierć przed i po zapaleniu ogniska, odzyskanie echa, zapis/wczytanie, walidacja mapy i odbiór gracza. To propozycja rozwoju, nie warunek zamknięcia obecnych napraw.

## Ograniczenia i pytania do weryfikacji

- Nie było ręcznego playtestu, badań graczy, odsłuchu, pomiaru fizycznego opóźnienia myszy/klawiatury, testów innych GPU ani wielogodzinnej sesji. Nie podaję ich domniemanych wyników.
- Pełny eksport dźwięków i `step-study` nie były uruchamiane poza profilem smoke. Pakowania nie uruchamiałem zgodnie z zakazem; oceniałem jego kod. Nie przeprowadzałem kompletnego audytu bezpieczeństwa zależności i historii Git.
- Wynik `startup-check` potwierdza etapy ładowania, obsługę błędu i anulowania. Jego pierwsze menu używa flagi przechwytywania, która zmienia przygotowanie (`game/qa/runtime.lua:45`, `src/app/application.lua:309`); nie przenoszę jego zimnych opóźnień wprost na zwykły start gry.
- Do ustalenia pozostają: sprzęt i rozdzielczość odniesienia, oczekiwana długość drogi między ogniskami oraz docelowy poziom opanowania zasad przez początkującego. Nie trzeba czekać na te odpowiedzi z N01–N10.
- Najważniejsza próba z człowiekiem: świeży slot, pierwsze ognisko, walka obiema broniami, unik po strzale, kontra i egzekucja, obrażenia z boku, odpoczynek po efekcie Buera, śmierć i odzyskanie echa. Zanotować konkretne pomyłki i przyczyny zgonów. Dopiero wtedy rozstrzygać o zmianie zapasów, trudności lub intensywności efektów.
