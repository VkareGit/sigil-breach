# SIGIL: BREACH — fundament v10: baza bez założeń jednego poligonu

Status: PRZYJĘTY przez użytkownika 2026-10-25; wdrażanie od V0.
Stan odniesienia: `b72d144`, wersja 0.32.
Docelowa wersja wydania: 0.33. Kontrakty trafień planu v7 i zasady planu v9
pozostają wymaganiami.

## Dlaczego ten plan

Ocena kodu 0.32 (2026-10-25): jakość „pionowa” jest wysoka. Działają warstwy
pilnowane checkerem, 0 krawędzi symulacja→prezentacja i stały krok 120 Hz
niezależny od FPS. Złoty wzorzec, dziennik z odtworzeniem, symulacja bez
grafiki, rejestry i schematy treści oraz 3981 sprawdzeń są zielone.
Jedna walka na jednym poligonie jest dobrze zbudowana.

Skalowanie „wszerz” opiera się jednak na założeniach tego poligonu. Kolejna
naturalna zmiana wymagałaby wtedy przepisania wielu modułów naraz, a to
znaczy, że baza nie jest gotowa. Plan nie przyjmuje zasady „dodamy, gdy
będzie potrzebne”: każdy z siedmiu blokerów ma być usunięty teraz, z dowodem.

Oznaczenia: bloker B1–B7 z oceny = etap V1–V7 poniżej, w kolejności wykonania
(kolejność wynika z zależności, nie z numeru blokera). „B2” w dokumentach
ODBIOR nadal znaczy odbiór gracza i nie jest tym samym co bloker B2.

| Bloker | Na czym polega dziś (dowód w kodzie 0.32) | Etap |
|---|---|---|
| B1 | Jeden cel: AI, ataki, pociski, zagrożenia i wybuch mają osobne ścieżki `damagePlayer`/`damageEnemy`; ok. 160 odwołań `g.player` w symulacji; `Rules.seesKnight`; poza i billboard liczone względem `g.player` (`enemies/pose.lua`) | V2 |
| B2 | ECS nominalny: 1 użycie `ecs:query`, 62 bezpośrednie `g.enemies`, pule sztywne według typu, brak usuwania encji i indeksu id (zagrożenie szuka właściciela liniowo); martwe ciała zostają w tablicy do końca fali; separacja O(n²) | V1 |
| B3 | Świat: kwadratowa siatka `w.size`, kafle 0/1/2, jedna podłoga na (x,z); BFS przepływu po całej mapie na każdą komórkę celu, cache czyszczony w całości, nawigacja bez promienia ciała; stały budżet 16 świateł na całą mapę (nadmiar cicho odrzucany); brak indeksu przestrzennego | V3 |
| B4 | Treść: demon z nowym atlasem wymaga ręcznych wielokątów anatomii dla każdej klatki (ok. 28), ręcznego `enemy_frames.lua` (2781 linii), bake masek i punktów anatomicznych | V7 |
| B5 | Zapis: ręczny format SIGIL08, każde pole kodowane ręcznie, migracje pisane per wersja; nowy rodzaj stanu = nowy ręczny koder | V4 |
| B6 | Prezentacja zamknięta: renderer ma metody dla konkretnych obiektów (seal, shrine, pickup, portal, ember); HUD pokazuje dwa wiersze broni i tylko slot Q; ekrany czytają `g.run` bezpośrednio; 34 użycia tabeli tekstów wobec ok. 725 literałów WIELKIMI LITERAMI w symulacji i trybach | V6 |
| B7 | Dziennik: obserwacja strzału zapisuje geometrię wszystkich ciał na mapie (`combat/observation.lua`); przy 96 ciałach 2,4 MB/s, limit 64 MiB po ok. 28 s | V5 |

## Cel i zakres

Każda z poniższych zmian ma się sprowadzać do definicji, danych i małego
modułu z testem, bez zmian rozsianych po AI, walce, rendererze, zapisie
i GUI:

- nowy aktor dowolnej strony (sojusznik, przywołaniec, wieżyczka, demon
  walczący z demonem, drugi rycerz),
- większa lub wielopoziomowa mapa,
- setki ciał,
- nowy demon z nowym atlasem,
- nowy rodzaj zapisywanego stanu,
- nowy obiekt świata lub slot HUD,
- długie nagranie dużej walki.

Produkcja się nie zmienia: jeden poligon, dwie fizyczne bronie, obecne
demony, menu i HUD 0.30, rycerz bez magii. Nowe możliwości dowodzą próby
w testach i poza menu. Gra lokalna dla jednego gracza pozostaje modelem
produktu. V2 usuwa jednak założenie jednego celu z symulacji, więc drugi
rycerz jest wpisem w puli, a nie przepisaniem. Sieć (transport, predykcja)
nie wchodzi do v10 bez osobnej decyzji użytkownika.

## Zasady wykonania (każdy etap)

