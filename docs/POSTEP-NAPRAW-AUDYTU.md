# Postęp napraw po audycie (dla kolejnego agenta)

Polecenie użytkownika: naprawić wszystko po kolei, nie omijać, skończyć dopiero gdy wszystko jest naprawione. Po każdym punkcie commit i wpis tutaj.

Audyt, z którego biorą się punkty: `work/audit/claude.md`, `work/audit/codex-report.md` (katalog `work/` nie jest w git, ale leży na dysku).

## Zasady, które obowiązują

- Odpowiedzi do użytkownika po polsku. Wszystko w grze i na nagraniach po angielsku. Dokumenty w `game/docs` po polsku.
- Bossów i mechaniki mobów nie ruszać. Margrave i Furfur to na razie zwykłe najtrudniejsze moby.
- Usuwać, nie przenosić. Stary kod odzyskuje się z commitów.
- Nie zostawiać niczego „bo duże”.
- Commit: `git -c user.name=Nahiko -c user.email=psmietanawork@gmail.com commit -F <plik>`, plik bez BOM, na końcu trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Dodawać `git add -u` plus jawnie nowe pliki. Nigdy `git add game`: nie wolno zgarnąć `game/docs/PORADNIK-EDYCJI-GRY.md` ani `docs/podrecznik-codex/`, to pliki użytkownika.
- Bez `git push`, chyba że użytkownik poprosi.
- Nie edytować `game/` w trakcie `TEST.ps1` ani `BUILD.ps1` („Source changed”).
- Testy: `.\TEST.ps1 -Suite All`. Format: `.\toolchain\stylua\stylua.exe --config-path .stylua.toml --color Never -- game/src game/qa game/tests`.
- Pojedynczy zestaw: `toolchain\love-11.5-win64\lovec.exe game --suite=<id>` z `SIGIL_UI_QA_DIR` ustawionym na `work\qa-v33`; wynik w `work/qa-v33/suite-<id>-results.txt`.
- Grafika, nowe modele i nagrania idą do Codexa astra (`gpt-6-astra`, high lub xhigh), nie ręcznie.

## Punkty

| # | Punkt | Stan |
|---|---|---|
| 1 | Zapis: walidacja, migracja, nie blokuje startu | zrobione |
| 2 | Moment zapisu: żadnego zapisu na dysk przy zabójstwie | zrobione |
| 3 | Powtórka sesji zaczętej z zapisu | zrobione |
| 4 | Testy na prawdziwej mapie, walidacja danych drogi | zrobione |
| 5 | Obszary, ruina na mapę, przejście między obszarami, sloty zapisu | zrobione |
| 6 | Kit w zapisie, ekonomia ognisk (śluby zamiast amunicji) | zrobione |
| 7 | Wydajność i bramka pomiarów | zrobione |
| 8 | Zależności: rejestr trybów, 241 leniwych require, haki testowe w produkcji | zrobione |
| 9 | Drobne blokady: sloty sklepu, klucz `z * 100 + x`, jedna wersja, nazwy qa-v33, narzędzia | zrobione |
| 10 | Selftest zgłasza wszystkie błędy, CI, podział długich funkcji | zrobione |
| 11 | Pełny BUILD 0.39, ZMIANY i ODBIOR, raport końcowy po polsku | zrobione |

## Szczegóły pozostałych punktów

**4.** Funkcja walidująca dane drogi wobec mapy: ogniska, drzwi, posterunki i patrole stoją na chodliwych, osiągalnych polach, a `creature` istnieje. Test dla wszystkich obszarów. Przypadek integracyjny na `proving`: trasa do każdego ogniska, drzwi, zakup, odpoczynek i śmierć, stacje poligonu, przejście bota.

**5.** `content/pilgrimage.lua` ma już `Way.areas` (Registry), `Way.start()`, `Way.fireOf`, `Way.doorOf`. `g.run` ma `area`, `ruins`, `slot`. Brakuje: przejścia między obszarami (podmiana świata, `Encounter.clearWorld`, `Destruction.restore`, przygotowanie świata przez Application), startu z zapisu w innym obszarze niż `session.map`, wyboru slotu w menu (zapamiętany w Preferences, `app.sessionOptions.pilgrimage`). Test na drugim tymczasowym obszarze na mapie `floor`.

**6.** Dopisać do sekcji zapisu `loadout`, `abilities`, `vows` (wersja sekcji zostaje 2, bo 2 nie wyszła jeszcze w wydaniu; nieznane id odrzucać jak w `known`). Sklep ogniska: trwałe śluby (np. większa manierka, większy ward, rosnące ceny) przez listę ofert zależną od trybu zamiast bezużytecznej amunicji, która po odpoczynku zawsze mówi RESERVE FULL. `r.vows` działają w `refresh`. Poligon zostaje przy starych ofertach. Teksty po angielsku.

