# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-07: silnik ruchu i strzału — zaakceptowany, wdrażanie trwa.**
Właściciel: „zacznij wdrażanie” po przedstawieniu planu E + F, czyli
z przyjęciem pięciu rekomendacji z „Decyzji właściciela”. Punkt wyjścia:
`d518491`, 0.45; pełna brama Linux All PASS (142 zestawy, 8808 sprawdzeń,
Input 50, Render i Tools).

Polecenie właściciela: odczucie strzelania i ruchu, czyli fizyka gry, ma być
perfekcyjne. Silnik ma być ogólny: tworzymy postacie w silniku, a nie silnik
dla postaci. Ten plan zastępuje plan Exorcista; jego treść przechodzi tu
jako etap E6, wykonywany już na wspólnym silniku. Poprzedni PLAN jest
w całości w HISTORII.

Zasada nadrzędna: rycerz, każdy stwór, przyszły boss, drugi rycerz i każda
broń to dane i profil podawane jednemu silnikowi. Kod silnika nie pyta
o nazwę postaci, broni ani trybu gry. Fizyka ciała jest ta sama dla
wszystkich; postacie różnią się liczbami i zdolnościami w swojej definicji.

## Potwierdzony stan

Dowody i miejsca w kodzie: HISTORIA, „Analiza silnika ruchu i strzału
(2026-11-07)”.

- Strzał jest już ogólny: dostawa z rejestru, dane broni, obserwacja
  pokazanego obrazu. Kliknięcie strzela w tej samej klatce, mysz obraca
  widok bez opóźnienia. To dobra podstawa; zostaje.
- Ruch ma dwa silniki. Rycerz: `player/feel.lua` (przyspieszenie, hamowanie,
  powietrze, skok, unik, ślizg, pchnięcie, uderzenie o mur). Stwór:
  `enemies/walking.lua` i `enemies/flight.lua` z innymi polami, własną
  całką grawitacji i dwiema ścieżkami lotu zależnie od tego, czy mapa ma
  podwyższenia. Lot stwora sprawdza sterowanego rycerza w pozycjach z
  wnętrza kroku, a pozostałych tylko od początku do końca kroku
  (korekta 2026-11-07: wcześniej błędnie zapisano, że tylko sterowanego).
- Tryb gry zmienia fizykę. Spowolnienie kroku w bok i w tył oraz chwila
  ciała po strzale działają tylko przy `attrition`. Tryb `floor`, na którym
  stoją golden i 34 pliki testów, go nie ma: testy pilnują innego ruchu niż
  ten w kaplicy.
- Symulacja pisze stan kamery (sprężyny, przysiad po lądowaniu, przechył,
  kołysanie w `player/feel.lua`), a wejście myszy pisze kołysanie broni.
  Fizyka i kamera są splątane.
- Wygładzanie obrazu korzysta z ręcznych list pól. Sonda 144 Hz: wysokość
  skoku stwora i zegar unoszenia Stolasa powtarzają 48 z 288 klatek;
  pozycje i skok rycerza są gładkie. Ładunki prochowe nie są wygładzane.
- Reakcje na strzał i ciosy to kilkanaście niezależnych sprężyn z liczbami
  w kodzie prezentacji (`feedback/weight.lua`). Strzał nadpisuje bieżący
  wstrząs, a część efektów pisze do wspólnego widoku zamiast do widoku
  właściciela zdarzenia.
- Bronie: profile prezentacji są w dużej mierze danymi, ale karty sklepu
  i ich polecenia znają tylko Judge'a i Exorcista (`ui/fire_shop.lua:14`,
  `app/commands.lua:149`).

## Plan do akceptacji

Każdy etap: najpierw czerwony test albo sonda, potem zmiana, dowód
przed/po, pełne Linux All, wpis w ZMIANY/ODBIOR i Postępie, commit.
Zegary SI, obrażenia, HP, rozrzut i kadencja bez zmian. Zmiana celowo
dotykająca symulacji: dwa identyczne golden i uzasadniony wzorzec Linux;
Windows pozostaje do sprawdzenia przez właściciela.

