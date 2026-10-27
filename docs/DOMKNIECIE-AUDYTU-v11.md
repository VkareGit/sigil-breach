# Domknięcie usterek z audytu v11

Data: 27 października 2026. Punkt wyjścia: `6ffb306`.

To realizacja listy napraw z `AUDYT-GOTOWOSCI-BAZY-v11.md`, nie kolejna przebudowa fundamentu. Zakres obejmuje kontrakty sprawcy, czasu wejścia, obserwatora i trwałego I/O. Istniejące modele, tekstury, menu, układ HUD-u i parametry balansu pozostają bez zmian. Stożek celowania korzysta teraz z właściwego modyfikatora `choke`.

## Wykonane poprawki

| Problem | Rozwiązanie | Dowód regresji |
|---|---|---|
| Efekt demona tracił ID źródła | `Effects.origin` rozdziela ID ciała od etykiety kontaktu; puls zachowuje właściciela, a `cancelOnSourceDeath` sprawdza właściwe ciało | `damage-origin`: demon/rycerz/nieznany sprawca, śmierć źródła, zmiana sterowania, snapshot i replay |
| Podkroki gubiły `input.actors` | Kopiowane są tylko rekordy z jednorazowym `dash`/`slide`; pozostałe pola i wejścia aktorów trwają przez cały update | `input-geometry-contracts`: 1/30 kontra cztery kroki 1/120, obaj aktorzy, replay, brak mutacji wejścia |
| Nieznany styl AI przechodził walidację | Kompozycja sesji wymaga istniejącej funkcji `move.style` i `move.targeting`; brak cichego fallbacku do `keep` | `foundation-contracts`, `content-contracts`: literówka, nie-wywoływalny wpis, nowa poprawna strategia wykonana w AI |
| Pochylenie zależało od sterowanego gracza | Jedna sprężyna ma jawny układ źródła kontaktu; obserwator rzutuje tę samą reakcję. Pocisk podaje obserwatora bez zależności zwrotnej Combat → Projectiles | `damage-origin`: rzeczywisty kontakt przy zmianie sterowania; `flinch-observers`: przeciwne strony, upadek, render A/B/B/A bez zmiany symulacji |
| Interpolacja mieszała reakcje z przeciwnych stron | Po zmianie bazy kontaktu używana jest bieżąca wartość, a następne kroki wracają do zwykłej interpolacji | `flinch-observers`: alpha 0 / 0,5 / 1, także źródło anonimowe; zachowanie dotychczasowej interpolacji dla tego samego sprawcy |
| Bufory brył dwóch obserwatorów aliasowały | `Geometry.volumes(..., into)` zapisuje w buforze odbiorcy; `Ballistics.prepare` ma własne wewnętrzne tablice | `input-geometry-contracts`: brak aliasu tablic i kształtów, ponowne użycie bufora bez zmiany drugiego wyniku |
| Raport wybuchu używał sterowanego zamiast rzucającego | `selfDamage` rozlicza `charge.owner`; nieobecny właściciel nie staje się innym rycerzem | `damage-origin`: rzucający B i nieobecny rzucający; istniejący test własnego wybuchu jawnie podaje właściciela |
| Teleport zostawiał ważną obserwację i bufor strzału | Faktyczne przeniesienie na poligonie unieważnia obserwację przemieszczonego aktora i czyści jego intencję | `input-geometry-contracts`: publiczne `Game:act`, bez ochrony przejścia ekranów |
| Classic czytał zmienny rekord z dysku w replayu | `storage/execution` zapisuje nazwany fakt `classic.bestScore` w `journal.externalInputs`; replay konsumuje zapisany fakt | `replay-io`: nagranie z 1000, dysk zmieniony na 2000, wynik nadal 1000, zero odczytów |
| Replay wykonywał trwałe zapisy | Jawny zakres replaya blokuje zapis checkpointu, niskopoziomowy `Save.write`, rekord i telemetry. Wynik checkpointu, także błąd, jest odtwarzanym faktem | `replay-io`: `testing=false`, sukces/błąd, zagnieżdżenie, cleanup po wyjątku i walidacja przed mutacją |
| Pełny reset czyścił efekt tylko sterowanego | `Encounter.clearWorld` czyści wszystkie ciała rycerzy. `clearStage` zachowuje dotychczasową politykę trwania ekspozycji | `damage-origin`: oddzielny test pełnego resetu i granicy fali |
| HUD pomijał glif `choke` | Oba istniejące rysowania pobierają promień stożka ze wspólnego `HUD.spreadRadius`, korzystającego z `Loadout.spread` | `consistency`: stożek strzelby zwęża się, rewolwer bez zmian, wyłączony ruch kamery ignoruje FOV kick |
| Rejestr milcząco nadpisywał ID | `register` odrzuca duplikat. Jawne `replace` wymaga istniejącego ID, waliduje nową wartość i zachowuje kolejność | `core-foundation` i jawna migracja zamierzonej podmiany w testach |
| Nieaktualna instrukcja | Numer 0.34, odniesienie do v11, opis nowych kontraktów i przepisy rozszerzania | `INSTRUKCJA.txt`, `ARCHITEKTURA.txt`, `ROZSZERZANIE.txt`, `ZMIANY.txt` |

