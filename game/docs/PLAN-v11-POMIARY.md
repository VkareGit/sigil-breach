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

## Kontrola A/A (ten sam kod po obu stronach, 5 par, wysoki priorytet, bez przypinania)

Oba warianty to `work/v11-base`.

| Metryka | Po/przed | Werdykt |
|---|---:|---|
| klatka, scena heavy | 0,983 | nierozstrzygnięty |
| klatka, scena normal | 0,997 | brak regresji |
| klatka, populacja 20 | 0,996 | nierozstrzygnięty |
| klatka, populacja 96 | 1,033 | nierozstrzygnięty |
| klatka, populacja 256 | 1,004 | nierozstrzygnięty |
| krok, 20 ciał | 0,918 | brak regresji |
| krok, 96 ciał | 0,907 | nierozstrzygnięty |
| krok, 256 ciał | 1,033 | nierozstrzygnięty |

Identyczny kod daje mediany w zakresie 0,91–1,03 i IQR powyżej 5 % w
większości metryk. Na tej maszynie warunek „IQR ≤ 5 % po obu stronach” nie
jest osiągalny niezależnie od zmiany. Protokół w obecnej postaci uznałby
każdy etap za nierozstrzygnięty, a po powtórzeniu za regresję.

Rozstrzygnięcie należy do użytkownika (zasada protokołu). Proponowane
kryterium praktyczne: brak regresji, gdy mediana „po” ≤ 1,05 × „przed”
albo różnica median mieści się w rozrzucie A/A danej metryki.

## E2 (worktree `work/v11-e2`, commit `a33705f`)

Pierwszy pomiar (5 par, przypięte rdzenie 2–7):
- sceny `complete_*` bez regresji (1,002 i 1,022);
- populacja 20: 1,059 przy IQR 1–3 %, czyli „regresja” według protokołu;
- reszta nierozstrzygnięta.

Powtórzenie bez przypinania (5 par):

| Metryka | Przed: mediana (IQR) | Po: mediana (IQR) | Po/przed |
|---|---|---|---:|
| krok, 20 ciał | 0,1305 ms (8,1 %) | 0,1310 ms (5,8 %) | 1,004 |
| krok, 96 ciał | 0,6141 ms (3,3 %) | 0,5844 ms (8,5 %) | 0,952 |
| krok, 256 ciał | 2,7407 ms (16,0 %) | 2,9492 ms (12,4 %) | 1,076 |
| klatka, scena normal | 4,0710 ms (5,3 %) | 4,2134 ms (3,2 %) | 1,035 |
| klatka, scena heavy | 5,6444 ms (11,1 %) | 5,4332 ms (5,9 %) | 0,963 |
| klatka, populacja 20 | 6,9140 ms (9,1 %) | 6,8301 ms (4,4 %) | 0,988 |
| klatka, populacja 96 | 12,4545 ms (12,4 %) | 12,6965 ms (8,7 %) | 1,019 |
| klatka, populacja 256 | 22,7526 ms (5,5 %) | 21,5007 ms (5,5 %) | 0,945 |

„Regresja” populacji 20 z przebiegu z przypięciem nie powtarza się
(0,988). Wszystkie mediany mieszczą się w ±5 % oprócz kroku 256 ciał
(1,076), a tam rozrzut po obu stronach to 12–16 % (A/A: 1,033).

E2 dokłada kilka zapytań o widoki na klatkę. Każde zapytanie to wypełnienie
małej tabeli sesji, bez pętli po ciałach.

## E3–E5: końcowe pomiary (5 par, High, bez przypinania)

### E3 — `8797d30`

