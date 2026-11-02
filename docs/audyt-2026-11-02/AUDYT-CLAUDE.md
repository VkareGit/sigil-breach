# Audyt Claude: SIGIL: BREACH, commit 489e3a5 (0.41)

Spisany przed przeczytaniem wyniku Astry. Wyniki na końcu pochodzą z kopii roboczej, kod gry nie został zmieniony.

Legenda pewności: **P** potwierdzone uruchomieniem albo pomiarem, **K** potwierdzone w kodzie, **H** hipoteza, **D** preferencja projektowa.

## 1. Stan projektu i filary

Główna pętla (kod i INSTRUKCJA): rycerz idzie od ogniska do ogniska przez jedną kaplicę (mapa `proving`, 15 stworów, 4 ogniska, 2 drzwi), strzela z dwóch broni, zbiera dusze, ginie, odzyskuje dusze z echa, kupuje śluby i grawery. Odpoczynek leczy, napełnia i wskrzesza stwory.

Decyzje właściciela: lista w prompcie. Moje interpretacje: gra ma być „Souls z bronią palną”: odczyt ciosu i wiedza mają znaczyć więcej niż refleks (PLAN-SOULS-v13, „wyzwanie to wiedza, nie ruch”). Doom nie występuje w planach jako świadome odniesienie, tylko jako ogólne tempo FPS; ruch rycerza (dwa ładunki uniku, ślizg, skok) to pozostałość tej warstwy.

Niepewne i nieblokujące: czy gra ma mieć koniec przed bossami, czy mapa ma ujawniać stwory, jaką trudność ma mieć pierwsza nawa.

Stan po poprzednim audycie: naprawy zgadzają się tam, gdzie sprawdziłem w kodzie: walidacja zapisu i kopie (`run/pilgrimage.lua:176`, `:636`), brak zapisu przy zabójstwie (`:357`), zapis echa i podróży (`:377`, `:309`), niezależny od dysku start powtórki (`:130`), rejestr trybów, obszary i sloty. Punktów 9 i 12 starego audytu Codexa (klucz `×100`, blokady narzędzi) nie sprawdzałem ponownie.

## 2. Ocena krótka

Technicznie zdrowo, a jako gra to jeszcze szkic pętli. Fundament jest lepszy niż zawartość. Największe ryzyko nie leży dziś w kodzie, tylko w tym, że elementy Souls nie zamykają się w pętlę: amunicja nie wystarcza na najtwardsze ciała, kluczowe mechaniki nie są nigdzie wyjaśnione, ognisko działa jako darmowa ucieczka z walki, a pierwsza nawa jest bardzo stromym progiem.

## 3. Mocne strony do zachowania

- Determinizm, dziennik, złoty wzorzec, 5780 sprawdzeń i ratchety `tools/check` (0 uwag).
- Oprawa: fresk, dolny pasek. Kontrast pisma na pasku zmierzony na zrzucie to 7,5–11:1.
- Czytanie ciosu: złoty pierścień okna odbicia (`render/passes/enemy_marks.lua:42`), pierścień lądowania skoku, łuki kierunku trafień.
- Stwory karzą nawyk: `answers` przy przeładowaniu i piciu (`content/creatures/imp.lua:35`).
- Bufor wejścia z powodem odmowy (`player/intent.lua`).
- Wydajność przy 15 ciałach: w prawdziwej grze 12 z 3600 klatek ponad 16,7 ms, p99 13,9 ms (patrz P9).

## 4. Ustalenia

### Błędy potwierdzone

