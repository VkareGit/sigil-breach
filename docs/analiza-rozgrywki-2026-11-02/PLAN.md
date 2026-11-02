# Analiza rozgrywki i plan (2026-11-02)

Dwie niezależne analizy: Claude (kod + sonda bez okna) i Codex Astra ultra (tylko odczyt, pełna odpowiedź: `work/gameplay-consult/astra-answer.md`, moja: `work/gameplay-consult/claude-analysis.md`). Pomysły właściciela były tylko jedną z rzeczy do rozważenia, nie listą do zrobienia.

## Diagnoza: przyczyny, nie objawy

### 1. Walki z najtwardszymi są wyścigiem amunicji przez to, jak ustawione są liczby
| Fakt z kodu | Liczba |
|---|---|
| Pełny zapas z ogniska (Judge 6+72 x 70, Exorcist 11 pełnych strzałów x 240) | ok. 8100 obrażeń przy 100% trafień z bliska |
| Margrave / Furfur | 9000 / 10000 HP |
| W trakcie zamachu i ciosu przyjmują | 30% / 35% obrażeń |
| Exorcist traci moc | powyżej 4 m |
| Pierwszy zrzut fazowy (14 łusek) | dopiero po odebraniu 3060 / 3400 HP |
| Egzekucja Margrave'a | 8% HP, a garda (2600) też jest kupiona nabojami |

W souls-like podstawowe obrażenia (miecz) są darmowe, a zasób (wytrzymałość) wraca w sekundy. Tu każdy punkt obrażeń kosztuje zasób, który wraca tylko przy ognisku, a ognisko odradza świat i kasuje postęp walki. Pusty arsenał odbiera naraz atak, odbicie strzałem i rally (leczenie). To nie jest „gorsza gra bez naboi”, tylko brak gry. Obie analizy doszły do tego samego niezależnie.

### 2. „Biegnie z ręką w górze i nie bije”: obraz mówi „teraz”, a reguły „jeszcze czekaj”
- Wiele ciosów ma celowe przytrzymanie po zamachu (`hold`; imp do 0,55 s, armored 0,55, Furfur 0,7, Margrave 0,9), żeby ukarać unik w starym rytmie.
- W tym czasie `e.windup` wynosi już 0, więc ciało stoi na ostatniej klatce zamachu (ręka w pełni uniesiona), a błysk „uderzam teraz” (`render/renderer.lua:303`, `windup < 0.18`) świeci przez całe przytrzymanie. Animacja (`enemies/action_phase.lua:44`) kończy zamach przed czasem. Pierścień kontry liczy oba zegary, ciało nie. **Sprawdzone w kodzie.** (znalazła to Astra)
- Sonda: zamach plus przytrzymanie to 30–38% całej walki z każdym stworem wręcz.
- W grupie (3 impy, armored, stolas) każdy stwór wręcz spędza **14–36% walki w zasięgu, gotowy, ale bez prawa ataku** (limit 2 atakujących i odstęp 0,24 s). Czeka wtedy przy rycerzu (`flank`: pierścień 1 m, krok w bok), czyli stoi obok i nie bije. (moja sonda)
- Imp: z bliska ok. 85% wyborów to odskok i późny pazur z przytrzymaniem (waga hop-back 14 wobec claw 2). Ma też martwą strefę 2,05–2,6 m, w której nie ma żadnego ciosu.
- Reakcje na przeładowanie i flaskę omijają limit atakujących: najpierw cisza, potem nagle naraz kilku, akurat gdy gracz się odnawia. Reakcja `dodged` jest w praktyce nieosiągalna. (Astra)

### 3. Rzeczy, których właściciel nie zgłosił
- Odrodzenie przy bocznych ogniskach stawia rycerza 5,5 m od Margrave'a / Furfura, czyli w ich zasięgu `alert = 6`: mogą się obudzić bez kroku gracza. (Astra)
- Rally oddaje 4% obrażeń, więc pancerz w trakcie zamachu dusi jednocześnie amunicję i leczenie.
- Awaryjne `mercy` w praktyce nie działa (wymaga zera w całym arsenale, żywego `guardian` i braku jakiejkolwiek paczki na mapie, a daje łuski Exorcista).
- Częściowo zebrana paczka znika z resztą.
- Grawery są tylko dla Exorcista; Judge, broń podstawowa, nie ma się czym rozwijać.
- Continue po wyjściu do menu może obchodzić koszt odwrotu (wczytanie odnawia przy ogniu). Nie sprawdzone w grze.

## Ogniska czy pętla w stylu Dooma: ocena

| Kierunek | Co to znaczy | Plusy | Minusy | Nakład |
|---|---|---|---|---|
| A. Ogniska jak teraz, tylko więcej zapasów | skrytki, większe paczki, bufor ok. 30% ponad koszt odcinka | najmniej zmian | przy każdej nowej mapie trzeba liczyć budżet; uczący się gracz nadal zostaje pusty | S |
| B. Pełna pętla doomowa (bez ognisk) | zasoby z walki (egzekucja daje naboje, glory kill zdrowie), automatyczne punkty kontrolne, oczyszczone pokoje zostają | szybsze tempo, agresja się opłaca | znika ryzyko powrotu, echo i dusze tracą sens, trzeba przebudować zapis, śluby, grawery i podróż; w pojedynku z jednym stworem nie ma „pił” do karmienia | L |
| **C. Hybryda (rekomendacja obu analiz)** | ogniska zostają (powrót, zapis, rozwój, odrodzenie), ale podstawowa broń nie może się skończyć na zawsze; łuski zostają rzadką przewagą | rdzeń souls zostaje, znika „brak naboi = brak gry” | mniej logistyki Judge'a; trzeba sprawdzić, czy skrytki nadal są potrzebne | M |