| Metryka | E0 mediana ms (IQR %) | Po mediana ms (IQR %) | Po/E0 | Ścisły protokół |
|---|---:|---:|---:|---|
| frame complete_heavy20_frozen_fx (ms) | 5.3157 (6.3 %) | 5.3060 (3.0 %) | 0.998 | nierozstrzygnięty |
| frame complete_normal4_frozen_fx (ms) | 4.0927 (3.3 %) | 4.2437 (2.4 %) | 1.037 | brak regresji |
| frame prepared_population_20_live (ms) | 6.7552 (10.7 %) | 6.4178 (9.9 %) | 0.950 | nierozstrzygnięty |
| frame prepared_population_256_live (ms) | 22.6715 (10.5 %) | 21.3813 (11.7 %) | 0.943 | nierozstrzygnięty |
| frame prepared_population_96_live (ms) | 12.5223 (11.0 %) | 11.6560 (7.6 %) | 0.931 | nierozstrzygnięty |
| step 20 bodies (ms) | 0.1266 (1.4 %) | 0.1329 (7.1 %) | 1.050 | nierozstrzygnięty |
| step 256 bodies (ms) | 2.8343 (4.1 %) | 2.4861 (33.0 %) | 0.877 | nierozstrzygnięty |
| step 96 bodies (ms) | 0.6345 (7.0 %) | 0.5849 (11.0 %) | 0.922 | nierozstrzygnięty |

Źródło: `work/v11-measure-final-e3/summary.txt`; pełne próbki i logi obok.

### E4 — `4a03cb4`

| Metryka | E0 mediana ms (IQR %) | Po mediana ms (IQR %) | Po/E0 | Ścisły protokół |
|---|---:|---:|---:|---|
| frame complete_heavy20_frozen_fx (ms) | 5.5669 (15.5 %) | 5.4732 (0.3 %) | 0.983 | nierozstrzygnięty |
| frame complete_normal4_frozen_fx (ms) | 4.0421 (9.6 %) | 3.7898 (10.6 %) | 0.938 | nierozstrzygnięty |
| frame prepared_population_20_live (ms) | 6.3841 (7.0 %) | 6.5142 (20.0 %) | 1.020 | nierozstrzygnięty |
| frame prepared_population_256_live (ms) | 22.7254 (8.7 %) | 18.9008 (22.0 %) | 0.832 | nierozstrzygnięty |
| frame prepared_population_96_live (ms) | 12.2745 (1.8 %) | 10.7363 (35.1 %) | 0.875 | nierozstrzygnięty |
| step 20 bodies (ms) | 0.1095 (13.5 %) | 0.1237 (4.8 %) | 1.130 | nierozstrzygnięty |
| step 256 bodies (ms) | 2.3129 (6.8 %) | 2.3458 (21.6 %) | 1.014 | nierozstrzygnięty |
| step 96 bodies (ms) | 0.6644 (8.7 %) | 0.5614 (0.9 %) | 0.845 | nierozstrzygnięty |

Źródło: `work/v11-measure-final-e4/summary.txt`; pełne próbki i logi obok.

### E5 — `e00c817`

| Metryka | E0 mediana ms (IQR %) | Po mediana ms (IQR %) | Po/E0 | Ścisły protokół |
|---|---:|---:|---:|---|
| frame complete_heavy20_frozen_fx (ms) | 5.3027 (0.8 %) | 5.4296 (2.6 %) | 1.024 | brak regresji |
| frame complete_normal4_frozen_fx (ms) | 4.1884 (5.8 %) | 4.1272 (3.8 %) | 0.985 | nierozstrzygnięty |
| frame prepared_population_20_live (ms) | 6.1014 (13.5 %) | 7.2530 (10.6 %) | 1.189 | nierozstrzygnięty |
| frame prepared_population_256_live (ms) | 20.1392 (16.1 %) | 22.3141 (5.3 %) | 1.108 | nierozstrzygnięty |
| frame prepared_population_96_live (ms) | 11.4551 (17.7 %) | 13.0127 (8.9 %) | 1.136 | nierozstrzygnięty |
| step 20 bodies (ms) | 0.1171 (8.7 %) | 0.1234 (6.3 %) | 1.054 | nierozstrzygnięty |
| step 256 bodies (ms) | 2.4023 (11.7 %) | 2.3069 (1.1 %) | 0.960 | nierozstrzygnięty |
| step 96 bodies (ms) | 0.5724 (15.8 %) | 0.5533 (2.2 %) | 0.967 | nierozstrzygnięty |

Źródło: `work/v11-measure-final-e5/summary.txt`; pełne próbki i logi obok.

## Koszt dodatkowego widoku

