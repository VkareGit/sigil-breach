# SIGIL: BREACH — PLAN v6 (szkic do akceptacji): hitboxy i wnioski z testu 0.25

> **ZASTĄPIONY przez PLAN-ROZWOJU-v7.md (2026-10-22).** Nie wdrażać. Część wniosków
> poniżej jest błędna (numery klatek bossa, „odsłonięcie”, metryka „powietrza”,
> etapy H1 i H5) — korekty w v7, sekcja 1.2. Dokument zostaje jako historia.

Stan: 2026-10-22, po wersji 0.26. Nic z tego planu nie jest jeszcze wdrożone.
Dane: Twoja sesja (telemetry.txt), przegląd hitboxów `work/qa-v26/hitbox-review.txt`,
`hitbox-review.csv` i arkusze `hitbox-<demon>.png`.

## 1. Hitboxy — co zmierzono

Przegląd porównuje bryły trafień z namalowaną sylwetką każdej klatki (rycerz 8 m przed
demonem). „Powietrze” to część brył nad przezroczystymi pikselami (strzał trafia
w nic), „pokrycie” to część namalowanego ciała w bryłach (skrzydła, rogi, płaszcze
są poza bryłami celowo).

| Demon | pokrycie | powietrze | najgorsza klatka | głowa w powietrzu (średnio / najgorzej) |
|---|---|---|---|---|
| Sługa | 64 % | 41 % | 18: 74 % | 40 % / 100 % (klatka 16) |
| Żelazny | 71 % | 35 % | 18: 69 % | 27 % / 100 % |
| Akolita | 49 % | 31 % | 17: 65 % | 24 % / 100 % |
| Ogrodnik | 63 % | 28 % | 12: 62 % | 19 % / 100 % |
| Margrabia | 73 % | 36 % | 12: 67 % | 51 % / 100 % |
| Furfur | 58 % | 46 % | 18: 65 % | 45 % / 99 % |

Najważniejsze wady (widoczne na arkuszach):
1. **Przewrócenie i upadek** (klatki 14–18 / 10–12): bryły stoją pionowo, głowa wisi nad
   leżącym ciałem. Przewrócony demon żyje — strzał w powietrze nad nim to „głowa”,
   a prawdziwa głowa na posadzce to „nogi”.
2. **Słaby punkt bossa w pozach chwiania** (Margrabia 7, 8, 10): czaszka schodzi niżej
   niż bryła głowy, więc strzał w nią trafia tułów z pancerzem 30 zamiast 0 —
   „odsłonięcie” traci sens dokładnie wtedy, gdy ma działać.
3. **Jedna bryła nóg** obejmuje przerwę między nogami (główne źródło powietrza).
4. **Pozy z pochyleniem** (zamach, ból): głowa przesunięta w bok względem bryły.

## 2. Hitboxy — propozycja etapów

- **H1 narzędzie kalibracji**: przegląd proponuje dla każdej klatki pasma i środki
  (głowa = zwarta grupa pigmentu najwyżej w osi ciała, tułów, nogi), zapisuje je jako
  dane `hit_volumes` do przejrzenia na arkuszu; człowiek zatwierdza, nie zgaduje liczb.
- **H2 pozy leżące**: bryły leżące (poziome walce) dla przewrócenia i upadku, z danych
  klatki; trafienie w głowę na posadzce to głowa.
- **H3 nogi**: dwie bryły nóg zamiast jednej, tam gdzie nogi są rozstawione.
- **H4 słabe punkty bossów**: głowa śledzi czaszkę w pozach chwiania i zamachu.
- **H5 strażnik**: test z progami (powietrze średnio ≤ 20 %, głowa ≤ 15 %, żadna żywa
  poza z głową > 50 %) i zapadką, która pozwala liczbom tylko maleć.
Weryfikacja: złoty wzorzec zmieni się (trafienia to symulacja) — nowa baza i opis
w ZMIANY; populacje botów przed i po; test anatomii głów bez zmian.

## 3. Wnioski z Twojej sesji 0.25 (potyczka na poligonie, 223 s, 40 zabójstw)

| Miara | Ty | boty wprawne | cel D7 |
|---|---|---|---|
| Czas kontroli | 8,5 % | 3,9 % | 8–12 % — spełniony w grze |
| Zabójstwa przełamane | 43 % | 16 % | 15–25 % — powyżej |
| Idealne uniki | 2 | 1,2 / przebieg | ≥ 1 na falę |
| Trafienia | 129 / 148 | — | — |

Do decyzji: zabójstwa przełamane u człowieka są prawie 3× częstsze niż u botów
(rewolwer łamie gardę, strzelba dobija). Leczenie wyniosło tylko 26 HP w 223 s, więc
pętla nie jest za mocna w liczbach HP, ale przekracza cel udziału. Opcje: zostawić
(cel był szacunkiem), skrócić okno 2 s -> 1 s, albo zmniejszyć leczenie. Potrzebna
druga sesja w próbie fal (nie tylko potyczka), żeby ocenić to rzetelnie.

## 4. Inne rzeczy na później
- Dziennik poleceń poligonu nie zapisuje akcji katalogu (spawn, stacje): powtórka
  sesji poligonu wymaga dodania tych akcji do dziennika.
- Renderer rysuje od podłogi 0 (symulacja zna Ground.height).
- Mana i dalsze zaklęcia (sloty F i C już mają klawisze).
