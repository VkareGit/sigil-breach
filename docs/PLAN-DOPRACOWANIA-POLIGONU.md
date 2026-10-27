# Dopracowanie poligonu i walki

Uzgodnienie z 27 października 2026. Bazą jest commit `386b82a` oraz obecna
arena, demony, dwie bronie i zatwierdzony interfejs. Celem jest rozwijanie
spójnych mechanizmów gry przez definicje i lokalnych wykonawców. Nowy rodzaj
zachowania może wymagać nowego modułu; nie powinien wymagać przepisywania
każdej postaci, broni, ekranu i trybu.

Każdy punkt kończy się weryfikacją, osobnym commitem i przerwą na test
użytkownika. Nie rozpoczynamy kolejnego punktu przed tą przerwą.

| Punkt | Zakres | Stan |
|---|---|---|
| 1 | Kontakt pocisków i melee, pełny reset próby, diagnostyka przyczyn obrażeń i profilowanie regresji | Commit bd9eff9; użytkownik zezwolił kontynuować; regresja wydajności otwarta |
| 2 | Dostępny wyłącznie poligon; wyłączenie wejść do Limbo, fal i handlu, zachowanie ich kodu i testów | Commit e625210; użytkownik zezwolił kontynuować |
| 3 | Jawna geometria i pionowy zasięg pocisków, ciosów, wybuchów oraz zagrożeń podłogowych | Commit c288bfb; użytkownik zezwolił kontynuować |
| 4 | Strategie wyboru ataku i trudności, fazy istniejącego bossa, nagroda i finalna śmierć dokładnie raz | Commit 1b97658; użytkownik zezwolił kontynuować |
| 5 | Pokoje i stanowiska na bazie obecnej areny, opisane danymi; początkowo jedna aktywna próba | Commit f3ff4f2, razem z korektą atmosfery, ołtarzy i ognia |
| 6 | Dźwięki ruchu, zapowiedzi, kontaktów i lotu, priorytety głosów, przestrzeń, ambient i miks muzyki | Oczekuje |
| 7 | Osobny rozwój nowych grafik i modeli | Odłożony przez użytkownika |
| 8 | Pełny sprawdzian rozszerzenia: boss, komnata, reset, replay, wydajność i odbiór w dłuższej grze | Oczekuje |

## Zakres punktu 1

Pociski już uwzględniały wysokość, skok i crouch. Usterka polegała na
traktowaniu niezależnie powiększonego promienia i wysokości cylindra jako
ostatecznego kontaktu. Tak powstawały fałszywe trafienia na jego obrzeżu.

`physics/cylinder_cast.lua` jest wspólną czystą matematyką kontaktu sfery
z pionowym cylindrem. Obsługuje względny ruch i niezależną zmianę dolnej
oraz górnej płaszczyzny. Szybki test przedziałów odrzuca odległe przypadki;
potencjalne trafienia obrzeża sprawdza rzeczywista odległość od cylindra.
Solver nie zna nazw postaci, broni, animacji ani trybu poligonu.

Adaptery pocisków i melee dostarczają podłoże, skok, crouch i ruch z jednego
kroku. Opcjonalne bryły demonów korzystają z tego samego rozwiązania dla
pocisków o niezerowym promieniu; malowane maski pozostają bez zmian.
Tolerancja numeryczna wynosi 1e-8 jednostki świata. Model zakłada stały
promień cylindra i liniowe przemieszczenia/granice w rozpatrywanym kroku.

Diagnostyka `PlayerHit/KnightHit.info.contact` opisuje rozstrzygnięty kontakt,
nie wykonuje drugiego testu i nie steruje obrażeniami. Rozróżnia sferę,
melee, zagrożenie podłogowe/pionowe, wybuch i efekt okresowy. Ma identyfikatory
i skopiowane wartości; nie zachowuje referencji do ciał. Nie dodaje paneli
ani napisów do zatwierdzonego HUD-u.

Pełny reset poligonu ma oddzielny zakres od uzupełnienia zasobów i granicy
fali. Czyści pozostałości obrażeń i ruchu kontrolowanego rycerza, hit-stop,
kolejkę prezentacji i stare reakcje wizualne. Zachowuje tożsamość sesji,
wyposażenie, rozszerzenia trwałe i monotoniczne generacje obserwacji.

Pomiary wydajności otrzymują wspólny indeks klatki dla update, świata,
UI, interpolacji, obserwacji i odczytu GPU. Eksport jest opcjonalny i nie
zmienia zwykłego profilu pomiarowego. Wynik analizy i jej ograniczenia:
[PUNKT-1-WYDAJNOSC.md](PUNKT-1-WYDAJNOSC.md).

### Weryfikacja punktu 1

`TEST.ps1 -Suite All -TestTimeoutSeconds 600` zakończył się powodzeniem:
4447 sprawdzeń mechaniki/zasobów, 36 sprawdzeń wejścia, 532 skompilowane
pliki Lua i zero naruszeń architektury. Przeszły renderowanie, pełny test
uruchomienia oraz smoke narzędzi benchmark/core-measure/step-study/audio-export.
Wszystkie osiem przebiegów korzystało ze stabilnych źródeł. Złote wzorce
symulacji i kontaktów przeszły bez zmiany oczekiwanych wyników.

Nowe sprawdzenia obejmują rzeczywisty lot nad ślizgającym się rycerzem,
kontakt obrzeża i styczność, ruch względny, podział czasu na podkroki,
kontakt melee oraz opcjonalne bryły demonów. Reset ma test negatywny dla
samego uzupełnienia zasobów i granicy fali, a zapis/odtworzenie pełnego
resetu odtwarza ten sam stan. Pokwitowania kontaktu nie zmieniają stanu
kontrolowanego przez test integralności i nie przechowują referencji do ciał.

