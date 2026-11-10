# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-10: dopracowanie bazy gry (etapy A–D), przyjęte, wdrażanie trwa.**
Właściciel: „Akceptuję, zaczynaj” po przedstawieniu przeglądu napraw Z1–Z13,
analizy kierunku gry i tego planu z rekomendacjami K1–K3. Punkt wyjścia:
`8cce94e`, 0.46; pełna brama Linux `TEST.sh All --jobs 4` PASS, 9458
sprawdzeń, Input, pokaz, narzędzia (`startup-check`, `resource-plateau`,
`measure-trial`). Przegląd i analiza: HISTORIA, „Przegląd po naprawach
i kierunek gry (2026-11-10)”. Poprzedni plan (naprawy z audytu silnika
Z1–Z13) jest w całości w HISTORII.

Cel: dopracować bazę gry przed jej rozwojem. Mapa i struktura świata są
poza planem: obecna kaplica to mapa testowa, mapa gry będzie inna
(właściciel, 2026-11-10).

Zasady pracy: `docs/AGENTS.md`. Każdy krok osobno: czerwony test albo sonda
odtwarzająca problem, zmiana, dowód przed/po, pełna brama
`scripts/linux/TEST.sh All --timeout 1800`, wpis w ZMIANY/ODBIOR 0.46
i w Postępie, commit (bez push). Zatrzymanie i czekanie na właściciela,
gdy: (a) zmienia się golden; (b) zmiana dotyczy balansu (HP, obrażenia,
zegary SI, elity, kadencja, rozrzut); (c) zmiana wymagałaby nowej
ilustracji, tekstury albo zmiany HUD-u; (d) brama jest czerwona z przyczyny
spoza bieżącego kroku; (e) kończy się etap. Nie osłabiamy oczekiwań testów
i nie przesuwamy fixture'ów. Sondy i pliki robocze poza repozytorium
(`/home/nahiko/Work/tries/sigil-breach-audit-measure`).

## Decyzje właściciela (2026-11-10, wiążące)

Pełny zapis w WIZJI (D21–D23).

- **K1 (D21): walka to pojedynek z każdym stworem.** Grupy 3–6 czuwających,
  bez hord. Stwory nie giną od jednego strzału. Optymalizacja tłumu (Z10a)
  zostaje odłożona.
- **K2 (D22): ekonomia to same znajdźki.** Znikają portfel dusz, ceny, sklep
  i echo dusz; Exorcist staje się znaleziskiem. Ognisko: zapis, odrodzenie,
  uzupełnienie i zmiana zestawu. Zmienia D12, D13 i D16; do wdrożenia
  w etapie D obecny sklep działa bez zmian.
- **K3 (D23): dwa prototypy mechanizmów stworów tylko na Ember Thrallu:**
  rana części i zmęczenie. O reszcie stworów decyduje pomiar z etapu B.
- Tryb w stylu Vampire Survivors nie jest kierunkiem gry.
- **D24: ogień nie odbiera ciosów** („tylko parada”): cios raz podjęty
  dochodzi; przerywa go strzał w oknie parady; złamana garda i ciężka rana
  w trakcie ciosu działają po ciosie. Dla każdego stwora; elity na osobne
  polecenie.
- **D25: dwa rodzaje stworów:** drobnica (Ember Thrall, Star Acolyte,
  Plague Gardener) i pojedynkowe (Iron Thrall, elity).
- **Progi miernika** (WIZJA): pojedynkowy: stojący ≤ 1/5, nieczytający
  ≤ 2/5, mistrz 5/5 i ≤ 25 obrażeń, mistrz ≥ 1,5 raza szybszy od
  nowicjusza; trójka drobnicy: nieczytający ≤ 2/5, mistrz ≥ 4/5.
- Exorcist: wolno proponować zmianę liczb po pomiarze. A5 przyjęte.
- **Uwaga właściciela po przyjęciu planu (2026-11-10):** stwory nie są dziś
  wymagające. Tempo jest szybkie, SHIFT daje unik z przeskokiem w bok,
  CTRL ślizg, więc walka często sprowadza się do skakania i unikania przez
  cały czas, bez radości z czytania ruchów. Do przemyślenia i dopracowania;
  termin ustala wykonawca. Miejsce w planie: pomiar w B1 (bot, który nie
  czyta) i krok C0 przed stworami.

## Kolejność

