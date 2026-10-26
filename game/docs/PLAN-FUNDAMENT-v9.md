# SIGIL: BREACH — domknięcie fundamentu v9

Przyjęty przez użytkownika 2026-10-24. Wdrażanie rozpoczęte.
Stan odniesienia: `216b56a`; wersja wejściowa 0.31. Ten plan wykonawczy
zastępuje podział „teraz / przy potrzebie” z PLAN-ROZWOJU-v8.md (dziś sekcja
docs/history/PLANY.txt). Kontrakty
trafień planu v7 pozostają wymaganiami. Wyniki wcześniejszych przeglądów
są historią; nie są automatycznie wynikiem niniejszego odbioru.

## Cel i zakres

Nową treść na istniejących zachowaniach dodaje się definicją i zasobami.
Nowy rodzaj zachowania ma mały, jawny moduł i test. Nie wymaga wyjątków
rozsianych w postaci, rendererze, obrażeniach, zapisie i GUI.

Produkcja zachowuje jeden poligon, dwie fizyczne bronie, obecne demony,
menu i HUD. Rycerz jest człowiekiem bez magii. Nie przywracamy LIMBO TRIAL.
Dodatkowe definicje, tryby, geometria i układy służą próbom rozszerzenia
w testach; nie powstaje nowy krąg ani kampania. Gra lokalna dla jednego
gracza jest docelowym modelem tej bazy.

Styl: żywy, mroczny fresk (Giovanni da Modena, Michał Anioł, Bosch,
Memling). Matowy pigment i zaakceptowane modele demonów pozostają punktem
odniesienia. Ulepszenie animacji nie upoważnia do wymiany modelu/palety.
Dotychczasowy układ HUD/menu nie zmienia się w ramach refaktoru.

## Zasady wykonania

- Każdy etap ma dowód odbioru, nie tylko listę zmienionych plików.
- Definicja, stan instancji i prezentacja mają osobnych właścicieli.
- Symulacja nie importuje prezentacji; efekty nie naliczają obrażeń.
- Ruch, podatna powierzchnia i geometria ataku są odrębne, lecz korzystają
  ze wspólnej pozy. Część ciała, strefa obrażeń i materiał to osobne ID.
- Refaktor zachowuje wyniki bazowe. Celowa zmiana reguły wymaga reprodukcji
  i wyjaśnienia różnicy przed aktualizacją wzorca.
- Narzędzia i raporty wiążą dowody z kodem i zasobami, nie tylko numerem 0.31.
- Nie osłabiamy testów, by poprawić wynik. Przy zmianie kontraktu testuje się
  nowy kontrakt i jego negatywne przypadki.
- Etapy wdrażane są w skończonych, weryfikowalnych częściach. Zadanie trwa
  do ich odbioru; B2 wymaga osobno rzeczywistej oceny użytkownika.

## Etapy i warunki odbioru

### F01 — stan odniesienia

Zabezpieczyć kod, narzędzia, sumy zasobów i wyniki istniejących scenariuszy.
Zarejestrować otwarte usterki: benchmark po portalach, granice nagrywania,
pełny chwyt/animacje broni i ludzki odbiór feelingu.

Odbiór: archiwum źródeł i manifest SHA-256; świeży selftest, input i render;
wadliwy benchmark opisany jako znana usterka, nie PASS.
Dowody: `work/foundation-v9`, `work/qa-foundation-v9-baseline`.

### F02 — wiarygodne narzędzia i pomiary

Naprawić lifecycle portali przez oczekiwanie na stan z ograniczonym czasem.
Rozdzielić przygotowaną walkę od prawdziwego wejścia/przywołania. Sprawdzić
każdą udokumentowaną ścieżkę QA; wdrożyć szybki przebieg narzędzi oraz pełny
profil pomiarowy. Mierzyć wejście gracza i widoczne obserwacje, nie tylko
sztuczne `Game:update({shoot=true})`. Zmierzyć koszt opcjonalnego record,
eksportu i replay, populacje 4/20/48/96, pamięć, alokacje oraz powroty sesji.

Odbiór: świeże raporty z identyfikacją źródeł; rzeczywiste scenariusze,
warunki błędu i limit wykonania; rozdzielone CPU/submission/readback.
64 MiB to szacunek tekstu, nie RAM ani gwarantowane 40 minut nagrania.

### F03 — własność danych i odpowiedzialności

Audyt wszystkich warstw: niezmienne definicje, stan instancji, stan widoku;
jedno miejsce reguł; jawne zależności i właściciele pól. Usunąć rzeczywiste
duplikaty i cykle; podzielić moduły według ról, nie liczby linii. Walidować
ID, referencje, jednostki, zakresy i relacje przed walką. Rejestracja
nieudana nie pozostawia części wpisu.

