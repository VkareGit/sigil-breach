# Poligon, walka i oprawa — odbiór etapu 28.10.2026

Wdrożenie kontynuuje plan poligonu. Ostatnia decyzja użytkownika ma
pierwszeństwo: jedna postać bossa/jedno życie, wszystkie dotychczasowe
ruchy dostępne w tej walce, zachowanie HUD-u i bazowych demonów.
To raport zmian i ich weryfikacji, nie deklaracja ukończonej gry ani
ponowny audyt każdej linii całego projektu.

**Korekta po zgłoszeniu użytkownika:** punkt 7 nie jest ukończony. Zatwierdzone
nisze, istniejące klatki i poprawione portale stanowią częściowy wkład, a nie
realizację całego zadania wizualnego. Nowy przegląd ujawnił brak wspólnej
kompozycji wnętrza, słabą separację sylwetki Margrave'a oraz współdzielone
gesty różnych ataków. Konkretne prace i odbiór opisuje sekcja „Punkt 7 —
korekta zakresu” w [planie](PLAN-DOPRACOWANIA-POLIGONU.md). Koncepcja otoczenia
jest podglądem do akceptacji; nie została podłączona do gry. HUD i modele
pozostają niezmienione. Wyniki testów poniżej potwierdzają wskazane kontrakty
techniczne, nie jakość artystyczną ani ukończenie punktu 7.

## Co jest w grze

Korekta portali po zgłoszeniu użytkownika: prześwitujące przywołania, zanikanie
bramy przy narodzinach demona i wyjście są rysowane po obiektach
nieprzezroczystych, z odczytem ich głębokości. Nie zastosowano rysowania
przez ściany. Test GPU obejmuje cztery rodzaje (także znak ołtarza), każdy
przed dekoracją, za dekoracją i za ścianą: 12 przypadków. Oryginalna kolejność
nie przechodzi kontroli negatywnej dla pojawienia się demona (0 widocznych
pikseli przed dalszą dekoracją); po zmianie wszystkie przypadki przechodzą.
Na etapie tej poprawki Mechanics miał 4947 sprawdzeń. Native rendery obejrzano w
`work/closure-28/portal-review`. Nie zmieniono PNG, HUD-u ani reguł walki.

| Commit | Wdrożony zakres |
|---|---|
| `ba8df4c` | Zamknięta bazylika, pełne zestawy ataków w jednym życiu, presja i odpowiedzi na zapowiedzi |
| `5ccd19b` | Kroki z animacji, głosy ostrzegawcze, priorytety, lot/kontakt pocisków, ambient pod stropem |
| `9449bb3` | Zatwierdzony obraz nisz grobowych, galerie i nazwany rejestr malowideł środowiska |
| `63f6a85` | Oddzielenie archiwalnych prób faz od aktualnych jednofazowych walk |
| `bca9642` | Nowe proporcje mapy: nawa procesyjna, absydy i dwie wysokie sale pojedynków, stanowiska mapy |
| `44f4060` | Jawna aktualizacja golden po udowodnieniu wpływu samych danych nowych ataków |
| `3a35b56` | Przygotowanie świata w widocznym ładowaniu i ograniczony cache kafelków cieni |
| `f3547ad` | Wspólna korekta kolejności rysowania portali i 12 testów GPU |
| `e5ab727` | Usunięcie alokacji zamknięć w każdym sweep kolizji, bez zmiany matematyki |
| `2704b4b` | Presja zwykłych demonów, konfigurowalne otwarcie próby i walki obiema broniami |
| `f27ba3f` | Kopia pozy tylko przed ostatnim nadrabianym tickiem; zgodność trzech widoków ze starą ścieżką |

Poprzednie punkty 1–3 (kontakt sfery z ciałem, reset, wysokości ataków,
poligon bez handlu i fal) pozostają częścią bazy. Nie przywrócono Limbo
do publicznego menu. Zachowano kod dawnych trybów.

