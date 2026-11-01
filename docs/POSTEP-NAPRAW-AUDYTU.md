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
| 5 | Obszary, ruina na mapę, przejście między obszarami, sloty zapisu | do zrobienia |
| 6 | Kit w zapisie, ekonomia ognisk (śluby zamiast amunicji) | do zrobienia |
| 7 | Wydajność i bramka pomiarów | do zrobienia |
| 8 | Zależności: rejestr trybów, 241 leniwych require, haki testowe w produkcji | do zrobienia |
| 9 | Drobne blokady: sloty sklepu, klucz `z * 100 + x`, jedna wersja, nazwy qa-v33, narzędzia | do zrobienia |
| 10 | Selftest zgłasza wszystkie błędy, CI, podział długich funkcji | do zrobienia |
| 11 | Pełny BUILD 0.39, ZMIANY i ODBIOR, raport końcowy po polsku | do zrobienia |

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
