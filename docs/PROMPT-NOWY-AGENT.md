Przejmujesz pracę nad grą SIGIL: BREACH. Ten prompt jest taki sam dla Claude Code i dla Codexa. Rozmawiaj ze mną po polsku. Przeczytaj go do końca, zanim cokolwiek zmienisz.

## Gdzie jest projekt

- Jedyne repozytorium robocze: `C:\Users\nahiko\Documents\dev\sigil-breach` (gałąź `main`, bez zdalnego push). Inne foldery w `C:\Users\nahiko\Documents\dev` (`sigil`, `sigil-the-descent`, `test`, `git-server`, `doom-c`, `techradar`) nie są częścią tej pracy: nie ruszaj ich.
- Gra w LÖVE 11.5 / LuaJIT: `toolchain\love-11.5-win64\love.exe` (gra) i `lovec.exe` (testy z konsolą). Kod `game/src`, treść i strojenie `game/src/content` (`tuning.lua`, `combat_defaults.lua`, `creatures/*.lua`), testy `game/tests` (rejestr `game/tests/suite.lua`), QA `game/qa`, narzędzia `tools`, skrypty `TEST.ps1`, `FORMAT.ps1`, `BUILD.ps1` w katalogu głównym. Wersja w `game/src/core/build.lua` (0.44 w chwili pisania).
- Najpierw przeczytaj: `START-HERE.txt`, `game/docs/INSTRUKCJA.txt` (rozdział KAPLICA), `game/docs/DEVELOPMENT.txt` (zasady testów), górne sekcje `game/docs/ZMIANY.txt` i `game/docs/ODBIOR.txt`, a potem `docs/audyt-2026-11-03/`: `DECYZJE.md` (moje decyzje), `POSTEP.md` (co zrobiono, z dowodami), `RAPORT-KONCOWY.md` (audyt i plan), `V01-ASTRA.md` (obraz, kontrast i odczucie strzału), `RAPORT-ASTRY-044.md` (ostatnia zmiana). Starsze: `docs/audyt-2026-11-02/`, `docs/analiza-rozgrywki-2026-11-02/`.
- `game/docs/PORADNIK-EDYCJI-GRY.md` i `docs/podrecznik-codex/` to moje pliki, nieśledzone. Nie dodawaj ich do commitów i nie zmieniaj.

## Czym jest gra i do czego dążymy

- FPS, który staje się souls-like. Rycerz bez magii, dwie bronie palne (Exorcist to strzelba, Judge to rewolwer), ładunek prochowy Q, flaska F (picie ok. 0,95 s, ma własną animację rąk od 0.44), unik z wytrzymałością, kaplica z ogniskami, dusze i echo po śmierci. Elity Margrave i Furfur są mobami, nie bossami.
- Trudność ma wynikać z czytania ciosów (telegraf, przytrzymanie, kontra strzałem, doskonały unik, pęknięta garda i egzekucja), nie z paska HP. Strzał nie zużywa wytrzymałości, ale po nim ciało potrzebuje chwili.
- Odniesienia: Doom dla znajdziek na mapie i tempa, Dark Souls dla walki i ognisk, Call of Duty tylko dla potwierdzenia trafienia i nagrody (medale serii).
- Styl to żywy mroczny fresk. Nie zmieniaj stylu demonów, HUD ani broni. Odczucie strzału i trafienia jest dla mnie jedną z najważniejszych rzeczy: strzał musi wyraźnie trafiać albo wyraźnie chybiać.
- Kaplica jest poligonem, nie docelową mapą. Bossowie i dawny etap 4 (koniec kaplicy, mapa, druga droga) są odłożeni do mojej zgody.

## Moje decyzje (obowiązują)