## Przestrzeń i klimat

Mapa `proving` ma 49×43 m. Nawa prowadzi ku podniesionemu prezbiterium;
do bocznych sal wchodzi się przez niższe progi. Każda sala pojedynku ma
15×18 m, wysokie sklepienie do 9,3 m, boczne kolumnady i absydę na końcu
osi. Środek pozostaje wolny od przypadkowych rekwizytów, żeby odczytywać
sylwetkę oraz tor ataku. Galerie grobowe mają 3 m wysokości.

Inspiracją był rzeczywisty porządek przestrzenny, a nie zestaw osobnych
ozdobników: [arkady i prezbiterium San Nicola](https://www.basilicasannicola.it/sez/2/93/114/interno),
[krypta z rytmem kolumn](https://www.basilicasannicola.it/sez/2/95/la-cripta)
i [proporcje nawy Durham](https://www.durhamcathedral.co.uk/explore/the-cathedral-building-and-grounds/the-nave).
Nie jest to rekonstrukcja żadnego z tych zabytków. Przeniesiono zasadę
osi, rytmu podpór i kontrastu niskiego wejścia z wysokim wnętrzem.

Pieczęcie bossów należą do podniesionych ołtarzy. Podłogowy obwód ognia
pojawia się podczas aktywnej próby; znika po zakończeniu/resetowaniu.
Nie zadaje obrażeń i nie maskuje nieistniejącej kolizji. Sklepienie i jego
obrzeże są natomiast rzeczywistymi przeszkodami dla pocisków.

`git diff a48c555..3a35b56 -- game/assets game/src/ui` wykazuje tylko
dodanie zatwierdzonego `catacomb-loculi-fresco.png`. Żadna wcześniejsza
grafika demona, ręki, broni, portretu ani HUD-u nie została podmieniona;
kod układu HUD-u też nie jest zmieniony w tym zakresie. Nowe zachowania
korzystają z istniejących malowanych klatek i efektów.

## Walka i dźwięk

### Korekta zwykłych demonów po kolejnym zgłoszeniu

Cztery zwykłe typy mają krótsze przerwy, szybsze podejście lub dostawy,
a strzelcy przewidują obserwowany ruch już na TIER 1. Imp wykonuje silniejsze
dosunięcie pazurem i wcześniej wybiera skok; żelazny sługa ma szybszą,
przewidywaną szarżę. Stolas unika utrzymywanego na nim celownika na TIER 1,
Buer częściej zmusza do opuszczenia miejsca. Trafienia kosztują więcej HP.
HP demonów, ich bazowe grafiki, geometria i czasy zapowiedzi pozostały takie same.
Tempo zwykłego biegu nadal nie przewyższa biegu rycerza nawet na TIER 5.

`trial.readyDelay` to opcjonalne ustawienie spotkania, odrębne od czasu portalu,
pauzy pojawiania się i windup ataku. Zwykłe komnaty używają 0,2 s zamiast
domyślnych 1,2 s. Bossowie zachowują swoje otwarcia i jedno życie.

Nowe 45 sprawdzeń `creature-pressure` rozgrywa 16 walk: cztery komnaty,
dwie bronie, bezruch albo reakcja. Zwykłe magazynki, rezerwa i przeładowanie;
brak dopisywania życia czy amunicji. Przykład trzech żelaznych sług ze strzelbą:
stanie kończy z 83,8 HP / 9,2 osłony, reakcja ze 100 HP / 24,6 osłony.
Próby reaktywne pozostają wygrywalne. Idealne celowanie rewolwerem potrafi
przerwać słabych strzelców przed rzutem — to zachowana kontra, nie błąd testu.
Te wyniki nie są ludzką oceną trudności ani deklaracją ostatecznego balansu.

Obie bronie przeszły walki z rzeczywistym przeładowaniem; cała reaktywna
walka rewolwerem z żelaznymi sługami odtwarza się bitowo. Dodatkowe testy
sprawdzają zamrożony cel rzutu, zero/ujemny readyDelay, brak mutacji definicji
i zachowanie pauzy pojawienia się. Pełna mechanika: **5001 sprawdzeń PASS**.
Poprzednie sześć skrótów golden wraca po przywróceniu samych czterech
definicji demonów na nowym silniku. Dawne projekcje v0.33 nie zostały zmienione.
Test poleceń dwóch aktorów korzysta z zamrożonego dawnego napastnika, aby
nowy balans nie zabijał drugiego rycerza przed zaplanowanym przełączeniem broni.

### Zachowane walki bossów i audio

Margrabia łączy wachlarz z presją na kierunek ruchu, linię ognia na ziemi,
odpowiedź pociskiem po lancy oraz bliski wybuch wokół siebie. Furfur ma
pchnięcie, szarżę, powrót po szarży i wzory piorunów. Wyraźna zapowiedź
poprzedza zobowiązanie celu; kolejne uderzenie ma własną zapowiedź,
a po zakończeniu ciągu pozostaje dłuższe odsłonięcie. Nie zwiększono HP
tylko po to, aby zastąpić presję dłuższym strzelaniem.

Podstawą były czytelna sylwetka, ciężar i etapy ruchu opisywane przez
[twórców Demon's Souls](https://blog.playstation.com/2021/03/26/what-demons-souls-can-teach-stunt-performers-about-human-movement/).
To adaptacja zasad do szybkiego FPS-a, nie dowód równej jakości walki.

Próba deterministyczna: 30 s, bez strzelania, TIER 1, 100 HP / 40 osłony:

| Zachowanie sterownika | Margrabia | Furfur |
|---|---|---|
| Bezruch | śmierć 11,500 s | śmierć 13,258 s |
| Stały obieg | śmierć 26,458 s | śmierć 20,992 s |
| Reakcja na zapowiedzi | przeżywa, 80,2 HP | przeżywa, 62 HP |

To sprawdza zagrożenie oraz istnienie odpowiedzi. Nie zastępuje człowieka,
który celuje, przeładowuje, uczy się przestrzeni i ocenia przyjemność.

Kroki wykorzystują zegar malowanej animacji. Typ głosu wynika z definicji
demona; ostrzeżenie ma wyższy priorytet od kroku i chwilowo ścisza muzykę.
Dodano odgłosy pobliskich lotów/kontaktów oraz rzadki ambient pod stropem.
Eksport obejmuje 52 efekty i pięć warstw muzyki. Sprawdzono limity,
próbki i brak mutacji symulacji; nie deklarujemy wykonanego ludzkiego odsłuchu.

## Weryfikacja i granice

- **5006 sprawdzeń mechaniki/zasobów**, **36 sprawdzeń rzeczywistego wejścia**,
  **566 skompilowanych plików Lua**; format poprawny, zero naruszeń architektury.
- Końcowy `TEST.ps1 -Suite All -TestTimeoutSeconds 600` zakończył się PASS
  w jednym przebiegu, na stabilnych źródłach: mechanika, wejście, showcase,
  benchmark/core-measure/step-study/audio-export smoke i pełny startup.
  Kontrola świeżości raportów pozostała aktywna. W poprzedniej iteracji
  poprawnie odrzuciła proces showcase bez nowego raportu mimo kodu wyjścia 0.
- Audyt bitmapowego UI: 270 scen, 7085 granic tekstu, 67995 porównań chronionych
  obrazów, 3415 kontroli wnętrz HUD-u; zero problemów. Native review obejmuje
  komnaty, aktywne ataki, portale, reset oraz różne proporcje ekranu.
  Obejrzano portal przed dekoracją, ołtarz, nawę i salę walki.
- W poprzednim etapie 48 par ujęć przed/po optymalizacji światła miało identyczne
  SHA-256 PNG. Obecna poprawka portali ma własne 12 sprawdzeń kontaktu obrazu
  z głębią GPU. Żaden bazowy PNG ani kod `src/ui` nie zmienił się od `686264f`.
- Kontrola przypisania nowych wyników golden: zamiana **wyłącznie czterech
  definicji zwykłych demonów** na dawne daje wszystkie sześć poprzednich digestów.
  Weryfikacja izolowanego drzewa ze stabilnym hashem:
  `work/closure-28/golden-attribution/verified/`. Referencje v0.33 zachowane.
- Pokwitowania końcowych testów mają `sourceStable=true`, `exitCode=0` i wspólny
  fingerprint `AE289FB9BE72F369155F2EB66C812B69A928A8553FC2F7D64DEAD8D81E025B54`.
  Artefakty: `work/qa-v33/`, `work/closure-28/`.

Wydajność i koszty ładowania są opisane w
[osobnym raporcie](PUNKT-1-WYDAJNOSC.md). Smoke narzędzia nie zamyka
kryterium wydajności. Pierwszy widok gry po przygotowaniu świata nie tworzy
odroczonych obrazów; w ostatnim pełnym startup miał 21,72 ms, katalog
9,72 ms. Ładowanie miało 63 widoczne kroki i 1,87 s do gotowości.
Najdłuższy provider trwał 120,60 ms; nie obiecujemy klatek 16,7 ms
podczas niepodzielnego dekodowania/uploadu obrazu.

Pięć par E0 (`710d1ac`) / stan przed ostatnią optymalizacją (`2704b4b`) wykazuje
**regresję pełnej klatki 20 żywych demonów: 6,3142 → 8,7204 ms (+38,1%)**.
P95 tej próby: 16,70–19,52 ms. P95 publicznych sal: 8,66–12,03 ms, lecz
pojedyncza klatka Margrabiego osiągnęła 86 ms. Nie zamykamy kryterium
wydajności medianą ani pominięciem outlierów. To porównanie całej ewolucji
gry, z nową treścią, nie izolowane A/B jednego algorytmu.
Osiem pełnych cykli wcześniejszego testu zasobów nie wykazało narastania
obrazów/canvas/pamięci GPU; pokwitowanie źródeł jest stabilne.

Po tym pomiarze `f27ba3f` usunął kopie historii, których aplikacja nigdy
nie wyświetlała. Nie połączono mutowalnych snapshotów ani nie zmieniono
czasu strzału. W 48 klatkach o różnych dt stan walki, powierzchnie trafień
i pola obrazu zgadzają się ze starą ścieżką dla trzech obserwatorów.
Osobne pięć par tej samej treści `2704b4b` / `f27ba3f`: mediana pełnej
żywej klatki 8,2468 → 8,1008 ms, wynik **INCONCLUSIVE**, ponieważ IQR
wcześniejszego wariantu to 12,7%. Nieruchome sceny: NO REGRESSION.
Po poprawce p95 20 demonów wynosi 14,92–16,18 ms, najgorsza klatka
24,63 ms; publiczne sale mają p95 8,50–11,22 ms. To wyniki tej maszyny,
nie gwarancja ani dowód zamknięcia historycznej regresji E0.

**Stan ośmiu punktów:** punkty 2–6 mają wdrożenie gotowe do próby użytkownika;
nie oznacza to akceptacji ich wyglądu, feelingu ani odsłuchu. **Punkt 7 wymaga
dalszego wykonania**, a nie wyłącznie testu gracza. Punkt 1 i kosztowa część
punktu 8 nie mają pełnego formalnego odbioru z powodu wydajności. Dotychczasowe
części integracji punktu 8, w tym poradnik, reset/replay, render, wejście
i ładowanie, są wykonane dla obecnej wersji; po wdrożeniu grafik trzeba
sprawdzić zmienione ścieżki ponownie. Nie deklarujemy „zamknięte 8/8”.

## Skalowanie i co pozostaje świadomą granicą

Komnata, ołtarz, próba, stanowiska resetu/fizyki i nowy obraz ścienny
są danymi mapy. Zmiana tych danych nie wymaga nowego trybu ani gałęzi
renderera. Nowe ataki używają wspólnych dostaw, pakietów i nazwanych póz.
Zegary audio są tylko prezentacją. Cache światła ma limit i właściciela.

Przegląd integracji objął granice danych i wykonawców, kolejność systemów,
własność stanu/efektów, zapis/replay, geometrię, rysowanie, audio oraz
testowe rozszerzenia. Nie jest to ponowne czytanie każdego wygenerowanego
atlasu/maski linia po linii. Ocena: **baza nadaje się do kolejnego przyrostu
treści bez nowego masowego refaktoru**, przy zachowaniu poniższych kontraktów.

| Rozszerzenie | Miejsce zmiany | Co chroni przed przebudową rdzenia |
|---|---|---|
| Broń o istniejącym sposobie strzelania | `content/weapons.lua`, profil/napisy/art | Rekord `arsenal[id]`, oddzielne dostawy i przeładowania; test `weapon-extension` |
| Nowy fizyczny efekt lub pocisk | Definicja i wykonawca w `combat/weapon_delivery.lua` / `combat/effects.lua` | Wspólne obrażenia, sprawca, kontakt, przerwanie/reset; walidacja wykonawcy |
| Nowy demon / wariant | Definicja `creatures/`, wpis w `content/enemies.lua`, art | Wspólna maszyna stanów i wybór ataków; katalog budowany z danych |
| Nowy wzór ataku bossa | `attacks`, `tactics.moves`, nazwane pozy | Commitment, własny cooldown, skończona objętość i kontynuacje nie zależą od nazwy bossa |
| Komnata / ołtarz / nowa mapa | `content/maps/` | Walidacja referencji, dojścia, stanowiska oraz reset/replay mapy |
| Nowy obiekt przezroczysty | Rejestr obiektów świata, etap `translucent` | Odczyt gotowej głębi sceny; brak wymuszania widoczności przez ściany |

Nowy **rodzaj** mechaniki nadal może wymagać nowego schematu i modułu.
Rejestr demonów pozostaje ręczną listą; checker wykrywa brak pliku/wpisu.
Nie ma potrzeby zmieniać go teraz w automatyczne odkrywanie plików, kosztem
kolejności i czytelności. Cache widoku musi używać korzenia sesji, a snapshot
strzału pozostaje niezmienny — te zasady są ważniejsze niż kolejna warstwa klas.

Pozostają konkretne ograniczenia: demony są płaskimi sprite'ami, mapa
używa geometrii 2.5D, strzelnica ma ustaloną oś, Q ma jeden publiczny slot,
a bank cieni przygotowuje najwyżej 64 różne pozycje lamp. Przekroczenie
tych założeń wymaga lokalnego rozszerzenia kontraktu, nie obietnicy, że
cała przyszła gra będzie wyłącznie zmianą liczb.

Zapis `SIGIL09` rodzaju session obejmuje mapę i ciała; nie jest pełnym
quicksave w dowolnym momencie walki. Kooperacja, sieć i kolizje rycerz–rycerz
nie są ukończonym produktem. Edytor mapy jest nadal tekstowy (Lua).

Ocena dłuższej gry i odsłuch należą do odbioru użytkownika. Starego
ujemnego wyniku względem E0 nie nazywamy zaliczonym przez zmianę progów
ani przez sam fakt ukończenia nowej mapy. Baza nadaje się do testowania
treści; określenie „perfekcyjna” nie wynika z raportu automatycznych testów.

Praktyczne przykłady zmian są w
[PORADNIK-POLIGON-WALKA-2026-10.md](PORADNIK-POLIGON-WALKA-2026-10.md).