- Rozgrywka, balans, wygląd i stare zapisy bez zmian. Złoty wzorzec
  (playtest `57ba111d/960187d6`, human `98255b1c/361bb557`, drill
  `4192c0b6/8200078d`, kontakty `aab9a46e/299`, `4be34edb/671`,
  `663b77fc/178`) zostaje bit w bit. Jedyny wyjątek to zmiana definicji
  samego skrótu (V1), udowodniona równoważnością na tych samych przebiegach.
- `FORMAT.ps1 -Check`, `TEST.ps1 -Suite All`, 0 naruszeń architektury,
  zapadki liczb i krawędzi nie rosną. Każdy etap dokłada test pozytywny
  i negatywny swojego kontraktu.
- Nowe zapadki checkera (V0) mogą tylko maleć; etap jest zamknięty, gdy jego
  zapadka osiągnie wartość docelową.
- Pomiar przed i po w tym samym profilu (`--core-measure`, `--benchmark`);
  czasy są diagnostyką, nie progiem zależnym od maszyny. Progi skalowania
  dotyczą kształtu kosztu (liniowy, nie kwadratowy).
- Render istniejących ekranów i scen zostaje identyczny piksel w piksel
  (showcase, GUI audit), chyba że etap mówi inaczej i pokazuje różnicę.
- Odbiór B2 (gracz w normalnej grze) jest zawsze osobny. Testy go nie
  zastępują.

## Etapy i warunki odbioru

### V0 — stan odniesienia i zapadki

Utrwalić 0.32: skróty, pełne `--core-measure` i `--benchmark`, populacje
rozszerzone o 256 i 512 ciał (przygotowana fabryka jak dla 96). W checkerze
dodać policzone zapadki (plik w `tools/check/`, może tylko maleć):
`g.player` w symulacji poza modułami rycerza; bezpośrednie tablice pul
(`g.enemies`, `g.bullets`, `g.hazards`, `g.pickups`, `g.charges`) poza
właścicielami; `g.run`/`g.testField` poza modułami swojego trybu; literały
tekstu dla gracza poza `content/text`.

Odbiór: świeże raporty 20/48/96/256/512 z identyfikacją źródeł; cztery
zapadki z wartościami 0.32; wykres kosztu kroku od liczby ciał (dziś
oczekiwany składnik kwadratowy separacji, opisany).

Wykonano (2026-10-25):
- Zapadki w `tools/check/` (raport `architecture.txt`, licznik może tylko
  maleć, nowy plik = 0). Liczone w kodzie bez komentarzy i napisów, jako
  wskaźnik, nie dowód projektu:

  | Zapadka | Wartość 0.32 | Plików |
  |---|---|---|
  | `KNIGHT AS THE ONLY TARGET` (g.player w symulacji i treści, poza `src/player/`, `combat/rules/knight.lua`) | 154 | 39 |
  | `DIRECT POOL ARRAYS` (g/self/game/session/shown . enemies/bullets/hazards/pickups/charges, poza `session/world.lua`, `session/state.lua`) | 99 | 35 |
  | `MODE RECORDS READ OUTSIDE THEIR MODE` (g.run/g.testField poza modułami trybów) | 57 | 19 |
  | `PLAYER TEXT OUTSIDE THE TEXT TABLE` (napisy WIELKIMI LITERAMI i argumenty notify poza `content/text`) | 340 | 44 |

- Pomiary: `--core-measure` liczy też krok symulacji z przebudzoną populacją
  (z osobną separacją) i krok ze zwłokami. Populacje do 512.
  `SIGIL_CROWD_MAP=qa_crowd` to diagnostyczna sala 72×72 tylko w QA
  (`qa/data/crowd_map.lua`), dzięki czemu cała krzywa leży na jednej mapie.
  `SIGIL_CORE_JOURNAL_SECONDS` jawnie skraca próbkę dziennika.
- Stan odniesienia (odcisk źródeł `24338727…7B22`; raporty i wykres
  `step-cost.svg` w `work/v10-baseline`, poza gitem):

  | Ciała (qa_crowd) | 20 | 96 | 256 | 512 |
  |---|---|---|---|---|
  | krok symulacji, mediana ms | 0,106 | 0,357 | 5,549 | 16,214 |
  | w tym separacja, ms | 0,004 | 0,118 | 3,908 | 13,794 |
  | reszta kroku, ms | 0,102 | 0,239 | 1,641 | 2,420 |
  | krok przy zwłokach (n−1 martwych, 1 żywy), ms | 0,022 | 0,032 | 0,175 | 0,292 |
  | pociski rycerza (10) na krok, ms | 0,066 | 0,289 | 0,818 | 1,481 |
  | snapshot capture, ms | 0,63 | 1,04 | 1,88 | 3,32 |
  | dziennik: przyrost tekstu, MB/s | 0,56 | 2,51 | 6,68 | 13,31 |
  | dziennik: 64 MiB wystarcza na, s | 121 | 27 | 10 | 5 |
  | benchmark: wywołania rysowania na klatkę | 183 | 414 | 920 | 1779 |
  | benchmark: update w klatce aplikacji, mediana ms | 0,40 | 2,26 | 11,67 | 40,13 |

  Wykładnik kosztu kroku 20→512 wynosi 1,55; 96→256 aż 2,80. Separacja
  par ma wykładnik 2,84 (96→512), a reszta kroku 0,98 (20→512). Przy 512
  ciałach sam krok (16,2 ms) przekracza budżet 8,33 ms kroku 120 Hz.
  Zwłoki kosztują liniowo, ok. 0,5 µs na ciało w kroku. Dziennik rośnie
  liniowo z liczbą ciał na mapie, niezależnie od tego, w co celuje strzał
  (B7): przy 256 ciałach 10-sekundowa próbka przekracza limit produkcyjny.
  Na arenie (limbo) krok wynosi 0,159 / 0,297 / 0,916 ms dla 20/48/96 ciał,
  z separacją 0,009 / 0,097 / 0,566 ms.

