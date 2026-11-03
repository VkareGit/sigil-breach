**SIGIL: BREACH 0.43 — niezależny przegląd `41610f4..f007a1d`, 3 listopada 2026**

**Werdykt: Etapu 0 nie można jeszcze odebrać.** F04 i F07 mają działające naprawy. Continue nadal pozwala odzyskiwać zasoby i unikać śmierci, a zwiększenie zasięgu elit otworzyło odpoczynek pod zapowiedzianym atakiem. B01 poprawia walkę ze stojącym strzelcem, lecz jego zielone bramki nie potwierdzają całych kryteriów odbioru.

Przejrzałem siedem commitów przez `git log`, `git show` i porównanie zakresu, oba audyty, raport końcowy, decyzje oraz opisy 0.43. Bez sieci, delegowania i zmian w `game/`, `tools/`, `docs/`; bez commitów. Końcowy `git status --short` jest pusty, a odcisk źródeł identyczny z początkiem testów: `9663A2EA9ED4F744F84E23BA87D3B24BAF2DC77FC2EA9E71548F09D579D8E14E`. Dowód: `work/review/final-integrity.json`.

Uruchomienia LÖVE miały każdorazowo `APPDATA=(Resolve-Path work\appdata).Path` i `Start-Process -WindowStyle Hidden`. Raporty oraz sondy są w `work/review/`; zapisy standardowych testów korzystały ze wskazanego izolowanego APPDATA. W Architecture breakpoint PowerShell zmieniał wyłącznie katalog wyników `Get-Project` na `work/review/architecture`, bez edycji skryptów i bez wyłączania kontroli.

Polecenia używane dalej jako skróty dowodowe:

- **A:** `.\TEST.ps1 -Suite Architecture`, z opisanym przekierowaniem wyników.
- **T(id):** `toolchain\love-11.5-win64\lovec.exe game --suite=<id>`, przez ukryty `Start-Process`, z `SIGIL_UI_QA_DIR=work/review` jako ścieżką absolutną.
- **S:** `lovec.exe work/review/probe`. Przypadki S1–S8 sprawdzają zapis, zagrożenia, paczki, dziennik i dodatkowy obszar. Operacje plikowe `Save.write/candidates` przekierowano do sondy; produkcyjne `capture/encode/decode/restore/flush` pozostają użyte. S9–S10 porównują obecne AI z funkcją `AI.demons` odczytaną przez `git show 41610f4:game/src/enemies/ai.lua`, podmienioną wyłącznie w pamięci procesu.
- **C:** `lovec.exe work/review/combat-probe`. C1: cztery strategie, dwie elity, ziarna 1–10, krok 1/120 s. C2: elita na swoim stanowisku w kaplicy, pozostałe ciała wyłączone przez HP=0, wyposażenie początkowe, po trzy ziarna. C3: rzeczywista geometria kaplicy, zapowiedź błyskawicy i kontrola bez odpoczynku. To sondy symulacji, nie próba człowieka.

Odtworzenie poleceń zapewnia `work/review/POWTORZ.ps1`: `-Kind Architecture`, `-Kind Suite -Suite <id>` lub `-Kind Probes`. Wyniki S i C: `probe-results.txt`, `combat-probe-results.txt`; źródła sond w podkatalogach `probe/` i `combat-probe/`.

Wszystkie poniższe zestawy mają świeży raport `STATUS: PASSED`. Architecture zakończyło się kodem 0, podobnie obie sondy. Nie uruchamiałem całego `-Suite All`, osobnego Input ani pełnego Render.

| Sprawdzenie | Wynik |
|---|---:|
| Architecture | formatowanie poprawne; 649 Lua, 0 naruszeń |
| pilgrimage-save | 155 PASS |
| pilgrimage | 167 PASS |
| attack-followups | 47 PASS |
| souls-gate | 6 PASS |
| souls-bots | 9 PASS |
| golden | 10 PASS |
| chambers | 102 PASS |
| proving | 56 PASS |
| replay | 29 PASS |
| open-presentation | 38 PASS |
| interface | 19 PASS |
| weapons | 347 PASS |
| weight | 807 PASS |
| weapon-art-review | 4 PASS |
| chapel-route | 11 PASS |
| encounters | 74 PASS |

