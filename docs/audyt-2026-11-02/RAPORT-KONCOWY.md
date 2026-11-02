# Raport końcowy: SIGIL: BREACH, commit 489e3a5 (0.41)

Synteza dwóch niezależnych audytów z 2 listopada 2026. Pliki źródłowe: `AUDYT-CLAUDE.md`, `AUDYT-ASTRA.md`, surowe dane: `POMIARY-CLAUDE.txt`, `SONDY-ASTRA.txt`.

## 1. Stan projektu i zakres weryfikacji

0.41 to grywalny wycinek: jedna kaplica, 15 stworów, 4 ogniska, 2 bronie, zapis w 3 slotach. Bossów i zakończenia nie ma z decyzji właściciela. `BUILD.ps1` przechodzi w całości (5780 sprawdzeń mechaniki, render, wejście, 0 uwag architektury).

Jak prowadzono audyty:

| | Claude | Astra |
|---|---|---|
| Model i poziom | Opus 5.5 | `gpt-6-astra`, `ultra` (dostępne `low`–`max`, `ultra`; log sesji potwierdza `"effort":"ultra"`) |
| Prompt | `PROMPT-AUDYTU.md`, SHA-256 `4BC1C915…8E24` | ten sam plik bajt w bajt |
| Kod | główne repozytorium | osobny klon commitu 489e3a5 |
| Kolejność | audyt zapisany przed odczytem Astry, SHA-256 `7776DB83…C716` | wyniku nie czytałem do końca obu prac |
| Uruchamianie | testy, rendery, bot, sondy | testy `All`, rendery, benchmark, sondy; piaskownica `unelevated` |
| Czas | w tej sesji | około 21 minut |

Różnice w dostępie:
- Znam historię tej rozmowy, Astra dostała jej streszczenie w prompcie.
- Astra miała zablokowany `%APPDATA%`, dostała katalog zastępczy i wskazówkę w prompcie.
- Astra nie mogła sterować zwykłym oknem gry.
- Pomiary klatek obu stron częściowo się nakładały.

Żaden model nie grał ręcznie i nie słyszał dźwięku.

## 2. Porównanie

