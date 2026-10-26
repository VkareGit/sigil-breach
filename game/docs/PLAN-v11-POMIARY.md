# Plan v11: pomiary według protokołu

Protokół jest opisany w `PLAN-FUNDAMENT-v11.md` („Koszt — protokół pomiaru”),
a narzędziem jest `MEASURE.ps1`.

Wariant „przed” to zawsze worktree `work/v11-base` (commit E0, kod gry 0.33).
Wariant „po” to worktree commitu etapu.

Ustawienia każdego pomiaru:
- osobny proces z rozgrzewką 300 kroków lub klatek;
- 2400 kroków i 720 klatek;
- mapa `qa_crowd`, 20/96/256 ciał oraz sceny `complete_*`;
- pary w zmiennej kolejności.

Od pomiaru E2 proces dostaje wysoki priorytet i stałe rdzenie wydajne
(procesory logiczne 2–7). Bez tego procesor hybrydowy (Core Ultra 7 155H)
przenosi proces między rodzajami rdzeni. Właśnie stąd brał się większość
rozrzutu między procesami.

## E1 (worktree `work/v11-e1`, commit `12d4bed`), 5 par

| Metryka | Przed: mediana (IQR) | Po: mediana (IQR) | Po/przed | Werdykt |
|---|---|---|---:|---|
| krok, 20 ciał | 0,1208 ms (5,6 %) | 0,1216 ms (5,5 %) | 1,007 | nierozstrzygnięty |
| krok, 96 ciał | 0,5792 ms (6,6 %) | 0,5544 ms (13,4 %) | 0,957 | nierozstrzygnięty |
| krok, 256 ciał | 2,3224 ms (3,2 %) | 2,4279 ms (6,6 %) | 1,045 | nierozstrzygnięty |
| klatka, scena normal | 4,2005 ms (0,8 %) | 4,2912 ms (5,5 %) | 1,022 | nierozstrzygnięty |
| klatka, scena heavy | 5,4721 ms (2,0 %) | 5,5150 ms (1,5 %) | 1,008 | brak regresji |
| klatka, populacja 20 | 6,6906 ms (5,2 %) | 6,3281 ms (10,0 %) | 0,946 | nierozstrzygnięty |
| klatka, populacja 96 | 12,1937 ms (5,0 %) | 11,9049 ms (13,1 %) | 0,976 | nierozstrzygnięty |
| klatka, populacja 256 | 21,3290 ms (3,1 %) | 21,5831 ms (9,4 %) | 1,012 | nierozstrzygnięty |

Żadna mediana „po” nie przekracza 1,05 × „przed”. Werdykty „nierozstrzygnięty”
wynikają tylko z warunku IQR ≤ 5 %. Rozrzut między procesami jest po obu
stronach i bierze się z maszyny.

Protokół każe powtórzyć pomiar (kolejne 5 par) z ustawieniem przypiętych
rdzeni. Wynik powtórzenia jest w sekcji „E1, powtórzenie” niżej.

## E1, powtórzenie (5 par, wysoki priorytet, procesory logiczne 2–7)

| Metryka | Przed: mediana (IQR) | Po: mediana (IQR) | Po/przed | Werdykt |
|---|---|---|---:|---|
| krok, 20 ciał | 0,1894 ms (3,1 %) | 0,1905 ms (3,5 %) | 1,006 | brak regresji |
| krok, 96 ciał | 0,9495 ms (6,3 %) | 0,9482 ms (7,5 %) | 0,999 | nierozstrzygnięty |
| krok, 256 ciał | 3,8414 ms (33,4 %) | 3,7485 ms (20,1 %) | 0,976 | nierozstrzygnięty |
| klatka, scena normal | 4,9504 ms (0,5 %) | 5,0113 ms (1,7 %) | 1,012 | brak regresji |
| klatka, scena heavy | 6,5525 ms (1,1 %) | 6,5758 ms (1,1 %) | 1,004 | brak regresji |
| klatka, populacja 20 | 7,9246 ms (6,2 %) | 8,9960 ms (16,7 %) | 1,135 | nierozstrzygnięty |
| klatka, populacja 96 | 16,4507 ms (9,9 %) | 17,5960 ms (17,9 %) | 1,070 | nierozstrzygnięty |
| klatka, populacja 256 | 31,1560 ms (7,0 %) | 31,9517 ms (11,4 %) | 1,026 | nierozstrzygnięty |

Przypięcie do sześciu procesorów logicznych spowolniło pomiar (krok 256 ciał
3,8 ms zamiast 2,3 ms) i zwiększyło rozrzut. Dlatego od E3 protokół używa
tylko wysokiego priorytetu, bez przypinania.

Wniosek dla E1:
- Sceny `complete_*` i krok 20 ciał mają IQR ≤ 5 % i nie pokazują regresji.
- Populacje 20/96/256 i krok 96/256 ciał pozostają nierozstrzygnięte
  z powodu rozrzutu maszyny po obu stronach.
- Mediany „po” mieszczą się w ±5 % w pierwszym pomiarze. W powtórzeniu
  wychodzą 1,07 i 1,135, ale przy IQR 17–18 %, czyli wewnątrz rozrzutu.
  Kod E1 nie zmienia pracy na klatkę: wybór klatki to te same porównania
  na danych arkusza.
- Według protokołu nierozstrzygnięty wynik po powtórzeniu liczy się jak
  regresja i wymaga decyzji użytkownika. Wniosek jest przedstawiony
  w raporcie końcowym.