### V1 — encje z cyklem życia (B2)

Świat ECS staje się rzeczywistym właścicielem encji:

- `spawn`/`despawn` z identyfikatorem i mapą `id → encja` (O(1)),
- zapytania po komponentach jako zwykła droga systemów,
- pule nie są typami gry: stworzenie, rycerz i pocisk to zestawy
  komponentów; `knight` staje się pulą 1..n, a `g.player` wskazuje
  sterowanego rycerza,
- zwłoki po osiądnięciu (`Corpse.settled`) i oknie prezentacji przechodzą
  do puli szczątków; pętle symulacji ciał żywych ich nie odwiedzają,
- definicje treści są tylko do odczytu po starcie sesji (strict: zapis do
  definicji = błąd; dotyczy ustaleń 5 podręcznika),
- zagrożenie, efekt i telemetria szukają właściciela po id.

Skrót złotego wzorca opisuje ciała żywe i szczątki w kolejności id, więc
przeniesienie zwłok nie zmienia opisu. Równoważność z obecnym skrótem
trzeba udowodnić na wszystkich trzech scenariuszach, zanim stary skrót
zostanie wycofany.

Odbiór:
- zapadka bezpośrednich tablic pul = 0 poza modułami pul;
- test: 300 zabójstw w jednej fali daje tablicę żywych równą liczbie
  żywych, a koszt kroku jest płaski względem liczby zwłok;
- test: despawn w trakcie iteracji, ponowne użycie id odrzucone;
- snapshot, restore i dziennik działają z pulą szczątków;
- separacja i kontakty idą przez indeks przestrzenny z V3 (do tego czasu
  O(n²) tylko po żywych, z pomiarem).

Wykonano (2026-10-25):
- V1-1 (commit dowodowy `9658dd4`): skrót złotego wzorca v2. Opisuje
  stworzenia w kolejności id z puli żywych i szczątków, a pomija zegar stanu
  (`phase`) ciał martwych, którego nic nie czyta. Przeliczony na
  niezmienionej symulacji 0.32 (zmienił się tylko `qa/golden.lua`):
  playtest `07f73bfa/a9192235`, human `fe26df14/563c8d0f`, drill
  `c13bcaec/f105ca06`; skróty kontaktów bez zmian.
- `core/ecs`: cykl życia `add`/`removeAt`/`remove`/`keep`/`clear`/`move`,
  indeks id O(1) (`get`) dla pul z id, samonaprawa indeksu po podmianie
  tablicy z zewnątrz, odmowa zajętego id bez zmiany puli.
  `session/world.lua` (moduł pul) daje `Pools.of/add/removeAt/remove/keep/
  clear/get/retire/retireWhere`, także dla ręcznych sesji bez ECS.
- Zapadka `DIRECT POOL ARRAYS`: 99 → 0. Zagrożenie, efekt i telemetria
  szukają ciała po id.
- Pula `remains`: zwłoki osiadłe, w spoczynku i po oknie rysowania
  (`combat_defaults.corpse.visible` = 25 s, wcześniej liczba w rendererze)
  przechodzą do niej w systemie `world.remains`. Żadna pętla kroku ich nie
  odwiedza; `Pools.get` i snapshot je znają.
- Pula `knights` (1..n, rycerz ma id `knight1`), `g.player` wskazuje
  sterowanego.
- Definicje treści pieczętowane w testach (`session/definitions.lua`):
  pieczęć na starcie przebiegu, weryfikacja po każdym zestawie. Zmiana
  pola istniejącej definicji jest błędem ze ścieżką; rejestry mogą zyskiwać
  i tracić wpisy. Cały przebieg nie wykazał ani jednej zmiany.
- Naprawione przy okazji: próbka prezentacji interpolacji czyta własne
  tablice (`out.ecs = false`); bez tego renderer dostałby pozycje
  nieinterpolowane.
