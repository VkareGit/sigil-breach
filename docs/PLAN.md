# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-10: naprawy z audytu silnika (Z1–Z13), przyjęte, wdrażanie trwa.**
Audyt wykonano na `a7d1de4` (0.46); brama w chwili audytu:
`scripts/linux/TEST.sh All --jobs 4` PASS, 9285 sprawdzeń, Input, pokaz,
narzędzia. Streszczenie i dowody: HISTORIA, „Audyt silnika (2026-11-10)”.
Poprzedni plan (silnik ruchu i strzału E0–E7, fundament F1–F5, porządki
G1–G7) jest w całości w HISTORII.

Każdy krok osobno: czerwony test albo sonda odtwarzająca problem, zmiana,
dowód przed/po, pełna brama `scripts/linux/TEST.sh All --timeout 1800`,
wpis w ZMIANY/ODBIOR 0.46 i w Postępie, commit (bez push). Przejście do
następnego kroku bez pytania. Zatrzymanie i czekanie na właściciela tylko,
gdy: (a) zmienia się golden (także oczekiwana zmiana w Z1); (b) brama jest
czerwona z przyczyny spoza bieżącego kroku; (c) poprawka wymagałaby zmiany
tekstury, HUD-u, balansu (HP, obrażenia, zegary SI, elity, kadencja,
rozrzut) albo decyzji, której tu nie ma. Nie osłabiamy oczekiwań testów
i nie przesuwamy fixture'ów. Parametry jako nazwane wartości w `content/`.
Bez zmian grafiki, HUD-u, nowych broni i stworów w grze (D20), bez Windows,
bez pakowania. Sondy i pliki robocze poza repozytorium; sondy audytu:
`/home/nahiko/Work/tries/sigil-breach-audit-measure/sondy`.

## Decyzje właściciela (2026-11-10, wiążące)

- Z1: wariant A (same dane). Reguły spojrzenia w SI się nie zmienia.
- Ognisko sanctuary: świadomy wyjątek, zostaje jak jest; test go pomija
  z zapisanym uzasadnieniem.
- Z2b: tak, własne ziarno nowej drogi, jako osobny krok po Z2a.
- Z3: `--resource-plateau` wchodzi do zestawu Tools bramy z 3 cyklami;
  czas zmierzony przed wpisaniem.
- Dokumenty (Z11): na końcu, osobny commit.
- Zakres: wszystko Z1–Z13.

## Kolejność

Z3 → Z5 → Z2a → Z2b → Z4 → Z1 (stop: golden) → Z6 → Z7 → Z8 → Z9 → Z10 →
Z12 → Z13 → Z11.

## Kroki

- **Z3. Ostatnia sesja zostaje w pamięci.** Tablica robocza kroku rycerza
  (`player/feel.lua`, `local m = {}`) trzyma `m.p` i `m.shown` ostatniej
  sesji, która wykonała krok; `love game --resource-plateau` kończy się
  „application retained ownership after JIT eviction: cycle_N: chapel
  session”. Czerwony test w `runtime-contracts`: porzucona sesja po kroku
  znika po `collectgarbage`. Zmiana: na końcu `step` czyszczenie `m.p`
  i `m.shown`. Brama: `resource-plateau` w Tools z `SIGIL_RESOURCE_CYCLES=3`.
  Golden bez zmian.
- **Z5. `MEASURE.sh` z domyślnymi populacjami.** Faza `--benchmark` nie
  dostaje `SIGIL_CROWD_MAP`, więc 256 ciał nie mieści się w arenie. Czerwony
  test: próbny przebieg `MEASURE.sh --pairs 1` w kontroli skryptów. Zmiana:
  `SIGIL_CROWD_MAP=qa_crowd` przy benchmarku. Windows bez zmian. Brama
  Architecture i Input.