- **E0. Miernik odczucia.** Jeden zestaw QA z zapisanymi wejściami: chód,
  zmiana kierunku, hamowanie, skok, lądowanie, unik, ślizg, strzał każdej
  broni, przeładowanie, przyjęty cios, skok stwora. Przebiegi przy
  30/60/120/144/165/240 Hz i nierównych klatkach. Mierzy w pokazanym
  obrazie: powtórzone klatki, szarpnięcia, opóźnienie od wejścia do
  pierwszej widocznej zmiany, przeregulowanie i czas uspokojenia kamery
  i rąk. Zapisuje punkt odniesienia dla rycerza, obu broni i każdego stwora.
  Czerwone sprawdzenia znanych wad z „Potwierdzonego stanu”. Bez zmian gry.
- **E1. Jedne zasady ruchu w każdym trybie.** Krok w bok i w tył oraz chwila
  ciała po strzale należą do ciała postaci, nie do trybu. Tryb decyduje
  wyłącznie o płaceniu zasobami (wytrzymałość, flaska). `floor`, poligon
  i kaplica poruszają się tak samo, więc golden pilnuje prawdziwego ruchu.
  Jedna zmiana golden z uzasadnieniem.
- **E2. Wspólny silnik ciała.** Jedno ciało kinematyczne dla rycerzy
  i stworów: prędkość własna, impulsy zewnętrzne z oporem na ziemi i
  w powietrzu, grawitacja, podparcie, strop i krawędzie, mur i uderzenie
  o niego, kontakt ciał według mas. Sterowniki podają tylko zamiar:
  gracz (klawisze, skok, unik, ślizg), SI (droga do celu), czynność
  (skok ataku, szarża, odrzut). Zdolności i liczby w definicji postaci.
  Kolejność: najpierw przeniesienie bez zmiany wyniku (golden identyczny),
  potem jednakowo dokładne omiatanie każdego rycerza, potem jedna ścieżka
  lotu niezależna od podwyższeń mapy (możliwa drobna zmiana golden).
- **E3. Fizyka oddzielona od kamery.** Symulacja publikuje fakty: prędkość,
  przyspieszenie, oderwanie, uderzenie lądowania, kontakt z murem, postawiona
  stopa. Kamera, ręce i dźwięk liczą z nich reakcję w prezentacji. Rytm
  kroków należy do aktora, nie do wspólnego widoku. Mysz zmienia tylko
  kierunek patrzenia.
- **E4. Wygładzanie deklarowane przy polu.** Pole komponentu deklaruje
  sposób wygładzania (liniowo, kątowo, wcale); próbkowanie obrazu buduje
  się z deklaracji. Obejmuje wysokość skoku, ładunki, ruchome zagrożenia
  i zegar póz. Zegar wybierający pozę (a więc maskę trafień) staje się
  zegarem symulacji. Brama: nowe pole ruchu bez deklaracji zatrzymuje
  testy; zero powtórzonych klatek przy 144/165/240 Hz.
  Tu pierwsza próba właściciela: płynność.
- **E5. Jeden system impulsów prezentacji.** Zdarzenie + profil źródła +
  kierunek + odległość → ograniczona odpowiedź rąk, kamery i dźwięku.
  Reakcje się łączą, słabsza nie kasuje mocniejszej, jeden wspólny limit.
  Siła z fizyki (pęd, masa, impuls), nie z obrażeń; nazwane liczby w treści.
  Dotyczy strzałów, ciosów, lądowań, wybuchów i zachwiań, z zachowaniem
  obecnej siły istniejących efektów. MOTION wyłącza całość i usuwa resztki.
- **E6. Bronie jako profile silnika.** Masa, pęd, chwyt, noszenie, bezwładność
  celowania, kształt odrzutu i bank dźwięku w danych broni. Karty sklepu
  i polecenia z rejestru broni. Test fikcyjnego trzeciego profilu bez
  dodawania broni do gry (D20). Następnie poprzedni plan Exorcista, punkty
  2–8 (ciężar, unik/ślizg/skok/dobycie, strzał, audio A/B, przestrzeń,
  grafika bez reinterpretacji z trzema kontrolami), jako pierwszy profil.
  Judge jako kontrola regresji. Druga próba właściciela: strzelanie.
- **E7. Weryfikacja końcowa.** Miernik E0 przed/po dla wszystkich postaci
  i broni, macierz z planu Exorcista (ruch × strzał × przeładowanie,
  pauza, śmierć, ognisko, Continue, MOTION, obserwator), pomiar CPU.
  Odbiór właściciela osobno od technicznego PASS.