Pięć naprzemiennych par, każdy wariant w świeżym procesie. W obu: dwóch
rycerzy i 20 demonów, 300 kroków/klatek rozgrzewki, 2400 kroków i 720
pełnych klatek. Każdy canvas ma 1280×720; dwie kamery oznaczają dwa pełne
obrazy, a nie dwa obrazy o połowie rozdzielczości. Klatka obejmuje renderer,
HUD, postprocessing, interpolację i synchroniczny odczyt 1 piksela. Symulacja
jest mierzona oddzielnie od rysowania; podczas pomiaru klatek pozostaje
zamrożona. To koszt diagnostyczny, nie pomiar FPS ani latencji wejścia.

| Metryka | Jeden widok: mediana ms (IQR ms) | Dwa widoki: mediana ms (IQR ms) | Iloraz |
|---|---:|---:|---:|
| whole_step | 0.1817 (0.0108) | 0.2072 (0.0086) | 1.140 |
| complete_frame | 5.1249 (0.0934) | 9.4206 (2.0987) | 1.838 |

Wszystkie 10 prób dało ten sam SHA-256 stanu symulacji:
`1f1463a0818e6f43d7624432261369b08002678f46d6bee3d6ad691976212f13`.
Rysowanie w każdej próbie zachowało Integrity. Próby nie dodają split-screenu do menu.

Źródło: `work/v11-views-final/`; `source-stable.txt` nazywa niezmienione źródło.

## E4: powtórzenie kroku dla 20 ciał

Pierwsze pięć par dało 1,130× przy IQR bazy 13,5%. Powtórzono pięć
par dla tej populacji, tym samym kodem, rozgrzewką i liczbą kroków.
MEASURE uruchomił też swoje sceny klatek dla 20 ciał; powtórzenie
nie obejmuje populacji 96/256. Niżej wynik powtórzenia i wszystkich
dziesięciu prób, bez wybierania korzystniejszej serii.

| Seria | Przed mediana ms (IQR ms) | Po mediana ms (IQR ms) | Po/przed | Ścisły protokół |
|---|---:|---:|---:|---|
| Powtórzenie, n=5 | 0.1200 (0.0052) | 0.1161 (0.0131) | 0.968 | nierozstrzygnięty |
| Łącznie, n=10 | 0.1200 (0.0120) | 0.1218 (0.0085) | 1.016 | nierozstrzygnięty |

Surowe dane: `work/v11-measure-final-e4-repeat20/summary.txt` oraz
`work/v11-measure-final-e4/summary.txt`. Wynik nierozstrzygnięty
po powtórzeniu nadal wymaga decyzji użytkownika według protokołu.

## E5: powtórzenie pełnych klatek

W pierwszej serii mediana pełnych klatek żywych populacji wzrosła
o 11–19%, przy IQR do 18%. Powtórzono pięć naprzemiennych par
pełnego benchmarku w świeżych procesach: High bez affinity,
300 rozgrzewki i 720 klatek, populacje 20/96/256 w qa_crowd, ten sam kod E0/E5.
Powtórzenie dotyczy klatek; nie uruchamia ponownie core-measure.
Niżej pokazano obie serie razem, bez wybierania korzystniejszych prób.

### Powtórzenie, n=5 na wariant

| Metryka | E0 mediana ms (IQR %) | E5 mediana ms (IQR %) | E5/E0 | Ścisły protokół |
|---|---:|---:|---:|---|
| complete_normal4_frozen_fx | 3.9347 (3.5 %) | 4.1538 (4.9 %) | 1.056 | nierozstrzygnięty |
| complete_heavy20_frozen_fx | 5.3664 (2.2 %) | 5.4237 (1.4 %) | 1.011 | brak regresji |
| prepared_population_20_live | 6.2327 (13.7 %) | 6.5222 (3.7 %) | 1.046 | nierozstrzygnięty |
| prepared_population_96_live | 11.5422 (10.5 %) | 11.9678 (3.4 %) | 1.037 | nierozstrzygnięty |
| prepared_population_256_live | 20.8660 (8.0 %) | 21.2237 (2.1 %) | 1.017 | nierozstrzygnięty |

### Wszystkie próby, n=10 na wariant

