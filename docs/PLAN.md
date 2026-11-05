# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-05: PLAGUE GARDENER / Buer — wdrożone, brama Linux zielona; odbiór gry przez właściciela otwarty.**
Właściciel zamówił takie samo całościowe dopracowanie jak dla Stolasa i Iron
Thralla, z rozważeniem przebudowy czarów. Dodatkowo wskazał nieintuicyjne
wymioty na obrazie i zaproponował rzeczywisty atak wymiotami przed siebie.
Właściciel zaakceptował poniższy zakres poleceniem „akceptuj zaczni wdrazanie”.
Zachowujemy cztery role ataków i dotychczasowy wygląd postaci.

Poprzedni PLAN zachowano w całości w HISTORII, w rozdziale „Plan sprzed
Plague Gardenera (zastąpiony 2026-11-05)”. Analiza kodu i sondy są w rozdziale
„Analiza Plague Gardenera (2026-11-05)”. Obowiązują WIZJA, STYL i AGENTS.

## Postęp

- Właściciel zaakceptował korektę grafiki i audyt wszystkich tekstur z
  `9867b7f`. Commit istniał przed rozpoczęciem tej analizy; repo było czyste.
  Pełna brama tego stanu: 6878 Mechanics/Assets, Input 50, Architecture,
  Render i Tools PASS. Windows niesprawdzony; push niezamówiony.
- Prześledzono definicję Buera, wybór ataków i ruch, rzeczywiste kontakty,
  pola, narastanie trucizny, animacje, anatomię, efekty, dźwięk i zapisy.
- Zachowano 16 natywnych kadrów czterech ataków, 14 prób pojedynczych ataków,
  12 prób zachowania bez/z ostrzałem oraz 12 prób obu broni przy 100 HP/40 ward.
  To pomiary wersji wyjściowej, nie dowód ukończenia przyszłej poprawki.
- Zestaw czterech ataków zaakceptowany. Rozpoczęto testy regresji przed
  zmianą wykonania: strumień, kontakt pocisku z podłożem, Siew i Żniwo.
- Wdrożono cztery role, cięższy obrót, gesty z oryginalnych póz i osobne
  głosy ciała/czarów. Oba PNG postaci oraz źródłowe maski alfa nie zmienione.
  Boczny rysunek plucia odłączony; rzeczywisty strumień mierzy kierunek od ust.
- Celowane 92 sprawdzenia Gardenera i 57 audio PASS; trzy kontrole grafiki,
  54+54 pojedynki, 27 prób grup, pomiary 1/8/32/128 i dwa zgodne golden.
  Szczegóły i ograniczenia pomiarów są w najnowszym ODBIOR w HISTORII.
- Perfekcyjny bot nadal szybko zabija zwykłego Gardenera; para w otwartej
  sali nie wymusza zejścia z automatycznego krążenia w 30-sekundowej próbie.
  Odbiór trudności, nowych efektów i barwy dźwięku należy do właściciela.
  Pełna brama Linux PASS: 7035 Mechanics/Assets, 50 Input, Architecture,
  Render i Tools; 741,24 s, 9 stabilnych świadectw. Windows niesprawdzony.
  Osobna sonda potwierdza uniknięcie każdego ataku zwykłym ruchem po 0,25 s
  reakcji w 60/120/240 Hz. Własny klon usunięty po zachowaniu dowodów.
  Pełny zatwierdzony zakres zweryfikowany; bez push.

## 1. Cel walki

Gardener ma zatruwać i zmieniać dostępną przestrzeń. Jego ciało wyraźnie
pokazuje, skąd zagrożenie pochodzi, gdzie trafi i kiedy przestaje szkodzić.
Zostaje zwykłym cięższym przeciwnikiem, z obecnym 520 HP. Na początek nie
zwiększamy HP, nie dodajemy faz bossa ani odporności na celne kontry.