Porównanie 606 PNG ze wzorcem E0: 588 identycznych; 10 wcześniejszych
różnic pozostaje dokładnie w tych samych obszarach i z tą samą liczbą
pikseli (wersja menu oraz poprawiony wskaźnik choke). Pozostałe 8 wynika
z usunięcia pozostawionych przez dawny reset liczb obrażeń i chwilowych
reakcji obrazu po poprzednim starciu. Obejrzano reprezentatywne pary Furfur,
chybiony rewolwer i rzut ładunku; zasoby, renderer i HUD nie są zmienione.
Lokalne dowody: `work/point1-final/`, w tym `pixels.csv`.

Profilowanie nie jest naprawą regresji. Formalny wynik +13,2% względem E0
wymaga dalszej pracy opisanej w osobnym raporcie. Smoke benchmarku nie
stanowi zaliczenia kryterium wydajności.

Przerwa po commicie: użytkownik sprawdza loty pocisków przy ślizgu/skoku
oraz pełny `F2 → RESET FIELD` po otrzymaniu obrażeń. Nie każdy pocisk nad
kamerą mija całe ciało; rozmiary i wysokości ataków będą strojone jawnie
w punkcie 3. Punkt 2 zaczynamy po tej próbie i informacji od użytkownika.

## Punkt 2 — publiczny poligon i zachowana biblioteka

`app/release.lua` opisuje dostępne tryby i opcje wejścia do poligonu.
`Navigation` przekazuje je do konstruktora sesji przed `adopt` i nagrywaniem.
`init(g, options)` kopiuje politykę do rekordu trybu. Nie ma globalnego
przełącznika zmieniającego zachowanie wszystkich istniejących sesji.

W publicznym poligonie `trade=false` i `waves=false` obowiązują zarówno
wyświetlane narzędzia, jak i ich wykonanie: katalog, interakcję przy Żarze,
zakup oraz właścicieli prób. Reset zachowuje ograniczenia. Nazwy funkcji
narzędzi są walidowane; literówka w wymaganiu lub konfiguracji kończy się
błędem podczas rejestracji/konstrukcji. Strzelnica, fizyka, poziom TIER,
przywołania, szybka potyczka i zasoby pozostają dostępne.

Kod klasycznej areny, wyprawy, sklepu i fal pozostaje w bibliotece razem
z testami. Bezpośrednie `Game.new('field')` bez opcji zachowuje historyczne
narzędzia QA. Publiczne polecenia aplikacji nie wznawiają niedostępnych
trybów. Sesja za menu jest tłem; wejście tworzy odrębny poligon.

Tryb eksportuje opcje przez `construction(g)` do nagłówka Journal.
Odtworzenie korzysta z zapisanej polityki, a nie z aktualnej konfiguracji
menu. Starsze nagłówki bez opcji zachowują dawną semantykę.

Zmiany prezentacji ograniczają się do usunięcia niedostępnych przycisków
i poprawienia opisów menu/pomocy. Zatwierdzony pasek HUD, grafiki, arena,
modele, parametry walki oraz pliki zapisanych wypraw nie są przebudowywane.
Przegląd zrzutów wykazał też błędne „7 celów” na pustym poligonie: nagłówek
korzystał z licznika wyprawy i nieaktywnej kolejki fali. Teraz pyta tryb
przez `Queries.remaining`; pusty poligon pokazuje zero, a martwe ciała
nie są żywymi celami. To korekta danych w istniejącym nagłówku.

### Weryfikacja punktu 2

`FORMAT.ps1` i `TEST.ps1 -Suite All -TestTimeoutSeconds 600` przeszły:
4470 sprawdzeń mechaniki/zasobów, 36 sprawdzeń prawdziwych wejść aplikacji,
534 skompilowane pliki Lua i zero naruszeń architektury. Nowa suita
`field-access` ma 22 sprawdzenia: blokady narzędzi i ich właścicieli,
reset, walidacja, niezależność opcji, snapshot, zapis/odtworzenie dziennika,
zgodność historycznych sesji oraz licznik rzeczywistych celów.
Złote wzorce przeszły bez aktualizacji oczekiwań. Osiem przebiegów All
zakończyło się kodem zero przy jednym stabilnym skrócie źródeł:
`8BC87761C858B5AEA66CCA8D9B4ECAEEE29F32BC37925DC64097A057310BC84D`.

Renderer sprawdził 5466 granic tekstu/obrazów/wskaźników. Dodano 15 zrzutów
publicznego katalogu, pomocy i HUD-u w pięciu rozmiarach; obejrzano także
menu. Przegląd potwierdził usunięcie sklepu/fal, poprawną liczbę celów
oraz zachowanie obecnych ramek, liter, grafiki i dolnego paska.

Porównanie z 606 obrazami E0: 245 identycznych. Różnice obejmują nowe opisy
menu, poprawiony licznik celów (również w złożonych arkuszach klatek) oraz
wcześniejsze zmiany opisane w punkcie 1. Nie zmieniono plików graficznych.
Lokalne dowody i porównanie obszarów: `work/point2-final/`.
Testy benchmarku w All były smoke; nie zamykają regresji wydajności punktu 1.

Próba użytkownika: wejść na poligon, otworzyć F2, przywołać przeciwnika,
użyć RESET FIELD i sprawdzić powrót licznika do zera. Sklep i WAVE TRIAL
nie są dostępne, E przy Żarze nie otwiera handlu, Enter nie uruchamia fal.
Po commicie punktu 2 zatrzymujemy wdrożenie przed punktem 3.

Uwaga do punktu 3 po teście użytkownika: pociski nadal potrafią trafić
podczas ślizgu. Należy zmierzyć wysokość i promień konkretnych ataków oraz
zgodność ich obrazu z kontaktem. Sam fakt, że środek pocisku jest ponad
kamerą, nie dowodzi minięcia całego ciała; nie zmieniać hitboxów na ślepo.

## Punkt 3 — pionowy zasięg i chwila kontaktu

