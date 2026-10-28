# Punkt 1 — diagnoza czasu klatki z 20 demonami

## Aktualizacja 28.10 — usunięcie alokacji z testu przesunięcia

Profiler LuaJIT na 2400 pełnych klatkach wskazał zbieranie pamięci przy
tworzeniu zamknięcia `collision.cast` jako jeden z powtarzalnych kosztów.
Każdy sweep tworzył funkcję i przechwycone zmienne, także na pustej podłodze.
Akumulator kontaktu jest teraz funkcją operującą na skalarach. Nie ma wspólnego
mutowalnego bufora; kolejność kandydatów, tolerancje i wzory pozostały takie same.

Kontrola na identycznej treści: wszystkie sześć digestów golden (stany i kontakty)
jest identycznych. Dowód: `work/closure-28/physics-golden/`.
Pięć naprzemiennych par na tej samej treści, 300 kroków rozgrzewki:

| Miara | Przed, mediana | Po, mediana | Ocena |
|---|---:|---:|---|
| Krok symulacji, 20 ciał | 0,2038 ms | 0,1123 ms | Obserwowana redukcja 44,9%; IQR 5,4%/11,1% |
| Pełna klatka, 20 żywych | 8,8125 ms | 9,6226 ms | Nierozstrzygnięte, IQR 18,9%/18,0% |
| Nieruchoma ciężka scena | 5,5783 ms | 5,9282 ms | Nierozstrzygnięte |
| Nieruchoma lekka scena | 4,1284 ms | 4,0417 ms | Nierozstrzygnięte |

Surowe wyniki: `work/closure-28/measure/summary.txt`; diagnostyczny profil:
`work/closure-28/profile-before/profile.txt`. Profil z próbkowaniem nie jest
pomiarem akceptacyjnym. Pary mierzyły odrębne, zamrożone kopie; późniejsze
strojenie demonów nie dostało się do tego porównania. Zysk kroku CPU nie
upoważnia do deklarowania poprawy całej klatki ani zamknięcia starej bramki E0.

Opis pierwotnego pomiaru i poprzednich prac poniżej zachowuje historię.

Stan: 27 października 2026. Wdrożono instrumentację QA, wykonano porównanie trzech wersji i kontrolowaną próbę wpływu GC. Nie zmieniono renderowania, HUD, zasobów ani ustawień odśmiecania w grze. **Wcześniejszy formalny wynik +13,2% względem E0 pozostaje otwarty. Ten raport nie uznaje go za naprawiony.**

## Co było wiadomo przed tą pracą

Zachowany pełny pomiar `work/v11-close-final/perf/` obejmował pięć naprzemiennych par E0 i źródeł po domknięciu v11, przed ich commitem. `run.json` zawiera commit rodzica oraz skróty faktycznie zmierzonych źródeł — sam `AfterCommit` nie oznacza czystego drzewa tego commita. Stabilność źródeł w tamtym przebiegu jest potwierdzona.

W scenie `prepared_population_20_live` mediana median wyniosła 6,1360 → 6,9475 ms, czyli +13,2%. Ten wynik porównuje **cały v11 z E0**, nie koszt ostatniej poprawki. W tamtych pięciu przebiegach:

| Faza | E0: mediana median [ms] | Źródła po domknięciu [ms] |
|---|---:|---:|
| update | 0,8144 | 0,9748 |
| world, łącznie z interpolacją | 1,3074 | 1,6435 |
| UI, łącznie z obserwacją strzału | 1,0501 | 1,3046 |
| readback | 2,8235 | 2,8609 |

Wzrost median jest widoczny przede wszystkim przed synchronizującym odczytem obrazu. Nie przesądza to, ile przypada na Lua, sterownik czy GC. Niezależnie posortowane listy faz nie pozwalają ustalić, co wydarzyło się w **tej samej** wolnej klatce. Nie wolno również dodawać median osobnych faz, aby odtworzyć medianę całkowitą.

## Wdrożona instrumentacja