Nowe testy są podpięte do zwykłego `TEST.ps1 -Suite All`, a nie tylko uruchomione jednorazowo. Materiały red→green dla wejścia, brył, walidacji, replaya i interpolacji są w `work/v11-close-*`; wcześniejsze reprodukcje źródła obrażeń i dodatkowych błędów pozostają w katalogach poprzedniego audytu. Są to lokalne materiały QA, ignorowane przez Git.

## Kontrakty i świadome granice

- **Zgodność replayów:** zachowane są wersje formatu dziennika obsługiwane wcześniej. Starszy dziennik bez `externalInputs`, który dochodzi do zwycięstwa classic i potrzebuje nieutrwalonego rekordu, kończy się jawnym `journal lacks external input classic.bestScore`. Nie da się odtworzyć historycznej wartości, której nie zapisano. Nadal obowiązuje kontrola wersji/fingerprintu; nie obiecujemy replayów między różnymi wydaniami. To nie zmienia migracji zapisów SIGIL06–09.
- **Geometria:** obecne demony pozostają malowanymi billboardami z maskami. Naprawa buforów zabezpiecza również punkt rozszerzenia `hit='volumes'`, mimo że obecny katalog go nie używa. Flinch to jawna konwencja billboardu ze sprężyną, nie trójwymiarowy model ciała.
- **Ładunki:** etykieta `self` w obrażeniach rycerzy nadal wyłącza perfect-dodge dla ładunku. ID właściciela jest od niej oddzielne. Nie zmieniono reguł friendly fire ani wartości obrażeń.
- **Wiele postaci:** niezależne wejście, walka i obserwacje są sprawdzane, ale kooperacja nie jest gotowym trybem produktu. Zapasy i sanktuarium nadal obsługują sterowanego rycerza; reguła blokowania się sojuszników wymaga osobnej specyfikacji.
- **Zapis:** SIGIL09 rodzaju `session` zapisuje mapę i pule, nie dowolny moment całego starcia. Snapshot, dziennik i checkpoint wyprawy są innymi kontraktami. Pełny quicksave wymaga dodatkowych sekcji, a nie przebudowy wszystkich systemów.
- **Rozszerzanie:** nowy typ broni, demon lub mapa korzysta z istniejących definicji i wykonawców. Rzeczywiście nowe zachowanie wymaga lokalnego wykonawcy i testu, nie obietnicy „zero nowego kodu”. Następny sensowny etap to jedna kompletna broń lub jeden demon, od danych po art, kontakt, feedback i zapis.

## Weryfikacja końcowa

`TEST.ps1 -Suite All`: **PASS**. Osiem niezależnych procesów ma ten sam
fingerprint przed/po i kod zakończenia 0:

```text
Źródła: A1A0CBEC3DC6468657B0BAD2B30F0CD6ADD2CCC4D5523B63D247D0BE96857381
LÖVE:   243A44E76504DF3EACA801A60C8EFE76B190EEB9B1AA444A7276FB33DF1E0361
```

- 4373 sprawdzenia mechaniki/zasobów, o 85 więcej niż przed domknięciem;
  36 sprawdzeń rzeczywistych callbacków wejścia.