- **Dolny pasek HUD jest chroniony** (kształt, kompozycja, styl). Wolno poprawiać czytelność treści w istniejących niszach. Każdą zmianę wyglądu pokaż mi na renderze przed/po (960×540, 1024×768, 1280×720, 1920×810, 1920×1080), zanim uznasz ją za przyjętą.
- Znacznik trafienia zmniejszałem dwa razy: cztery cienkie kreski 4–8 px, zabójstwo zgaszoną czerwienią. Nie powiększaj go i nie wracaj do dużego X.
- Nie zmieniaj zegarów SI dla odczucia. Wstrzymanie stworów przy trafieniu (D05) złamało `creature-pressure` i zostało wycofane. Odczucie poprawiaj obrazem i dźwiękiem.
- D1: ognisko odmawia odpoczynku z podaniem powodu, gdy ściga cię czuwający stwór. D2: amunicja pochodzi ze stworów (rodzina daje swój rodzaj, egzekucja pewny skromny zwrot, rzadka amunicja z trudniejszych). D3: unik ogranicza tylko wytrzymałość. D4: zaalarmowani w otwartej przestrzeni ruszają wszyscy, oddzielone części budzą się grupą, przed wykryciem część patroluje, część stoi. D7: Furfur płaci tyle co Margrave.
- D8: pieczęcie i grawery znajduje się w świecie (relikwie). Za dusze kupuje się śluby, wycenione na ok. 1420 dusz na przejście. D9: Continue wznawia grę dokładnie tam, gdzie była, z HP, amunicją i flaską, bez kasowania alarmu. D10: znajdźki nie wracają po odpoczynku (jak w Doomie, bo stwory się nie odradzają); po śmierci wraca tylko to, co zabrano od ostatniego ogniska.
- Elity: walka 20–35 s dla dobrego gracza, stanie w miejscu i strzelanie nie może być pewną strategią. Regularne wygrywanie z 20% HP oznacza, że działa.
- Ogniska zostają. Kluczowe są ich rozmieszczenie i wpływ na tempo. Wariant bez ognisk (C02) tylko po mojej próbie.
- Tekst w grze i na obrazach po angielsku. Dokumenty w `game/docs` po polsku.
- Bez budowania EXE/ZIP: gram przez `love .`, `BUILD.ps1` tylko testuje, `-Package` dopiero na moją prośbę. Bez nagrań wideo, chyba że o nie poproszę.
- Moje spostrzeżenia traktuj jako hipotezy do sprawdzenia (sonda, pomiar). Pracujemy razem.

## Jak pracować