Dowody zestawów: `work/review/suite-<id>-results.txt` oraz `<id>.stdout.txt`; Architecture: `work/review/architecture/architecture.txt` i `architecture.evidence.json`.

| Commit | Ocena zmiany |
|---|---|
| `2118a76` | Poprawne rozróżnienie dropu i skrytki, wybór potrzebnych zapasów przez bota oraz asercja otwarcia menu w scenie renderu. Aktualizacje bramek wymagają zastrzeżeń z ustaleń 6 i 8. |
| `7fc9269` | F04 naprawione w sprawdzonych przypadkach; potwierdzenie porównaniem starego i nowego AI, ustalenie 9. |
| `e648495` | Naprawia truciznę po martwym Buerze, HUD i ramy. Bezpieczeństwo odpoczynku nie obejmuje nowego zasięgu B01, ustalenie 4. |
| `01dfef8` | Zapis pola jest krokiem we właściwą stronę, ale nie realizuje D9 w pełnym cyklu życia, ustalenia 1–3. |
| `bc1da54` | Dobra reguła procesu; późniejszy B01 nie zachowuje „jednej zmiennej na commit”, ustalenie 11. |
| `505be0c` | Poprawne przejście przez model amunicji; A i `pilgrimage-save` zielone. Nie usuwa pozostałych luk Continue. |
| `f007a1d` | Wyraźnie poprawia karę za stanie/cofanie, ale łączy trzy dźwignie balansu, osłabia bramki i koliduje z promieniem ogniska, ustalenia 4, 6–7, 11. |

Priorytety: **P1** — przed uznaniem podstaw za gotowe; **P2** — przed rozwojem zależnym od danego zachowania; **P3** — uzupełnienie jakości i dokumentacji.

1. **Potwierdzony błąd, P1 — Continue nie zapisuje wyjścia po samym ruchu, strzelaniu lub utracie zasobów.** Nowy stan pola korzysta ze starej flagi `dirty`, ustawianej przede wszystkim przez nagrodę za zabójstwo. `Application:flushSave` pyta o `unsaved`, a `P.flush` również wymaga `dirty`. Po poprawnym zapisie flagę wyzerowano, więc dalsza walka bez zabójstwa nie trafia na dysk.

   **Dowód:** `game/src/app/application.lua:146`, `game/src/run/modes.lua:176`, `game/src/run/pilgrimage.lua:165`. S/S1: `dirty=false`, `flush=false`; po wznowieniu pozycja `(27;31,08) → (27;33,50)`, HP `81,9 → 100`, magazynek Exorcista `0 → 2`, flaska `1 → 3`, ścigający `awake=true → false`. S/S2: pierwsza sesja bez zabójstwa nie tworzy zapisu. `work/review/probe-results.txt:1`. Nowy test `pilgrimage_save.lua:514` zawsze wcześniej zabija trzy stwory, więc omija ten przypadek mimo nazwy obiecującej wznowienie.

   **Poprawka:** oddzielić zapis bieżącego pola przy opuszczeniu sesji od odroczonego zapisu nagród. Zaktualizować również `unsaved`; samo usunięcie warunku w `P.flush` nie wystarczy. Dodać przypadki bez zabójstwa, po wcześniejszym autosave oraz po ponownej odmowie dysku.

2. **Potwierdzony błąd, P1 — nawet wykonany zapis usuwa nadlatujące obrażenia i resetuje rozpoczęty atak.** `fieldOf` nie zapisuje pocisków, zagrożeń ani fazy/czasów ataków. `resumeField` buduje przeciwników od nowa i przywraca tylko wybrane dane łowców. Samo zachowanie `awake` nie spełnia warunku D9 „wyjście nie może być ucieczką”.

   **Dowód:** `game/src/run/pilgrimage.lua:240`, `:811`, `:837`. S/S3: pociski `1 → 0`; po 0,2 s nieprzerwana sesja kończy się śmiercią z HP=0, wznowiona pozostaje w grze z HP=20. S/S4: opancerzony `windup → idle`, pozostały zamach `0,56 → 0`, mimo zachowanego `awake=true`. `work/review/probe-results.txt:3`.

   **Poprawka:** zapisywać i odtwarzać istotny stan trwającej walki, łącznie z zagrożeniami, fazami i zegarami. Objąć też stan akcji gracza, który dziś czyści `refresh`. Test powinien porównywać wynik kolejnych kroków przed i po wznowieniu, a nie wyłącznie pozycję i flagę pościgu.

