# Plan v11, etap E6: zgodność, zasoby i odbiór źródeł 0.34

Zakres techniczny E0–E6 jest wdrożony. Formalne zamknięcie punktu 7 planu
(wydajność) czeka na decyzję użytkownika o kryterium pomiaru. B2 pozostaje
oceną człowieka. Nie włączono nowych trybów ani split-screenu w menu.

## Co objęło wdrożenie

E5 (`e00c817`) rozdziela aktora HUD/rąk i widza kamery/audio, zakresy pól
prezentacji oraz historie interpolacji. Osobiste efekty dotyczą właściciela
zdarzenia, efekty świata powstają raz. Wejście wskazuje aktora, a dziennik
zapisuje jego ID. Próby obejmują rzeczywiste płótna i wejście aplikacji,
nie sam odczyt danych. Raport szczegółowy: `PLAN-v11-E5-RAPORT.md`.

Próby zgodności E6 i kontrola zasobów powstawały podczas integracji E5,
ponieważ sprawdzają ten sam cykl życia kontekstu. Są w tym samym commicie.
Końcowy commit E6 obejmuje numer wydania i dokumentację wyników; jego hash
podaje raport końcowy rozmowy, bez samoodwołania w zawartości commitu.

## Zapisy i dzienniki

- Pięć checkpointów SIGIL09 oraz okresowe/zdarzeniowe rzuty stanu,
  przypisanie leczenia i nagród, tabela póz: oryginalne
  `tests/fixtures/v033/` pozostały bez zmian.
- 15 wejść SIGIL06/07/08 i 15 oczekiwanych projekcji w
  `tests/fixtures/legacy-v033/` powstało przez kod E0 `710d1ac`, nie kod
  po refaktorze. Pochodzenie i SHA opisuje `PROVENANCE.txt`.
- Starszy format używał zaokrąglającego `tostring`. Dlatego porównanie
  dotyczy jego własnej projekcji wyliczonej przez E0, a nie dokładniejszego
  wyniku SIGIL09. Dla każdego: odczyt do stanu bazowego oraz zapis nowym
  formatem i ponowny odczyt bez zmiany tej projekcji.
- Dzienniki v2–v5 mają próby odtworzenia z Integrity. Próba v4 jest jawna
  w `journal-values`, v3 w `fight-recording`; v5 obejmuje też wejście
  dodatkowych aktorów. Wymóg zgodności wydania i fingerprintu nie został
  zniesiony; nie deklarujemy odtwarzania nagrań 0.33 w 0.34.

## Zasoby i poprawka wykryta przy integracji

`resource-plateau` wykonuje osiem cykli rzeczywistej aplikacji:
menu → poligon → drugi aktor i widok → nagranie/odtworzenie → wyprawa →
powrót do menu → zwolnienie renderera. Po każdym zwolnieniu liczby zasobów
wracają do 68 obrazów, 2 płócien i 383,786 MiB tekstur. Pierwotny renderer
aplikacji i wspólne UI pozostają celowo żywe; nie oczekujemy zera GPU.

Wykryty cykl: cache sesji → pożyczony widok → stempel → sesja. W LuaJIT
słabe klucze nie wystarczały do zwolnienia tak utrzymywanej sesji.
Stempel posiada teraz neutralny token, bez referencji do właściciela.
Test trzyma pożyczony wynik przy życiu, a sprawdza zebranie jego właściciela.

Konteksty i interpolowane próbki posiadają oddzielne tabele odpowiedzi,
ale wspólną rewizję komendy sesji. Komenda w tej samej chwili unieważnia
stare odpowiedzi wszystkich widoków; jawne kopie zachowują dane.

Normalne cykle działają z JIT. Końcowy pojedynczy `jit.flush` jest audytem
referencji utrzymywanych przez skompilowane domknięcia, wyłącznie w QA.
Nie ma wymuszania flush po każdym cyklu ani w produkcji. Raport podaje
osobno stertę Lua przed/po tym audycie oraz zachowane referencje; nie
ukrywa rozrzutu RAM sztucznym progiem. Po końcowym audycie nie pozostają
sesje, aplikacje, dzienniki ani prywatne widoki tych cykli.

## Weryfikacja końcowa

Wymagany odbiór wydania: `FORMAT.ps1`, `FORMAT.ps1 -Check`, następnie
`TEST.ps1 -Suite All -TestTimeoutSeconds 1800` i `--resource-plateau`.
Wszystkie procesy końcowego odbioru mają działać na jednym niezmienionym
drzewie. Zbiorczy dowód `work/v11-final-evidence.json` porównuje ich
fingerprinty i wymaga `sourceStable`, kodu wyjścia 0 oraz osobnego ID próby.
Szczegóły: `work/qa-v33/source-*.evidence.json` i `tool-smoke/`.

Zakres sprawdzeń końcowych: 4285 mechaniki/zasobów, 36 wejścia, 519
kompilowanych plików Lua i 0 naruszeń architektury. `view-context` ma 43
sprawdzenia. Złoty wzorzec pozostaje:

| Scenariusz | Stan / wynik | Kontakty / liczba |
|---|---|---|
| playtest | `07f73bfa / a9192235` | `aab9a46e / 299` |
| human | `fe26df14 / 563c8d0f` | `4be34edb / 671` |
| drill | `c13bcaec / f105ca06` | `663b77fc / 178` |

Zapadki v11 osiągnęły zero. W szczególności `PRESENTATION ASSUMES ONE
PLAYER` spadła z 73 do 0; osobne próby rozszerzeń dowodzą zachowania,
sam wynik wyszukiwania nie jest ich zastępstwem.

