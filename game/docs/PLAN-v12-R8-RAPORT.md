# Plan v12, etap R8: raport

Rzecz świata to jedna deklaracja `Entities.define` w `session/entities.lua`.

## Co się zmieniło

- Pula `entities` (tablica `g.things`), prefab `entity`, stan w `state`, który zapis
  trzyma jak jest. Pole `system = { after, step }` wstawia krok po nazwanym systemie:
  `Scheduler.after`, bez kosztu, gdy nic nie jest zadeklarowane.
- Strzał, wybuch i pocisk rycerza spotykają rzecz z `hittable` (`Entities.ray`,
  `Entities.within`), rycerz zatrzymuje się na `collides`, klawisz użycia działa na
  `interact`, rysunek idzie przez jeden wpis `WorldObjects`.
- `Bodies.targets`: to, co strzał może znaczyć.

## Dowody

- Próby w `tests/support/extension/r8.lua`, bez zmian w `game/src`: wieżyczka sama
  strzela do demonów i przechodzi przez zapis, beczka wybucha po rozbiciu, postać
  odpowiada na klawisz użycia, dźwignia otwiera i zamyka drzwi.
- `TEST.ps1 -Suite Mechanics`: 5934 sprawdzenia, złoty wzorzec bez zmian.

## Odstępstwa

- `enemy-pool-reads` kończy się listą uzasadnionych odczytów, zgodnie z planem:
  każdy z nich znaczy demona, a nie cel. `combat/bodies.lua` jest wyłączone jako
  miejsce, które definiuje cele.
- Rzecz zatrzymuje tylko rycerza. Stwory i tory ich ruchu jej nie widzą: wieżyczka
  na drodze demona stoi jak duch. Do poprawy, gdy powstanie pierwsza produkcyjna
  rzecz z `collides`.
- Pociski demonów nie trafiają w rzeczy, tylko pociski strony rycerza.