A1 → A2 → A3 → A4 → A5 → (stop: koniec etapu) → B1 → B2 → (stop: raport) →
C0 → (stop: propozycja) → C1 → C2 → C3 → C4… → (stop przy każdej zmianie
liczby) → N1 → (stop: tabela) → N2. Etap B mówi, czy stwory wymagają
przebudowy, zanim cokolwiek w nich się zmieni. C0 stoi przed stworami,
bo stwora nie da się ustawić, dopóki unik bez czytania wystarcza na
wszystko: każda liczba stwora jest względem obrony rycerza.

## Kroki

### Etap A. Domknięcie fundamentu (niezależne od mapy)

- **A1. Kontrakt wznowienia zalicza pominięte przypadki.** W `contracts`
  atak, który w fixturze nie dojdzie do zamachu albo ciosu, zwraca `nil`
  i sprawdzenie przechodzi (dziś 2 ze 106). Czerwony test: przypadek
  pominięty, którego nie ma na jawnej liście z powodem, jest błędem. Zmiana
  tylko w teście. Golden bez zmian.
- **A2. Strona wczytywania przygotowuje stwory tylko obszaru rycerza.**
  `P.creatures` (`run/pilgrimage.lua`) czyta garnizon jednego obszaru, a
  `populate` stawia garnizony całej mapy (ta sama klasa co Z6). Sonda
  `prepared`: rycerz w obszarze próbnym, przygotowany tylko Ember Thrall,
  na mapie pięć rodzin. Czerwony test w `pilgrimage` z obszarem próbnym.
  Zmiana: iteracja po `Way.areasOf(mapa)`. Golden bez zmian.
- **A3. Walidator obszarów pamięta posterunki po wyrejestrowaniu
  i po odrzuceniu.** `content/pilgrimage.lua` (`posts`, `mapPosts`) trzyma
  identyfikatory także wtedy, gdy obszar zniknął albo nie został przyjęty.
  Czerwony test: ten sam obszar rejestruje się drugi raz po wyrejestrowaniu;
  odrzucona definicja niczego nie zostawia. Golden bez zmian.
- **A4. Akcenty ataków pytają o rodzaj po nazwie (reszta Z7).**
  `render/cast_accents.lua` (blink, salvo, storm), `feedback/world_feedback.lua`
  (blink), `render/painters/pigment.lua` (stream, sow)
  i `feedback/rite_feedback.lua` (beam, wave). Zmiana bez zmiany obrazu:
  wpisy rodzaju zamiast porównań nazw. Test: rodzaj ataku z własnym akcentem
  dodany samymi rejestrami. Rendery pokazu identyczne, golden bez zmian.
- **A5. Pomiar przed/po napraw Z1–Z13.** `MEASURE.sh` w 3 parach
  (`a7d1de4` wobec `8cce94e`) nie rozstrzygnął: wszystkie mediany po
  zmianach wyższe o 2–20 %, w granicach rozrzutu. Powtórka w 7 parach na
  bezczynnej maszynie; wynik do HISTORII. Bez zmian gry. Regresja: STOP
  i raport.

### Etap B. Miernik głębi walki (bez zmian gry)

- **B1. Narzędzie.** Dla każdego stwora trzy boty (nowicjusz, sprawny,
  mistrz) na istniejących botach QA. Wynik: czas zabicia, zużyte naboje,
  otrzymane obrażenia, udział zabójstw kontrą i egzekucją, liczba różnych
  sytuacji w walce. Stwór, którego mistrz zabija mniej niż dwa razy szybciej
  niż nowicjusz, jest gąbką. Narzędzie QA, nie zmienia symulacji.
  Czwarty bot nie czyta niczego: skacze, ślizga się i unika, gdy tylko ma
  wytrzymałość (obok istniejących `Bot.reflex` i `Bot.oneSide` z
  `qa/souls_bot.lua`, „rycerz, którego walka nie ma nagradzać”). Druga
  miara, premia za czytanie: o ile lepiej wypada bot czytający zapowiedzi
  od nieczytającego (otrzymane obrażenia, czas zabicia, zużyte zasoby),
  osobno dla jednego stwora i dla grupy 3–6. Premia bliska zera potwierdza
  uwagę właściciela liczbą. Punkt wyjścia z danych rycerza
  (`content/knight.lua`): unik 2,5 m w 0,155 s, nietykalność 0,32 s, koszt
  26 ze 100 wytrzymałości, odnowa 48/s po 0,4 s; trzy uniki z rzędu, potem
  jeden co ok. 0,9 s, czyli około jednej trzeciej czasu w nietykalności
  bez żadnego czytania; skok i ślizg (8,7 m/s przez 0,52 s) nic nie
  kosztują; idealny unik zwraca wytrzymałość.