- Testy: zestaw `entity-lifecycle` (13 sprawdzeń, m.in. 300 zgonów w jednym
  starciu → 300 w `remains`, 1 żywy w puli, zwłoki nie są już krokowane).
  Sonda w scenariuszach złotego wzorca: 2 zwłoki przeniesione, skróty v2
  bit w bit.
- Pomiar (qa_crowd, n−1 martwych + 1 żywy): krok 0,014 / 0,011 / 0,008 ms
  dla 95 / 255 / 511 zwłok (0.32: 0,032 / 0,175 / 0,292 ms). Koszt nie zależy
  już od liczby zwłok. Separacja żywych pozostaje O(n²) do V3; jej czasy
  wahają się między przebiegami (256 ciał: 0,7–3,9 ms).

### V2 — strony, cele i jedna droga obrażeń (B1)

- Komponent `faction` i tabela relacji w treści (rycerz, demony, neutralni):
  kto jest wrogiem, sojusznikiem, kto może ranić kogo i czym (zagrożenia,
  wybuchy, odłamki).
- AI ma cel jako id (`e.target`) wybierany strategią (`AI.targeting`).
  Domyślna strategia odtwarza dzisiejsze zachowanie: wrogi widoczny rycerz.
- Zmysły (`Rules.sees(g, o, target)`), style ruchu, zamach, okno ataku
  i unik działają względem celu, nie `g.player`.
- Jedno wejście obrażeń `Outcomes.body(g, target, packet, source, context)`.
  Prawa rycerza i stworzenia zostają osobne pod spodem, ale pocisk, cios,
  zagrożenie, wybuch i odłamek pytają o wrogie ciała w zasięgu, a nie
  o konkretną tablicę.
- `Pose.sample(g, e, viewer)` oraz billboard, klatki tyłem i punkty pazura
  liczą się względem podanego widza.
- Zdarzenia niosą źródło i cel jako id ciał.

Domyślne relacje odtwarzają 0.32: demony nie ranią demonów, zagrożenia
demonów nie ranią ich właścicieli.

Odbiór:
- złoty wzorzec bit w bit;
- zapadka `g.player` w symulacji zeszła do modułów rycerza (sterowanie,
  kamera, HUD przez zapytanie);
- testy-próby bez zmian kodu, tylko definicjami:
  - sojusznik atakowany przez demony, który rani demony i dostaje od
    zagrożeń,
  - demon „bratobójczy” atakujący inne demony,
  - wieżyczka,
  - dwóch rycerzy, gdzie demony wybierają cel między nimi;
- render tej samej sceny z drugiego widza daje pozę liczoną względem niego;
- unik idealny działa dla rycerza będącego celem.

Wykonano (2026-10-26):
- `content/factions.lua` (strony, wrogość, środki: blow, missile, hazard,
  blast; wybuch rani każde ciało w zasięgu), `faction` w definicji
  stworzenia (sprawdzana) i na ciele.
- `combat/bodies.lua`: pytania o każde ciało; `core/roles.lua`: jedyne
  miejsce, które nazywa sterowanego rycerza i widza.
- `enemies/target.lua`: `e.target`, strategia `move.targeting` (domyślnie
  najbliższe wrogie żywe ciało), odnawiana na zegarze wzroku, nigdy w trakcie
  zaangażowanego ataku. Zmysły (`Rules.sees`), style ruchu, unik, zamach,
  limit atakujących i tempo ataków liczą się per cel.
- Ataki (wypad, szarża, skok, piorun, kałuża, wachlarz, pocisk), kontakt
  wręcz i kontakt ciał, zagrożenia, pociski, wybuch i efekty trwające
  rozstrzygają się na ciałach, które ich strona rani. Jedna droga obrażeń
  `Outcomes.body` (`g:damageBody`); `KnightHit`/`KnightFell` dla rycerza
  innego niż sterowany.
- Wszyscy rycerze regenerują się; migawka kroku obejmuje każdego; unik
  idealny i powidok należą do rycerza, który się uchylił.
- Poza, klatki tyłem i billboard zwracają się do widza.
- Zapadka `KNIGHT AS THE ONLY TARGET`: 153 → 1 (utworzenie rycerza).
  Każde inne odwołanie do sterowanego rycerza mówi to wprost
  (`Roles.controlled`).
- Złoty wzorzec v2 bit w bit; zestaw `factions` (15 prób tylko z danych:
  domyślne relacje 0.32, sojusznik, kałuża demonów na sojuszniku i demonie,
  renegat, wieżyczka, dwóch rycerzy z upadkiem jednego, unik drugiego
  rycerza, drugi widz, nieznana strona odrzucona). Bramki: 4011 sprawdzeń.
- Pomiar (qa_crowd): krok 0,48 / 2,30 / 14,90 ms dla 96 / 256 / 512 ciał
  (V1: 0,47 / 1,59 / 17,83; w granicach rozrzutu), pociski rycerza
  0,34 ms na krok przy 96 ciałach (V1 0,29; sprawdzanie stron i rycerzy).
