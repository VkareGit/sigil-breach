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
