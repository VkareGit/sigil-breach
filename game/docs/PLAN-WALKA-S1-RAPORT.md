# Plan walki souls, etap S1: raport

Silnik ciosu bez zmiany treści: złoty wzorzec i klatki są takie same jak w R5.

## Nowe mechaniki

| Pole lub rodzaj | Działanie |
|---|---|
| `string = { into, gap, every }` | Cios przechodzi w następny po krótkiej przerwie; `every` daje na zmianę krótki i długi ciąg |
| `hold` | Po windupie ciało stoi przez podany czas, kolejność stała |
| `track` | Cel podąża za graczem przez część windupu, potem zamarza |
| `sweep` | Szeroki łuk z zasięgiem, można wyjść z łuku, przeskoczyć niski albo przejść unikiem; `trail` zostawia ogień na linii |
| `seize` | Pochwycenie: przypina ofiarę, rani gdy się zamyka; unik je opróżnia, zachwiany trzymający puszcza |
| `wave` | Pierścień po podłodze, do przeskoczenia; nie trafia tego, co już minął |
| `beam` | Promień obracający się wokół ciała, zatrzymywany przez kamień |
| `tempest` | Cała sala uderza pulsami, bezpieczny jest wędrujący krąg |
| `storm` | Pioruny znaczone tam, gdzie cel stoi, spadają po czasie |
| `salvo` | Pociski wypuszczane kolejno, każdy celowany od nowa |
| `summon` | Wzywa istniejące stwory z limitem żywych |
| `hop`, `blink` | Odskok i teleport na stałej liście kierunków |
| `charge.turns` | Szarża zatrzymuje się, patrzy i rusza znowu |
| efekt `buildup` | Narażenie narasta, zanika, skutek spada dopiero przy progu |

Stany `seized` i `rooted`. Zakazy `dash`, `jump`, `fire`, `cast` obsługuje rycerz.

## Dowody

- `tests/cases/souls_engine.lua`: każda mechanika osobno, z odpowiedzią gracza:
  łuk i wyjście z niego, przeskok, unik, pochwycenie i jego przerwanie, fala i
  skok, promień i kamień, limit wezwań, storm dla poruszającego się gracza,
  krąg ciszy, zwrot szarży, próg narażenia.
- `TEST.ps1 -Suite Mechanics`: 5830 sprawdzeń, `Architecture`: 0 uwag.