- Granica jawna: rycerze inni niż sterowany podlegają już wszystkim regułom
  walki, ale nie mają własnego sterowania (wejście, broń w ręku, kamera).
  To zakres decyzji o grze wieloosobowej, nie reguł świata.

### V3 — przestrzeń w skali (B3)

- Mapa prostokątna (`width`/`height`) z sektorami (np. 16×16 komórek).
- Indeks przestrzenny ciał (siatka mieszająca aktualizowana w kroku);
  zapytania promień/pas/stożek dla separacji, kontaktów, strzałów, wybuchów
  i zmysłów.
- Nawigacja: pola przepływu w obrębie sektora i graf przejść między
  sektorami, cache LRU z limitem pamięci. Klasy prześwitu według promienia
  ciała. Obecne demony mają klasę dzisiejszą (bez zmiany dróg), duże ciało
  dostaje swoją.
- Warstwy podłogi: komórka może mieć więcej niż jedną powierzchnię
  z sufitem (most nad pomieszczeniem). Ruch, lądowanie, wzrok, strzał,
  pocisk, nawigacja i renderer korzystają z warstw. Mapa jednowarstwowa
  zachowuje dzisiejsze liczby.
- Oświetlenie: dowolna liczba świateł mapy. W klatce wybór N najbliższych
  widocznych dla kamery; atlas widoczności per sektor. Żadne światło nie
  ginie po cichu (raport przekroczenia budżetu).
- Grupowanie rysowania sprite'ów tego samego atlasu (mniej wywołań).

Odbiór:
- obecny poligon: złoty wzorzec, rendery i drogi demonów bez zmian;
- mapa testowa 256×128 z mostem i 200 kagankami: ruch, strzał przez
  i pod mostem, nawigacja na obu poziomach, wszystkie kaganki w pobliżu
  kamery świecą;
- zapytanie drogi na mapie 256×256 bez BFS całej mapy (licznik odwiedzonych
  komórek w teście);
- koszt kroku dla 20/96/256/512 ciał rośnie liniowo (wykładnik dopasowania
  ≤ 1,2);
- wywołania rysowania przy 96 demonach mniejsze niż przy 20 w 0.32
  (diagnostyka).

Wykonano (2026-10-26):
- Mapa to prostokąt `width` × `depth` (`physics/grid.lua`); ciała w indeksie
  przestrzennym (`physics/spatial.lua`) dla separacji i promieni strzałów,
  z dowodem równości bit w bit z przejściem po wszystkich parach.
- Nawigacja: pole odległości w oknie 32 komórek wokół celu, klasy
  prześwitu (promień; przy płytach także wysokość), LRU; dalej regiony
  sektorów 16 × 16 z łączami (`world/navigation.lua`). Zapytanie drogi na
  mapie 256 × 256 odwiedza 1948 z 65 536 komórek.
- Warstwy podłogi: płyty (`decks`) nad podłogą komórki; ciało pamięta
  swoją powierzchnię (`o.level`). Ruch, lądowanie, sufit skoku, wzrok,
  strzał, pocisk, ładunek, nawigacja (węzły komórka + poziom) i renderer
  (siatka płyt, płyta zasłania światło) korzystają z warstw. Sprzeczności
  z rendererem 2.5D nie było: geometria jest prawdziwie 3D, a 2.5D atlas
  świateł uzupełnia jedna próbka płyty na piksel.
- Światła: dowolna liczba, 14 miejsc dla najbliższych kamerze (stałe
  miejsce, wygaszanie, raport `lights.report`); okno 32 komórek na światło
  dla dużych map. Ciała jednego obrazu, ich cienie i plamy pod nimi to po
  jednym wywołaniu instancyjnym.
- Odbiór:

  | Warunek | Wynik |
  |---|---|
  | złoty wzorzec, rendery, drogi demonów | 6 skrótów bez zmian; 596 obrazów showcase/GUI identycznych piksel w piksel; testy dróg bez zmian |
  | mapa 256 × 128 z mostem i 200 kagankami (`qa_bridge`) | test `floor-layers` (16): ruch po moście i pod nim, upadek z krawędzi, wysoki stwór zatrzymany, sufit skoku, strzał wzdłuż mostu i pod nim, spód/góra płyty, ładunek na płycie, pola na obu poziomach, demon wchodzi po schodach do rycerza na moście, wszystkie kaganki przy kamerze świecą, płyta zasłania światło |
  | zapytanie drogi 256 × 256 bez BFS całej mapy | 1948 odwiedzonych węzłów z 65 536 |
  | koszt kroku 20/96/256/512 | 0,145 / 0,451 / 0,974 / 2,848 ms; wykładnik dopasowania 0,88 |
  | wywołania rysowania przy 96 demonach < 0.32 przy 20 | 137,6 < 182,9 (512: 158,4) |

  Odcinek 256 → 512 ma wykładnik 1,55: w stałej sali 72 × 72 gęstość tłumu
  rośnie z liczbą ciał, więc rośnie też liczba sąsiadów w separacji
  (0,18 → 0,87 ms). To koszt gęstości, nie algorytmu; krok przy 512
  ciałach spadł z 16,2 do 2,85 ms. Update klatki aplikacji: 0,44 / 1,67 /
  5,36 / 11,67 ms (0.32: 0,40 / 2,26 / 11,67 / 40,13). Raporty i zrzuty
  mostu w `work/v10-v3-measure` (poza gitem).

