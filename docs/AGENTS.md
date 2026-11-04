# SIGIL: BREACH — instrukcje projektu

Rozmawiaj z właścicielem po polsku. Punktem wejścia jest `START-HERE.txt`.
Przed pracą poznaj `game/INSTRUKCJA.txt` (zwłaszcza KAPLICA), `docs/WIZJA.md`,
`docs/PLAN.md`, `docs/TECHNIKA.md`, `docs/STYL.md` i najnowszy odbiór w
`docs/HISTORIA.md`. Najnowsze polecenia właściciela mają pierwszeństwo
przed starszymi opisami. Pamięć automatyczna nie zastępuje sprawdzenia kodu,
wersji, `git status` i ostatnich commitów.

- Środowisko właściciela to natywny Linux / Omarchy. Główne repozytorium:
  `/home/nahiko/Work/sigil-breach`. Osobne klony, eksperymenty i katalogi
  robocze można tworzyć w `/home/nahiko/Work/tries` w ramach zleconego zadania.
  Zwykłe zadania wykonuj w głównym repozytorium. Klon to osobna kopia
  repozytorium z kodem, zasobami i historią Git; twórz go tylko do potrzebnej
  izolacji lub porównania wersji. Po przeniesieniu potrzebnych zmian i
  zakończeniu weryfikacji usuń własny klon oraz przypisany mu katalog wyników.
  Katalog raportów `sigil-breach-<id>/work` nie jest klonem projektu.
  Omarchy kafelkuje okna: testy interfejsu muszą uwzględniać rzeczywisty
  rozmiar okna i marginesy obrazu, zamiast zakładać zadany rozmiar.
- Git jest skonfigurowany przez właściciela. Używaj istniejącej tożsamości,
  bez nadpisywania `user.name` i `user.email`. Zasady commitów wynikają
  z aktualnego zlecenia i instrukcji projektu; push wymaga polecenia.
  Po zakończeniu uzgodnionych zmian i wymaganej weryfikacji rób commit
  bez osobnego pytania, także dla nowych plików należących do zadania.
  Dla zmian gry nadal wymagana jest zielona pełna brama; odstępstwo wymaga
  wyraźnego polecenia właściciela po przedstawieniu wyników. Push tylko
  na polecenie właściciela. Wiadomości `fix:`/`docs:` po
  angielsku, UTF-8 bez BOM, `git commit -F <plik>`. Nigdy `git add .` ani
  `git add game`; dodawaj świadomie wybrane pliki, bez cudzej pracy.
- Istniejące zmiany można edytować, gdy wymaga tego zadanie. Zachowuj ich
  intencję i nie cofaj niezwiązanej pracy właściciela.
- Realizuj jeden uzgodniony cel do końca. Sprawdź zależności i skutki dla
  całej dotkniętej ścieżki gry, możliwość dalszej rozbudowy oraz regresje.
  Najpierw odtworzenie problemu, potem zmiana i dowód przed/po. Nie rozszerzaj
  zakresu samodzielnie na następne punkty planu.
- Dla zmian gry obowiązuje pełna brama Linux:
  `scripts/linux/TEST.sh All --timeout 1800`. Dla samych skryptów:
  Architecture i Input; dla samych dokumentów nie uruchamiaj testów gry.
  Nie maskuj wcześniejszych błędów ani nie osłabiaj oczekiwań testów.
  Po awarii Mechanics dokończ Input, Render i Tools osobno. Wpisy
  `FAIL second/fourth/failure` są celowymi próbami raportera.
  Zmiana celowo wpływająca na symulację wymaga dwóch identycznych przebiegów
  golden i uzasadnionego wzorca danego systemu; sprawdzenie Linuxa nie
  zastępuje Windows. Zmiana obrazu/dźwięku powinna zachować golden, ale
  klatka pozy wybiera maskę trafień. Testuj zależności, nie samą implementację.
- Wyniki Linuxa trafiają do `~/Work/tries/sigil-breach-<id>/work`, osobno
  `qa/`, `qa-direct/` i pomiary. Ścieżki i nadpisania: `START-HERE.txt`.
  Nie twórz katalogu `work` w repozytorium. Pomiary i długie sondy wykonuj
  w osobnym klonie, bez innych ciężkich procesów; usuwaj własny klon
  pomiarowy po zakończeniu. Skrypty pomocnicze trzymaj poza repozytorium.
- Obecny zakres dotyczy Linuxa. Właściciel odłożył zmiany i testy skryptów
  Windows; nie rozszerzaj zadania na tę platformę samodzielnie.
- Zachowuj chroniony HUD, styl Inferno i decyzje dotyczące trafień,
  zegarów SI, elit, broni oraz znajdziek. Szczegóły i wymagane rendery
  przed/po są w `docs/STYL.md`. Tekst gry po angielsku, dokumenty
  po polsku. Bez pakowania EXE/ZIP i nagrań wideo bez polecenia.
- Nie twórz nowych dokumentów w `docs/`. Uzupełniaj istniejące dokumenty;
  raporty i analizy dopisuj do `docs/HISTORIA.md`. Nie zapisuj sekretów.
  Zmianę odnotuj w ZMIANY/ODBIOR bieżącej wersji i w Postępie `docs/PLAN.md`.
  Nowy plan zastępuje PLAN, a poprzedni trafia w całości do HISTORII.
- Parametry symulacji zapisuj jako nazwane wartości treści; amunicję
  zmieniaj przez jej model. Zachowuj granice warstw z `docs/TECHNIKA.md`.
  Jedna zmiana balansu na commit, z sondą przed/po; nie reguluj elit,
  żeby zamaskować słabość bota. Komentarze po angielsku, dokumenty UTF-8
  bez BOM. Nie zlecaj równoległych zmian w tych samych plikach.