Rekomendacja: **cztery różne ataki, z przebudową obecnego zestawu**, zamiast
piątego podobnego pola na ziemi. Poniższy zestaw jest zatwierdzony do wdrożenia.
Nazwy angielskie są robocze; tekst gry nadal po angielsku.

## 2. Proponowany zestaw

| Atak | Obraz i działanie | Odpowiedź gracza |
|---|---|---|
| **Wymioty / Retch** — zamiast root-brace | Chwyta brzuch, zapiera przednie nogi, pochyla głowę i wymiotuje krótkim, szerokim strumieniem przed siebie. Wymioty wychodzą z ust i zadają obrażenia tam, gdzie widać strumień. Tułów i przód są groźne, boki pozostają wolne. | Wyjście w bok lub unik poza strumień; kara po wyczerpującym wydechu. Skok nie jest domyślną ochroną przed strumieniem na wysokości ciała. |
| **Zaraźliwe splunięcie / Rot Spit** — przebudowa spore | Jeden ciężki pocisk z ust na średni dystans. Ślad lotu prowadzi do rzeczywistego uderzenia. Dopiero kontakt z podłożem zostawia krótką plamę; ściana blokuje lot i nie tworzy plamy za sobą. | Zmiana kierunku po namierzeniu; obserwacja miejsca upadku. Brak naprowadzania już wypuszczonego pocisku. |
| **Siew / Blight Sowing** — zamiast seed-ring | Dłonie zbierają i wyrzucają trzy widoczne nasiona; powstają niewielkie, rozdzielone ogniska zarazy przecinające część drogi. Materiał: zgnilizna, wyschnięte tkanki i korzenie, zgodne z bazą. Zawsze czytelna luka; bez dziewięciu jednakowych kół otaczających kamerę. | Wybór wolnej drogi, zmiana kierunku zamiast automatycznego okrążania w jedną stronę. |
| **Żniwo / Harvest** — zamiast late-bloom | Wyraźnym gestem wyrywa własny zasiew: istniejące dojrzałe ogniska najpierw pęcznieją, potem wybuchają krótko i gasną. Obrys całego zagrożenia jest widoczny od zapowiedzi. Atak zużywa plamy i ponownie otwiera przestrzeń. Nie pojawia się nowy niewidoczny wybuch pod aktualną pozycją gracza. | Odejście od zapowiedzianych ognisk albo celna kontra w widocznym oknie. Przerwanie przygotowania zatrzymuje Żniwo. |

Wymioty mają ograniczony czas i ustalony kierunek końcówki przygotowania;
nie obracają się natychmiast za graczem przez cały atak. Mały rozbryzg po
strumieniu ma jasno określony koniec obrażeń. Siew i splunięcie korzystają
ze wspólnej reguły osadzania plamy po rzeczywistym kontakcie. Żniwo wybiera
wyłącznie własne, istniejące i wystarczająco trwałe ogniska; bez zasiewu
Gardener wybiera inny atak. Nie dodajemy przywoływanych mobów ani nowego
systemu niszczenia nasion w tym zakresie.

Punkt wyjścia do strojenia: przygotowanie Wymiotów około 0,8 s, krótki
wydech około 0,6 s i wyraźny odpoczynek około 0,8 s; zasięg około 4 m.
Siew/Żniwo: około 0,9–1,0 s czytelnej zapowiedzi. To hipotezy do sond,
nie zatwierdzone liczby balansu. Nie skracać ukradkiem czasu już widocznego
ostrzeżenia. Na start limit trzech utrzymywanych ognisk na Gardenera;
wybór Siewu przy pełnym limicie nie usuwa aktywnego zagrożenia bez wygaszenia.

## 3. Ruch i reakcje

- Podejście, zatrzymanie, obrót i odejście mają pasować do czterech nóg
  i ciężkiego brzucha. Sprawdzić poślizg stóp, ruch przy kolumnie i w drzwiach.
