# SIGIL: BREACH — technika

Architektura kodu, zasady pracy i testów, konwencje, rozszerzanie treści, anatomia i fizyka, praca na Linuxie. Polecenia uruchamia się z katalogu repozytorium; skrypty są w `tools/`.

## Spis rozdziałów

- Praca nad grą i testy
- Architektura
- Konwencje kodu
- Rozszerzanie treści
- Anatomia i fizyka (0.28)
- Linux

## Praca nad grą i testy

_Dawniej: `game/docs/DEVELOPMENT.txt`_

SIGIL: BREACH / JAK ROZWIJAĆ PROJEKT

GŁÓWNY KATALOG
Klon wskazany w zadaniu: Windows lub Linux (migracja: rozdział Linux niżej).

Pracuj w game/, nie w outputs/*/source. outputs to zbudowane snapshoty.
outputs ma bieżące i poprzednie wydanie. Przebudowa przenosi poprzednie
dostawy do work/qa-v<wersja>/rollback (jedna generacja, następny build ją zastępuje).
Zasada właściciela (2026-11-04): zwykłe zadania wykonujemy w głównym
repozytorium /home/nahiko/Work/sigil-breach. Klon oznacza osobną kopię kodu,
zasobów i historii Git; powstaje w Work/tries tylko wtedy, gdy potrzebna
jest izolacja lub porównanie wersji. Po przeniesieniu potrzebnych zmian
oraz zakończeniu weryfikacji usuwamy własny klon i przypisany mu zewnętrzny
katalog wyników. Katalog sigil-breach-<id>/work w Work/tries zawiera raporty
oraz dane QA, a nie kopię projektu. Dla głównego repozytorium pozostaje
jeden taki katalog; następny pełny All zastępuje poprzednie raporty w qa/,
chroniąc rollback, blokadę sesji i sąsiednie dane ręczne/pomiary.

Aktualna architektura: rozdział Architektura niżej. Historia zmian: docs/HISTORIA.md
(jeden plik, najnowsze na górze). Dawne konteksty, plany i opisy są w historii gita.

POLECENIA POWERSHELL Z GŁÓWNEGO KATALOGU

Windows: PowerShell 5.1 i dołączony toolchain/love-11.5-win64.
Linux: każde polecenie niżej ma odpowiednik w scripts/linux/*.sh (tabela w rozdziale Linux).
Zapisy: %APPDATA%/LOVE na Windows; ${XDG_DATA_HOME:-~/.local/share}/love na Linuxie.

  .\scripts\win\RUN.ps1                     uruchom aktualne źródła
  .\scripts\win\RUN.ps1 -Release            uruchom EXE bieżącej wersji
  .\scripts\win\FORMAT.ps1                  sformatuj aktywny kod Lua
  .\scripts\win\FORMAT.ps1 -Check           sprawdź styl bez zapisywania zmian
  .\scripts\win\BAKE-HIT-MASKS.ps1           przelicz maski po zmianie ilustracji/klatek
  .\scripts\win\EXPORT-SHEET.ps1 <id>        arkusz atlasu: zmierz stopy i rozmiary (-Spec: nowy)
  .\scripts\win\EXPORT-ANATOMY.ps1 <id>      adnotacja jako dane (-Legend: z warstw części)
  .\scripts\win\ANATOMY-EDITOR.ps1 <id>      edytor regionów anatomii na klatkach
  .\scripts\win\CHECK-CREATURE.ps1 <id>      wszystkie elementy demona: OK / MISSING
  .\scripts\win\TEST.ps1 -Suite Architecture składnia, zależności i granice modułów
  .\scripts\win\TEST.ps1 -Suite Mechanics    mechanika, zasoby i kontrakty aplikacji
  .\scripts\win\TEST.ps1 -Suite Input        prawdziwe callbacki, menu i zapis
  .\scripts\win\TEST.ps1 -Suite Render       widoki gry i pomiary interfejsu
  .\scripts\win\TEST.ps1 -Suite Tools        smoke narzędzi + realny start/retry/cancel
  .\scripts\win\TEST.ps1                     wszystkie powyższe kontrole

Pełny Render obejmuje także gęste próbkowanie trafień w żywych animacjach.
Na wolniejszym komputerze można jawnie zwiększyć limit procesu, bez pomijania
próbek: .\scripts\win\TEST.ps1 -Suite Render -TestTimeoutSeconds 1200.
Analogiczny parametr ma tools/win/verify.ps1. Limit domyślny wynosi 300 sekund;
timeout nie jest zaliczonym testem. Przebieg trafień wypisuje kolejne archetypy.
  .\scripts\win\BUILD.ps1                    testy źródeł; -Package: snapshot, testy EXE, ZIP

0.32: BUILD tworzy osobne paczki Developer-Windows i Player-Windows.
Gracz dostaje EXE/runtime i niezbędną zawartość; nie dostaje qa/tests ani
luźnego source i dokumentacji warsztatu. Deweloper dostaje także pełne
źródła, narzędzia i dołączony toolchain. Format .love zawiera wykonywalne
Lua — paczka gracza nie jest ochroną kodu przed odczytem. Archiwum gry
gracza istnieje tylko wewnątrz jego EXE (bez drugiej kopii .love obok);
weryfikacja czyta je z EXE i odrzuca bajty dopisane za archiwum.
tools/win/package-check.ps1 sprawdza manifesty/allowlistę i odrzucanie zmian;
-Installed uruchamia rzeczywiste paczki z katalogu poza repo.
PACKAGE-MANIFEST.json oraz build-fingerprint.txt wiążą wynik z SHA-256
źródeł, a osobne .sha256 poświadczają ZIP. Sam timestamp PASS nie wystarcza.

QA przy uruchomieniu hashuje całe game przed i po procesie. Edycja pliku
w trakcie unieważnia poświadczenie. Pełny odbiór wymaga nieruchomego drzewa;
próby focused przy równoległym pisaniu są wyłącznie dowodami roboczymi.
Każde uruchomienie dostaje własny identyfikator (SIGIL_QA_RUN); raporty
wpisują go jako "QA run: ..." i bramka sprawdza ten wpis, a nie zegar pliku.
Jeden katalog QA obsługuje naraz jedną sesję (.qa-session.lock): drugi
TEST/BUILD/BAKE, np. równoległego agenta, czeka zamiast nadpisywać raporty.
Hashowanie może rozgrzać cache plików OS, więc pierwszy przebieg procesu
nie jest automatycznie pomiarem dysku po zimnym restarcie komputera.

Po udanych testach źródeł można wykonać samo tools/win/build.ps1, a potem
tools/win/verify.ps1. Drugi krok jest konieczny do poświadczenia i utworzenia ZIP.
Testy są wyciszone, poza ekranem, bez przejmowania myszy i na osobnym zapisie.
Na Linuxie raporty zapisują się poza repozytorium, w
~/Work/tries/sigil-breach-<id>/work/qa; ręczne uruchomienia bez
SIGIL_UI_QA_DIR w sąsiednim qa-direct. <id> to pełny skrót SHA-256
kanonicznej ścieżki klonu (dowolny katalog roboczy i dowiązanie dają ten sam wynik).
SIGIL_TRIES_DIR pozwala wskazać inną bezwzględną bazę. tools/linux/project.sh
udostępnia SIGIL_WORK i SIGIL_QA, a gra stosuje tę samą regułę przez
src/app/workspace.lua. Wszystkie ręczne raporty i audyt UI używają tej samej
ścieżki; SIGIL_UI_QA_DIR nadal jawnie wybiera katalog danego uruchomienia.
Windows zachowuje work/qa i work/qa-direct (skrypty Windows poza zakresem
przenoszenia). Numery wersji: game/src/core/build.lua. Pełny All usuwa
stare wyniki tylko z zablokowanego qa, z zachowaniem rollback i blokady;
nie usuwa qa-direct, pomiarów ani wyników innych klonów.
Jeden zestaw: Windows toolchain/love-11.5-win64/lovec.exe game --suite=<id>,
Linux love game --suite=<id> (id z tests/suite.lua);
raport suite-<id>-results.txt nie nadpisuje pełnego test-results.txt.
Błąd jednego zestawu nie przerywa pozostałych; przebieg kończy się błędem.

Sprzęt odniesienia (0.42, audyt E04): Intel Core Ultra 7 155H (16 rdzeni,
22 wątki), Intel Arc Graphics, sterownik 32.0.101.8826, 31,5 GB RAM, Windows
11 Pro 10.0.26200, ekran 1920x1200 60 Hz. --frame-watch (minuta gry
w kaplicy, 1280x720, bez vsync), dwa przebiegi A/A na spokojnej maszynie:
mediana 5,11 / 4,95 ms, p95 7,59 / 7,67, p99 11,46 / 10,61, klatek ponad
16,7 ms 13 / 11 z 3600. Pomiar obok innego procesu jest niewiarygodny
(audyt: 196 / 3600). Sondy bez okna muszą ustawić te same limity JIT co
main.lua, inaczej mierzą rekompilację, nie grę.
--frame-watch (astra-fix) wykonuje jeden compositor na klatkę; wcześniejsza
sonda robiła present drugi raz. SIGIL_WATCH_PROFILE=1 włącza jit.profile,
SIGIL_WATCH_SYNC=1 dodaje odczyt jednego piksela i rozdziela oczekiwanie GPU
od submit oraz HUD/present. To synchronizacja potoku, nie czysty timer GPU
ani pomiar zwykłego FPS; porównuj tylko przebiegi z tym samym ustawieniem.
SIGIL_WATCH_SCALE=1 / 0.75 / 0.5 wybiera skalę sceny dla tego przebiegu.
Raport podaje rzeczywisty rozmiar sceny i końcowy digest symulacji.

Pomiary rdzenia (0.29, każdy osobno, raport w work/qa):
  --core-measure   maski (start, pamięć), salwa, pociski, pazur, Snapshot,
                   krok z przebudzoną populacją (z osobną separacją), krok
                   ze zwłokami, Journal, długa sesja -> core-measure.txt
                   SIGIL_CORE_POPULATION=20..512; SIGIL_CROWD_MAP=qa_crowd
                   (diagnostyczna sala 72×72 tylko w QA, cała krzywa na
                   jednej mapie); SIGIL_CORE_JOURNAL_SECONDS skraca próbkę
                   dziennika, gdy 10 s dużego tłumu przekracza limit.
                   SIGIL_BENCH_POPULATIONS (do 512) dla --benchmark.
  --benchmark      przygotowane populacje 20/48/96 oraz osobno prawdziwe
                   wejście/przywołanie przez portal (normalny limit20).
  --startup-check  rzeczywisty Application.load/update/draw, postęp,
                   błąd zasobu, retry i cancel; oddzielny świeży proces.
  --qa-smoke       modyfikator benchmark/core-measure/step-study/audio-export,
                   mniejszy scenariusz, bez pomijania etapów przygotowania.
  --step-study     ten sam przebieg przy różnym FPS oraz różnym kroku
                   symulacji (prawa ruchu i kontaktu) -> step-study.txt
  --mask-formats   formaty masek (hex, przycięte, upakowane, RLE): rozmiar,
                   wczytanie, dekodowanie -> mask-formats.txt
  --pigment-review skok i unik obok modelu bazowego, przed/po w tym samym
                   świetle; alfa 16 klatek -> creature-pigment.txt, pigment-*.png
  --audio-export   dźwięk poza grą jako WAV: każda warstwa partytury (pętla),
                   miks każdego nastroju (dwie pętle) -> music/*.wav; każdy
                   efekt tak, jak gra go renderuje -> sounds/*.wav; report.txt
  --movement-review ruchy rycerza w zwykłej symulacji (uniki, idealny unik,
                   ślizg, lądowanie, ładunek), trzy chwile każdego
                   -> movement-marks-*.png, movement-marks.csv
Trafienia: --hit-review liczy same raporty trafień względem obrazu (hit-*,
plan v7 H0–H9). Nowy punkt anatomiczny: wycinek tools/art/landmarks/crops.ps1,
wpis w game/qa/data/hit_landmarks.lua, test hit-landmarks sprawdzi, czy leży
na pigmencie lub w powietrzu tak, jak gra go rysuje.
Zmiana numeru wersji wymaga też nowej sekcji ZMIANY-X.txt na górze
docs/ZMIANY.txt i sekcji ODBIOR-X.txt na górze docs/ODBIOR.txt; BUILD
odmawia budowy bez nich.
Node/Python nie są zależnościami gry ani testów. Runtime i StyLua dla Windows
są dołączone; na Linuxie zainstaluj wersje podane w rozdziale Linux niżej.

GDZIE WPROWADZIĆ ZMIANĘ

Obrażenia, pancerz, poise:
  content/enemies.lua i weapons.lua -> combat/damage.lua oraz rules.lua.
  Trafienie jest rozliczane raz; UI korzysta z raportu, nie oblicza wyniku ponownie.
  Testuj odległość, osłonę ścianą, trafienie w głowę, pancerz i wielokrotne trafienia.

Ruch gracza / feeling:
  player/feel.lua, physics/kinematics.lua, physics/collision.lua.
  feedback/weapon_motion.lua i weight.lua odpowiadają za reakcję widoczną na broni.
  Nie dodawaj obrażeń do animacji. Zależne od prędkości siły licz w symulacji.
  Ślady ruchu (drobiny pigmentu, złoty błysk uniku, sinopia idealnego uniku):
  dane w content/movement_marks.lua (schemat content/defs/movement_mark.lua),
  wykonanie feedback/movement_marks.lua na hakach motion.dash/slide/marks;
  nowy ruch = nowy wpis. Podgląd: --movement-review.

Dźwięk i muzyka:
  Audio sześciu stworów ma osobne profile content/creature_audio.lua:
  ciało, czynność, pocisk i pole. Profile są prezentacją i nie trafiają
  do zamrożonych definicji walki ani zapisu. Rozpoznawanie przez archetype.id
  zachowuje odrębność Iron Thralla mimo wspólnego rodzaju SI z Emberem.
  audio/spatial.lua aktualizuje źródła i słuchacza; bada zasłonięcie co
  0,08 s, łagodzi zmianę poziomu i filtruje zasłonięte źródło. Bilet głosu
  chroni ponownie wykorzystany Source przed spóźnionym przerwaniem.
  audio/field_voices.lua śledzi faktyczne życie pola, początek i koniec;
  jednorazowy kontakt nie jest zapętlany, a groźny przebieg może być.
  worldRestored odbudowuje wyłącznie prezentację: bez ponownego kontaktu
  aktywnego pioruna; oczekujący kontakt i rozpoczęty głos czaru zostają.
  content/audio_mix.lua ogranicza sumę poziomów nakładających się rytuałów,
  nie głośność pojedynczego pola ani głosu rzucającego. Pule nadal mają
  po 28 źródeł żywych i odłożonych; strzał ma pierwszeństwo przed tłumem.
  creature-audio-lifecycle oraz creature-audio-mix sprawdzają natywne
  Sources, przypisanie zdarzeń, Continue, granice miksu i wszystkie warianty.
  PASS techniczny nie zastępuje odsłuchu. Pochodzenie i licencje nagrań:
  assets/sounds/<rodzina>/provenance.json; dowody i próbki poza repozytorium.
  Efekty to przepisy w audio/recipes.lua (długość, głos; wspólne narzędzia
  audio/synth.lua); każdy dźwięk ma własne ziarno szumu, nowy nie zmienia
  innych. Muzyka to dane w audio/score.lua (chorał, warstwy, nastroje),
  renderowane przy starcie przez audio/soundscape.lua (~0,4 s). Nowa warstwa
  = wpis z kind (drone, chant, pulse, knell); nowy nastrój = wpis w moods.
  Strzał broni: fire.sound w content/weapons.lua; etapy przeładowania:
  reload.<mechanizm>.voices w content/tuning.lua (nowy mechanizm = własne
  głosy). Odsłuch poza grą: --audio-export.

Strzał i przeładowanie:
  combat/combat.lua, ballistics.lua, reload.lua; parametry w content/weapons.lua.
  render/weapon.lua i weapon_art.lua opisują wygląd i punkty emisji efektów.
  weapon_art.fire dobiera faktyczne klatki odrzutu/catch. Reload.frame jest
  logiczną osią dawnego cyklu, nie dowodem na zmianę narysowanej sylwetki.
  Sprawdź anulowanie przeładowania, pusty magazynek, zmianę broni i moment
  faktycznego zużycia amunicji. Nie przesuwaj tych transakcji do love.draw.

Przeciwnik / boss:
  content/enemies.lua opisuje ciało i listę ataków. enemies/actions.lua wykonuje
  ataki, animation.lua dobiera fazę, pose.lua jest wspólne dla trafień i obrazu.
  Atlasy: arkusze content/art/sheets/ (enemy_art, enemy_frames i enemy_idle
  są ich wynikiem); ability_art rejestruje arkusze umiejętności; regiony części
  są w content/art/anatomy/*.lua (id, zone, material, polygon, anchors) w UV
  klatki; inne jednostki tylko przez Author.fromPixels/fromCell/cellPolygon.
  Rozmiary obrazów źródłowych: content/art/sources.lua (test anatomy-data
  porównuje je z PNG, SHA-256 wszystkich źródeł masek, dokładne prostokąty
  i filtry, reguły klasyfikacji, regiony z Anatomy.problems).
  enemies/surface.lua sprawdza pigment i region. Po zmianie atlasu wykonaj bake;
  wybierz niezależne punkty na ilustracji, nie środek wyliczonej bryły.
  Wariant na istniejącym obrazie z innym opisem ciała: appearance.regions
  (przykład: tests/cases/creature_extension.lua). Przepis „jak dodać demona”
  w dwóch przypadkach: ARCHITEKTURA pkt 12. HITBOXES na poligonie rysuje te
  same dane, którymi gra rozstrzyga (render/effects.lua E.hitboxes).
  render/fresco_enemies.lua ładuje obrazy na GPU. Poligon i testy mają
  pokazywać antycypację, aktywny cios, recovery, trafienie i śmierć.
  Droga łapy/pyska: enemies/contact_anchor.lua; parametry zasięgu w Action.
  Materiały: content/ballistic_surfaces.lua (wound, guard, penetrable, debris;
  kod czyta pola, nie nazwy). Wyjaśnienia i ograniczenia:
  docs/ANATOMIA-I-FIZYKA-0.28.txt. Liczba kończyn nie jest stałą silnika.

Efekt kontaktu lub ślad:
  feedback/impact_response.lua wybiera reakcję po trafieniu; effects.lua,
  shot_trails.lua i surface_marks.lua przechowują ograniczone pule.
  render/effects.lua i surface_marks.lua tylko rysują te dane.
  death_response.lua dostaje rozliczony śmiertelny kontakt; nie liczy obrażeń.
  Body.fall zgłasza kontakt z podłożem raz. Animacja śmierci nie zeruje zegara
  przy lądowaniu, a końcowa poza pozostaje na posadzce.
  Nowe dane przejściowe dopisz do właściwego resetu w session/encounter.lua.

Przycisk lub ekran:
  ui/interface.lua i odpowiedni ekran ui/* deklarują kontrolki.
  Przycisk podaje ID; app/commands.lua nadaje mu działanie.
  app/input.lua obsługuje priorytet ekranów, fokus oraz krawędzie klawiszy.
  Teksty używają PNG w ui/fonts i ui/skin, razem z pomiarem rzeczywistego tuszu.
  Sprawdź minimum 960x540, 1280x720, 1024x768, szeroki ekran i duże liczby.

Mapa / obiekt świata:
  Aktualnie utrzymujemy jedno pole testowe. Dane kolizji: world/arena.lua.
  Po zmianie mapy wywołaj World.rebuild; renderer odświeży siatkę na żądanie.
  Ozdoba nie staje się automatycznie przeszkodą fizyczną. Trzeba to zdecydować.

Zapis:
  run/pilgrimage.lua. Nie zapisuj siatek GPU, transientów
  lub stanu klawiszy. Zapis SIGIL08 przechowuje sloty wyposażenia (slots,
  checkslots) osobno od liczby użyć po ID. Odczyt także SIGIL06 i SIGIL07:
  dawne formaty nie miały kolejności wyposażenia, więc migracja zachowuje
  powder na Q, a pozostałe zapisane ID dopina alfabetycznie. Nieznane ID,
  duplikat, brak rekordu slotów lub niezgodne użycia są odrzucane.
  Identity sigil-breach-prototype i dwie generacje zapisu zachowano.
  Nie zmieniaj formatu bez migracji i testów uszkodzonego/starego zapisu.

Nowy demon z nowym atlasem (plan v10 V7):
  Atlas to jeden plik danych arkusza: content/art/sheets/<id>.lua (źródła
  z cięciami, kolejność klatek, stopy, kotwice, oddech pozy spoczynku).
  Klatki (content/art/enemy_frames.lua), wpis katalogu (enemy_art), pozy
  spoczynku (enemy_idle) i rozmiary obrazów (art/sources) są jego wynikiem
  (content/art/atlases.lua), nie pisze się ich ręcznie. Kroki:
  1. PNG atlasu akcji w dowolnej siatce (np. 6 x 4 albo 4 x 4) i arkusz
     2 x 2 czterech póz spoczynku, w assets/art/.
  2. Specyfikacja (plik Lua: { id, size, idle?, sources = { { path,
     columns, rows, scale?, idle? } }, poses? | template? }) i
     .\scripts\win\EXPORT-SHEET.ps1 -Spec <plik>: narzędzie znajduje cięcia
     w przezroczystych przerwach, mierzy stopy, proponuje kotwicę głowy
     (szczyt sylwetki) i zapisuje nazwane pozy (plan v11 E1). Pozy podaje
     specyfikacja (poses) albo szablon dawnego układu (template =
     'extended' 6 x 4 lub 'compact' 4 x 4, qa/art/pose_templates.lua;
     domyślnie według liczby kolumn). Poza to { clock, frames, bounds |
     rate | step, ends? } (content/art/poses.lua): zegar action (faza akcji
     0..1), seconds, countdown (minus pozostały czas), stride (droga chodu),
     world (czas świata); granice to przedziały [a, b). Wymagane: walk,
     windup, strike, recover, pain, knockdown, rise, collapse; walkRear,
     watchRear, painHeavy, hover mają zastępniki, quiet wynika z klatek
     spoczynku, strike.<atak> to osobna klatka ciosu. Arkusz z błędną pozą
     (nierosnąca granica, klatka spoza arkusza, pusta sekwencja, cykl
     zastępników, brak pozy) jest odrzucony z nazwą błędu. Dopisz moduł
     arkusza do content/art/sheets/index.lua.
  3. Anatomia jedną z dwóch dróg:
     - warstwy części: maska na część (PNG wielkości źródła, nieprzezroczyste
       = część) i legenda ({ id, atlas, body, parts = { { id, zone,
       material, hittable?, masks = { [obraz] = maska } } } });
       .\scripts\win\EXPORT-ANATOMY.ps1 -Legend <plik> -Install;
     - edytor regionów: .\scripts\win\ANATOMY-EDITOR.ps1 <id> (przeciąganie wierzchołków,
       I/Del, nowe części, strefa, materiał, kotwica, cofanie; S zapisuje
       anatomy/<id>.lua w zewnętrznym SIGIL_WORK na Linuxie; Windows:
       work/anatomy/<id>.lua), potem kopia do content/art/anatomy/.
     Dopisz moduł do content/art/anatomy/index.lua. Istniejącą adnotację
     zapisze jako dane .\scripts\win\EXPORT-ANATOMY.ps1 <id> (dokładnie te same liczby).
  4. .\scripts\win\BAKE-HIT-MASKS.ps1 (maski RLE związane ze źródłem).
  5. Definicja: content/creatures/<id>.lua (appearance.atlas, klucze
     tekstów nazwy i karty bestiariusza; body.corpse = { settle, landing }
     to czas osiadania zwłok i moment uderzenia o podłogę, niezależne od
     długości malowanego upadku), id w A.creatures;
     punkty anatomiczne w qa/data/hit_landmarks.lua.
  6. .\scripts\win\CHECK-CREATURE.ps1 <id> wypisuje każdy brakujący element (definicja,
     arkusz, obrazy, klatki, pozy (każda klatka pozy z kotwicą, anatomią
     i maską), stopy, anatomia, maski, punkty, galeria,
     bestiariusz, grafika ataków); kod wyjścia 0 = komplet.
  Zmierzony czas narzędzi (test creature-pipeline, 20 klatek nowego atlasu):
  arkusz 0,1 s, anatomia z warstw 0,16 s, maski 20 klatek 5,5 s.
  Skrypty z izolowanym uruchomieniem gry: BAKE-HIT-MASKS.ps1 (188 klatek)
  29,3 s, CHECK-CREATURE.ps1 2,7 s, EXPORT-SHEET.ps1 2,5 s,
  EXPORT-ANATOMY.ps1 2,3 s. Praca ręczna to już tylko namalowanie masek
  części (przy dwóch częściach i dwóch obrazach: cztery maski) i przegląd
  kotwic w edytorze, zamiast ok. 28 klatek ręcznych wielokątów
  i ręcznego enemy_frames.lua.

Wyposażenie i nowe rodzaje dostawy:
  Abilities.define(def) waliduje także Action i zakres całkowitych użyć;
  Abilities.give(g, id) dopina slot bez zmiany kodu postaci. Powtórne give
  zachowuje slot i użycia. W istniejącym rodzaju bolt/throw wystarczą dane.
  AbilityCast wybiera animację rzeczywiście użytego wyposażenia. name, tag
  i empty to klucze tekstów (content/text.lua; define sprawdza, że istnieją).
  HUD pokazuje każdy slot z klawiszem z app/bindings (ui/hud_slots.lua):
  jeden przedmiot w układzie 0.30, kilka po wierszu (klawisz, tag, użycia).
  Nowy rodzaj: Action.defineKind opisuje jego schemat; moduł zachowania
  zwraca funkcję (g, ability), rejestrowaną przy starcie jako
  Cast.kinds[id] = require('src.combat.<moduł>'). Treść nie importuje combat.
  Handler zwraca true po wykonaniu; wspólny caster sprawdza bramki i dopiero
  po sukcesie zużywa użycie i ustawia cooldown. Nieznany handler daje jawny
  błąd przed zmianą tych pól. content_schema sprawdza obie strony rejestru.
  Rzut zapisuje własną action na ładunku (lot, zapalnik, promień, obrażenia),
  więc drugi throw nie dziedziczy fizyki powder. Wygląd i dźwięk ładunku
  pozostają wspólne; nowy wygląd wymaga osobnej pracy prezentacyjnej.
  Nowe statusy/DoT wymagają zachowania we wspólnym systemie efektów;
  sam nowy damageType nie nadaje pociskowi statusu. Nie dodawaj ifów po ID
  wyposażenia do postaci. Przykład i testy: tests/cases/ability_extension.lua,
  uruchamiany przez --selftest --suite=extension (bez nowego wyposażenia gry).

Obserwacja strzału i skończone nagrywanie:
  combat/observation.lua przechowuje jawne dane ostatniej pokazanej geometrii
  celu i początku promienia, bez referencji do renderera, GPU, HP lub AI.
  Direct korzysta z obserwacji naciśnięcia; zwolniony tap zachowuje ją przez
  bufor 120 ms. Held pobiera najnowszą obserwację raz przed serią ticków ramki.
  Bieżący ruch myszy określa kierunek komendy. Hitscan sprawdza tę geometrię
  wobec aktualnych przesłon świata i aktualnego stanu ochrony/życia celu.
  Martwy lub usunięty obserwowany cel nadal jest kontaktem blokującym zgodnie
  z materiałem i penetracją broni, bez ponownej rany lub nagrody.
  Pocisk w locie używa aktualnej geometrii; nie odtwarza historycznego trafienia.
  Obserwacja wygasa po 320 ms (limit catch-up 200 ms + bufor 120 ms), po pauzie,
  utracie focusu, zmianie sesji lub wyczyszczeniu etapu.
  Obserwacja należy do strzelca (plan v11 E4): ma jego id i generację, a
  komenda innego aktora jest odrzucana. Wygasa też przy jego śmierci,
  odejściu albo zmianie sterowania; obserwacje innych aktorów zostają.
  Geometria pocisku i wzroku stworzeń ma jawnego obserwatora; widza kamery
  (Context.viewer) podaje tylko prezentacja. Journal zapisuje
  kopię komendy i jej przestrzeń identyfikatorów; replay nie wymaga rysowania.
  Bez --record obserwacje nie tworzą historii: aplikacja trzyma bieżący widok.

  --record jest opcjonalnym, skończonym nagraniem diagnostycznym. Limity
  content/tuning.recording to 64 MiB szacowanego tekstu lub 216000 komend
  (najwyżej 10 min samych update przy 120 Hz; look/shoot skracają ten czas).
  Dane obserwacji mogą osiągnąć limit tekstu znacznie wcześniej: pomiar
  48 ciał dawał ok. 2,1 MB/s samych komend held przy 120 Hz.
  To NIE jest limit RAM. Tabele Lua, klucze, ciągi i końcowy eksport tekstu
  zajmują dodatkową pamięć. Estymacja może przekroczyć próg o ostatnią pełną
  komendę, jej wszystkie receipts i końcowy stan integralności.
  Zatrzymanie następuje po tej komendzie; gra trwa dalej bez wrapperów
  nagrywania, a komunikat informuje o limicie. F9 zapisuje zamknięty prefiks,
  nie późniejszą rozgrywkę. Powrót do tej samej sesji nie wznawia nagrywania;
  nowa sesja otrzymuje nowy limit. Eksport F9 jest synchroniczny i duży zapis
  może na chwilę zatrzymać aplikację. Automatyczny eksport wywołany wewnątrz
  komendy czeka przez Journal.whenComplete na wszystkie jej receipts i koniec
  transakcji; direct-kill i auto-limit mają osobne reprodukcje.
  Nie zmieniaj golden dla samego PASS.
  Dowody: --suite=shot-observation, --suite=recording-budget, --hit-timing.

DODAWANIE TESTU

1. Dodaj przypadek w tests/cases lub nowy spójny zestaw w tests/suites.
2. Zestaw ma zwrócić tablicę faktycznie wykonanych wierszy 'PASS nazwa'.
   Błąd zatrzymuje test przez assert. Nie wpisuj ręcznej sumy testów.
3. Nowy zestaw zarejestruj jednym wpisem w tests/suite.lua. Kolejność jest
   jawna, bo część testów ćwiczy rzeczywisty cykl życia aplikacji.
4. Gdy zmieniasz grafikę lub UI, dodaj scenę do qa/showcase.lua albo odpowiedniego
   qa/reviews. Test powinien używać prawdziwego renderera i działań gry.
5. Nie czytaj starego test-results.txt jako podstawy powodzenia nowego testu.
6. Commit dopiero przy zielonym .\scripts\win\TEST.ps1 -Suite All (0.43, audyt 2026-11-03:
   commity 0.42 weszły z czerwonym Mechanics i ukryły regresje). Czerwony selftest
   zatrzymuje Render i Input, więc przy znanym czerwonym zestawie uruchom je osobno
   (-Suite Render -TestTimeoutSeconds 1800, -Suite Input). Znany czerwony zestaw
   wolno zostawić tylko z wpisem w ODBIOR, który mówi, co go zazieleni.
7. Zmiana balansu: jedna zmienna na commit, z sondą lub zestawem przed i po
   (souls_gate, souls_bots, chapel_route), liczby w ODBIOR.
8. Test naprawy ma być czerwony bez niej: sprawdź to, chwilowo cofając zmianę.

STYL I ZALEŻNOŚCI

Funkcja powinna mieć jedną odpowiedzialność i czytelną nazwę. Zamiast
przepisywania większego bloku ustal wspólnego właściciela operacji. Krótkie
wyliczenie matematyczne nie potrzebuje osobnej klasy. Nie dodawaj ogólnego
menedżera lub event busa, jeśli zwykła funkcja zachowuje jawną kolejność.
Nowe moduły importuj dosłowną ścieżką, np. require('src.combat.damage').
Nie twórz nowych plików system_v19.lua: nazwa ma opisywać odpowiedzialność.
Wersje w nazwach atlasów i metadanych źródłowych grafiki pozostają celowe.

Stary kod i wycofane pliki są w historii gita (folder old/ usunięto 2026-11-03;
wzorce broni v32/v33: commit e44c509). Starsza nazwa nie oznacza śmiecia:
przed usunięciem sprawdź odwołania w game/src, tests, qa i tools, także
ścieżki składane w kodzie oraz źródła odbudowy zasobów.

Narzędzia grafiki: tools/art; wymagają własnych zmiennych SIGIL_* wskazujących
materiał wejściowy. Są zachowanym warsztatem produkcji, nie częścią uruchomienia
gry. Nie uruchamiaj ich masowo: część zapisuje atlasy lub wygenerowane metadane.

Broń w grze: shotgun-iron-v16.png i revolver-iron-v16.png (od 998b189
ponownie aktywne). Arkusze v32/v33 i ich warsztat (tools/art/weapon_cycles_v32)
są w historii gita.

REFAKTOR 0.18 / DOWODY

2291 sprawdzeń mechaniki/zasobów, 52 callbacków/zapisu, 177 plików Lua
kompilowanych przez kontrolę architektury. Zachowano 2241 wcześniejszych
sprawdzeń i dodano 50 dotyczących raportowania, sesji i aplikacji/zasobów.
Przed migracją nazw porównano 2460 pełnych stanów symulacji z kopią 0.17
przy jednakowym ziarnie RNG: identyczne. Źródłowy audyt bitmap: 260 widoków,
6670 granic tekstu, 71820 porównań obrazów, 3275 wnętrz HUD, zero problemów.
To weryfikacja automatyczna; nie zastępuje ludzkiej oceny balansu i feelingu.

FUNDAMENT v11 / ODBIÓR 0.34

Receptury nowych póz, trybu, rycerza, urządzenia i widoku znajdują się
w ROZSZERZANIE (punkty 17–22). Ich działające próby: named-poses,
mode-state, actors, observer, view-context. W produkcji nadal jeden
poligon, jeden gracz i ten sam HUD. Kolejny widok nie wykonuje kroku świata.

Pomiary E3–E5: raport planu v11 w historii gita, surowe logi
work/v11-measure-final-e3, e4, e5. Baza: E0 710d1ac; etapy: 8797d30,
4a03cb4, e00c817. Każdy wariant w świeżym procesie, pięć naprzemiennych
par, High bez affinity; rozgrzewka 300, kroków 2400, klatek 720.
Nie uruchamiaj innych QA ani nie edytuj game podczas pomiaru.

--view-measure przy SIGIL_VIEW_COUNT=1 albo 2 mierzy cały krok i pełne
obrazy 1280x720 (renderer, HUD, postprocessing, interpolacja, odczyt
1 piksela dla synchronizacji). Świat z dwoma rycerzami jest taki sam;
zmienia się tylko liczba obserwowanych widoków. W fazie rysowania świat
jest zamrożony, bez present/VSync. Pełne próbki: work/v11-views-final.
To koszt dwóch pełnych obrazów, nie dwa mniejsze okna ani pomiar FPS.

--resource-plateau wykonuje osiem rzeczywistych cykli aplikacji przez
menu, poligon, dodatkowy widok, replay i kaplicę. Mierzy zasoby natywne
i stertę Lua, sprawdza właścicieli po zamknięciu. Normalne cykle nie
wyłączają JIT; pojedyncze końcowe usunięcie trace'ów jest tylko audytem
rozróżniającym referencje aplikacji od referencji skompilowanych domknięć.
Nie kopiuj tego jit.flush do kodu produkcyjnego. Liczby tekstur wracają
do poziomu pierwszego rozgrzanego cyklu; sterta Lua jest raportowana
oddzielnie, bez arbitralnego progu obietnicy stałego RAM.

Końcowe dowody source-*.evidence.json pozostają w work/qa oraz jego
tool-smoke. To historyczna nazwa katalogu, nie wersja źródeł. Wydanie
jest odczytywane z src/core/build.lua. Nie regeneruj tests/fixtures/v033;
osobne legacy-v033 powstały kodem E0, z uwzględnieniem niższej precyzji
dawnego formatu tostring. Nagrania 0.33 nie stają się nagraniami 0.34.

Ścisły protokół wydajności nie jest automatycznie zaliczony: duży IQR
występuje też w A/A. Decyzja o kryterium praktycznym należy do użytkownika.
Odbiór B2 pozostaje osobny od testów technicznych.

Zmierzony koszt drugiego widoku (mediana pięciu procesów, ms):
  cały krok z capture: 1 widok 0.1817, 2 widoki 0.2072, iloraz 1.140.
  pełny obraz z HUD i synchronizacją: 1 widok 5.1249, 2 widoki 9.4206, iloraz 1.838.
  W obu wariantach ta sama symulacja dwóch rycerzy; dziesięć prób
  daje identyczny SHA-256 stanu. Pełne IQR: raport planu v11 w historii gita.

## Architektura

_Dawniej: `game/docs/ARCHITEKTURA.txt`_

FUNDAMENT v12 (0.36)

Cios w stworzenie ma jedną drogę: combat/hit.lua (measure, wound, answer, land), a
rana jedno wejście: Rules.wound. Akcja ma jeden wpis w combat/action_kinds.lua i
jedno wykonanie dla stwora, aktora i punktu (combat/caster.lua). Rejestry zamiast
wyjątków: content/damage_types, attributes, conditions, reloads, triggers, runs,
glyphs, supplies, hazards, core/tiles. Rzeczy świata: session/entities.lua, pula
entities, wpięcie w krok przez Scheduler.after. Zapadki planu w tools/check.

SIGIL: BREACH / ARCHITEKTURA KODU / Foundation 0.34

Korekta drugich faz (po punkcie 5): Action.pattern opisuje do 12 lokalnych
punktów kontaktu (forward/lateral/delay) względem zamrożonego kierunku
celowania. enemies/ground_pattern jest wykonawcą dostawy w ranged_kinds;
nie dodaje drugiego AI ani osobnego systemu obrażeń. Po release zwykłe
hazards posiadają ostrzeżenie, volume, packet, owner/side i czas życia.
Nie ma obrażeń w windup ani znaczników śledzących późniejsze wejście gracza.
Punkty za ścianą lub w bryle odpadają. pool pulsuje, lightning trafia raz;
kontakt nadal uwzględnia wysokość, skok, strop i osłonę przez area_contact.
Tak jak wcześniej: śmierć właściciela anuluje pioruny, wypuszczony ogień
żyje do końca swojego czasu. Reset próby usuwa oba rodzaje.
Opcjonalne phase.transitionPose wybiera nazwany przebieg istniejącego
atlasu; phaseEnteredAt jest serializowanym polem brain. Wspólny sampler
animation wybiera klatkę zarówno dla obrazu, jak i geometrii trafienia.
windup.<id> i strike.<id> pozwalają odróżniać gesty ataków danymi; brak
własnej pozy wraca do podstawowej. ArtContract sprawdza te referencje.
HUD i pliki graficzne tej korekty pozostają bez zmian.

Punkt 5 poligonu: app/release.sessionMaps wybiera mapę proving przy wejściu
z menu; jawny mapId wygrywa. Domyślna mapa to proving.
Mapa proving opisuje komnaty, wejścia, miejsca przywołań, próby i medale
interakcji. content/defs/proving sprawdza strukturę/identyfikatory/powiązania,
run/field/chambers weryfikuje bryły postaci względem zbudowanej geometrii.
Komendy katalogu i E korzystają z tego samego właściciela próby: reset,
ustawienie gracza, prawdziwe portale, rejestr przybyłych id, końcowa śmierć.
Nie ma drugiego AI ani nagród komnaty, ścian niewidzialnych czy smyczy.
roomTrial należy do testField, więc obejmują go snapshot oraz journal.
  Poligon nie zapisuje niczego na dysk. SIGIL09 (mapa/ciała) nadal nie jest
pełnym checkpointem trybu; nie dodano częściowego zapisu samych komnat.
exhibits=false pomija plansze atlasów i posągi w publicznej walce; stara
galeria, mapa i scenariusze pozostają dostępne dla narzędzi bibliotecznych.
Tekst próby mieści się w istniejącym polu kontekstu; brak panelu PHASE.

Punkt 4 poligonu: enemies/attack_selection wybiera atak, actions wykonuje
jego istniejący cykl. Bez tactics działa dawny wybór uporządkowany; tactics
dobiera odległość, wagę, odnowienie i historię rozpoczęć. Phases w danych
creature są walidowane przez content/defs/encounter. enemies/encounter
rozstrzyga próg przed BodyHit/EnemyKilled: odnawia zapas bez śmierci,
anuluje niedostarczony atak i wchodzi w istniejący stan recover.
phaseIndex/phaseBaseHp/lastAttack/attackRepeats są stanem komponentów;
snapshot, zapis i journal obejmują je. damageEnemy zwraca rzeczywistą
utratę zdrowia; puls efektu nie odejmuje nowego zapasu HP od starego.
EnemyPhaseChanged służy prezentacji, a nagrody i otwarcie wyjścia nadal
należą tylko do EnemyKilled. Bieżące kontrakty: ROZSZERZANIE.txt;
plan etapu poligonu pozostaje w historii gita.

LÖVE 11.5 / LuaJIT / Lua 5.1. Baza pod rozbudowę (hub/baza, więcej demonów,
zaklęć demonów, broni i wyposażenia rycerza, map, trybów). Model: sesja = świat ECS nad własnymi tablicami
+ dwufazowa szyna zdarzeń + jawny harmonogram systemów + dane jako
Type Object ze schematami + rejestry wszystkiego, czego może być więcej.
Symulacja nie zna prezentacji (działa bez grafiki i dźwięku). Zachowanie gry
jest zamrożone złotym wzorcem (tests/golden/baseline.lua); świadoma zmiana
rozgrywki aktualizuje bazę i jest opisana w ZMIANY.

Geometria ataków (punkt 3 poligonu): content/defs/area waliduje skończone
pasma wysokości; combat/area_contact rozstrzyga kolumny/kałuże/lądowanie
z osłoną i próbkowaniem czasu. Sfery pocisków i ciosów korzystają z
physics/cylinder_cast; projectile_shape dzieli promień z prezentacją.
ballistics.world rozlicza również stropy przy sprawdzaniu osłony wybuchów
i ataków obszarowych. Nie utożsamiamy maski strzału, kolizji ruchu,
próbki ekspozycji wybuchu i bryły ataku — każdy kontrakt jest jawny.

1. PRZEPŁYW STEROWANIA

  main.lua (callbacki LÖVE)
    -> app/application   uruchomienie, ustawienia, aktywna sesja, renderer;
                         ładuje prezentację (feedback/install.lua); sprząta
                         pamięć przy przejściach (Application.settle);
                         Application:adopt = jedyne wejście nowej aktywnej
                         sesji (ustawienia, dziennik --record, sprzątanie);
                         raport sesji (app/session_report.lua)
    -> app/input         klawisze z app/bindings.lua, mysz -> Game:look;
                         klawisz ekranu = wpis app/screens
    -> app/commands      rejestr poleceń (przycisk i klawisz = ten sam id);
                         znaczenie poleceń trybu: Modes.act
    -> session/game      fasada sesji: publiczne polecenia gracza
    -> session/simulation krok 1/120 s: zegar, bramka pauzy, harmonogram
                         systemów (core/scheduler), potem słuchacze 'present'
    -> render/presentation + render/renderer + ui/interface   (tylko odczyt)

2. WARSTWY (pilnuje tools/check/main.lua)

  src/core      fundament bez zależności: class, schema, registry, events,
                ecs, scheduler, rng, timers, strict, serialize, mathx.
  src/content   dane (Type Object): content/defs (packet, body, action,
                creature + appearance, knight, weapon, ability, condition),
  stworzenia, rycerz, bronie, umiejętności, stany, mapy,
  strojenie, dane trybów (pilgrimage, field, shop).
  src/physics   kolizje, wysokości kafli, wysokość podłogi (ground.lua).
                ordnance_flight: lot/odbicia ładunku z przekazanymi danymi;
                okrągłe kolumny mają radialną normalną i okrągły blat.
  SYMULACJA: src/combat, src/enemies, src/player, src/session, src/systems,
             src/run, src/world — NIE importują feedback/render/ui/audio/app.
  PREZENTACJA: src/feedback (słuchacze 'present', haki prezentacji),
             src/render, src/ui, src/audio; src/app łączy całość.
  src/storage   zapisy i preferencje.

  Kontrola: kompilacja, brak cykli, granice warstw, brak nieosiągalnych
  modułów, brak GPU w danych/fizyce, KIERUNEK symulacja -> prezentacja
  (zapadka tools/check/presentation-edges.txt; 0 krawędzi), każde zdarzenie
  katalogu ma emiter, ZAPADKA NIENAZWANYCH LICZB w kodzie symulacji, app
  i feedback (tools/check/literals.txt; plik może tylko maleć, nowy = 0),
  IMPULSE WRITE (zdarzenie porusza kanał z content/view_reactions.lua tylko przez
  Impulses.react w feedback/impulses.lua).
  Zapadki skalowania planu v10 (tools/check/<nazwa>.txt, ta sama zasada):
  knight-references (g.player w symulacji poza modułami rycerza), pool-arrays
  (bezpośrednie tablice pul poza session/world i state), mode-records
  (g.run / g.testField poza modułami trybów), player-text (napisy dla gracza
  poza content/text). Etap planu, który usuwa dane założenie, sprowadza
  licznik do 0.

3. SYMULACJA BEZ PREZENTACJI (session/presentation.lua)

  Symulacja woła haki: Presentation.call(g, 'nazwa', ...), cue (dźwięk),
  capture (mysz), stage (krok harmonogramu: efekty, cząstki, audio).
  feedback/install.lua rejestruje haki i słuchacze przy starcie aplikacji.
  Bez prezentacji (serwer, boty, test headless) haki nic nie robią, a
  symulacja daje ten sam skrót (tests/cases/headless.lua). Symulacja nie pisze
  g.view: łuski wyrzuca słuchacz ReloadStage (spent), liczby obrażeń
  feedback/damage_numbers.lua (VolleyResolved, BlowResolved.number).
  Zwłoki: enemies/corpse.lua — krew, łoskot i plamy to feedback/
  death_response.lua przez haki.

4. MODEL DANYCH SESJI

  Sesja (g): pola symulacji z właścicielami w src/session/fields.lua; stan
  widoku (kamera, odrzut, ruch broni, efekty, napisy, shotAge, swapAge) w
  g.view (Fields.view). Odczyt/zapis pola widoku na sesji to błąd (metatabela
  Game). Złoty test odrzuca niezadeklarowane pola obu.

  ECS (core/ecs + session/world.lua + session/components.lua): pule nad
  tablicami sesji (enemies, remains, projectiles=g.bullets, hazards,
  pickups, charges, knights). Świat posiada członkostwo: kod gry czyta
  i zmienia pule wyłącznie przez Pools (session/world.lua: of, add,
  removeAt, remove, keep, clear, get, retire), nigdy przez pola tablic
  sesji (zapadka pool-arrays = 0). Stworzenia i rycerze mają id; Pools.get
  znajduje je w O(1), także martwe w remains. remains to zwłoki osiadłe,
  w spoczynku i po oknie rysowania (Corpse.done, combat_defaults.corpse.
  visible): żadna pętla kroku ich nie odwiedza. knights to pula 1..n;
  g.player to sterowany rycerz. Prefaby, tryb ścisły w testach.
  Usuwanie w trakcie pętli: wstecz przez removeAt albo keep po pętli.
  Definicje treści są tylko do odczytu: testy pieczętują je
  (session/definitions.lua) i przerywają przebieg przy zmianie pola.

  Rycerz: player.loadout + player.arsenal[id] = { mag, reserve, open, loaded,
  spent, readyAt }; player.abilities + player.abilityState[id] = { uses,
  readyAt }; dodgeFromX/Z = powidok uniku. Demon: brokenAge = jego zegar
  (spawnAge) w chwili utraty równowagi (zabójstwo przełamane w oknie).

5. KROK SYMULACJI (systems/index.lua — JEDYNE miejsce kolejności)

  clocks -> knight.recovery -> knight.reload -> knight.snapshot ->
  knight.motion -> knight.contact -> world.effects -> world.transientsBefore
  -> knight.trigger -> combat.demons -> combat.separation -> combat.bodies ->
  combat.hazards -> combat.projectiles -> combat.charges -> combat.contactEffects -> world.telemetry ->
  world.remains -> world.stillPlaying -> world.transientsAfter -> world.supplies ->
  world.progression (Modes.of(g).progress).
  Ciała (combat/body_contact.lua): kto wszedł w drugie żywe ciało, zatrzymuje
  się na kontakcie (rycerz po swoim ruchu, demony po swoim); pęd z ciosów
  przechodzi prawem mas (P.contact). g.worldStop (przełamana garda rycerza)
  wstrzymuje zagrożenia, pociski i ładunki — systemy pytają
  session/capabilities.lua (held, missilesFly, groundActs, demonsAct,
  vulnerable), jedyne miejsce zasad „co dziś działa”. Zegary wstrzymania
  (impactSlow, worldStop) odlicza systems/clocks.

6. ZDARZENIA (core/events, session/event_catalog.lua)

  Katalog rodzajów (ShotFired, BodyHit, EnemyKilled, PlayerHit, AbilityCast,
  ReloadStage, BlowResolved, WaveCleared, ModeStarted...); nieznany = błąd,
  nieemitowany = błąd checkera. 'sim' natychmiast (nagrody trybu, combo,
  hit-stop, pomiary), 'present' po kroku (dźwięk, cząstki, kamera, liczby).

7. BRONIE, UMIEJĘTNOŚCI, WYGLĄD, WALKA

  content/weapons.lua: rejestr broni po id (Weapon.define; fire.noise, glyphs
  set/scale/spread, pierce.minRetain), W.inHand/state/ammo/load/give/nextSlot.
  combat/reload.lua: mechanizmy (breech, cylinder) z czasami w danych
  (tuning.reload); interruptBefore + closing: strzał przerywa przeładowanie.
  combat/combat.lua: ready (zachwianie blokuje strzał) -> discharge -> Volley.
  combat/observation.lua: serializowalna geometria ostatnio pokazanego
  obrazu, przekazana jako jawna część komendy przez kontroler. Kliknięcie,
  przytrzymanie i bufor mają ten sam kontrakt. Resolver nie cofa HP/pancerza
  ani nagród; obecne ściany nadal blokują promień. Ważność jest ograniczona
  sesją, generacją i tuning.observation.maxAge. Zmiana sesji/pauzy/fokusu
  unieważnia zamiar. Pocisk w locie korzysta z aktualnego kontaktu.
  combat/damage.lua: Damage.rating = pancerz trafionej części (obrażenia,
  raport, przebicie). content/abilities.lua + combat/abilities.lua (Cast.kinds).
  Idealny unik: combat/dodge.lua — Dodge.afterimage (cios na powidoku) i
  Dodge.perfect (zwrot ładunku, zamrożenie, garda); wołają go ścieżka obrażeń,
  ataki (pazur, szarża, lądowanie), pociski i pioruny. Tylko cios z pakietem,
  tylko w grze i gdy rycerz jest podatny (Capabilities.vulnerable).
  Prezentacja strzału (bez wpływu na symulację): weight.viewKick/viewKickRate/
  thump w definicji broni -> feedback/weight.lua (podskok widoku aimKick,
  sprężyna krytycznie tłumiona; łomot) -> renderer (pitch + aimKick). Ręce:
  shader render/shaders.lua hands z danymi WeaponArt.look (światło, mgła,
  nasycenie, kontrast, cień); Weapon.handsShader dla broni i ręki rzutu.
  Stworzenie: appearance i guardian; content/enemies.lua A.of(e), A.look(e).
  Trafienie w ciało (0.29: jedna reprezentacja na stworzenie, jawnie):
  appearance.hit = 'painted' (domyślnie; enemies/surface: maska atlasu +
  adnotacja anatomii appearance.regions, domyślnie atlas) albo 'volumes'
  (enemies/geometry: profil brył appearance.anatomy w enemies/hit_volumes.lua,
  dziś pusty rejestr). B.prepare przygotowuje tylko używaną; Geometry.uses(e)
  wybiera. Strefa (zone), część (id), materiał, ruch (Rules.radius), atak
  (combat/melee: M.window/M.reach) i rejestracja obrazu (enemies/pose) są
  osobne; nic nie zależy od indeksu „części głowy”.
  Zwłoki na linii strzału: enemies/corpse.lua (Corpse.settled, Corpse.shields)
  — jedna reguła dla strzału natychmiastowego (B.blocks) i pocisków rycerza.
  Przełamanie przy zabójstwie: combat/rules/balance.lua R.offBalance(e, causes)
  ustala decyzję i przyczyny (guard, wound, knockdown, micro, trip) w jednym
  miejscu; EnemyKilled niesie causes, telemetria tylko je liczy.

8. MAPY, TRYBY, EKRANY

  content/maps/<id>.lua + content/maps/index.lua: pokoje, kolumny, pieczęcie,
  portal, spawn, kaganki, Ember, bramy przywołań, strefy, floor (wysokość podłogi);
  elevations (podpora na komórkach), decks (płyty nad podłogą: most),
  decor (scenografia) i anchors (miejsca). Mapa jest prostokątem width ×
  depth (size dla kwadratu); physics/grid.lua jest jedyną odpowiedzią na
  wymiary. content/maps/schema odrzuca uszkodzone wymiary/listy przed budową.
  world/arena.lua buduje świat (Game.new(kind, mapId)); W.clear = przejście
  ciała w linii.
  Przestrzeń w skali (plan v10 V3):
  - Ciała w indeksie przestrzennym (physics/spatial.lua): separacja tłumu
    i promienie strzałów pytają o sąsiedztwo, nie o każdą parę (wynik
    identyczny bit w bit z przejściem po wszystkich parach, test).
  - Węzły chodu: podłoga komórki albo płyta nad nią (W.node, W.layer,
    W.step). W.flow = pole odległości wokół celu w oknie navigation.window
    komórek, na klasę prześwitu (promień, a przy płytach wysokość ciała),
    pamięć LRU. Dalej world/navigation.lua: regiony sektorów, łącza między
    nimi, przejścia; Navigation.waypoint/distance. Zapytanie drogi nie
    przechodzi całej mapy (licznik odwiedzonych węzłów w teście).
  - Płyty (physics/ground.lua): Ground.height(w, x, z, y) = powierzchnia pod
    wysokością y; ciało pamięta swoją (o.level, ustawia W.move); Ground.of(w,
    o) to podłoga ciała, miejsca, pocisku. Kolizja zatrzymuje głowę na płycie
    (Rules.tall), skok, lot i upadek kończą się na jej spodzie (Rules.ceiling);
    promienie, pociski i ładunki trafiają w górę, spód i bok płyty. Mapa bez
    płyt idzie dokładnie dawną drogą (o.level = nil).
  - Światła: dowolna liczba; 14 miejsc w shaderze dostają najbliższe kamerze
    (stałe miejsce, wygaszanie, raport lights.report); mapa szersza niż 32
    komórki ma okno 32 komórek na światło i obraz podłoża całej mapy; płyta
    nie przepuszcza światła na drugą stronę. Ciała jednego obrazu to jedno
    wywołanie (render/instances.lua), cienie i plamy pod nimi tak samo.
  Prezentacja otwarta (plan v10 V6):
  - Klatka to lista przejść (render/passes/: architecture, projectiles,
    ground, enemy_marks, hazards, ash, sprites, effects; R.passes); kolejność
    to kontrakt głębi i mieszania.
  - Obiekty świata rejestrują rysowanie (render/world_objects.lua:
    register(rodzaj, { { pass, order, draw }..., init?, overlay?, release? })):
    przejście rysuje zarejestrowanych w kolejności order. Wbudowane:
    render/world_art.lua (kaganek, pieczęć, zapasy, Żar, freski, echo,
    brama, wyjście, sekret, rekwizyt, galeria). Renderer nie zna ich nazw;
    nowy rodzaj = jedna rejestracja (test open-presentation).
  - Teksty: content/text.lua — klucz -> szablon z {parametrami}; definicje
    treści (broń, stworzenie, wyposażenie, oferta, strefa, pieczęć,
    stanowisko) niosą klucze, rysujący woła Text.get. Text.language(nazwa,
    szablony, malunki) + Text.use: inny język bez zmian kodu (brakujący klucz
    = szablon bazowy). Napisy malowane: rejestr ui/fonts/painted_titles
    (names); bez malunku w atlasie albo w języku bez własnych malunków napis
    pisany glifami (Skin.inscription). Zapadka player-text = 0.
  - HUD z deklaracji slotów (ui/hud_slots.lua): arsenał N broni w dwóch
    wierszach wokół broni w ręku; wyposażenie każdego slotu z klawiszem
    (app/bindings: Q, F, C) — jeden pełny jak w 0.30, więcej po wierszu.
  - qa/data/bridge_map.lua (qa_bridge, 256 × 128, most, 200 kaganków) i
    qa/data/crowd_map.lua (qa_crowd) to mapy diagnostyczne QA.
  run/modes.lua: rejestr trybów (field, pilgrimage: init, start,
  progress, policy + ready, retry, closeShop, buy, lose, reward);
  Modes.act(g, nazwa, ...) — polecenia i skutki pytają tryb. Stan trybu
  (g.run, g.testField) czyta tylko on sam: [E] i podpowiedź (interact,
  context), pozwolenia (frozen, invincible, attrition: session/capabilities),
  dane paska HUD (hud: glyph, wallet, echo, progress). Nowy tryb odpowiada tymi
  funkcjami. Ekrany i HUD pytają tryb (plan v10 V6): session/queries.lua — run
  (sakiewka, echo, ogniska), field (ustawienia i wybór poligonu), world, tools,
  objective; widoki buduje tryb z własnego rekordu (run/mode_views.lua).
  Zapadka mode-records = 0. Handel: run/economy.lua (E.trade, bez zapisu) i
  Sanctuary.trade / closeTrade (session/sanctuary.lua); kaplica sama zapisuje zakup.
  run/pilgrimage.lua: droga przez kaplicę, dane w content/pilgrimage.lua.
  field: niezależny sandbox. Tryb z prepared przygotowuje malowany świat na
  ekranie ładowania (app/application: kit/halls loadingJobs, prepareWorld); podczas
  ładowania symulacja stoi. Poligon i ekrany współdzielą pętlę aplikacji.
  app/screens.lua: klawisze ekranów; ui/views.lua: rysowanie i przyciski;
  ui/interface.lua tylko rozdziela.
  Game.new i Journal.session korzystają ze wspólnego Modes.session.
  Renderery i ekrany pytają session/queries. app/navigation posiada stos powrotów.
  Poligon (run/test_field.lua) to cykl życia, komunikaty i akcje katalogu;
  stawianie celów i wezwania (run/field/placement.lua, run/gates.lua), odwiedziny
  pieczęci i sklepu (visits.lua), stanowiska (trials.lua); liczby
  poligonu w content/field.lua.
  Pełny reset próby korzysta z run/actor_reset.lua (rycerz) i
  run/field/reset.lua (sesja). Reset aktora jest wspólny dla próby poligonu,
  odpoczynku, retry, podróży i zakupu w kaplicy (0.42): kończy rzucanie bez
  opłaty, usuwa warunki (w tym oszołomienie), poise, impulsy, efekty, rally,
  serię, ruch, unik i bufory wejścia; zachowuje tożsamość, wyposażenie i
  postęp. Reset.session kończy worldStop, usuwa stare podparcie, zapadki ruchu
  i diagnostykę walki, zrzuca oczekujące efekty prezentacji.
  Refill uzupełnia zasoby; clearStage kończy falę. Żaden nie staje się
  pełnym resetem próby. ID, RNG i czas sesji nie są przewijane; obserwacje
  zostają unieważnione, a czas próby i pomiary zaczynają od nowa.
  world_mesh posiada zasób GPU poza serializowanym rekordem świata.
  app/load_plan obsługuje także start: audio, bitmapy UI, renderer i broń
  mają punkty oddania sterowania między zasobami. Pojedynczy upload obrazu
  jest nadal niepodzielny; postęp nie oznacza gwarancji stałego czasu klatki.

9. ZAPIS, POWTÓRKI, DETERMINIZM, POMIARY

  core/rng (strumienie sim/present). session/snapshot.lua (Memento; zbiór
  definicji współdzielonych liczony raz, odświeżany przy zmianie zestawu lub
  tożsamości modułów src.content). Narzędzie dodające nowe zagnieżdżone
  definicje do już wczytanego modułu wywołuje Snapshot.invalidateDefinitions()
  przed kolejnym capture/restore. Istniejące definicje pozostają niezmienne
  przez życie sesji i snapshotów; API nie migruje działającej sesji.
  Wersja kompilacji: core/build.lua — Journal stempluje
  ją w nagłówku bez udziału aplikacji (powtórka w narzędziu = ta sama wersja).
  Dodatkowo źródłowy SHA pochodzi z uruchomienia QA albo wygenerowanego
  build-fingerprint.txt w paczce. Sam numer wersji nie poświadcza kodu.
  Bez SHA zwykły start developerski jest oznaczony jako niepoświadczony.
  Journal v4 (plan v10 V5): komenda strzału niesie tylko ciała korytarza
  strzału (Observation.command: stożek rozrzutu każdej noszonej broni
  × zasięg + sfera ograniczająca ciała; resolver poza nim niczego nie
  trafia); obserwacja bez użycia przez strzał zostaje samym nagłówkiem,
  ciała wchodzą przy ObservationUsed; ciało niezmienione to odwołanie,
  zmienione to różnica pól od poprzedniego wpisu. v3/v2 nadal odtwarzane.
  Odtworzenie nie mutuje danych archiwum.
  session/journal.lua: polecenia (look, update, shoot, cast, reloadGun,
  switchWeapon, dash, interact, start, act = polecenia trybu przez Game:act)
  + 'aim' (bezpośrednie ustawienie) + 'set' (stan, pauza, mapa, pomoc,
  zamiary ustawione przez aplikację między poleceniami) + 'actorSet' (te
  same zamiary i generacja obserwacji innych rycerzy: drugie urządzenie,
  Journal.actorExternal) + origin w nagłówku;
  --record + F9 zapisuje dziennik (każdej sesji przyjętej przez adopt, także
  poligonu: akcje katalogu to polecenie 'field', a nagłówek niesie warunki
  początkowe poligonu).
  Zapis (plan v10 V4): storage/save.lua to rdzeń bez wiedzy o sekcjach.
  Plik SIGIL09 = rodzaj pliku, numer, suma kontrolna i drzewo
  { sekcja = { version, data } } przez core/serialize; odczyt literalnym
  core/data_reader (nic się nie wykonuje). Sekcję deklaruje jej właściciel
  (Save.declare: name, file, version, schema, pack, unpack, restore,
  migrations, default): 'pilgrimage' w run/pilgrimage.lua (droga przez kaplicę),
  'map' w world/arena.lua, 'pools' w session/world.lua (członkowie pul ze
  stronami, definicje jako ścieżki core/data_tree.lua, wspólne tabele raz).
  Każdy błąd odrzuca cały plik przed przywróceniem czegokolwiek. Zapis jest
  atomowy: plik obok (.tmp), sprawdzony, zamiana, poprzedni zostaje
  (.previous); odczyt bierze najnowszy pełny z trzech. SIGIL06/07/08 czyta
  zapis tylko SIGIL09. storage/session_save.lua: zapis
  stanu sesji (mapa, pule, strony).  Złoty wzorzec to odcisk regresji wybranych pól trzech scenariuszy (nie
  wyrocznia poprawności): części ciała, stany i telemetria są poza nim.
  Telemetria (combat/telemetry.lua: T.copy, T.since, T.lines) w grze i w
  botach; app/session_report.lua słucha zdarzeń (Presentation.attacher:
  PlayerHit -> śmierć, EnemyKilled -> poligon oczyszczony, WaveCleared) i F9;
  każdy wpis = „to starcie” (różnica od znacznika) + „od początku pomiarów”.
  Plik: <katalog zapisu LÖVE>/telemetry.txt (Report.path; ze źródeł
  %APPDATA%\LOVE\sigil-breach-prototype, EXE %APPDATA%\sigil-breach-prototype).
  qa/golden.lua + baseline; qa/scenarios/playtest.lua: populacje (podstawowa
  i wprawna) z celami S.targets.
  Trafienia względem obrazu (plan v7 H0): render/renderer.lua
  R:enemyPlacement = jedna transformacja sprite'a (shader i pomiar);
  qa/hit_truth.lua = reguła piksela shadera na CPU (sprawdzana z GPU);
  qa/reviews/hit_truth.lua = przebiegi żywych stanów i raporty hit-*;
  qa/data/hit_landmarks.lua + qa/hit_landmarks.lua = punkty anatomiczne
  (test tests/cases/hit_landmarks.lua: znane wady oznaczone etapem planu).

10. WZORCE PROJEKTOWE

  Fasada (session/game, combat/rules), Type Object (content/defs),
  Prototyp (extends/from), Fabryka/Prefab (ecs:create), Komponent/ECS,
  Strategia (Attacks.kinds, Cast.kinds, AI.styles, mechanizmy, E.kinds,
  supplies, Modes), Stan (AI.states, tryb), Obserwator (core/events),
  Odwrócenie zależności (session/presentation: haki), Łańcuch
  odpowiedzialności (ui/views), Harmonogram, Metoda szablonowa (C.shoot,
  R:draw), Rejestr (core/registry), Memento, Polecenie (commands, journal,
  Game:look), Pamięć podręczna (W.flow).

11. GDZIE MIESZKAJĄ LICZBY

  content/tuning.lua (ruch, bronie, ekonomia, reload, reach, floorSurface,
  flowFields, collector + grupy: clocks, knight, motion, camera, rewards,
  shot, explosives, world, feel), content/combat_defaults.lua (ciała i demony:
  impulse, stagger, breakKill, walk, flank, keep, senses, separation, attacks,
  claw, missiles, hazards, corpse, flashes, locks...), content/knight.lua,
  content/maps/*, content/pilgrimage|field|shop,
  definicje stworzeń/broni/umiejętności, content/ballistic_surfaces.lua
  (wound, guard, penetrable, debris), content/art/anatomy/* (regiony obrazu),
  physics/collision (heights), ui/palette.lua, app/bindings.lua (klawisze).
  enemies/hit_volumes.lua nie ma już liczb (0.29: dawna kalibracja walców
  malowanych demonów usunięta; rejestr profili dla appearance.hit='volumes').

12. JAK DODAĆ (przepisy — sprawdzone w tests/cases/extension.lua, engine.lua
    i creature_extension.lua)

  Demon na ISTNIEJĄCEJ ilustracji (wariant, inny pancerz, inne zachowanie):
  content/creatures/<id>.lua: Creature.define({ extends = rodzic, ... }), id w
  A.creatures. Atlas, maski, klatki i animacje umiejętności dziedziczy.
  Gdzie jest wymieniony, mówi jego definicja (catalog, nie dziedziczy się):
  field = miejsce w katalogu poligonu i na polach; bestiary =
  { order, text, tip, color } karta pomocy F1. Listy buduje A.listed(klucz);
  ekranów się nie edytuje. Nowy stwór na mapie: posterunek w content/pilgrimage.lua.
  Odmiana ciała w grze: e.variant (id odmiany z definicji), A.of(e).
  Inny opis ciała na tym samym obrazie (płyty, inne materiały, inna liczba
  części jednej strefy): adnotacja w content/art/anatomy/<id>.lua, wpis w
  anatomy_regions.layouts i appearance.regions = '<id>'; adnotacja ma klatkę
  dla każdej klatki atlasu (test anatomy-data) i spełnia Anatomy.problems.
  Atak i unik łączy się danymi: attacks (z rodzica lub from=), move.evade,
  appearance.art (atak -> arkusz) i appearance.evadeArt. Nowy materiał: wpis
  w content/ballistic_surfaces.lua (wound, guard, penetrable, debris) — strzał
  i efekty czytają politykę, nigdy nazwy. Masa i promień: ruch i kontakt ciał.
  Demon z NOWYM atlasem (plan v10 V7; kroki i czasy: DEVELOPMENT): PNG,
  arkusz content/art/sheets/<id>.lua z narzędzia (EXPORT-SHEET.ps1 -Spec:
  cięcia w przerwach, stopy, kotwice, kolejność, nazwane pozy) i jego
  linia w sheets/index.lua; klatki, wpis enemy_art, pozy spoczynku
  i rozmiary wylicza content/art/atlases.lua. Nazwane pozy (plan v11 E1,
  content/art/poses.lua): arkusz mówi, które klatki pokazuje każdy stan
  i jaki zegar je wybiera (action, seconds, countdown, stride, world,
  breath); enemies/animation.lua pyta o pozę po nazwie i nie zna numeru
  klatki ani układu. Zwłoki mają własne liczby (body.corpse.settle
  i landing): długość malowanego upadku decyduje tylko o tym, co widać.
  Stan trybu (plan v11 E2): strażnik należy do rekordu spotkania
  (g.encounter, API session/encounter.lua), pieczęcie i sekret do świata
  (World.activeSeals, world.secretFound), stan prywatny trybu do jego
  rekordu (Modes: record = 'run' | 'testField' | 'modeData'; haki reset,
  snapshot, load, save). Prezentacja czyta tylko widoki (session/queries.lua):
  widok należy do sesji, jest ważny do następnego kroku albo polecenia,
  Queries.copy daje kopię na własność. Nowy tryb trzyma stan w g.modeData,
  cel w objective, znaczniki mapy w markers widoku świata (test mode-state:
  tryb „ołtarze”).
  Aktorzy (plan v11 E3): broń w ręku, przeładowanie, spust, strzały
  i sekwencja strzałów są polami rycerza; statystyki są w księdze
  session/stats.lua (na id aktora, sumy przez Stats.total). Polecenia sesji
  przyjmują id aktora, systemy rycerza obsługują każdego rycerza puli na
  jego wejściu (input.actors[id]). Każde obrażenie niesie właściciela
  łańcucha (owner): zabójstwo, wynik, leczenie i nagroda należą do niego.
  Dziennik v5: header.actors, actorJoin/actorLeave/actorControl, preflight
  id. Obserwacja strzału (E4) nazywa strzelca i jego generację. Komenda
  innego aktora jest odrzucana bez zużycia amunicji. Unieważnianie ma dwa
  zakresy:
  - świat: reset, mapa, sesja, wyjście z gry;
  - aktor: jego śmierć, zmiana sterowania, actorLeave.
  app/input.lua trzyma obserwację na aktora. Pola sesji przeniesione w v11 są wycofane (session/fields.lua:
  retire) i ich użycie kończy się błędem ze wskazaniem nowego miejsca. Anatomia z warstw części
  (EXPORT-ANATOMY.ps1 -Legend, qa/art/anatomy_layers.lua) albo z edytora
  regionów (ANATOMY-EDITOR.ps1, model qa/art/anatomy_editor.lua), jako dane
  (qa/art/anatomy_export.lua) i linia w content/art/anatomy/index.lua;
  BAKE-HIT-MASKS.ps1 (maski RLE związane ze źródłem), punkty anatomiczne
  qa/data/hit_landmarks.lua, --hit-review. CHECK-CREATURE.ps1 <id> wypisuje
  brakujące elementy. Sprawdzone w tests/cases/creature_pipeline.lua (demon
  z nowym atlasem z samych danych i wyników narzędzi).
  Rodzaje ataków: enemies/melee_kinds.lua (lunge, charge, leap) i
  ranged_kinds.lua (strike, pool, fan, bolt), wspólny kontakt
  enemies/attack_contact.lua, lot ciała enemies/flight.lua; enemies/actions.lua
  to wybór, zobowiązanie, wyzwolenie i stan uderzenia.
  Rodzaj ataku: Action.defineKind + Attacks.kinds[nazwa]; idealny unik przez
  powidok: test kontaktu także z Dodge.afterimage, potem Dodge.perfect.
  Obiekt świata: WorldObjects.register(rodzaj, ...) (render/world_objects.lua).
  Tekst: klucz w content/text.lua; język: Text.language + Text.use.
  Broń: Weapons.define({... hud, art?}; name i pola hud to klucze tekstów)
  + Weapons.give(g, id) lub domyślny
  loadout; mechanizm przeładowania: wpis w Reload.mechanisms z danymi czasu.
  Wyposażenie rycerza (Q, F, C; rycerz jest człowiekiem bez magii):
  Abilities.define({... action = Action.build(...)}) + slot w player.abilities
  (klawisz: app/bindings.lua abilities); nowy rodzaj dostawy: Cast.kinds[nazwa]
  (throw = ładunek prochowy; bolt = pocisk, dziś bez wyposażenia gracza).
  Abilities.give(g, id) dodaje slot bez zmiany postaci; define waliduje Action.
  AbilityCast wskazuje faktycznie użyty slot i jego animację dłoni.
  Nazwa, tag i komunikat braku to klucze tekstów (Text.register lub wpis
  w content/text.lua); HUD pokazuje każdy slot z klawiszem (ui/hud_slots.lua).
  Checkpoint zapisuje kolejność slotów (także checkpointu); SIGIL06/07
  migrują przez adapter.
  Rzut niesie własną definicję: lot, zapalnik, promień i blast; wspólne
  zachowanie nie odczytuje parametrów innego wyposażenia. Rejestracja nowego
  handlera i ograniczenia statusów/wyglądu: DEVELOPMENT, „Wyposażenie”.
  Mapa: content/maps/<id>.lua (z floor) + Maps:register; Game.new(kind, mapId).
  Tryb: Modes:register(id, { start, progress, policy, ready?, retry?, ... }).
  Ekran: Screens:register (klawisze) + Views:register (draw, controls).
  Strona: Factions:register(id, { hostile = { ... } }) w content/factions.lua
  (relację podają obie strony); stworzenie: faction w definicji albo pole
  faction na ciele (sojusznik, renegat, wieżyczka bez ruchu). Strategia
  celu: Target.strategies[nazwa] + move.targeting. Drugi rycerz: prefab
  'knight' z id w puli knights (tests/cases/factions.lua).
  Zdarzenie: event_catalog + emiter + słuchacz. Pole sesji: fields.lua
  (sim) lub Fields.view (prezentacja). Liczba: nazwana w treści.

13. ŚWIADOME GRANICE

  Tryby oryginalne trzymają rekordy w g.run / g.testField (dane trybu).
  Role trybów: pilgrimage = gra (menu i kaplica); field = poligon jako warsztat;
  floor (qa/floor.lua) = pusta sala testów, botów i złotego wzorca, istnieje tylko w QA.
  Krzywe animacji to dane w kodzie objęte zapadką tools/check/literals.txt
  (może maleć). Trafienia wszystkich dzisiejszych demonów: enemies/pose ->
  enemies/surface -> maska atlasu + adnotacja anatomii (appearance.regions).
  Obserwator (plan v11 E4): obrót billboardu, klatki tyłem i sylwetka liczą
  się względem jawnego obserwatora (argument Pose.sample/anchor/base,
  Surface.prepare, Geometry.volumes). Symulacja nigdy nie pyta widza kamery
  (zapadka VIEWER IN SIMULATION = 0):
  - strzał: oko strzelca z jego obserwacji albo z bieżącego kroku;
  - pocisk: oko żywego i obecnego właściciela, inaczej punkt wystrzału
    (Projectiles.observer);
  - stworzenie: jego cel (Pose.observerOf).
  Tylko prezentacja podaje Context.viewer(g), czyli widza kamery (druga
  kamera, kamera powtórki; domyślnie sterowany rycerz). Sprite nie ma głębi:
  maska leży w płaszczyźnie billboardu; sweep pocisku jest konserwatywny
  o pół przekątnej komórki maski.
  Strony i cele (V2): content/factions.lua mówi, kto jest wrogi komu;
  combat/bodies.lua odpowiada o każdym ciele (strona, wrogość, krzywda
  danym środkiem, pozycja z początku kroku, zasięg kontaktu);
  enemies/target.lua wybiera cel stworzenia (e.target, strategia
  move.targeting, domyślnie najbliższe wrogie żywe ciało). Ciosy, pazur,
  szarża, skok, piorun, kałuże, pociski, wybuch i efekty trwające ranią
  ciała, które ich strona może zranić; jedna droga obrażeń Outcomes.body
  (g:damageBody): rycerz prawem rycerza (osłona, garda, unik idealny),
  stworzenie prawem stworzeń. Rycerz inny niż sterowany dostaje KnightHit
  i KnightFell; jego upadek nie kończy walki. Sterowany rycerz i widz mają
  jedno źródło nazwy: core/roles.lua (zapadka knight-references = 1,
  utworzenie rycerza). Rycerze inni niż sterowany mają własne wejście,
  uzbrojenie i prezentację (plan v11 E3–E5). Input.new(actorId, device)
  produkuje actors[id], a publiczne komendy przechodzą przez ID aktora
  zgodne z dziennikiem v5. Nie dodano split-screenu do menu.
  session/context.lua rozdziela actor (HUD/ręce) i viewer (kamera/audio).
  Pola g.view deklarują scope: world, actor, view; ustawienia motion/fov
  są wspólne. watch tworzy osobisty widok, unwatch usuwa go wraz z kamerami
  zależnymi; unobserve kończy oddzielną kamerę. Kamera ma stałą tożsamość.
  view_state inicjalizuje prezentację bez zależności od player/feel.
  Interpolacja obejmuje wszystkich rycerzy i oddzielne historie kamer.
  Symulacja wykonuje się raz, efekty świata są pojedyncze; feedback
  osobisty trafia do właściciela zdarzenia. Śmierć dodatkowego rycerza
  zeruje widok także po flush kolejki; ekran śmierci sterowanego zachowuje
  0.33. Reset/zmiana sterowania usuwa stare widoki i historie.
  Queries stempluje pożyczone widoki neutralnym ownerToken, nigdy
  referencją zwrotną do sesji (LuaJIT: słabe klucze nie są ephemeronami).
  Konteksty i próbki zachowują osobne tabele wyników, ale rewizja
  komendy jest wspólna z sesją: komenda w tym samym czasie unieważnia
  pożyczone wyniki wszystkich kamer. Queries.copy zachowuje własną kopię.
  Krok symulacji 1/120 s: wynik nie zależy od FPS (qa/step_study.lua, ten sam
  skrót przy 30/60/144/240/zmiennym FPS). Zmiana samego kroku (nie FPS):
  1/240 przesuwa czasy kontaktów o ≤ 1 krok (≤ 0,0042 s), 1/60 do 0,025 s
  (lądowanie skoku); upadek trupa, bieg rycerza i odepchnięcie bez zmian;
  droga marszu demona ma błąd O(dt) ≈ 0,46 % przy 1/120 — zostawione.
  Id kształtu, strefa obrażeń i materiał są oddzielne; dowolna liczba części.
  Poza nie zależy od hitboxu ani zainicjalizowanego renderera. Dokładność,
  koszt i ograniczenia: ANATOMIA-I-FIZYKA-0.28.txt; pomiary qa/reviews/hit_*.
  Rycerz nie używa magii:
  nadnaturalne ataki należą do demonów (bez many i zaklęć gracza).
  Podłoga: Ground.height(map,x,z) obejmuje datum mapy i lokalny heightfield.
  Ruch, pociski, lot, lądowanie, renderer i dekoracje używają tego samego
  podparcia. Podparcie stóp jest punktowe; promień ruchu jest oddzielną
  bryłą poziomą, a nie geometrią trafienia. Most nad drugim pomieszczeniem
  to płyta (decks, plan v10 V3): podłoga zależy od wysokości ciała.
  Strzały i pociski rycerza blokują żywe i padające ciała. Zabite ciało
  osiada po body.corpse.settle i zakończeniu lotu (fallY/fallVY <= 0);
  Corpse.settled nie zależy od liczby klatek malowanego upadku. Po
  osiadaniu ciała przepuszczają strzały. Padające ciała nie dostają HP/nagród. Materiały mają jawne mnożniki i politykę
  penetracji (content/ballistic_surfaces); odbicia wymagają przyszłej specyfikacji.
  Ruch, droga ataku i podatna powierzchnia pozostają osobnymi reprezentacjami.
  Wybuch sprawdza ekspozycję kotwicy tułowia z fizycznym leapY, bez
  kosmetycznego bob/hover; nie jest promieniem anatomicznym.
  Pule zostają tablicami (LuaJIT), ale ich członkostwem zarządza świat
  ECS (Pools); separacja żywych idzie przez indeks przestrzenny (V3).

14. NARZĘDZIA

  FORMAT.ps1 (StyLua) przed testami; TEST.ps1 -Suite All|Architecture|
  Mechanics|Input|Render|Tools; tools/win/check.ps1; raporty w work/qa-v<wersja>/
  (qaOutput w game/src/app/release.lua). Flagi: --selftest, --input-test,
  --showcase, --benchmark, --hit-review
  (raporty trafień, GPU, opóźnienia i koszt salwy, nakładki hit-overlay-*),
  --record (+ F9), --suite=<id> (jeden zestaw), --core-measure
  (core-measure.txt: maski, salwa, pociski, pazur, Snapshot, Journal, długa
  sesja), --step-study (step-study.txt: FPS vs krok), --mask-formats
  (mask-formats.txt: porównanie formatów masek).
  BAKE-HIT-MASKS.ps1 generuje maski offline po zmianie źródłowych ilustracji:
  content/art/hit_masks.lua = tokeny RLE (content/art/mask_codec.lua,
  dekodowane raz przy wczytaniu, nigdy na promień) + źródło każdej klatki
  { obraz, x, y, szer., wys. }; test anatomy-data porównuje je z PNG.
  Journal v5 (z kompresją v4): integralność stanu początkowego i końcowego, kontakty części
  i działania poligonu; korytarze strzałów i delty geometrii ciał (wyżej).
  Złoty wzorzec obejmuje także skrót kontaktów.
  Literalny parser danych nie wykonuje kodu Lua. Weryfikacja formatu,
  referencji i fingerprintu źródeł poprzedza mutację sesji replay.
  Zewnętrzne fakty i wyniki checkpointu trafiają do journal.externalInputs
  przez storage/execution (nazwane skalary, kolejność konsumowania).
  Replay odtwarza je bez czytania bieżącego profilu i bez trwałych zapisów;
  zakres blokady jest zdejmowany także po błędzie. Stary dziennik bez
  zapisanego wejścia zgłasza brak, zamiast pobierać dzisiejszy plik.
  Obserwacja trafienia jest częścią komendy. Nagrywanie ma limit szacowanych
  64 MiB serializowanego tekstu albo 216000 komend (10 min aktualizacji 120/s
  i celowania 240/s; nie jest to limit RAM).
  Zatrzymuje się na granicy kompletnej komendy; eksport czeka na kontakty
  i końcowy Integrity. Szczegóły i koszt: DEVELOPMENT.txt.
  Punkty anatomiczne: tools/art/landmarks/crops.ps1 -Kind boss -Frame 9
  [-Points "x,y;..."] (wycinek z siatką pikseli źródła, po --hit-review).
  Celowa zmiana rozgrywki: skopiuj work/qa-v<wersja>/golden-current.lua do
  tests/golden/baseline.lua i opisz w ZMIANY (najpierw wyjaśnij różnice).

15. KONTRAKTY DOMKNIĘCIA v11 (27 października 2026)

  Profil publicznego poligonu (punkt 2): app/release wybiera dostępne tryby
  i sessionOptions. Opcje docierają przez Navigation do Game.new i init
  trybu, przed adopt/rozpoczęciem nagrywania. Field kopiuje features do
  testField; reset nie zmienia tej polityki. run/field/access jest wspólną
  regułą dla katalogu, akcji, interakcji i zakupu. Nie usuwa wykonawców
  starszych narzędzi. construction(g) eksportuje opcje do nagłówka Journal;
  odtworzenie nie zależy od bieżącej dostępności w menu. Starsze nagłówki
  bez options i bezpośrednie sesje QA zachowują dotychczasowe działanie.
  Menu używa dawnej sesji wyłącznie jako tła; polecenia aplikacji nie
  rozpoczynają ani nie kontynuują niedostępnego trybu. Biblioteka nadal
  pozwala konstruować go w testach. UI nie odczytuje mutable testField,
  lecz widok Queries.field. Grafiki i układ paska HUD są zachowane.

  Efekt: sourceId jest ID ciała, nie etykietą typu kontaktu. sourceSide
  opisuje stronę; nieznany sprawca to world/nil. Efekt zachowuje sprawcę
  po zmianie sterowania lub jego odejściu; cancelOnSourceDeath sprawdza
  to konkretne ciało. Ładunek używa swojego owner w raporcie obrażeń własnych.
  Etykieta self dla kontaktu ładunku z rycerzem zachowuje dotychczasową
  regułę braku perfect-dodge; to nie zastępnik ID sprawcy.
  Flinch: jedna sprężyna w układzie billboardu skierowanym do źródła
  kontaktu, rzutowana dla obserwatora. Źródło pozostaje odniesieniem,
  dopóki jest w świecie; potem używany jest zapisany punkt kontaktu.
  Zmiana źródła przelicza skalar i prędkość, a prezentacja nie miesza
  skalarów z różnych baz. To jawna reguła sprite'a, nie pełne ciało 3D.
  Geometry.volumes(..., into) zapisuje bryły w buforze odbiorcy. Wariant
  bez into pożycza scratch ważny tylko do kolejnego volumes/find tego ciała.
  Ballistics.prepare używa własnego into; Observation nadal utrwala kopię.
  Registry.register odrzuca duplikat; replace wymaga istniejącego ID,
  waliduje wpis i zachowuje kolejność. AI.style/targeting sprawdzane przy
  kompozycji sesji, przed walką, łącznie z istnieniem funkcji wykonawczej.
  SIGIL09 rodzaju session to zapis mapy i pul, nie dowolny quicksave
  całego starcia. Interakcje zapasów/sanktuarium należą do sterowanego
  rycerza. Kooperacja i kolizja rycerz–rycerz nie są gotowymi funkcjami.

## Konwencje kodu

_Dawniej: `game/docs/KONWENCJE.txt`_

SIGIL: BREACH / KONWENCJE KODU / 0.27

Obowiązują każdy nowy i każdy ruszany plik (zasada skauta: plik, który
zmieniasz, zostawiasz zgodny z konwencją).

1. SZABLON MODUŁU
   -- Cel w jednym-dwóch zdaniach (co ten moduł robi i czego NIE robi).
   -- Dane: co posiada / co czyta. Zdarzenia: co emituje / czego słucha.
   local Zaleznosc = require('src....')        -- require na górze
   local K = Tuning.<grupa>                     -- stałe z content/tuning
   local Modul = {}                             -- tabela modułu
   local function pomocnicza(...) ... end       -- prywatne
   function Modul.publiczna(...) ... end        -- API
   return Modul

2. NAZWY
   - Tabela modułu nazywa się jak jego rola: Rules, Weapons, World,
     Renderer, Reload, Spawner... (nie R/W/A/P w kilku znaczeniach).
   - Lokalne aliasy require tak samo jak tabela modułu, którą wskazują.
   - Funkcje: czasownik dla działań (spawn, react, emit), rzeczownik
     dla zapytań (body, stability, uptime).
   - Pola bytów: camelCase, jednostki SI (m, s, m/s); czasy kończą się
     na Time/Delay albo są licznikami opadającymi do 0.

3. ':' I '.'
   - ':' tylko dla obiektów z metatabelą (klasy z core/class, Registry,
     World ECS, Volley, Renderer).
   - '.' dla modułów i funkcji danych.

4. DANE I LICZBY
   - Liczba, którą się stroi, ma nazwę i dom (ARCHITEKTURA, punkt 9):
     content/tuning, content/view_reactions (odpowiedź widoku na zdarzenia),
     content/combat_defaults, dane trybów,
     definicje, ui/palette. Kod symulacji: liczby całkowite jednocyfrowe,
     0.5 i epsilony (1e-9) wolno; reszta tylko nazwana. tools/check liczy
     nienazwane liczby w każdym pliku symulacji (i src/app, src/feedback) i nie przepuści wzrostu
     ponad tools/check/literals.txt (nowy plik: zero). Gdy plik zejdzie
     niżej, obniż jego wpis (raport podpowiada: RATCHET ... can drop to).
   - Brak fallbacków danych w kodzie („atk.recover or 0.48”): wartości
     domyślne uzupełnia schemat definicji przy ładowaniu.
   - Definicje są tylko do odczytu w czasie gry.

5. BYTY I KOMPONENTY
   - Byt (demon, pocisk, zagrożenie, znajdźka, rycerz) powstaje z prefabu
     w fabryce; każde jego pole należy do zadeklarowanego komponentu.
   - Nowe pole = dopisanie do schematu komponentu (z opisem), nigdy
     „po drodze” w systemie (tryb ścisły w testach to wyłapuje).
   - Pole sesji (g.x) ma właściciela w src/session/fields.lua; tylko on
     je zapisuje (reset trybu może je cofnąć do wartości startowej).

6. SYSTEMY I ZDARZENIA
   - System: jedna odpowiedzialność, zapytanie o komponenty, kolejność
     w harmonogramie.
   - Skutek dla symulacji (nagroda, leczenie) = słuchacz fazy 'sim'.
     Skutek dla zmysłów (dźwięk, cząstki, kamera, napis, pomiar) =
     słuchacz fazy 'present'; nigdy nie zmienia symulacji.

7. REJESTRY
   - Coś, czego może być więcej (rodzaj ataku, styl ruchu, stan AI,
     mechanizm, znajdźka, stan, tryb, zdarzenie), żyje w rejestrze
     core/registry ze schematem wpisu. Kod pyta o rodzaj, nigdy o nazwę.
   - Rejestry wypełnia jawny plik indeksu (bez require przez sklejanie).
   - Tryb, ekran, oferta, rodzaj ataku: wpis w rejestrze, nie if po
     nazwie (app/screens, run/modes, run/economy E.kinds, Attacks.kinds).

7b. SYMULACJA I PREZENTACJA
   - Kod symulacji (combat, enemies, player, session, systems, run, world)
     nie importuje feedback/render/ui/audio/app. Dźwięk: Presentation.cue;
     efekt w kroku: Presentation.call / stage; mysz: Presentation.capture;
     reszta: zdarzenie 'present'. tools/check odrzuca nową krawędź.
   - Stan widoku (kamera, odrzut, efekty, napisy) tylko w g.view; symulacja
     go nie pisze (łuski, liczby obrażeń: słuchacze 'present').
   - Ciała: własny ruch nie przechodzi przez żywe ciało ani go nie pcha
     (combat/body_contact.lua); pęd z ciosów przechodzi prawem mas. Nowe ciało
     potrzebuje tylko masy i promienia w danych.
   - Wysokość: ciała liczą wysokość nad podłogą (skok, upadek, przykucnięcie);
     pociski, ładunki i promienie żyją w wysokości świata i dodają
     Ground.height (physics/ground.lua). Nigdy „y = 0” w nowym kodzie.
   - Polecenie trybu (gotowość, ponów, sklep, zakup, śmierć, nagroda) idzie
     przez Modes.act. Moduł jednego trybu nie wymienia
     innego trybu z nazwy (kaplica nie zna poligonu); różnice = handlery trybu.
   - Pytanie „czy to teraz działa” (wstrzymanie, zamrożenie, podatność) idzie
     przez session/capabilities.lua, nie przez czytanie pól sesji w systemie.
   - Brak obejść pod atrapy testowe („g.f and g:f()”, udawane pakiety,
     zapasowe „or liczba” dla danych, które zawsze istnieją): test buduje
     prawdziwą sesję albo moduł przyjmuje zależność jawnie.
   - Nowa aktywna sesja w aplikacji tylko przez Application:adopt.
   - Dokumenty: INSTRUKCJA = aktualna specyfikacja (tak gra działa teraz),
     ZMIANY.txt = historia (nowa wersja na górze), ODBIOR.txt = dowody
     i odbiór wydań, PLAN-* = plany i pomysły. Zmiana zasady
     gry zmienia INSTRUKCJĘ w tym samym kroku. Rycerz nie używa magii — nowe
     wyposażenie gracza nie nazywa się zaklęciem.
   - Klawisze gry tylko w app/bindings.lua.
   - Stan broni i umiejętności tylko w rekordach: player.arsenal[id],
     player.abilityState[id]. Nic nie zakłada liczby broni/slotów.
   - Rozróżnianie stworzeń po nazwie (kind == 'boss') jest zabronione:
     appearance, guardian, body.boss.

7a. DETERMINIZM I ZAPIS
   - Symulacja losuje tylko z g.rng.sim; prezentacja (cząstki) z
     g.rng.present: w QA ze stałego ziarna sesji, w grze z zegara
     (app/application adopt). love.math tylko poza sesją (dźwięk).
     Polecenie gracza przechodzi przez fasadę session/game, żeby
     dziennik (session/journal) je widział. Stan do zapisania = dane sesji
     (session/snapshot), nie domknięcia ani obiekty LÖVE.
   - Kolejność pairs() jest w każdym uruchomieniu inna: LuaJIT tej wersji
     losuje ziarno haszy napisów per proces. pairs() nie może więc
     decydować o kolejności rysowania, emisji, zużycia wspólnego RNG,
     tekstu raportu ani zapisu — tablica (ipairs) albo posortowane klucze
     (jak core/serialize, combat/rules/conditions). Sprawdzenie: dwa
     przebiegi --showcase tego samego kodu dają identyczne zrzuty.

8. TESTY
   - Pomocnicze z tests/support/fixtures.lua: checker(lines, fail, pass),
     within(tolerancja), arena(G), expedition(G). Nowy test nie pisze ich
     od nowa.
   - Każdy naprawiony błąd ma test regresji; każda zmiana symulacji
     musi przejść złoty wzorzec (tests/suites/golden.lua) albo świadomie
     zaktualizować tests/golden/baseline.lua z wpisem w ZMIANY.
   - Zmiana balansu: pomiar botem przed i po (qa/souls_bot.lua)
     i opis techniczny (kontrola, czas zabicia, obrażenia,
     zabójstwa przełamane, idealne uniki).
   - Nazwa pliku testu mówi, co sprawdza, nie z której wersji jest.

9. FORMAT
   - FORMAT.ps1 (StyLua) przed testami; komentarze po angielsku w kodzie,
     dokumentacja po polsku w docs/.

## Rozszerzanie treści

_Dawniej: `game/docs/ROZSZERZANIE.txt`_

JAK DOPISAĆ OGNISKO, POSTERUNEK LUB DRZWI

Wszystko jest w game/src/content/pilgrimage.lua, bez zmian w kodzie:

- Ognisko: wpis w fires { id, name, x, z } i nazwa w content/text.lua.
- Stwór: wpis w garrison { id, creature, x, z, yaw }. Opcjonalnie alert (jak blisko
  zauważa i słyszy), leash (jak daleko idzie za rycerzem), patrol { { x, z }, ... }.
- Drzwi: wpis w doors { id, x, z, side, back }. Komórka x, z jest murem, dopóki rycerz
  nie otworzy jej ze strony side. Od strony back drzwi tylko odpowiadają, że są zaryglowane.

Identyfikatory trafiają do zapisu, więc po wydaniu nie zmieniaj ich bez migracji.

JAK EDYTOWAĆ CIOS (plan v13)

Cios stoi w game/src/content/creatures/<stwór>.lua. Poligon pokazuje go bez restartu:
F2 wybierz stwora i przywołaj go, HITBOXES włącz, F3 następny cios, F4 cios teraz,
F5 wczytaj pliki stworów od nowa, F6 czas 1, 1/2, 1/4, stop, F7 krok.

windup, hold     zamach i zawieszenie po nim, shuffle = true losuje zawieszenie
turn, lockAt     obrót ciała (rad/s) i udział zamachu, po którym ciało już się nie obraca
trace            tor ostrza: { at, angle, reach, height } od kierunku ciała
mirror           każde użycie losuje stronę; ciało zmienia rękę i pochyla się na tę stronę
chase            w ciosie ciało goni tego, kto ucieka z ostrzem, nie tego, kto idzie pod prąd
parry            tyle sekund przed uderzeniem strzał przerywa cios; złoty krąg to pokazuje
steady, hyper    złamanie gardy dopiero po ciosie, wyższy próg w ciosie
string           następny cios lub branches = { { into, weight }, { weight } }; bez into stop
recover          okno na karę; ciało z shell przyjmuje pełne obrażenia dopiero tu

Ciało: shell, breakTime, execution, steadfast, personal. Reakcje: answers (drinking,
reloading, behind, hugging, sniped, dodged). Każdy nowy cios potrzebuje jednej właściwej
odpowiedzi: opisz ją w bieżącej instrukcji i naucz jej bota w qa/souls_bot.lua.
Bramka tests/cases/souls_gate.lua pilnuje, żeby ruch i unik z nawyku przegrywały.

PRZEPISY PLANU v12 (0.36)

Każdy przepis ma działającą próbę w game/tests/support/extension/ i pakiet
w game/tests/cases/v12_pack.lua. Nic z tego nie wymaga zmian w game/src.

Postać            Characters.define: ciało, ruch, zestaw, resources, reactions.
Broń              Weapons.define: ammo = { kind }, reload = { mechanism, speed },
                  trigger = { mode }, delivery, secondary, reactions.
Amunicja          Ammo:register: pełny interfejs z content/ammo/index.lua.
Przeładowanie     Reloads:register: stages, resume, labels. Interpreter jest jeden.
Spust             Triggers.define i Intent.modes:register.
Dostarczanie      Delivery.defineKind i Deliveries:register; Volley jest publiczna.
Typ obrażeń       Types.define: armored, color, impact, flight.
Stan              Conditions.register: modifiers, forbids. Statystyka: content/attributes.lua.
Reakcja           pole reactions: on, effect, target. Rodzaj: Reaction.defineKind
                  i Reactions.kinds:register. Stan: Reaction.bind.
Zdolność          Abilities.define: cost, channel, toggle; action.windup to czas rzucania.
Rodzaj akcji      Action.defineKind z hookami i ActionKinds:register (cast, execute...).
Stwór             A.register(Creature.define(...)).
Cios stwora       pola string, hold, track na akcji.
Zagrożenie        HazardKinds:register, Hazards.kinds:register, render/hazard_kinds.
Ruch malowany     Anim.motions:register.
Pole              Tiles.define: walkable, solid, speed. Komórka: g:setCell.
Mapa              Maps:register; tryb mówi, czego żąda: session.requires.
Bieg              Runs:register: stages = { { map, waves } }.
Glif              Glyphs:register i pole glyphs na broni.
Zapas             Supplies:register i Interactions.supplies.
Oferta            Shop.define.
Rzecz świata      Entities.define: health, hittable, collides, system, interact, draw.

SIGIL: BREACH / KONTRAKT ROZBUDOWY / 0.35

Cel: nowa zawartość nie wymaga przepisywania postaci. Dane dobierają
istniejące zachowania; nowy rodzaj zachowania otrzymuje mały moduł i test.
Nie obiecujemy, że dowolna nowa mechanika będzie samą zmianą liczb.

MALOWANA MAPA I ŻYWE RZECZY (1 listopada 2026)

Nowa sala kaplicy: wpis w content/maps/proving_halls.lua, powierzchnie
w content/art/chapel_hall.lua i malowidła namalowane na szablon z
tools/art/chapel_hall (main.lua pisze szablony, prepare.py gotowe obrazy).
Układ powierzchni jest zarazem reliefem bryły, więc wnęka namalowana jest
wnęką w geometrii. Mniejsze pomieszczenie: prostokąt i nazwa ściany na liście
rooms w tym samym pliku. Nowy rodzaj sali: jeden moduł w render/kit
i wpis w content/art/halls.lua.

Nowa rzecz do zniszczenia: rodzaj w content/breakables.lua, wygląd
w render/kit/props.lua, miejsce w decor.breakables mapy. Stan trzyma
combat/destruction.lua, ciosy biorą się z rozstrzygniętych strzałów
i wybuchów, a walka i rysowanie tylko czytają świat. Podpora (collapses)
wymaga cell, hole i rubble; kształt wyrwy jest wspólny dla fizyki i obrazu
(content/maps/breakables.lua). Ruina powstaje przy wczytaniu; World.opened
odświeża trasy bez przebudowy siatek.

KONTYNUACJE ATAKÓW I DYSTANS FAZY (28 października 2026)

tactics.moves może zawierać np.:
  {attack='antler-return', ideal=2, max=3.3, weight=9,
   after={attack='tempest-charge', within=1.0}}
To kandydat do wyboru, nie automatyczne wykonanie ani kolejka wymuszonych
ciosów. Staje się dostępny po ukończeniu poprzedniego strike, przez within
sekund czasu symulacji i tylko dla tego samego celu. Zasięg, własne cooldowny,
wzrok, budżet atakujących, pełny windup i recovery nadal obowiązują.
Inny wybrany atak zużywa okazję; zmiana fazy ją usuwa. Anulowany windup nie
daje kontynuacji. Stracony cel w trakcie pierwszego ciosu nie przekazuje
kontynuacji następnemu. Podczas własnej zapowiedzi drugi cios bierze nowy,
zamrożony cel; nie śledzi uniku ani przycisków gracza w trakcie wykonania.

Walidacja odrzuca nieistniejących/wyłączonych poprzedników, nieskończone
okna, powtórzenia i cykle. Autor kończy sekwencję ruchem bez następcy oraz
czytelną przerwą. Bieżące sekwencje mają dwa uderzenia; typ danych może
opisać dłuższy acykliczny ciąg bez gałęzi z nazwą konkretnego demona.
finishedAttack/finishedAt/finishedTarget należą do komponentu attacker,
snapshotu i zapisu ciała; pełny journal obejmuje rzeczywiste wykonanie.
finishedTarget rezerwuje cel już przy commitment poprzednika.

Opcjonalne phases[i].ideal nadpisuje preferowany dystans stylu ruchu keep
w metrach; nie zmienia zasięgu żadnego ciosu. speed/pace zachowują wcześniejszy
kontrakt. Krótsza przerwa wewnątrz sekwencji jest jawnie nową definicją
ataku, nie ukrytym mnożnikiem wszystkich zamachów w drugiej fazie.
Miejsca pracy: content/defs/encounter.lua, enemies/attack_selection.lua,
creatures/*.lua. Regresje: tests/cases/attack_followups.lua.

KOMNATA PRÓB (punkt 5 poligonu)

Układ bazyliki używa istniejących rooms/pillars/elevations/decor. Żebra
decor.arches mogą podać yaw (radiany), aby obracać tę samą geometrię
wzdłuż nawy lub nad wejściem. Spring/rise/halfSpan pozostają w metrach.
Łuk nie tworzy nowej niewidzialnej kolumny: autor opiera jego końce na
prawdziwych ścianach/pillars. tests/cases/chambers pilnuje obecnej mapy.

Mapa może zawierać proving = { exhibits=false, chambers={}, trials={}, pads={} }.
Przykład (pozycje trzeba dobrać do rzeczywistej podłogi i promienia ciała):
  chambers = {{ id='court', entry={x=7,z=20,yaw=math.pi},
    slots={{x=7,z=12},{x=4,z=12},{x=8,z=15}} }}
  trials = {{id='ash',chamber='court',creature='boss'}}
  pads = {{x=8.2,z=17.5,trial='ash',spawn='boss'}}
Każdy medal ma dokładnie jedną akcję: trial, weapon albo refill=true.
spawn w medalu próby wskazuje tę samą definicję co creature, aby podpis
i istniejąca grafika znaku odpowiadały przywołaniu. Id: litery/cyfry/_ .
Polecenie Game:act('catalog','field_chamber_ash') lub E na medalu rozpoczyna
jedną próbę po pełnym resecie. Field.chamber(g,id,count) dopuszcza od 1 do
liczby slots; F2 zachowuje przyciski 1/3. Pierwsza próba danego creature
jest domyślna dla F2, kolejne można wybrać własnymi medalami/poleceniami.
Nowy demon bez przypisanej komnaty nadal korzysta ze swobodnego przywołania
na wyczyszczonym poligonie. Zmiana geometrii nie zmienia rendererów/AI.
Konstrukcja sprawdza referencje, skończone współrzędne, wejście i miejsca
przywołania z realnym promieniem ciał, odstęp od wejścia i innych slotów.
Test autora powinien dodatkowo wykazać osiągalność wejść, widoczność znaków
i dostateczną przestrzeń na konkretne ataki. Schemat nie ocenia grywalności.
RANGE/PHYSICS nadal korzystają z content/field.lua; inna mapa musi zapewnić
im miejsce lub osobno rozwinąć definicję stanowisk, nie wpisywać wyjątki
nazw map w rdzeniu. tests/cases/chambers sprawdza obie istniejące stacje.
Snapshot/journal odtwarza całą próbę, także oczekujące portale. Nie mylić
tego z pełnym checkpointem SIGIL09. Poligon pozostaje trybem bez zapisu
wyprawy; przyszły zapis trybu wymaga jawnej sekcji właściciela i migracji.

TAKTYKA I FAZY (punkt 4 poligonu)

W Creature.define/boss opcjonalnie:
  tactics = { repeatPenalty = 0.2, moves = {
    { attack = 'claw', ideal = 1.5, max = 3, weight = 1.5 },
    { attack = 'bolt', ideal = 7, min = 3, fromTier = 2 },
  }}
Id muszą istnieć w attacks. range/minRange/rest ataku pozostają twardymi
granicami; min/max wyboru tylko je zawężają. Ocena to
weight/(1+abs(distance-ideal)), pomnożona przez repeatPenalty^powtórzenia
dla ostatniego rozpoczętego ataku. Remis: kolejność definicji. Brak tactics
zachowuje dawne maxRange/every i ostatni atak jako fallback.

Przykład etapów:
  phases = {
    { id = 'vigil' },
    { id = 'wounded', at = 0.5, recovery = 1.2, pace = 1.1 },
    { id = 'last_stand', at = 0, refill = 0.4, recovery = 1.4,
      pace = 1.2, speed = 1.1, tactics = { moves = ... } },
  }
Pierwszy etap bierze HP ze spawnu. at to udział bieżącego maxHp, refill
to udział początkowego HP po TIER (nie narastające mnożenie poprzednich
zapasów). Bez refill zdrowie zostaje; z refill nadmiar tego trafienia
przepada, ale następny kontakt od razu zadaje obrażenia. recovery jest
oknem odpowiedzi gracza, nie odpornością. pace skaluje cooldown/rest
i odstęp przydziału ataku; nie windup/recover ani obrażenia.

Przejście nie czyści efektów, warunków, gardy ani odnowień; anuluje
nierozliczony znak i bieżący atak ciałem. Już wystrzelone pociski oraz
aktywne pola trwają. Jeden EnemyKilled i nagrody dopiero po ostatnim
etapie. Nowy typ dostawy nadal dodaje lokalnego wykonawcę actions.kinds,
bez zmiany modułu faz. Test referencyjny: tests/cases/encounters.lua.
Druga faza może podać transitionPose='phase.last_stand'. W poses atlasu
dodaj tę nazwę z clock='action', istniejącymi frames i bounds w 0..1.
Zegar biegnie od phaseEnteredAt przez recovery; nie ma nowego stanu AI.
windup.<id ataku> / strike.<id ataku> mają ten sam mechanizm z zegarem
samego ataku. Kompozycja odrzuca nieistniejącą pozę lub nieznany id ataku.

Sekwencja zagrożeń na ziemi jest osobnym typem dostawy Action.pattern:
  Action.pattern({id='cross', range=10, windup=1.2, duration=1,
    recover=1, cooldown=1.6, rest=4, origin='target',
    hazard='lightning', radius=1, life=0.22, pulse=0.45,
    volume={bottom=0,top=2.9,sample='body',includeRadius=true},
    marks={{forward=0,lateral=0,delay=0.75},
           {forward=0,lateral=2.8,delay=1.15}},
    packet=packet(26,80,'lightning')})
packet to src.content.defs.packet.new. origin: target albo caster.
Offsety są w metrach w układzie kierunku celowania z chwili wykonania;
cel jest zamrożony na początku przygotowania. Delay biegnie od release,
każdy punkt jest ostrzegany od release, niezależnie od pozostałych.
1..12 punktów, skończone offsety i dodatnie radius/life/pulse/delay są
walidowane. Wpisanie pattern do attacks nie udostępnia go samo w każdej
fazie: dodaj jego id w tactics.moves właściwego etapu. Można zmieniać
układ, rytm, promienie i obrażenia bez zmiany AI lub renderera.
hazard='pool' używa domyślnie volume 0..0,42 m/sample='feet'; lightning
powinien podać własne volume jak powyżej. Ogień można przeskoczyć, ślizg
zostawia stopy w jego zasięgu. Piorun jest jednorazowym kontaktem.
Najpierw sprawdź miejsce na sekwencję w docelowej arenie: ściany pomijają
zasłonięte punkty. Przy krawędzi mapy układ celowo może być niepełny.

Zmianę grafiki najpierw przedstaw użytkownikowi; dobór nowego ataku
nie upoważnia do zamiany zatwierdzonego atlasu lub HUD-u.

BROŃ = DEFINICJA + STAN + KOMPOZYCJA ZACHOWAŃ

Definicja: content/defs/weapon.lua, rejestr: content/weapons.lua.
Stan (mag/reserve/open/loaded/spent/readyAt): actor.arsenal[id].
Kolejność wyposażenia: actor.loadout. Dodawanie: Weapons.give(game, id, actor).
Pominięty actor oznacza sterowanego. Prezentacja jawnie przekazuje aktora
kontekstu; Weapons.state/inHand/idAt przyjmują go po argumencie slot.
Postać nie zna nazw typów ani numeru ostatniego slotu.

Niezależne części definicji:
  delivery  sposób dotarcia: hitscan lub projectile (speed/radius/color)
  attack    obrażenia, typ, falloff, penetracja, poise i impuls
  fire      liczba pocisków/amunicji, kadencja przez cycle, sygnały strzału
  mechanism przeładowanie (combat/reload mechanizmy)
  weight    parametry odczuwalnej masy i odrzutu
  art/hud   wybór atlasu i nazwy (name i pola hud to klucze tekstów,
            content/text.lua); GUI czyta wyposażenie

Variant można opisać jako extends = Weapons.get('exorcist'), z własnym id,
name i zmianami pól. Rekordy łączą się, tablice listowe zastępują rodzica.
Pusta lista {} także usuwa odziedziczoną listę. Pusty rekord {} dziedziczy
pola rekordu; kopiowanie danych instancji używa Schema.copy, nie inherit.
Rodzic i jego pola nie są modyfikowane. Pełny przykład z testu:
  tests/cases/weapon_extension.lua
To broń testowa, której nie rejestrujemy w zwykłej rozgrywce.
Jeżeli wariant nie podaje art, zachowuje atlas rodzica. Zmiana delivery.kind
zastępuje rekord transportu; strojenie tego samego kind dziedziczy parametry.

Jeśli zmienia się tylko odporność/typ obrażeń, attack.damageType = 'fire'
wystarcza do wspólnego rozliczenia odporności. Nie implikuje płomienia ani
podpalania: to osobne zachowania. Pocisk transportuje swoją definicję i typ,
prędkość/radius nie zależą od rodzaju obrażeń. Inny wygląd wymaga grafiki.

Nowy algorytm dostawy:
  1. content/defs/delivery.defineKind(id, pola schematu).
  2. combat/weapon_delivery:register(id, { prepare?, fire }).
     fire(game, shot, prepared) dostaje payload, definicję, slot, serial,
     origin, count i wspólne rozliczenie trafień. Rejestracja przy starcie,
     zanim powstaną sesje; nie wykonywać jej co klatkę.
  3. Test lotu/kontaktu/śmierci/zasobów oraz zapis i replay.
Nie tworzyć if weapon.id == 'nowa_bron' w Game, AI, HUD lub damage.

Obecny projectile: skończona prędkość, odległość jako długość drogi,
ciągła kolizja, jeden końcowy kontakt. Nie obsługuje przebijania wielu ciał;
opcja attack.pierce jest odrzucana zamiast po cichu ignorowana. Wariant
rodzica z pierce potrzebuje jawnej pełnej definicji attack bez tego pola
(np. zbuduj własną definicję zamiast odziedziczyć Judge). Nie usuwa się
opcjonalnych pól rodzica przez nil w Lua: nil nie jest wpisem tabeli.

Po zmianie materiałów obowiązują te same reguły dla broni, pocisków i ciał.
Status i obrażenia okresowe mają wspólny rejestr efektów opisany poniżej.
Ciągły strumień, odbicia i łańcuchy wymagają własnego wykonawcy dostawy
i testu. Nie należy udawać ich samym kolorem ani naliczać obrażeń w love.draw.

UMIEJĘTNOŚĆ / WYPOSAŻENIE

GEOMETRIA ATAKU (punkt 3 poligonu)
Pocisk: height to wylot nad podłożem strzelca (plus jego leapY), aimHeight
to stała wysokość celu nad jego podłożem; radius to rzeczywista sfera.
speed jest prędkością poziomą. Celowanie nie śledzi potem ruchu ofiary.
combat/projectile_shape jest jedynym źródłem promienia dla kolizji i
renderowania. Malowana aura jest dekoracją, nie dodatkową strefą obrażeń.

Kałuża/linia/piorun: volume. Lądowanie: landVolume. Przykład innego pasma
trafienia na istniejącym wykonawcy (bez przerabiania postaci):
  volume = { bottom = 1.5, top = 2, sample = 'body', includeRadius = true }
Stojący rycerz wchodzi w to pasmo, pełny ślizg może je ominąć. Domyślne
profile opisuje content/defs/area.lua; pełne dane powstają przez Action.build.
bottom jest włączone, top wyłączone dla próbki stóp; kolumna sprawdza
przecięcie przedziałów ciała. includeRadius powiększa poziomy zasięg o
promień ciała, niezależnie od wybranej próbki pionowej.
Strop nad źródłem ogranicza top. Osłonę sprawdza promień 3D w paśmie
kontaktu; obszar nie przechodzi przez ściany ani pod własne podłoże.

Nie kopiować kolejnego hit-testu do AI/renderera. Area.test zwraca zarówno
wynik, jak i opis rozstrzygniętego kontaktu. Area.sample interpoluje
wysokość świata na czas pulsu. Komponent hazard.volume przenosi geometrię
do snapshotu i replay. Test rozszerzenia i granic: tests/cases/attack_volumes.lua.
Ładunek prochowy nadal ma sferyczny zasięg 3D i promień osłony do kotwicy
ciała. To jawna próbka ekspozycji, nie anatomiczny test każdego fragmentu
powierzchni; promień wybuchu nie jest nieskończonym walcem.

content/defs/action opisuje dostawę i parametry ataku. Demon wykorzystuje
enemies/actions.kinds (wykonawcy: enemies/melee_kinds.lua i ranged_kinds.lua),
a gracz combat/abilities.kinds. Jeden rodzaj może
mieć dwóch wykonawców ze względu na kierunek/cele. Dane i zachowanie są
osobne, żeby content nie importował symulacji ani renderera.

Abilities.define(def) waliduje dane; Abilities.give(game, id) wyposaża.
Nowy bolt lub throw to definicja na istniejącym zachowaniu. Throw ma własne
fuse, radius, blast, selfBlast i parametry ruchu. Postać pozostaje bez zmian.
SIGIL08 przechowuje sloty i użycia, z migracją SIGIL06/07.
Test: tests/cases/ability_extension.lua (także własny rzut i zapis w locie).

Nowa logika: Action.defineKind + odpowiedni handler, jeden moduł importowany
przy starcie. Caster sprawdza istnienie handlera przed zużyciem zasobów.
Tryb gry nadal wyposaża człowieka wyłącznie w powder; próbne spelle nie
zmieniają uzgodnienia "człowiek bez magii".
Klawisze Q/F/C wynikają z app/bindings. name, tag i empty to klucze tekstów.
HUD pokazuje każdy slot z klawiszem (ui/hud_slots.lua, plan v10 V6): jeden
przedmiot w układzie 0.30, kilka po wierszu; odbiór gracza nowego przedmiotu
w produkcji pozostaje osobny.
AbilityCast wskazuje użyty przedmiot, więc animacja dłoni nie wybiera
bezwarunkowo pierwszego slotu. Art dłoni wybiera pole hands; inny model
rejestruje własny atlas i gest w content/equipment_art, bez wyjątku
w render/weapon. Produkcja nadal wyposaża tylko Q.

ANIMACJA I JEJ GEOMETRIA

content/ability_art jest wspólnym katalogiem sekwencji: ścieżka, klatki,
kotwice, sampler, anatomia i pigment. Loader, bake i poświadczenie masek
przechodzą po tym samym katalogu. Dopisz dane i sampler zachowania;
nie rozbudowuj list leap/evade w kilku niezależnych plikach.
enemies/art_contract sprawdza referencje stworzeń przy kontroli zawartości.
content/effect_art opisuje czas i klatki FX na istniejącym atlasie.
Test art-extension dodaje trzecią sekwencję i FX, po czym je usuwa.
Maski/poza nadal są danymi CPU. Dokładność strzału, kolizji ruchu i ataku
pozostaje odrębna; identyfikator kształtu nie jest strefą obrażeń.

WALIDACJA PRZED URUCHOMIENIEM

Wspólny core/id obowiązuje rejestry, definicje i format zapisu. Używaj
identyfikatorów alfanumerycznych z podkreśleniem (np. iron_rifle).
Action.build odrzuca m.in. pulse <= 0, niespójne okna aktywności,
niepoprawne czasy lotu/szarży i krzywe obrażeń. Nieudana rejestracja nie
zostawia połowy definicji w katalogu. Testy: content-contracts.

PROCES I DOWÓD GOTOWOŚCI

1. Zdefiniuj element i istniejące zachowania, które składa.
2. Sprawdź błędne definicje i brak referencji, zanim uruchomisz grę.
3. Przejdź: użycie -> kontakt -> obraz/HUD -> zasoby -> zapis -> replay.
4. Dla ilustracji: PNG -> kotwice -> anatomia -> maski -> film w scenie.
5. Sprawdź działanie razem z obecną zawartością i koszt w pełnej klatce.

Nie rozbudowujemy drzew klas ani nie tworzymy nowego silnika. Obecne
definicje, rejestry i wykonawcy mają jasnych właścicieli. Test rozszerzenia
ma uruchamiać prawdziwą drogę, nie tylko sprawdzać obecność wpisu w rejestrze.
Zakończenie QA technicznego nie zamyka B2 (feeling/balans przez człowieka).

PRAKTYCZNE ROZSZERZENIA FUNDAMENTU 0.32

1. Ilustracja trzeciej broni o innym układzie
   WeaponArt.register(id, entry) w content/weapon_art. entry.frames posiada
   nazwane id, rect w pikselach, grip i action. entry.phases.fire
   i reload to kolejne {finish = sekundy, frame = nazwa}. ready,
   reloadComplete oraz open.primed/empty wskazują nazwy, nie ostatni indeks.
   screenScale, cellWidth, reloadMotion i style opisują prezentację.
   Loader nie zakłada 16 klatek, 1600x1600 ani dwóch nazw broni.
   Sprawdzony przykład: tests/cases/hand_art_extension.lua, pięć klatek,
   ready jako piąta i complete jako pierwsza, inna kotwica błysku, prawdziwy
   strzał i przerwane/wznowione przeładowanie. Ogólny renderer bez zmian.

   muzzle jest pomierzonym wylotem i jest wymagany dla ready oraz klatek
   fire. Poza tym jest opcjonalny: poza przeładowania bez widocznego wylotu
   nie dostaje wymyślonej kotwicy ani błysku. grip jest fizycznym punktem
   trzymania/pivotem, a opcjonalne entry.placement = {x, y} przesuwa go
   względem ekranowej pozycji w źródłowych pikselach. Pozwala to zachować
   pozycję wylotu oraz szerokość broni bez fałszowania punktu obrotu.
   Opcjonalne frame.eject wskazuje otwarte komory dla wyrzutu łusek.
   Efekt zapisuje weapon ID i wiąże punkt przy pierwszym widocznym rysunku;
   potem tor porusza się niezależnie od ręki i zachowuje proporcje po resize.
   Zmiana broni przed pierwszym pokazaniem pomija niewidoczny efekt zamiast
   wyrzucać starą łuskę z nowej broni. Nie zmienia to amunicji ani obrażeń.

   Odkryte komory: frame.rounds = {'zero', 'one', ...} wskazuje gęstą
   listę nazw od zera do pojemności włącznie. Lua indeks mag + 1 wybiera
   dokładnie stan Weapons.state(g).mag. Elementy muszą być klatkami
   końcowymi bez własnego rounds; nie wolno tworzyć łańcuchów ani pętli.
   validateWeapon sprawdza pokrycie capacity + 1 przy kompozycji grafiki.
   Sampler nie przyznaje amunicji, nie ma drugiego zegara ani clampowania
   błędnej liczby nabojów. Przed transakcją widać pozostałe żywe naboje;
   po niej nową zawartość, także przy jednym naboju w zapasie. Zamknięte
   lub zasłonięte komory mogą współdzielić ilustrację.
   Opcjonalne phases.interruptedClose zawiera nazwane klatki ze znormalizowanym
   finish (ostatnie dokładnie 1). Prezentacja używa started/duration zdarzenia
   przerwanego zamknięcia i g.elapsed, a nie własnego zegara. Swap, reset i strzał
   usuwają zapis prezentacji; ammo/readyAt nadal należą wyłącznie do mechaniki.
   Test weapon-rounds obejmuje rezerwę jednego naboju, cancel/swap/resume,
   przerwanie spustem, niepoprawne referencje oraz faktyczny wybór GPU quad.
   Sprawdza także każdą produkcyjną otwartą pozę z każdą legalną liczbą
   nabojów oraz kotwicę, niezależność toru i zmianę rozmiaru efektu łuski.
   weapon-art-review tworzy żywe filmstripy weapon-*-16-poses (historyczna
   nazwa, liczba klatek jest dynamiczna), weapon-*-partial-one,
   weapon-*-cancel-resume, weapon-revolver-trigger-interrupt oraz pełne
   weapon-*-scene-v32.png. Obejrzyj je: zaliczenie testu nie ocenia anatomii
   ręki, spójności pigmentu ani przyjemności animacji.

2. Nowe wyposażenie z własnymi rękami
   EquipmentArt.registerAtlas(id, metadata) i register(gestureId, gesture)
   w content/equipment_art. Gest wskazuje atlas, duration i nazwane phases.
   AbilityCast niesie tożsamość użytego wyposażenia. Przykład w tym samym
   teście obejmuje drugi slot z odrębnym trzyklatkowym arkuszem.

3. Nowy efekt kontaktu
   Opcjonalne attack.effects / packet.effects to lista walidowanych danych.
   condition dodaje nazwany stan; periodic: id, duration, interval, packet,
   stacking = refresh albo replace, opcjonalnie cancelOnSourceDeath.
   Periodic packet nie może zawierać kolejnych effects ani impulsu/pchnięcia.
   Refresh zachowuje fazę pulsu i istniejący payload; replace zaczyna od nowa.
   Efekt uruchamia rzeczywiste uszkodzenie zdrowia, raz na trafiony cel
   agregowanej salwy. Sam kontakt z rogiem/pancerzem bez rany go nie tworzy.
   Nowy algorytm: Effect.defineKind + Effects.kinds:register({apply, tick?}).
   Stan instancji jest na celu, nie we współdzielonej definicji broni.
   Puls wraca do wspólnego rozliczenia ochrony, śmierci i nagrody.
   Testy: contact-effects, foundation-contracts. Produkcyjne bronie nie
   otrzymały nowych efektów ani zmienionych obrażeń w tym refaktorze.

4. Nowy rodzaj akcji demona
   Action.defineKind + wykonawca w Attacks.kinds (enemies/melee_kinds.lua
   lub ranged_kinds.lua, wspólny kontakt enemies/attack_contact.lua); osobno
   ActionPhase.register(kind, durationSampler) dla prezentacji czasu oraz
   AttackDebug.register(kind, painter) dla diagnostyki prawdziwego kontaktu.
   Animacja i debug niczego nie trafiają ani nie uruchamiają drugiego zegara.
   Test: action-presentation. Nowa ilustracja nadal wymaga anatomii/masek.

5. Tryb / stanowisko
   Modes:register opisuje session = {world, map, prepare?}, init, start,
   progress oraz polityki i polecenia. Game.new(id, map) i Journal.session
   używają tego samego konstruktora. modeData jest miejscem prywatnego stanu.
   Prezentacja pyta run/queries: run, field, world, tools, objective;
   widoki buduje tryb z własnego rekordu (run/mode_views.lua), są pożyczone
   i tylko do odczytu. Żaden ekran nie czyta g.run/g.testField (zapadka
   mode-records = 0).
   app/navigation przechowuje powroty i je czyści przy resecie.
   Poligon: run/field/stations (rejestr), catalog, actions, targets, reset.
   Testy: mode-lifecycle i extension; nowy tryb oraz stanowisko działają
   wraz z snapshotem i replay bez zmian Journal/Game/ogólnego renderera.

   Dostępność w wydaniu jest oddzielna od rejestracji. app/release opisuje
   playableModes i sessionOptions. Navigation przekazuje opcje do
   Game.new(id, map, options); init(g, options) waliduje je i kopiuje
   trwałe wartości do rekordu trybu. construction(g) zwraca ich kopię do
   nagłówka Journal; odtworzenie nie czyta aktualnego profilu aplikacji.
   Brak tego haka/opcji zachowuje dotychczasowy konstruktor.
   Dla narzędzia poligonu: zadeklaruj nazwę w content/field.toolFeatures,
   przypisz feature do stanowiska/akcji i sprawdź dostępność także u jego
   właściciela. Publiczny profil wyłącza trade i waves; zwykłe Game.new('field')
   zachowuje komplet narzędzi dla QA. UI czyta Queries.field, a catalog.stationsFor
   filtruje ten sam rejestr, który obsługuje wykonanie. Test: field-access
   i rzeczywiste callbacki w input-test. Nie używaj samego ukrycia przycisku.

6. Przestrzeń testowa
   content/maps: geometria, elevations, decor, lamps i anchors. Wysokości
   elevations są nieujemne względem floor i zajmują rozłączne komórki.
   Heightfield ma jedną podporę na x/z; piętro nad inną podłogą to płyta
   (decks, punkt 10).
   Scenografia ma kotwice mapy, nie współrzędne zaszyte w rendererze.
   Testy world-support i terrain-motion obejmują schody, podest, kolumnę,
   zejście z krawędzi, pociski, ciała, lądowanie i zgodność widocznej pozy.
   To geometria testów; produkcja nadal ma jeden dotychczasowy poligon.

7. Więcej tekstu / pozycji
   Text.register(key, template), Text.get(key, {nazwanyParametr = wartość});
   języki: punkt 15.
   Nie generuj obrazka dla każdej liczby: gotowe bitmapowe glify składają
   dowolną wartość; cache pomiarów jest ograniczony. UI.pages i text_fit
   obsługują większe katalogi, opisy i długie polskie nazwy. Zachowane są
   obecne cztery karty/sześć ofert; większa zawartość dostaje strony.
   Test ui-content-extension: 9 kart, 13 ofert, 7 broni w pięciu rozmiarach.
   Oprócz przecięć sprawdzaj oddech między wierszami oraz wnętrze ornamentu.

8. Nowy zasób
   Resources.new(label) tworzy właściciela. :image(path, options) współdzieli
   zgodny wariant próbkowania; :own(handle) posiada natywny obiekt;
   :release() jest jawne i idempotentne, :manifest() ujawnia zależności.
   Inny filtr/wrap to inny wariant, nie mutacja tekstury drugiego odbiorcy.
   LoadPlan etapuje pracę, pokazuje błąd, pozwala anulować i ponowić.
   Nie kopiuj uchwytów GPU do świata/snapshotu. Maski kontaktu są osobne CPU.

PRAKTYCZNE ROZSZERZENIA FUNDAMENTU 0.33 (plan v10)

Każdy punkt sprowadza się do definicji, danych i małego modułu z testem.
Próby w testach dodają treść na czas próby i ją usuwają.

9. Nowy aktor dowolnej strony (V2)
   Strona: Factions:register(id, { hostile = { ... } }) w content/factions.lua
   (relację podają obie strony). Stworzenie: faction w definicji albo na
   ciele (sojusznik, przywołaniec, renegat, wieżyczka bez ruchu). Cel
   wybiera enemies/target.lua (strategie Target.strategies, move.targeting).
   Każde obrażenie idzie jedną drogą (g:damageBody, Outcomes.body); drugi
   rycerz to prefab 'knight' w puli knights. Test: factions.

10. Setki ciał i większa mapa (V1, V3)
   Pule przez Pools (session/world.lua), id w O(1), zwłoki osiadłe w remains.
   Ciała w indeksie przestrzennym (physics/spatial.lua). Mapa jest
   prostokątem width x depth; nawigacja w oknie wokół celu, regiony
   i klasy prześwitu (world/navigation.lua). Płyty nad podłogą (decks):
   most nad drugim pomieszczeniem, Ground.height(w, x, z, y). Światła bez
   limitu (14 najbliższych w shaderze). Testy: entity-lifecycle, space-scale,
   floor-layers; mapy QA qa_crowd i qa_bridge.

11. Nowy rodzaj zapisywanego stanu (V4)
   Właściciel deklaruje sekcję: Save.declare({ name, file, version, schema,
   pack, unpack, restore, migrations, default }) (storage/save.lua). Plik
   SIGIL09 to drzewo sekcji; błąd odrzuca cały plik przed przywróceniem.
   Test: save-format.

12. Długie nagranie dużej walki (V5)
   Journal v4: strzał zapisuje tylko ciała swojego korytarza, obraz bez
   strzału sam nagłówek, ciało niezmienione jako odwołanie. Test:
   fight-recording; koszt i limity: DEVELOPMENT.

13. Nowy obiekt świata (V6)
   WorldObjects.register(rodzaj, { { pass, order, draw }..., init?,
   overlay?, release? }) w render/world_objects.lua. Renderer i przejścia
   (render/passes/) nie znają nazw obiektów. Test: open-presentation.

14. Slot HUD (V6)
   ui/hud_slots.lua: arsenał N broni, wyposażenie każdego slotu z klawiszem
   z app/bindings (Q, F, C). Jeden przedmiot zachowuje układ 0.30, kilka
   dostaje po wierszu. Test: open-presentation (4 bronie, 3 sloty, audyt
   w pięciu rozdzielczościach).

15. Język (V6)
   Każdy napis dla gracza jest kluczem content/text.lua (zapadka
   player-text = 0); definicje treści niosą klucze. Text.language(nazwa,
   szablony, malunki) + Text.use: zmiana języka bez zmian kodu; napis
   malowany bez malunku pisze się glifami. Test: open-presentation.

16. Nowy demon z nowym atlasem (V7)
   Arkusz content/art/sheets/<id>.lua z EXPORT-SHEET.ps1, anatomia
   z warstw części albo edytora regionów (EXPORT-ANATOMY.ps1,
   ANATOMY-EDITOR.ps1), BAKE-HIT-MASKS.ps1, definicja, CHECK-CREATURE.ps1.
   Kroki i czasy: DEVELOPMENT, „Nowy demon z nowym atlasem”. Test:
   creature-pipeline.

Wszystkie przykłady dodają treść testową na czas próby i usuwają ją po niej.
Dowód rozszerzalności nie jest deklaracją obsługi dowolnego przyszłego
algorytmu samymi danymi. Nowe zachowanie otrzymuje mały lokalny wykonawca;
wspólne kontrakty pozostałych systemów mają pozostać stabilne.

KONTRAKTY v11 / PRZEPISY ROZBUDOWY 0.34

17. Inny układ atlasu i nowa animacja
    Arkusz content/art/sheets/<id>.lua deklaruje poses: nazwę, clock,
    frames oraz bounds/rate/step. Przykład: strike = { clock='action',
    frames={7,9,12}, bounds={0.25,0.6} }. Granice należą do następnego
    przedziału. Geometria i renderer pytają tę samą nazwaną pozę; zmiana
    kolejności atlasu nie wymaga edycji rendererów ani logiki zwłok.
    Testy: named-poses, anatomy-data oraz v033-reference.

18. Nowy tryb i jego stan
    Modes:register(id, descriptor) nazywa record (domyślnie modeData),
    session oraz haki start/progress/reset/snapshot/load/save. Obiekty
    świata i Encounter pozostają wspólne, wynik trybu jest jego rekordem.
    UI pyta Queries, nie rozpoznaje id nowego trybu przez if/elseif.
    Testowy tryb trial_altars: tests/cases/mode_state.lua; obejmuje
    własną sekcję Save.declare i komendy poprzez Game:act.
    Pożyczony widok ważny do następnego kroku/komendy: Queries.valid.
    Chcesz zatrzymać dane: Queries.copy. Nie zatrzymuj referencji sesji
    w globalnym stemplu widoku; ownerToken nie jest referencją właściciela.
    Próba: mode-state i tryb ołtarzy w testach, poza menu.

19. Drugi rycerz i urządzenie
    Utwórz rekord prefabu knight i zgłoś przez game:actorJoin(record).
    Publiczne komendy przyjmują ID: game:shoot(command, id),
    game:reloadGun(id), game:switchWeapon(slot, id), game:cast(slot, id),
    game:look(yawDelta, pitchDelta, id). Wywołujący nie przekazuje całej
    tabeli aktora przez granicę dziennika. Rekord dołączenia powstaje
    przez Pools.memberRecord, tak jak rekord członka sekcji pools. Broń,
    przeładowanie i intencje należą do aktora. Statystyki mają osobne
    rekordy według ID w księdze Stats, zamiast jednego wyniku sesji.
    Input.new(id, device) przypisuje wejście; device.held(name) i
    device.mouseDown() dostarczają próbkę. Wynik: input.actors[id].
    Przy prezentacji: input:present(game, shown, actor). Potem komenda
    używa obserwacji tego samego strzelca. Testy: actors, observer,
    view-context; journal v5 odtwarza komendy i właścicieli.

20. Drugi widok lub kamera
    Context.watch(game, id); local actor = Pools.get(game, id);
    local shown = Context.of(game, actor).
    renderer:draw(shown, width, height) i UI.draw(shown, width, height,
    settings) z src.ui.interface korzystają z aktora HUD/rąk i widza kamery.
    Gotowy przykład przechwycenia
    każdego obrazu na własny canvas: qa/view_measure.lua (lokalny
    adapter renderer.present). Samo setCanvas przed renderer:draw
    nie wystarcza: renderer używa własnego celu i kończy go przed present.
    P.capture(game) raz przed krokiem, P.sample(shown, alpha) na widok.
    Drugi widok NIE uruchamia drugiego kroku symulacji.
    Wolna kamera: Context.of(game, actor, camera), gdzie camera ma
    x/y/z/yaw/pitch i stałą tożsamość tabeli, zmieniane są jej współrzędne.
    Zamknięcie kamery: Context.unobserve(game, actor, camera).
    Zamknięcie widoku aktora: Context.unwatch(game, id).
    Nie twórz nowej tabeli kamery co klatkę bez zwolnienia poprzedniej.
    Split-screen jest sprawdzany technicznie, nie udostępniony w menu.

21. Nowe pole prezentacji i efekt
    Fields.declareView(owner, names, scope): world = wspólny świat;
    actor = osobisty feedback; view = historia konkretnej kamery.
    Bez scope domyślnie actor. Najpierw określ właściciela i reset.
    Własne transienty inicjalizuj przez view_state/hak motion.init,
    tykaj raz na właściciela. Światowe smugi/krew/plamy emituj raz na
    zdarzenie, bez pętli po kamerach. Łuski ekranu należą do aktora.
    Feedback zdarzenia rozwiązuje właściciela przez Recipient; nie tworzy
    przy tym widoku dla nieobserwowanego aktora. Właściciel, który nie jest
    rycerzem (demon), trafia tam, gdzie liczy go księga (Stats.owner).
    Nowe pole aktora zmieniane przez aplikację poza komendą dopisz do
    Journal.actorExternal, bo inaczej dziennik się rozjedzie. Efekt nie zmienia HP,
    czasu przeładowania ani promienia trafienia.

22. Jawny obserwator trafienia
    Geometria pocisku używa żywego właściciela lub punktu wystrzału,
    wzrok i oczy stworzenia jego celu, strzał obserwacji strzelca.
    Kamera dekoracyjna nie jest obserwatorem symulacji. Wykonawca dostawy podaje
    obserwatora jawnie do Pose/Surface/Geometry, zgodnie z E4.
    Dwie nogi mogą mieć osobne id kształtu i jedną strefę obrażeń;
    kolizja ruchu i podatna powierzchnia nadal są osobnymi kontraktami.

23. Sprawca efektu i reakcja kontaktu
    Przekaż ID źródła całym łańcuchem obrażeń; efekt okresowy korzysta
    z Effects.origin(g, owner), bez podmieniania na etykietę 'creature'.
    Nieznane źródło to world/nil. Kontakt pocisku/hazardu z rycerzem
    podaje context.effectSource={side=..., id=...}; impuls/pochylenie
    dostaje extra.origin. Nie zastępuj autora bieżącą kamerą ani sterowanym.
    Sprawdź śmierć/odejście źródła, zmianę sterowania, snapshot i replay.
    Pełny reset czyści efekty wszystkich rycerzy; granica fali zachowuje
    poprzednią politykę trwania ekspozycji. Nie zmieniaj jej przypadkiem.

24. Zewnętrzny fakt i zapis podczas sesji
    Execution.effect(g, 'nazwa', fn) (storage/execution.lua) utrwala skalarny
    wynik zapisu w dzienniku, np. komunikat błędu (paragon); fn nie wykonuje
    się podczas replaya ani w sesji efemerycznej. Odczytu z dysku w regule nie ma.
    Trwałe zapisy przeprowadzaj przez storage/save lub jawne canWrite.
    Nie czytaj pliku bezpośrednio z reguły wpływającej na Integrity.
    Test: nagraj A, zmień dane dysku na B, odtwórz A bez odczytu/zapisu.
    Sprawdź też błąd i zwolnienie blokady. Stary journal bez potrzebnego
    faktu ma zgłosić brak danych, nie uzupełniać go dzisiejszym plikiem.

25. Nowe ID, podmiana, wejście wielu aktorów
    Registry:register służy tylko nowemu ID. Zamierzoną podmianę istniejącej
    definicji wykonaj przez replace; ta sama walidacja nadal obowiązuje.
    Nowy move.style/targeting musi mieć funkcję wykonawczą, zarejestrowaną
    przed kompozycją sesji. Literówka ma zakończyć walidację, nie walkę.
    Wejście ciągłe zachowuj przez wszystkie podkroki, także w input.actors.
    Nowe jednorazowe pole dopisz do withoutEdges w session/simulation.lua
    i przetestuj dt większe niż 1/120 bez mutacji wejścia wywołującego.

26. Stan przejściowy i reset próby poligonu
    Nowy rodzaj stanu ma właściciela i czas życia: zasoby/wyposażenie,
    próba walki albo cała sesja. Warunki w conditions i ekspozycje w
    effectState już podlegają pełnemu resetowi niezależnie od ich ID.
    Inny nowy transient rycerza dopisz jawnie do run/actor_reset.lua: tę
    granicę dzielą próba poligonu, odpoczynek, retry i podróż w kaplicy.
    Stan sesji próby należy do run/field/reset.lua.
    Nie odbudowuj aktora z prefabu i nie kasuj wszystkich nieznanych pól;
    zniszczyłoby to przyszłe wyposażenie i trwałe rozszerzenia postaci.
    Refill nie usuwa oszołomienia/poise/worldStop ani trwającej ekspozycji.
    Granica fali nadal ma osobny kontrakt Encounter.clearStage.
    Testuj reset po rzeczywistym trafieniu, pierwszy ruch i kolejne
    trafienie po resecie, zachowanie wyposażenia oraz zapis/odtworzenie
    polecenia resetu z snapshotu w trakcie walki (tests/cases/test_field).

Nowy obszar drogi
-----------------
Dopisz Way.areas:register('id', { id, map, first, fires, doors, garrison }) w
src/content/pilgrimage.lua. Id ognisk i drzwi są unikalne w całej drodze, bo zapis podaje je bez
obszaru. Drzwi na inną mapę mają leads = 'id obszaru', a back stoi już w tamtym obszarze. Test
tests/cases/proving.lua sprawdza każdy obszar przez P.problems: ściany, wysokość kroku, zasięg z
pierwszego ogniska, istnienie stworów. Zmiana nazwy id w istniejącej treści wymaga migracji w sekcji
zapisu 'pilgrimage'; usunięte id samo wypada z zapisu.

## Anatomia i fizyka (0.28)

_Dawniej: `game/docs/ANATOMIA-I-FIZYKA-0.28.txt`_

SIGIL: BREACH — anatomia, obliczenia i granice rozwiązania 0.28
(aktualne dla 0.29; zmiany 0.29 w sekcjach oznaczonych 0.29 i w ZMIANY-0.29)

KIERUNEK
Jeden poligon i dotychczasowe bronie. Wcześniejsze malowane potwory pozostają
wzorcem: matowy fresk, duże plamy pigmentu, miękkie przejścia tonalne. Dodanie
animacji nie upoważnia do zmiany anatomii, połysku ani szczegółowości postaci.
Kontrola SHA-256 155 obrazów względem paczki 0.27: brak zmian. Broń ma jedynie
łagodniejsze różnice między sąsiednimi próbkami pigmentu; alfa i obrys bez zmian.

ARCHITEKTURA
content/enemy_art (z arkuszy content/art/sheets/, plan v10 V7) i content/ability_art: źródła ilustracji i niezmienna rejestracja
klatek. enemies/pose: wspólny opis pozy. Renderer tylko dopina uchwyt obrazu.
Zmiana strefy trafienia nie przesuwa głowy w animacji.
content/art/anatomy/*: części jako dane; id kształtu, strefa obrażeń i materiał
są niezależne. Kilka nóg może mieć wspólną strefę lower; ich liczba nie należy
do algorytmu strzelania. Ostatni pasujący wielokąt opisuje wierzch malunku.
enemies/surface: promień przecina pełny, pochylony billboard, maskę alfa,
a następnie ręcznie opisane regiony. Nie tworzy prostokątnego celu wokół
potwora. Przestrzeń między kończynami jest przestrzelna. Efekt może być widoczny,
ale hittable=false; tasak może blokować z zone=false, bez ranienia właściciela.

Maski wypieka offline qa/bake_hit_masks.lua do danych Lua (0.29: tokeny RLE
o stałej szerokości, content/art/mask_codec.lua, dekodowane raz przy wczytaniu
do wierszy hex; każda klatka zapisuje też źródło: obraz i prostokąt w jego
pikselach). Symulacja nie ładuje PNG ani nie pyta GPU. Siatka 320×320 odpowiada istniejącemu shaderowi: 2 bity
rozróżniają ciało i obrys żywej postaci. Kontur nie zostaje niewidoczną osłoną
po śmierci. Pełny quad zawiera każdą komórkę; nie odrzucamy wystającego rogu
na podstawie dawnego walca tułowia. Wewnętrzne regiony anatomii są ręcznymi
wielokątami, nie idealną segmentacją każdego włosa. Niezależne punkty źródłowych
ilustracji sprawdzają ich sens.

Ruch używa bryły kontaktu ciał; broń palna malowanej powierzchni; pazur własnej
drogi dłoni i fizycznego zasięgu akcji. Dokładność odpowiada zapytaniu.
0.29: reprezentację trafienia wybiera stworzenie (appearance.hit): 'painted'
(wszystkie dzisiejsze demony) albo 'volumes' z jawnym profilem brył. Dawna
kalibracja walców malowanych demonów została usunięta; nic jej nie liczy.

MATERIAŁY I OBRAŻENIA
Damage.surface jest wspólne dla śrucin i pocisków o promieniu. Najpierw obecny
wzór odległości, strefy, pancerza i odporności, następnie polityka materiału.
Żywa kość i czaszka pozostają podatne. Róg nie zabiera HP, lecz przenosi impuls
na gardę. Pancerz używa ratingu strefy. Tkanka skrzydła ma jawny współczynnik
rany/gardy. Szata na ciele nie daje odporności; luźne fragmenty mogą być wyłączone
w danych. Współczynniki to parametry rozgrywki, nie pomiary biologii ani dżule.
Materiały mają osobną politykę penetracji. Nie dodano losowego rykoszetu:
odbicie wymaga wiarygodnej normalnej i osobno ustalonego bilansu energii.
Normalna billboardu nie opisuje krzywizny rogu. Kontakt już przenosi materiał
i normalną, więc przyszłe odbicia nie wymagają przebudowy katalogu postaci.

Padający trup blokuje, dopóki jest widocznie w ruchu (0.29, enemies/corpse):
malowany upadek nie doszedł do ostatniej klatki (rozszerzony układ 0,44 s:
Sługa, Żelazny, Akolita, Furfur; zwarty 0,28 s: Ogrodnik, Margrabia),
pochylenie nie osiadło (0,33 s) albo ciało jest w powietrzu.
Ta sama reguła obejmuje strzał natychmiastowy i pociski rycerza. Nie dostaje
nowych ran ani nagród. Po osiadaniu przestaje blokować. Kontakty śrucin zbieramy przed zmianą
HP: śmierć od pierwszej nie otwiera arbitralnie drogi kolejnym w tej samej salwie.

RUCH I POCISKI
Niski skok nie pomija już kolizji z graczem aż do lądowania. Względny ruch obu
ciał jest sprawdzany w aktywnej części kroku; lądowanie ma wyliczony czas kontaktu.
Usuwa to końcowe wypchnięcie z nałożonych ciał. Pazur korzysta z punktów dłoni/
pyska oraz zasięgu w danych akcji. Ilustracja nie ma głębokości 3D.
Pocisk o promieniu wykonuje ciągły sweep, także przy ścianie, filarze i ziemi.
Powierzchnia postaci jest konserwatywnie aproksymowana komórkami: przyspieszone
trafienie ogranicza połowa przekątnej komórki maski, zapisana w contact.tolerance.
Hitscan nie używa tego rozszerzenia. Wybuch zachowuje osobną regułę ekspozycji
środka ciała; nie udaje promienia.

POWTÓRKI I POMIAR
Journal v2 sprawdza pełny początkowy i końcowy stan symulacji, domyka zmianę
pauzy przed eksportem. Dziennik trafień zawiera shapeId, zone, material, punkt,
dystans i wynik obrażeń. Inny ekwipunek, tier czy nieśmiertelność nie mogą po
cichu odtwarzać pozornie tej samej sesji. Telemetria rozdziela czas od pojawienia,
świadomości i pierwszej rany, rodzaje kontroli oraz potencjalne/faktyczne/
zmarnowane leczenie. Raporty work/qa-v28/hit-* mierzą GPU, interpolację przy
różnych harmonogramach klatek i koszt całej salwy. CPU nie odtwarza mipmap GPU
idealnie; granica niepewności jest raportowana. Automat nie dowodzi przyjemności
ani perfekcyjnego balansu. Ocena B2 wymaga faktycznych sesji człowieka.

ŹRÓDŁA — ZASADY, NIE KOPIOWANIE KODU SILNIKÓW
NVIDIA PhysX, Scene Queries: różne zapytania ray/sweep/overlap, fazy i dane wyniku.
https://nvidia-omniverse.github.io/PhysX/physx/5.4.1/docs/SceneQueries.html
Epic, Physical Materials: materiał powierzchni jako osobna własność danych.
https://dev.epicgames.com/documentation/en-us/unreal-engine/physical-materials-user-guide-for-unreal-engine
Valve Source SDK 2013 studio.h; id Software Doom 3 Actor.cpp: części, grupy obrażeń,
animacja. Własna implementacja dostosowana do billboardów, bez kopiowania kodu.
https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/public/studio.h
https://github.com/id-Software/DOOM-3/blob/master/neo/game/Actor.cpp
Erin Catto, Continuous Collision, GDC 2013: pierwszy kontakt w przebiegu kroku.
https://box2d.org/files/ErinCatto_ContinuousCollision_GDC2013.pdf
A Large-scale Benchmark and an Inclusion-based Algorithm for Continuous Collision
Detection (2021): koszt oraz błędy fałszywych trafień/pominięć mierzymy oddzielnie.
https://continuous-collision-detection.github.io/
https://arxiv.org/abs/2009.13349
Redon, Lin, Manocha, Fast Continuous Collision Detection for Articulated Models:
pełna obwiednia przed szczegółowym zapytaniem. Nie przenosimy ciężkiego systemu
szkieletowego 3D do płaskiej ilustracji.
https://diglib.eg.org/items/13aac165-e652-4c78-a0a6-0b42305f0753
Przegląd patentów nie uzasadnił innego rozwiązania dla tego prototypu. Sam patent
ani renoma gry nie dowodzą przydatności — decyduje porównanie w naszym silniku.

KONWENCJA WSPÓŁRZĘDNYCH (0.29)
Każdy region jest zapisany w UV KLATKI: u w prawo, v w dół, od lewego górnego
rogu prostokąta klatki w jej obrazie źródłowym; 0..1 wewnątrz klatki. Region
może wystawać poza klatkę (maska go przycina), ale nie dalej niż -0,25..1,25 —
większa wartość to współrzędna w złych jednostkach (test anatomy-data).
Rysowane w innych jednostkach konwertuje się jawnie, z metadanych klatki
(sourcePath, rect) i rozmiaru źródła (content/art/sources.lua, sprawdzanego
względem PNG): Author.fromPixels (piksel obrazu), Author.fromCell (piksel
komórki siatki cols×rows), Author.cellPolygon (wielokąt z komórki, przycięty).
Wszystkie pliki anatomii używają tych funkcji; wymiarów atlasu nie wpisuje
się na sztywno. Maska klatki zapisuje prostokąt w pikselach i dokładny UV,
filtr, SHA-256 pełnego PNG oraz reguły klasyfikacji (siatka, próg, kontur,
skrót qa/hit_truth.lua). Test anatomy-data sprawdza wszystkie źródła,
także podmianę obrazu pod tą samą nazwą i w tych samych wymiarach.
Zmiana wymaga BAKE-HIT-MASKS.ps1 i przeglądu regionów; hashowanie i odczyt
PNG wykonuje tylko bake/QA, nigdy promień strzału. Fallback musi zawierać
cztery różne narożniki klatki w kolejności obwodu; region zerowego pola
jest błędem. Oba kierunki obwodu oraz celowe wyjście poza klatkę są poprawne.

Spójność pigmentu skoku/uniku (domknięcie 0.29): render/creature_pigment.lua
używa profilu obok definicji ilustracji w content/ability_art.lua. Grupuje
tylko RGB i dopasowuje kontrast do bazowych fresków. Alfa, siatka trafień,
prostokąt klatki, pozycja i kotwice pozostają identyczne. QA --pigment-review
sprawdza alfę wszystkich 16 klatek i porównuje sceny w tym samym świetle.

CZĘŚCI I MATERIAŁY (stan 0.29; zmiana to decyzja rozgrywki, nie poprawka)
Materiały (content/ballistic_surfaces.lua): wound = udział rany w HP, guard =
udział impetu w gardzie, penetrable = runda może iść do ciała za nim,
debris = co rzuca zatrzymany strzał (iskry metal, odpryski bone); brak =
miękka powierzchnia. Strzał i efekty czytają te pola, nigdy nazwy.
  rogi, poroże        torso, horn (bez HP, pełna garda)       Sługa, Ogrodnik,
                                                              Margrabia, Furfur
  skrzydła błoniaste  torso, membrane (25% rany i gardy)       Sługa (i skok)
  skrzydła z piór     torso, flesh (100%)                      Akolita (i unik)
  ogon                torso, flesh                             Sługa
  grzywa, sierść      torso, flesh                             Ogrodnik
  płomień ogona       efekt, hittable=false (bez kontaktu)     Furfur
  blask czaru, ślina  efekt, hittable=false                    Akolita, Ogrodnik
  luźny płaszcz       zone=false, cloth, hittable=false        Żelazny
  szata na ciele      cloth (jak ciało: bez osłony)            —
  tasak               zone=false, metal (blokuje bez rany)     Margrabia
Niespójność do decyzji (B2), świadomie NIE zmieniona w 0.29: skrzydła Sługi
(błona) chronią, skrzydła Akolity (pióra) są pełnym ciałem. Jeśli pióra mają
chronić, potrzebny jest osobny materiał „feather” z własnymi wound/guard —
to zmiana balansu i złotego wzorca, więc wymaga oceny w grze.

NARZĘDZIE DO ADNOTACJI — OCENA (0.29)
Wariant na istniejącej ilustracji nie wymaga narzędzia: dziedziczy atlas,
a inny opis ciała to adnotacja appearance.regions wyprowadzona z istniejącej
w kodzie (tests/cases/creature_extension.lua tnie tułów na płyty). Nowy atlas
to dziś ok. 28 klatek ręcznych wielokątów (6–12 części na klatkę) pisanych
w Lua, sprawdzanych arkuszami kontaktowymi (tools/art/anatomy/contact.ps1),
punktami źródłowymi i testem anatomy-data. Prosty edytor w LÖVE (klatka
z maską pod spodem, klikane wierzchołki, eksport Author.part w UV klatki,
podgląd stref i materiałów) zwróci się przy pierwszym nowym atlasie;
wcześniej nie jest potrzebny. Propozycja na kolejny etap, nie zrobione.

ROZBUDOWA
Wariant na istniejącej ilustracji: Creature.define({ extends = ... }),
ewentualnie appearance.regions (własna adnotacja tych samych klatek),
attacks/move.evade/appearance.art/evadeArt (połączenie istniejących ataków
i uników). Nowa istota z nowym atlasem (plan v10 V7): PNG, arkusz
content/art/sheets/<id>.lua z narzędzia (EXPORT-SHEET.ps1), anatomia z warstw
części lub edytora regionów (EXPORT-ANATOMY.ps1, ANATOMY-EDITOR.ps1),
BAKE-HIT-MASKS.ps1, punkty źródłowe, --hit-review i CHECK-CREATURE.ps1.
Nowy materiał:
jeden wpis w content/ballistic_surfaces (wound, guard, penetrable, debris).
Nowa broń: definicja Weapon; nowy mechanizm tylko przy innej zasadzie
działania. Bez if kind == nowy_potwor w matematyce pocisku. Niszczenie
kończyn i nowe modele 3D pozostają poza zakresem.

## Linux

_Dawniej: `docs/LINUX.md`_

### SIGIL: BREACH na Linuxie

Każde polecenie ma tu pełny odpowiednik linuksowy: `scripts/win/*.ps1` i `tools/win/*.ps1` to Windows, `scripts/linux/*.sh` i `tools/linux/*.sh` to Linux, o tych samych nazwach poleceń i tym samym zakresie. PowerShell na Linuxie nie jest potrzebny. Sklonowane repozytorium ma własne LÖVE 11.5 (`toolchain/love-11.5-linux`, AppImage) i StyLua 2.6.0 (`toolchain/stylua/stylua`), z pochodzeniem w `toolchain/stylua/PROVENANCE-LINUX.txt`.

#### Instalacja i pierwszy start

Potrzebne z systemu: git, bash, coreutils, flock (util-linux), python3 i biblioteki graficzne pulpitu. Bez pulpitu także `xvfb-run` z pakietu xvfb oraz xauth. Biblioteka libfuse2 nie jest potrzebna: AppImage rozpakowuje się sam do `/tmp` i zostaje tam na następne uruchomienia.

```bash
git clone git@github.com:VkareGit/sigil-breach.git ~/dev/sigil-breach
cd ~/dev/sigil-breach
scripts/linux/RUN.sh
```

`SIGIL_LOVE=/ścieżka/do/love` i `SIGIL_STYLUA=/ścieżka/do/stylua` wskazują inne programy (sam plik, bez argumentów). Bez dołączonego LÖVE skrypty biorą `love` z PATH. Sam uruchomisz grę także przez `love game`, jeśli masz LÖVE w systemie.

#### Testy i warsztat

| Windows | Linux | Co robi |
|---|---|---|
| `.\scripts\win\RUN.ps1` | `scripts/linux/RUN.sh` | gra ze źródeł (`--release`: ostatnia paczka) |
| `.\scripts\win\FORMAT.ps1 [-Check]` | `scripts/linux/FORMAT.sh [--check]` | StyLua |
| `.\scripts\win\TEST.ps1 -Suite All -TestTimeoutSeconds 1800` | `scripts/linux/TEST.sh All --timeout 1800` | pełna brama; także `Architecture`, `Mechanics`, `Input`, `Render`, `Tools` |
| `.\scripts\win\BUILD.ps1 [-Package]` | `scripts/linux/BUILD.sh [--package]` | testy i paczki |
| `.\scripts\win\MEASURE.ps1` | `scripts/linux/MEASURE.sh --before A --after B` | protokół pomiaru |
| `.\scripts\win\BAKE-HIT-MASKS.ps1` | `scripts/linux/BAKE-HIT-MASKS.sh` | maski trafień |
| `.\scripts\win\CHECK-CREATURE.ps1 <id>` | `scripts/linux/CHECK-CREATURE.sh <id>` | kompletność demona |
| `.\scripts\win\EXPORT-SHEET.ps1 <id>` | `scripts/linux/EXPORT-SHEET.sh <id>` (`--spec plik`) | arkusz atlasu |
| `.\scripts\win\EXPORT-ANATOMY.ps1 <id>` | `scripts/linux/EXPORT-ANATOMY.sh <id>` (`--legend plik`, `--install`) | dane anatomii |
| `.\scripts\win\ANATOMY-EDITOR.ps1 <id>` | `scripts/linux/ANATOMY-EDITOR.sh <id>` | edytor regionów |
| `tools\win\art-contact.ps1` | `tools/linux/art-contact.sh` | arkusze kontaktowe UV |
| `tools\win\art-crops.ps1` | `tools/linux/art-crops.sh <kind> <frame>` | powiększenia klatek |

Wewnętrzne części też mają pary: `project`, `check`, `check-paths`, `check-platform`, `build`, `verify`, `package-check`. Wspólna biblioteka to `tools/linux/project.sh`, a zasady paczki gracza `tools/linux/package.py`.

Na Omarchy okno bez trybu floating może zostać dopasowane do kafelka. Testy kliknięć muszą korzystać z rzeczywistego obszaru interfejsu (`U.viewport`, skala i marginesy), zamiast niezależnie rozciągać współrzędne X/Y. Sonda FOV przy 960×1080 odtworzyła błędne kliknięcie starego testu; po poprawce przechodzi 39 sprawdzeń behavior.

Lokalne ustawienie właściciela: okna o tytule `^SIGIL: BREACH.*` są kierowane na pulpit 2 bez przełączania pulpitu aktywnego. W `~/.config/hypr/hyprland.lua` dodano `o.window({ title = "^SIGIL: BREACH.*" }, { workspace = "2 silent", no_initial_focus = true, render_unfocused = true })`. Ostatnia opcja jest potrzebna, bo ładowanie LÖVE czeka na klatki postępu również wtedy, gdy pulpit 2 nie jest widoczny. Zmiana dotyczy konfiguracji tego komputera; repo jej nie instaluje. Próba potwierdziła okno na 2 i aktywny pulpit 1; `hyprctl configerrors` bez błędów.

Na pulpicie testy otwierają okno i rysuje prawdziwa karta graficzna. `SIGIL_XVFB=1` albo brak `DISPLAY` i `WAYLAND_DISPLAY` przenosi je na wirtualny ekran z rysowaniem programowym. W WSL uruchamiaj z Windows, np. `wsl.exe -d Ubuntu -- bash scripts/linux/TEST.sh Mechanics --timeout 1800`, z folderu repozytorium. `/mnt/c` nie rozróżnia wielkości liter, ale brama `check-paths` sprawdza pisownię ścieżek niezależnie od systemu plików.

Wyniki idą do `~/Work/tries/sigil-breach-<id>/work/qa`, uruchomienia ręczne bez `SIGIL_UI_QA_DIR` do sąsiedniego `qa-direct`. `SIGIL_TRIES_DIR` wybiera inną bezwzględną bazę (także w CI); `<id>` to pełny skrót SHA-256 kanonicznej ścieżki repozytorium. Po `source tools/linux/project.sh` zmienne `SIGIL_WORK` i `SIGIL_QA` podają pełne ścieżki. `MEASURE` zapisuje w `$SIGIL_WORK/measure-<czas>`, edytor w `anatomy/`, a narzędzia UV w `annotate/` i `anatomy-contact/`; ich domyślne dane po ręcznym `--hit-review` pochodzą z `qa-direct/`. Skrypty Linux nie tworzą repozytoryjnego `work/`. Wpisy `FAIL second/fourth/failure` to celowe próby raportera. Złoty wzorzec Linuksa to `game/tests/golden/baseline_linux.lua`, bo biblioteki C inaczej zaokrąglają sin, cos i atan2.

Paczka na Linuxa (`BUILD.sh --package`, tylko na prośbę właściciela): `outputs/<nazwa>-Player-Linux` z `game.love`, AppImage LÖVE, `run.sh`, instrukcją i dokumentami pochodzenia oraz `outputs/<nazwa>-Developer-Linux` ze źródłami i narzędziami. `tools/linux/verify.sh` sprawdza sumy i zawartość, uruchamia gracza na 20 s, puszcza bramę Architecture w kopii deweloperskiej i pisze archiwa `.tar.gz`. Paczka EXE i ZIP powstaje tylko na Windows.

Warsztat malowideł `tools/art/chapel_hall/*.py` wymaga opcjonalnie Pillow i NumPy; nie są zależnościami gry ani bramy.

#### Zapisy i przenoszenie komputera

Domyślny katalog danych LÖVE to `~/.local/share/love/`. Jeśli ustawisz
bezwzględne `XDG_DATA_HOME`, będzie to `$XDG_DATA_HOME/love/` (małe litery).
Główna gra zachowuje identity `sigil-breach-prototype`; QA używa
`sigil-breach-qa` i `sigil-breach-qa-input`.

Zamknij grę na obu komputerach. Skopiuj **całe katalogi**
`%APPDATA%\LOVE\sigil-breach*` z Windows do linuksowego katalogu `love`,
zachowując nazwy, sloty i zapasowe generacje. Najpierw zachowaj kopię istniejących
zapisów z nowego komputera. Zapisów nie ma w repozytorium. Pliki QA można pominąć,
jeśli nie chcesz przenosić danych testowych.

Ręcznie przenieś to, czego klon nie odtworzy:

- pamięć Claude Code: `~/.claude/projects/<ścieżka-projektu>/memory/`.
  Nazwa katalogu projektu jest wyprowadzana z pełnej ścieżki. Po pierwszym
  uruchomieniu Claude w nowym klonie odszukaj utworzony katalog dla tej ścieżki
  i skopiuj do niego `memory/`; nie zostawiaj jej pod nazwą opisującą dysk C:.

Śledzone wzorce z `docs/art/` przychodzą z klonem.

#### Agenci na Linuxie

Zainstaluj linuksowego Codexa i używaj `codex` z PATH; sprawdź `command -v codex`
i `codex exec --help`. Nie kopiuj ścieżki do windowsowego `codex.exe`.
Usuń z przenoszonej konfiguracji ustawienie `windows.sandbox` (lub pole sandbox
w sekcji `[windows]`). Pozostałe ustawienia dobierz do nowej instalacji.
Poniższe opcje sprawdzono w lokalnej pomocy CLI; nie instalowano narzędzi ani
nie weryfikowano ich przez sieć podczas tego porządkowania.

Przykład pracy Astry w osobnym klonie, z bash:

```bash
cd ~/Work/tries/sigil-linux
source tools/linux/project.sh
export XDG_DATA_HOME="$SIGIL_WORK/xdg-data"
mkdir -p "$XDG_DATA_HOME/love/sigil-breach-qa" /tmp/sigil-codex
codex exec -m gpt-6-astra -c 'model_reasoning_effort="ultra"' \
  --sandbox workspace-write -C "$PWD" --json \
  -o /tmp/sigil-codex/last-message.md - < BRIEF.md > /tmp/sigil-codex/codex.jsonl
```

Na Linuxie izolację danych LÖVE ustawia `XDG_DATA_HOME`, zamiast `APPDATA`.
`SIGIL_UI_QA_DIR` nadal wybiera katalog raportów, niezależnie od zapisów gry.
Punkt wejścia: `START-HERE.txt`; zasady pracy: `docs/AGENTS.md`; decyzje właściciela: `docs/WIZJA.md`. Nie dodawaj prywatnych konfiguracji,
pamięci agentów ani plików właściciela do gita.

#### Znane różnice (sprawdzone w WSL, 3 listopada 2026)

Przed przeprowadzką testy gry uruchomiono w WSL Ubuntu 26.04 z LÖVE 11.5 przez
`xvfb-run`, na natywnym systemie plików (`/mnt/c` nie rozróżnia wielkości liter).
Przeszło 116 ze 119 zestawów. Pozostałe trzy:

- `golden`: symulacja jest deterministyczna, ale biblioteki C liczą sin, cos i atan2
  z innym zaokrągleniem niż na Windows, więc długie przejścia rozjeżdżają się po
  chwili. Linux ma własny wzorzec `game/tests/golden/baseline_linux.lua`. Zmiana
  rozgrywki odświeża wzorzec systemu, na którym ją sprawdzono.
- `weight` (rysowanie ciał w jednej partii daje te same piksele co osobno) i
  `floor-layers` (ogień na moście nie świeci na podłogę pod spodem) porównują
  piksele dokładnie albo z tolerancją 0,004. WSL rysuje programowo (llvmpipe),
  więc najpewniej to różnica sterownika. **Sprawdź je przy pierwszym
  `./scripts/win/TEST.ps1 -Suite All` na nowym komputerze z prawdziwą kartą graficzną.** Jeśli
  dalej nie przechodzą, ustal przyczynę, zanim zmienisz tolerancję.

### Kontrola bazy wyglądu (2026-11-05)

`baza/` nie jest zasobem gry ani częścią pakietu `.love`. `index.json`
zapisuje reprezentatywne wzorce z ich pochodzeniem, a `catalog.json`
obejmuje wszystkie rastrowe pliki produkcyjne. Architecture na Linuxie
uruchamia `python3 tools/art/check_visual_catalog.py --self-test`;
raport to `visual-catalog.txt`. Siedem prób kontrolnych sprawdza także
podmianę pod tą samą nazwą, nowy/utracony plik i zależność gry od bazy.
Zmiana SHA-256 w katalogu wymaga trzech przeglądów opisanych w STYLU.
Nie jest sposobem zatwierdzania niezaakceptowanego malowania.

Zestaw `visual-identity` w Mechanics wiąże Iron Thralla z oryginalnym
arkuszem 6×4. Przepakowana kopia zachowuje każdy widoczny RGB i każdą alfę,
przezroczyste obramowanie, skalę pikseli i najbliższe próbkowanie. Cztery
pozy spoczynku mogą wskazywać komórki używane przez ruch; każda nadal jest
sprawdzana. Inne nowe projekty przechodzą procedurę akceptacji właściciela,
a nie automatyczne rozszerzenie listy akceptacji. Windows nie był objęty
podłączeniem skryptu Pythona, zgodnie z obecnym zakresem właściciela.