- **Z2a. Continue zaczyna losowanie od nowa.** Ziarno stałe, zapis nie niesie
  stanu RNG; pierwszy rzut po Continue 0,00006 (pierwszy zabity zawsze
  zostawia naboje), wbrew D9. Testy: stan `rng.sim` po wznowieniu równy
  stanowi przy zapisie; kontrakt generowany z danych (każdy atak każdego
  stwora zapisany w połowie zamachu i w pierwszym kroku ciosu, przez tekst
  zapisu, wznowiony w świeżej sesji, identyczny przez 6 s); powtórka
  dziennika sesji wznowionej daje ten sam skrót. Zmiana: pole zapisu niesie
  stan RNG, sekcja pilgrimage w wersji 5 z migracją, `core/rng.lua` jawny
  odczyt i zapis stanu. Golden bez zmian.
- **Z2b. Własne ziarno nowej drogi** (osobny commit). Nowa droga losuje
  ziarno, zapisuje je w zapisie i w nagłówku dziennika; powtórka je
  odtwarza. Testy, golden, QA i sesje ephemeral z jawnym ziarnem 1. Małe
  ziarna xorshift32 dają rzuty bliskie zera: rozgrzanie albo wymieszanie
  ziarna sesji gracza; test rozkładu pierwszego rzutu dla 1000 ziaren.
  Stare zapisy i dzienniki bez ziarna jak dziś.
- **Z4. Ruchome zagrożenia nie są wygładzane.** Pula `hazards` poza próbką
  obrazu, schemat bez `linear`; pierścień fali stoi w 35/210 klatek przy
  144 Hz, 65/240 przy 165 Hz, 143/288 przy 240 Hz. Czerwony test w `feel`:
  promień fali, kąt rozdarcia, środek bezpiecznego kręgu i postęp zapowiedzi
  bez zamrożonych klatek. Zmiana: deklaracje wygładzania i pula w próbce;
  `audio/field_voices.lua` czyta żywą pulę. Rendery pokazu identyczne,
  golden bez zmian.
- **Z1. Przebudzenie przy pierwszym ognisku zaczyna się alarmem** (wariant A).
  Rycerz budzi się twarzą w nawę; w pierwszym kroku po BEGIN i po śmierci
  czuwa 10 z 15 stworów, rycerz bez wejścia ginie po 4,6 s. Czerwony test
  w `pilgrimage` z danych: przy każdym ognisku, po przebudzeniu drogą
  odpoczynku i powrotu po śmierci, po 3 s bez wejścia nikt nie czuwa
  i zdrowie nietknięte; sanctuary pominięte z uzasadnieniem; sprawdzenie
  „nobody knows he is here” za pierwszym krokiem. Zmiana: ognisko narthex
  z własnym `wake` (start: `{ x = 27, z = 33.5, yaw = 0 }`). Znany stan:
  po odwróceniu się w nawę 10 stworów budzi się w 0,1 s (wariant B
  odłożony). Golden Linux się zmieni: dwa identyczne przebiegi,
  uzasadnienie, souls-gate i souls-bots przed/po. **STOP: pokazać
  właścicielowi.**
- **Z6. Odpoczynek zabezpiecza tylko obszar rycerza.** `secure` i awaryjne
  listy `fallen`/`picked` przechodzą tylko po obszarze rycerza, `populate`
  stawia garnizony całej mapy (wbrew D10 przy wielu obszarach). Czerwony
  test z obszarem próbnym (`trial_annex`) i podróżą między obszarami. Zmiana:
  iteracja po `Way.areasOf(mapa)`. Golden bez zmian.
- **Z7. Stan rodzaju zagrożenia w płaskim rekordzie.** Pola rodzajów we
  wspólnym schemacie `hazard`; prezentacja pyta o rodzaj po nazwie. Zmiana
  bez zmiany zachowania: stan deklarowany przez rodzaj z wersją i migracją
  (jak `combat/action_kinds.lua`), wersja puli w zapisie, haki rodzaju dla
  prezentacji. Test: nowy rodzaj w `extension` samymi rejestrami. Golden,
  rendery i eksport dźwięku identyczne.
- **Z8. Start i wczytywanie rosną liniowo z treścią.** Jedna porcja planu
  na klatkę; gotowość po 22,2 s w oknie QA, pierwsza klatka menu 4,4 s.
  Zmiana: budżet czasu na klatkę (nazwany limit w `content/`) i obrazy menu
  przez plan. Pomiar przed/po. Zwalnianie obrazów obszaru: tylko warianty
  i koszt w HISTORII, decyzja właściciela.