Zachowana bryła rycerza: promień 0,22 m, przedział od 0,08 do 1,80 m
nad podłożem i skokiem. Pełny ślizg obniża górną granicę o 0,43 m do
1,37 m. Pocisk celujący na około 1,15 m przecina ją prawidłowo. Nie dodano
ukrytej odporności, nie obniżono ciała dla łatwiejszego unikania strzałów.

| Dostawa | Obecny kontrakt |
|---|---|
| Pocisk | Sfera swept przeciw ciału/światu; wspólny promień obrazu i kontaktu; definiowane height/aimHeight/radius |
| Pazur i szarża | Sfera kontaktu, aktywne okno i kotwice obecnych animacji; continuous cylinder cast z punktu 1 |
| Kałuża / linia | Skończony walec, domyślnie stopy w [0; 0,42) m nad własnym podłożem |
| Lądowanie | Domyślnie stopy w [0; 1) m, z promieniem ciała w zasięgu poziomym; sprawdza osłonę |
| Piorun | Skończona kolumna 0–2,9 m, przecięcie ciała i promienia, ograniczona stropem nad źródłem |
| Ładunek | Sferyczny dystans 3D do kotwicy ekspozycji ciała, falloff i promień osłony; nie nieskończony walec |

`content/defs/area.lua` waliduje `volume` i `landVolume`: `bottom`, `top`,
`sample` i `includeRadius`. `combat/area_contact.lua` wykonuje wspólne
sprawdzenie i zwraca diagnostykę przyjętego kontaktu. Zmiana wysokości
obszaru jest zmianą danych ataku; nie wymaga nowego kodu demona. Nowy
kształt, np. łuk poruszającej się ściany, nadal wymaga właściwego wykonawcy
i testu — nie udajemy go samą zmianą liczby. Testowy wariant podniesionego
pasma pokazuje to rozszerzenie; nie został dodany do publicznej rozgrywki.

Naprawione przypadki:

- Piorun nie trafia dowolnie wysoko ani przez strop. Kałuża z górnego
  poziomu nie trafia rycerza na dolnym; lądowanie nie przenika ściany.
- Puls interpoluje wysokość świata między pozycjami. Nie przenosi całego
  skoku na podłoże komórki końcowej. Opóźniony piorun próbkuje czas
  wygaśnięcia znacznika; świeżo wykonany przez AI bierze pozycję po ruchu.
- `ballistics.world` pomijał stropy w promieniach punktowych, mimo że
  fizyczne pociski je uwzględniały. Teraz blokują też hitscan i ekspozycję
  wybuchu. Światy bez stropów korzystają z dotychczasowej szybkiej ścieżki.
- Kierunek pionowy pocisku uwzględnia przesunięty wylot (d−muzzle zamiast d)
  i leapY strzelca. aimHeight jest danymi ataku, bez śledzenia celu w locie.
- Kałuża zachowuje ID sprawcy również bez efektów okresowych. Geometria
  jest deklarowanym polem komponentu; snapshot nie traci jej ani nie
  pozostawia referencji do mutowanego egzemplarza.

Ograniczenia są jawne: ekspozycja wybuchu nadal jest pojedynczą kotwicą,
obszary są walcami, a próbkowanie pulsu korzysta z interpolacji liniowej
wewnątrz kroku. To różne kontrakty od anatomicznej maski trafień demona.
Malowana aura pocisku jest dekoracją; nowy promień skaluje ją wraz z rdzeniem.
Nowa forma efektu nadal wymaga oceny grafiki i jej zapowiedzi przed publikacją.
Nie zmieniono atlasów, HUD-u, HP, obrażeń ani amunicji istniejących broni.

### Złoty wzorzec i zgodność

Świadoma korekta kąta lotu zmienia pośrednie skróty stanów: playtest
`07f73bfa` → `31e0ff45`, human `fe26df14` → `c34e3780`, drill
`c13bcaec` → `0bc736d6`. Końcowe stany i wszystkie trzy skróty kontaktów
są identyczne. W izolowanym procesie przywrócono **wyłącznie mianownik
prędkości pionowej** w pamięci: 6/6 starych wyników wróciło. Stąd aktualizacja
trzech wpisów `tests/golden/baseline.lua`, z komentarzem uzasadniającym.
Referencje 0.33 nie zostały przepisane. Dowód lokalny:
`work/point3-final/golden-attribution/legacy-aim.csv`.

### Odbiór punktu 3

`FORMAT.ps1` i `TEST.ps1 -Suite All -TestTimeoutSeconds 600`: PASS.
4509 sprawdzeń mechaniki/zasobów (39 nowych w attack-volumes), 36 testów
wejścia, 538 plików Lua, zero problemów architektury. Referencje 0.33:
58 sprawdzeń PASS bez regeneracji. Testy nowych granic obejmują 60/120/240 Hz
dla pocisków i różne rozmiary kroku przy opóźnionym piorunie, świat ze
stropem i podniesionym podłożem, własną geometrię ataku i dwóch rycerzy.

Renderowanie sprawdziło 5466 granic tekstu/obrazów/wskaźników oraz 15
publicznych ekranów poligonu w pięciu rozmiarach. Obejrzano aktualne sceny
pioruna, pocisku, HUD i katalog. Porównanie 606 obrazów z E0 nadal daje
245 identycznych; względem raportu punktu 2 jedyna zmieniona metryka różnic
dotyczy `attack-stolas-2-projectile.png` (przesunięcie pocisku po korekcie
toru). Nie zmieniono żadnego pliku assetów ani układu interfejsu.

Wszystkie osiem przebiegów All miało stabilne źródła i kod wyjścia 0;
skrót źródeł: `AD4266BCBE1E56A1ED0D0CA8C91ABE76A2C4C19F42EFE392F847C2FF86DF9B5B`.
Dowody: `work/point3-final/all/`, `pixels.csv`, `render-new-differences.csv`
i osobna próba przypisująca zmianę golden do toru pocisku. Narzędzia
wydajności w All działały jako smoke, nie jako odbiór regresji punktu 1.

