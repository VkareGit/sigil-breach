Kontynuujesz pracę nad grą SIGIL: BREACH. Odpowiadaj po polsku. Plan poniżej jest propozycją modeli, właściciel go jeszcze nie zatwierdził.

# Projekt

Katalog: C:\Users\nahiko\Documents\dev\sigil-breach. FPS w LÖVE 11.5 i LuaJIT, który staje się grą w stylu Souls. Rycerz bez magii, bronie Exorcist (strzelba) i Judge (rewolwer), kaplica z 4 ogniskami i 15 stworami, dusze, echo po śmierci, śluby przy ogniskach, 3 sloty zapisu. Wersja 0.41, audytowany commit 489e3a5.

Filary: odczyt ciosu i wiedza ważniejsze niż refleks; ciężki, czytelny strzał; żywy mroczny fresk.

# Decyzje właściciela

- Styl demonów, HUD i broni ma się nie zmieniać. Dolny pasek jest chroniony: jego charakter, kształt, kompozycja i styl zostają. Wolno poprawiać czytelność treści wewnątrz istniejących nisz. Zmiana designu wymaga osobnej zgody.
- Bossowie są odłożeni. Margrave i Furfur to zwykłe najtrudniejsze moby.
- Call of Duty jest odniesieniem tylko dla nagrody i potwierdzenia po strzale. Gra zostaje Souls-like.
- Strzał nie bierze wytrzymałości, kosztuje chwilę po strzale. Serie dają bonus tylko na broni, z której powstały. Medal chwilowo u góry ekranu, stała informacja o serii cicha.
- Język celownika: biały X trafienie, niebieski pancerz, złote narożniki pęknięta garda, duży czerwony X zabójstwo.
- Tekst w grze i na nagraniach po angielsku. Dokumenty w game/docs po polsku.
- Usuwać, nie przenosić. Rozmiar nie jest powodem do odkładania zatwierdzonej pracy.
- Bez EXE i ZIP, dopóki właściciel nie poprosi. Uruchamia grę przez `love .`. `.\BUILD.ps1` to same testy, około 13 minut.
- Pracuj do końca, sprawdzaj sam (testy, bot, rendery), kończ jednym raportem. Właściciel często czyta z telefonu: pełna odpowiedź w wiadomości końcowej, pliki przez SendUserFile.
- Po każdym punkcie commit i wpis postępu, żeby inny agent mógł przejąć pracę.
- Właściciel raz wkleił w czacie token Hugging Face: nigdy go nie zapisuj ani nie powtarzaj.

# Codex Astra: obowiązkowa delegacja

Grafikę, dźwięki, muzykę, modele i nagrania generuj przez Codex Astra (`gpt-6-astra`) na poziomie high albo xhigh, nie ręcznie. Kod gry piszesz Ty. Codex dostaje wąskie zadanie, kontekst, ścieżkę wyniku i kryterium, a Ty oglądasz wynik i integrujesz.

Wywołanie w PowerShell 5.1 przez cmd, bo tylko tak prompt przechodzi jako UTF-8:

