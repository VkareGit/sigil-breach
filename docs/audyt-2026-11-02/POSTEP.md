# Postęp planu po audycie z 2 listopada 2026 (dla kolejnego agenta)

Plan i kryteria: `RAPORT-KONCOWY.md` w tym katalogu. Właściciel zatwierdził 2026-11-02 Etapy 0–3 (zatrzymać się przed Etapem 4) i podjął decyzje:
- D1: odpoczynek przy ognisku odmawia z powodem, gdy jakiś stwór czuwa.
- D2: amunicja ze stworów. Każda rodzina daje przewidywalny rodzaj naboi (wygląd lub broń stwora to sugeruje). Zwykłe zabójstwo daje szansę na mały drop z lekko losową wielkością paczki. Ryzykowna akcja (egzekucja z bliska) daje pewny, skromny zwrot. Rzadka amunicja do najmocniejszej broni pochodzi z trudniejszych przeciwników.
- D3: unik ogranicza tylko wytrzymałość, bez ładunków, z regeneracją pod szybką walkę. Zwykły ruch bez kosztu. Szczegóły zostawione mnie.
- D4: zaalarmowani w otwartej przestrzeni ruszają wszyscy, także ci z tyłu. Oddzielone części sali budzą się grupą przy wejściu albo gdy dotrze alarm. Przed wykryciem część patroluje, część stoi na warcie.
- D7: Furfur daje 150 dusz (w jednostkach treści), tyle co Margrave.
- D5 i D6 zostają otwarte (Etap 4).

## Zasady

