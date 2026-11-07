# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-07: silnik ruchu i strzału — plan do akceptacji.** Nie rozpoczęto
wdrażania. Stan gry: `d518491`, 0.45; pełna brama Linux All PASS
(142 zestawy, 8808 sprawdzeń, Input 50, Render i Tools).

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
  podwyższenia. Lot stwora omiata tylko sterowanego rycerza.
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
  potem omiatanie wszystkich rycerzy w locie stwora, potem jedna ścieżka
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

## Postęp i dowody

- 2026-11-07: przegląd skalowalności całego projektu i analiza silnika ruchu
  i strzału; obie w HISTORII. Sonda 144 Hz w osobnym klonie (usuniętym):
  48/288 powtórzonych klatek wysokości skoku stwora i zegara unoszenia,
  0/288 dla pozycji i skoku rycerza. Bez zmian gry; nie uruchamiano
  ponownie All po zmianie dokumentów.

## Decyzje właściciela

1. Jedne zasady ruchu we wszystkich trybach (E1). Rekomendacja: tak;
   poligon różni się tylko płaceniem zasobami.
2. Wspólny silnik ciała może drobno zmienić lot i kontakt stworów (golden);
   zegary SI, obrażenia i balans zostają (E2). Rekomendacja: tak.
3. Plan Exorcista jako etap E6 na wspólnym silniku. Rekomendacja: tak.
4. Kolejność E0 → E7 z próbami po E4 i E6. Rekomendacja: tak.

## Poza zakresem

Rejestr sigili, zapis rozpoczętych ataków po id zamiast numeru, granice
zapisu przy zmianie strojenia sigili, `boss` → poziom postaci, Git LFS
i podział bramy na procesy (przegląd skalowalności w HISTORII: osobne
zadania). Nowe bronie, balans, zegary SI, elity, HUD, Windows, pakowanie
i wideo. Odłożone sprawy i wcześniejsze plany pozostają w HISTORII.
