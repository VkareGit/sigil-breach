# Plan v13, W7 na Margrabii: raport

Po uwagach gracza miarą jest wiedza, nie ruch. Karta ciosów: `PLAN-SOULS-v13.md`.

## Co doszło

- **Kontra:** `parry` na ciosie. Strzał w oknie przerywa cios i otwiera egzekucję. Złoty
  krąg pod ciałem pokazuje okno.
- **Pancerz:** `shell`. W zamachu i ciosie Margrabia bierze 30% obrażeń.
- **Odzysk:** 60% straconego zdrowia można odbić trafieniami przez 3,5 s.
- **Pogoń:** `chase`. Unik z ostrzem jest ścigany, unik pod prąd nie.
- **Losowa strona:** `mirror`. Ciało zmienia rękę i pochyla się na stronę cięcia.
- **Losowe opóźnienie:** `shuffle`. Stały rytm przestał wystarczać.
- **Rozgałęzienia:** `branches`. Po cięciu idzie drugie, cios z góry albo nic.
- **Nowe ciosy:** klatka z ognia karze ruch, tupnięcie przyklejenie, cięcie w obrocie
  krążenie, łapanie uniku unik na ślepo.

## Wyniki

| Bot | Wynik |
|---|---|
| Stoi i strzela | ginie po 15,1 s, bossowi zostaje 77% |
| Odruch: ruch i unik w bok | ginie 3 z 3, po 21-50 s |
| Stała strona uniku | ginie 3 z 3, po 53-135 s |
| Zna kartę ciosów | wygrywa 3 z 3, około 63 s, 3 egzekucje |

Ciosy pod ogniem: 0,44 na sekundę wobec 0,45 bez ognia, liczone w czasie, gdy stoi wolny.

## Czego to nie mówi

Bot zna stronę cięcia z danych. Czy człowiek czyta ją ze zmiany ręki i pochylenia,
zobaczy dopiero gracz. Pozostałe pięć stworów ma stare ciosy i zasady wysiłku. Furfur
ma mniej życia niż Margrabia do czasu przebudowy.

Testy: `TEST.ps1 -Suite All`, 0 uwag architektury. Wzorzec hashy zaktualizowany.
