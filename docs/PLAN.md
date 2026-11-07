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