| ID | Ustalenie | Dowód | Pewność |
|---|---|---|---|
| E1 | Nazwa serii w niszy ARSENAL jest ucięta: „TRIPTY...”. Dotyczy też TETRAPTYCH i POLYPTYCH | `ui/hud.lua:144` szerokość 90 przy czcionce 12; `look-chain.png` | P |
| E2 | Na mapie ucięty przycisk: „BACK TO COMBAT [ TAB...” | `look-map.png` | P |
| E3 | HEALTH i WARD pokazują surowe punkty z `%`. Po ślubie zdrowia będzie „130%”. Pasek wardu dzieli przez stałe 100, więc pełny ward 40 wygląda na 40% paska | `ui/hud.lua:136`, `:168-169`, `content/knight.lua:9` | K |
| E4 | Furfur daje 0 dusz, Margrave 1500. Najtwardszy stwór gry nie ma nagrody | sonda: `souls 0` dla furfur | P |
| E5 | `--frame-watch` przez większość czasu mierzył sklep: bot wchodzi do menu ognia w klatce 445 i nikt go nie zamyka. Dowód „minuty walki” z ODBIOR 0.40 był zawyżony | `qa/reviews/frame_watch.lua:109`, `WORST ... shop`, tylko 4 strzały | P |
| E6 | Romb głowy jest złoty, choć zasada mówi „złoto to pęknięta garda”, a plan „biały X i romb”. Komentarz nad `aimMarks` nadal mówi, że celownik czerwienieje | `ui/hud.lua:304`, `:308` | K |
| E7 | Podpowiedź „Drink from the flask” stoi cały czas przy niskim zdrowiu, także gdy flaska jest pusta | `ui/hud.lua:496` | K |
| E8 | Medal zajmuje y 84–205, a komunikat 91–137 i podpowiedź 139–185. Rysowane później panele przykrywają medal | `ui/hud.lua:463-466`, `:485`, `:502`, `ui/layout.lua:19-20` | K |
| E9 | `e.guardianFell` nikt nie ustawia, a `Encounter.guardianFell` nikt nie wywołuje. Napis „Return to the gate and press E” jest martwy. W SKIRMISH strażnik nigdy nie będzie martwy dla muzyki | `feedback/listeners.lua:73,106`, `session/encounter.lua:39`, `audio/soundscape.lua:275` | K (skutek w muzyce H) |
| E10 | Martwy przepis `multikill` | skan przepisów | K |
| E11 | Sklep mówi SHOTGUN, HUD EXORCIST: ta sama broń pod dwiema nazwami | `look-fire-menu.png` | P |
| E12 | Dokumenty wejściowe kłamią: START-HERE to 0.33 i `work/qa-v33`, KONTEKST 0.33/0.36, INSTRUKCJA ma sprzeczne okna (0,12 s i 0,35 s) i „zachwiany rycerz nie strzela” | `START-HERE.txt:1,44`, `INSTRUKCJA.txt:21,58,67` | P |

### Mechanika i odbiór

| ID | Ustalenie | Dowód | Pewność |
|---|---|---|---|
| M1 | Amunicji z ogniska nie wystarcza na najtwardsze ciała. Nieśmiertelny rycerz z idealnym celem wystrzeliwuje wszystko i zdejmuje Margrave'owi 57%, Furfurowi 50%. Reszta to minimum 6 odbić zakończonych egzekucją (8% i 7% życia). Bez nabojów rycerz ma tylko 3 ładunki Q, walki wręcz nie ma. Stwory bez bossów mają razem 5320 życia, a cały zapas to około 6100 obrażeń przy 100% trafień | sonda `feasible`; `boss.lua`, `furfur.lua`, `pilgrimage.lua:26` | P |
| M2 | Odpoczynek działa w środku walki: rycerz 10 HP, obok czuwający stwór, [E] daje 100 HP i cofa wszystkich na posterunki. Rycerz biegnie 5,25 m/s, szybciej niż każdy stwór (najszybszy 5,0), więc ognisko to darmowa ucieczka | sonda; `run/pilgrimage.lua:274`, `content/knight.lua:60` | P |
| M3 | Próg nawy jest bardzo stromy i czuły na celność. Bot: chybienia 0: 3 śmierci na 6 min, sanktuarium po 137–188 s. Chybienia 0,1: 6–8 śmierci, 1 z 2 przebiegów dochodzi po 327 s. Chybienia 0,3: 12–13 śmierci, 0 z 2 dochodzi. Prawie wszystkie zgony przed pierwszym celem | sonda bota (nie człowiek: nie cofa się, nie używa ognisk taktycznie) | P dla bota, H dla gracza |
| M4 | Niczego z rdzenia Souls gra nie uczy: odbicie strzałem, złoty pierścień, pasek gardy, egzekucja, rally i bonusy serii nie występują w pomocy ani w podpowiedziach. Podpowiedź startowa to tylko WASD, SHIFT, CTRL, SPACJA | `content/text.lua:121-130,399`, `look-help.png` | K |
| M5 | Bez kosztu strzału wytrzymałość wydaje tylko unik, który i tak ma dwa ładunki z odnową 0,78 s. To dwa limity na jedną akcję i dwa różne komunikaty odmowy | `content/knight.lua:57,72`, `player/intent.lua:39-46` | K |
| M6 | Górne szczeble serii są prawie nieosiągalne: w 4 przebiegach bota i około 185 zabójstwach TETRAPTYCH raz, POLYPTYCH nigdy. Leczenie, o które prosił właściciel, praktycznie nie działa przy 15 ciałach i limicie dwóch naraz | sonda `chains` | P dla bota |
| M7 | Skarga „widzę moby, a one czekają” jest załatwiona połowicznie: `seenPack=2`, trzeci i kolejni stoją na widoku. Test wręcz tego wymaga („a third waits its turn”) | `enemies/ai.lua:202-207`, `tests/cases/responsiveness.lua:177` | K |
| M8 | Gra nie ma celu końcowego. Po ogniskach nic się nie dzieje. To znana konsekwencja odłożenia bossów, ale gracz o niej nie wie | `INSTRUKCJA.txt:26` | K |
| M9 | Mapa od początku pokazuje cały układ i pozycje wszystkich stworów. To osłabia zwiedzanie i naukę | `look-map.png` | P, ocena D |
| M10 | Ekran śmierci nie mówi, co zabiło. Pokazuje czas i liczniki | `look-dead.png` | P |
| M11 | Pierwszy odpoczynek otwiera pełny ekran MERCHANT z 0 dusz; menu główne eksponuje PROVING GROUND i SKIRMISH obok głównej gry | `look-fire-menu.png`, `look-menu.png` | P, ocena D |

Działa dobrze razem: odbicie, odsłonięcie i egzekucja z bezpiecznymi klatkami; rally z agresją; przeładowanie pod presją `answers`; dusze w echu. Spięcie z Call of Duty jest zdrowe, dopóki dotyczy potwierdzeń. Konflikt: warstwa FPS (ładunki uniku, ślizg, szybki bieg) rozbraja koszt pozycji, a gąbczaste HP najtwardszych ciał przy rzadkiej amunicji to nie Souls, tylko wyścig zasobów.

### GUI

Dolny pasek ma dobry kontrast i kompozycję. Problem to nie pismo, tylko waga informacji.

| ID | Problem → sytuacja gracza → poprawka → efekt → sprawdzenie |
|---|---|
| G1 | Licznik flaski i Q to najmniejsze pismo (11 px), choć to decyzja życia i śmierci → w walce gracz nie widzi, czy ma łyk → powiększyć cyfrę liczby użyć, nazwy zostają małe, w tej samej niszy → odczyt jednym spojrzeniem → zrzut 1280×720 i 960×540, audyt układu bez uwag |
| G2 | „Q BLAST” i „F FLASK” dotykają lewej krawędzi niszy, a „3” kolumny po prawej → tekst wchodzi w ornament → odsunąć o 4–6 px, zwęzić zakres → czysta nisza, zgodna z zasadą „tusz we wnętrzu planszy” → zrzut, `ui-layout-audit` |
| G3 | Ładunki uniku to pasek 2×20 px przy słowie SHIFT → gracz nie wie, czy ma unik → dwa większe znaki w tej samej linii, bez zmiany niszy → pewność przed unikiem → zrzut, test oczu |
| G4 | E1: nazwa serii ucięta → gracz nie czyta nagrody → użyć całej szerokości niszy pod pieczęcią albo samej pieczęci z paskiem czasu → cicha, pełna informacja → zrzut każdej serii |
| G5 | E3: procenty, które nie są procentami → po ślubach gra pokazuje bzdurę → liczba bez `%` albo prawdziwy udział, pasek wardu wobec `maxArmor` → zgodność → test z ślubami |
| G6 | Niskie zdrowie ma prawie ten sam kolor co zwykłe (`red` i `wound`) → brak sygnału na pasku → ciemniejszy lub pulsujący kolor tylko liczby, bez ruszania paska → szybszy sygnał → zrzut przy 20 HP |
| G7 | Czerwony napis odmowy ma kontrast 4,3:1 na scenie i ten sam kolor co znak zabójstwa → gubi się i łamie zasadę kolorów → ten sam napis w kości słoniowej z czarnym tuszem → czytelność i czystość języka kolorów → zrzuty na jasnym i ciemnym tle |
| G8 | E8: medal pod panelem → nagroda znika → panel komunikatu niżej lub ukryty na czas medalu → brak nakładania → test geometrii |
| G9 | Minimalne okno 960×540 daje z czcionki 11 piksele 8 → drobne nazwy tracą szeryfy → G1–G3 rozwiązują najgorsze, reszta bez zmian → zrzut w 960×540 |

Wymaga decyzji właściciela, bo dotyka chronionego paska: stałe zastąpienie DEATHS przez pasek celu serii, dodanie osobnej niszy na unik.

## 5. Kod i skalowalność

Skalowalność wydajnościowa: wystarcza z zapasem do obecnej skali. Czasy: 12 z 3600 klatek ponad 16,7 ms na spokojnej maszynie, 196 z 3600 gdy obok działał inny proces, czyli pomiar jest wrażliwy. Pojedyncze skoki to leniwe ładowanie liternictwa przy pierwszym sklepie (24 ms, `render/resources.lua:108`) i pieczęci (1,8 ms). Klatka 1 ma 100 ms.

Skalowalność treści: nowa broń i stwór mają rejestry, schematy i CHECK-CREATURE, a nowy obszar ma `P.problems`. Najdroższa jest mapa: `proving_halls.lua` to ręczny kod, zestaw `render/kit/chapel` jest związany z tym stylem, a nowy obszar wymaga mapy, zestawu i malarstwa. Boss to 666 linii danych.

| ID | Ustalenie | Dowód | Pewność |
|---|---|---|---|
| T1 | Dwa zestawy reguł: `Capabilities.attrition` w 7 plikach. Poligon gra inaczej niż kaplica, a tylko 6 ze 146 przypadków testowych nazywa kaplicę | skan | K |
| T2 | CI uruchamia wyłącznie Architekturę. 5780 sprawdzeń działa tylko lokalnie, pełny BUILD trwa około 13 min | `.github/workflows/checks.yml` | K |
| T3 | Jeden nieodtworzony błąd narzędzia: `TEST.ps1` zgłosił „Report was not written by run” po kilkunastu sekundach, a kolejne przebiegi przeszły. Przyczyny nie znam | wynik z tej sesji | P objaw, H przyczyna |
| T4 | Stan rysowania w module HUD (`trail`, `love.timer` w rysowaniu). Nieszkodliwe dziś, ale nieobjęte testem i mieszane z rysowaniem | `ui/hud.lua:346-361` | K |
| T5 | Długie funkcje: `Reader.decode` 232, `Journal.record` 185, `R.new` 145, `Chapel.build` 145. Nie boli, to dane lub sekwencje | skan | K, D |

Nie proponuję przepisywania niczego.

## 6. Najważniejsze ryzyka

Doświadczenie: M1, M2, M3, M4 razem. Gracz może utknąć z pustą bronią przed stworem, którego nie da się zabić bez wiedzy, której gra nie przekazuje.

Technika: T1 (testy i gra rozjeżdżają się), E5 (fałszywa pewność z pomiaru), E12 (nowy agent czyta nieaktualne dokumenty).

## 7. Plan

Priorytety: P0 konieczne naprawy, P1 usprawnienia, P2 rozwój. Nakład: S mały, M średni, L duży.

| ID | P | Problem i dowód | Zmiana i zakres | Korzyść | Zależy od | Nakład / regresja | Kryterium ukończenia |
|---|---|---|---|---|---|---|---|
| A1 | P0 | E5 | `closeShop` w `frame_watch`, poprawić wpis w ODBIOR | prawdziwy dowód | – | S / niskie | raport pokazuje ponad 40 strzałów, 0 klatek w sklepie |
| A2 | P0 | E1, E2, E6, E7, E8, E10, E11 | drobne poprawki HUD i tekstów | czystość, brak uciętych słów | – | S / niskie | zrzuty, nowy test uciętych napisów w audycie układu |
| A3 | P0 | E3 | liczby i paski wobec maksimum | prawda na pasku | – | S / niskie | test ze ślubami 3/3 |
| A4 | P0 | E4 | dusze Furfura | nagroda | decyzja o wartości | S / niskie | sonda: dusze > 0 |
| A5 | P0 | M2 | decyzja i blokada odpoczynku przy czuwającym stworze | ognisko bezpieczne, nie teleport | decyzja D1 | S / średnie (bot, testy) | test: odpoczynek odmawia i mówi dlaczego |
| A6 | P0 | E12 | aktualizacja START-HERE, KONTEKST, INSTRUKCJA | nowy agent nie błądzi | – | S / brak | zgodność z build.lua |
| B1 | P1 | M1 | model ognia i amunicji: decyzja, potem liczby (zapas, HP najtwardszych, ewentualny awaryjny atak) | walka do wygrania | D2 | M / wysokie | sonda `feasible`: wykonalne przy zadanym poziomie trafień; bot; ocena właściciela |
| B2 | P1 | M4 | nauka: krótkie podpowiedzi przy pierwszym pierścieniu, pierwszym odsłonięciu, pierwszej serii, strona pomocy o walce | Souls da się zrozumieć | – | M / niskie | każda mechanika ma tekst, test kontraktu, ocena nowego gracza |
| B3 | P1 | M3 | krzywa nawy: rozstawienie i tempo, bez ruszania modeli | uczciwy pierwszy próg | B1, B2 | M / średnie | bot 0,1 dochodzi w większości prób; ocena gracza |
| B4 | P1 | M5 | decyzja: usunąć ładunki uniku albo wytrzymałość | jedna reguła | D3 | M / wysokie (golden, boty) | jeden limit, jeden komunikat |
| B5 | P1 | M7 | decyzja o `seenPack` lub stworach, które się ruszają, ale nie szarżują | spełnienie skargi | D4 | S–M / średnie | test i ocena właściciela |
| B6 | P1 | M6 | progi serii pod rzeczywistą gęstość | nagroda osiągalna | B3 | S / niskie | bot: POLYPTYCH osiągalny przy dobrej grze |
| B7 | P1 | M10 | linia na ekranie śmierci: co zadało ostatni cios | zrozumienie porażki | – | S / niskie | test tekstu, zrzut |
| B8 | P1 | G1–G3, G6, G7, G9 | czytelność paska bez zmiany designu | szybki odczyt | A2 | S–M / niskie | zrzuty 1280×720 i 960×540, zgoda właściciela |
| B9 | P1 | T1, T2 | testy kaplicy: scenariusz walki bez GPU, jeśli się da, i mechanika w CI | mniej regresji | – | M / niskie | CI uruchamia selftest albo jest udokumentowane, dlaczego nie |
| B10 | P1 | T3 | zdiagnozować błąd raportu | zaufanie do narzędzi | – | S / niskie | powtórzenie albo wyjaśnienie |
| C1 | P2 | M8 | koniec pętli bez bossów: zamknięcie kaplicy, napis, statystyka | gra się kończy | D5 | M | ocena właściciela |
| C2 | P2 | M9 | mapa odkrywana, bez stworów | zwiedzanie | D6 | S–M | decyzja, zrzut |
| C3 | P2 | E9 | usunąć martwe gałęzie strażnika albo SKIRMISH | mniej kodu | decyzja | S | skan czysty |
| C4 | P2 | T4, T5 | porządki tylko przy okazji | czytelność | – | S | bez zmian w złotym wzorcu |
| C5 | P2 | treść | drugi obszar, dopiero po B1–B3 | rozwój | B | L | `P.problems` czyste, bot przechodzi |

Decyzje właściciela: D1 odpoczynek w walce, D2 model amunicji i HP, D3 ładunki czy wytrzymałość, D4 stwory na widoku, D5 koniec gry, D6 mapa.

## 8. Ograniczenia

- Nikt nie grał ręcznie. Bot nie zastępuje człowieka: nie wie, jak gracz odbiera grę, i nie odczytuje pierścieni tak jak człowiek.
- Dźwięku nie słyszałem. Nie oceniam brzmienia ani głośności.
- Oglądałem zrzuty, nie ruch. Czytelność w walce oceniam z geometrii i pojedynczych klatek.
- Nie mierzyłem pamięci ani czasu startu w tym audycie. Pomiary klatek zakłócał równoległy audyt Astry; wynik 12/3600 pochodzi z chwili spokoju.
- Render, fizyka, dziennik i narzędzia artystyczne przejrzane skanem i punktowo, nie linia po linii. Przeczytane w całości: `run/pilgrimage.lua`, `content/pilgrimage.lua`, `combat/execution.lua`, `player/intent.lua`, większość `ui/hud.lua`.
- Do weryfikacji przez właściciela: odczucie strzału, dźwięki, medale, skok znacznika, czy nawa jest za trudna dla człowieka.
