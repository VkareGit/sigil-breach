# Plan v12, etap R2: raport

Każdy cios w stworzenie przechodzi teraz jedną drogą (`combat/hit.lua`:
`measure`, `wound`, `answer`, `land`), salwa jest publiczna
(`combat/volley.lua`), a stany, typy obrażeń i reakcje są danymi.

## Co się zmieniło

- `Volley:apply`, `strikeDemon`, `X.strike`, `creatureBlow`, tyk efektu,
  `rules/contact.lua` i `destruction.lua` wchodzą przez `Hit`. Jedyne wywołanie
  `g:damageEnemy` to `Rules.wound` w `rules/hit_response.lua`. Tam mieszka
  rana, bo reguły nie mogą zależeć od `combat/hit.lua`.
- `Delivery` ma pole `observes`, strona strzelca pochodzi z `Bodies.side`,
  `Bodies.law` wybiera prawo ciała.
- `content/attributes.lua`, `combat/attributes.lua`: `modifiers` i `forbids`
  w stanie. `exposed` i `staggered` nie mają już wyjątków w kodzie.
- `content/damage_types.lua`: `armored`, kolor, dźwięk trafienia i lotu. Literówka
  odpada przy definicji: `check` w `Schema`.
- `content/defs/reaction.lua`, `combat/reactions.lua`: zdarzenia `hit`, `kill`,
  `shot`, `miss`, `surface`, `reload`. Źródła w kolejności: broń, modyfikator
  biegu, postać, stany. `EnemyKilled` i `BodyHit` niosą id broni.
- Pociski skończone mogą przebijać ciała: ta sama reguła co promień, zakaz w
  `content/defs/weapon.lua` zniknął.

## Dowody

- `TEST.ps1 -Suite All`: 5760 sprawdzeń, 0 uwag architektury.
- Złoty wzorzec bez zmian po każdej ścieżce.
- 23 klatki przeglądu mapy identyczne z `r1-frames`.
- Zapadki `damage-entry`: 7 → 0, `damage-type-literals`: 9 → 0.
- Próby w `tests/support/extension/r2.lua`, bez zmian w `game/src`: wiązka i
  rykoszet przez publiczną salwę, pocisk przebijający, stan zmniejszający
  pancerz i zakazujący strzału, nowy typ `frost`, broń lecząca przy strzale,
  broń wybuchająca przy zabiciu, stan reagujący za nosiciela.
- Negatywne: literówka w typie, nieznana statystyka, nieznane zdarzenie, reakcja
  w reakcji, cel `struck` w zdarzeniu bez ciała. Wybuch reakcji nie wywołuje
  kolejnej.

## Odstępstwa

- Zapadka `damage-type-literals` nie liczy już `hazards.lua`, `render/effects.lua`,
  `render/passes/hazards.lua` i `player/intent.lua`. Słowa `lightning` i `fire`
  znaczą tam rodzaj zagrożenia i polecenie, nie typ obrażeń.
- Reakcje stanu rejestruje `Reaction.bind`, nie definicja stanu. Efekt reakcji
  nazywa stany, więc pole w stanie tworzyłoby cykl modułów.
- `Rules.wound` zastępuje zapisane w planie `Hit.land` jako jedyne wejście z tego
  samego powodu: reguły nie importują `Hit`.