3. **Potwierdzony błąd, P1 — wznowienie odtwarza pełne resztki skrytek, gubi dropy i leczy rannych nieaktywnych przeciwników.** Dla zapasów zapamiętano tylko obecność `rewardId`, a dla żywych stworów tylko stan tych z `awake=true`. To niepełny zapis świata: może dawać dodatkową amunicję albo karać za zakończenie sesji utratą nagrody i postępu obrażeń.

   **Dowód:** `game/src/run/pilgrimage.lua:837`, `:845` oraz odtworzenie przez `P.populate` w `:240`. S/S5 używa rzeczywistego `collectSupplies`: z paczki sześciu naboi pobrano jeden, po wznowieniu reszta rośnie `5 → 6`, przy zachowanym zapasie gracza `72 → 72`. Dodany drop znika: liczba paczek `23 → 22`. Ranny, nieaktywny opancerzony odzyskuje HP `123 → 560`. `work/review/probe-results.txt:6`.

   **Poprawka:** utrwalać pozostałe ilości oraz niezebrane dropy i stan wszystkich żywych stworów. Zachować rozdział między stanem bieżącej próby a stanem zabezpieczonym przy ognisku. To istotne dla D9, skończonych zasobów D10 i przyszłych nagród C01.

4. **Potwierdzony błąd, P1 — ognisko pozwala odpocząć pod zapowiedzianą błyskawicą Furfura.** B01 zwiększa zasięg do 18 m, ale `fighting` nadal rozpoznaje żywego łowcę tylko poniżej 14 m; nie uwzględnia aktywnego znaku na ziemi. `calm` kasuje ten znak podczas odpoczynku. Pierwotna plama po martwym Buerze została naprawiona, lecz nowa kombinacja pozwala leczyć się pod bieżącym atakiem.

   **Dowód:** `game/src/content/creatures/furfur.lua:178`, `game/src/content/pilgrimage.lua:24`, `game/src/run/pilgrimage.lua:366`, `:385`. C/C3: gracz przy East Fire `(38;21)`, Furfur `(41;7)`, dystans 14,32 m, widoczność i pozycja poprawne, przeciwnik wewnątrz swojego leash. Podczas zapowiedzi: `fighting=false`, wejście do `shop`, znaki `1 → 0`. Po odpoczynku HP/ward pozostają `100/40`; identyczna próba bez odpoczynku kończy się `77,5/12,5`. Dowód w końcowych wierszach `combat-probe-results.txt`.

   **Poprawka:** odmowę odpoczynku oprzeć także na ataku lub aktywnym zagrożeniu wymierzonym w gracza, z uwzględnieniem nowych zasięgów. Rozróżnić pozostałość po martwym autorze od bieżącego ostrzału. Dodać test 14–18 m; dotychczasowy `safeRest` w `game/tests/cases/pilgrimage.lua:80` sprawdza bliski pocisk i martwego Buera, więc tej regresji nie wykrywa.

5. **Potwierdzony błąd istniejący wcześniej, P2 — przejście do innego obszaru i powrót odnawia niezabezpieczone zabójstwa, zachowując dusze.** Nie przypisuję tej luki nowym commitom. Jest jednak istotna przed C01 i dokładaniem obszarów: zapis bieżącego pola nie przenosi historii opuszczonego obszaru.

   **Dowód:** `game/src/run/pilgrimage.lua:189`, `:348`: zmiana obszaru czyści świat, powrót wykonuje `P.populate` z trwałych flag. S/S8 rejestruje testowy aneks analogicznie do istniejącego `pilgrimage_save.lua:405`. Po zabiciu `nave_1`, przejściu, wznowieniu i powrocie stwór żyje, a portfel nadal zawiera 40 dusz. `work/review/probe-results.txt:10`. Samo wznowienie w aneksie przed odpoczynkiem poprawnie zachowało mapę i miejsce; śmierć po wznowieniu odtworzyła ognisko i echo 40.

   **Poprawka:** przechowywać bieżący, niezabezpieczony stan osobno dla odwiedzonych obszarów; śmierć powinna go cofać zgodnie z D10. Testować powrót przez drzwi po zabójstwie i zabraniu nagrody, nie tylko poprawność mapy i punktu odrodzenia.

