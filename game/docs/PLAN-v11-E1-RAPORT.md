# Plan v11, etap E1: nazwane pozy i reguła zwłok (C1)

Raport odbioru E1 planu `PLAN-FUNDAMENT-v11.md`.

## Co się zmieniło

### Pozy w arkuszu

Arkusz atlasu (`content/art/sheets/<id>.lua`) ma `poses`: nazwa →
`{ clock, frames, bounds | rate | step, ends?, offset? }`. Reguły są
w `content/art/poses.lua`.

Zegary:
- `action` — znormalizowana faza akcji;
- `seconds` — sekundy stanu;
- `countdown` — minus czas, który stanowi zostało;
- `stride` — droga chodu;
- `world` — czas świata z przesunięciem na id ciała;
- `breath` — oddech klatek spoczynku.

`bounds` to wewnętrzne granice przedziałów `[a, b)`. Wartość na granicy
należy do następnej klatki.

`rate` daje pozę cykliczną: chód i lot. `step` daje równe klatki z ostatnią
zatrzymaną: upadek. `ends` kończy pozę, a stan przechodzi do innej: z
powalenia do wstawania.

`countdown` jest dodatkowym zegarem, którego nie było w liście planu.
Wstawanie wybierało klatkę warunkiem „pozostało > x”. Zanegowany pozostały
czas daje dokładnie te same przedziały `[a, b)`, bo negacja jest dokładna.

Pozy w użyciu:
- `walk`, `walkRear`, `watchRear`, `quiet`;
- `windup`, `strike`, `strike.<atak>` (zastępuje `strikeFrames` Furfura),
  `recover`;
- `pain`, `painHeavy`;
- `knockdown`, `rise`, `collapse`;
- `hover`, `hoverRear` (Stolas).

`quiet` wynika z klatek spoczynku.

Zastępniki: `walkRear`→`walk`, `watchRear`→`quiet`, `painHeavy`→`pain`,
`hover`→`walk`, `hoverRear`→`walkRear`, `strike.<atak>`→`strike`. Arkusz
może też podać `{ fallback = 'nazwa' }`.

### Animacja

`enemies/animation.lua` pyta o pozę po nazwie (`Anim.posed`) i podaje jej
zegar stanu. Nie zna numeru klatki ani układu.

Usunięto:
- `appearance.layout`, `appearance.strikeFrames`;
- `Anim.extended`, `Anim.layout`;
- `combat_defaults.corpse.extended/compact/contact`.

Dawne układy 6×4 i 4×4 są szablonami narzędzia arkusza
(`qa/art/pose_templates.lua`, `EXPORT-SHEET.ps1 -Spec` z `template` albo
`poses`).

### Reguła zwłok

- `body.corpse.settle` to najkrótszy czas osiadania.
- `body.corpse.landing` to moment uderzenia o podłogę.
- Domyślne wartości 0,33 / 0,14 obowiązują dawne 4×4. Imp i Iron Thrall
  (dziedziczy po Impie), Stolas i Furfur mają 0,44 / 0,22.
- Warunek leżenia (`fallY <= 0`, `fallVY <= 0`) zostaje.
- Poza `collapse` decyduje tylko o tym, co widać i co spotyka strzał
  w trakcie upadku.

### Walidacja (`Sheet.problems` przy `Atlases.register`)

Arkusz z błędną pozą jest odrzucony przed rejestracją. Komunikat podaje
nazwę pozy i błąd. Sprawdzane są:
- rosnące granice w dziedzinie zegara;
- liczba klatek równa liczbie przedziałów;
- klatki istniejące w arkuszu;
- niepuste sekwencje;
- zegar zgodny z nazwą pozy;
- `rate`, `step` i `ends`;
- cykle zastępników (DFS);
- wymagane pozy.

Progi animacji umiejętności (`content/ability_art.timing`) przechodzą ten sam
walidator granic (`AbilityArt.timingProblems`). `AbilityPose` zostaje jedynym
mechanizmem.

### Spójność z walką

`CHECK-CREATURE` ma pozycję „poses”: każda klatka każdej pozy ma kotwicę
głowy, klatkę anatomii i upieczoną maskę.

### Poprawka przy okazji

`Atlases.unregister` nie usuwa już rozmiaru obrazu, z którego maluje inny
atlas. `register` przyjmuje istniejący rozmiar tego samego obrazu, a inny
rozmiar odrzuca.

## Odbiór

- **Tabela pozy klatki z E0:** identyczna, łącznie z punktami na granicach
  (5200 wierszy).
- **Złoty wzorzec:** te same skróty.
- **Rzut stanu i przypisanie** (`v033-reference`): identyczne z 0.33.
- **Rendery:** 606/606 identycznych z `work/v11-render-base`.
- **Bramki:** format, 0 naruszeń architektury, Mechanics 4148 sprawdzeń;
  Input, Render i Tools przechodzą.
- **Test negatywny (`named-poses`):** odrzucone są arkusze z:
  - nierosnącą granicą;
  - klatką spoza arkusza;
  - pustą sekwencją;
  - cyklem zastępników;
  - brakiem wymaganej pozy;
  - granicą `action` > 1;
  - złym zegarem.

  Każdy jest odrzucony z nazwą błędu i nie trafia do rejestru. Malejące
  progi umiejętności też są odrzucane.
- **Próba przestawienia:** Buer z odwróconą kolejnością 16 klatek akcji
  (pozy, anatomia i maski przestawione razem) daje w musztrze rzut stanu
  i kontakty identyczne z referencją 0.33.
- **Próba zwłok:**
  - dwie dodatkowe klatki `collapse` zmieniają rysunek, a nie zmieniają
    osłony ani momentu uderzenia;
  - ciało podrzucone po upływie `settle` osłania do kroku, w którym leży
    (krok 44 z dodatkowymi klatkami i bez nich).
- **Próba rozszerzenia** (`creature-pipeline`): demon o nowym układzie,
  dodany samymi danymi i narzędziami. Ma 3 klatki chodu, nie ma tyłu
  (zastępuje go chód), ma osobny ciężki ból i 4 fazy zamachu.
  - Rejestruje się, a `CHECK-CREATURE` jest kompletny (z pozycją „poses”).
  - Animuje się.
  - Strzał w malowaną głowę trafia w każdej z 18 klatek jego póz.
- **Zapadki:**
  - FRAME NUMBERS OUTSIDE SHEETS = 0 (z 25);
  - liczby bez nazwy w `enemies/animation.lua` 77 → 43, łącznie 222 → 188;
  - pozostałe bez zmian.

Pomiar przed/po (protokół, `work/v11-base` kontra drzewo E1): sekcja
„Pomiar” niżej.