Odbiór: checker bez nowych wyjątków; testy niezmienności definicji i
resetu; mapa odpowiedzialności w aktualnej dokumentacji.

Wdrożono: walidację list bez cichego obcinania, rejestr warunków,
walidację kompletnej kompozycji treści przed konstrukcją sesji i adapter
modyfikatorów wyposażenia. Jawna pusta lista wariantu usuwa odziedziczone
elementy; kopiowanie instancji mapy używa osobnego Schema.copy.
`foundation-contracts`: 18 PASS; niezmienność
definicji i deklaracje pól ponownie potwierdza golden. Końcowy checker
oraz aktualizacja ogólnej mapy odpowiedzialności należą do odbioru całości.

### F04 — wspólna droga walki

Utrwalić drogę zamiar -> wykonanie/dostawa -> kontakt -> ochrona/obrażenia
-> impuls/status -> zdarzenia prezentacji. Sprawdzić odległość, materiały,
strefy, wielokrotne kontakty, przerwanie/anulowanie, śmierć właściciela,
zmianę broni i częściowy reload. Przygotować rozszerzanie efektów okresowych
oraz zachowań dostawy bez dopisywania nazw broni w postaci.

Odbiór: rozszerzenie przechodzi zasoby/kontakt/zdarzenia/save/replay; brak
podwójnego skutku; jeden wspólny resolver prawdy. Nowa reguła ma nazwę,
jednostki i dowód, nie arbitralny wyjątek dobrany pod test.

Wdrożono opcjonalne skutki kontaktu przez schematy i rejestr wykonawców.
Instancja efektu posiada zegar i identyfikację źródła na celu; impuls
pocisku i okresowa ekspozycja mają osobne znaczenie. Próba rzeczywistej
dostawy finite/hitscan, wielośrutu, odświeżania, anulowania, śmierci,
zmiany broni i serializacji/replay: `contact-effects` 15 PASS. Produkcyjne
bronie i demony nie dostały nowych efektów ani zmian balansu.

### F05 — kontrakt grafiki i animacji

Katalogi opisują źródła, dowolne jawne klatki, fazy, kotwice, chwyt,
wylot lufy, warianty, filtr i pigment. Usunąć sztywne dwie nazwy broni,
1600x1600/16 klatek i powder-only w ogólnym ładowaniu. Zachować fasady
tam, gdzie ułatwiają bezpieczną migrację istniejących odbiorców.
Animacja czyta rzeczywistą fazę; nie posiada drugiego zegara obrażeń.
Osobne rejestry/wykonawcy dla pozy, oprawy i podglądu geometrii; diagnostyka
odczytuje prawdziwy kontakt. Narzędzia przeglądu atlasów/kotwic/anatomii/faz.

Odbiór: trzeci testowy układ atlasu i dłoni działa bez edycji ogólnego
renderera; zgodność faz/zużycia amunicji/przerwania/efektu wylotu. Obecne
grafiki i klatki przed korektami artystycznymi pozostają identyczne.

### F06 — tryby, sesje, nawigacja i zapis

Rejestr konstruktorów sesji wspólny dla aplikacji i replay. Nawigacja
posiada powroty, anulowanie i reset zamiarów. Moduły ogólne korzystają
z jawnych danych trybu, nie z obecności `g.run`. Własny ekran trybu może
znać jego stan. Zapis zawiera stabilne ID i dane; walidacja/migracje
obejmują brakujące definicje i nieznane formaty.

Odbiór: tryb testowy tworzy się, wraca, zapisuje i odtwarza bez zmiany
Journal/Game/ogólnego renderera; stary zapis i menu pozostają zgodne.

Wdrożono deskryptor `Modes.session`, wspólną fabrykę Game/Journal,
stos `app/navigation` i `run/queries` dla widoku świata/narzędzi/celu.
Własne dane trybu nie narzucają struktury `g.run`. Zachowano alias
`descent` oraz stare nagłówki dzienników. Etykieta powrotu należy do
`g.view`. `mode-lifecycle`: 25 PASS; najnowszy stabilny `replay`: 30 PASS.

### F07 — przestrzeń i wysokości

Mapa posiada geometrię, dekoracje, światła i nazwane miejsca. Tryb wybiera
zdarzenia/nagrody/obsadę tych miejsc. Renderer nie zna współrzędnych Limbo.
Wspólne dane opisują obiekt widoczny i kolizyjny tam, gdzie są tym samym.
Osobno obsłużyć przesunięcie całej podłogi oraz powierzchnie podparcia
o różnych wysokościach. Ruch, lądowanie, pociski, widoczność i nawigacja
muszą zachować ten sam kontrakt przestrzeni.

Odbiór: testowa geometria ze stopniem/podestem i zmiennym położeniem
dekoracji; brak ręcznego poprawiania współrzędnych w rendererze/walce;
obecny poligon pozostaje zgodny poza jawnymi poprawkami błędów.