### V4 — zapis jako dane ze schematem (B5)

- Zapis to drzewo danych przez `core/serialize` i literalny `core/data_reader`
  (bez wykonywania kodu), z sumą kontrolną i zapisem atomowym (plik
  tymczasowy + zamiana, jedna kopia poprzednia).
- Sekcje deklarują ich właściciele (jak `session/fields.lua`): nazwa, wersja,
  schemat, `pack`/`unpack`. Migracje to uporządkowana lista funkcji.
- Format sekcyjny zapisuje stan V1–V3 (pule, strony, mapa) bez kodu
  w rdzeniu zapisu.
- SIGIL06/07/08 czytane adapterem do nowego formatu; zapis tylko w nowym.

Odbiór:
- wszystkie dotychczasowe zapisy z testów wczytują się identycznie (porównanie
  stanu);
- test właściwości: zapis → odczyt = ten sam stan dla losowych stanów;
- uszkodzony, obcięty lub z obcą wersją plik jest odrzucany bez częściowego
  stanu;
- próba: nowa sekcja (np. flagi bazy) dodana samą deklaracją, bez zmian
  w rdzeniu zapisu;
- przerwanie zapisu w połowie nie niszczy poprzedniego.

Wykonano (2026-10-26):
- Rdzeń `storage/save.lua` (bez wiedzy o sekcjach): plik SIGIL09 z rodzajem,
  numerem, sumą kontrolną i drzewem `{ sekcja = { version, data } }`;
  odczyt literalny, sprawdzenie schematu, migracje kolejnymi funkcjami,
  odrzucenie całego pliku przed przywróceniem; zapis przez plik obok,
  zamianę i zachowaną poprzednią kopię.
- Sekcje u właścicieli: `run` (checkpoint wyprawy, `storage/run_save.lua`),
  `map` (`world/arena.lua`), `pools` (`session/world.lua`: członkowie pul,
  ich strony, odwołania do definicji jako ścieżki `core/data_tree.lua`,
  wspólne tabele raz, sterowany rycerz, następne id). Zapis sesji:
  `storage/session_save.lua`.
- SIGIL06/07/08 czyta adapter; gra zapisuje tylko SIGIL09. Koder SIGIL08
  w wersji 0.32 został w `tests/support/legacy_save.lua` dla testów migracji.
- Odbiór (test `save-format`, 11): 30 checkpointów SIGIL08 czyta się jak
  dotąd i równo z bliźniakiem SIGIL09; 40 losowych checkpointów i 8 losowych
  sesji (pule, strony, mapa) wraca bit w bit, definicje i wspólne tabele
  zachowują tożsamość; plik uszkodzony, obcięty, obcej wersji, nowszej
  sekcji, z nieznaną sekcją, z wartością spoza schematu, z kodem Lua albo
  innego rodzaju jest odrzucany, a sesja zostaje nietknięta; sekcja próbna
  dodana samą deklaracją zapisuje się, czyta (ze stanem domyślnym dla
  starszego pliku) i migruje; zapis przerwany przed zamianą i w jej trakcie
  zostawia pełny zapis. Złoty wzorzec i 596 renderów bez zmian.

### V5 — nagrywanie dużych walk (B7)

- Obserwacja strzału zapisuje tylko ciała w korytarzu tego strzału:
  stożek rozrzutu broni × zasięg plus promień ciała, z indeksu V3. Pełna
  lista nie jest potrzebna, bo resolver nie trafia ciał spoza korytarza.
- Geometria ciała niezmieniona od poprzedniej obserwacji to odwołanie
  (delta), nie kopia.
- Dziennik v4; v3 nadal odtwarzany (albo jawnie odrzucony z konwerterem,
  jeśli odtwarzanie jest niemożliwe).

Odbiór:
- 96 ciał, ten sam przebieg co w 0.32: przyrost tekstu ≤ 15% dzisiejszych
  2,43 MB/s, odtworzenie bit w bit;
- 64 MiB starcza na co najmniej 10 minut tej walki;
- test negatywny: ciało spoza korytarza nie może zostać trafione przez
  odtworzony strzał;
- istniejące dzienniki z testów odtwarzają się.

Wykonano (2026-10-26):
- Komenda strzału (`Observation.command`) niesie tylko ciała korytarza:
  stożek rozrzutu każdej noszonej broni (wzór śrutu × rozrzut × najszerszy
  glif) z zasięgiem, sfera ograniczająca ciała; resolver poza nim niczego
  nie trafia (porównanie z pełną obserwacją w 12 scenach).