**7.** `enemies/target.lua` (nearest odwiedza wszystkie ciała; kolejność remisów musi zostać, żeby złoty wzorzec się nie zmienił), `combat/projectiles.lua:122`, skok p95 przy 144 ciałach, odcinanie poza widokiem w `render/passes/sprites.lua:12` i `enemy_marks`, `render/kit/halls.lua`, ładowanie tylko potrzebnych gatunków w `render/fresco_enemies.lua`, limit `nav.toward` (`world/navigation.lua:162`), limit `remains`, `MEASURE.ps1` z kodem błędu przy REGRESSION, scenariusz kaplicy w `qa/core_measure.lua` (tam też stara linia o limbo i słowo waves). Pomiary tłumu są zaszumione: czytać fazy i jit.profile, nic nie puszczać obok.

**8.** Rejestr trybów do `session/modes`, żeby session nie importował run, plus reguła w `tools/check`. Wyciągnąć leniwe require tam, gdzie nie ma cyklu. Usunąć z produkcji `Capabilities.recognise`, pola `test` w trybach, rekordy ręczne w testach.

**9.** `shop_weapon_*` tylko 1–9 (`app/commands.lua:129`), `z * 100 + x` w `render/kit/chapel.lua:510,558`, wersja w jednym miejscu (`core/build.lua:18`, `app/release.lua:5`, `content/text.lua:473`), nazwy `work/qa-v33` i `sigil-breach-qa-v33`, `tools/verify.ps1:203`, twarda ścieżka `tools/gen/codex-gen.sh:7`, blokady `BAKE-HIT-MASKS.ps1:14` i `tools/build.ps1:123`, nieaktualne komentarze.

**10.** `qa/report.lua:64` przerywa na pierwszym błędzie: ma iść dalej i upaść na końcu, `tools/verify` oczekuje jednego podsumowania. Dodać `.github/workflows` (tu nie da się uruchomić, powiedzieć o tym). Podzielić `feel.lua F.update`, `world_mesh build`, `projectiles P.update`, `Journal.replay`, `hud H.draw`, `ai.lua`; pilnuje złoty wzorzec.

**11.** BUILD wymaga sekcji `ZMIANY-0.39.txt` i `ODBIOR-0.39.txt` na górze `game/docs/ZMIANY.txt` i `game/docs/ODBIOR.txt`.