- `game/qa/benchmark.lua`: `SIGIL_BENCH_RAW=1` zapisuje chronologiczne CSV **przed** sortowaniem do percentyli. Istniejące pomiary i workload domyślny zostają zachowane.
- `SIGIL_BENCH_PHASE_DETAIL=1`: dodatkowe znaczniki wydzielają `Presentation.sample`, sam HUD, `Input:present` i końcowy flush z dotychczasowych faz world/UI. Sama obecność dodatkowych zegarów oznacza, że jest to instrumentowany przebieg diagnostyczny.
- `SIGIL_BENCH_HEAP=1`: zapisuje wielkość sterty Lua przed/po klatce. Odczyty sterty i zapis wyników są poza mierzonym przedziałem. Spadek sterty oznacza odzyskanie pamięci; jego brak nie dowodzi, że GC nic nie zrobił.
- `game/qa/frame_samples.lua`: wspólny zapis `frames-<scena>.csv`, kontrola zgodności długości i skończonych wartości. Zapis nie sortuje ani nie zmienia tablic pomiarów.
- `game/tests/cases/qa_tools.lua`: regresja sprawdza dwa wiersze o przeciwnie uporządkowanych kosztach update/readback, zachowanie kolejności i odrzucanie niepełnej serii. Suity `qa-tools`: **30 sprawdzeń PASS**.

Podstawowe kolumny to `frame, update_ms, world_ms, ui_ms, submit_ms, readback_ms, total_ms`. Dodatkowe: `sample_ms, hud_ms, observation_ms, flush_ms, heapBefore_KiB, heapAfter_KiB`. `sample_ms` należy do `world_ms`; trzy kolejne podfazy należą do `ui_ms`. Nie należy dodawać ich drugi raz do total.

W normalnej grze nie działają te sondy. Przy wyłączonych zmiennych benchmark nie wykonuje dodatkowych zegarów ani odczytów sterty i nie tworzy CSV.

## Porównanie E0 / przed domknięciem / po domknięciu

Izolowane kopie w `work/punkt-1-perf/`:

| Nazwa | Commit | Znaczenie |
|---|---|---|
| e0 | `710d1ac` | Początek pomiarów v11 |
| pre | `6ffb306` | Czysty stan przed ostatnim domknięciem audytu |
| current | `386b82a` | Stan rozpoczynający bieżący punkt 1 |

Wszystkie trzy dostały identyczny plik diagnostycznego benchmarku i serializator CSV. Zasoby między tymi commitami nie różnią się; kopie czytają wspólny katalog zasobów. Skróty każdego mierzonego pliku `src/` i `qa/` są w `focused/run.json`; ponowna kontrola w `focused/source-after.json` wykazała **Stable=true**.

Protokół diagnostyczny: pięć świeżych procesów na wersję, kolejność rotowana między trzema wersjami; High priority, bez zmiany affinity; 1280×720, scena wysokości 450, Intel Arc iGPU, OpenGL, VSync 0; 20 demonów z rzeczywistej fabryki na `qa_crowd`; 300 klatek rozgrzewki i 720 pełnych klatek pomiaru. Audio aktualizuje się przy wyciszonym wyjściu. W czasie pomiarów pozostali agenci nie uruchamiali gry/testów.

**Różnica wobec formalnego `MEASURE.ps1`:** pominięto wcześniejsze workloady legacy, frozen i lifecycle. Przygotowana scena i pojedyncza klatka są takie same, ale historia rozgrzewki, JIT, alokacji i sterownika jest inna. To ukierunkowana diagnoza, nie ponowne przejście formalnego kryterium. Testy bieżących poprawek kontaktu/resetu nie są częścią tych trzech historycznych kopii.

| Wersja | Mediana median total [ms] | IQR median [ms] | Najwyższe p95 w przebiegu [ms] | Najwyższe p99 [ms] | Najgorsza klatka [ms] |
|---|---:|---:|---:|---:|---:|
| E0 | 6,5556 | 0,7302 | 13,1212 | 16,4801 | 26,2261 |
| przed domknięciem | 7,4546 | 0,6955 | 15,9184 | 18,8682 | 29,3891 |
| po domknięciu | 6,8575 | 1,0857 | 14,9123 | 19,2081 | 25,4472 |

Current/E0 to około +4,6%, lecz duży rozrzut nie daje podstaw do ogłoszenia wygranej ani przypisania poprawy konkretnej zmianie. Wynik ukierunkowany nie unieważnia poprzedniego formalnego +13,2%. Percentyle tej tabeli policzono interpolacją liniową w skrypcie analizy; oryginalny log benchmarku zachowuje dotychczasowy wybór próbki przez `ceil(n*p)`, dlatego ostatnie cyfry mogą się różnić.

Rozbicie bieżącej wersji, mediana median:

| Faza | ms |
|---|---:|
| update — dwa kroki symulacji i capture w klatce 1/60 s | 0,9631 |
| world razem | 1,5476 |
| w tym `Presentation.sample` | 0,0326 |
| UI razem | 1,3746 |
| w tym sam HUD | 1,0970 |
| w tym `Input:present` / obserwacja strzału | 0,2146 |
| w tym końcowy flush | 0,0054 |
| synchronizujący readback | 2,8648 |

To nie uzasadnia dużego refaktoru interpolacji: jej próbka kosztuje zwykle setne części milisekundy. Nie oznacza to, że `Presentation.capture` w update jest darmowe; nie było osobnym miernikiem w tej próbie. HUD jest istotnym kosztem, ale badanie samego czasu fazy nie identyfikuje jeszcze kosztownej funkcji i nie upoważnia do zmiany wyglądu.

Przykład prawdziwie sparowanych danych: `current-4`, klatka 500, total **25,4472 ms** = update 8,3430 + world 6,3542 + UI 6,0709 + readback 4,6791 ms. W tej klatce sterta spadła o około 985 KiB. Natomiast `current-1`, klatka 220, trwała **25,0390 ms**, a sterta wzrosła o około 472 KiB. Same spadki sterty nie wyjaśniają wszystkich skoków. W E0 wystąpiła też klatka z samym readback 22,8166 ms — nie można każdego skoku przypisać nowemu kodowi Lua.

## Kontrolowany eksperyment z GC

Trzy naprzemienne pary na **tym samym `386b82a`**, takie same ustawienia przygotowanej sceny. Oba warianty wykonują pełne collect po 300 klatkach rozgrzewki, przed pomiarem. Jeden zachowuje działający GC, drugi zatrzymuje go wyłącznie na 720 zmierzonych klatek i następnie przywraca. Zmiana znajduje się tylko w kopiach `work/punkt-1-perf/gc-on` i `gc-off`; nie trafiła do gry.

| Wariant | Mediana median total [ms] | IQR [ms] | Najwyższe p95 [ms] | Najwyższe p99 [ms] | Najgorsza klatka [ms] | Maksymalna sterta Lua |
|---|---:|---:|---:|---:|---:|---:|
| GC włączony | 6,8619 | 0,4082 | 14,7776 | 18,3696 | 25,3693 | ok. 21,4 MiB |
| GC zatrzymany na pomiar | 6,3370 | 0,1115 | 12,5027 | 14,8917 | 18,1537 | ok. 177,1 MiB |

Wszystkie trzy mediany GC-off są niższe od odpowiadających im GC-on; mediana median spadła około **7,6%**. To dowód udziału odśmiecania/alokacji w koszcie tego workloadu. **Nie dowodzi, że GC spowodował regresję między E0 i v11, ani że odpowiada za każdy skok.** Nie ma osobnego równoważnego porównania E0 z/bez GC. Nadal występują klatki ponad 16,7 ms, a koszt pamięci bez GC narasta bardzo szybko; zatrzymywanie GC nie jest rozwiązaniem do wdrożenia.