Odbiór techniczny focused: `world-support` 29 PASS i `terrain-motion`
26 PASS. Niezależny przegląd wykrył i zamknął podwójne rebazowanie
wysokości przy kontakcie ciał, boczne teleportowanie na krawędzi, utratę
reszty czasu lotu i opóźnione rozpoczęcie spadku zwłok. Próbę pionowego
lądowania, podziału czasu, gwałtownego nawrotu przy półce, interpolacji
pozy i reakcji na lądowanie wykonuje rzeczywista ścieżka mechaniki.

Jawne ograniczenie: heightfield ma jedną powierzchnię podparcia na
komórkę, bez nakładających się platform. Podparcie liczone jest pod
punktem stóp; promień stanowi osobny obrys poziomego ruchu. To nie jest
anatomiczna powierzchnia trafień ani ogólny silnik brył 3D. Przejściowe
zachodzenie tylnej części obrysu na bok opuszczanej półki pozwala wyjść
lub przesuwać się stycznie, blokując ruch głębiej bez dodawania energii.
Obejrzano obraz `work/qa-v9-terrain/world-support.png`: podest, stopnie
i stopy demona zgadzają się w scenie. Produkcyjny poligon pozostał ten sam.

### F08 — zasoby i pamięć

Manifest zależności mapy, demonów, broni, FX, audio i UI; jawny właściciel
i okres życia GPU/audio. Współdzielenie, etapowe ładowanie, anulowanie,
błędy brakującego zasobu i bezpieczny powrót. CPU geometria/maski nie
znikają z powodu zwolnienia obrazu. Ocena formatów/kompresji teraz,
wdrożenie formatu wyłącznie na podstawie jakości i zmierzonej korzyści.

Odbiór: wielokrotne przejścia osiągają plateau pamięci; brak duplikatów
ładowania i odwołań do zwolnionych zasobów; pigment i kontakty zachowane.

### F09 — poligon jako narzędzie

Katalog, stanowiska, reset, akcje i przywoływanie mają osobne role oraz
rejestry. Wpisy pochodzą z definicji treści. Jasne stany pending/active/dead
i odwołanie oczekujących zdarzeń. Pełne cykle ataku, przerwania, trafienia,
przełamania, śmierci i resetu służą autorowi zawartości.

Odbiór: nowe testowe stanowisko/treść nie wymaga wielkiego łańcucha if;
reset czyści również portale i pozostałości poprzedniej próby.

Wdrożono `run/field/catalog`, `stations` i `actions`; nowa testowa treść
i narzędzie rejestrują się bez dopisywania do łańcucha nazw. Katalog
odczytuje definicje przy zapytaniu. Walidacja i reset pending/active są
częścią `mode-lifecycle` (25 PASS), a rzeczywisty portal zachowuje 1,2 s.

### F10 — UI i teksty przygotowane do rozbudowy

Dotychczasowy układ i wygląd zostają. Opisy wyposażenia/ulepszeń jako dane;
teksty z parametrami, katalog kluczy, bitmapowe glify, polskie znaki,
ograniczony cache. Testy większej liczby elementów i dłuższych tekstów.
Rzeczywisty tusz ma mieścić się we wnętrzu planszy, nie na ornamencie.

Odbiór: obecne ekranowe referencje zachowane; rozszerzenia testowe są
czytelne w 960x540, 720p, 4:3, szerokim ekranie i 1080p. Odbiór wizualny
obok automatycznych granic. Nowy układ produkcyjny wymaga odbioru użytkownika.

### F11 — paczki i praktyczna próba rozwoju

Osobne paczki gracza i dewelopera z identyfikacją źródeł, licencjami,
sprawdzeniem EXE i sum. Instrukcja dodawania zawartości przetestowana przez:
wariant demona, odmienny atlas broni, wyposażenie z własną oprawą, atak,
przestrzeń, tryb, zapis i replay. Spisać faktycznie zmienione moduły.

Odbiór: paczka działa poza repo; kompletne ścieżki rozszerzenia i brak
masowego przepisywania niepowiązanych systemów. Duża powierzchnia zmiany
w próbie jest powodem powrotu do kontraktu, a nie ukrycia wyniku.

### F12 — obecna oprawa i feeling

Dokończyć spójne pełne cykle dwóch broni (chwyt, strzał, powrót, reload,
przerwanie, swap), a nie podmienić pojedyncze idle. Zaakceptowana nowa poza
strzelby i lokalny retusz palca to materiał warsztatowy. Demony zachowują
modele/pigment; poprawki dotyczą animacji i czytelności istniejących akcji.
Ocenić w scenie także nakładanie FX, światło, materiały i śmierć przeciwnika.