## Fundament kodu (F1–F5, do akceptacji)

Z przeglądu jakości i powiązań (HISTORIA, 2026-11-07): przebudowa jednego
stwora dotyka dziś 22–37 plików w 4–8 katalogach. Cel: nowa postać lub
mechanika to dane i jeden pakiet, a zmiana zostaje w jednym miejscu.
Każdy krok osobno, z bramą i golden; pierwsze kroki bez zmiany wyniku.

- **F1. Higiena bez zmiany zachowania.** Jedna nazwa na moduł (sprawdzana
  bramą), wartości domyślne pól widoku i ciała w deklaracjach zamiast
  964 × `or 0`, wspólne pomocnicze zamiast kopii, liczby odczucia
  z `feedback/` do treści, zapadka literałów także dla `feedback/`.
- **F2. Listy z rejestrów.** Wygładzanie, głosy, bronie sklepu, migracje
  i sekcje audio deklarowane przy swojej definicji; brak deklaracji
  zatrzymuje bramę.
- **F3. Stan czynności i klocki mechanik.** Stan ataku należy do jego
  rodzaju (schemat i wersja rodzaju), nie do płaskiego rekordu stwora.
  Istniejące rodzaje (strumień, zasiew, burza, fala, rytuał) rozłożone na
  ogólne klocki: wyrzut, pocisk, osad/strefa, fala, ruch ciała. Wybór pozy
  z rejestru stanów zamiast łańcucha w `Anim.pose`; zegar symulacji dla
  każdej pozy wpływającej na maskę trafień.
- **F4. Pakiet postaci.** Definicja, arkusz, anatomia, maski, profil
  i pliki głosów, teksty i malowane efekty jednej postaci w jednym
  katalogu, rejestrowane przez pakiet.
- **F5. Testy kontraktu.** Zachowanie każdego rodzaju i każdego modułu
  silnika sprawdzane na danych; testy postaci generowane z definicji,
  zamiast sprawdzania nazw póz i dźwięków.

E3–E5 (kanały prezentacji, wygładzanie, impulsy) realizują część tego
fundamentu dla ruchu i strzału. Rekomendowana kolejność łączna:
E0 → F1 → E1 → E2 → F2 → E3 → E4 → E5 → F3 → E6 → F4 → F5 → E7.

## Postęp i dowody

- 2026-11-07: przegląd skalowalności całego projektu i analiza silnika ruchu
  i strzału; obie w HISTORII. Sonda 144 Hz w osobnym klonie (usuniętym):
  48/288 powtórzonych klatek wysokości skoku stwora i zegara unoszenia,
  0/288 dla pozycji i skoku rycerza. Bez zmian gry; nie uruchamiano
  ponownie All po zmianie dokumentów.
- 2026-11-07: przegląd jakości i powiązań kodu (HISTORIA): koszt zmiany,
  płaski rekord stwora, trzy kanały prezentacji, 5941 literałów poza
  treścią, 68 modułów pod różnymi nazwami, 964 × `or 0`. Bez zmian gry.
- 2026-11-07, **E0 zrobione:** `qa/feel.lua` (pętla aplikacji, próbka
  rysowanego obrazu) i zestaw `feel` (84 sprawdzenia) przy 30/60/120/144/
  165/240 Hz i nierównych klatkach. Punkt odniesienia: chód, skok i unik
  bez zamrożonych klatek; pierwszy widoczny skutek klawisza mieści się
  w kosztach pętli (jeden krok wygładzania + jedna klatka bez kroku,
  np. 16,7 ms przy 120 Hz). Podbicie kamery po strzale idzie za błyskiem
  (np. 60 Hz: błysk 16,7 ms, podbicie 33,3 ms; 12 z 14 strzałów): znana
  wada E5. Szczyt podbicia Exorcist 0,0349 rad, uspokojenie ok. 320 ms;
  Judge 0,0179 rad, ok. 215 ms. Znane: wysokość skoku stwora i unoszenie
  Stolasa (E4), cofanie 1,110 m w testach i 0,715 m na poligonie (E1),
  strzał zaniża silniejszy wstrząs 0,5 → 0,010 (E5). Brama Linux All PASS:
  143 zestawy, 8892 sprawdzenia, Input 50, Render, Tools.