- 526 plików Lua skompilowanych, zero naruszeń architektury, format poprawny.
- 58 sprawdzeń referencji 0.33, sześć skrótów złotego wzorca i wszystkie
  referencyjne pliki pozostały bez zmian.
- Showcase, startup-check oraz smoke benchmark/core-measure/step-study/audio-export przeszły.
- **606 renderów porównanych piksel po pikselu z E0:** 596 identycznych,
  pięć wcześniejszych różnic numeru wersji oraz pięć poprawionych wskaźników
  stożka `choke`. Każda z tych pięciu nowych różnic to dokładnie 72 piksele
  przy celowniku, w prostokącie `(557,297)–(723,303)`; reszta sceny jest
  identyczna. Pliki: `42-pickups-and-threats`, `43-distance-visibility`,
  `44-armored-back`, `45-armored-strike`, `46-armored-fall`. To zmiana
  rozstawu istniejącego wskaźnika, nie nowa kompozycja interfejsu.
  Dodatkowo obejrzano render sceny i portretu/HUD-u.
- Wcześniejsze błędy integracji wychwycone podczas wdrożenia usunięto przed
  końcowym All: zależność zwrotna Combat→Projectiles oraz test własnego
  wybuchu bez wskazanego właściciela. Test nadal wymaga dokładnie 45 HP
  obrażeń własnych; uzupełniono jego dane, nie poluzowano oczekiwania.
- Osobny pełny `--resource-plateau`: **PASS**, osiem cykli rzeczywistej
  nawigacji, drugi widok, replay i wyprawa. Zero zatrzymanych właścicieli
  sesji przed i po końcowym usunięciu śladów JIT; liczby zasobów natywnych
  i bajty tekstur nie rosły ponad pierwszy rozgrzany cykl. Rozrzut sterty
  Lua ostatnich trzech cykli: 950,492 KiB — raport diagnostyczny, bez
  wymyślonego progu. Źródła mają ten sam fingerprint co All.

Dowody lokalne: `work/v11-close-final/all/`, `all-evidence.json`, `pixels.json`.
Zestawy regresji mają odpowiednio: `damage-origin` 19, `flinch-observers` 17,
`input-geometry-contracts` 26, `replay-io` 11 sprawdzeń. Nie jest to deklaracja
pełnego pokrycia każdej przyszłej konfiguracji zawartości.

### Koszt i granice pomiaru

Wykonano **pięć naprzemiennych par E0/current**, 40 niezależnych procesów,
według istniejącego `MEASURE.ps1`: High, bez affinity, mapa `qa_crowd`,
populacje 20/96/256, 300 rozgrzewki, 2400 kroków symulacji, 720 klatek
przygotowanej sceny. Oba drzewa zachowały fingerprinty przez całą serię.
E0 to `710d1ac`, SHA źródeł
`8B3F355A4AD7AC3905E4B5E54ADD9AA4D35FA1AB3FEFAB7F7549FBC62B2D3498`.

**Wynik nie zamyka kryterium wydajności v11.** Nie podmieniono progów na
łagodniejsze ani nie uznano rozrzutu za automatyczny PASS.

| Pomiar | Mediana E0, ms | Mediana obecna, ms | Obecna/E0 | Wynik istniejącego protokołu |
|---|---:|---:|---:|---|
| Klatka: 4 zamrożone demony + FX | 4,0843 | 4,3947 | 1,076 | INCONCLUSIVE |
| Klatka: 20 zamrożonych demonów + FX | 5,5569 | 5,4633 | 0,983 | INCONCLUSIVE |
| Klatka: 20 aktywnych demonów | 6,1360 | 6,9475 | 1,132 | **REGRESSION** |
| Klatka: 96 aktywnych demonów | 10,9816 | 12,8296 | 1,168 | **REGRESSION** |
| Klatka: 256 aktywnych demonów | 20,2136 | 22,5437 | 1,115 | **REGRESSION** |
| Krok: 20 ciał | 0,1208 | 0,1225 | 1,014 | INCONCLUSIVE |
| Krok: 96 ciał | 0,6146 | 0,6792 | 1,105 | INCONCLUSIVE |
| Krok: 256 ciał | 2,4867 | 2,3871 | 0,960 | INCONCLUSIVE |