- **B2. Raport** dla sześciu stworów do HISTORII i do oceny właściciela.
  Niczego nie stroimy.

### Etap C. Stwory jako pojedynki

- **C0. Ruch rycerza a czytanie** (uwaga właściciela, 2026-11-10; przed
  stworami). Z liczb B2: propozycja do akceptacji, jak sprawić, żeby unik
  na oślep przestał wystarczać, a czytanie się opłacało, bez odbierania
  tempa i responsywności ruchu. Dźwignie do zważenia, nie decyzje: koszt
  i odnowa wytrzymałości, długość nietykalności wobec długości uniku,
  odpowiedzi stworów na unik za wczesny i na skok (dziś `dodged` mają
  tylko elity), opóźnione ciosy, ataki łapiące ruch w bok, koszt ślizgu
  i skoku, nagroda za unik w porę (idealny unik) wobec uniku zawczasu.
  Każda zmiana liczby to zmiana balansu: osobny commit, pomiar miernikiem
  przed i po, zgoda właściciela. Zmienia golden.
  Pomysły wykonawcy do oceny w C0 i C1 (wizja walki właściciela w WIZJI;
  kandydaci, nie decyzje):
  1. *Stój i czytaj.* W grze z samą bronią palną ryzykiem nie jest
     bliskość, tylko stanie z uniesioną lufą, gdy cios już leci. Parada
     strzałem (`combat/rules/balance.lua`: strzał w ostatnich 0,16–0,3 s
     zamachu przerywa cios i odsłania ciało do egzekucji) już istnieje;
     ma stać się osią walki: każdy atak ma okno parady albo inną odpowiedź
     lepszą niż ucieczka.
  2. *Unik jest bezpieczny i nic nie daje.* Kto tylko unika, powoli
     przegrywa zasobami: egzekucja zawsze oddaje naboje, zwykłe zabicie
     z szansą (D2). Do zmierzenia w B: bilans nabojów na zabicie.
  3. *Unik kosztuje strzał.* Dziś po strzale ciało przez 0,12–0,22 s nie
     może unikać; w drugą stronę kosztu nie ma. Kandydat: broń po uniku
     potrzebuje chwili.
  4. *Stwór odpowiada na nawyk.* Tabela `answers` zna dziś przeładowanie,
     picie, przyklejenie, obejście, unik i strzał z daleka. Kandydaci:
     unik zawczasu (zanim cios się zablokuje), ciągle ta sama strona,
     skakanie. To „łapanie przewrotu” z Souls, w danych.
  5. *Wzorzec zmienia się przez to, co zrobił gracz* (rana części, K3)
     i przez to, co zrobił stwór (zmęczenie, K3).
  6. *Porażka uczy.* Po śmierci nazwany cios, który zabił, i bestiariusz,
     który dopisuje ataki poznane i te, na które rycerz odpowiedział.
     Wymaga decyzji o ekranie (HUD chroniony).
  7. *Grywalność ponowna bez nowej grafiki:* śluby pokutne (rycerz sam
     nakłada sobie ograniczenia za nagrodę), drugie czytanie stwora
     (te same klatki, nowe łańcuchy i odpowiedzi na dalszym kręgu), próby
     i rewanże w komnatach poligonu z medalami za sposób zabicia.

- **C1. Karta każdego stwora** (dokument, do akceptacji): lekcja w jednym
  zdaniu, 2–3 pytania z odpowiedziami, skrót dla mistrza, wynik z B2.
- **C2. Prototyp: rana części** (K3) tylko na Ember Thrallu: trafienia
  w część ciała zmieniają to, co stwór może zrobić. Stan w zapisie, test
  rozszerzeń, kontrakt wznowienia. Bez nowych klatek; jeśli mechanizm
  wymaga nowej ilustracji: STOP.
- **C3. Prototyp: zmęczenie** (K3) tylko na Ember Thrallu: po długiej
  serii większe okno kary. Te same wymagania co C2.
- **C4. Po jednym stworze naraz** według kart i pomiaru. Każda zmiana
  liczby to osobny commit z pomiarem miernikiem przed i po oraz zgodą
  właściciela.

### Etap D. Ekonomia według K2

Kroki noszą oznaczenia N1 i N2, żeby nie mylić ich z decyzjami D1–D23.

