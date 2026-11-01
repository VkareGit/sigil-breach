# Plan v12, etap R4: raport

Zdolności należą do aktora, mają koszt i czas, a jedna akcja ma jedno wykonanie
dla stwora, aktora i punktu w świecie.

## Co się zmieniło

- `Abilities.give`, `rest`, `inventory`, `restore`, `fill` przyjmują aktora.
- `content/resources.lua`, `combat/resources.lua`: `character.resources`
  (`max`, `start`, `regen`), `actor.resources`. Zdolność ma `cost`; domyślnie
  `{ uses = 1 }`, czyli dzisiejszy ładunek.
- Rzucanie: `actor.casting`, system `Knight.casting` po spuście. `windup`,
  `channel`, `toggle`. Koszt płaci się przy wydaniu, więc przerwanie nic nie
  kosztuje. Przerywa stan z `forbids = { 'cast' }`. `windup = 0` działa w tym
  samym kroku co wcześniej.
- `combat/action_kinds.lua`: jeden rejestr rodzajów z wpisem `cast` i cyklem
  życia ataku. `Cast.kinds` i `Attacks.kinds` to widoki tego rejestru.
- `combat/caster.lua`: `Caster.actor`, `Caster.point`, stwór w
  `enemies/ranged_kinds.lua`. Rakieta ma jedną implementację `launch`.
- `Action.defineKind` ma hooki `build`, `validate`. Łańcuch `if built.kind`
  zniknął z `Action.build`.
- Reakcja `action` wykonuje akcję w punkcie. `defaultAction` zniknęło: ładunek
  zawsze niesie swoją akcję.

## Dowody

- `TEST.ps1 -Suite Mechanics`: 5788 sprawdzeń, `Architecture`: 0 uwag.
- Złoty wzorzec bez zmian, klatki przeglądu identyczne z `r2-frames`.
- Zapadka `controlled-abilities`: 4 → 0.
- Próby w `tests/support/extension/r4.lua`, bez zmian w `game/src`: zaklęcie
  dwusekundowe z maną, kanał, przełącznik, rakieta demona u rycerza i z punktu,
  reakcja wykonująca akcję, dwaj aktorzy z osobną maną.
- Negatywne: brak zasobu, przerwany rzut bez kosztu, nieznany koszt, rodzaj bez
  wykonawcy, rodzaj nie do rzucenia odrzucony przy kompozycji sesji.

## Odstępstwa

- Rodzaje ruchu ciała (`lunge`, `charge`, `leap`) nie mają `cast`, bo potrzebują
  ciała w stanie ataku. Zdolność z takim rodzajem odpada przy starcie sesji.
- `fan`, `pool`, `strike`, `pattern` mają na razie tylko ścieżkę stwora. `cast`
  dostaną, gdy któraś zdolność ich zażąda.

## Pomiar po R2 (`MEASURE.ps1`, 5 par, drzewa `6084176` i `a32bfd5`)

Klatki pełne bez regresji (0,994 i 1,037). Klatki i kroki populacji są
nierozstrzygnięte: 256 ciał 1,073 przy IQR 9 %, 96 ciał 1,049, 20 ciał 1,036.
Krok 20 ciał 1,28 przy IQR 34 % to 0,02 ms. Wyniki w `work/v12-measure/r2`.
Nie ma dowodu regresji, ale 256 ciał warto zmierzyć ponownie po R5.