- Dziennik v4: obserwacja, której żaden strzał nie użył, zostaje samym
  nagłówkiem (o jej losie decyduje tylko ważność); ciała wchodzą, gdy
  strzał ich użyje (zdarzenie `ObservationUsed`). Ciało niezmienione od
  poprzedniego wpisu to odwołanie, zmienione — różnica pól. v3 i v2
  nadal odtwarzane.
- Limit komend nagrania liczy 10 minut aktualizacji (120/s) i celowania
  w każdej klatce do 240/s (216 000), bo samo celowanie myszą kończyło
  nagranie po 6,6 min mimo zapasu tekstu.
- Odbiór:

  | Warunek | Wynik |
  |---|---|
  | 96 ciał, przebieg 0.32: przyrost ≤ 15% z 2,43 MB/s | 70,4 KB/s (2,9%); 58 kontaktów jak w 0.32; odtworzenie zweryfikowane |
  | 64 MiB na ≥ 10 min tej walki | 10 min nagrane naprawdę: 29,6 MB, bez zatrzymania, odtworzenie zweryfikowane (zapas ≈ 23 min przy 10-sekundowym tempie) |
  | ciało spoza korytarza nie trafione | test `fight-recording`: nie ma go w komendzie, odtworzony strzał go nie trafia, żaden promień żadnej broni nie sięga poza korytarz |
  | istniejące dzienniki odtwarzają się | testy replay/headless/journal values; dziennik v3 z tej samej walki odtwarza się |

  Raporty w `work/v10-v5-measure` (poza gitem).

### V6 — otwarta prezentacja (B6)

- Renderer dzielony według przejść na moduły. Obiekty świata (pieczęć,
  żar, portal, zapasy, dekoracje, nowe rodzaje) rejestrują swoje rysowanie
  według komponentu lub rodzaju, jak `AttackDebug.register`. Renderer nie
  zna ich nazw.
- HUD budowany z deklaracji slotów: N broni, wszystkie sloty wyposażenia
  (Q, F, C i kolejne). Dla obecnej zawartości układ 0.30 jest identyczny.
- Wszystkie teksty dla gracza przez `content/text` z identyfikatorami
  i parametrami (także komunikaty trybów). Napisy malowane: rejestr
  z zastępczym napisem glifami, gdy brak obrazu.
- Ekrany i HUD pytają tryb o dane (`Modes`/`run/queries`), nie czytają
  `g.run`/`g.testField`.
- `run/test_field.lua` i `enemies/actions.lua` podzielone według
  odpowiedzialności.

Odbiór:
- rendery showcase i GUI audit identyczne piksel w piksel; 0 problemów
  układu;
- zapadki: literały tekstu dla gracza = 0, `g.run`/`g.testField` poza
  trybem = 0;
- próby: nowy rodzaj obiektu świata narysowany samą rejestracją; HUD
  z 4 broniami i 3 slotami wyposażenia czytelny w audycie;
- zmiana języka tabeli tekstów zmienia wszystkie napisy bez zmian kodu.

Wykonano (2026-10-26):
- Renderer: klatka to lista ośmiu przejść w `render/passes/` (architecture,
  projectiles, ground, enemy_marks, hazards, ash, sprites, effects).
  Obiekty świata rejestrują rysowanie w `render/world_objects.lua`
  (`register(rodzaj, { { pass, order, draw }..., init, overlay, release })`).
  Wbudowane rodzaje są w `render/world_art.lua`: kaganek, pieczęć, zapasy,
  Żar, freski, echo, brama, wyjście, sekret, rekwizyt i galeria. Renderer
  i przejścia nie znają ich nazw; test to sprawdza w źródle.
- HUD z deklaracji slotów (`ui/hud_slots.lua`). Arsenał pokazuje N broni
  w dwóch wierszach wokół broni w ręku. Wyposażenie obejmuje każdy slot
  z klawiszem z `app/bindings` (Q, F, C): jeden przedmiot w pełnym układzie
  0.30, kilka po wierszu (klawisz, tag, użycia). To samo w HUD areny classic.
- Teksty: `content/text.lua` ma 523 klucze (wcześniej 33) z parametrami.
  Klucze niosą definicje broni, stworzeń, wyposażenia, ofert, kręgów, stref,
  pieczęci, stanowisk, archiwum, galerii i fal; broń i wyposażenie
  sprawdzają klucze przy definicji. Komunikaty trybów (wyprawa, ekonomia,
  poligon, classic, interakcje, nawigacja) są kluczami. Języki:
  `Text.language(nazwa, szablony, malunki)` + `Text.use`. Napisy malowane
  mają rejestr (`painted_titles.names`, `has`); gdy brak malunku w atlasie
  albo język nie ma własnych malunków, `Skin.inscription` pisze glifami.
- Ekrany i HUD pytają tryb przez `run/queries` (`run`, `field`, `world`,
  `tools`, `objective`). Widoki buduje tryb z własnego rekordu
  (`run/mode_views.lua`); `Capabilities.posed` zastąpiło `g.testField`
  w animacji.
