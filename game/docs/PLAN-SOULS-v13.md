# SIGIL: BREACH — plan v13: potwory jak w Soulsach i ogniska

Status: DO ZATWIERDZENIA, 1 listopada 2026. Stan odniesienia: `414cf35`, 0.36.
Zakres: sześć istniejących istot, modele bez zmian. Fale i Limbo znikają, poligon
zostaje jako warsztat do testowania ataków.

**Stan z 1 listopada 2026:** W0-W7 i O1-O4 zrobione, wersja 0.38. Bossy odłożone decyzją gracza, na razie to najtrudniejsze moby.

## Diagnoza

Pomiary z 0.36 na prawdziwej symulacji, bot o idealnym celu, próba w kaplicy:

| Scena | Wynik |
|---|---|
| Margrabia, nikt do niego nie strzela | 16 ciosów w 30 s, najdłuższa przerwa 3,9 s |
| Margrabia, rycerz stoi i strzela (bez śmierci) | 4 ciosy, boss martwy po 14 s walki |
| Margrabia, rycerz stoi i strzela (zwykle) | rycerz ginie po 11,5 s, bossowi zostaje 1/3 życia |
| Furfur, rycerz stoi i strzela | rycerz ginie po 6,7 s |
| Żar, rycerz stoi i strzela | Żar ginie po 0,9 s, 0 ciosów |
| Żelazny, rycerz stoi i strzela | Żelazny ginie po 2,8 s, 0 ciosów |

| Fakt w kodzie | Skutek w grze |
|---|---|
| Margrabia traci około 170 HP/s od strzałów z miejsca | Wyścig obrażeń jest niemal wyrównany, a nie przegrany z góry |
| Trafienia wstrzymują bossa tylko na 0,7 s z 14 s; 4 s to przejścia między aktami (`recovery`), które sam gracz przyspiesza | Im szybciej strzelasz, tym mniej ciosów boss zdąży zadać |
| Z 18 ciosów ciałem tylko 3 (`lunge`) idą za namalowaną ręką. `sweep` i `seize` to cały łuk naraz, `leap` to walec przy lądowaniu | Cios nie ma kierunku ani toru, nie da się wejść pod ostrze ani obiec go |
| 31 z 40 ciosów zamraża cel na początku windupu, a `track` przestawia cel natychmiast. Obrót ciała (`turnRate`) jest tylko wizualny | Brak prawdziwego śledzenia, nie ma sensu obchodzić bossa bokiem |
| Stwór wybiera cios tylko z dystansu i odnowienia. Nie reaguje na leczenie, przeładowanie, strzelanie z daleka ani stanie za plecami | Nie karze błędów, tylko wykonuje listę |
| Rycerz strzela bez kosztu, unik wraca po 0,78 s, zdrowie wraca z zabójstw i podnoszonych skrzynek | Nie ma zasobu, którym trzeba gospodarować |
| Przy dużym ciele na 1 m ekran wypełniają piksele sprite'a | Przyklejenie się do bossa jest brzydkie i bezpieczne |

## Jak działają potwory w Soulsach

Publiczne źródła opisują to częściowo. Wnętrze gier FromSoftware nie jest
udokumentowane i dokładnych liczb śledzenia nigdzie nie znalazłem.

1. **Cios to oś czasu animacji.** Zapowiedź, sygnał, aktywne trafienie, poza końcowa,
   powrót. Hitbox istnieje tylko w aktywnej części, w Dark Souls 3 przez 2-4 klatki.
   Powrót to okno gracza i im krótszy, tym trudniej.
2. **Trafienie wynika z animacji.** Zdarzenia animacji włączają hitboxy i pociski,
   więc liczy się tor ciosu, a nie odległość od ciała.
3. **Unik to niewrażliwość, nie ucieczka.** Średni przewrót w DS3 chroni przez 433 ms
   i można przejść przez cios, jeśli wyczuje się moment.
4. **Stwór obraca się podczas zamachu, a potem przestaje.** Za wczesny unik dostaje
   cios, spóźniony też. Stąd obchodzenie dużych ciał i opóźnione ciosy.
5. **Równowaga to ukryty pasek.** W Elden Ring zwykli wrogowie mają 15-65, bossowie
   zwykle 80-120. Pasek odnawia się po przerwie. Złamanie daje długie ogłuszenie
   i krytyk, a nie drobne zachwianie. Ciosy mają też pancerz na czas ataku.