- Blisko: ustawienie przodu do Wymiotów i czytelne zaparcie. Średnio: wybór
  drogi i zasiewu. Bez teleportu, odskoku sowy czy kopiowania szarży Irona.
- Gardener czyta widoczny ruch, odległość i faktyczne przeładowanie; nie
  przyszłe wejście gracza. Kiedy cel zejdzie z linii, rzeczywiście chybia.
- Dobór ataków uwzględnia czas i miejsce własnego zasiewu. Istniejące limity
  liczby atakujących pozostają; sprawdzić też nakładanie pozostawionych pól.
- Trudność wynika z wyboru odpowiedzi i przestrzeni. Bot strzelający idealnie
  może dobrze wykorzystać kontrę; nie podnosić HP ani nie osłabiać trafień,
  żeby wymusić przegraną każdego nieruchomego bota.

## 4. Animacje i wygląd

Wzorce: `baza/buer.png`, obecne zaakceptowane pozy oraz dołączone Inferno.
Zachować twarz, rogi, czerwoną grzywę, skórę, cztery nogi, kopyta, proporcje,
kontur i skalę detalu. Nie regenerować całej postaci. Najpierw wykorzystać
istniejące pozy; dopisać tylko brakujące etapy, jeśli zachowają ten sam obraz.

1. Odróżnić brzuch/gardziel przy Wymiotach, pojedyncze splunięcie, gest dłoni
   przy Siewie i wyrwanie przy Żniwie. Każdy: przygotowanie → wypuszczenie →
   skutek → powrót. Przerwanie i śmierć również muszą kończyć gest.
2. Wszystkie czary dziś używają namalowanego plucia z klatki 7. Oddzielić
   dekoracyjny strumień od chronionej sylwetki i związać efekt z ustami oraz
   prawdziwym kierunkiem kontaktu. Nie przemalować przy tym twarzy ani skóry.
3. Przed podłączeniem nowych ilustracji porównać je obok bazy w tej samej
   skali i zachować dowód. Właściciel zatwierdza kierunek nowych efektów
   w ramach tego planu; odstępstwo wymaga nowej propozycji. Do `baza/`
   trafia jeden obraz nowego projektu efektów, bez zastępowania wzorca postaci.
4. Malowana, zgaszona oliwka, ochra i brunatna zgnilizna. Żadnego neonu,
   plastikowych glutów, uproszczenia palety czy dodatkowego mikroszczegółu.
   Granice kontaktu są czytelne; dekoracyjny ślad po wygaśnięciu nie szkodzi.
5. Obowiązkowe trzy kontrole przed commitem: klatki z bazą, natywne sceny
   3/6/12 m w jednym świetle, przejścia ruchu i wszystkich ataków. Każda
   zmiana sylwetki wymaga anatomii, punktów niezależnych i nowych masek.

Dolny HUD, obrazy broni, amunicja, inne postacie i przywrócony ogień pozostają
poza zmianą. Czytelność ostrzeżenia poprawia ciało i efekt w świecie.

## 5. Dźwięk — po dopracowaniu walki i obrazu

Własny, przytłumiony głos cierpiącego ciała: ciężki oddech, cichy pomruk,
zauważenie gracza, ból, śmierć oraz wysiłek przy każdym ataku. Oddzielnie
materiał czaru: zalegający w gardle odgłos przed Wymiotami, mokry wydech,
ciężkie splunięcie, rozsypanie nasion i pękanie korzeni. Groza, nie głośność
ani komiczne wymioty; bez brzmienia szuflady, ostrych pisków i maskowania
strzałów Judge'a/Exorcista. Głos ciała gra obok czaru, nie zamiast niego.

Korzystać ze wspólnego limitu głosów i obecności, źródła z jawną licencją
oraz proweniencją. Sprawdzić obcięcie szczytów, odsłuch w grze, tłum,
zasłonięcie ścianą, dystans, suwaki, pauzę, przerwanie i śmierć. Nie zmieniać
stanu symulacji ani jej RNG na potrzeby dźwięku.

