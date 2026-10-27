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
| 2 | Dostępny wyłącznie poligon; wyłączenie wejść do Limbo, fal i handlu, zachowanie ich kodu i testów | Wdrożony i zweryfikowany; przerwa na test użytkownika |
| 3 | Jawna geometria i pionowy zasięg pocisków, ciosów, wybuchów oraz zagrożeń podłogowych | Wdrożony i zweryfikowany; przerwa na test użytkownika |
| 4 | Strategie wyboru ataku i trudności, fazy istniejącego bossa, nagroda i finalna śmierć dokładnie raz | Oczekuje |
| 5 | Pokoje i stanowiska na bazie obecnej areny, opisane danymi; początkowo jedna aktywna próba | Oczekuje |
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