6. **Myślenie to stos celów.** Wybór ciosu to ważone losowanie zależne od odległości
   i odnowień, z ciągami, które mogą się wydłużyć. Przerwania reagują na zdarzenia:
   użycie przedmiotu, ogień, trafienie od dołu, wejście gracza w strefę.
7. **Ognisko to punkt kontrolny świata.** Odpoczynek leczy, napełnia flaski, ustawia
   miejsce powrotu i wskrzesza zwykłych wrogów, ale nie bossów. Po śmierci dusze
   zostają w miejscu zgonu, a druga śmierć po drodze je kasuje.

## Korekta: wyzwanie to wiedza, nie ruch

Uwaga gracza po przebudowie silnika: przejście walki nie może zależeć od tego, czy się
ruszasz. Pomiar to potwierdził: bot wygrywał jednym odruchem, unikiem w bok tuż przed
ciosem. To porażka projektu, a nie sukces, więc miarą zostaje wiedza o ciosach.

**Co robi walkę FromSoftware**

1. Boss to umowa: płacisz śmiercią, dostajesz informację. Każdy cios ma swoją
   odpowiedź i po porażce wiadomo, co poszło źle.
2. Różne ciosy karzą różne nawyki: ucieczkę, panikę, krążenie, chciwość, kurczowe
   trzymanie dystansu. Jeden nawyk nie działa na wszystko.
3. Okno na karę jest nagrodą za odczytanie wzoru, nie stałym stanem. Rozróżnienie
   „okno” a „zaproszenie” to połowa nauki.
4. Bloodborne daje broń palną jako kontrę: strzał w chwili ataku ogłusza i otwiera
   krytyk. Odzysk zdrowia za oddanie ciosu ciągnie gracza do przodu, nie do ucieczki.
5. Stwory uczą reguł, które boss później sprawdza.

**Jak to przekładam na grę**

- **Kontra strzelbą:** salwa w oknie tuż przed ciosem przerywa go i otwiera egzekucję.
  Nie każdy cios da się skontrować, to część nauki. Wymaga stania i patrzenia.
- **Pancerz z popiołu:** w zamachu i w ciosie Margrabia bierze 35% obrażeń, w odpoczynku
  pełne. Strzelanie cały czas przestaje mieć sens, liczy się moment.
- **Odzysk:** część straconego zdrowia wraca przez kilka sekund za trafienia.
- **Karta ciosów:** każdy cios ma jedną właściwą odpowiedź:

| Cios | Co karze | Odpowiedź |
|---|---|---|
| Cięcie w prawo, cięcie w lewo | unik w stronę cięcia | unik przez ostrze, pod prąd |
| Cios z góry z opóźnieniem | panikę | czekać, unik w ostatniej chwili, potem kara |
| Chwyt | unik za wcześnie | kontra strzelbą |
| Skok i krąg | ucieczkę | skok nad kręgiem albo unik przez niego |
| Grad z wyprzedzeniem | ciągły ruch | zatrzymać się |
| Lanca po ziemi | stanie na linii | filar albo bok |
| Tupnięcie | przyklejenie | skok |
| Cięcie w obrocie | krążenie za plecami | wyjście z zasięgu |
| Łapanie uniku | unik na ślepo | nie unikać po pierwszym ciosie |
| Fala z absydy | wszystko oprócz skoku | skok w chwili przejścia |

**Stwory, każdy to lekcja przed bossem**

- **Żar:** opóźniony pazur i stado z flanki. Uczy czekania na cios.
- **Żelazny:** pancerz z przodu, wolny obrót. Uczy wychodzenia na bok i strzałów w nogi.
- **Akolita:** czar można przerwać strzałem. Uczy kontry w bezpiecznych warunkach.
- **Ogrodnik:** odcina podłogę i narasta. Uczy czytania ziemi i wyjścia z ognia.

**Nowa bramka:** bot odruchowy (ruch i unik w bok na każdy cios) ma przegrać z bossem.
Wygrywa tylko bot z kartą ciosów.

## Zasady planu

1. Stanie i strzelanie przegrywa z każdym stworem poza pojedynczym Żarem. To
   najważniejszy test.
