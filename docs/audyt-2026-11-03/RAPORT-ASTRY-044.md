Wdrożyłam **0.44** w klonie `sigil-astra-044`, na bazie `aa7b1e9`, bez commitów i delegowania. Poprawiłam potwierdzenie trafienia, punkt kontaktu, ślad pudła, pozę Exorcista, czytelność ARSENAL i włóczni Stolasa, dźwięki Judge IRON oraz dodałam animację picia. Nie zmieniałam balansu ani zegarów SI. Warianty tonów stworów zostały odrzucone ze względu na naruszenie stylu i sylwetki.

**Pełne `TEST.ps1 -Suite All -TestTimeoutSeconds 1800` jest zielone, kod zakończenia 0.** Wynik: 6044 sprawdzenia mechaniki/zasobów, 50 wejścia, showcase ze 144 scenami i 5275 sprawdzonymi granicami elementów UI, wszystkie testy narzędzi i startu. `hazard-art` przeszedł w pełnym przebiegu: 43 sprawdzenia. Wpisy `FAIL second`, `fourth`, `failure` są wyłącznie celowymi próbami raportera. Wszystkie dziewięć etapów ma ten sam, stabilny odcisk źródeł. [Świadectwa i podsumowanie](C:/Users/nahiko/Documents/dev/sigil-astra-044/work/astra-044/verification/SUMMARY.json).

Materiały: [nagranie.mp4 — 29,49 MiB](C:/Users/nahiko/Documents/dev/sigil-astra-044/work/astra-044/nagranie.mp4), [kopia poniżej 30 MiB — 15,87 MiB](C:/Users/nahiko/Documents/dev/sigil-astra-044/work/astra-044/nagranie-ponizej-30MiB.mp4), [Judge IRON A/B](C:/Users/nahiko/Documents/dev/sigil-astra-044/work/astra-044/judge-iron-AB.wav). Oba filmy: H.264, 1280×720, 30 fps, 46 s; sprawdzone przez ponowne odkodowanie. Film jest niemy, obejmuje sceny kontrolowane i fragment rzeczywistej walki bota z Margrave'em. Odsłuch WAV zawiera kolejno trzy pary oryginał/wariant.

Najpierw sprawdziłam rejestrację. Sonda używa alfy malowanego arkusza odczytanej przez położenie renderera do wyboru środka ciała, niezależnie od maski trafień. Obejmuje 3/6/10 m, obie bronie, spoczynek, ruch boczny, przygotowanie/uderzenie/powrót z ataku, skok Ember Thralla i rzeczywisty unik Stolasa. Każdy przypadek wykonuje strzał świeży, kolejny w pierwszym dozwolonym momencie oraz strzał po szybkiej zmianie broni. Między obserwacją a rozstrzygnięciem upływa 33,3 ms ruchu. To 32 reprezentatywne pozy i 576 salw na przebieg.

| Stwór | Salwy przed / po | Całkowite pudła przed / po |
|---|---:|---:|
| Ember Thrall | 108 / 108 | 0 / 0 |
| Stolas | 108 / 108 | 0 / 0 |
| Iron Thrall | 90 / 90 | 0 / 0 |
| Buer | 90 / 90 | 0 / 0 |
| Margrave | 90 / 90 | 0 / 0 |
| Furfur | 90 / 90 | 0 / 0 |

Judge trafił 288/288 promieni. Exorcist trafił 1787/1920 śrucin z 3 m (**93,1%**), 1397/1920 z 6 m (**72,8%**) i 966/1920 z 10 m (**50,3%**). Pozostałe śruciny to rozrzut; żadna cała salwa nie ominęła ciała. Wyniki CSV przed/po są identyczne. Maksymalny błąd projekcji celownika względem promienia wyniósł 2,28×10⁻¹³ px. Ruch celu między obserwacją a strzałem dochodził do 0,355 m; w badanych środkach ciała nie spowodował rozbieżności trafienia.

Dodatkowa siatka 40 960 punktów zawierała 11 642 próbki trafialnej farby, 442 dekoracyjne, 27 180 powietrza i 1696 próbek krawędzi. Nie wykryła rozbieżności alfa z maską. Spośród trafialnych próbek 26 leżało na najniższych fragmentach stóp zasłoniętych płaszczyzną podłogi; jedna próbka Margrave'a wypadła dokładnie na narożniku teksela i zmieniała wynik przy przesunięciu UV o 0,000001. To granica numeryczna konturu, nie odtworzony błąd wnętrza ciała. Surowy raport zachowuje tę pojedynczą niezgodność, zamiast ją usuwać.

`hittable=false` obejmuje m.in. luźną tkaninę Iron Thralla i efekty zaklęć. Błona skrzydła pozostaje trafialna, z istniejącym mnożnikiem obrażeń 0,25; otwory alfa pozostają powietrzem. Stolas wykonuje fizyczny odskok, bez dodanej nietykalności. Nowe miejsce kontaktu/pudła pomaga zobaczyć, dokąd poszedł strzał. Nie znalazłam powtarzalnego błędu rejestracji środka ciała, więc nie zmieniałam balistyki, anatomii ani `combat/observation.lua`. Ten pomiar nie dowodzi poprawności każdego punktu konturu i każdego możliwego opóźnienia.