- Odpowiedzi do właściciela po polsku, tekst w grze po angielsku, dokumenty w `game/docs` po polsku.
- Każdy punkt: najpierw test lub sonda, która odtwarza błąd, potem naprawa, wpis w `game/docs/ZMIANY.txt` i `ODBIOR.txt` (sekcja 0.42), wpis tutaj, commit.
- Commit: `git -c user.name=Nahiko -c user.email=psmietanawork@gmail.com commit -F <plik>`, plik bez BOM, na końcu `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. `git add -u` plus nowe pliki z nazwy. Nigdy `git add game`: `game/docs/PORADNIK-EDYCJI-GRY.md` i `docs/podrecznik-codex/` należą do właściciela. Bez push i bez pakowania.
- Pojedynczy zestaw testów: `$env:SIGIL_UI_QA_DIR=<katalog>; toolchain\love-11.5-win64\lovec.exe game --suite=<id>`, wynik w `<katalog>/suite-<id>-results.txt`. Identyfikatory w `game/tests/suite.lua`.

## Punkty

| ID | Punkt | Stan | Dowód |
|---|---|---|---|
| R01 | Ponowienie zapisu | zrobione | `pilgrimage_save.lua` `refusals`: przed naprawą padało na „its souls still wait for the disk” |
| R02 | Wspólny reset aktora | zrobione | `pilgrimage.lua` `freshStarts`: przed naprawą padało na „the rest ends the drink unpaid”, a bez resetu (sam koniec picia) na „after a rest: nothing burns”; Mechanics zielone, złoty wzorzec zaktualizowany |
| R03 | Broń ze zdarzenia w serii | zrobione | `chain.lua` `origins`; stary kod liczył trzy zabójstwa ładunkiem jako serię Judge'a (sonda Astry) |
| R04 | Egzekucja z zasłoną i pionem | zrobione | `souls_balance.lua`: przed naprawą padało na „not through a wall” |
| R05 | Liczby HP i wardu | zrobione | `pilgrimage.lua` (procenty wobec maksimum); render obejrzany razem z Etapem 1 |
| R06 | frame-watch i sprostowanie ODBIOR 0.40 | zrobione | przebieg: 3600 klatek gry, 55 strzałów, 0 klatek sklepu w pomiarze; przy okazji złapany „-0%” z R05 |
| R07 | Furfur 150 dusz | zrobione | `pilgrimage.lua`: każdy stwór z posterunku płaci, Furfur = Margrave |
| R08 | Dokumenty wejściowe | przeniesione na koniec Etapu 3 | Etap 2 zmienia unik i amunicję, więc INSTRUKCJA i START-HERE pisane raz, na końcu |
| R09 | Złoty romb, stare komentarze, `multikill`, `guardianFell`, SHOTGUN/EXORCIST | zrobione | skan czysty; Mechanics zielone (jedyny błąd `v12-proofs` po R05 poprawiony w tym commicie) |

| G01 | Ucięte napisy, wielokropek jako błąd audytu | zrobione | reguła ELIDED w `ui/skin.lua`; Render znalazł i naprawiono jedno ucięcie |
| G02 | `trail` do widoku | zrobione | `tests/cases/damage_trail.lua` |
| G03 | Priorytety komunikatów, warunek flaski | zrobione | rendery `look-medal-crowded`, `look-low-flask(-empty)` |
| G04 | Powód oczekiwania na unik, kolor odmowy | zrobione | `responsiveness.lua`, render `look-recovering` |
| G05 | Q/F, znaki, niskie HP w niszach | zrobione (czeka na zgodę właściciela na wygląd) | grafiki Codexa w `game/assets/art/icons`; geometry 0 uwag |
| G06 | Seria przy wierszu broni | zrobione | razem z G01 (`look-chain`) |
| L02 | Odpoczynek przy czuwającym stworze (D1) | zrobione | `pilgrimage.lua` |
| L03 | Amunicja ze stworów (D2) | zrobione, liczby do strojenia po L01 | `tests/cases/drops.lua`; `run/drops.lua`, pole `ammo` stworów |
| L04 | Nauka: strona zasad i lekcje | zrobione (ocena właściciela) | `tests/cases/lessons.lua`, render `look-help`; ilustracje Codexa w `game/assets/art/rules` |
| L05 | Alarm i grupy zamiast kolejki (D4) | zrobione | `responsiveness.lua` (sight); patrole nave_4 i crypt_3 |
| L07 | Przyczyna śmierci | zrobione | `pilgrimage.lua` (causes), render `look-dead` |
| L09 | Unik tylko na wytrzymałości (D3) | zrobione | wspólny commit z Etapem 1 (te same pliki) |

| E01 | Retry między obszarami | zrobione | `pilgrimage_save.lua` (areas) |
| E02 | Powrót do menu | zrobione | `mode_lifecycle.lua`; benchmark: pierwsza klatka menu 22–27 ms |
| E03 | Scenariusz kaplicy, CI, „Report was not written” | zrobione | `tests/cases/chapel_route.lua`; ręczne uruchomienia piszą do `work/qa-direct` (`Release.handOutput`); CI zostaje przy Architekturze, powód niżej |
| E04 | Sprzęt odniesienia i pomiar A/A | zrobione (odsłuch: właściciel) | `game/docs/DEVELOPMENT.txt`, ODBIOR-0.42 |
| L06 | Próg nawy | zmierzone, liczby czekają na L01 | tabela niżej; zmieniłem tylko rozsądny kształt alarmu (1 krok, w strefie) |
| L08 | Progi serii | czeka na L01 i L06 | progi stroi się pod gęstość po próbie człowieka |
| L01 | Próba właściciela | scenariusz gotowy | `PROBA-WLASCICIELA.md` |

CI: `TEST.ps1 -Suite Mechanics` uruchamia LÖVE z oknem i rysuje (OpenGL 3.3). Runnery GitHub nie gwarantują takiego sterownika, więc CI zostaje przy Architekturze i formacie. Pełne Mechanics, Input, Render i narzędzia idą lokalnie przez `BUILD.ps1`.

„Report was not written by run”: `TEST.ps1` zawsze ustawia `SIGIL_UI_QA_DIR=work/qa` i identyfikator przebiegu. Ręczne uruchomienie bez tej zmiennej (sonda, `--chapel-look`, `--suite=`) pisało jednak do tego samego `work/qa`. Puszczone równolegle z TEST-em nadpisywało jego raport „direct invocation”, a bramka słusznie odrzucała obcy raport. W audycie obie strony puszczały takie rzeczy równolegle. Teraz ręczne uruchomienia piszą domyślnie do `work/qa-direct`.

Uwagi właściciela w trakcie: paczki naboi na podłodze za jaskrawe (zrobione: światło kaplicy zamiast stałego blasku, bez podskakiwania, render `look-ammo-drops`); do zrobienia: czerwony X zabójstwa zbyt rzucający się w oczy (po Etapie 3: przegląd rozwiązań CoD i innych gier, ewentualnie grafika Codexa).

## Pomiar trudności po D1–D4 (bot, 6 minut, sonda bez okna)

Sonda: bot `qa/souls_bot` przechodzi kaplicę od pierwszego ogniska do sanktuarium, potem do pozostałych ognisk, przez 6 minut gry, przy 0 / 10 / 30% chybień i dwóch ziarnach. Liczy śmierci, ogniska, zrzuty, strzały i odmowy odpoczynku. Audyt (0.41): chybienia 0 dawały 3 śmierci i sanktuarium po 137–188 s.

| Wariant | 0% chybień | 10% | 30% |
|---|---|---|---|
| alarm bez ograniczeń (pierwsza wersja L05) | 13 śmierci, brak sanktuarium | 17 | 21 |
| bez alarmu (sam koniec kolejki) | 9, sanktuarium 124 s | 14 | 18 |
| alarm 1 krok w strefie, prosta droga co 0,15 s (stan obecny) | 9 i 7, brak sanktuarium | 12 i 10 (raz sanktuarium 221 s) | 20 i 18 |
| jak wyżej, seenRange 12 zamiast 18 (tylko próba) | 12 i 5 (raz sanktuarium 317 s) | 10 | – |

Wniosek: D3 i D4 wyraźnie podniosły trudność nawy dla bota. Liczb balansu nie ruszam przed próbą właściciela (zasada: jedna zmienna, po człowieku). Pierwsza zmienna do rozważenia po próbie: zasięg „widzę go przed sobą” (`combat_defaults.senses.seenRange`) albo rozstawienie progów sal (west_1/2, east_1–3).

Zawieszenie sondy: z sondą bez okna (własny `main.lua`) pojedyncze odcinki gry liczyły się po 200 ms na krok. W prawdziwej grze, z jej `main.lua` i limitami JIT, 6 minut tej samej trasy liczy się w 27 s (`tests/cases/chapel_route.lua` wydłużone na próbę). To patologia JIT-a w środowisku sondy, nie błąd gry. Każdy zapis diagnostyczny ją usuwał. Przy okazji profil pokazał, że największym kosztem kroku jest próba prostej drogi stworów wracających na posterunek (`W.clear`). Ograniczyłem ją do 8 m i sprawdzania co 0,15 s.

## Notatki

- R01: `P.save` (`game/src/run/pilgrimage.lua`) zeruje `dirty` i `waited` dopiero po wyniku zapisu. Przy odmowie `dirty` zostaje (także dla zapisów trwałych: ognisko, drzwi, śmierć), a `waited = 0`, więc kolejna próba przychodzi po `K.saveEvery` spokoju. Wynik zapisu jest paragonem w dzienniku (`storage/execution.lua`), więc powtórka zachowuje się tak samo.
- R02: nowy `game/src/run/actor_reset.lua` (`Reset.actor(g, p)`) zastąpił `Reset.actor` z `run/field/reset.lua` (tam zostało `Reset.session`). Wołają go `refresh` w `run/pilgrimage.lua` (start, odpoczynek, zakup, retry, podróż) i `run/test_field.lua` (reset próby). Nowe `Cast.stop` w `combat/abilities.lua` kończy rzucanie bez opłaty. Przy okazji wyszedł trzeci błąd: picie rozpoczęte przed odpoczynkiem kończyło się po nim i zjadało ładunek z napełnionej flaski. Złoty wzorzec: oba przejścia kaplicy zmieniają się po pierwszej śmierci (retry bez odrzutu i efektów), poligon bez zmian.
- R03: `Chain.kill(g, p, weapon)` bierze `event.weapon` z `EnemyKilled` (`session/listeners.lua`). Broń ustawia tylko `combat/volley.lua` (`self.profile.id`; tryb dodatkowy dziedziczy `id`). Zabójstwo bez broni wraca bez zmian w serii. Złoty wzorzec może się zmienić, jeśli bot zabija ładunkiem: sprawdza to pełne Mechanics po R04.