2. Trudność nadal bierze się z rytmu, nie z krótszych telegrafów.
3. Atak edytuje się w jednym miejscu i widać go w grze bez restartu.
4. Świat jest stały, stwory stoją na swoich miejscach, śmierć ma koszt i drogę powrotu.
5. Każdy etap ma commit, raport, testy dodatnie i ujemne. Etapy zmieniające walkę
   mają własny złoty wzorzec z opisem zmiany.

## Część I: potwory

### W0. Bramka
Bot „stoi i strzela” wchodzi do testów akceptacji jako oczekiwana porażka. Dochodzą
pomiary: ciosy bossa ostrzeliwanego wobec nieostrzeliwanego oraz czas walki.

### W1. Oś czasu i ślad ciosu
Nowe pole ataku zastępuje `reach`, `arc` i `active`:

```lua
timeline = { tell = 0.62, lockAt = 0.45, recover = 0.8 },
trace = {
  { at = 0.08, angle = -1.2, reach = 3.2, height = 1.5, radius = 0.35 },
  { at = 0.16, angle = 0, reach = 3.3, height = 1.2, radius = 0.35 },
  { at = 0.22, angle = 1.2, reach = 3, height = 0.9, radius = 0.35 },
},
```

`trace` to tor kuli względem ciała, przeciągany co krok przez istniejące `Melee.contact`
(ściany, skok, kucanie, odbicie uniku zostają). `lunge`, `sweep`, `seize` i `charge`
dostają jedną ścieżkę kontaktu. `leap` rani przy lądowaniu falą o szerokości z danych,
a w locie ciało potrąca. Cios można przejść unikiem, wejść pod niego albo obejść.

### W2. Obrót i śledzenie
Obrót staje się prawdą symulacji. Każdy cios ma `turn` (rad/s) i `lockAt`, moment
w którym ciało przestaje się obracać. Tor liczy się od kierunku ciała, nie od zapisanego
celu. Duże ciała obracają się wolno, więc bok i plecy są realnym miejscem.

### W3. Edycja ataku
Dziś atak zmienia się w `content/creatures/<istota>.lua`, wymaga restartu, a podgląd
hitboxów na poligonie nie rysuje `sweep`, `seize` ani fal. Po tym etapie:

- podgląd hitboxów rysuje każdy rodzaj: tor, stożek obrotu, moment blokady;
- pod F2 lista wszystkich ciosów stwora: wywołaj dowolny na żądanie;
- spowolnienie 0,25× i krok po kroku;
- klawisz przeładowania danych stworów bez restartu gry;
- rozdział „Jak edytować cios” w poradniku i raport osi czasu każdego ciosu.

### W4. Równowaga i hiperpancerz
- `microStun` i pauzy od trafień znikają u dużych ciał.
- `hyper` staje się osią: od którego do którego momentu ciosu ciało nie reaguje.
- Złamanie to rzadkie zdarzenie. U bossa około co 20-30 s poprawnej walki.
- Po złamaniu okno na **egzekucję**: [E] z bliska, wielkie obrażenia, reset paska.
- Przejścia między aktami wciąż są bezpieczne dla oka, ale przestają kasować bossowi
  czas: po nich wraca do walki z gotowym ciosem.

### W5. Wytrzymałość i flaska
- **Wytrzymałość:** kosztuje salwa, unik, skok i przeładowanie pod presją. Odnawia się
  po krótkiej przerwie. Pusta: brak uniku.
- **Unik** dłuższy i z zobowiązaniem, celuję w okolice 0,35 s zamiast 0,20 s.
- **Flaska:** kilka łyków, picie trwa i zostawia odsłoniętym. Znika leczenie
  z zabójstw i skrzynki ze zdrowiem.

### W6. Myślenie stworów
- Zamiast samej kolejki: pasma odległości, wagi, losowanie z ziarna sesji (dziennik
  dalej odtwarza walkę co do klatki), ciągi, które czasem się wydłużają.
- **Reakcje** jako dane: picie flaski, przeładowanie, strzelanie z daleka, stanie za
  plecami, przyklejenie się na mniej niż 2 m.
- **Zachowanie między ciosami:** cofanie się, krążenie, czekanie, powolne podejście.
- **Duże ciało odpycha:** kara za przyklejenie i minimalny dystans, żeby sprite nie
  zasłaniał ekranu.