- **N1. Tabela** (do akceptacji przed kodem): każda pozycja sklepu staje
  się znaleziskiem, funkcją ogniska albo znika; co dzieje się z duszami
  w starych zapisach.
- **N2. Wdrożenie** z migracją zapisu i uzasadnionym wzorcem golden.

## Kontekst, którego nie zmieniamy

- Wytrzymałość stworów przyjęta: Ember Thrall 360 HP (2 salwy Exorcista albo
  6 kul Judge'a w tułów), Iron Thrall 4 salwy albo 11 kul. Zmiany tylko
  w etapie C, pojedynczo, za zgodą.
- Nienaruszalna spójność grafiki, chroniony HUD, D20 (bez nowych broni).
- Dźwięku nikt nie odsłuchiwał; wybór A/B strzelby czeka na właściciela.
- Raz na minutę seria 5–6 klatek powyżej 16,7 ms w walce (frame-watch),
  także bez GC; przyczyna nieznana.

## Postęp i dowody

- 2026-11-10: decyzje właściciela po raporcie B2 i doświadczeniach C0:
  D24 w brzmieniu „tylko parada”, D25 (drobnica i stwory pojedynkowe),
  progi miernika, zgoda na propozycje dla Exorcista, A5 przyjęte. Bez
  zmian gry.
- 2026-11-10: właściciel przyjął D24 (ogień nie odbiera ciosów). Sześć
  doświadczeń w drzewie roboczym, zmierzonych miernikiem i cofniętych
  (HISTORIA, „Doświadczenia C0”): sama zasada zmienia mało; nieczytającego
  chroni ruch, nie nietykalność ani koszt uniku; wzorcem pojedynku jest
  Iron Thrall. C0 czeka na decyzje właściciela: podział na drobnicę
  i stwory pojedynkowe oraz progi miernika. Bez zmian gry.
- 2026-11-10, **B2 zrobione, etap B zamknięty:** raport w HISTORII. Trzy
  z czterech zwykłych stworów przegrywają z rycerzem, który stoi i strzela;
  wymagają tylko te, które zachowują ciosy pod ogniem; wiedza nie skraca
  walki. Trzy pytania do właściciela przed C0.
- 2026-11-10, **B1 zrobione:** miernik głębi walki (`--depth-meter`):
  sześciu rycerzy, osiem walk, dwa uzbrojenia; zestaw `depth-meter`
  w bramie. Bez zmian gry, golden bez zmian.
- 2026-11-10, **A5 zrobione, werdykt do decyzji:** 7 par, po/przed
  0,89–1,06 ze znakami w obie strony, żadna różnica ponad rozrzut;
  protokół nadal INCONCLUSIVE, bo rozrzut maszyny (IQR 6–21 %) jest
  większy niż jego próg 5 %. Etap A zamknięty.
- 2026-11-10: uwaga właściciela o uniku na oślep i braku czytania ruchów
  wpisana do planu: czwarty bot i premia za czytanie w B1, krok C0 przed
  stworami. Bez zmian gry.
- 2026-11-10, **A4 zrobione:** akcenty, głos uwolnienia i osiadający obraz
  pytają o cechy rodzaju ataku; rendery identyczne, golden bez zmian.
- 2026-11-10, **A3 zrobione:** walidator obszarów pyta stojące obszary
  zamiast własnej pamięci; obszar da się przyjąć ponownie i zastąpić.
  Golden bez zmian.
- 2026-11-10, **A2 zrobione:** strona wczytywania przygotowuje stwory
  wszystkich obszarów mapy, nie tylko obszaru rycerza. Golden bez zmian.
- 2026-11-10, **A1 zrobione:** kontrakt wznowienia ma jawne sprawdzenie
  dojścia do zamachu i ciosu; zbiór Ogrodnika jest teraz zapisywany
  i zabijany w trakcie (wcześniej zaliczany bez próby). Golden bez zmian.
- 2026-11-10: plan A–D przyjęty; poprzedni PLAN oraz przegląd po naprawach
  z analizą kierunku w HISTORII; decyzje D21–D23 w WIZJI. Bez zmian gry.

## Poza zakresem

Mapa i struktura świata (także „Zejście”), zwalnianie obrazów obszaru (Z8),
wariant B przebudzenia (Z1), niepodzielna porcja 1,5 s przy wejściu na pole,
optymalizacja tłumu (Z10a), bossowie, nowe bronie (D20), Windows, pakowanie
i wideo. Podział pokazu (G6) i wybór A/B Exorcista pozostają otwarte.