- Pracuj do końca zatwierdzonego zakresu, sam weryfikuj (testy, sondy, rendery, boty) i raportuj raz, na końcu, bez meldunków w połowie. Rozmiar pracy nie jest powodem do odkładania. Pytaj tylko o decyzje, które naprawdę należą do mnie, i zbierz je na początku.
- Każdy punkt: najpierw test albo sonda, które odtwarzają problem (czerwone przed zmianą), potem zmiana, wpis w sekcji bieżącej wersji `game/docs/ZMIANY.txt` i `game/docs/ODBIOR.txt` (`BUILD.ps1` odmawia, gdy sekcji brakuje), wpis w `POSTEP.md` bieżącego planu, commit. Jedna zmiana balansu na commit, z sondą przed/po (`souls-gate`, `souls-bots`, przebieg bota w kaplicy).
- Commit tylko przy zielonym `.\TEST.ps1 -Suite All -TestTimeoutSeconds 1800`. Długi limit jest potrzebny dla showcase. Wpisy `FAIL second`, `fourth`, `failure` to celowe próby raportera. `hazard-art` uruchomiony osobno nie przechodzi, także przed zmianami. Pojedynczy zestaw: `$env:SIGIL_UI_QA_DIR=<katalog>; toolchain\love-11.5-win64\lovec.exe game --suite=<id>`. Formatowanie `.\FORMAT.ps1` (stylua). Brama architektury `.\TEST.ps1 -Suite Architecture`: liczby w kodzie symulacji tylko jako nazwane wartości w `content/tuning.lua` lub `content/combat_defaults.lua`; pola magazynka tylko przez model amunicji; brak zależności `session` → `run`; słowa typu obrażeń (np. `fire`) w kodzie są wykrywane.
- Złoty wzorzec: zmiana celowo zmieniająca symulację wymaga dwóch identycznych przebiegów `--suite=golden` i skopiowania wartości z `golden-current.lua` do `game/tests/golden/baseline.lua`, z komentarzem dlaczego. Zmiana tylko obrazu i dźwięku nie może go zmienić.
- Commit: `git -c user.name=Nahiko -c user.email=psmietanawork@gmail.com commit -F <plik>`. Plik wiadomości UTF-8 bez BOM (PowerShell 5.1 ma domyślnie inne kodowanie). Styl wiadomości: `fix: …`/`docs: …`, zdanie po angielsku, w treści co i dlaczego. Dodawaj `git add -u` oraz nowe pliki po nazwie. **Nigdy `git add game` ani `git add .`.** Bez push.
- Pliki `game/docs/*.txt` mają końce linii CRLF: zachowaj CRLF i UTF-8 bez BOM. W PowerShell 5.1 czytaj przez `[IO.File]::ReadAllText` (`Get-Content -Raw` psuje UTF-8), a do zmian używaj edytora plików, nie `.Replace` z `` `n ``. Łatki przenoś przez `git diff --binary --output=<plik>` i `git apply` (przekierowanie `>` daje UTF-16).
- Okno LÖVE z błędem Lua potrafi wisieć bez komunikatu. QA uruchamiaj z ukrytym oknem i czytaj raporty. Raport sprzed zmian po przekroczeniu czasu oznacza błąd startu.
- Pomiary czasu i długie sondy rób w osobnym klonie (`git clone` repozytorium do `C:\Users\nahiko\Documents\dev\sigil-<cel>`), nie obok innych ciężkich procesów; tłum 256 ciał waha się 34–45 ms. Po skończeniu usuń klon. Inny agent może pracować równolegle: przed zaufaniem dokumentom sprawdź `git log`, `git status` i `build.lua`.
- Usuwaj, nie przenoś: stary kod jest w historii git. Komentarze pisz zdaniami po angielsku, w stylu otaczającego kodu.
- Nigdy nie zapisuj ani nie powtarzaj tokenów i haseł. Raz wkleiłem token Hugging Face: nie szukaj go i nie cytuj.

## Podział ról między Claude a Codex

- Claude: kod gry, walka, SI, reguły, testy, przegląd zmian Codexa i przeniesienie ich do `main`.
- Codex Astra (`gpt-6-astra`; high/xhigh do pracy, max/ultra do audytów i dużych zmian): grafika, dźwięk, nowe modele i klatki, niezależne audyty i przeglądy. Pracuje w osobnym klonie, bez commitów; Claude przegląda diff, puszcza pełne testy i robi commity.
- Uruchomienie z Claude: `codex exec -m gpt-6-astra -c model_reasoning_effort="ultra" --sandbox workspace-write -c windows.sandbox="unelevated" -C <klon> --json -o last-message.md - < BRIEF.md` (przez `cmd /c`, ze względu na polskie znaki), z `$env:APPDATA=<klon>\work\appdata` i istniejącym `work\appdata\LOVE\sigil-breach-qa`. Binarka: `C:\Users\nahiko\AppData\Local\OpenAI\Codex\bin\<wersja>\codex.exe` (ścieżkę daje `Get-Process codex`). Poziom wysiłku potwierdzisz w `~/.codex/sessions/.../rollout-*.jsonl` (`turn_context`, `"effort"`). Postęp na żywo: `Get-Content <klon>\work\<zadanie>\codex.jsonl -Wait -Tail 20`.
- Jeśli jesteś Codexem: kod gry też możesz zmieniać, gdy dostaniesz takie zadanie, ale z tymi samymi zasadami testów i commitów. Grafikę tworzysz swoim narzędziem obrazów, z kolorem klucza do przezroczystości, dopasowaną do istniejących malowanych arkuszy; maski anatomii muszą nadal pasować (`anatomy-data`, `hit-landmarks`, `painted-surfaces`).
- Nie zlecaj dwóm agentom równoległej pracy na tych samych plikach.

## Stan (0.44) i co jest otwarte

- Zrobione w 0.43: zielona brama QA, zegary SI, bezpieczny odpoczynek, Continue według D9, relikwie i śluby według D8, znajdźki według D10, elity przestrojone (B01), atak z laserem Stolasa (R01), próbkowane dźwięki z przełącznikiem F7 do A/B, wstrząs prochu zależny od dystansu, nisza ARSENAL, chwianie odsłoniętej elity. W 0.44 (Astra, przegląd Claude): wyraźniejsze trafienie (błysk 80 ms, ciemniejszy podkład znacznika, punkt kontaktu na rzeczywistym promieniu, ślad pudła na ścianie), dłuższa poza strzału Exorcista, jaśniejsza druga broń w ARSENAL, kościany rdzeń promienia Stolasa, nowy Judge IRON, animacja picia z flaski. Sonda nie znalazła prawdziwych pudeł: 576 salw, wszystkie trafiły ciało. Śruciny poza ciałem to rozrzut.
- Czeka na moją ocenę w grze: czytelność trafienia, ręka z flaską, rdzeń promienia (wygląda płasko: możliwy powrót do starego pola), dźwięk Judge IRON, wybór zestawu dźwięków (potem usunąć F7), wynik mojej próby B02 (elity, nawa, Continue, relikwie).
- Otwarte technicznie: kontrast Iron Thralla w nawie (cel ≥1,5:1, warianty Astry odrzucone, bo naruszały styl); B03 sonda zasobów i B04 nawa (po mojej próbie); niezabezpieczeni zabici w innych obszarach (rozwiązać przed dodaniem obszarów); boty nawyku i półczytania nadal wygrywają z elitami (ocenię w próbie); C02 tylko po próbie; mikro-zatrzymanie tylko w wersji wizualnej, jeśli trafienie nadal będzie słabo czytelne.

## Pierwszy krok

1. Sprawdź `git log -15`, `git status` i `game/src/core/build.lua`. Przeczytaj `POSTEP.md` i górne sekcje `ZMIANY.txt`.
2. Uruchom `.\TEST.ps1 -Suite All -TestTimeoutSeconds 1800` i potwierdź, że brama jest zielona (albo opisz różnicę).
3. Napisz mi krótko (5–8 zdań): stan, co według Ciebie jest następne, i pytania o decyzje, które należą do mnie (z rekomendacją). Potem pracuj według odpowiedzi, punkt po punkcie, do końca zakresu.