- 2026-11-07, **F1 zrobione (część):** każdy moduł `src` ma jedną nazwę
  lokalną, a nazwa oznacza jeden moduł (reguła w bramie architektury,
  249 zmian w 145 plikach, bez zmiany zachowania; m.in. `Arena`, `Pools`,
  `Tuning`, `Kinematics`, `Ballistics`). Zmiana nazw odsłoniła odczyt puli
  w `audio/soundscape.lua`, którego zapadka `enemy-pool-reads` nie widziała
  przez inną nazwę modułu; dopisano go jawnie. Wspólne `MathX.smoothstep`
  zamiast czterech kopii. Wartości domyślne pól widoku i liczby odczucia
  z `feedback/` przechodzą do E5, który przepisuje te funkcje.
- 2026-11-07, **E1 zrobione:** krok w bok i w tył, chwila ciała po strzale
  i nietykalność uniku (0,32 s) są zasadami ciała we wszystkich trybach;
  tryb decyduje tylko o płaceniu wytrzymałością. Usunięto `dashIframes`
  (0,20 s, używane tylko na `floor`). Testy i poligon cofają się tak samo
  (0,715 m); trzy testy oczekiwały starych liczb `floor` i sprawdzają teraz
  tę samą intencję na prawdziwych zasadach. Golden bez zmian (jego
  scenariusze grały już z zasadami wysiłku).
- 2026-11-07, **E1b zrobione:** ukos płaci udział kroku w bok dla 45°;
  wcześniej udział wzdłuż patrzenia dzielono przez długość klawiszy dwa
  razy i ukos szedł jak 60° w bok (4,683 zamiast 4,834 m w pierwszej
  sekundzie). Wykryte przez test E1. Golden Linux zmieniony z dwóch
  identycznych przebiegów; `souls-gate` i `souls-bots` przed/po identyczne.
- 2026-11-07, **E4 zrobione:** pola ciał deklarują wygładzanie
  w `session/components.lua` (`linear` dla miejsca i wysokości, `clock` dla
  zegara bieżącego stanu, wartość spoczynku dla wysokości lotu i upadku);
  `render/presentation.lua` buduje z deklaracji listy stworów, pocisków
  i ładunków (ładunki prochowe wcześniej nie były wygładzane). Zegar
  biegnący (unoszenie, oddech, migotanie) jest wygładzany w próbce obrazu;
  symulacja i golden bez zmian. Miernik mierzy ciągłe parametry pozy
  (uniesienie, przechył, rozciągnięcie) każdego stwora w chodzie, każdym
  ataku i wyjściu z portalu: przed zmianą 108 czerwonych sprawdzeń przy
  144 Hz i nierównych klatkach, po zmianie 0. Pola widoku rycerza zostają
  na liście do E3/E5.
- 2026-11-07, **E5 krok a zrobiony:** wstrząs kamery ma jedną regułę łączenia
  (`feedback/impulses.lua`); wszystkie zapisy przez nią. Strzał nie zaniża już
  silniejszego wstrząsu (wcześniej Judge zbijał 0,5 do 0,010). Dalszy krok E5
  (podbicie widoku w klatce błysku) czeka na decyzję właściciela, bo
  przesuwa szczyt podbicia o ok. 8 ms.
- 2026-11-07, **E5 krok b zrobiony (decyzja właściciela: tak):** impuls
  strzału daje `Impulses.kick` od początku kroku strzału, wiek błysku
  pokazuje zegar obrazu (`render/presentation.lua: viewClocks`); podbicie
  i błysk czytają jedną chwilę strzału. Sprężyny dłoni w `camera.hands`.
  Zostaje z E5: impuls jako zdarzenie z profilem, kierunkiem i odległością,
  wartości domyślne pól widoku zamiast `or 0`, liczby odczucia z
  `feedback/` do treści z zapadką literałów, odbiorcy per aktor.
- 2026-11-07, **E5 krok c zrobiony:** wartości startowe pól widoku
  w `Fields.start` (`session/fields.lua`); `ViewState.init`, widok ciała
  (`player/feel.lua`), `Weight.clearMotion` i `WeaponMotion.init` biorą je
  stamtąd; reguła VIEW START w `tools/check/main.lua` pilnuje `feedback/`.
  Odczyty w `render/` i `ui/` zostają z zapasem, bo przeglądy QA rysują
  widoki budowane ręcznie; to do F5 (kontrakty).
