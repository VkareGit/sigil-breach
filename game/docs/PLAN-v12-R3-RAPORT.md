# Plan v12, etap R3: raport

Broń przestała zakładać magazynek, przeładowanie i jeden tryb ognia.

## Co się zmieniło

- `content/ammo/index.lua`: rejestr modeli z jednym interfejsem, produkcyjny
  `magazine` w `content/ammo/magazine.lua`. Definicja ma `ammo = { kind, ... }`.
- `Weapons.meter` zastępuje `Weapons.ammo` w UI. Sklep, zapasy, zapis, tryby i
  rysunek pytają model. `run/economy.lua` pyta `room` i `offer`.
- `content/reloads.lua`: mechanizmy to dane (`stages`, `resume`, `labels`...),
  jeden interpreter w `combat/reload.lua`. Broń ma `reload = { mechanism, speed }`.
  Nieznany mechanizm odpada przy `Weapon.define`.
- `content/triggers.lua`, `Intent.modes`: tryb spustu. Produkcja ma `auto`.
- `secondary` dziedziczy po głównym trybie i może podmienić `fire`, `attack`,
  `delivery`, `cycle`. Wejście `altFire` istnieje, klawisza i HUD-u nie ma.
- Zapadka `ammo-fields` liczy teraz prawdziwe pola i stoi na zerze. Definicje w
  `content/weapons.lua` i stała w `tuning.lua` są wyłączone jako dane.

## Dowody

- `TEST.ps1 -Suite Mechanics`: 5888 sprawdzeń, `Architecture`: 0 uwag.
- Złoty wzorzec bez zmian, zapis magazynka ma ten sam kształt.
- Próby w `tests/support/extension/r3.lua`, bez zmian w `game/src`: ostrze bez
  amunicji i przeładowania z własnym dostarczaniem, karabin z ciepłem i
  stygnięciem, półautomat, seria 3, ładowany strzał, szybsze przeładowanie,
  drugi tryb z własnym atakiem. Ostrze przechodzi przez zapis.
- Negatywne: pole spoza modelu, magazynek bez przeładowania, nieznany mechanizm,
  tryb spustu i model.

## Odstępstwa

- Zapis trzyma dwie wartości na broń, bo tak stoi format SIGIL09. Model z większym
  stanem dostanie je, gdy R7 przebuduje zapis biegu.
- Stan akcji (`open`, `loaded`, `spent`) zostaje w rekordzie broni: należy do
  mechanizmu przeładowania, nie do amunicji.
