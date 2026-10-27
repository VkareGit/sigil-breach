# Plan v11, etap E5: kontekst prezentacji i wejście aktorów

## Zakres

Kontekst rozdziela aktora (HUD, ręce, portret, odrzut) i widza (kamera,
billboardy, światła, słuchacz). Dla zwykłego jednego gracza `Context.of`
zwraca samą sesję. Rozgrywka, balans, grafiki i układ HUD-u pozostają bez
zmian. Stary HUD trybu `classic` występuje w próbie technicznej; nie został
podstawiony pod HUD poligonu ani dodany do menu.

## Własność i czas życia

- `Fields.declareView(owner, names, scope)` określa zakres: świat, aktor lub
  widok. Świat przechowuje pojedynczy zbiór cząstek, plam, śladów i liczb.
  Łuski są osobiste, ponieważ animowane są w przestrzeni ekranu.
- `Context.watch(g, id)` tworzy osobisty stan tylko obserwowanego rycerza.
  Nieobserwowani nie otrzymują pełnego widoku. `unwatch` zwalnia jego stan
  i zależne kamery. `Context.view` tylko odczytuje istniejący stan.
- `Context.of(g, actor, viewer)` nie zastępuje kontrolowanego rycerza.
  Błędne ID jest odrzucane. Oddzielna kamera zachowuje tożsamość podczas
  używania; `unobserve(g, actor, viewer)` zamyka ją i usuwa jej historię.
- Osobne kamery tego samego rycerza mają oddzielną historię interpolacji.
  `P.capture` zbiera pozycje świata raz, `P.sample` interpoluje wszystkich
  rycerzy i ustawia jawnego aktora oraz widza; bieżący kierunek celowania
  pozostaje bez opóźnienia.
- Inicjalizacja osobista należy do `session/view_state.lua`, niezależnego
  od ruchu i kontekstu. Zmiana sterowania czyści stare widoki, ustawienie
  ruchu kamery czyści również obserwowane widoki i historie kamer.
- Śmierć dodatkowego rycerza czyści widok także po odroczonym `KnightHit`
  w fazie prezentacji. Śmierć kontrolowanego zachowuje ekran 0.33 — jawny
  wyjątek zgodności, bez kasowania dotychczasowego efektu śmierci.

## Wejście, feedback i symulacja

`Input.new(actor, device)` przypisuje urządzenie. Intencja trafia do
`input.actors[id]`, obserwacja strzału do właściwego strzelca. Granica
publicznych komend przyjmuje ID, nigdy mutowalny obiekt aktora; zachowuje
to zapis i odtwarzanie dziennika. Domyślne urządzenie zachowuje dotychczasową
liczbę argumentów komend. Mysz dodatkowego, nieobserwowanego aktora działa
bez wymuszania powstania widoku. Interakcje trybu pozostają kontrolowane
przez główne wejście; split-screen nie jest opcją menu.

Zdarzenia wystrzału, salwy, przeładowania, wyposażenia i zranienia kierują
osobiste skutki do obserwowanego właściciela. Ślady świata powstają tylko
raz. Zegary łusek, zranienia, odrzutu i ruchu broni tykają osobno; dodatkowy
widok nie podwaja dźwięków kroków ani wspólnych efektów. Ruch i obrażenia
nie zależą od liczby widoków.

## Dodatkowa poprawka własności wykryta przy integracji

Próba zasobów E6 wykryła cykl `Queries.sessions -> view -> stamp -> session`.
Słabe klucze LuaJIT nie zwalniały tak utrzymywanych sesji. Stempel zawiera
teraz neutralny token właściciela, bez referencji zwrotnej do sesji.
Kontrakt ważności i ponownego użycia tabel pozostał ten sam. QA sprawdza
zarówno żywy cache, jak i zebranie właściciela przy zachowanym pożyczonym
widoku.

## Dowody

- `view-context`: 43 sprawdzenia, rzeczywiste dwa płótna, HUD, broń,
  odrzut/zranienie, wspólna krew, kamera, światła, audio, interpolacja,
  lifecycle, wejście i replay v5.
- `journal-values`: jawny replay v4 oraz zachowane próby v2/v5; v3 w
  `fight-recording`. Wynik odtwarzania porównywany przez Integrity.
- Zapadka `PRESENTATION ASSUMES ONE PLAYER`: 73 -> 0.
- Oryginalne referencje `tests/fixtures/v033/` nie były regenerowane.
- Szczegółowe wyniki bramek i porównania obrazów: raport końcowy E6.
- Pomiary E3–E5 i koszt dwóch widoków: `PLAN-v11-POMIARY.md`.

Funkcjonalny zakres E5 jest wdrożony. Odbiór wydajności według protokołu
pozostaje osobną decyzją opisaną w raporcie końcowym; ocena B2 należy do
człowieka.

Odbiór kodu przed podbiciem wersji: TEST.ps1 -Suite All, 4284 sprawdzenia
mechaniki i zasobów, 36 kontroli wejścia, 519 kompilowanych plików Lua,
0 naruszeń architektury; wszystkie narzędzia i startup-check przechodzą.
Sześć skrótów złotego wzorca i projekcje 0.33 pozostały bez zmian.
Rendery 606/606 identyczne z bazą. Raporty source-*.evidence.json potwierdzają
sourceStable. Rozszerzony resource-plateau i diagnostyczny view-measure
przeszły również z fingerprintem źródeł i runtime.

Po zbiorczym przebiegu dodano regresję ważności zapytań przy komendzie
w tym samym czasie: 43/43 view-context, architektura 0 oraz ponowny
resource-plateau PASS. Końcowe All wydania 0.34 obejmuje również tę zmianę.
