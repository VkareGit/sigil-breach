Kontynuujesz pracę nad grą SIGIL: BREACH po podwójnym audycie z 2026-11-03 (Claude Opus 5.5 + Codex Astra). Rozmawiaj ze mną po polsku. Najpierw przeczytaj ten prompt do końca.

## Projekt i filary

- Repozytorium: `C:\Users\nahiko\Documents\dev\sigil-breach`. Gra w LÖVE 11.5 / LuaJIT (`toolchain\love-11.5-win64`), kod w `game/src`, testy w `game/tests`, QA w `game/qa`, narzędzia w `tools`, skrypty `*.ps1` w katalogu głównym. Wersja 0.42 (`game/src/core/build.lua`).
- FPS, który staje się souls-like: rycerz bez magii, dwie bronie palne (Exorcist — strzelba, Judge — rewolwer), ładunek prochowy Q, flaska F, kaplica z ogniskami, dusze i echo po śmierci, elity Margrave i Furfur (to moby, nie bossowie).
- Trudność ma wynikać z czytania ciosów (telegraf, przytrzymanie, kontra strzałem, doskonały unik, egzekucja), nie z paska HP. Strzał nie bierze wytrzymałości, kosztuje chwilę ciała po strzale. Call of Duty to odniesienie tylko dla potwierdzenia trafienia i nagrody (medale serii). Doom to odniesienie dla znajdziek na mapie.
- Styl: żywy mroczny fresk. Styl demonów, HUD i broni się nie zmienia.

## Moje decyzje (obowiązują)