$b=(Get-ChildItem "$env:LOCALAPPDATA\OpenAI\Codex\bin" -Recurse -Filter codex.exe | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
cmd /c "`"$b`" exec --skip-git-repo-check -m gpt-6-astra -C `"<katalog>`" --sandbox workspace-write -c windows.sandbox=`"unelevated`" -c model_reasoning_effort=`"high`" --json - < `"<prompt.md>`" > `"<wynik.jsonl>`" 2> `"<wynik.err>`""

Tekst końcowy to ostatni `item.completed` typu `agent_message`. Uruchamiaj w tle. Przy piaskownicy `elevated` LÖVE nie startuje. Do grafiki Codex uruchamiaj w repozytorium; do audytów i pomiarów w osobnym klonie. Obowiązkowo zgłoś właścicielowi, że nikt nie słyszał dźwięków, dopóki ich nie oceni.

Kolejność delegacji:
1. Znaki HUD do G05 i ikony ślubów (treść niżej), po etapie 0.
2. Ilustracje strony zasad do L04: złoty pierścień, garda, egzekucja, w stylu pieczęci.
3. Poprawki dźwięków po odsłuchu właściciela, tylko według jego uwag.
4. Nagrania na prośbę właściciela.

Pierwsza delegacja, gotowa treść (zapisz jako prompt, poziom high):

"""
Projekt SIGIL: BREACH, gra w stylu żywego, mrocznego fresku. Wygeneruj grafiki, nie zmieniaj żadnego pliku poza work/hud-marks/.
Zapoznaj się z: game/docs/KIERUNEK-ARTYSTYCZNY.txt, game/assets/art/medals (styl i provenance.json), work/look/look-first-fire.png (dolny pasek).
Potrzebne PNG z przezroczystym tłem, malowane, matowe, ochra, umbra, zgaszona czerwień, kontur brunatny, czytelne w 18 px na jasnym pergaminie:
1. dodge_ready i dodge_spent: znak ładunku uniku, 64×64.
2. flask i powder: znaki flaski i ładunku prochowego, 64×64.
3. vow_flask, vow_ward, vow_vigour: trzy różne ikony ślubów do sklepu, 96×96, dziś dwa śluby mają tę samą tarczę.
Bez tekstu, bez czaszek, bez połysku. Styl paska i modele demonów zostają bez zmian.
Wynik: work/hud-marks/<nazwa>.png, provenance.json i arkusz sheet.png pokazujący każdy znak w 18 px na pergaminie. Wypisz, czego nie udało się osiągnąć.
"""

Nie dubluj pełnych audytów. Astra może dodatkowo zrobić przegląd read-only ryzykownych zmian (R02, R03) na xhigh, jeśli właściciel się zgodzi.

# Praca w repozytorium

- Commit: `git -c user.name=Nahiko -c user.email=psmietanawork@gmail.com commit -F <plik>`, plik bez BOM, na końcu `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Dodawaj `git add -u` plus nowe pliki z nazwy. Nigdy `git add game`: `game/docs/PORADNIK-EDYCJI-GRY.md` i `docs/podrecznik-codex/` to pliki właściciela. Bez push.
- Nie edytuj `game/` w trakcie `TEST.ps1` i `BUILD.ps1`. Przed commitem `.\FORMAT.ps1`.
- Testy: `.\TEST.ps1 -Suite Architecture|Mechanics|Input|Render|All -TestTimeoutSeconds 560`. Wyniki w work/qa. Złoty wzorzec po zmianie zachowania: game/tests/golden/baseline.lua z work/qa/golden-current.lua.
- Rendery: `$env:SIGIL_UI_QA_DIR=(Resolve-Path work\look).Path; toolchain\love-11.5-win64\love.exe game --chapel-look`. Obejrzyj look-*.png.
- Warstwy pilnuje tools/check. Pola sesji w session/fields.lua i session/components.lua, zegary w systems/clocks.lua, zdarzenia w session/event_catalog.lua, liczby w content.
- Sondy bez okna muszą zrobić `require('src.run.modes')`. Sondy i bot: docs/audyt-2026-11-02/sonda-claude.lua, sonda-astra.lua, game/qa/souls_bot.lua.
- Pomiary klatek rób na spokojnej maszynie. Nic nie uruchamiaj obok.

# Źródła

docs/audyt-2026-11-02/: RAPORT-KONCOWY.md (cały plan), AUDYT-CLAUDE.md, AUDYT-ASTRA.md, POMIARY-CLAUDE.txt, SONDY-ASTRA.txt. Plan strzelania i postęp: game/docs/PLAN-STRZELANIE.md. Stan gry: game/docs/INSTRUKCJA.txt (fragmenty nieaktualne, patrz R08), ZMIANY.txt, ODBIOR.txt, ARCHITEKTURA.txt, ROZSZERZANIE.txt. START-HERE.txt opisuje 0.33 i jest nieaktualny.

# Status audytu

Dwa niezależne audyty z 2 listopada 2026, ten sam prompt (SHA-256 4BC1C915…8E24), ten sam commit. Astra: `gpt-6-astra`, poziom `ultra` potwierdzony w logu sesji, osobny klon, testy All, rendery, benchmark i własne sondy, około 21 minut. Audyt Claude zapisany przed odczytem Astry. Nikt nie grał ręcznie i nie słyszał dźwięku. Nie powtarzaj audytu: wracaj do analizy tylko tam, gdzie są zmiany, nowe dowody albo otwarte kwestie.

Potwierdzone (kod lub sonda):
- `P.save` zeruje `dirty` przed zapisem. Odpoczynek nie czyści efektów, a retry impulsu. `Chain.kill` liczy trzymaną broń, ładunek buduje serię. Egzekucja działa przez ścianę i 8 m w pionie. Retry zostaje w obcym obszarze.
- HP i ward mają fałszywe `%`, po ślubach 130%. Furfur daje 0 dusz.
- Cały zapas z ogniska przy 100% trafień zdejmuje Margrave'owi 5091/9000, Furfurowi 4926/10000. Egzekucja to 8% i 7%. Stwory bez bossów mają 5320 życia, zapas daje około 5100–6100.
- Odpoczynek przy czuwającym stworze leczy z 10 do 100 HP i cofa wszystkich.
- Gra nie uczy odbicia, złotego pierścienia, gardy, egzekucji, rally ani bonusów serii.
- Bot, 6 minut: chybienia 0: 3 śmierci, 0,1: 6–8, 0,3: 12–13. Na 185 zabójstw TRIPTYCH 14 razy, TETRAPTYCH 1, POLYPTYCH 0.
- Po przebudzeniu 2 stworów 4 widoczne czekają na posterunkach.
- `--frame-watch` mierzy głównie sklep, stąd zawyżony dowód w ODBIOR 0.40. Po poprawce w kopii: 12/3600 klatek ponad 16,7 ms na spokojnej maszynie. Obok innego procesu 196/3600.
- UI: ucięte „TRIPTY...” i „[ TAB...”; medal zasłaniany przez komunikat i podpowiedź; podpowiedź o flasce przy pustej flasce; brak powodu oczekiwania na unik; stan `trail` w rysowaniu; złoty romb głowy; dwie nazwy broni. Kontrast dolnego paska 7,5–11:1, dobry.
- Powrót z poligonu do menu 1,65–1,72 s (pomiar Astry). 740 MiB tekstur.

Rozstrzygnięcia modeli (nie decyzje właściciela): kolejność napraw według połączeń, bez przepisywania; balans po jednej zmiennej i dopiero po próbie człowieka; kolejkę stworów najpierw przez ustawienie, regułę AI tylko za zgodą.

Otwarte: odczucie strzału, miks dźwięku, trudność dla ludzi, sprzęt odniesienia, jednorazowy błąd `Report was not written by run`, muzyka SKIRMISH po śmierci strażnika, realna siła ładunku Q.

Decyzje do właściciela: D1 czy blokować odpoczynek przy czuwającym stworze; D2 jak zabija się Margrave'a i Furfura (HP, amunicja, zdobywanie amunicji, atak awaryjny); D3 ładunki uniku czy wytrzymałość; D4 czy wszystkie widoczne stwory mają ruszać; D5 co kończy kaplicę; D6 mapa odkrywana czy pełna; D7 ile dusz daje Furfur.

# Plan (szczegóły i kryteria w RAPORT-KONCOWY.md)

Etap 0: R01 ponowienie zapisu; R02 wspólny reset aktora; R03 źródło broni w serii; R04 egzekucja z zasłoną i pionem; R05 liczby HP i wardu; R06 frame-watch i sprostowanie ODBIOR; R07 dusze Furfura (D7); R08 dokumenty wejściowe; R09 złoty romb, stare komentarze, `multikill`, gałęzie `guardianFell`, SHOTGUN/EXORCIST.
Etap 1: G01 ucięte napisy i wielokropek jako błąd audytu; G02 `trail` do widoku; G03 priorytety komunikatów i warunek flaski; G04 powód oczekiwania na unik, kolor odmowy; G05 Q/F, znaki uniku, niskie HP w tych samych niszach; G06 seria przy wierszu broni.
Etap 2: L01 próba właściciela; L02 odpoczynek (D1); L03 model amunicji i HP (D2); L04 nauka; L05 ustawienie stworów (D4); L06 próg nawy; L07 przyczyna śmierci; L08 progi serii; L09 limit uniku (D3).
Etap 3: E01 retry między obszarami; E02 powrót do menu; E03 scenariusz kaplicy i CI; E04 sprzęt odniesienia i odsłuch.
Etap 4: F01 koniec kaplicy (D5); F02 mapa (D6); F03 druga droga.

Zasady łączne: nad sceną najwyżej jeden napis pod celownikiem i jeden komunikat; podpowiedzi poza gorącą walką; czerwień przy celowniku tylko dla zabójstwa, złoto tylko dla gardy; dolny pasek bez zmian kompozycji; balans po jednej zmiennej.

Kryteria odbioru każdego zadania: test albo sonda odtwarzająca problem przed zmianą i przechodząca po niej; `.\BUILD.ps1` zielony; rendery obejrzane dla zmian UI; ZMIANY, ODBIOR i postęp zaktualizowane; commit. Odczucia, dźwięk i trudność zatwierdza właściciel, nie automat.

# Pierwszy krok

1. Sprawdź `git log -1`, `git status` i `src/core/build.lua`. Porównaj z 489e3a5 i commitem audytu. Jeśli Codex lub właściciel coś zmienili, ustal co.
2. Uruchom `.\TEST.ps1 -Suite Architecture`.
3. Pokaż właścicielowi krótko decyzje D1–D7 i zapytaj, czy zatwierdza Etap 0.
4. Po zgodzie zacznij od R01: najpierw test odtwarzający błąd w game/tests/cases/pilgrimage_save.lua, potem naprawa `P.save`, commit, wpis postępu w docs/audyt-2026-11-02/POSTEP.md. Dalej R02 i kolejne po kolei.