- 2026-11-08, **E5 krok d zrobiony:** impuls jako zdarzenie. Ciosy, ściana,
  wybicie, lądowanie, potwierdzenia trafień, zachwianie i wstrząsy świata
  idą przez `Impulses.react` (siła, kierunek, odległość) z profilami
  w `content/view_reactions.lua`; kanały mają jedną wspólną granicę, szczyt
  zostaje przy silniejszym. Siła bez zmian (sonda 118 przypadków). Reguła
  IMPULSE WRITE i zapadka liczb bez nazwy dla `feedback/` (468).
  Zostaje z E5: dźwięk ciosu w profilu, liczby odczucia z `weapon_motion`,
  `impact_response` i `death_response` do treści, odbiorcy per aktor.
- 2026-11-08, **E5 krok e zrobiony:** liczby ruchu rąk (`content/hand_motion.lua`),
  ciosów, werdyktów i serca (`tuning.weight`) oraz kontaktów ciała
  (`tuning.contact`) w treści; `weapon_motion`, `weight`, `movement_impact`
  bez liczb bez nazwy. Przebieg sondy identyczny bajt w bajt. Zostaje
  z E5: reakcje stworów (`impact_response`, `death_response`) i reszta
  `feedback/` (304), odbiorcy per aktor.
- 2026-11-08, **E2 krok a zrobiony:** jeden wzór lotu (`Kinematics.flight`)
  dla rycerza, skoku stwora i padającego ciała; pchnięcie rycerza przez
  `Physics.drag` jak u stworów; reguła BODY MOTION. Golden identyczny.
  Następne: równie dokładne omiatanie każdego rycerza (dziś tylko
  sterowany jest omiatany co pod-krok, pozostali od migawki kroku), potem
  jedna ścieżka lotu bez `flatFallTime`.
- 2026-11-08, **E2 krok b zrobiony:** każdy rycerz omiatany w tej samej
  części kroku co ruch stwora (`moveEnemy` z ułamkami kroku); test
  z drugim rycerzem czerwony przed, zielony po. Golden identyczny.
- 2026-11-08, **E2 krok c zrobiony:** jedna ścieżka lotu i upadku na każdej
  mapie (bez `flatFallTime`, bez osobnej drogi dla płaskiej mapy); test
  mapa płaska = mapa z zerowymi podwyższeniami. Golden bez zmian (dwa
  przebiegi). Zostaje z E2: sterowniki jako sam zamiar (chód stwora
  i przyspieszenie rycerza to wciąż dwie reguły), zdolności i liczby
  ruchu w definicji postaci; lądowanie rycerza na końcu kroku, stworów
  o czasie podłogi.
- 2026-11-08, **F2 krok a zrobiony:** bronie sklepu z deklaracji broni
  (`shop = { order }`, karta z ilustracji broni); sklep, polecenia i arkusz
  kart bez listy broni. Wygładzanie było już z deklaracji pól (E4).
  Następne: banki głosów, sekcje i pola głosów audio, migracje.
- 2026-11-08, **F2 krok b zrobiony:** banki głosów z katalogu `audio/banks`,
  pola głosów oznaczone w schematach (`voice = true`) i sprawdzane wszędzie,
  sekcje profilu audio deklarowane przy czytniku. Golden bez zmian.
- 2026-11-08, **F2 zrobione (krok d):** migracje z deklaracji stwora
  (`savedAttacks`), bez osobnej listy reguł. Każda z pięciu list z przeglądu
  powstaje teraz z deklaracji przy definicji, a brak deklaracji zatrzymuje
  bramę. Zostaje poza F2: zapis ataku po id zamiast numeru na liście
  (przegląd skalowalności), który usunąłby same kopie. Następny: E3.
- 2026-11-08, **E3 krok a zrobiony:** krok rycerza publikuje fakty w chwili
  zdarzenia (`motion.*`), kamera, ręce i dźwięki ruchu liczy
  `feedback/motion.lua`; reguła MOVEMENT PRESENTATION. Obraz i dźwięk
  identyczne (sonda), golden bez zmian.
- 2026-11-08, **E3 krok b zrobiony:** mysz zmienia tylko kierunek patrzenia
  (martwe kołysanie od myszy usunięte); test w `core`. Zostaje poza E3:
  pozostałe dźwięki wybierane przez symulację (`Presentation.cue` w walce
  i u stworów) i nazwane haki poza ruchem rycerza (przegląd jakości, pkt 5).
  Następny: F3 (E4 i E5 w głównej części zrobione wcześniej).