Odbiór: techniczne filmstripy/geometry/input + rzeczywisty B2 użytkownika
(ruch, strzał, czytelność zamachu, kontakt, chęć ponowienia walki). Nie
oznaczać ludzkiego odbioru jako wykonanego na podstawie testów/botów.

## Zamknięcie

Wszystkie F01-F12 mają dowody. Brak znanych usterek blokujących obecną
walkę lub zaplanowane sposoby rozszerzenia. Dokumentacja opisuje wynik,
nie zamiar. Raport osobno wymienia wyniki techniczne i ocenę użytkownika.
Nie ma gwarancji samych zmian danych dla dowolnego nowego algorytmu;
wymaganiem jest lokalny wykonawca i stabilne kontrakty pozostałych warstw.

## Rejestr postępu

| Etap | Status | Dowód / pozostałe |
|---|---|---|
| F01 | Odebrany | reference-216b56a.zip + assets-reference.json; baseline 3435 PASS, input PASS, 147 scen oraz przeglądy szczegółowe PASS. |
| F02 | Wdrożone; końcowa bramka | Rzeczywiste smoke CLI, bounded lifecycle portali i identyfikacja buildów. Pełne 20/48/96 oraz końcowe źródła: work/foundation-v9/final-report.txt. |
| F03 | Wdrożone; odbiór focused | foundation-contracts 18 PASS, golden niezmienność definicji/pól PASS; końcowy checker i ogólna dokumentacja przed nami. |
| F04 | Wdrożone; odbiór focused | contact-effects 15 PASS: rzeczywista dostawa, skutki, anulowanie, śmierć, zmiana broni, save/replay. Balans produkcji zachowany. |
| F05 | Wdrożone; odbiór focused | Test odrębnego atlasu 5 klatek i gestu: 27 PASS; osobne zegary/debug, rejestry i regresje. Klatki amunicji są odczytem stanu, bez drugiego zegara transakcji. |
| F06 | Wdrożone; odbiór focused | mode-lifecycle 25, replay 30 PASS; deskryptory, stos nawigacji, modeData, neutralne zapytania widoku i legacy descent. |
| F07 | Wdrożone; odbiór focused | world-support 29 + terrain-motion 26 PASS; render podestu obejrzany, niezależne reprodukcje naprawione, geometry 356 i golden 10 PASS. |
| F08 | Wdrożone; końcowa bramka | Własność/refcount, poprawione lifecycle geometrii/fontów/Journal, etapowy LoadPlan/startup/retry/cancel. Wybór PNG uzasadniony pomiarem; final startup/plateau w raporcie końcowym. |
| F09 | Wdrożone; odbiór focused | Rejestry katalogu/stanowisk/akcji, nowa treść i narzędzie, walidacja i reset portali w mode-lifecycle 25 PASS. |
| F10 | Wdrożone; odbiór focused | Katalog tekstów, parametry, paginacja rozszerzeń. 58 prób wraz z odstępem tuszu; obejrzane 4:3 i 960x540. Pełny showcase po integracji. |
| F11 | Wdrożone; końcowa bramka | Paczki Player/Developer, źródłowy manifest i relokacja; narzędzia odrzucają nieaktualny raport. Ostateczne paczki i SHA powstają po All. |
| F12 | Wdrożenie i odbiór cykli | Pełne dwa arkusze, jawny retusz dłoni/komór, warianty rzeczywistej amunicji, kotwice. Modele demonów zachowane. B2 nadal wymaga użytkownika. |

Powyższe PASS focused są dowodami roboczymi z drzewa zmienianego równolegle.
Nie zastępują końcowego przebiegu na nieruchomym kodzie. Raporty końcowe
będą miały SHA-256 całego drzewa gry oraz uruchomionego EXE; zmiana źródeł
w trakcie przebiegu unieważnia jego certyfikację.

Uzupełnienie: przebieg `work/qa-v9-terrain` dla world-support, architecture,
geometry, replay i golden wykonano już na nieruchomym kodzie (każdy
`sourceStable=true`, SHA-256
`D72DA74F8C669091BB7D599AFB809948B65363093D1C23A17F1DB2877F604A65`).
Terrain-motion 26 PASS ma osobny stabilny fingerprint sprzed wyłącznie
korekty cleanup fixture world-support. Wszystkie sześć hashy wzorca golden
pozostało zgodnych. Ten odbiór focused nie zastępuje pełnej bramki oraz
testów spakowanego wydania po zakończeniu pozostałych zmian.

Po końcowym przeglądzie F03 zamknięto również błąd pustej listy w
dziedziczeniu. Powtórka foundation-contracts 18, contact-effects 15 oraz
golden 10 PASS jest stabilna dla SHA-256
`8EE8390FDEE888769638704475FE43E7171C5871B679ED49B6A6651A74428873`.
Checker: 432 pliki Lua skompilowane, 0 naruszeń architektury. Aktualizacja
wzorca golden nie była potrzebna.