| Obszar | Oba | Tylko Claude | Tylko Astra | Rozstrzygnięcie |
|---|---|---|---|---|
| Połączenia mechanik | HP z `%` | Furfur 0 dusz, martwe gałęzie strażnika | nieudany zapis gubi ponowienie; reset po odpoczynku niepełny; seria liczy trzymaną broń; egzekucja przez ścianę i 8 m w pionie; retry między obszarami | sprawdziłem kod Astry, wszystkie 5 potwierdzone. Pominąłem je, bo czytałem pętlę, a nie ścieżki błędów |
| Pętla Souls | brak nauki kontry i egzekucji; widoczna kolejka stworów | amunicja nie zabija najtwardszych; odpoczynek w walce; stromy próg nawy; górne serie nieosiągalne; brak przyczyny śmierci | brak powodu oczekiwania na unik | ustalenia się uzupełniają |
| GUI | medal zasłaniany; font 11 → 8 px przy 960×540; bez zmian w designie paska | ucięte „TRIPTY...” i „[ TAB...”; ciasne Q/F; małe znaki uniku; złoty romb; podpowiedź przy pustej flasce; dwie nazwy broni | stan `trail` w rysowaniu; do której broni należy seria | pełna suma |
| Wydajność | `--frame-watch` mierzył sklep; 15 ciał nie stanowi problemu | prawdziwa gra: 12/3600 klatek ponad 16,7 ms na spokojnej maszynie | powrót do menu 1,65–1,72 s; 740 MiB tekstur; tłum 48–96 | oba pomiary zostają |
| Dokumenty | START-HERE i INSTRUKCJA nieaktualne | KONTEKST | `ROZSZERZANIE.txt:634` | pełna suma |

Rozbieżności:

| Spór | Claude | Astra | Dowód | Stanowisko |
|---|---|---|---|---|
| Amunicja | braki przed najtwardszymi | nie zwiększać | sonda na najlepszej wysokości: Margrave 5091/9000, Furfur 4926/10000 przy 100% trafień; egzekucja 8% i 7% | Fakt potwierdzony. Astra ma rację, że liczb nie wolno ruszać przed próbą człowieka. Sprzeczność znika: najpierw decyzja, potem jedna zmienna |
| Trudność | stromy próg | bez dowodu dla ludzi | bot 0 / 0,1 / 0,3: 3 / 6–8 / 12–13 śmierci | czułość na celność potwierdzona dla bota, dla człowieka otwarte |
| Priorytety | P0 dla odpoczynku i drobiazgów | brak P0, najpierw połączenia | żaden błąd nie blokuje startu ani gry | przyjmuję kolejność Astry dla napraw. Odpoczynek w walce to potwierdzone zachowanie, ale decyzja projektowa, nie naprawa |
| Wytrzymałość | zbędny drugi limit | uznaje unik za mocną stronę | bot: `no_dodge` 170, `no_breath` 34 | limit działa rzadko, lecz działa. Niski priorytet, decyzja po grze |
| Kolejka stworów | zmienić `seenPack` | najpierw ustawienie i zasłony | sonda Astry: 2 obudzone, 4 czekają | najpierw ustawienie, reguła AI tylko za zgodą |
| Ślad obrażeń | niski priorytet | P2 z sondą | sonda: czas stoi poza celem | Astra ma rację, to mój kod z ostatniej zmiany |

Nierozstrzygnięte: odczucie strzału, miks dźwięku, trudność dla ludzi, sprzęt odniesienia, błąd `Report was not written` (raz, nieodtworzony), skutek martwego `guardianDead` w muzyce SKIRMISH, realna siła ładunku Q (sonda dała 27 obrażeń i mogła nie trafić wybuchem).

## 3. Raport końcowy

Fundament techniczny jest mocny i nie wymaga przepisywania: determinizm, testy, architektura, wydajność przy obecnej skali, styl. Słabe miejsca to szwy między systemami i to, że pętla Souls nie jest jeszcze domknięta.

Najważniejsze wnioski:

1. **Pięć potwierdzonych błędów połączeń** psuje uczciwość: trucizna po odpoczynku, odrzut po śmierci, utrata ponowienia zapisu, seria na złą broń, egzekucja przez ścianę.
2. **Najtwardszych stworów nie da się zabić samą amunicją z ogniska.** Przy 100% trafień z całego zapasu schodzi 57% Margrave'a i 49% Furfura. Reszta to co najmniej 6 odbić zakończonych egzekucją, a gra nigdzie tego nie uczy. Limit `carried` doszedł w 0.41, a HP pochodzi z czasów bez limitu.
3. **Ognisko działa jak teleport leczący:** odpoczynek przy czuwającym stworze leczy do pełna i cofa wszystkich na posterunki.
4. **Gra nie uczy swojego rdzenia:** ani słowa o odbiciu, złotym pierścieniu, gardzie, egzekucji, rally i bonusach serii.
5. **Dolny pasek jest dobry.** Kontrast 7,5–11:1. Poprawiać trzeba wagę informacji i marginesy, nie projekt.
6. **Dowód płynności z 0.40 był zawyżony,** bo mierzył głównie sklep. Prawdziwa gra po poprawce sondy też wypada dobrze (12/3600), ale wniosek trzeba oprzeć na właściwym pomiarze.

Spójność inspiracji: Souls i Call of Duty nie kolidują, dopóki CoD dotyczy potwierdzeń. Konflikt leży między warstwą FPS (szybki bieg, dwa ładunki uniku) a kosztem pozycji oraz między rzadką amunicją a gąbczastym HP.

Efekt łączny, zasady dla całego planu:
- Nad sceną najwyżej jeden napis pod celownikiem i jeden komunikat. Podpowiedzi nauki poza gorącą walką. Inaczej nowe teksty zniszczą to, co naprawiają.
- Dolny pasek: te same nisze i kompozycja, zmieniają się tylko wielkość i marginesy treści.
- Balans po jednej zmiennej naraz, z botem i próbą właściciela. Naprawa serii obniży jej częstość, więc progi stroić po niej.
- Czerwień przy celowniku tylko dla zabójstwa, złoto tylko dla gardy.

## 4. Plan rozwoju i poprawek

To propozycja modeli, właściciel jej jeszcze nie zatwierdził. Nakład: S, M, L. Priorytet: P1 konieczne, P2 usprawnienia, P3 rozwój.

**Decyzje właściciela:** D1 czy odpoczynek przy czuwającym stworze ma być zablokowany. D2 jak zabija się Margrave'a i Furfura: mniej HP, więcej amunicji, zdobywana amunicja czy atak awaryjny. D3 ładunki uniku czy wytrzymałość. D4 czy stwory na widoku mają ruszać wszystkie. D5 co kończy kaplicę. D6 mapa odkrywana czy pełna. D7 ile dusz daje Furfur.

### Etap 0: uczciwe połączenia i prawdziwe dowody

| ID | P | Problem i dowód | Zmiana | Korzyść | Zależy | Nakład / ryzyko | Ukończone, gdy |
|---|---|---|---|---|---|---|---|
| R01 | P1 | `P.save` zeruje `dirty` przed zapisem (`run/pilgrimage.lua:109`), sonda: 1 próba | czyścić po sukcesie, ograniczyć ponowienia | postęp nie ginie | – | S / średnie | odmowa, potem sukces: stan zapisany, brak pętli co klatkę |
| R02 | P1 | `refresh` nie czyści efektów, `retry` impulsu; sonda: 2,7 HP po odpoczynku, 0,18 m po śmierci | wspólny reset aktora dla odpoczynku, retry, podróży | uczciwe podejście | R01 | M / średnie | testy: Buer, śmiertelny impuls, aktywna akcja |
| R03 | P1 | `Chain.kill` czyta trzymaną broń (`combat/chain.lua:21`); sonda: 3 zabójstwa ładunkiem, 0 strzałów, seria Judge'a | przenieść broń ze zdarzenia | reguła właściciela działa | – | M / średnie | ładunek nie buduje serii, zmiana broni nie przepina |
| R04 | P1 | `Execution.target` bez ściany i wysokości; sonda: przez ścianę, 8 m | wspólny warunek z zasłoną i pionem | spójny kontakt | – | S–M / średnie | brak egzekucji przez ścianę, legalna działa |
| R05 | P1 | HP i ward z `%`, pasek wardu dzieli przez 100 (`ui/hud.lua:136,168-169`); sonda 130% | liczyć wobec maksimum | prawda na pasku | – | S / niskie | 100/130 i ślub wardu zgodne z paskiem |
| R06 | P1 | `--frame-watch` mierzy sklep | zamykać sklep, raport osobno dla stanów; sprostować ODBIOR 0.40 | wiarygodny dowód | – | S / niskie | 60 s gry, ponad 40 strzałów, 0 klatek sklepu |
| R07 | P1 | Furfur 0 dusz | wartość z D7 | nagroda | D7 | S / niskie | sonda: dusze > 0 |
| R08 | P2 | START-HERE, KONTEKST, INSTRUKCJA, ROZSZERZANIE nieaktualne | zaktualizować | nowy agent nie błądzi | – | S / brak | zgodne z `build.lua` i kodem |
| R09 | P2 | złoty romb, stary komentarz, `multikill`, gałęzie `guardianFell`, SHOTGUN/EXORCIST | usunąć, ujednolicić | czystość języka | – | S / niskie | skan czysty, zrzuty |

### Etap 1: czytelność bez zmiany designu

| ID | P | Problem i dowód | Zmiana | Korzyść | Zależy | Nakład / ryzyko | Ukończone, gdy |
|---|---|---|---|---|---|---|---|
| G01 | P1 | „TRIPTY...”, „[ TAB...” | pełne słowa lub sama pieczęć; audyt układu traktuje wielokropek jako błąd | nagroda czytelna | – | S / niskie | wszystkie serie bez wielokropka w 5 rozdzielczościach |
| G02 | P2 | `trail` w module i rysowaniu (`ui/hud.lua:346`) | stan w widoku, czas w aktualizacji | suma nie kłamie | – | M / średnie | odwrócenie wzroku, zmiana celu, dwie sesje |
| G03 | P2 | medal pod komunikatem i podpowiedzią; podpowiedź przy pustej flasce | priorytety i rozłączne miejsca; warunek flaski | nagroda i zagrożenie widoczne | G02 | M / niskie | medal + niskie HP + komunikat bez nakładania |
| G04 | P2 | brak powodu oczekiwania na unik; czerwony napis 4,3:1 | krótki sygnał po próbie, napis w kości słoniowej z tuszem | responsywność widoczna | – | S / niskie | próba po 120 i 220 ms pokazuje powód, czas bez zmian |
| G05 | P2 | Q/F 11 px przy krawędzi niszy, małe znaki uniku, niskie HP prawie bez zmiany koloru | większa liczba użyć, marginesy, wyraźniejsze znaki, ton niskiego HP; te same nisze | szybki odczyt | G01 | S–M / niskie | zrzuty 1280×720 i 960×540, zgoda właściciela |
| G06 | P2 | nie widać, do której broni należy seria | znak przy wierszu broni | wiadomo, kiedy działa bonus | R03 | S / niskie | zmiana broni i powrót |

### Etap 2: domknięcie pętli

| ID | P | Problem i dowód | Zmiana | Korzyść | Zależy | Nakład / ryzyko | Ukończone, gdy |
|---|---|---|---|---|---|---|---|
| L01 | P1 | brak człowieka w dowodach | próba właściciela według scenariusza z raportu, notatki zgonów | fakty do balansu | Etap 0 | S / brak | notatka z próby w `PLAN` |
| L02 | P1 | odpoczynek w walce, sonda 10 → 100 HP | wg D1 | ognisko bezpieczne, nie teleport | D1 | S / średnie | odmowa z powodem albo świadome „zostaje” |
| L03 | P1 | M1: 57% i 49% | wg D2, sonda `feasible` na trasie, jedna zmienna | walka do wygrania | D2, L01 | M / wysokie | wykonalne przy celności ustalonej z właścicielem; bot; ocena |
| L04 | P1 | brak nauki rdzenia (`content/text.lua`) | jedna strona zasad, krótkie podpowiedzi po zdarzeniu, poza gorącą walką | Souls da się zrozumieć | G03 | M / niskie | każda mechanika ma tekst i test; właściciel potwierdza |
| L05 | P2 | kolejka stworów: 2 obudzone, 4 czekają | ustawienie, patrole, zasłony; regułę AI tylko po D4 | świat nie wygląda jak kolejka | L01, D4 | M–L / średnie | oględziny, bot, próba |
| L06 | P2 | stromy próg nawy, bot 0,1: 1 z 2 dochodzi | tempo i rozstawienie po L05 | uczciwy pierwszy próg | L03, L05 | M / średnie | bot 0,1 dochodzi w większości; ocena właściciela |
| L07 | P2 | brak przyczyny śmierci | linia „co zadało ostatni cios” | zrozumienie porażki | – | S / niskie | test i zrzut |
| L08 | P2 | TETRAPTYCH 1 raz, POLYPTYCH 0 na 185 zabójstw | progi pod rzeczywistą gęstość | leczenie serią osiągalne | R03, L06 | S / niskie | bot osiąga POLYPTYCH przy dobrej grze |
| L09 | P3 | dwa limity uniku | wg D3 | jedna reguła | D3, L01 | M / wysokie | jeden limit, jeden komunikat |

### Etap 3: gotowość do rozbudowy

| ID | P | Problem i dowód | Zmiana | Korzyść | Zależy | Nakład / ryzyko | Ukończone, gdy |
|---|---|---|---|---|---|---|---|
| E01 | P2 | retry zostaje w obcym obszarze, sonda aneksu | przejście do obszaru ogniska | drugi obszar możliwy | R02 | M / średnie | wejście, śmierć, retry, powrót po echo, zapis |
| E02 | P2 | powrót do menu 1,65–1,72 s | przygotowanie przez LoadPlan | brak pozornego zawieszenia | R06 | M / średnie | pierwsza klatka nie buduje świata |
| E03 | P2 | CI tylko Architektura; 6/146 przypadków o kaplicy | scenariusz kaplicy, ocena mechaniki w CI, diagnoza `Report was not written` | mniej regresji | – | M / niskie | CI rozszerzone albo powód na piśmie |
| E04 | P3 | brak sprzętu odniesienia i odsłuchu | pomiar A/A, odsłuch właściciela | świadomy budżet | R06 | M / niskie | zapisany sprzęt, p95/p99, notatka o miksie |

### Etap 4: rozwój

| ID | P | Problem i dowód | Zmiana | Korzyść | Zależy | Nakład / ryzyko | Ukończone, gdy |
|---|---|---|---|---|---|---|---|
| F01 | P3 | gra bez końca | koniec kaplicy wg D5 | gra się kończy | D5 | M / średnie | ocena właściciela |
| F02 | P3 | mapa ujawnia stwory | wg D6 | zwiedzanie | D6 | S–M / niskie | zrzut, test |
| F03 | P3 | jedna lokacja | druga krótka droga z istniejących elementów | test produkcji treści | E01, L06 | L / średnie | `P.problems` czyste, przejście, zapis |

Scenariusz próby L01: świeży slot, pierwsze ognisko, obie bronie, unik po strzale, kontra i egzekucja, cios z boku, odpoczynek po efekcie Buera, śmierć, odzyskanie echa, walka z Margrave'em do wyczerpania amunicji. Zapisać każdy zgon i powód.
