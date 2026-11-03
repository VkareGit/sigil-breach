# Postęp planu po audycie z 3 listopada 2026

Plan: `RAPORT-KONCOWY.md`, decyzje właściciela: `DECYZJE.md`. Zakres zatwierdzony 2026-11-03: całość planu (Etapy 0–3) z R01 (laser), D02 (próbkowany dźwięk z odsłuchem A/B), D05 (mikro-zatrzymanie do testu); C02 (wariant bez ognisk) po próbie właściciela. Wersja 0.43.

Uwaga dla edycji z PowerShell 5.1: pliki są w UTF-8 bez BOM; czytać przez `[IO.File]::ReadAllText`, nie `Get-Content -Raw`.

| ID | Punkt | Stan | Dowód |
|---|---|---|---|
| A01 | Zielona brama i prawdziwe testy | zrobione | 4 asercje dopasowane do reguł 0.42; render menu ognia; drop ≠ skrytka; bot bierze tylko potrzebny zapas. souls-gate/souls-bots czerwone do B01 |
| A05 | Zegary AI i reakcja na unik | zrobione | `attack_followups.lua`: cios i odpowiedź po pełnej regeneracji (było 0,7 s), gore-return na unik w serii; oba czerwone bez naprawy |
| A03 | Bezpieczny odpoczynek | zrobione | `pilgrimage.lua` safeRest: plama po martwym Buerze nie rani po odpoczynku (bez naprawy rani), pocisk w drodze = odmowa |
| A06 | HUD, teksty, podpowiedź w ramie | zrobione | grawer broni w ręku; teksty bez odradzania; audyt 3 podpowiedzi × 5 rozdzielczości; komunikat sklepu poligonu w polu |
| A02 | Continue wznawia w miejscu (D9) | zrobione po przeglądzie Astry | pierwsza wersja (01dfef8) miała luki (wyjście bez zabójstwa, pociski, ciosy, resztki, dropy, rany); poprawione zapisem sekcji pools i flagą moved. Odłożone: niezabezpieczeni zabici innego obszaru (przed dodaniem obszarów) |
| A07 | Reguła procesu | zrobione | `game/docs/DEVELOPMENT.txt`, DODAWANIE TESTU 6–8 |
| A04 | Znajdźki | rozstrzygnięte (D10) | nie wracają po odpoczynku z decyzji właściciela; tylko teksty (A06) |
| B01 | Elity | częściowo: stanie i cofanie przegrywają; boty odruchowe i połowiczne wygrywają, ocena w B02 | patrz tabela niżej; souls-gate i souls-bots zielone |
| C01 | Rozwój w świecie (D8) | zrobione | relikwie w kaplicy, 2 miejsca na pieczęcie, śluby za dusze 1378 |
| D03 | Wstrząs wybuchu z odległością | zrobione | rules.lua: 2 / 10 / 20 m |
| R01 | Atak z laserem (Stolas, star-lance) | zrobione | attack_followups: linia przed uderzeniem, trafia stojącego, nie tego, kto zszedł |
| D05 | Mikro-zatrzymanie (do testu) | zrobione | stwory czekają 0,025/0,03 s przy ciężkiej salwie/zabójstwie |
| D01 | Nagranie bazowe (Astra) | zrobione | Astra (high), 54 s, 6 scen; `work/film-baseline/` (baseline.mp4, baseline-phone.mp4, README, klatki kontrolne); czeka na ocenę właściciela |

## B01: pomiar elit (sonda 4 strategii, komnaty poligonu, bot z idealnym celem)

| Strategia | Margrave przed | Margrave po | Furfur przed | Furfur po |
|---|---|---|---|---|
| stoi i strzela | wygrana 13,5 s, 86% HP | porażka (2/2) | wygrana 10,6 s, 16% HP | porażka (2/2) |
| cofa się | wygrana, 84–89% HP | porażka (2/2) | wygrana, 15% HP | porażka (2/2) |
| okrąża | porażka po A05 | porażka (2/2) | wygrana, 88% HP | wygrana, 71% HP |
| czyta ciosy | wygrana 11–15 s | wygrana 12–13 s, 83–100% HP | wygrana 10 s | wygrana 15–17 s, 79–93% HP |

Zmiany: styl duel idzie trasą (Furfur stał zablokowany 9,3 s z 12 s), zasięg dystansowy elit 16–18 m (rycerz strzela do 42 m), HP 2700 / 2250. Sonda: `sonda-elity-main.lua` w tym katalogu.
## Przegląd Astry (ultra, tylko odczyt) i odpowiedź

Pełny tekst: `PRZEGLAD-ASTRY.md`. P1 (Continue bez zabójstwa, wznowienie walki, resztki/dropy/rany, odpoczynek pod błyskawicą 18 m) naprawione i zakryte testami czerwonymi bez naprawy. P2: kwota w teście sklepu, przywracanie `spare`, komentarze — naprawione; obszary — odłożone; jedna zmienna na commit w B01 — złamana, odnotowane.

## Uwagi właściciela 2026-11-03 (do zrobienia po reszcie planu)

- **B01b, elita „zacięta”**: elita z pękniętą gardą (EXPOSED) stoi i wygląda jak zawieszona; wskaźnik ogłuszenia ma być wyraźniejszy, a ogłuszenie trwa za długo, także przy ładowaniu czaru, co ułatwia walkę.
- **V01, analiza z Astrą po naprawach**: odbiór obrazu przez człowieka (kolorystyka, kontrasty, czy rzeczy się zlewają), znaczniki (zabójstwo, celownik) i — bardzo ważne — odczucie strzelania.