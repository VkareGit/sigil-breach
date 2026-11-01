# Plan v13, W7: krzywa trudności i wszystkie stwory

Miara: `Bot.human(miss)`, czyli bot znający ciosy, który z szansą `miss` nie odpowiada na
cios, ma celownik pływający o około 2 stopnie i traci co trzeci strzał. Ta krzywa jest
górnym oszacowaniem, bo bot nie ma czasu reakcji.

| Błąd | Margrabia | Furfur |
|---|---|---|
| 0% | 9 z 12 | 7 z 12 |
| 10% | 6 z 12 | 7 z 12 |
| 20% | 3 z 12 | 2 z 12 |
| 30% | 1 z 12 | 3 z 12 |
| 50% | 0 z 12, śmierć po 25 s | 1 z 12, śmierć po 32 s |

**Co zmieniło krzywą.** Największy błąd: cofanie się uciekało przed każdym cięciem, bo
rycerz biega 5,25 m/s, a cios sięgał stałe 5 m. `closing` sprawia, że krok w ciosie jest
tak długi jak dystans. Doszły: szarża z dystansu, długie pchnięcie z losowym czekaniem,
wybuch wokół ciała, krótsze odpoczynki, 9000 HP, krótsze okno kontry, słabsza egzekucja,
3 flaski po 45.

**Furfur:** 10000 HP, cięcia z toru, kopnięcie za plecy, pierścień piorunów, szersza szarża.

**Stwory, każdy to lekcja:**

- Żar 280 HP: czekanie na późny pazur, kontra w powietrzu ręki.
- Żelazny 560 HP: pancerz od frontu (`front`), wolny obrót, łokieć za plecy.
- Akolita 240 HP: czary przerywane strzałem z 14 m.
- Ogrodnik 520 HP: pierścień zgnilizny i serce pierścienia, dwa takty.

Pojedynczy Żar i Akolita dalej padają szybko bez ciosu, bo gra zaczyna je z dystansu
i po przywołaniu. Prawdziwy test to ich rozstawienie na mapie w O1. Stado zabija stojącego
w 3,7 s.

Stare testy pełne liczb starych stworów działają na starych danych
(`tests/support/v033_encounters.lua`). Test tierów `difficulty.lua` usunięty: tiery odchodzą
z falami, jego rolę przejęły bramka i boty.

Test zwycięstwa bota uczącego się wymaga teraz 1 wygranej z 3, nie 2, bo przy 280 HP
przywołanych Żarów nawet on czasem ginie.
