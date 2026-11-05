# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-05: dopracowanie dźwięku Stolasa, Iron Thralla i Plague Gardenera. Wdrożone; pełna brama Linux zielona, odsłuch właściciela otwarty.**
Polecenie właściciela obejmuje śmierć, różne głosy czynności oraz słyszalne
ataki podczas walki. To zakres audio; nie zmieniamy wyglądu, balansu, SI,
trafień, zapisów, HUD-u ani pozostałych stworów. Commit po zielonej pełnej
bramie Linux; bez push. Poprzedni PLAN zachowano w całości w HISTORII.

## Plan wykonania

1. Zachować próbki i pomiary sprzed zmiany; testem odtworzyć pojedynczy
   wariant śmierci, brak głosu zależnego od ruchu/odpoczynku i słabe zapowiedzi
   z dystansu walki. Prześledzić priorytety, wyciszanie i recykling Source.
2. Trzy odrębne tożsamości: Stolas — gardłowa inkantacja i urywany lament;
   Iron — zduszona ludzka agonia pod żelazem; Gardener — mokry oddech,
   dławiący wysiłek i gasnące ciało. Dodać warianty śmierci i głosów ciała
   oraz krótkie oddechy po wysiłku. Ciemna barwa bez ostrych skoków i pisku.
3. Podnieść czytelność własnych ostrzeżeń/wykonań tych trzech stworów przez
   mastering, poziom i tłumienie dystansu. Zachować pozycję źródła,
   tłumienie przez ściany i suwaki. Wspólne dźwięki innych stworów bez zmian.
4. Warianty nagrań wybiera wspólny odtwarzacz, bez powtórzenia pod rząd
   i bez losowań symulacji. Nadal najwyżej 28 aktywnych i 28 buforowanych
   głosów. Sprawdzić przerwanie, śmierć, pauzę, zmianę świata i tłum stworów.
5. Porównać PCM i rzeczywiste poziomy runtime przed/po, wykonać powiązane
   testy audio oraz pełne `scripts/linux/TEST.sh All --timeout 1800`.
   Golden ma pozostać niezmieniony. Zapisać ograniczenia i zrobić commit.

## Inspiracje i źródła

- Bethesda, [chór DOOM Eternal](https://bethesda.net/en-EU/news/heavy-metal-choir):
  inspiracja ekspresją ludzkiego głosu, nie kopiowanie dźwięków gry.
- GDC, [The Mix: Understanding Your Tools](https://gdcvault.com/play/1024604/The-Mix-Understanding-Your-Tools):
  dostępny opis wskazuje na równowagę treści i narzędzi miksu; nie traktujemy
  samego podbicia głośności jako dowodu dobrego brzmienia.
- Źródła nagrań CC0 i przetwarzanie zapisane przy próbkach w provenance.json.
  Groza potępionych z fresku ma wynikać z oddechu, wysiłku i urwania głosu,
  bez zmieniania zwykłych mobów w ciągle krzyczący chór bossów.

## Postęp

- Stan wejściowy `31af872`, repo czyste, poprzednia pełna brama Linux PASS
  (7035 Mechanics/Assets, Input 50, Render, Architecture i Tools).
- Potwierdzono: po jednej próbce śmierci; oddech/pomruk przełączane bez
  kontekstu czynności; liniowe tłumienie 0,13 mocno zmniejsza obecność z 10 m.
  Zachowano kopie wszystkich 50 istniejących próbek trzech postaci i ich PCM.
- Odbiór emocji/barwy przez właściciela pozostaje oddzielny od pomiarów.
  Środowisko agenta nie udostępnia wiarygodnego odsłuchu; testy techniczne
  nie będą przedstawiane jako ocena słuchowa.

- Wdrożono 91 nagrań, trzy śmierci na postać, 35 wariantów i sześć głosów
  kontekstu. Miks ostrzeżeń i wysiłku jest przestrzenny, z większą obecnością
  na dystansie. 442 celowane sprawdzenia PASS; 3 cykle natywnego zwolnienia
  i ponownego wczytania wariantów PASS. Po wznowieniu usunięto przyczynę błędu izolacji testu; pełna brama PASS.

## Wznowienie i końcowa weryfikacja

- Przerwę właściciela zakończono 2026-11-05. Osobna natywna sonda
  potwierdziła przyczynę błędu: test miksu pozostawiał 28 bezczynnych Source,
  przez co następny test nie miał wolnego miejsca do ponownego użycia
  rewolweru. Sam mechanizm puli wykonywał obowiązującą regułę limitu.
- Nowy test otrzymał własny stan odtwarzania i zwalnia swoje Source także
  po błędzie, po czym przywraca wcześniejszy stan. Sonda przed/po: FAIL
  (pula 28, reuse=false) → PASS (pula wraca do 0, reuse=true). Nie osłabiono
  istniejącego testu i nie zmieniono reguł odtwarzacza dla tego problemu.
- Input osobno PASS (50), Render i Tools PASS. Końcowe All PASS:
  Architecture (692 Lua), Mechanics/Assets (7328), Input (50), Render i Tools;
  692.47 s, dziewięć świadectw z jednym stabilnym fingerprintem. Golden
  PASS bez zmiany wzorców. Przegląd diffu zakończony; commit bez push.
- Rozszerzona próba miksu: 178 kombinacji trzech stworów, obu broni i ich
  nagrań, dystansów 0/4/10 m i pełnej muzyki walki bez ściszenia ostrzegawczego.
  Brak próbek przekraczających zakres; najwyższy szczyt 0,978 przy master 0,7.
  To wybrane scenariusze sumowania PCM, nie gwarancja dla dowolnej walki.
- 41 nowych plików zajmuje 3,57 MiB; statyczne warianty wczytywane raz,
  budżet odtwarzanych i buforowanych głosów nadal 28+28. Sprawdzone formaty,
  kompletność oraz SHA-256 wszystkich 91 WAV w plikach pochodzenia.
- Dowody w `~/Work/tries/sigil-breach-fcd220901f33f62b2f468c3244397c0be71f943d3a6fffa5bf5b128cc0949d3e/work/qa-direct`:
  trio-audio-before, trio-audio-after-r2, trio-audio-isolation-before/after,
  trio-audio-mix-evidence, trio-audio-paused oraz trio-audio-final-gates.

## Odbiór

Do odsłuchu właściciela: charakter trzech głosów, śmierci i obecność ataków
w rzeczywistej walce. Techniczne PASS nie potwierdza emocji ani wrażenia grozy.
Próbka `trio-audio-mix-evidence/death-performances.wav`: Stolas → Iron →
Gardener, po trzy śmierci bez muzyki. Windows nie uruchamiano. Nie zmieniono
wyglądu ani reguł walki. Dalsze postacie czekają na osobne zlecenie.