## Dziennik
- Punkty 1–3: sekcja `pilgrimage` ma wersję 2 z migracją z 1. `unpack` odrzuca złe typy i wyrzuca id, których gra już nie ma. `P.init` próbuje kopii od najnowszej (`Save.candidates`), każda nieudana zostawia nowy bieg, a gdy żadna nie działa, pliki idą pod `.damaged` (`Save.quarantine`), nie są kasowane. `Save.write` nie podmieni zapisu czymś, czego czytnik by nie przyjął. Zabójstwo tylko ustawia `r.dirty`; zapis po `K.saveEvery` s, gdy nikt nie czuwa, albo przez `game:act('flush')` z `Application:flushSave`. Odpoczynek, śmierć, zakup, drzwi, odzyskanie dusz i podróż zapisują od razu. `P.construction` zwraca `{slot, origin, saves}`, a powtórka nie czyta dysku. `Execution.read` usunięte. Testy: `tests/cases/pilgrimage_save.lua` (94 sprawdzenia), `tests/input.lua`.
- Punkt 4: dane drogi mają kontrakt przy rejestracji (id unikalne, pierwsze ognisko własne) i `P.problems(area)` sprawdza każde ognisko, drzwi, posterunek i patrol wobec mapy, z wysokością kroku; kaplica przechodzi. `tests/cases/proving.lua`: bot dochodzi do każdego ogniska i drzwi na prawdziwej mapie, handel po odpoczynku, wszystkie komory i stacje poligonu na `proving`. Bot (`qa/souls_bot.lua`) omija cokoły, bo liczy wysokość kroku. Ekran mapy w trybie poligonu miał się wywalić na braku obszaru, poprawione.
- Punkt 5: `r.area` wybiera obszar, `r.ruins[mapa]` trzyma ruinę każdej mapy. `enter` przechodzi między obszarami i podmienia świat, `stand` stawia świat obszaru. Drzwi mogą prowadzić do innego obszaru (`leads`), podróż między ogniskami przechodzi przez wszystkie obszary, start z zapisu staje na mapie obszaru. Application maluje nowy świat na stronie ładowania (`prepareWorld`). Sloty: `P.file(slot)`, `settings.slot`, przycisk `save_slot` w menu, `app:useSlot`. Test na tymczasowym obszarze `annex` na mapie `floor`.
- Punkt 6: sekcja zapisu trzyma `loadout`, `abilities`, `vows` (wersja dalej 2, bo 2 nie była wydana). Ogniska sprzedają trwałe śluby (`vow_flask`, `vow_ward`, `vow_vigor`, oferty `kind='vow'` z rangą i rosnącą ceną) i grawery; amunicja, naprawa i ładunki zostały na poligonie (`sold='field'`), lista przez `E.offersFor(g)`. `swear` w `refresh` przelicza kit od postaci w górę. `Abilities.capacity` z `state.extra`. Ikony ślubów to istniejące ikony; nowe mógłby zrobić Codex, nie blokuje. Application: przygotowanie nowego świata tylko przy zmianie w symulacji, nie przy powrocie do menu.
- Punkt 7: wybór celu nie przechodzi tłumu dla każdego stwora (`Bodies.sides` raz na takt, `Bodies.eachCreature`, kolejność remisów bez zmian), pociski najpierw sprawdzają odległość, ciała, cienie, znaki i części hal za kamerą nie są przygotowywane (`R:behind`), gatunki ładują się na żądanie i na stronie ładowania (`FrescoEnemies.onDemand`, `R:prepareCreatures`, handler `creatures`), start około 7,0 s zamiast 8,3 s. Limity: `tuning.remainsKept` 128, `navigation.fieldsKept` 64, `groundLimit` 2048. `MEASURE.ps1` kończy się kodem 1 przy REGRESSION i INCONCLUSIVE. `qa/core_measure.lua` mierzy kaplicę. Profil tłumu jest płaski, bez jednego gorącego miejsca; rozrzut p95 przy 144 ciałach wynikał głównie z rozgrzewania JIT.
- Punkt 8: rejestr trybów jest w `session/modes.lua`, tryby rejestruje `run/modes.lua`, a ładuje je `app/application.lua` (korzeń kompozycji). `run/queries` przeniesione do `session/queries`. Nowa reguła `SESSION DEPENDENCY` w `tools/check/main.lua`. Z 222 leniwych require zostało 1 (`app/runtime` lub `app/release`, bo `conf.lua` działa przed modułami LOVE); skrypt hoistu zachowywał kolejność i nie dotykał plików z domknięcia `conf.lua`. Usunięte `Capabilities.recognise` i pola `test`; rekordy ręczne w testach nazywają `mode`. `g.testing` to teraz `g.ephemeral`. `content/enemy_catalog.lua` jest żywym widokiem. Probe poza aplikacją musi sam zrobić `require('src.run.modes')`.
- Punkt 9: zakładki broni bez limitu 9, klucz komórki w `render/kit/chapel.lua` nie zależy od szerokości, wersja tylko w `core/build.lua` (tytuł bez numeru, `menu_release` z parametrem), `work/qa` i `sigil-breach-qa` zamiast starych nazw, tekst w `tools/verify.ps1`, `tools/gen/codex-gen.sh` wyznacza katalog z repozytorium, `BUILD.ps1` trzyma jedną blokadę na całe wydanie, `tools/build.ps1` odmawia pracy poza nią, `BAKE-HIT-MASKS.ps1` kopiuje pod blokadą. Stan `won` usunięty z ekranów, resztki `claimed`, `pending`, `fragment` z rekordu drogi. Skrypty w scratchpadzie używają `work\qa`.
- Punkt 10: `qa/report.lua` idzie dalej po błędzie zestawu i kończy proces błędem na końcu, testy `tests/cases/report.lua` i `qa/tests_report.lua`. `.github/workflows/checks.yml` uruchamia format i architekturę; nie dało się go tu uruchomić, a testy z grafiką zostają lokalnie, bo potrzebują GPU. Podzielone: `F.update` (`player/feel.lua`), `P.update` (`combat/projectiles.lua`), `Journal.replay`, `H.draw` (`ui/hud.lua`), `build` (`render/world_mesh.lua`), a `enemies/ai.lua` z 736 do około 385 linii przez `enemies/walking.lua`, `enemies/styles.lua`, `enemies/separation.lua`. Złoty wzorzec bez zmian, 5729 sprawdzeń.
- Punkt 11: wersja 0.39, `ZMIANY`, `ODBIOR`, `INSTRUKCJA`, `ROZSZERZANIE`, `ARCHITEKTURA`, `DEVELOPMENT` zaktualizowane. Przycisk slotu przeniesiony do stopki, bo wychodził poza pergamin. `BUILD.ps1` przeszedł w całości: selftest, test sterowania, render, narzędzia, paczki poza repozytorium. Wszystkie punkty zamknięte.
