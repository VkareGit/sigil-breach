# Postęp planu po audycie z 2 listopada 2026 (dla kolejnego agenta)

Plan i kryteria: `RAPORT-KONCOWY.md` w tym katalogu. Właściciel zatwierdził Etap 0 (R01–R09) 2026-11-02 i zdecydował D7: Furfur daje 150 dusz, tyle co Margrave. Pozostałe decyzje (D1–D6) są otwarte, więc Etapy 1–4 czekają na zgodę.

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
| R04 | Egzekucja z zasłoną i pionem | do zrobienia | |
| R05 | Liczby HP i wardu | do zrobienia | |
| R06 | frame-watch i sprostowanie ODBIOR 0.40 | do zrobienia | |
| R07 | Furfur 150 dusz | do zrobienia | |
| R08 | Dokumenty wejściowe | do zrobienia | |
| R09 | Złoty romb, stare komentarze, `multikill`, `guardianFell`, SHOTGUN/EXORCIST | do zrobienia | |

## Notatki

- R01: `P.save` (`game/src/run/pilgrimage.lua`) zeruje `dirty` i `waited` dopiero po wyniku zapisu. Przy odmowie `dirty` zostaje (także dla zapisów trwałych: ognisko, drzwi, śmierć), a `waited = 0`, więc kolejna próba przychodzi po `K.saveEvery` spokoju. Wynik zapisu jest paragonem w dzienniku (`storage/execution.lua`), więc powtórka zachowuje się tak samo.
- R02: nowy `game/src/run/actor_reset.lua` (`Reset.actor(g, p)`) zastąpił `Reset.actor` z `run/field/reset.lua` (tam zostało `Reset.session`). Wołają go `refresh` w `run/pilgrimage.lua` (start, odpoczynek, zakup, retry, podróż) i `run/test_field.lua` (reset próby). Nowe `Cast.stop` w `combat/abilities.lua` kończy rzucanie bez opłaty. Przy okazji wyszedł trzeci błąd: picie rozpoczęte przed odpoczynkiem kończyło się po nim i zjadało ładunek z napełnionej flaski. Złoty wzorzec: oba przejścia kaplicy zmieniają się po pierwszej śmierci (retry bez odrzutu i efektów), poligon bez zmian.
- R03: `Chain.kill(g, p, weapon)` bierze `event.weapon` z `EnemyKilled` (`session/listeners.lua`). Broń ustawia tylko `combat/volley.lua` (`self.profile.id`; tryb dodatkowy dziedziczy `id`). Zabójstwo bez broni wraca bez zmian w serii. Złoty wzorzec może się zmienić, jeśli bot zabija ładunkiem: sprawdza to pełne Mechanics po R04.