6. **Ryzyko, P1 — zielone `souls-gate` i `souls-bots` nie oznaczają spełnienia B01.** Puste `BOSS_GATE` wyłącza wszystkie asercje o botach odruchowych i połowicznym czytaniu. Decyzja o krótszych elitach nie ustanawia sama w sobie wyjątku od wymagania reakcji; plan B01 nadal wymienia skuteczność prostych strategii. Zmiana została jawnie opisana, ale odłożenie oceny nie jest jej zaliczeniem.

   **Dowód:** `game/tests/cases/souls_gate.lua:11`, `:92`, `:121`; T(souls-gate) daje tylko 6 PASS. W jego logu Margrave przegrywa wszystkie sześć prób `reflex/oneSide`, a obie elity wszystkie trzy próby `human(0.5)`. Ponadto `game/tests/cases/souls_bots.lua:112` wyłącza wymóg zwycięstwa uczącego się bota właśnie dla obu elit. `enemy_durability.lua:351` i `game/docs/ZMIANY.txt:25` twierdzą, że długość walki chroni `souls_gate`, chociaż nie ma tam asercji 20–35 s. Test unikania pojedynczych ataków w `souls_bots.lua:62` używa dystansu około 3 m, więc jego PASS nie sprawdza nowych 16–18 m.

   **Poprawka:** przywrócić osobne, jawne kryteria dla elit: powtarzalność porażek prostych strategii, osiągalność zwycięstwa oraz pomiar czasu i pokazanych ataków. Zaakceptowany wyjątek projektowy powinien zmieniać kryterium, a nie pozostawiać pustą bramkę i status „zrobione”. Dodać próby nowych zasięgów i prawdziwej kaplicy.

7. **Ryzyko, P2 — B01 poprawia presję, ale 2700/2250 HP nie dowodzi 20–35 s dobrej walki człowieka.** Obie wartości HP wzrosły o około 61%; nawigacja `duel` i większy zasięg usuwają część bezpiecznych pozycji. Korzyść jest realna, lecz te trzy zmiany jednocześnie zwiększają wymagania dotyczące ruchu, zapasów i liczby trafień. Nie ma podstaw, by z samego DPS bota wyprowadzać deklarację czasu człowieka.

   **Dowód:** `game/src/content/creatures/boss.lua:42`, `:181`, `:205`; `furfur.lua:61`, `:178`; `game/src/enemies/styles.lua:138`. T(souls-bots): uczący się bot wygrywa w 12,8 s i 16,9 s, po 3/3 zwycięstwa. C/C1 daje:

   | Strategia, zwycięstwa | Margrave | Furfur |
   |---|---:|---:|
   | Stanie i strzelanie | 1/10 | 0/10 |
   | Cofanie i strzelanie | 0/10 | 0/10 |
   | Stałe okrążanie i strzelanie | 0/10 | 10/10 |
   | Istniejący `Bot.human(0.3)` | 9/10 | 10/10 |

   Okrążanie Furfura wygrywa w 16,28–18,17 s z 27,6–72 HP. Model `human(0.3)` daje w komnatach przebiegi 12,09–18,54 s. W C/C2, przy początkowym wyposażeniu i samotnej elicie w kaplicy, zwycięstwa tego modelu trwają 12,80–22,47 s dla Margrave'a i 16,73–27,52 s dla Furfura. Stojący strzelec przegrywa tam 3/3 z każdym. To wspiera decyzję „stanie ma zawodzić”; pojedyncze zwycięstwo 1/10 nie jest dowodem regularnej skuteczności. Nie dowodzi natomiast realizacji całego celu B01. `Bot.human` (`game/qa/souls_bot.lua:284`) nadal czyta dokładne zegary i dziedziczy ruch bota.

   **Poprawka:** B02 na rzeczywistej trasie, z wyposażeniem odpowiednim do obu elit, pomiarem czasu, zużycia zapasów i rozpoznanych ataków. Wynik okrążania Furfura rozstrzygnąć jawnie względem `RAPORT-KONCOWY.md:107`. Nie podnosić ponownie HP wyłącznie dla dopasowania zegara. Deklarację „przy celności człowieka 25–35 s” w `game/docs/ZMIANY.txt:73` oznaczyć jako hipotezę do próby.