[Wycinki sześciu przypadków](C:/Users/nahiko/Documents/dev/sigil-astra-044/work/astra-044/checks/hit-cases.png). Dane: `work/astra-044/before-grid/` i `after/` — `shots.csv`, `masks.csv`, `grid-occlusions.csv`; narożnik teksela: `film/boundary.csv`. Powtórzenie: `work/astra-044/scripts/run.ps1 -Stage repeat -Task probe` przy zamkniętych innych testach. Skrypt tymczasowo dodaje sondę do wejścia gry i przywraca plik bajt w bajt; końcowy `game/main.lua` jest niezmieniony.

Czytelność trafienia mierzyłam z par renderów różniących się wyłącznie błyskiem ciała, w liniowej luminancji sRGB przeliczonej na L*. Mediana ΔL* po 33,3 ms:

| Ujęcie | 0.43 | 0.44 |
|---|---:|---:|
| Judge, 3 m | 5,80 | **8,54** |
| Judge, 10 m | 6,21 | **9,10** |
| Exorcist, 3 m | 5,57 | **8,19** |
| Exorcist, 10 m | 5,86 | **8,63** |

Cel ≥7 został osiągnięty przez wydłużenie błysku 65→80 ms, bez dodatkowego rozjaśniania shadera. Podkład znacznika ma alfa 0,85 zamiast 0,55; cztery kreski, ich wymiary i kolory pozostają bez zmian. Akcent kontaktu trwa 67 ms i powstaje na rzeczywistym promieniu, zamiast w średniej mogącej wypaść między skrzydłami. Pudło pokazuje kontakt ze ścianą/podłogą oraz istniejący trwały ślad. [Wycinki przed/po](C:/Users/nahiko/Documents/dev/sigil-astra-044/work/astra-044/checks/flash-before-after.png).

Rdzeń włóczni sprawdziłam na wspólnym obszarze obu wariantów, obejmującym także ciemną krawędź; maska pomiarowa to suma pikseli zmienionych względem tła o więcej niż 2/255. Udział kontrastu poniżej 1,5:1 wynosi: centrum **39,15→31,84%**, jasna płyta **44,78→30,95%**, ciemna płyta **38,57→31,56%**, widok boczny **36,10→27,39%**. Mediana centralna: **1,73→2,35:1**. Cel <40% spełniony we wszystkich czterech parach. Wstępny pomiar na osobnych maskach, zapisany w ZMIANY, dawał 38,45→29,70%; wspólny obszar jest surowszym porównaniem. To nowe pary kontrolne, nie dokładne odtworzenie kamery V01. Pierwszy wygenerowany wariant pogarszał wynik i został odrzucony. [Wycinki włóczni](C:/Users/nahiko/Documents/dev/sigil-astra-044/work/astra-044/checks/lance-before-after.png).

Judge IRON ma 8 ms ataku w paśmie 1,5–4 kHz. Udział energii poniżej 150 Hz spadł z **87,12/84,74/82,22% do około 75%**. RMS pierwszych 100 ms zmienił się o mniej niż 0,001 dB. Szczyty trzech plików: **0,639 / 0,679 / 0,611**, poniżej 0,95. Są to pomiary plików źródłowych, przed wzmocnieniem miksera gry; szczegóły w `audio-measurements.json`.

Zmiany plik po pliku; poniższe ścieżki zaczynają się w `game/`:

| Plik | Zmiana i uzasadnienie |
|---|---|
| `src/content/combat_defaults.lua` | `hitFlash` 0,065→0,08 s, żeby błysk pozostał czytelny po 33 ms. |
| `src/ui/hud.lua` | Podkład znacznika 0,55→0,85; `quietInk` ARSENAL 0,42→0,55. Chroniona kompozycja HUD bez zmian. |
| `src/content/effect_art.lua` | Krótkie sekwencje kontaktu krwi i materiału z istniejącego malowanego atlasu. |
| `src/feedback/impact_response.lua` | Emisja zwartego akcentu w rzeczywistym miejscu kontaktu; także przy pudle w powierzchnię. |
| `src/feedback/shot_feedback.lua` | Jeden akcent na trafiony cel, z konkretnego promienia salwy. |
| `src/content/art/weapon_frames.lua` | Exorcist: końce faz 0,08/0,14 s, `automaticFireUntil` 0,14 s; cykl 0,94 s bez zmian. |
| `assets/art/rites-fresco-v36.png` | Kościany rdzeń i ciemne obrzeże w obecnym polu promienia. Oryginalna alfa, rozmiar i pozostałe trzy pola zachowane dokładnie. |
| `assets/sounds/judge/B1-1.wav` | Pierwszy wariant IRON z krótkim atakiem; zachowany RMS. |
| `assets/sounds/judge/B1-2.wav` | Drugi wariant IRON z tymi samymi ograniczeniami. |
| `assets/sounds/judge/B1-3.wav` | Trzeci wariant IRON z tymi samymi ograniczeniami. |
| `assets/art/flask-hands-v44.png` | Nowy malowany arkusz 1536×1024, sześć klatek; przezroczystość uzyskana z zamówionego klucza magenta. |
| `src/content/abilities.lua` | Przypisanie gestu rąk do flaski. |
| `src/content/equipment_art.lua` | Atlas, uchwyty, fazy i ścieżka ręki; rozróżnienie gestu podczas przygotowania i po użyciu. |
| `src/feedback/ability_feedback.lua` | Faza picia pochodzi z istniejącego `casting.left` i czasu zdolności; brak osobnego zegara, który przetrwałby anulowanie. |
| `src/render/weapon.lua` | Ruch i przechył ręki oraz opuszczenie/powrót broni, z istniejącym shaderem rąk. |
| `tests/cases/flask_art.lua` | 24 sprawdzenia sześciu faktycznie rysowanych klatek, shadera, zakończenia, przerwania, zapisu, śmierci i zmienionej długości zdolności. |
| `tests/cases/hit_feedback.lua` | 7 sprawdzeń kontaktu obu broni, błysku po 33 ms i śladu pudła bez hitmarkera. |
| `tests/cases/firing_feedback.lua` | Sprawdzenie dłuższej pozy Exorcista, także granic faz. |
| `tests/suites/movement.lua` | Test śmierci sprawdza plamę i obecność krwi niezależnie od kolejności efektów; dodatkowo potwierdza zgon. |
| `tests/suite.lua` | Rejestracja `flask-art` i `hit-feedback` w pełnym zestawie. |
| `src/core/build.lua` | Wersja 0.44. |
| `docs/ZMIANY.txt` | Nowa sekcja `ZMIANY-0.44.txt`, z pomiarami i ograniczeniami. |
| `docs/ODBIOR.txt` | Nowa sekcja `ODBIOR-0.44.txt`, testy i zakres odbioru właściciela. Oba dokumenty zachowują CRLF i UTF-8 bez BOM. |

Poza grą, `work/astra-044/scripts/` zawiera sondę, przygotowanie zasobów, pomiary, składanie filmu i wycinków. `originals/` przechowuje materiały A/B, `variants/` wyniki generacji, `PROMPTY.md` specyfikacje ImageGen, `checks/` klatki kontrolne PNG, `film/` 1320 surowych klatek i przebieg zdarzeń. [Sześć faz picia](C:/Users/nahiko/Documents/dev/sigil-astra-044/work/astra-044/checks/flask-phases.png), [kontrola odkodowanego MP4](C:/Users/nahiko/Documents/dev/sigil-astra-044/work/astra-044/checks/decoded-mp4.png).

Test czerwony przed poprawą czytelności: przywrócenie `hitFlash=0.065` wywołuje błąd „keeps the body flash through the second 30 Hz sample”; po 0,08 przechodzi (`red-proof/red-test.txt`). Pierwszy pełny przebieg wykrył opisane założenie o ostatnim efekcie w `movement`; krew i plama były obecne. Po korekcie testu `movement` przechodzi 46 sprawdzeń i cała brama została uruchomiona ponownie.

Osobno zielone: `firing-feedback` 32, `weight` 808, `geometry` 316, `open-presentation` 38, `aim-truth` 12, `anatomy-data` 17, `hit-landmarks` 220, `painted-surfaces` 15, `weapon-art-review` 4, `ability-art` 85, `flask-art` 24, `hit-feedback` 7. Dwa przebiegi `golden` po 10 sprawdzeń dały identyczne pliki, SHA-256 `CFE9A54506CFE842C22F1760E6A710A351010E241A3BF2307143BC7644FB1679`, zgodne z istniejącym wzorcem. `baseline.lua` pozostał bez zmian. Formatowanie i architektura: 652 pliki Lua, 0 naruszeń.

Nie wdrożyłam lokalnego rozjaśnienia Iron Thralla i Stolasa: wygenerowane warianty zmieniały detale sylwetki, materiały i alfa. Oryginalne arkusze oraz anatomia zostały zachowane; **cel kontrastu Iron Thralla ≥1,5:1 pozostaje otwarty**. Nie dodałam opcjonalnego zamrażania pozy — sam błysk spełnił cel, a obraz nadal odpowiada bieżącej pozie. Nie dodałam dźwięku łyku. Istniejący stan `drinking` zabrania uniku, więc nie zmieniałam tej reguły: animację przerywają cios, anulowanie i śmierć; test potwierdza też dotychczasowy zakaz dash. Czas picia nadal wynika ze zdolności, obecnie 0,95 s.

Do oceny właściciela pozostają: czytelność trafienia w normalnej grze, wygląd i skala ręki z flaską, charakter jasnego rdzenia włóczni oraz brzmienie Judge IRON. Pomiary i film nie zastępują tego odbioru.
