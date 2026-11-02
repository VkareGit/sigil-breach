# Plan strzelania i nagrody po strzale

Burza mózgów Claude i Codexa, 2 listopada 2026. Nic z tego nie obowiązuje, dopóki nie trafi do INSTRUKCJA.txt. Liczby są punktem startu do prób w grze, nie gotowym balansem.

## Zasada

Przycisk zawsze odpowiada, płaci się po naciśnięciu. Soulsowe zobowiązanie to odsłonięcie po akcji, nie opóźnienie wejścia. Kryterium: gracz umie wskazać, który dodatkowy strzał był chciwością, i rozumie, dlaczego za niego zapłacił.

Call of Duty jest wzorem tylko dla potwierdzeń i nagrody po strzale, nigdy dla mechaniki strzelania.

## Czy strzał ma brać wytrzymałość

| Wariant | Co daje | Dlaczego nie |
|---|---|---|
| Jak teraz: 34 i 14 | Strzał zabiera unik | Kara przychodzi później, przy próbie uniku. Rewolwer co 0,38 s trzyma odnowę w miejscu. |
| Mniejszy koszt (Claude: 26 i 8, krótsza pauza) | Zostaje wspólna pula | Nawet mały koszt wstrzymuje odnowę, jeśli nie skrócimy pauzy. |
| Osobny zasób (ciepło, skupienie) | Rytm strzelania | Trzeci limit obok amunicji i przeładowania, za dużo na dwie bronie. |
| Zmęczenie psuje celność | Strzał zawsze działa | Ukryta kara i spirala porażki. Odrzucone przez obu. |
| Czas, pozycja, amunicja, wytrzymałość tylko dla ciała | Decyzja zapada w chwili strzału: czy zdążę przed ciosem | Bezpieczny ostrzał z dystansu, jeśli odsłonięcie będzie za krótkie. |

**Rekomendacja: ostatni wariant.** Strzał nie bierze wytrzymałości. Przez 0,22 s po shotgunie i 0,12 s po rewolwerze nie ma uniku, a bufor wykonuje naciśnięty unik zaraz po tym czasie, więc nic nie ginie. Oba koszty siedzą w danych broni, więc wariant łatwo sprawdzić i cofnąć.

Claude zaczynał od wersji z mniejszym kosztem i zmienił zdanie: wspólny pasek karze z opóźnieniem, a blokadę po strzale gracz czuje od razu i ma ją wytłumaczoną przez odrzut broni. Jeśli strzał i unik zaczną dominować, wydłużamy odsłonięcie i dokładamy presję mobów.

## Co od czego zależy

| Co | Zależy od | Stan |
|---|---|---|
| Czy strzał padnie | żyje, ma nabój, broń zamknięta, cykl broni | do uporządkowania |
| Obrażenia | dystans, część ciała, pancerz | jest, bez zmian |
| Garda wroga | impact, poise, faza ataku | jest |
| Odbicie ciosu | ostatnie 180 ms zamachu, do 6 m, impact 40+ | jest |
| Egzekucja | odbicie, potem [E] z bliska | jest |
| Unik | wymaga pełnych 26, bez długu poniżej zera | do zrobienia |
| Przeładowanie | czas i pozycja, unik zatrzymuje postęp | do sprawdzenia |
| Zapas | ognisko uzupełnia do 12 nabojów shotguna i 24 rewolweru | teraz 72 i 72 |
| Odzysk życia | zadane obrażenia po trafieniu | jest |

## Nagroda po strzale

Warstwy Call of Duty i ich odpowiedniki tutaj:

| Warstwa | Zadanie | Tutaj |
|---|---|---|
| Znacznik i dźwięk trafienia | Pewność, że trafiłem | 100–140 ms, jeden dźwięk na salwę, inny dla ciała i pancerza |
| Potwierdzenie zabójstwa | Mogę przestać strzelać | 180–220 ms mocniejszy znacznik, jeden niski akcent, reakcja ciała |
| Głowa | Pochwała celności | Romb i suchy akcent, przy śrucie od 25% śrucin w słaby punkt |
| Liczba nagrody | Czuję przyrost | `+40 SOULS` przy liczniku dusz, prawdziwa wartość zamiast `+N / DEMON DESTROYED` |
| Medal czynu | Gra zauważa, co zrobiłem | Jeden na zabójstwo, według ważności, patrz niżej |
| Drabina serii | Narastający wyczyn | Patrz niżej |

Dźwięki mają hierarchię: śmierć, potem odbicie i pęknięcie gardy, potem głowa, potem zwykłe trafienie. Gra w jednej chwili gra najwyższy z nich.

Drabina serii, odpowiednik Double Kill do Ultra Kill. Nazwy pasują do fresków kaplicy:

| Zabójstw | Call of Duty (Black Ops 6) | Tutaj |
|---|---|---|
| 2 | Double Kill | DIPTYCH |
| 3 | Triple Kill | TRIPTYCH |
| 4 | Fury Kill | TETRAPTYCH |
| 5 i więcej | Frenzy, Mega, Ultra, Kill Chain | POLYPTYCH |

Okno serii to 4 s od ostatniego zabójstwa, trafienie przez wroga ją zeruje (tak działa już `combo`). Seria jest czysto honorowa: nie daje dusz ani żadnego bonusu. Malowana pieczęć powstaje przez Codexa, w stylu gry.

Medale czynów: ABSOLVED (egzekucja), PARRY (odbicie), SMITTEN (głowa), LAST RITES (zabójstwo przy małym życiu), ONE SHOT (kilka ciał jednym strzałem), POINT BLANK, LONG SHOT. Najtrudniejsze moby dostają duży napis ENEMY FELLED.

Przy ognisku krótkie podsumowanie od ostatniego odpoczynku: ile padło, ile egzekucji, najlepsza seria.

Multikill w czasie, wiele ciał jednym strzałem i seria bez trafienia to trzy różne rzeczy i nie liczymy ich jednym licznikiem.

## Czego nie robić

- Odmowa strzału za zmęczenie, pod żadną nazwą. Osłabianie pocisku przy zmęczeniu.
- Animacja przygotowania przed pierwszym strzałem.
- Lektor, kill feed, stos medali, mnożnik punktów, nagrody za serię.
- Bonus do dusz za serię. Darmowe zwroty staminy, amunicji i życia za sukces.
- Hit-stop przy każdym trafieniu.
- Blok bronią i udźwig: kolejne systemy nie rozwiążą responsywności.

## Spór Claude i Codexa

| Sprawa | Claude | Codex | Decyzja |
|---|---|---|---|
| Koszt strzału | mniejszy | zero, czas i pozycja | Codex |
| Zmęczenie a celność | gorsza celność | nie | Codex |
| Seria w stylu Ultra Kill | drabina | ukryć w walce | Claude, bo właściciel jej chce; bez nagrody, co usuwa zarzut Codexa |
| Dusze za serię | tak | nie | Codex |
| Zachwianie a strzał | pokazać | usunąć blokadę | do prób: bez blokady przy lekkim zachwianiu |
| Bufor strzału | 0,35 s | 150 ms | patrz niżej |

Znana wada wersji 0.40 (znalazł Codex): strzał z bufora leci tam, gdzie gracz celował w chwili kliknięcia, nawet 0,35 s później. Strzał, który musiał poczekać, powinien brać cel z chwili wystrzału.

## Kolejność

1. Celowanie strzału z bufora i zasady naciśnięcia: strzał w trakcie uniku, lekkie zachwianie, pusta broń.
2. Strzał bez wytrzymałości, odsłonięcie po strzale, unik bez długu, próg uniku na pasku.
3. Potwierdzenia: hierarchia dźwięków, znacznik zabójstwa, `+SOULS`.
4. Medale i drabina, malowane pieczęcie przez Codexa.
5. Próba parry, riposty i przeładowania w grupie mobów.
6. Zapas amunicji i cała trasa między ogniskami. Cel: sprawne przejście zużywa 60–70% przydziału.

Materiały źródłowe są w `work/brainstorm/`: `claude.md`, `codex-report.md`, `codex-stamina.md`.

## PostÄ™p

WdraÅ¼ane po kolei, kaÅ¼dy krok z commitem.
- Krok 1: strzał, który czekał dłużej niż 0,12 s, bierze cel z chwili wystrzału. Unik nie blokuje rąk (brak `rollLock`), a strzał z uniku oddaje resztę jego ochrony. Lekkie zachwianie rycerza to `shaken`: spowalnia, nie blokuje strzału; ciężkie dalej blokuje. Strzał przerywa picie bez leczenia i bez zużycia flaski. Pociągnięcie spustu przy przeładowaniu mówi `RELOADING`.
- Krok 2: strzał nie bierze wytrzymałości, zamiast tego `fire.recovery` (0,22 s shotgun, 0,12 s rewolwer) blokuje unik, a bufor wykonuje go zaraz po tym czasie. Unik wymaga pełnych 26 i nie robi długu. Na pasku wytrzymałości jest znacznik progu uniku, poniżej niego pasek czerwienieje. Bot przechodzi kaplicę łatwiej (3–7 śmierci zamiast około 12), do skorygowania w krokach 5 i 6.
- Krok 3: jeden dźwięk na salwę według ważności (przełamanie, mocne trafienie, głowa, trafienie; zabójstwo mówi samo). Znacznik zabójstwa trwa dłużej, nad celownikiem pojawia się czaszka na 0,4 s. Przy liczniku dusz `+N SOULS` z prawdziwą wartością, sumuje się przez 1,4 s; w kaplicy zniknął napis z punktami.