## 6. Kolejność wdrażania po akceptacji

1. Zachować bazę i sondy; dopisać czerwone testy konkretnych zaakceptowanych
   zachowań. Rejestrować szkody, kontakty, czas reakcji i przerwania.
2. Wdrożyć i sprawdzić kolejno Wymioty, kontakt splunięcia, Siew i Żniwo.
   Wspólne wykonanie opisane danymi, bez wyjątków `if kind == 'buer'`
   rozsianych w fizyce i renderze. Jedna zmiana balansu na commit z przed/po.
3. Dopracować ruch, dobór i rytm ataków w samotnej walce oraz przy dwóch
   Gardenerach, a także w krypcie i przy wschodnim wejściu ze Stolasem/Impem.
4. Podłączyć zaakceptowane etapy animacji i efekty, sprawdzić maski,
   rzeczywiste początki/końce zagrożeń i wykonać trzy kontrole wizualne.
5. Dopasować i odsłuchać osobno ciało i czary, potem całość z bronią i tłumem.
6. Testy końcowe, przegląd diff, aktualizacja istniejącej dokumentacji,
   commit po pełnej zielonej bramie. Push tylko na polecenie właściciela.

## 7. Warunki weryfikacji

- Widoczny strumień/pocisk odpowiada kontaktowi; brak obrażeń z tyłu,
  przez ścianę, inne piętro lub po wygaśnięciu. Trafienie i chybienie jawne.
- Każdy atak ma wykazaną odpowiedź z normalnym czasem reakcji i kosztami
  uniku; testy 60/120/240 Hz. Wymioty nie stają się naprowadzającym laserem.
- Porównać trzy strategie: stanie i strzał, automatyczne krążenie, świadome
  czytanie. Obie bronie, skończona amunicja, 100 HP/40 ward, kilka dystansów
  i seedów. Porównać koszt błędu oraz wypuszczone/przerwane ataki; nie
  podmieniać progów testów, żeby wymusić sukces.
- Pola mają ograniczony koszt i czas życia; działają z wieloma właścicielami,
  różnymi stronami, ścianami i piętrami. Żniwo nie uruchamia cudzych pól.
  Brak nieprzerwanego uwięzienia i nieuniknionego pokrycia wyjścia całej grupy.
- Continue w środku przygotowania, lotu, rozwoju plamy i Żniwa zachowuje
  pozycję, fazę i właściciela. Sprawdzić stare zapisane ataki, śmierć
  Gardenera/gracza, przerwanie, odpoczynek, zmianę mapy i replay. Zmiana
  identyfikatorów/formatu wymaga zgodności lub jawnej migracji.
- `souls-gate`, `souls-bots`, aktualne próby kaplicy oraz testy kontaktów,
  pól, warunków, anatomii, masek, obrazu i dźwięku. Historyczny
  `creature-pressure` nie zastępuje prób bieżącego Buera.
- Wydajność przed/po w osobnym klonie w Work/tries: 1/8/32/128 stworów,
  limit pól i głosów, bez innych ciężkich procesów; po pomiarze usunąć klon.
- Dwa identyczne golden dla celowej zmiany symulacji/masek, uzasadniony
  wzorzec Linux, potem `scripts/linux/TEST.sh All --timeout 1800`.
  Windows jawnie niesprawdzony. Testy techniczne nie zatwierdzają stylu.

## Poza bieżącym zakresem

Bez nowych broni, zmian elit, bossów, docelowej mapy, +II ani następnych sigili.
P7 pozostaje próbą właściciela; wcześniejsze problemy ukończenia kaplicy
przez bota nie są powodem do regulowania innych stworów. Otwarte B03/B04,
C02 wyłącznie po próbie, wybór F7, kontrast Iron Thralla oraz stany zabitych
w kolejnych obszarach zachowano w archiwum poprzedniego PLANU. Dawne błędy
weight/cienia zostały naprawione i nie stanowią obecnie czerwonej bramy.
