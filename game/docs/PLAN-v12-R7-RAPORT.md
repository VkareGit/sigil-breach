# Plan v12, etap R7: raport

Bieg to lista etapów, a dziewięć kręgów stało się kwestią danych.

## Co się zmieniło

- `content/runs.lua`: bieg, etap z mapą i falami, `Runs.total`, `Runs.guardian`,
  `Runs.wave`, `Runs.following`. Wyprawa to bieg jednoetapowy.
- `Descent.nextStage`: nowy świat, ci sami aktorzy, pule czyszczone. Etap i plan
  idą przez zapis; bieg jednoetapowy zapisuje się jak dotąd.
- `content/glyphs.lua`: rejestr. Zapis czyta rejestr zamiast listy trzech słów.
  Bieg może nosić listę glifów (`glyphs`), produkcja zostaje przy jednym.
- `content/supplies.lua`: ikona i rozmiar zapasu z definicji, nie z warunku w
  `render/world_art.lua`. `Shop.define`, `Shop.undefine`: oferty.
- Mapa nie ma już wartości domyślnej: `W.new` wymaga mapy, tryby biorą pierwszą
  mapę wyprawy.

## Dowody

- Próby w `tests/support/extension/r7.lua`, bez zmian w `game/src`: trzy etapy na
  dwóch mapach, zapis między nimi, koniec biegu, dwa glify naraz, nowy zapas,
  nowa oferta.
- Negatywne: etap z nieistniejącą mapą, nieznany glif, przejście poza listę.
- Zapadka `default-map`: 21 → 0.

## Odstępstwa

- Glif daje `set`, `scale`, `spread` i reakcje. Modyfikatorów statystyk nie dostał:
  `Attributes.scale` czyta stany ciała, a glif należy do biegu. Pod ten sam efekt
  można użyć reakcji nakładającej stan.
- Tekst `hud_wave` i ekran końca nadal mówią o jednej wyprawie. Podtytuł etapu
  trzeba dopisać, gdy powstanie drugi krąg.
