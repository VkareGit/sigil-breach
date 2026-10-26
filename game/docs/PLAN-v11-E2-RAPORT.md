# Plan v11, etap E2: własność stanu trybów i kontrakt widoków (C2)

Raport odbioru E2 planu `PLAN-FUNDAMENT-v11.md`.

## Tabela własności (wiersze E2)

| Pole 0.33 | Właściciel teraz | API | Kto czyta |
|---|---|---|---|
| `bossSpawned`, `bossDead` | rekord spotkania `g.encounter` (`session/encounter.lua`), wspólny dla trybów | `Encounter.guardianArrived/guardianFell/setGuardian`, odczyt `guardianSpawned/guardianDead` | prezentacja przez `Queries.world(g).guardianSpawned/guardianDead` (muzyka, wyjście, HUD-y, mapa) |
| `secretFound` | świat mapy: `g.world.secretFound` | zapis: classic (odkrycie), wyprawa (odtworzenie z sekcji `run`), poligon (reset) | `Queries.world(g).secretFound` (sigil, rekwizyt) |
| `seals` | wyliczane: `World.activeSeals(world)` (zniszczone `world.seals[i].active`); `World.breakSeals(world, n)` | bez osobnego licznika | cel classic, wynik classic, rzut stanu |
| `rank`, `bestScore` | rekord classic w `g.modeData` | `run/classic.lua` (koniec próby) | ekran końca przez `Queries.result(g)` |

Sekcja `run` checkpointu wyprawy ma format bez zmian (`secret`). Pole sesji
`seals` było tylko kopią stanu świata, więc nie było zapisywane osobno.

Pola `score`, `kills`, `damageTaken`, `combo` i `comboTimer` przechodzą do
aktora w E3.

## Mechanizm stanu trybu

- `g.run` (wyprawa), `g.testField` (poligon) i `g.modeData` (classic i każdy
  nowy tryb) to rekordy trybów nazwane w rejestracji (`record`). Nazwy
  zostają.
- Wspólne haki `Modes` to `reset`, `snapshot`, `load`, `save` i
  `Modes.record(g)`.
- Logika areny classic przeszła z `session/interactions.lua` do
  `run/classic.lua`: sekret, pieczęcie, strażnik, wyjście, nagrody, ranga
  i najlepszy wynik. W `session/interactions.lua` zostały tylko zapasy.
- Nowe pole sesji: `encounter` (rekord strażnika). Z katalogu pól zniknęły
  `seals`, `secretFound`, `rank`, `bestScore`, `bossSpawned` i `bossDead`.

## Kontrakt widoków (`run/queries.lua`)

- **Właściciel:** widok należy do sesji. Każda sesja ma słabo trzymaną
  tabelę na każdy rodzaj widoku, a dwie sesje nigdy nie dzielą tabeli.
  Budowniczowie z `run/mode_views.lua` wypełniają tabelę sesji. Tryb może
  też zwrócić własną tabelę, a zapytanie przejmuje jej pola.
- **Ważność:** do następnego kroku symulacji (`g.time`) albo polecenia
  (`Game:act` → `Queries.command`). Wywołanie w tym samym kroku zwraca ten
  sam obiekt, wypełniony od nowa.
- **Zachowanie:** `Queries.copy(view)` daje głęboką kopię na własność.
  `Queries.valid(g, view)` wykrywa widok trzymany za długo.
- **Nowe zapytanie:** `Queries.result(g)`. Każdy widok świata niesie stan
  strażnika i sekretu. Mapa rysuje `markers` z widoku świata, bez gałęzi
  trybu.

## Odbiór

- **Zapadka MODE STATE ON THE SESSION:** 0 (z 53 w 12 plikach).
- **ACTOR STATE:** bez zmian, 172. Wpis 6 odwołań przeszedł razem z kodem
  z `session/interactions.lua` do `run/classic.lua`.
- **Złoty wzorzec:** te same skróty.
- **Rzut stanu 0.33** (`v033-reference`): identyczny we wszystkich
  przebiegach, także w próbie wyprawy z zapisem i wczytaniem. Fixture
  SIGIL09 wczytują się do rzutu 0.33.
- **Rendery:** 606/606 identyczne z `work/v11-render-base`.
- **Bramki:** format, 0 naruszeń architektury, Mechanics 4164 sprawdzeń;
  Input, Render i Tools przechodzą.
- **Test przeplatania (`mode-state`):**
  - widoki wyprawy i classic czytane na przemian zachowują swoje wartości;
  - dwie wyprawy nie dzielą tabeli;
  - widok trzymany przez następny krok jest wykryty jako nieważny (test
    negatywny);
  - widok sprzed polecenia też jest nieważny;
  - kopia zostaje.
- **Próba rozszerzenia „ołtarze”** (test, nie menu): pełny cykl.
  - Start i postęp: zniszczone ołtarze, cel w HUD, znaczniki mapy z widoku
    świata.
  - Ołtarze rysuje zarejestrowany obiekt świata.
  - Własna sekcja `Save.declare` zapisana i odtworzona z pliku.
  - Zakończenie (stan `won`), odtworzenie dziennika do tego samego końca,
    `reset`, czysty restart.
  - Bez nowego pola sesji, bez gałęzi w ekranach.

Pomiar przed/po (protokół): raport zbiorczy pomiarów
`PLAN-v11-POMIARY.md`.
