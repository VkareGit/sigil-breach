# Postęp planu po audycie z 3 listopada 2026

Plan: `RAPORT-KONCOWY.md`, decyzje właściciela: `DECYZJE.md`. Zakres zatwierdzony 2026-11-03: całość planu (Etapy 0–3) z R01 (laser), D02 (próbkowany dźwięk z odsłuchem A/B), D05 (mikro-zatrzymanie do testu); C02 (wariant bez ognisk) po próbie właściciela. Wersja 0.43.

Uwaga dla edycji z PowerShell 5.1: pliki są w UTF-8 bez BOM; czytać przez `[IO.File]::ReadAllText`, nie `Get-Content -Raw`.

| ID | Punkt | Stan | Dowód |
|---|---|---|---|
| A01 | Zielona brama i prawdziwe testy | zrobione | 4 asercje dopasowane do reguł 0.42; render menu ognia; drop ≠ skrytka; bot bierze tylko potrzebny zapas. souls-gate/souls-bots czerwone do B01 |
| A05 | Zegary AI i reakcja na unik | zrobione | `attack_followups.lua`: cios i odpowiedź po pełnej regeneracji (było 0,7 s), gore-return na unik w serii; oba czerwone bez naprawy |
| A03 | Bezpieczny odpoczynek | zrobione | `pilgrimage.lua` safeRest: plama po martwym Buerze nie rani po odpoczynku (bez naprawy rani), pocisk w drodze = odmowa |
| A06 | HUD, teksty, podpowiedź w ramie | zrobione | grawer broni w ręku; teksty bez odradzania; audyt 3 podpowiedzi × 5 rozdzielczości; komunikat sklepu poligonu w polu |
| A02 | Continue wznawia w miejscu (D9) | zrobione | `pilgrimage_save.lua` resumes: miejsce, HP, naboje, łyki, zabici leżą, ścigający ściga; po śmierci jak dawniej |
| A04 | Znajdźki | rozstrzygnięte (D10) | nie wracają po odpoczynku z decyzji właściciela; tylko teksty (A06) |
| D01 | Nagranie bazowe (Astra) | zrobione | Astra (high), 54 s, 6 scen; `work/film-baseline/` (baseline.mp4, baseline-phone.mp4, README, klatki kontrolne); czeka na ocenę właściciela |
