# Plan walki souls, etap S5: raport

Nowe efekty czarów. Modele, atlasy stworów, HUD i broń są nietknięte.

- `assets/art/rites-fresco-v36.png`: płonąca fala, krąg ciszy, cięcie z popiołu,
  promień gwiazd. Cztery obrazy z Codexa `gpt-6-astra` na `high`, z istniejącym
  atlasem zaklęć i zagrożeń jako wzorcem. Pochodzenie w
  `assets/art/rites-provenance-v36.json`.
- `render/hazard_kinds.lua`: fala i krąg są malowane na podłodze, promień tnie
  posadzkę do pierwszego kamienia, burza znaczy podłogę wokół kręgu i uderza w
  rytmie pulsów.
- Cięcie (`Action.trait(spec, 'cuts')`) stoi w powietrzu przez okno ciosu i chwilę
  po nim, rysowane gładko, nie przez cieniowanie sprite'ów.
- `Blinked` i `Seized` mają dźwięk, drobiny i wstrząs widoku.
- `qa/reviews/souls_moves.lua`, flaga `--souls-review`: 93 klatki 21 ciosów z gry.

Animacje ciosów korzystają z namalowanych póz i ruchu. Nowych klatek ciał nie ma:
istniejące pozy tasaka i poroża czytają się dobrze, a każdy nowy atlas ciała groził
odejściem od modelu.