8. **Uwaga, P2 — część zmian testów jest uczciwa, część zmniejsza ochronę bardziej, niż potrzeba.** Ocena poszczególnych złagodzeń:

   | Zmiana i dowód | Ocena i proponowane domknięcie |
   |---|---|
   | `souls_gate.lua:64`: „ponad 60%” → „przeżywa”; T(souls-gate): pozostaje 12%/18% HP elity | Uzasadnione decyzją właściciela: liczy się zawodność stania, nie wielkość przewagi elity. Wymaga wielu ziaren i wyposażenia, bo sam `left > 0` daje mały margines. |
   | `souls_gate.lua:68`: Furfur 0,8 → 0,7; pomiar 0,66 ataku/s bez ostrzału i 0,47 pod ostrzałem | Jest mechaniczne uzasadnienie kontry szarży, ale próg leży blisko wyniku około 0,71. Agregat nie rozróżnia prawidłowej kontry od stłumienia AI. Liczyć osobno rodzaje ataków i przyczyny przerwania; nie traktować samego PASS jako dowodu. |
   | `enemy_durability.lua:354`: obie elity >2× HP moba, bez nakazu Furfur > Margrave; T(weight): 807 PASS | Relacja HP jest rozsądniejsza od arbitralnej hierarchii. Usunąć jednak fałszywą obietnicę, że inny test pilnuje czasu, albo rzeczywiście ten test dodać. |
   | `tests/suites/interface.lua:122`: konkretna kwota → dowolne `Missing %d+ souls`; T(interface): 19 PASS | Zmiana cen uzasadnia aktualizację, ale regex akceptuje również błędną kwotę. Wyliczyć oczekiwany niedobór z aktualnej oferty i portfela. Nazwa testu dotyczy przede wszystkim zastąpienia starego komunikatu; to nadal sprawdza. |
   | `tests/suites/weapons.lua:230`: regeneracja zapasu Judge'a; T(weapons): 347 PASS | Zgodne z celową regułą 0.42. Test sprawdza brak strzału, przyrost i końcowy limit sześciu. Warto uzupełnić mieszany stan magazynka/zapasu i granicę momentu regeneracji; nie widzę tu maskowania błędu. |
   | `qa/reviews/weapon_timeline.lua:201`: czasowe `spare=0`; T(weapon-art-review): 4 PASS | Uczciwa izolacja rachunku transakcji, jawnie opisana. Nie jest testem przeładowania z włączoną regeneracją. Dodać taki przypadek i przywracanie `spare` także po błędzie, bo obecne przywrócenie w `:212` następuje tylko przy sukcesie. |

   Naprawy `chapel_route.lua:38` i `qa/souls_bot.lua:177` poprawiają trafność testów. `chapel_look.lua:114` teraz jawnie wymaga `shop`; scenariusz rzeczywiście dotyczy menu. Odświeżenie golden jest opisane w `tests/golden/baseline.lua:27`, a T(golden) odtwarza wzorzec. Golden potwierdza zgodność z nowym przebiegiem, nie jego jakość ani brak luk D9.

9. **Uwaga, P2 — F04 jest potwierdzoną naprawą, a nowe próby wykrywają dawny błąd.** `spent` blokuje zwykłe ciosy i odpowiedzi przez pełne recovery; sprawdzanie odpowiedzi przed rozwinięciem serii przywraca reakcję na unik. Odstęp nadal odpowiada równoległym zegarom recovery/cooldown, nie ich sumie, zgodnie z doprecyzowaniem audytu.

   **Dowód:** `game/src/enemies/actions.lua:206`, `game/src/enemies/ai.lua:188`, `:360`, `:394`, `game/src/enemies/answers.lua:30`. T(attack-followups): 47 PASS; T(encounters): 74 PASS. S/S9: wymagane 1,05 s, aktualny pierwszy atak 1,058 s, ze starą funkcją AI 0,700 s. S/S10: obecnie `gore-return`, dawniej `crown`. `work/review/probe-results.txt:12`.

   **Proponowane uzupełnienie:** osobny przypadek `ash-catch` Margrave'a oraz przerwania recovery przez ogłuszenie. Obecny nowy test odpowiedzi na unik dotyczy Furfura; jego wynik nie dowodzi automatycznie wszystkich rodzin i okien czasowych.