Próba dodatkowego statystycznego profilu LuaJIT nie dała kompletnego pełnego raportu i została przerwana. Krótki smoke narzędzia przeszedł, ale jego kilka klatek nie służy do wskazywania hotspotów. Nie użyto tych danych jako dowodu. Sposób działania i ograniczenia próbkowania opisuje [dokumentacja profilera LuaJIT](https://luajit.org/ext_profiler.html).

## Decyzja i następny krok

1. Zostawić nową instrumentację i testy; nie zmieniać kryteriów akceptacji.
2. Nie wdrażać na podstawie tych danych poolingu snapshotów, wyłączania GC ani zmiany jakości renderowania. Snapshot strzału ma kontrakt niezmienności; oszczędność alokacji nie może wprowadzić ponownie błędu zgodności trafienia z obrazem.
3. Następna optymalizacja wymaga wskazania konkretnej ścieżki alokacji lub kosztownej funkcji w update/HUD/obserwacji, krótkiej izolowanej zmiany i porównania przed/po. Obecne dane wskazują obszary, nie dowodzą winy konkretnej funkcji.
4. Po takiej zmianie ponowić pełny `MEASURE.ps1` względem E0, kontrolę identyczności renderów i właściwe testy deterministyczne. Ten etap nie jest wykonany w ramach obecnej diagnozy; **nie deklarujemy zamknięcia regresji wydajności**.

Pomiar kończy się na synchronizującym odczycie 1 piksela z końcowego canvas. `submit` może zawierać oczekiwanie sterownika, `readback` zawiera synchronizację/kopiowanie. Żaden nie jest czystym timestampem GPU. Nie jest to pomiar desktopowego present, opóźnienia wejścia ani gwarancja stałych 60 FPS w grze.

## Artefakty i odtworzenie

- Zachowany pełny protokół: `work/v11-close-final/perf/summary.txt`, `run.json`, `before/`, `after/`.
- Przygotowanie izolowanych kopii: `work/punkt-1-perf/prepare.ps1`.
- Ukierunkowana seria: `work/punkt-1-perf/run-focused.ps1`, `focused/run.json`, `focused/source-after.json`, `focused/*/frames-prepared_population_20_live.csv`.
- Analiza: `work/punkt-1-perf/analyze.ps1`, `focused/analysis.txt`, `focused/per-run.csv`, `focused/worst-paired-frames.csv`.
- Eksperyment GC: `prepare-experiments.ps1`, katalog `gc/` z analogicznymi metadanymi i wynikami, `gc/source-after.json`: **Stable=true**.
- `work/` to nieśledzone artefakty lokalne. Trwałym kontraktem w repo są instrumentacja QA, test i niniejszy raport. Skrypty w `work/` mają ochronę przed nadpisaniem poprzednich wyników.

Do zebrania pełnych surowych próbek bez zmiany standardowego workloadu należy ustawić trzy opisane zmienne `SIGIL_BENCH_*` i uruchomić dotychczasowy `--benchmark`. Po pomiarze trzeba je usunąć/przywrócić; nie służą do konfiguracji normalnej gry. Nie należy wykonywać pomiaru równolegle z innymi testami lub renderowaniem.

## 28 października — nowe starcia i przygotowanie światła

Pięć naprzemiennych par E0 (`710d1ac`) / `9449bb3`, po 300 klatkach
rozgrzewki, 720 klatek pomiaru i 2400 krokach, dało:

| Scena | E0 mediana [ms] | Po zmianach [ms] | Wynik protokołu |
|---|---:|---:|---|
| 4 ciała, nieruchome efekty | 4,1132 | 4,2855 | NO REGRESSION |
| 20 ciał, nieruchome efekty | 5,4102 | 5,4165 | INCONCLUSIVE |
| 20 ciał, żywa walka, pełna klatka | 6,5114 | 8,7823 | REGRESSION |
| 20 ciał, sam krok symulacji | 0,1234 | 0,1550 | REGRESSION |

Surowe wyniki: `work/basilica-duel/perf/summary.txt`. To porównanie całego
produktu, także nowych ataków, AI i hazardów; nie izoluje kosztu silnika.
W żywej walce rozrzut po zmianach wynosi 22,4%. Nie unieważnia to ujemnego
wyniku protokołu. W pierwszym przebiegu 20 ciał p95 wyniosło 17,82 ms,
p99 21,95 ms. Nie deklarujemy stałych 60 FPS ani zamknięcia starej regresji.

Znaleziono osobną, konkretną przyczynę zacięcia przy wejściu: atlas cieni
i geometria świata powstawały dopiero w pierwszym rysowaniu. Poprzedni
pełny test wejścia zarejestrował 345,72 ms w pierwszym katalogu i trzy
odroczone natywne obrazy. Teraz `Renderer:prepareWorld` jest zadaniem
widocznego LoadPlan. Symulacja i wejście pozostają zatrzymane do końca
przygotowania. Kafelki widoczności powstają po jednym kroku ładowania.

Atlas zachowuje najwyżej 64 kafelki CPU po 128×128 RGBA8 (4 MiB) i tylko
14 miejsc GPU. Powrót do wcześniej widzianej lampy kopiuje gotowy kafelek,
zamiast jeszcze raz liczyć widoczność i AO. Nowa geometria unieważnia cache;
zwolnienie właściciela zwalnia też ImageData. Na obecnej mapie wszystkie
30 źródeł mieści się w przygotowanej puli. Mapa z ponad 64 różnymi
pozycjami świateł może nadal potrzebować obliczeń podczas eksploracji.

Pierwszy pełny test po tej zmianie: katalog 10,737 ms (submit 5,273 ms),
gra 15,450 ms (submit 11,930 ms), oba bez późnych obrazów PNG i natywnych.
63 klatki ładowania, 17 PNG, 1917,894 ms do gotowości, najdłuższy provider
127,738 ms. Dekodowanie PNG i upload pozostają niepodzielne. To świeży
proces, nie wyczyszczony cache systemu/sterownika; przebudowana mapa też
różni się od starszej. Liczby opisują obserwację, nie izolowane A/B.

48 ujęć `majestic-final` i `optimized-review` ma identyczne SHA-256 PNG.
Oszczędność nie pochodzi ze zmiany tekstur, HUD-u ani jakości cieni.
Kontrola obejmuje powrót do lamp, przekroczenie limitu cache, odtworzenie
wyrzuconego kafelka, porzucenie zasobów oraz awarię tworzenia mapy stropu
i ponowienie przygotowania bez oznaczenia niepełnej rewizji jako gotowej.

### Końcowe A/B tej samej treści: 44f4060 → 3a35b56

Pięć par w naprzemiennej kolejności, kopie źródeł poza katalogiem gry,
te same assety i definicje mapy/ataków; protokół MEASURE bez zmiany progów.
Wyniki: `work/basilica-duel/cache-perf/results/summary.txt`.

| Scena | Przed mediana [ms] | Po mediana [ms] | Wynik |
|---|---:|---:|---|
| 20 ciał, nieruchome efekty | 5,7895 | 5,7245 | NO REGRESSION |
| 4 ciała, nieruchome efekty | 3,8210 | 4,0273 | INCONCLUSIVE |
| 20 ciał, żywa walka, pełna klatka | 8,2016 | 8,6236 | INCONCLUSIVE |
| 20 ciał, sam krok | 0,1649 | 0,1673 | INCONCLUSIVE |

Żywa walka ma +5,1% mediany, lecz różnica mieści się w sumie IQR.
Zmiana nie dotyka symulacji; w kroku też widać rozrzut pomiaru. To nie
uprawnia do zaliczenia bramki: protokół traktuje nierozstrzygnięty wynik
jako brak zamknięcia regresji. Nie powtarzano pomiaru aż do trafienia
korzystnego zestawu ani nie poluzowano kryterium.

Rzeczywiste publiczne sale z tego samego pełnego benchmarku, pięć przebiegów
po 540 klatek (mediana median; zakres p95; najgorsza pojedyncza klatka):

| Scena po zmianie | Mediana [ms] | p95 [ms] | Najgorsza [ms] |
|---|---:|---:|---:|
| Jeden Margrabia | 5,81 | 9,23–9,49 | 38,76 |
| Trzech Furfurów | 5,91 | 10,29–11,56 | 19,05 |
| Przygotowany tłum 20 | 8,62 | 15,05–18,11 | 28,81 |

Przed cache najgorsza klatka publicznego Margrabiego miała 171,40 ms;
po nim 38,76 ms. Pozostałych skoków nie przypisujemy bez dowodu samemu GC.
P95 sal mieści się w budżecie 60 FPS, lecz outliery i cięższy tłum nadal
pozostają ograniczeniem. Pomiar kończy się na readback, nie desktopowym
present; nie jest testem opóźnienia wejścia.

W pełnym benchmarku historyczne pole `first_field_world_draw...` wywołuje
renderer bez aplikacyjnego LoadPlan i nadal może obejmować wypiekanie świata.
Nie opisuje ścieżki użytkownika po tej zmianie. Jej osobnym pomiarem jest
pełny `startup-check` przez Application: ostatnio katalog 10,590 ms,
gra 12,850 ms, bez odroczonych obrazów, 63 kroki / 2488,387 ms do gotowości.

Pełna kontrola `--resource-plateau`, osiem cykli menu/poligon/drugi widok/
replay/wyprawa/zwolnienie, przeszła. Liczba obrazów, canvas i bajtów GPU
nie rośnie ponad pierwszy rozgrzany cykl. Po pojedynczym końcowym usunięciu
śladów JIT pozostało zero sesji/dzienników/aplikacji utrzymywanych przez
badane korzenie. Rozrzut sterty ostatnich trzech cykli to 2024,395 KiB;
nie użyto arbitralnego progu RAM. Dowody:
`work/basilica-duel/resource-final/`, źródła stabilne, kod wyjścia 0.