Przywołać Stolas/Buer/Margrave/Furfur przez F2, wyłączyć GOD MODE.
Niski pocisk może trafić przy ślizgu; pocisk, którego cała sfera przechodzi
nad ciałem, powinien chybić. Skok nad kałużą zależy od chwili jej pulsu.
Piorun dochodzi do ziemi — ślizg nie zastępuje wyjścia poza jego obszar.
Po sprawdzeniu wykonać RESET FIELD. Nowe piętra/stropy testuje automatyczna
geometria techniczna; nie dodano mapy do rozgrywki.
Punkt 4 (strategie AI i fazy bossa) zaczynamy po przerwie na tę próbę.
Otwarta regresja wydajności z punktu 1 pozostaje do osobnego domknięcia.

## Punkt 4 — decyzje w walce i fazy istniejących bossów

### Wnioski z odniesień

Sekiro wiąże Vitality z regeneracją Posture, a silniejszy przeciwnik może
wymagać kilku Deathblow. Przejmujemy rozdział wyczerpania etapu od finalnej
śmierci; nie dodajemy obowiązkowego finiszera ani mechaniki parowania do FPS.
Źródło: [oficjalny opis mechanik Sekiro, Activision](https://support.activision.com/sekiro/articles/sekiro-shadows-die-twice-game-mechanics).

Bloodborne wymaga obserwowania zamachu, właściwego momentu uniku/parowania
i zarządzania przerwą na odzyskanie sił. W naszym modelu zapowiedź, wykonanie
i odzyskanie gotowości pozostają osobnymi zegarami. Zwiększenie tempa nie
skraca zapowiedzi ani przerwy, podczas której gracz może odpowiedzieć.
Źródło: [poradnik walki Bloodborne, PlayStation](https://blog.playstation.com/archive/2018/03/06/12-tips-for-surviving-the-first-few-brutal-hours-of-bloodborne-this-months-ps-plus-headliner).

Opis serii Souls wydawcy podkreśla adaptację do zasięgu i ataków obszarowych
oraz pojedynki wielofazowe. Tutaj odległość wybiera właściwy atak, zaś jego
geometrię nadal rozstrzygają wspólne solvery. Nie twierdzimy, że odtwarzamy
wewnętrzny algorytm FromSoftware. To nasze reguły projektowe, oparte na
obserwowalnych zasadach walki.
Źródło: [omówienie walk z bossami, Bandai Namco](https://en.bandainamcoent.eu/elden-ring/news/elden-ring-the-best-of-the-souls-series).

### Wykonanie i granice

- `enemies/attack_selection.lua` oddziela decyzję od cyklu wykonania.
  Bez `tactics` obowiązuje dawny porządek listy i jawny fallback.
  `tactics.moves` wskazuje stabilne id ataku, preferowany dystans, wagę,
  twarde granice dystansu i minimalny TIER. Wybór jest deterministyczny:
  `waga / (1 + |dystans - ideal|)`, pomnożona przez
  `repeatPenalty ^ liczba_powtórzeń` dla ostatnio rozpoczętego ataku.
  Remis rozstrzyga kolejność autora. To użyteczność decyzji, nie wzór obrażeń.
- Zasięg i odnowienie nadal są twardymi warunkami. Brak dostępnego ruchu
  oznacza dalsze przemieszczanie, nigdy cios poza zasięgiem. Decyzja nie zna
  przycisków gracza, nie zmienia celu w środku zapowiedzianego ataku i nie
  zużywa RNG. Historia zapamiętuje rozpoczęcie, także przy późniejszym
  anulowaniu; odczyty renderera nie tworzą historii.
- `content/defs/encounter.lua` waliduje odwołania, powtórzone id, puste
  listy, skończone parametry i nieosiągalne zakresy. Definicje są niezmienne.
  Nowy atak istniejącego rodzaju wymaga danych; nowy sposób dostawy wymaga
  lokalnego wykonawcy, jak wcześniej. Nie powstał drugi automat stanów.
- `phases` definiuje kolejne etapy. `at` odnosi się do bieżącego maksimum
  HP. Opcjonalne `refill` przywraca nowy zapas jako udział zdrowia ze spawnu,
  już po zastosowaniu TIER. Próg bez refill zachowuje HP i maxHp; daje np.
  zmianę zachowania przy połowie zdrowia. Etap zerowego HP musi mieć refill.
- `session/damage_outcomes.lua` rozstrzyga etap przed `BodyHit` i
  `EnemyKilled`. Przy nowym zapasie nadmiar pojedynczego trafienia przepada;
  następny kontakt może od razu zranić bossa. Nie ma ukrytej odporności.
  Kilka przekroczonych progów bez refill może zostać rozliczonych jednym
  uderzeniem, ale jedno uderzenie nie zabiera kilku odnawianych zapasów.
- Przejście anuluje przygotowywany znak i atak wykonywany ciałem. Już
  wystrzelone pociski oraz aktywne pola zostają, z właściwym właścicielem.
  Lot i pchnięcie pozostają fizyczne. Efekty okresowe, osłabienia, uszkodzenie
  gardy i odnowienia umiejętności nie są czyszczone. Efekt zależny od życia
  sprawcy kończy się dopiero przy jego finalnej śmierci.
- Powrót HP nie daje dusz, punktów, leczenia za zabójstwo, zwłok ani otwartego
  wyjścia. `EnemyPhaseChanged` obsługuje istniejący głos. Zgodnie z uwagą
  użytkownika nie tworzy kafelka ani napisu z numerem fazy; test pilnuje,
  by przejście nie nadpisywało komunikatów HUD-u.
  Wynik `damageEnemy` zwraca rzeczywistą utratę HP; puls efektu nie wylicza
  jej jako różnicy zdrowia przed i po odnowieniu.
- Zapis, snapshot i journal obejmują indeks etapu, podstawę jego zdrowia,
  ostatni atak i liczbę powtórzeń. Reset poligonu nie przenosi ich do
  kolejnego przeciwnika. Ruch w drugiej fazie mnoży prędkość, zaś `pace`
  mnoży tempo odnowień i odstęp przydziału ataku; nie obrażenia, promień,
  czas zamachu ani minimalną przerwę po ciosie.

| Boss, TIER 1 | Pierwszy zapas | Drugi zapas | Zmiana walki |
|---|---:|---:|---|
| Margrave of Ash | 1000 HP | 400 HP | Zachowany wachlarz; naprzemiennie węższa, szybsza salwa 3 pocisków z dłuższą zapowiedzią; tempo odnowień ×1,2, chód ×1,1 |
| Furfur | 1400 HP | 700 HP | Dystans i historia wybierają pazur, szarżę lub piorun; osobne odnowienia 4/3,4 s; w drugiej fazie inne wagi, tempo ×1,25, chód ×1,12 |

Przerwy wejścia do drugiej fazy: odpowiednio 1,4 i 1,5 s. Dotychczasowe
grafiki, animacje, paleta i rozmieszczenie HUD są zachowane. Nowa salwa
używa istniejącego malowanego rzutu i pocisków; tytuł furii wykorzystuje
istniejące napisy. Odbiór i końcowe wyważenie wymagają próby użytkownika.

### Kontrola zmian w testach

Stare testy ostatecznej śmierci bossa muszą odróżniać ją od wyczerpania
pierwszego zapasu. Test mikroogłuszenia wskazuje ostatni etap; test wejścia
na poligon rzeczywiście wyczerpuje oba. Test pioruna ustawia historię
poprzedniej szarży, bo parzystość licznika nie wybiera już ataku Furfur.
Przegląd renderów śmiertelnego strzału również ustawia ostatni etap bossa;
nadal wymaga faktycznego trafienia, jednej śmierci i ustania ruchu zwłok.

W pełnej próbie klasycznej walki skrypt przełącza się na niesioną strzelbę
po wyczerpaniu rewolweru. Nie dostaje dodatkowej amunicji. Dotychczasowy
model z doskonałym celowaniem, ale bez unikania pocisków, przegrywa z nową
fazą: zachowano go bez zmiany jako
porównanie i złoty wzorzec przebiegu. Oddzielna próba ukończenia wyprawy
korzysta z opcjonalnego reagowania przyciskiem uniku na widoczne, zbliżające
się pociski. To wyłącznie sterowanie QA, nie wspomaganie gracza w grze.
Nowy skrypt nie modyfikuje HP, amunicji ani kolizji. Wygrana automatu nie
potwierdza ludzkiego feelingu ani poziomu trudności.

Zamrożone referencje 0.33 pozostają bez zmian. Adapter testowy przywraca
wyłącznie poprzednie definicje dwóch starć w danej sesji, bez podmiany
matematyki ani wykonawców silnika. W tej konfiguracji wracają dokładne
trzy skróty przebiegów z punktu 3. Tabela poz porównuje każdą starą pozycję;
nowe id ataku mogą dodać osobne wiersze. Aktywna konfiguracja ma oddzielnie
zaktualizowany złoty wzorzec, obejmujący także etap walki i historię wyboru.
Nowa suita sprawdza rzeczywiste strzały przez granicę etapów i finalną śmierć
w serializowanym dzienniku, a nie tylko ręczną zmianę stanu przeciwnika.

### Weryfikacja i próba punktu 4

`TEST.ps1 -Suite All -TestTimeoutSeconds 600` zakończył się powodzeniem:
4558 sprawdzeń mechaniki/zasobów (w tym 46 nowych sprawdzeń starć), 36 wejścia,
543 skompilowane pliki Lua i zero naruszeń architektury. Wszystkie osiem
przebiegów zakończyło się kodem 0, ze stabilnymi źródłami i jednym skrótem:
`F2BD23DBC447C5933AB3C539677DC376E6EAED6F829D031F4ECCB901B7C589D8`.
Dowody: `work/point4-final/all/`.

Render sprawdził 5466 granic elementów interfejsu; audyt wnętrz i kolizji
również nie zgłosił problemów. Dodano 10 ujęć obu faz: przejścia w trzech
rozmiarach oraz faktyczne wybranie ataku, jego zapowiedź i wykonanie.
Obejrzano m.in. oba przejścia (960×540 i 1024×768), zapowiedź Margrave'a
i wykonanie Furfur. Nie ma dodatkowego kafelka fazy. Scena ma właściwą
etykietę wybranego bossa, wygasłe powiadomienie przywołania i jest po
samouczku wejściowym. Używa normalnego update, nie zamraża błysku trafienia
na późniejszych klatkach. Zachowano malowane postacie, broń i układ HUD-u.

Porównanie 606 wcześniejszych renderów z E0: nadal 245 identycznych.
Pozostałe 361 ma te same liczby i obszary różnic co raport punktu 3;
nie pojawiła się nowa metryka różnic. To porównanie z E0, nie deklaracja
identyczności pikseli z niearchiwizowanym pełnym zestawem punktu 3.
Nowe ujęcia i zestawienia: `work/point4-final/review/`, `pixels.csv`.
Próby strzałów (bezpośrednio, mousepress, bufor naciśnięcia) objęły łącznie
1176 przypadków przy różnych harmonogramach klatek: zero chybień wewnątrz
ważnej powierzchni, zmian stref ani obrażeń w tym zestawie.

Smoke narzędzi wydajności przeszedł; nie jest odbiorem regresji z punktu 1,
która nadal pozostaje otwarta. Automaty nie potwierdzają ludzkiego feelingu.

Próba użytkownika: F2, TIER 1, osobno Margrave i Furfur, GOD MODE wyłączony.
Sprawdzić odpowiedź po zapowiedzi, przerwę po ciosie, przejście po wyczerpaniu
pierwszego zapasu oraz nagrodę dopiero na końcu. Następnie RESET FIELD
i ponowne przywołanie; boss ma zacząć od pierwszego zapasu. Punkt 5
(pokoje/stanowiska) czeka na tę próbę, zgodnie z uzgodnionym trybem pracy.

## Punkt 5 — komnaty istniejącego poligonu

Publiczne wejście wybiera `proving` przez `Release.sessionMaps`; jawny mapId
jest nadrzędny. Mapa jest podziałem dotychczasowej areny, z tymi samymi
materiałami, freskami, bronią i przeciwnikami. Nie dodano świata kampanii.
`limbo` pozostaje domyślną mapą biblioteki, aby zachować dawne narzędzia,
galerię atlasów, scenariusze i referencje QA. Publiczne komnaty pomijają
plansze atlasów oraz posągi podglądu, które przesłaniały pole walki.

Po dodatkowej uwadze użytkownika układ przyjmuje formę zrujnowanej bazyliki:
wysoka centralna nawa ze strzelnicą i stanowiskiem fizyki, podłużne arkady,
nawy boczne, transept, zachodnia kaplica Margrave, wschodnia Furfur,
północno-zachodnia kaplica dla impa
i opancerzonego oraz północno-wschodnia dla Stolas/Buer. To przypisania
prób, nie ostateczna fabularna geografia. Drzwi są otwarte; kolizja,
osłona i trasy to zwykłe reguły świata, bez niewidzialnej granicy walki.

Prezbiterium ma dwa rzeczywiste stopnie 0,16/0,32 m. Otwarte pozostałości
sklepienia zachowują dotychczasowy malowany horyzont. Łuki obsługują
opcjonalne yaw w danych; wspólny konstruktor liczy geometrię i normalne
w orientacji łuku. Test sprawdza podparcie każdego końca realną ścianą
lub kolumną. Ołtarze boczne stoją poza osią walki; paleniska nie pokrywają
miejsc przywołania. Nie zmieniono tekstur ani stylu istniejących zasobów.

`map.proving` zawiera komnaty, wejścia, sloty, próby oraz medale. Schemat
sprawdza identyfikatory, strukturę i referencje; właściciel prób sprawdza
realny promień ciała przy podłodze/ścianach, odległość od wejścia i odstępy
między slotami. Nie ma gałęzi `if boss == ...` w obsłudze komnaty.
Kilka prób może wskazywać jednego demona; pierwsza jest domyślna dla F2.
Dodanie testowej odmiany tej samej próby w innym pomieszczeniu sprawdzono
wyłącznie zmianą danych. Nowy typ zachowania nadal wymaga własnego modułu,
nie rozszerzania tego właściciela o mechaniki pojedynczego przeciwnika.

E na medalu lub dotychczasowe F2/przywołanie rozpoczyna nową czystą próbę.
Pełny reset usuwa poprzednie ciała, portale, pociski i efekty. Rycerz trafia
do wejścia, a demony wychodzą z normalnych portali. Wariant 3 celów ma trzy
autorskie sloty. TIER i GOD MODE zostają wybrane przez użytkownika.
Domyślnie GOD MODE jest włączony, więc do oceny trudności trzeba go wyłączyć.

Stan trybu przechowuje id próby, żądaną liczbę, id przybyłych ciał oraz
chwile/status. Zakończenie następuje dopiero po wszystkich przybyciach
i końcowych śmierciach; odnowienie HP w drugiej fazie nie kończy próby.
Retry po śmierci ponawia tę samą próbę, RESET FIELD wraca do nawy.
Rozpoczęcie RANGE/PHYSICS zastępuje walkę, nie dokłada do niej manekinów.
Nie dodano osobnej nagrody ani ekonomii komnat.

Interfejs zachowuje dotychczasową grafikę i układ. Stan próby używa
istniejącego dolnego pola kontekstu. Start nie dodaje centralnego komunikatu,
a instrukcja podstawowego ruchu nie zasłania starcia. PHASE 2 pozostaje
usunięte. Nazwa aktywnej próby nie zmienia się od przeglądania innego
przeciwnika w katalogu.

Snapshot oraz journal obejmują próbę i oczekujące portale; test używa
prawdziwych poleceń, przybyć i strzału. To nie rozszerza SIGIL09 do pełnego
checkpointu: istniejący format mapy/ciał nie przechowuje całego stanu trybu,
a poligon nadal nie zapisuje wyprawy. Przyszły checkpoint wymaga jawnych
sekcji właścicieli, migracji i testu całego cyklu.

### Weryfikacja punktu 5

`TEST.ps1 -Suite All -TestTimeoutSeconds 600` przeszedł: 4630 sprawdzeń
mechaniki/zasobów, 36 wejścia, 547 skompilowanych plików Lua i zero naruszeń
architektury. Nowa suita `chambers` ma 72 sprawdzenia. Wszystkie osiem
przebiegów zakończyło się kodem zero i stabilnymi źródłami:
`EF7AF2A11840B9340660322E69752AAF058B1FA0120D2269887751E110E58C13`.
Lokalna dokumentacja dowodów: `work/point5-final/all/` oraz `review/`.

Showcase ma 33 dodatkowe zrzuty układu, portali, sześciu prób i zakończenia.
Obejrzano nawę, arkady boczne, prezbiterium, obie kaplice bossów oraz
pozostałe cztery starcia, także w 960×540 i 1024×768. Zbiorczy audyt
sprawdził 16639 granic malowanych elementów UI w 511 przebiegach ekranu:
zero zgłoszonych problemów. Przegląd nie zastępuje testu ludzkiego feelingu.

Porównanie 606 wcześniejszych PNG z E0: 245 identycznych. W porównaniu
z raportem punktu 4 tylko `startup-first-field.png` ma inną liczbę/obszar
różnic: pierwsze publiczne wejście rzeczywiście pokazuje nową bazylikę.
Obszar zmiany kończy się nad dolnym HUD-em (y=584). Pozostałe 360 wierszy
różnic ma te same metryki co punkt 4; to nie jest deklaracja identyczności
z niearchiwizowanym kompletem jego obrazów. Żaden PNG zasobów nie zmienił się.

Pierwszy smoke benchmarku wykrył stare założenie, że kolejne przywołania
F2 kumulują cele. Zachowano dawny scenariusz 4/20 ciał na jawnie wybranej
mapie bibliotecznej i dodano oddzielne cykle publicznych komnat 1/3.
Oba sprawdzają prawdziwe wejście aplikacji, portale, przybycia, grę i powrót
do menu. Nie usunięto asercji ani nie zmniejszono historycznego obciążenia.
Pełny startup-check oraz smoke narzędzi przeszły. Smoke nadal nie zamyka
formalnej regresji wydajności punktu 1; ta praca pozostaje otwarta.

Próba użytkownika po commicie: przejść bocznymi i północnymi drzwiami,
użyć E przy medalu, następnie F2/przywołania 1 i 3. Sprawdzić swobodę uniku,
widoczność zapowiedzi, drugie życie obu bossów, śmierć/retry oraz przejście
do RANGE/PHYSICS. Dopiero po tej próbie zaczynamy punkt 6 — audio.

### Korekta oprawy punktu 5 — ołtarze i ogień (27 października)

Na prośbę użytkownika uzupełnienie należy do tego samego commita co bazylika.
Publiczna mapa ma własne `decor.atmosphere`: niższe światło odbite, ciemniejsze
niebo i oddzielny poziom czytelności sylwetek. Nie ma filtra nakładanego na HUD
ani edycji pikseli broni, demonów i otoczenia. Mapy bez tej konfiguracji zachowują
dotychczasowe wartości oświetlenia.

Medale bossów wskazują `altar = id` zamiast powielać x/z na podłodze. Wspólny
`world/proving_pads` rozwiązuje położenie z rzeczywistego ołtarza oraz wysokości
podłoża; używają go interakcja i podpis. Punkt E sięga do krawędzi podestu.
Znaki stoją bezpośrednio nad blatami, a podpis znajduje się pod znakiem.
Wycięty tusz zapisuje głębię: nie znika za dalszym freskiem i nie prześwituje
przez bliższe obiekty. Furfur używa własnej pieczęci nr 34 z wydania Goetii
Mathersa/Crowleya (1904); oryginalny PNG i pochodzenie są w assets/art/sigils.

Opcjonalna lista `chamber.fire` określa obrzeże scenograficzne, do 96 płomieni.
Obie sale bossów mają płomienie przy ścianach, z otwartym przejściem transeptu.
To oprawa, nie nowy hazard, niewidzialna ściana ani zmiana zasad obrażeń.
`Queries.world().arenaFire` udostępnia ją tylko dla aktywnej próby; źródłem jest
id komnaty, nie nazwa demona. Drugie życie zachowuje oprawę, końcowa śmierć,
śmierć rycerza i reset ją usuwają. Render używa czterech istniejących malowanych
płomieni paleniska, z różnymi przesunięciami animacji, bez osobnej puli cząstek.

Testy obejmują kotwicę ołtarza, E, fazy, śmierć/retry/reset, odrzucenie błędnych
danych i utrzymanie dawnych prób. `--ritual-review` obejmuje teraz również nawę,
oba ołtarze, areny, drugie życie i zakończenie. Zrzuty są wykonywane aktualnym
rendererem, z kontrolą braku mutacji symulacji. Przegląd wizualny wykrył i usunął
zasłanianie znaku przez dalszy fresk; samo sprawdzenie współrzędnych tego nie łapało.

Po commicie tej korekty: osobny etap drugich faz bossów, zgodnie z kolejną
uwagą użytkownika. Obecne mechaniczne przejście fazy nie jest jeszcze dowodem,
że zmiana zachowania jest dostatecznie wyrazista w normalnej grze.

Weryfikacja korekty: pełne `TEST.ps1 -Suite All -TestTimeoutSeconds 600` przeszło;
4642 sprawdzenia mechaniki/zasobów, 84 w komnatach, 36 wejścia, 549 plików Lua
bez naruszeń architektury. Wszystkie osiem przebiegów ma stabilny fingerprint
`3D404580E634D50DBF4FF37DB906E1505633BDA26C0A70761787AAC090FBEB4C`.
Audyt UI: 17093 granice w 524 ekranach, zero problemów. Cztery bezpośrednie
porównania PNG z poprzednią wersją punktu 5 (nawa, żebra, obie walki) mają
zero zmienionych pikseli dolnego HUD-u. Obejrzano dodatkowo ołtarze, zapowiedzi
ataków w 960×540 i 1024×768 oraz rzeczywiste zakończenie próby bez płomieni.
Raporty i obrazy: `work/point5-refinement/all`, `review`, `hud-comparison.txt`.
Showcase zawiera 35 ujęć komnat; jego historyczna etykieta nadal podaje 33.
Smoke narzędzi nadal nie zamyka formalnej regresji wydajności punktu 1.

## Korekta drugich faz — osobno po commicie punktu 5

Zgodnie z kolejnością wskazaną przez użytkownika najpierw zamknięto oprawę
kaplic, ołtarze i ogień w `f3ff4f2`. Dopiero potem rozwinięto drugie fazy.
Nie wymieniono żadnego PNG, modelu ani elementu HUD-u. Numery faz nadal
nie pojawiają się w osobnych kafelkach. Gesty korzystają z zatwierdzonych
klatek i ich istniejących masek trafień.

| Boss | Pierwszy / drugi zapas HP (TIER 1) | Odrębność drugiego życia |
|---|---|---|
| Margrave of Ash | 1000 / 650 | Trzy pola ognia wzdłuż zamrożonej osi celowania; początek 0,65 / 0,95 / 1,25 s po release; zejście w bok lub skok nad ogniem |
| Furfur | 1400 / 980 | Sekwencja pięciu wyładowań: środek, boki, druga oś; 0,75 / 1,15 / 1,55 s; ukośne przejścia i powrót do opróżnionego środka |

Pierwsze życie zachowuje swoje zestawy ataków. Drugie łączy nowy wzór
z dotychczasowymi atakami przez contextual tactics i historię wyborów.
Nie zmniejszono windup ani czasu recovery. Przejście nadal jest okazją
do trafienia, bez ukrytej odporności. Zwiększony drugi zapas daje nowym
sekwencjom więcej czasu, ale nie przesądza końcowego balansu.

`Action.pattern` to nowy typ dostawy, nie osobny FSM. Definicja zawiera
1..12 punktów w lokalnych współrzędnych, opóźnienia, promień, rodzaj
zagrożenia, packet i volume. `enemies/ground_pattern` wypuszcza je przez
dotychczasowy system hazards. Pola nie podążają za graczem i nie powstają
za osłoną. Na brzegu komnaty część wzoru może się prawidłowo nie zmieścić.
Objętości i kontakt z podłożem pozostają wspólne z wcześniejszymi atakami.

`transitionPose`, `windup.<id>` i `strike.<id>` wybierają nazwane sekwencje
z atlasu. `phaseEnteredAt` należy do komponentu brain i zapisu sesji.
Wspólny sampler nadal wyznacza obraz oraz geometrię trafienia, a zapis
obserwacji strzału przechowuje faktycznie pokazaną pozę. Walidacja wykrywa
błędne odwołania do póz/ataków przed rozpoczęciem gry.

Sprawdzono osobno: wysokość ognia przy staniu, ślizgu i skoku, brak obrażeń
przed zapowiedzią, jednorazowy kontakt pioruna, stałe położenie po uniku,
ścianę na drodze wzoru, zapisywanie aktywnych zagrożeń i deterministyczne
odtworzenie nowego ataku wybranego przez rzeczywiste AI.
Przegląd `--ritual-review` pokazał oba przejścia oraz kolejne uderzenia
w publicznych kaplicach (3 znaczniki ognia, 5 wyładowań), finalną śmierć
i wygaszenie obwodu areny. Aparat przeglądu cofa się po rzuceniu zaklęcia,
aby pokazać również miejsca ukrywane przez broń podczas stania na celu.

Wzorzec walki zmieniono świadomie po sprawdzeniu przyczyny: przywrócenie
wyłącznie poprzednich definicji creature i sheet w pamięci bieżącego silnika
odtworzyło **6/6** poprzednich skrótów, także stref trafień. Dowód:
`work/phase2-refinement/golden-attribution/content-attribution.csv`.
Zamrożone referencje 0.33 nie zostały przepisane; ich adapter nadal podaje
trzy historyczne ataki Furfura. Bieżące wzory mają własne regresje i replay.

Pełne `TEST.ps1 -Suite All -TestTimeoutSeconds 600` zakończyło się poprawnie:
4672 sprawdzenia mechaniki/zasobów (w tym 76 encounter, 84 chambers i 61
referencji 0.33), 36 sterowania, 550 skompilowanych plików Lua, zero
naruszeń architektury. Wszystkie osiem przebiegów ma stabilne źródła:
`F6E5624F2DA3530830B6E9F6CAA9A55AD17C14E2441BE9582C0DB0CE774ACFC0`.
Audyt UI: 17753 granice / 544 ekrany / zero problemów. Trzy zestawy
pomiarów faktycznie wyświetlonych trafień wykazują zero nietrafień,
zmian stref i zmian obrażeń w próbkach wewnętrznych; każdy jawnie wyłącza
trzy przypadki brzegowe. Obejrzano również przejścia w 960×540 i 1024×768.
Raporty: `work/phase2-refinement/all`, obrazy: `work/phase2-refinement/review`.
Testy nie są potwierdzeniem przyjemności ani ostatecznego poziomu trudności.

Ocena gracza po commicie: rozegrać obie drugie fazy, sprawdzić rozpoznanie
gestów, reakcję na sekwencję i długość walki. W F2 można wyłączyć GOD MODE;
domyślne testowe ustawienie pozostaje bez zmian. Audio nadal jest następnym
osobnym punktem, a formalna regresja wydajności punktu 1 pozostaje otwarta.

## Zasady następnych etapów

- Tryb poligonu nie rozstrzyga przyszłego systemu kampanii, fal ani ekonomii.
  Nie wystarczy ukryć przycisku sklepu, jeśli nadal otwiera go interakcja.
- Istniejące windup, commitment, recovery, cooldown i budżet atakujących
  pozostają bazą AI. Rozwijamy ich polityki, nie tworzymy drugiego FSM.
- Przejście fazy bossa następuje przed finalną śmiercią. Osobne reguły
  określają nadmiar obrażeń, efekty okresowe, aktywne ataki i pociski.
  `EnemyKilled` oraz nagrody należą wyłącznie do ostatecznej śmierci.
- Potrzebę ślizgu/skoku/osłony określa geometria konkretnego ataku.
  Kamera nie jest całą bryłą gracza; wysokość sylwetki wymaga osobnego
  strojenia i oceny odbioru, a nie powiększania lub kurczenia hitboxu w ukryciu.
- Audio reaguje na istniejące zdarzenia i ma osobną losowość prezentacyjną.
  Renderer nie uruchamia dźwięku przy każdym rysowaniu postaci.
- Nie dodajemy teraz nowej broni ani potworów jako osobnego etapu treści.
  Grafiki konieczne do nowych umiejętności mogą powstać w ich etapie, lecz
  zmiany wyglądu wymagają podglądu i akceptacji przed włączeniem do gry.
- Wzorzec estetyczny: obecne demony i GUI, kierunek malowanego fresku zapisany
  w `game/docs/KIERUNEK-ARTYSTYCZNY.txt`. Brak samowolnych zmian HUD-u,
  modeli, palety, ostrości lub gęstości detalu.