- **Dolny pasek HUD jest chroniony**: podoba mi się jego design. Nie zmieniaj charakteru, kształtu, kompozycji ani stylu. Wolno poprawiać czytelność treści w istniejących niszach (wielkość, grubość, kontrast, marginesy), a każdą zmianę wyglądu pokaż mi na renderze przed/po do akceptacji. Wariant naruszający design przedstaw osobno jako moją decyzję.
- Bossowie odłożeni. Kaplica to poligon testowy, nie docelowa mapa. Dawny etap 4 (koniec kaplicy, mapa, druga droga) odłożony — nie zaczynaj bez mojej zgody.
- D1: ognisko odmawia odpoczynku z powodem, gdy ściga czuwający stwór. D2: amunicja pochodzi ze stworów (rodzina daje swój rodzaj, egzekucja daje pewny skromny zwrot, rzadka amunicja z trudniejszych). D3: unik ogranicza tylko wytrzymałość. D4: zaalarmowani w otwartej przestrzeni ruszają wszyscy, oddzielone części budzą się grupą, przed wykryciem część patroluje, część stoi. D7: Furfur płaci tyle co Margrave.
- 2 listopada wybrałem: znajdźki jak w Doomie w wariancie „wracają przy odpoczynku i śmierci”, pięć ulepszeń przy ognisku (grawery i hartowanie na broń). Pozostałe zmiany 0.42 (krótkie elity, pieczęcie, ognisko zabezpieczające, odnawianie Judge'a) wprowadzono po analizach modeli; nie oceniłem ich jeszcze w grze.
- Tekst w grze i na nagraniach po angielsku; dokumenty w `game/docs` po polsku.
- Usuwać, nie przenosić (stary kod jest w historii git). Rozmiar pracy nie jest powodem do odkładania. Pracuj do końca zatwierdzonego zakresu, sam weryfikuj (testy, sondy, rendery) i raportuj raz na końcu, bez meldunków w połowie.
- Bez budowania EXE/ZIP. Gram przez `love .`. `BUILD.ps1` tylko testuje; `-Package` dopiero na moją prośbę.
- Grafikę, dźwięk, modele i nagrania robi Codex Astra (`gpt-6-astra`, high/xhigh; do audytów max/ultra). Ty robisz kod gry i walkę.
- Moje spostrzeżenia traktuj jako hipotezy do sprawdzenia: pracujemy razem.

## Zasady pracy w repo

- Commit po każdym punkcie: `git -c user.name=Nahiko -c user.email=psmietanawork@gmail.com commit -F <plik>`; plik wiadomości bez BOM (PowerShell 5.1), na końcu `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. `git add -u` plus nowe pliki z nazwy. **Nigdy `git add game` ani `git add .`**: `game/docs/PORADNIK-EDYCJI-GRY.md` i `docs/podrecznik-codex/` to moje pliki. Bez push.
- Każdy punkt: najpierw test lub sonda, która odtwarza problem, potem zmiana, wpis w `game/docs/ZMIANY.txt` i `game/docs/ODBIOR.txt` (sekcja bieżącej wersji), wpis w `docs/audyt-2026-11-03/POSTEP.md` (utwórz), commit. Commit dopiero przy zielonym `.\TEST.ps1 -Suite All` (poza znanymi FAIL opisanymi w A01).
- Pojedynczy zestaw: `$env:SIGIL_UI_QA_DIR=<katalog>; toolchain\love-11.5-win64\lovec.exe game --suite=<id>` (id w `game/tests/suite.lua`). Rendery: `love.exe game --chapel-look` z `SIGIL_UI_QA_DIR`. Okno z błędem Lua potrafi wisieć bez komunikatu: QA uruchamiaj z ukrytym oknem i czytaj raporty. Sondy bez okna: limity JIT jak w `game/main.lua`.
- Pomiary czasu i długie sondy rób w osobnym klonie, nie równolegle z innymi ciężkimi procesami. Codex może pracować w tym samym repo równolegle: przed zaufaniem dokumentom sprawdź `git log`, `git status` i `build.lua`.
- Nigdy nie zapisuj ani nie powtarzaj tokenów i haseł (raz wkleiłem token Hugging Face — nie szukaj go i nie cytuj).

## Stan i źródła

- Oceniany commit: `f69a19b`. Sprawdź, co doszło od tego czasu (`git log f69a19b..HEAD`), i wracaj do analizy tylko tam, gdzie są zmiany, nowe dowody albo otwarte kwestie. Nie powtarzaj audytu.
- `docs/audyt-2026-11-03/`: `RAPORT-KONCOWY.md` (synteza i pełny plan — przeczytaj w całości), `AUDYT-CLAUDE.md`, `AUDYT-ASTRA.md`, `PROMPT-AUDYTU.md`, `sonda-continue.lua`, `dane-astry/` (wyniki sond Astry: `probe-results.txt`, `combat-probe-results.txt`, `ui-layout-audit.txt`, kody sond).
- Poprzedni audyt i jego realizacja: `docs/audyt-2026-11-02/` (RAPORT-KONCOWY, POSTEP, PROBA-WLASCICIELA). Analizy rozgrywki: `docs/analiza-rozgrywki-2026-11-02/`.
- Klony audytowe (do pomiarów, nie do commitów): `C:\Users\nahiko\Documents\dev\sigil-audit-claude-1103`, `...\sigil-audit-astra-1103`.

## Synteza audytu i status konsultacji z Astrą

Konsultacja odbyła się naprawdę: oba modele dostały ten sam prompt (SHA-256 `CBCA92B8…25B1`), ten sam commit i te same materiały, pracowały w osobnych klonach; Astra na `ultra` (potwierdzone w logu sesji), ok. 36 min, uruchamiała testy, benchmark, frame-watch i sondy. Żaden model nie grał ręcznie i nie słuchał dźwięku. Mój `-Suite All` szedł równolegle z częścią pracy Astry (możliwy wpływ na jej pomiary czasu).

Fundament jest mocny (stały krok, determinizm i powtórki, schematy treści, spójna fizyka 2,5D z jedną grawitacją 18,5, osobne pociski stworów z x/y/z i prędkością, strzały rycerza hitscan, 20 żywych stworów ok. 7,4 ms klatki). Nie przepisywać. Słabe są granice reguł wprowadzonych 2 listopada i bramka QA.

Potwierdzone problemy (dowody w raporcie):
- **QA czerwone na `f69a19b`**: 6 FAIL w Mechanics. 4 nieaktualne asercje (cena Focus 100 → 180 w `tests/suites/interface.lua:119`, brak odnawiania Judge'a w `tests/suites/weapons.lua:226` i `qa/reviews/weapon_timeline.lua:123`, wytrzymałość elit w `tests/cases/enemy_durability.lua:351`); 2 to sygnał projektowy (`souls_gate.lua:59`, `souls_bots.lua:116`: bot stojący i strzelający wygrywa z elitą). Render `look-fire-menu` pokazuje odmowę zamiast menu (`qa/reviews/chapel_look.lua:108`); test trasy liczy paczki z mapy jako drop; bot krąży przy paczkach, których nie podniesie (`qa/souls_bot.lua:174`).
- **Continue = darmowy odpoczynek i farma**: zapis przy wyjściu utrwala portfel, a Continue (`run/pilgrimage.lua` `P.init`: `refresh(g, true)` + `P.populate`) leczy, odnawia zasoby i przywraca zabitych od ostatniego ogniska. Dwie sondy: portfel zostaje, HP 20 → 100, 3/3 zabitych stoi.
- **Odpoczynek przy żywym zagrożeniu**: `fighting` patrzy tylko na ciała; plama trucizny po martwym Buerze rani po przyjętym odpoczynku (100 → 92,8 HP).
- **Znajdźki nie wracają** ani po odpoczynku, ani po śmierci (`secure` → `run.taken`), wbrew mojemu wyborowi; zmienił to późniejszy krok hybrydy `1268d37`.
- **Zegary AI**: `Attacks.rest` (`enemies/actions.lua:205`) dzieli regenerację; odpowiedzi pilne (przeładowanie, picie) czekają ≤ 0,7 s zamiast pełnej regeneracji, zwykły odstęp też się kurczy (cleave 1,2 → 1,1 s, przy małym cooldownie do 0,5 s krócej); reakcja `dodged` nieosiągalna (`enemies/answers.lua:29` vs kolejność w `ai.lua:357`).
- **GUI**: HUD pokazuje grawer drugiej broni (`P.hud` bez `worn`, `ui/hud.lua:184`); teksty obiecują odradzanie przy ognisku (`content/text.lua:148, 282`) i „One is active” (`:171`); „Narthex Fire / NO REST WHILE YOU ARE HUNTED” wychodzi poza ramę w 5 formatach (`ui/hud.lua:522`).
- **Elity za łatwe dla prostych strategii**: 48/48 walk bota wygranych (stanie, cofanie, okrążanie); Margrave pada stojącemu w 13,5 s. Jednocześnie bot w nawie: 12–17 śmierci na 180 s, 0 s z pustymi broniami.
- Wstrząs wybuchu prochu bez zależności od dystansu (`feedback/world_feedback.lua:157`). Pierwsza klatka menu po zimnym starcie ok. 0,92 s (pomiar Astry). Cały dźwięk jest syntezowany w kodzie (`audio/recipes.lua`, 0 plików audio).

Rozstrzygnięcia: ekonomia 1420 dusz na przejście wobec 4759 za katalog to nie błąd, tylko moja decyzja (D8). Elity naprawiać strojeniem ciosów po naprawie zegarów, nie powrotem do gąbek. Nowy atak z laserem odłożony do po strojeniu. Ogniska zostają (rekomendacja obu modeli, nie moja decyzja); wariant bardziej doomowy porównać później na tej samej treści (C02). Moje hipotezy: kite'owanie po prostej nie działa na walczących wręcz (cofanie 3,15 m/s), pociski są celowo do ominięcia zmianą kierunku, i-frames (unik 0,155 s ruchu, 0,32 s ochrony) w normie, soczystość jest w kodzie, ale jej siły nikt nie ocenił.

Otwarte: odczucie strzału/odrzutu/trafienia i miks; trudność nawy dla człowieka; przyczyna zatrzymania F08; decyzje D8, D9, D10.

## Plan (propozycja modeli, NIE zatwierdzona przeze mnie)

Pełne tabele (problem, dowód, zakres, zależności, nakład, ryzyko, kryteria) w `RAPORT-KONCOWY.md`, sekcja 4. Skrót:

Decyzje do mnie: **D8** gdzie żyje rozwój (sklep czy znaleziska w świecie); **D9** co znaczy wyjście z gry w trakcie (wznowienie dokładnie tam / powrót do ogniska bez leczenia i z zachowaniem zabitych); **D10** czy znajdźki wracają przy odpoczynku i śmierci.

- Etap 0 (P1): **A01** zielona brama i prawdziwe testy (4 asercje, render sklepu, test dropu, bot; `souls-gate`/`souls-bots` zostają kryterium B01) → **A05** zegary AI → **A03** bezpieczny odpoczynek → **A06** HUD, teksty, podpowiedź w ramie, audyt szerokości tekstu → **A02** Continue wg D9 → **A04** znajdźki wg D10 → **A07** reguła procesu (commit po zielonym All, jedna zmienna balansu na commit).
- Etap 1: **B01** elity (kryterium: careless/backpedal/orbit nie wygrywają pewnie — ≥1 z 2 ziaren porażka albo <30% HP; learning 3/3 z >70% HP; walka 20–35 s) → **B02** moja próba wg uzupełnionego `PROBA-WLASCICIELA.md` → **B03** sonda zasobów i jedna zmienna → **B04** nawa.
- Etap 2: **C01** ekonomia wg D8; **C02** eksperyment ogniska vs punkt kontrolny; **C03** warstwa broni stwora tylko przy konkretnej mechanice.
- Etap 3: **D01** nagranie bazowe (Codex, od razu); **D02** odsłuch A/B i ewentualne próbkowane warstwy (Codex); **D03** wstrząs prochu z dystansem; **D04** nisza ARSENAL, pasek SHIFT, drobne podpisy (render, moja zgoda); **D05** opcjonalne mikro-zatrzymanie; **D06** zimny start.
- Etap 4 opcjonalnie: **R01** atak z celownikiem-laserem (mój pomysł) po B01/B02; **R02** skalowanie AI > 30 ciał.

## Odbiór i sprawdzanie

- Każdy punkt ma test lub sondę, która była czerwona przed zmianą i jest zielona po niej; `-Suite All` zielone (poza opisanymi wyjątkami A01).
- Zmiany GUI: rendery w 960×540, 1024×768, 1280×720, 1920×810, 1920×1080, audyt układu bez uwag, moja zgoda na wygląd.
- Balans: sonda przed/po (komnaty: `souls_gate`, `souls_bots`; kaplica: przebieg bota 180 s), jedna zmienna na commit.
- Odczucie i dźwięk: tylko moja ocena z nagrania lub gry; nie ogłaszaj „lepiej” bez niej.

## Co przekazywać Codexowi (Astra)

Uruchamianie: `codex exec -m gpt-6-astra -c model_reasoning_effort="high"` (xhigh dla trudniejszych), `--sandbox workspace-write -c windows.sandbox="unelevated"`, w osobnym klonie, z `$env:APPDATA` ustawionym na `<klon>\work\appdata` i istniejącym `work\appdata\LOVE\sigil-breach-qa`; prompt przez `cmd /c "... - < prompt.md"` (polskie znaki), `--json -o last-message.md`. Binarka: ścieżka z `Get-Process codex`. Jeśli LÖVE nie wystartuje w piaskownicy, Codex przygotowuje sceny i `render.ps1`, a Ty uruchamiasz je u siebie. Narzędzia nagrań: `work/film-tools` (`film.lua`, `compose.py`, `transcode.ps1`, `probe.ps1`; MJPEG 4:2:0 → H.264; kopia na telefon < 30 MiB).

Kolejność delegacji: (1) D01 nagranie bazowe — od razu po mojej zgodzie, równolegle z A01; (2) D02 warstwy dźwięku — dopiero po moim odsłuchu; (3) grafika do D04 tylko, jeśli poprawka wymaga malowanych elementów; (4) po Etapie 0 niezależny przegląd zmian przez Astrę (tylko odczyt, max/ultra). Kod gry i walki zostają u Ciebie; nie zlecaj Codexowi zmian w tych samych plikach równolegle.

Gotowa treść pierwszej delegacji (D01):

```
Nagranie bazowe SIGIL: BREACH do oceny "soczystości" walki. Nie zmieniaj kodu gry ani dokumentów w repozytorium; pracuj w osobnym klonie na commicie <HEAD z git log> i zapisuj tylko do work/film-baseline/. Odpowiadaj po polsku, napisy na nagraniu po angielsku.

Cel: właściciel ma ocenić z obrazu odrzut broni, błysk i reakcję stwora na trafienie, wstrząs kamery oraz czytelność zagrożeń, zanim cokolwiek zostanie zmienione. Dźwięk nie jest nagrywany.

Sceny (każda 6-10 s, 1280x720, 30 kl/s, prawdziwy renderer, uczciwa walka: g.testField.invincible = false):
1. Judge: 3 strzały w Ember Thralla z 3 m, potem z 8 m (trafienie w tułów i w głowę).
2. Exorcist: 2 strzały w Ember Thralla z 2 m i z 6 m; zabójstwo.
3. Exorcist w opancerzonego (trafienie w pancerz) i pęknięta garda (złote narożniki, zatrzymanie świata).
4. Ładunek Q: wybuch 2 m od rycerza i 10 m od rycerza (porównanie wstrząsu).
5. Margrave: jedna seria ciosów z telegrafem, unik zwykły i doskonały, kontra strzałem.
6. Stolas: gwiazda i salwa trzech gwiazd lecące na rycerza, zejście z linii.

Narzędzia: work/film-tools (film.lua jako game/qa/reviews/film.lua w klonie, --film w qa/runtime.lua, compose.py, transcode.ps1, probe.ps1; MJPEG z subsampling=2, potem H.264). Podpisy krótkie, angielskie, nazwa sceny i co się dzieje.

Wynik: work/film-baseline/baseline.mp4 (i kopia < 30 MiB na telefon), 3 klatki kontrolne na scenę jako PNG, oraz README.md po polsku: lista scen z czasem w nagraniu, commit, rozdzielczość, czego nie udało się nagrać i dlaczego. Sprawdź zdekodowane klatki z MP4 (kolory). Nie oceniaj jakości efektów, tylko je pokaż.
```

## Pierwszy krok

1. Sprawdź `git log f69a19b..HEAD` i `git status`; jeśli coś doszło, oceń, czy dotyka punktów planu.
2. Uruchom `.\TEST.ps1 -Suite All` i potwierdź te same 6 FAIL (albo opisz różnicę).
3. Napisz mi krótko (5–8 zdań): stan, Etap 0 do zatwierdzenia, pytania D9 i D10 (z rekomendacją), prośba o zgodę na delegację D01.
4. Po mojej zgodzie: uruchom D01 w tle (Codex, osobny klon) i zacznij A01. Dalej według kolejności planu, punkt po punkcie z commitem i wpisem w `POSTEP.md`, do końca zatwierdzonego zakresu.