- `run/test_field.lua` (630 → 274 wierszy): cykl życia, komunikaty i akcje.
  Odrębne moduły: `run/field/placement.lua` (cele i wezwania),
  `visits.lua` (pieczęć, sklep), `trials.lua` (strzelnica, fizyka, próba
  fal). Liczby poligonu są w `content/field.lua`. `enemies/actions.lua`
  (599 → 216): wybór, zobowiązanie, wyzwolenie i stan uderzenia. Rodzaje
  ataków są w `melee_kinds.lua` / `ranged_kinds.lua`, wspólny kontakt
  w `attack_contact.lua`, lot ciała w `flight.lua`.
- Odbiór:

  | Warunek | Wynik |
  |---|---|
  | showcase i GUI audit piksel w piksel, 0 problemów układu | 596/596 obrazów identycznych z bazą sprzed V6; GUI audit 270 scen, 0 problemów |
  | zapadki: teksty dla gracza = 0, `g.run`/`g.testField` poza trybem = 0 | player-text 340 → 0 (44 pliki), mode-records 57 → 0 (19 plików); bazy w tools/check są puste |
  | nowy rodzaj obiektu świata samą rejestracją | test `open-presentation`: rodzaj `trial_obelisk` zarejestrowany w teście zmienia 954 próbki klatki, po wyrejestrowaniu znika |
  | HUD z 4 broniami i 3 slotami czytelny w audycie | 10 audytów (5 rozdzielczości × broń 4 i broń 2), 0 problemów; obrazy `hud-slots-*` |
  | zmiana języka zmienia wszystkie napisy bez zmian kodu | pseudojęzyk znaczy każdy szablon; 29 ekranów i etykiety galerii, 875 napisów, wszystkie znaczone; napisy malowane piszą się glifami |

### V7 — potok treści dla nowych demonów (B4)

- Rejestracja atlasu z jednego pliku danych arkusza (komórki, stopy,
  kotwice, kolejność) generowanego narzędziem; `enemy_frames.lua` staje się
  wynikiem, nie ręcznym źródłem.
- Narzędzie anatomii z dwiema drogami:
  - edytor regionów na klatce, uruchamiany w LÖVE jako narzędzie, który
    eksportuje adnotację,
  - generacja regionów z warstw części namalowanych w źródle (maska
    na część).
  Obie kończą się istniejącym bake masek RLE związanym ze źródłem.
- Jedno polecenie sprawdzające demona (np. `CHECK-CREATURE.ps1 <id>`)
  wypisuje każdy brakujący element: atlas, klatki, anatomia, maski, punkty,
  galerię, bestiariusz, fale.

Odbiór:
- obecne demony wyeksportowane narzędziem dają te same adnotacje i bit
  w bit te same maski; testy anatomy-data i hit-landmarks przechodzą;
- próba: demon testowy z nowym atlasem dodany samymi danymi i wynikami
  narzędzi, bez zmian w kodzie gry;
- opis kroków i zmierzony czas pracy w DEVELOPMENT.

## Kolejność i zależności

V0 → V1 → V2 → V3 → V4 → V5 → V6 → V7

- V2 potrzebuje encji i id z V1.
- V3 korzysta z encji (indeks ciał) i domyka separację z V1.
- V4 zapisuje stan wprowadzony przez V1–V3.
- V5 potrzebuje zapytania korytarza z V3.
- V6 rysuje obiekty i strony z V1–V2.
- V7 jest niezależny od kodu walki, ale zamyka plan, bo jego próba korzysta
  z V2 (strony) i V6 (rejestr rysowania, HUD, teksty).

Po każdym etapie: commit z dowodami (bramki, złoty wzorzec, pomiary) i wpis
w sekcji ZMIANY-0.33.txt.

## Co plan świadomie zmienia w dotychczasowych dokumentach

ARCHITEKTURA.txt, sekcja 13 („Świadome granice”), traci punkty: jeden widz,
jedna podłoga na x/z, pętle po tablicach i HUD bez wielu slotów. Zastępują
je kontrakty z V2, V3 i V6. Zostaje: sprite jako billboard z maską
w płaszczyźnie i krok 1/120 s z opisanymi błędami O(dt).

## Ryzyka

- V2 i V3 dotykają rdzenia walki. Złoty wzorzec i skróty kontaktów są
  głównym zabezpieczeniem; każdy podetap ma osobny commit.
- Warstwy podłogi (V3) to największa zmiana modelu przestrzeni. Jeśli próba
  mostu wykaże sprzeczność z rendererem 2.5D, etap staje i wraca do
  użytkownika z pomiarem i propozycją, zamiast obniżać kryterium.
- Edytor anatomii (V7) to praca narzędziowa; jego wynik musi się zgadzać
  z dzisiejszymi danymi bit w bit, zanim zastąpi ręczne źródła.
