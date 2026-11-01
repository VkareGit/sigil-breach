# Plan v12, etap R1: raport

Postać jest definicją (`content/defs/character.lua`, `content/characters.lua`):
ciało, ruch, zestaw startowy i prezentacja. Aktor nosi `character`, `maxHp`
i `maxArmor`. Stałe ruchu z `Tuning`, `Archetypes.player` i `Rules.playerBody()`
bez aktora zniknęły. Próg niskiego zdrowia to jeden udział 0,30.

## Dowody

- `TEST.ps1 -Suite All`: 5729 sprawdzeń, 0 uwag architektury.
- Złoty wzorzec i fixture v033 bez zmian, zapisy starsze wczytują się przez
  migrację sekcji `pools` do wersji 3.
- 23 klatki przeglądu mapy identyczne piksel w piksel z `r0-frames`.
- Zapadka `player-body`: 26 → 0.
- Próba `trial_warden` w `tests/cases/v12_proofs.lua`: 60 HP, własny udział
  osłony, ruch ×1,4, trzy uniki, zapis i wczytanie, bez zmian w `game/src`.

## Odstępstwo

`presentation` postaci istnieje, ale HUD czyta dziś stałe portrety. Pole czeka na
pierwszą postać z własnym portretem. Pomiar kosztu odbędzie się po R2, zgodnie z planem.