- 2026-11-08, **F3 krok a zrobiony:** stan ataku jednego rodzaju w `e.act`,
  deklarowany przez rodzaj (`state`), zapis pul 8 z migracją, reguła ATTACK
  STATE. Golden bez zmian. Zostaje z F3: wspólne pola przebiegu ataku
  (zatrzymanie, łańcuch, ciąg, oznaczony cios na ziemi) i wersja stanu
  rodzaju w zapisie; klocki mechanik (wyrzut, pocisk, osad, fala, ruch
  ciała); wybór pozy z rejestru stanów i zegar symulacji dla póz maski.
- 2026-11-08, **F3 krok b zrobiony:** znak pioruna w stanie rodzaju
  (`e.act.mark`), haki rodzaju `abandon`/`release`/`forget` zamiast pól
  rodzajów w rejestrze, wersja stanu rodzaju w zapisie (zapis pul 9).
  Zatrzymanie, łańcuch i ciąg zostają na ciele jako zegary stanu ciała
  (uzasadnienie w HISTORII). Golden bez zmian.
- 2026-11-08, **F3 krok c zrobiony:** wybór pozy z rejestru stanów
  (`Anim.states`, `Anim.state`), sonda póz identyczna. Golden bez zmian.
- 2026-11-08, **F3 krok d zrobiony:** każdy zegar pozy stwora to zegar
  symulacji (reguła POSE CLOCK); obraz wygładza go między krokami. W pauzie
  stwór stoi. Golden bez zmian. Znalezisko: w spoczynkowej klatce 28
  chochlika pocisk w namalowany korpus mija bryłę trafień (HISTORIA).
- 2026-11-08, **F3 krok e zrobiony, F3 zamknięty:** klocki mechanik
  w `enemies/mechanics.lua` (wyrzut, pocisk, pocisk łukiem, znak na ziemi,
  seria); rodzaje z nich złożone, test rodzaju z samych klocków. Golden bez
  zmian. Następny: E6.
- 2026-11-08, **E6 krok a zrobiony:** profil rąk broni (`hands`) i jej bank
  dźwięku przeładowania (`reload.voices`, `reload.sounds`), reguła HAND
  PROFILE, test fikcyjnej trzeciej broni. Golden bez zmian. Zostaje z E6:
  punkty 2–8 planu Exorcista jako jego pierwszy profil (ciężar noszenia,
  unik/ślizg/skok/dobycie, gest strzału, audio A/B, przestrzeń, grafika)
  i druga próba właściciela.
- 2026-11-08, **E6 krok b zrobiony (punkt 2 planu Exorcista):** ciężar
  noszenia jako profil rąk Exorcista: lufy zostają dalej i później, osiadają
  bez odbicia, kolba trzyma broń równo, lądowanie głębsze bez odbicia,
  spoczynek oszczędny z korektami chwytu wyciszanymi przez unik. Judge bez
  zmian. Golden bez zmian. Następny: punkt 3 (unik, ślizg, skok, dobycie).

## Decyzje właściciela

1. Jedne zasady ruchu we wszystkich trybach (E1). Rekomendacja: tak;
   poligon różni się tylko płaceniem zasobami.
2. Wspólny silnik ciała może drobno zmienić lot i kontakt stworów (golden);
   zegary SI, obrażenia i balans zostają (E2). Rekomendacja: tak.
3. Plan Exorcista jako etap E6 na wspólnym silniku. Rekomendacja: tak.
4. Kolejność E0 → E7 z próbami po E4 i E6. Rekomendacja: tak.
5. Fundament F1–F5 razem z E, w kolejności łącznej wyżej. Rekomendacja: tak.

Przyjęte 2026-11-07 („zacznij wdrażanie”): wszystkie pięć zgodnie z
rekomendacją.

## Poza zakresem

Rejestr sigili, zapis rozpoczętych ataków po id zamiast numeru, granice
zapisu przy zmianie strojenia sigili, `boss` → poziom postaci, Git LFS
i podział bramy na procesy (przegląd skalowalności w HISTORII: osobne
zadania). Nowe bronie, balans, zegary SI, elity, HUD, Windows, pakowanie
i wideo. Odłożone sprawy i wcześniejsze plany pozostają w HISTORII.
