# Plan walki souls, etapy S2, S3, S4: raport

Sześć istot walczy według planu. Modele, atlasy i HUD się nie zmieniły: nowe ciosy
używają istniejących póz (`windup`, `strike`, `phase.cinders`, `phase.tempest`).

## Istoty

| Istota | Zmiana |
|---|---|
| Żar | Pazur 28, ciąg z opóźnionym drugim pazurem, skok przechodzący w pazur, odskok po długim ciągu |
| Żelazny | HP 260, nogi słabym punktem, szeroki zamach, zwód szarżą 38, wbicie z falą |
| Akolita | Gwiazda 26, trzy gwiazdy kolejno, promień z ostrzeżeniem, teleport z bliska |
| Ogrodnik | HP 220, narastająca zgnilizna, korzenie zatrzymujące, spóźniony wybuch |
| Margrabia | HP 2400, trzy akty: tasak w ciągach do 3 ciosów, pochwycenie, doskok z falą; ogniste cięcia i wezwanie dwóch Żarów; wielka fala z długim odsłonięciem |
| Furfur | HP 2800, trzy akty: poroże w ciągach, szarża z dwoma zwrotami, burza idąca za graczem; krzyż piorunów i odskok z piorunem; cała sala z wędrującym kręgiem |

## Odstępstwa od projektu

- Żar i Akolita zachowują HP 112 i 76. Podwójne zabójstwo salwą i śmierć Akolity
  od jednej salwy to reguły broni. Testy pilnują ich od 0.20. Trudność idzie z
  obrażeń i rytmu.
- Bossowie mają 2400 i 2800 zamiast 1600 i 2000. Bot z idealnym celem kończył
  pierwszą wersję w 17 s, zanim zobaczył trzeci akt.
- Boss zadaje tyle, że amunicja stała się ograniczeniem: bot kończył bieg z pustą
  bronią. Stąd dwie zasady: progi zostawiają rundy i zdrowie, a rycerz bez ani
  jednej rundy przy żyjącym strażniku znajduje mały zapas obok siebie.
- Gdy Furfur wzywa całą salę, stoi wyczerpany do końca burzy. Inaczej krzyż
  piorunów wypychał z jedynego bezpiecznego kręgu.

## Dowody

- `tests/cases/souls_bots.lua`:

| Starcie | Bot nieuważny | Bot uczący się |
|---|---|---|
| Margrabia | ginie po 11,5 s | wygrywa w 18,5 s, zdrowie 100 |
| Furfur | ginie po 6,7 s | wygrywa w 25,7 s, zdrowie 100 |
| Stado 6 istot | ginie po 6,3 s | wygrywa w 11,2 s, zdrowie 100 |

- Każdy cios każdej istoty, osobno, z odległości, do której jest zrobiony: bot
  uczący się nie dostaje ani raz.
- Pełna wyprawa z botem znającym strażnika kończy się wygraną.
- `TEST.ps1 -Suite Mechanics`: 5861 sprawdzeń, nowy złoty wzorzec opisany w
  `tests/golden/baseline.lua`. Sam silnik S1 odtwarzał stary wzorzec.

## Czego boty nie mówią

Bot ma idealny cel i zna każdy telegraf. Pojedyncze stwory giną mu w 2-4 s, więc o
ich trudności mówi stado, nie test pojedynczy. Czas walki z bossem i przyjemność
ocenia człowiek.