- **Z9. Przeładowanie to jeden interpreter trzech etapów.** Zmiana: etapy
  jako rejestr rodzajów etapu, ładowanie po jednym naboju z przerwaniem
  strzałem, widok i dźwięk etapu z deklaracji; breech i cylinder bez zmiany
  wyniku. Test: fikcyjna broń testowa (D20) z zapisem w trakcie
  przeładowania. Golden bez zmian.
- **Z10. Granice przy tłumie.** a) zapytania SI przez indeks przestrzenny,
  wynik identyczny bit w bit, pomiar `MEASURE.sh` przed/po z medianą i IQR;
  bez zmierzonego zysku nie wdrażać. b) limit jednoczesnych głosów na
  kategorię (kroki, skrzydła) w `content/audio_mix.lua`, najbliższe
  pierwsze; w obecnej kaplicy wynik bez zmian. Odsłuch należy do
  właściciela.
- **Z12. Luka maski trafień w klatce 28 Ember Thralla.** Czerwony test
  obejmujący klatkę 28 (obok obecnego). Przyczyna i poprawka tylko w danych
  trafień; zmiana obrazu: STOP. Sprawdzić strzał natychmiastowy i klatki
  spoczynku innych stworów.
- **Z13. Medale liczone ze stanu po kroku.** `last_rites` i `point_blank`
  czytają stan rycerza w chwili prezentacji. Zmiana: `EnemyKilled` niesie
  stan aktora z chwili zabicia. Test: zabójstwo przełamane z leczeniem przy
  zdrowiu pod progiem.
- **Z11. Dokumenty i martwy kod** (na końcu). START-HERE i INSTRUKCJA podają
  0.45; sprzeczności INSTRUKCJI (stwory wstają / nie wstają, pieczęcie,
  przykłady HP i leczenia, przebudzenie po Z1). Martwe `g.intensity`
  i odwołania do nieistniejących plików (osobny commit z bramą). `enemies/ai.lua`:
  stwór z `leash` bez `home` (walidacja albo warunek z testem).

## Kontekst, którego nie zmieniamy

- Wytrzymałość stworów przyjęta: Ember Thrall 360 HP (2 salwy Exorcista albo
  6 kul Judge'a w tułów), Iron Thrall 4 salwy albo 11 kul.
- Zatrzymanie trafionego ciała (25 ms przy mocnym ciosie, 60 ms przy
  zabiciu) jest w golden.
- Raz na minutę seria 5–6 klatek powyżej 16,7 ms w walce (frame-watch),
  także bez GC; przyczyna nieznana (hipoteza: kompilacja JIT).
- Dźwięku nikt nie odsłuchiwał; wybór A/B strzelby czeka na właściciela.

## Postęp i dowody

- 2026-11-10, **Z2b zrobione:** nowa droga w grze losuje i miesza własne
  ziarno; zapis i dziennik je niosą; sekcja `pilgrimage` 6. QA, testy
  i golden na ziarnie 1, golden bez zmian.
- 2026-11-10, **Z2a zrobione:** pole drogi niesie strumień losowania
  i resztę zatrzymania trafienia; sekcja `pilgrimage` 5 z migracją.
  Wznowienia walki: 19 ze 106 rozjeżdżało się, teraz 0. Golden bez zmian.
- 2026-11-10, **Z5 zrobione:** `MEASURE.sh` mierzy klatkę na mapie
  `qa_crowd`; `--trial` w bramie Linux (Tools). Bez zmian gry.
- 2026-11-10, **Z3 zrobione:** porzucona sesja zwalniana po kroku rycerza;
  `--resource-plateau` (3 cykle) w bramie Linux. Golden bez zmian.
- 2026-11-10: plan Z1–Z13 przyjęty, poprzedni PLAN i streszczenie audytu
  w HISTORII. Bez zmian gry.

## Poza zakresem

Grafika, HUD, nowe bronie i stwory w grze (D20), balans, zegary SI, elity,
Windows, pakowanie i wideo. Zwalnianie obrazów obszaru (Z8) i wariant B
przebudzenia (Z1) czekają na decyzję właściciela. Podział pokazu (G6)
i wybór A/B Exorcista (punkty 7–8 planu Exorcista) pozostają otwarte.
