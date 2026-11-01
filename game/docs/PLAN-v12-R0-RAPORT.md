# Plan v12, etap R0: raport

Commit startowy: `3109330` (0.35). Bez zmian zachowania.

## Wykonane

- Zapadki w `tools/check` policzone od stanu 0.35:

| Zapadka | Stan startowy |
|---|---|
| `player-body` | 26 w 14 plikach |
| `damage-entry` | 7 w 6 plikach |
| `damage-type-literals` | 9 w 7 plikach |
| `ammo-fields` | 1 w 1 pliku |
| `controlled-abilities` | 4 w 2 plikach |
| `creature-names` | 21 w 7 plikach |
| `tile-literals` | 36 w 12 plikach |
| `default-map` | 21 w 9 plikach |
| `enemy-pool-reads` | 53 w 34 plikach |
| `step-rate` | 6 w 5 plikach |

- `tests/support/extension/proof.lua` i `tests/cases/v12_proofs.lua`: szkielet prób
  rozszerzeń, który sprząta po sobie także przy błędzie.
- Referencje: złoty wzorzec i fixture v033 w repozytorium, klatki 0.35 w
  `work/v12-reference/r0-frames`, pomiar w `work/v12-measure/r0-baseline`.

## Pomiar bazowy (`MEASURE.ps1`, 5 przebiegów)

| Metryka | Mediana | IQR |
|---|---|---|
| Klatka, 20 ciał żywych | 12,29 ms | 7,2 % |
| Klatka, 96 ciał żywych | 19,91 ms | 7,3 % |
| Klatka, 256 ciał żywych | 32,55 ms | 6,3 % |
| Krok, 20 ciał | 0,105 ms | 8,7 % |
| Krok, 96 ciał | 0,528 ms | 5,7 % |
| Krok, 256 ciał | 2,045 ms | 22,2 % |

Rozrzut przekracza próg 5 % protokołu, więc porównania wymagają par z tej samej sesji.

## Zmiana planu

Plan powstał na 0.34. Podstawą jest teraz `3109330`, bo mapa zmieniła się w 0.35.
Numer końcowy R9 przesuwa się na wersję wydaną po walce. Trudność stworów prowadzi
`PLAN-WALKA-SOULS.md`; zmienia wyniki, więc nigdy nie dzieli commita z etapem v12.

`ammo-fields` liczy tylko dostęp przez sesję i pokazuje za mało; R3 poprawi regułę.