10. **Uwaga, P2 — F07, podstawowe D10 i sprawdzone ścieżki zgodności działają; nie są to pełne gwarancje Continue.** HUD dostaje `worn`, sprawdzenie rysuje obie bronie z różnymi grawerami, a trzy podpowiedzi mieszczą się w pięciu rozdzielczościach. Teksty gracza przestały obiecywać odradzanie po odpoczynku. Stare zapisy bez `field`, migracja, podstawowe drzwi i śmierć przechodzą istniejące próby. D8 pozostaje zadaniem C01; pozostawienie sklepu w tym zakresie nie jest samodzielną regresją.

   **Dowód:** `game/tests/cases/pilgrimage.lua:122`, `game/tests/cases/open_presentation.lua:207`, `game/src/ui/hud.lua:531`, `game/src/ui/chapel.lua:314`. T(pilgrimage): 167 PASS; T(open-presentation): 38 PASS; T(pilgrimage-save): 155 PASS; T(proving), T(chambers), T(replay) również zielone. Dodatkowe S/S6 odtwarza dziennik rozpoczęty z rannym graczem i aktywnym łowcą: zgodny replay, 0 zapisów na dysk. S/S8 potwierdza śmierć po wznowieniu. To zgodność nowego dziennika tej wersji; nie potwierdzam zgodności nagrań z 0.42.

   **Proponowane uzupełnienie:** rozszerzyć macierz zapisu o ustalenia 1–5. Uporządkować komentarze `game/src/run/pilgrimage.lua:59` oraz `game/src/content/pilgrimage.lua:8` i `:103`, które nadal sugerują odnawianie zapasów przy odpoczynku. Czytelność w ruchu i wygląd pozostają do odbioru człowieka; automatyczny test ram ich nie zastępuje.

11. **Uwaga, P2 — reguła procesu została zapisana, lecz B01 jej nie zachował.** `game/docs/DEVELOPMENT.txt:342` wymaga jednej zmiennej balansu na commit. `git show f007a1d` obejmuje równocześnie HP, zasięgi, trasę ruchu, zmianę kryteriów QA i golden. Opis prób kolejnych wariantów nie zastępuje rozdzielenia zmian w historii.

   **Dowód:** polecenie `git show --stat f007a1d` oraz kod wskazany w ustaleniach 6–7. `POSTEP.md:13` przedstawia A02 jako wykonane mimo reprodukcji S1–S5, a `:16` B01 jako wykonane z odłożoną oceną. Aktualna kontrola A jest zielona; nie wyciągam z tego wniosku, że historyczne `-Suite All` wykonano przed każdym commitem.

   **Poprawka:** sprostować status A02 i zakres odbioru B01. Następne korekty rozdzielać na przyczynowe zmiany z porównywalnymi pomiarami i kompletem wymaganych wyników. Nie aktualizować golden ani progów tylko dlatego, że istniejąca bramka jest czerwona.

**Czy można iść dalej?** Najpierw zamknąć P1: niezawodny zapis przy wyjściu, odtwarzanie walki i zasobów oraz odmowę odpoczynku pod aktywnym atakiem. **C01** można projektować według D8, ale wdrażanie trwałych znajdziek powinno opierać się już na poprawnym zapisie, także między obszarami. **R01** powinien wejść po tej naprawie i B02: laser musi od początku mieć test kontry, wznowienia w zapowiedzi oraz odmowy ogniska. **D03–D04** mogą być rozwijane niezależnie z porównaniem obrazu; **D05** wymaga osobnej próby rytmu walki po ustabilizowaniu B01. Obecny stan nadaje się do dalszych poprawek i próby właściciela, ale nie do ogłoszenia zakończenia Etapu 0 i pełnego odbioru elit.