Pełne usunięcie ognisk rozwiązuje objaw (reset świata zabiera postęp) kosztem tożsamości: bez ognisk nie ma decyzji „zaryzykować dalej czy wrócić”, a kara za śmierć słabnie. Z Dooma warto wziąć tylko to, co działa: **zasób z agresji i z dobrego czytania walki**, a nie z biegania po paczki.

## Plan (etapy, od najważniejszego)

| # | Co | Mechanika i liczby startowe | Pliki | Ryzyko dla filarów | Nakład | Grafika/dźwięk |
|---|---|---|---|---|---|---|
| 1 | **Uczciwy cios** | Przy przytrzymaniu ciało zostaje w pozie gotowości (nie na ostatniej klatce), błysk dopiero w ostatnich 0,18 s całości (zamach + przytrzymanie). Animacja liczy oba zegary. | `render/renderer.lua` (tell), `enemies/action_phase.lua`, `enemies/animation.lua` | wzmacnia odczyt ciosu | S | może osobna klatka „czeka” (Codex) |
| 2 | **Stwory bez slotu nie stoją przy rycerzu** | Czekający odchodzi na pierścień 3–3,5 m przodem do rycerza; lekkie stwory (imp, stolas) 3 naraz zamiast 2; reakcje na przeładowanie/flaskę liczą się do limitu; martwa strefa impa zamknięta (claw do 2,3 m albo leap od 2,3 m); waga hop-back 14 → 5. Przytrzymanie zwykłych stworów rzadsze: 0 w 2 na 3 ciosów. | `enemies/ai.lua`, `enemies/styles.lua`, `content/combat_defaults.lua`, `content/creatures/imp.lua` | grupa staje się groźniejsza: sprawdzić na bocie, ile śmierci | S/M | nie |
| 3 | **Judge nie kończy się na zawsze** (rdzeń hybrydy) | Pusty Judge (bęben i zapas 0) ładuje 1 nabój/s, do 6 w bębnie; można przerwać, zostają włożone. Pełne przeładowanie z zapasu zostaje 1,85 s. Exorcist i proch zostają skończone. Usunąć zepsute `mercy`. | `combat/reload.lua`, `content/reloads.lua`, `content/ammo/`, `content/tuning.lua`, `session/interactions.lua` | Judge przestaje być presją logistyczną, staje się „mieczem”; łuski zostają przewagą | M | ruch ładowania pojedynczego naboju i klik (Codex) |
| 4 | **Bezpieczne odrodzenie** | Rycerz przy bocznym ognisku poza zasięgiem `alert` (nisza albo reguła sanktuarium wokół ogniska). | `content/pilgrimage.lua`, `run/pilgrimage.lua` | brak | S | nie |
| 5 | **Czas walki z najtwardszymi** | Po 1–3: celem 60–90 s dobrej walki zamiast długości paska. Jedna zmienna naraz: najpierw pierwszy zrzut fazowy przy 80% HP (zamiast 66%), potem ewentualnie HP lub pancerz zamachu 30% → 50%. Egzekucja najtwardszego 8% → 12%, żeby czytanie skracało walkę. | `content/creatures/boss.lua`, `furfur.lua` | to są moby, nie bossowie: nie mogą udawać bossa długością paska | S | nie |
| 6 | **Zasób z dobrej gry (z Dooma)** | Doskonały unik albo odbicie strzałem oddaje 1 łuskę (raz na 4 s); egzekucja już daje paczkę. Opcja po próbie: łyk flaski oddaje 6 naboi Judge'a do zapasu (nie magazynek strzelby: 2 łuski za 45 HP to zła wymiana). Zdrowie za naboje (Bloodborne) **nie**: obciąża drugi zasób akurat wtedy, gdy gracz przegrywa. | `combat/dodge.lua`, `run/drops.lua` | nagradza czytanie ciosu | S/M | dźwięk zwrotu łuski |
| 7 | **Wzmocnienia do znalezienia w świecie** | Trwałe, jednorazowe znaleziska na opcjonalnych trasach, głównie dla Judge'a (który nie ma grawerów): szybsze przeładowanie 1,85 → 1,6 s, większy bęben 6 → 7, ciaśniejszy rozrzut Exorcista. Wpisane jako grawery, które leżą w świecie zamiast w sklepie. Nigdy obowiązkowe +obrażenia. | `content/weapons.lua` (grawery), `content/pilgrimage.lua` (miejsca), `run/pilgrimage.lua` (zapis) | żadne, jeśli są opcjonalne | M | ikony / modele znalezisk (Codex) |

Skrytki z 60-sekundowym powrotem (zrobione dziś na prośbę właściciela) zostają jako doraźna pomoc. Po etapie 3 ocenić, czy nadal są potrzebne.

## Pierwszy krok i pomiar
Obie analizy zgadzają się: najpierw 1 i 2 (uczciwość i czytelność, bez zmiany balansu amunicji), potem 3 jako **jedyna** zmiana ekonomii przed próbą właściciela. Zmienić jedno naraz, żeby było wiadomo, co pomogło.

Po próbie zmierzyć (sonda plus ocena właściciela):
- czas z obiema broniami pustymi (poza przeładowaniem) oraz odwroty i dodatkowe przejścia przez salę wyłącznie po amunicję,
- obrażenia na wydany nabój oraz udział strzałów w pancerz zamachu,
- czas walki z Margrave'em i Furfurem oraz liczbę egzekucji i kontr,
- czy właściciel rozumiał moment ciosu i przyczynę każdej śmierci.
