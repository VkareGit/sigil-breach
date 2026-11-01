# Plan v13, etapy W0-W2: raport

Etapy zmieniają silnik, a nie treść: żaden stwór nie używa jeszcze nowych pól, więc
złote wzorce stoją.

**W0.** `tests/cases/souls_gate.lua` mierzy każdą próbę: stoi i strzela, a także ciosy
na sekundę ostrzeliwanego i nieostrzeliwanego ciała. Lista `GATED` czeka na stwory
przebudowane. Stan 0.36: Margrabia 0,56 ciosu/s bez ognia i 0,28 pod ogniem, Furfur
0,35 i 0,24, zwykłe stwory 0.

**W1.** `sweep` i `seize` dostają pole `trace`: momenty strzału z kątem, zasięgiem
i wysokością. Zasięg, szerokość i okno wynikają z toru. Tor idzie przez istniejące
`Melee.claw` i `Melee.contact`, więc ściany, skok, kucanie i odbicie uniku działają bez
nowego kodu. Ostrze to kule na 100, 70 i 40% zasięgu (`blade`, `contactRadius`).

Odstępstwo od planu: `timeline` z planu nie powstał. Czasy mają już swoje pola
(`windup`, `hold`, `recover`), nowa jest tylko oś toru. Promień jest jeden na cios,
a nie na moment.

**W2.** `turn` i `lockAt` na ciosie, `move.turn` na ciele. Cios z obrotem idzie tam,
gdzie ciało się obróciło, i nie szuka celu na końcu windupu. Stare `track` działa dalej
do czasu przebudowy pozostałych stworów.

Dowody w `tests/cases/souls_trace.lua`: tor trafia jedną stronę wcześniej, za ciałem
i poza zasięgiem nic nie trafia, wysoki cios przechodzi nad kucającym, wolne ciało nie
sięga za plecy, szybkie sięga, odskok przed blokadą jest śledzony, po blokadzie nie.

Testy: Mechanics 5962 sprawdzenia.
