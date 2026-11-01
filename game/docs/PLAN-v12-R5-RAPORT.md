# Plan v12, etap R5: raport

Stwór, zagrożenie i namalowany ruch to wpisy w rejestrach. Kod nie zna już nazw
sześciu istot.

## Co się zmieniło

- `content/enemies.lua`: `A.register`, `A.unregister`. Testy nie wstrzykują już
  pól, tylko rejestrują.
- `content/hazards.lua`, `Hazards.kinds`, `render/hazard_kinds.lua`: definicja,
  wykonawca i rysunek. Sesja odrzuca rodzaj bez wykonawcy, renderer bez rysunku.
- `Action.trait`: `airborne`, `gathers`, `lands` zamiast `kind == 'leap'` w AI,
  animacji i znakach.
- `Anim.motions`: rejestr ruchów, sprawdzany przy kompozycji sesji.
- `ActionKinds.abandon` to jedno miejsce porzucenia oznaczonego zagrożenia;
  uwalnianie przy rzucie należy do rodzaju `strike`.
- Nazwy wyszły z kodu: `appearance.seal`, `content/occult_catalog.lua`
  (`seals`, `margins`, `visits`), `content/field.lua` (`dummy`, `skirmish`).
- Fala przyjmuje własną kolejność ról.

## Dowody

- `TEST.ps1 -Suite Mechanics`: 5797 sprawdzeń, `Architecture`: 0 uwag.
- Złoty wzorzec bez zmian, klatki przeglądu identyczne z `r4-frames`.
- Zapadka `creature-names`: 21 → 0.
- Próba w `tests/support/extension/r5.lua`, bez zmian w `game/src`: stwór z
  własnym gazem, stylem ruchu, ruchem malowanym i linią zagrożeń, widoczny w
  katalogu poligonu.
- Negatywne: nieznany rodzaj zagrożenia, zagrożenie bez wykonawcy, nieznany ruch.

## Odstępstwo

`rotation` zostaje w `content/waves.lua` jako domyślna, ale każda fala może podać
własną. Pełne dane starcia przyjdą z R7.