Przykład 20 aktywnych demonów: wzrost mediany klatki o **0,8115 ms
(13,2%)**, większy od obu IQR (0,1720 i 0,4693 ms). Sam fakt, że mediana
pozostaje poniżej 16,67 ms, nie spełnia kryterium braku regresji. Ta seria
porównuje **całe v11 z E0**, nie izoluje kosztu tylko tego commitu.

| Bieżąca scena | Mediana z median, ms | Mediana z p95, ms | Najgorsze p95, ms | Najgorsze p99, ms | Maksimum, ms |
|---|---:|---:|---:|---:|---:|
| 4 zamrożone demony + FX | 4,3947 | 5,4618 | 6,6746 | 7,5394 | 18,0934 |
| 20 zamrożonych demonów + FX | 5,4633 | 7,4268 | 8,4625 | 9,2260 | 11,2585 |
| Cykl walki 2 | 8,6300 | 16,2663 | 20,2363 | 24,2846 | 31,5824 |
| Cykl walki 4 | 8,9059 | 16,1624 | 20,2301 | 26,6107 | 30,9341 |
| Przygotowana scena: 20 aktywnych | 6,9475 | 13,2260 | 16,2926 | 20,0296 | 24,2145 |
| Przygotowana scena: 96 aktywnych | 12,8296 | 29,1143 | 30,9497 | 40,4690 | 45,3480 |
| Przygotowana scena: 256 aktywnych | 22,5437 | 48,6257 | 50,6733 | 63,1809 | 158,4933 |

Każdy kwantyl jest najpierw liczony w osobnym przebiegu; powyższe mediany
kwantyli nie są kwantylami połączonych surowych klatek. Cykl 1 osiągnął
osobne maksimum 32,3148 ms. Zatem także warunek **p95 ≤16,67 ms w każdym
przebiegu zwykłej walki** nie został spełniony. 96 i 256 ciał są próbami
przeciążeniowymi, nie obietnicą obecnej liczby demonów w grze.

Pomiar klatki obejmuje update, świat, UI/obserwację oraz synchronizujący
odczyt jednego piksela końcowego canvasu. Nie mierzy desktopowego
present/vsync ani opóźnienia wejścia. Nie stanowi pomiaru samych czasów GPU.
Nie ma dowodu, że skoki powoduje GC: dotychczasowe logi sortują próbki faz
oddzielnie, więc nie pozwalają powiązać ich w tę samą klatkę. Nie zmieniano
ustawień GC na podstawie przypuszczenia.

Dowody: `work/v11-close-final/perf/run.json`, `perf/summary.txt`, surowe
`before/` i `after/`, `performance.json`, `resources/resource-plateau.txt`.
Powtórzenie pomiaru przy niezmienianych źródłach:

```powershell
./MEASURE.ps1 -Before work/v11-base/game -After game -Pairs 5 -Populations '20,96,256' -Out work/v11-measure-nowa-seria
```

Należy wybrać nowy katalog wyników. Zachowany lokalny wrapper `work/v11-close-perf/run-final.ps1`
dodatkowo pilnuje fingerprintów i środowiska procesu.

Najbliższe zadanie wydajnościowe jest konkretne: porównanie E0, stanu
sprzed domknięcia i obecnego stanu w tej samej scenie 20 demonów, rozdzielenie
kosztu update/świata/UI/odczytu oraz surowe próbki ze wspólnym indeksem
klatki. Dopiero na tej podstawie lokalna optymalizacja i ponowne pięć par.
To osobny problem od naprawionego przypisania obrażeń czy walidacji treści.

## Ocena bazy

**Usterki funkcjonalne z listy audytu są naprawione i sprawdzone. Punkt 7
odbioru wydajności i B2 nie są zamknięte.** Nowy pomiar wykazał regresję,
więc nie nazywam całego fundamentu bezwarunkowo odebranym.

Potwierdzone luki mają rozwiązania w odpowiednich właścicielach stanu; nie
są zasłonięte wyjątkami w HUD-zie ani większymi hitboxami. Struktura pozwala
rozwijać treść przez definicje i lokalnych wykonawców. Wyniki nie uzasadniają
kolejnego masowego refaktoru; uzasadniają celowane profilowanie opisane
wyżej, a później jedno kompletne rozszerzenie treści. Ocenę feelingu przez
gracza nadal trzeba odróżnić od poprawności automatycznych testów.