| Metryka | E0 mediana ms (IQR %) | E5 mediana ms (IQR %) | E5/E0 | Ścisły protokół |
|---|---:|---:|---:|---|
| complete_normal4_frozen_fx | 4.0248 (6.3 %) | 4.1405 (4.7 %) | 1.029 | nierozstrzygnięty |
| complete_heavy20_frozen_fx | 5.3430 (2.2 %) | 5.4267 (2.0 %) | 1.016 | brak regresji |
| prepared_population_20_live | 6.1670 (13.8 %) | 6.5526 (11.6 %) | 1.063 | nierozstrzygnięty |
| prepared_population_96_live | 11.4986 (13.8 %) | 12.2659 (10.2 %) | 1.067 | nierozstrzygnięty |
| prepared_population_256_live | 20.5026 (9.8 %) | 21.3985 (5.1 %) | 1.044 | nierozstrzygnięty |

Surowe próby: `work/v11-measure-final-e5-repeat-frames-crowd/` oraz
`work/v11-measure-final-e5/`. Nierozstrzygnięty wynik po powtórzeniu
nie jest automatycznym zaliczeniem; wymaga decyzji według protokołu.

Pierwsze uruchomienie pomocniczego wrappera nie przekazało qa_crowd:
proces zatrzymał się przed końcem na walidacji pojemności domyślnej
areny. Nie powstał kompletny benchmark.txt i żadne jego próbki nie
weszły do zestawienia. Log zachowano w work/v11-measure-final-e5-repeat-frames.
Poprawiono wyłącznie konfigurację wrappera poza game; całą serię
wykonano od początku w osobnym katalogu wymienionym powyżej.

## Interpretacja końcowa i decyzja użytkownika

Powtórzenia nie zastępują pierwszych serii: zestawienia n=10 zawierają
wszystkie próbki. Poniższa tabela pokazuje wartości po powtórzeniach,
a dla niepowtarzanego rdzenia E5 nadal n=5. Nie oznacza przyjęcia
nowego kryterium odbioru ani zgody użytkownika na odstępstwo.

| Zakres | Po/przed | Różnica median ms | Suma IQR A/A ms | Ścisły wynik |
|---|---:|---:|---:|---|
| E4 krok 20, n=10 | 1.016 | +0.0019 | 0.0105 | nierozstrzygnięty |
| E5 complete_normal4_frozen_fx, n=10 | 1.029 | +0.1158 | 0.2209 | nierozstrzygnięty |
| E5 complete_heavy20_frozen_fx, n=10 | 1.016 | +0.0836 | 0.5188 | brak regresji |
| E5 prepared_population_20_live, n=10 | 1.063 | +0.3856 | 0.6357 | nierozstrzygnięty |
| E5 prepared_population_96_live, n=10 | 1.067 | +0.7673 | 2.6384 | nierozstrzygnięty |
| E5 prepared_population_256_live, n=10 | 1.044 | +0.8958 | 3.8350 | nierozstrzygnięty |
| E5 step 20 bodies (ms), n=5 | 1.054 | +0.0063 | 0.0105 | nierozstrzygnięty |
| E5 step 256 bodies (ms), n=5 | 0.960 | -0.0954 | 0.4805 | nierozstrzygnięty |
| E5 step 96 bodies (ms), n=5 | 0.967 | -0.0191 | 0.0654 | nierozstrzygnięty |

A/A: `work/v11-measure/aa/summary.txt`, ten sam kod E0 po obu stronach.
Suma obu IQR jest tu jawną, proponowaną interpretacją rozrzutu A/A
dla tej samej metryki, nie potwierdzoną granicą regresji ani formalnie
zaakceptowanym progiem. Wartości ujemne różnicy oznaczają krótszy czas.

Zgodnie z przekazaną instrukcją decyzja należy do użytkownika:
czy przyjąć kryterium praktyczne: mediana po <= 1,05x mediany przed,
albo dodatnia różnica median nie większa niż suma IQR obu wariantów A/A?
Do czasu decyzji punkt 7 pozostaje otwarty. Duży IQR, także przy
mediana <= 1,05x, nie daje PASS według pierwotnego protokołu.
B2 (feeling, czytelność, płynność podczas zwykłej gry) również pozostaje
do oceny człowieka. Próba dwóch widoków nie jest funkcją w menu.