Przed zmianą numeru wydania porównanie obrazów: 606/606 identycznych
piksel w piksel (`work/v11-pixel-comparison.json`). Końcowe porównanie
0.34 znajduje się w `work/v11-release-pixel-comparison.json`; jedynym
dopuszczonym wyjątkiem jest numer wydania na stronie menu, ze wskazanym
prostokątem różnic, a nie wyłączenie całych obrazów menu z porównania.
Układ HUD-u, assety, rozgrywka i balans nie były przeprojektowane.
Starszy HUD `classic` występuje w QA — nie został dodany do menu produktu.

## Koszt i odbiór

Pełne mediany i IQR E3–E5 względem E0 oraz jednego/dwóch widoków:
`PLAN-v11-POMIARY.md`. Pięć naprzemiennych par na wariant, osobne procesy,
300 rozgrzewki, 2400 kroków, 720 klatek, High bez affinity. Pomiary dotyczą
commitu E5 przed podbiciem wersji; E6 zmienia metadane i dokumentację,
nie algorytmy mierzonego kodu.

Nie uznajemy dużego IQR za automatyczne zaliczenie ani za dowód regresji
spowodowanej refaktorem. Praktyczne kryterium mediana ≤1,05× albo różnica
w rozrzucie A/A wymaga decyzji użytkownika zgodnie z przekazaną instrukcją.
Wyniki nie zastępują B2: feelingu, czytelności i wydajności normalnej gry.

## Dokumenty i granice dostawy

Zaktualizowano ARCHITEKTURA, ROZSZERZANIE (przepisy 17–22), DEVELOPMENT,
ODBIOR-0.34 i ZMIANY-0.34 oraz status planu. Wersja źródeł to 0.34;
`qa-v33` pozostaje historyczną nazwą izolowanego katalogu QA. Odbiór
źródeł nie poświadcza nowej paczki ZIP/EXE — taka paczka wymaga BUILD.
Nie wykonano push. Nie zmieniono `docs/podrecznik-codex/`.

## Poprawki po przeglądzie (po `1ed58b6`)

Przegląd E5–E6 potwierdził próbami dwa błędy. Oba są naprawione, a każdy
ma test regresji w `view-context`, który bez poprawki pada:

- **Feedback zabójstwa z łańcucha bez rycerza.**
  - Objaw: `Recipient.actor` traktował id demona (właściciela ciosu
    demona lub jego pchnięcia) jak aktora. W grze jednoosobowej takie
    zabójstwo nie dawało napisu ani błysku złamania, choć 0.33 je dawało.
  - Poprawka: odbiorcę wyznacza teraz reguła `Stats.owner`.
- **Dziennik i drugie urządzenie.**
  - Objaw: buforowany spust, skok i zapomniane obserwacje urządzenia
    przypisanego do innego rycerza zmieniały jego pola poza komendami
    i dziennikiem. Odtworzenie takiego przebiegu się rozjeżdżało.
  - Poprawka: wpis `actorSet` (`Journal.actorExternal`) zapisuje te pola
    tak, jak `set` zapisuje pola sterowanego. Sterowany dostaje dodatkowo
    ścieżkę `player.observationGeneration`.
  - Starsze dzienniki odtwarzają się bez zmian.

## Interpretacja końcowa i decyzja użytkownika

Powtórzenia nie zastępują pierwszych serii: zestawienia n=10 zawierają
wszystkie próbki. Poniższa tabela pokazuje wartości po powtórzeniach,
a dla niepowtarzanego rdzenia E5 nadal n=5. Nie oznacza przyjęcia
nowego kryterium odbioru ani zgody użytkownika na odstępstwo.

| Zakres | Po/przed | Różnica median ms | Suma IQR A/A ms | Ścisły wynik |
|---|---:|---:|---:|---|
| E4 krok 20, n=10 | 1.016 | +0.0019 | 0.0105 | nierozstrzygnięty |
| E5 complete_normal4_frozen_fx, n=10 | 1.029 | +0.1158 | 0.2209 | nierozstrzygnięty |
| E5 complete_heavy20_frozen_fx, n=10 | 1.016 | +0.0836 | 0.5188 | brak regresji |
| E5 prepared_population_20_live, n=10 | 1.063 | +0.3856 | 0.6357 | nierozstrzygnięty |
| E5 prepared_population_96_live, n=10 | 1.067 | +0.7673 | 2.6384 | nierozstrzygnięty |
| E5 prepared_population_256_live, n=10 | 1.044 | +0.8958 | 3.8350 | nierozstrzygnięty |
| E5 step 20 bodies (ms), n=5 | 1.054 | +0.0063 | 0.0105 | nierozstrzygnięty |
| E5 step 256 bodies (ms), n=5 | 0.960 | -0.0954 | 0.4805 | nierozstrzygnięty |
| E5 step 96 bodies (ms), n=5 | 0.967 | -0.0191 | 0.0654 | nierozstrzygnięty |

A/A: `work/v11-measure/aa/summary.txt`, ten sam kod E0 po obu stronach.
Suma obu IQR jest tu jawną, proponowaną interpretacją rozrzutu A/A
dla tej samej metryki, nie potwierdzoną granicą regresji ani formalnie
zaakceptowanym progiem. Wartości ujemne różnicy oznaczają krótszy czas.

Zgodnie z przekazaną instrukcją decyzja należy do użytkownika:
czy przyjąć kryterium praktyczne: mediana po <= 1,05x mediany przed,
albo dodatnia różnica median nie większa niż suma IQR obu wariantów A/A?
Do czasu decyzji punkt 7 pozostaje otwarty. Duży IQR, także przy
mediana <= 1,05x, nie daje PASS według pierwotnego protokołu.
B2 (feeling, czytelność, płynność podczas zwykłej gry) również pozostaje
do oceny człowieka. Próba dwóch widoków nie jest funkcją w menu.
