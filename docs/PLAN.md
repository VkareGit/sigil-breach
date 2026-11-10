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

## Kolejność

A1 → A2 → A3 → A4 → A5 → (stop: koniec etapu) → B1 → B2 → (stop: raport) →
C1 → C2 → C3 → C4… → (stop przy każdej zmianie liczby) → N1 → (stop: tabela)
→ N2. Etap B mówi, czy stwory wymagają przebudowy, zanim cokolwiek w nich
się zmieni.

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
- **B2. Raport** dla sześciu stworów do HISTORII i do oceny właściciela.
  Niczego nie stroimy.

### Etap C. Stwory jako pojedynki

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