### W7. Przejście po wszystkich 40 ciosach
Każdy cios sześciu istot dostaje oś, tor, obrót i rolę. Liczby ustalają boty.
Margrabia i Furfur: walka idealnego bota 60-90 s zamiast 18-26 s, czyli wyższe HP
wobec salwy i mniej okien. Zamachy potrzebują widocznego kierunku, więc Codex astra
maluje nowe arkusze zamachów na sprawdzonej drodze ability, a tam, gdzie arkusz
odstaje od modelu, zostaje malowany ślad cięcia. Bazowe atlasy zostają bajt w bajt.

## Część II: ogniska

### O1. Stwory na stałych miejscach
Mapa `chapel`, samodzielna, bez kopiowania bazy z Limbo: te same malowane sale
połączone w drogę. Nowe pole mapy `garrison`: istota, miejsce, kierunek, zachowanie
(śpi, stoi, patroluje, zasadzka) i czy wraca. Stwór ma dom i smycz: gubi trop i wraca,
a nie staje w miejscu.

### O2. Ognisko
Rzecz świata z `session/entities.lua`, oparta na obecnym Żarze i jego grafice.
[E] odpoczynek: pełne zdrowie, flaski, amunicja, miejsce powrotu, zapis, powrót
zwykłych stworów. Bossowie i zabite wyjątki nie wracają. Menu ognia: wydawanie dusz
(obecny handel) i podróż między zapalonymi ogniskami. Nowy tryb w `run/modes.lua`
z własnym zapisem.

### O3. Śmierć, brama, skróty
Dusze zostają w miejscu zgonu (`echo` już to potrafi), druga śmierć je kasuje.
Powrót do ostatniego ogniska. Brama bossa zamyka się na czas walki i po wygranej zapala
kolejne ognisko. Skrót to drzwi otwierane z jednej strony. Zapis pamięta bossów,
ogniska, skróty i zniszczenia: filary i wyłomy zostają, drobiazgi wracają przy
odpoczynku.

### O4. Koniec fal i Limbo
Znikają fale, odliczanie, tiery fal, klasyczna arena i mapa Limbo. Zakres z dziś:
26 plików `src` mówi o falach, 20 plików testów i QA o Limbo, 63 używa starych trybów,
więc testy przechodzą na małą mapę-fiksturę. Poligon zostaje jako warsztat. Menu dostaje
nową grę i kontynuację, dokumenty i wersja 0.37, pełny `BUILD.ps1`.

## Odbiór

- „Stoi i strzela” przegrywa z każdym stworem poza pojedynczym Żarem, a z bossem ginie
  przy ponad 60% jego życia.
- Ostrzeliwany boss zadaje co najmniej 80% ciosów nieostrzeliwanego. Dziś około 50%.
- Bot uczący się dalej wygrywa każde starcie: żaden cios nie jest nieunikniony.
- Testy toru: wejście pod cios, obejście, unik przez cios, ściana zatrzymująca tor.
- Pełna droga: ognisko, śmierć, powrót po dusze, boss, kolejne ognisko, zapis i odczyt.
- Dziennik odtwarza walkę dokładnie, koszt klatki przy 20 ciałach bez regresji.
- Nagranie z gry po etapach W7 i O4. Ocena gracza jest osobna.

## Decyzje do zatwierdzenia

| Decyzja | Rekomendacja |
|---|---|
| Wytrzymałość na strzał i unik | Tak, to główny hamulec stania w miejscu |
| Flaska zamiast leczenia z zabójstw | Tak |
| Żar pada od dwóch salw, koniec podwójnych zabójstw jedną salwą | Tak, choć zmienia tożsamość strzelby |
| Broń biała | Nie teraz, egzekucja wystarczy |
| Filary i wyłomy zostają po odpoczynku | Tak |

## Kolejność

W0, W1, W2, W3, W4, W5, W6, W7, O1, O2, O3, O4. Etap W7 można wstrzymać do Twojej oceny
W1-W6 na jednym stworze: najpierw Margrabia, potem reszta.

## Źródła

- https://www.gamedeveloper.com/blogs/anatomy-of-an-enemy-attack-in-dark-souls-3
- https://bittide.aicompass.dev/article/dcc29290-7ba6-4dd2-bbab-e6f4bb84f34b?locale=en
- https://eldenring.wiki.gg/wiki/Stance
- https://darksouls.wiki.fextralife.com/Bonfire
