# Plan v12, etap R6: raport

Pole mapy to wpis z właściwościami, a mapa ma tylko to, czego żąda jej tryb.

## Co się zmieniło

- `core/tiles.lua`: `walkable`, `solid`, `round`, `masonry`, `speed`. Kod pyta
  tablice po kodzie pola, nie liczby 0, 1, 2. Plan chciał `content/tiles.lua`,
  ale fizyka nie może zależeć od treści, więc rejestr stoi w `core`.
- `W.setCell`, `Game:setCell`: zmiana komórki podnosi rewizję, zapis trzyma siatkę,
  dziennik odtwarza polecenie. `W.footing`: tempo na polu.
- `spawn` jest wymagany. `portal`, `ember`, `zones`, `gates` są opcjonalne, tryb
  deklaruje `session.requires`, a sesja odmawia mapy bez nich.
- `Spawner` i `Sanctuary` czytają świat sesji. Znikły `Run.shrine`, `Run.portals`.
- Dane mapy wyszły z kodu: `decor.jointless` zamiast współrzędnych w
  `surface_marks`, brama mapy czytana z `world.portal`, napis bez rozmiaru.
- `core/rate.lua`: jedna stała kroku.

## Dowody

- `TEST.ps1 -Suite Mechanics`: 5900 sprawdzeń, `Architecture`: 0 uwag.
- Złoty wzorzec bez zmian.
- Zapadki `tile-literals`: 36 → 0, `step-rate`: 6 → 0.
- Próby w `tests/support/extension/r6.lua`, bez zmian w `game/src`: płytka woda
  nie blokuje i spowalnia, drzwi przez `setCell` z zapisem i odtworzeniem z
  dziennika, mapa bez Ognia, bram i stref odrzucona przez wyprawę.
