# Niezależny audyt SIGIL: BREACH (2026-11-03)

Wykonaj pełny, samodzielny audyt projektu gry. Drugi model wykonuje równolegle taki sam audyt z tej samej treści, ale nie widzisz jego wyników i nie wolno Ci na nie czekać ani ich szukać. Nie wdrażaj żadnych zmian: to wyłącznie analiza i plan. Nie przekazuj zadania nikomu dalej i nie zlecaj go innym modelom.

Odpowiadaj po polsku. Oceniaj kod w commicie `f69a19b` (wersja 0.42; katalog roboczy jest na tej wersji). Numery linii podawaj wobec tej wersji.

## Zasady pracy

- Nie modyfikuj niczego w `game/`, `tools/`, `docs/` ani w plikach głównych repozytorium. Nie rób commitów. Pliki robocze (sondy, wyniki, zrzuty) zapisuj tylko w `work/`.
- Pełny raport zapisz jako `AUDYT.md` w katalogu głównym repozytorium, w którym pracujesz, a na końcu wypisz ten sam raport jako odpowiedź końcową.
- Możesz uruchamiać testy, grę, bota, sondy i narzędzia pomiarowe. Oddziel to, co uruchomiłeś i zobaczyłeś, od tego, co tylko przeczytałeś. Jeżeli czegoś nie da się uruchomić, napisz dokładnie co i dlaczego. Pomiarów czasu nie puszczaj równolegle z innymi ciężkimi procesami; jeśli musisz, oznacz to.
- Nie ma żadnego zamówionego wyniku. Jeśli gra jest dobra w danym obszarze, napisz to. Nie zawyżaj liczby ustaleń.
- Nigdy nie zapisuj ani nie cytuj sekretów, tokenów i haseł, jeśli na jakieś trafisz.

## Materiały

Wszystkie ścieżki względem katalogu głównego repozytorium.

- Wejście i instrukcje: `START-HERE.txt`, `docs/KONTEKST.txt`, `game/docs/DEVELOPMENT.txt`, `game/docs/ARCHITEKTURA.txt`, `game/docs/ROZSZERZANIE.txt`, `game/docs/KONWENCJE.txt`.
- Jak gra działa dziś: `game/docs/INSTRUKCJA.txt`, `game/docs/ZMIANY.txt` i `game/docs/ODBIOR.txt` (najnowsze sekcje na górze; sekcja 0.42 opisuje zmiany po poprzednim audycie). Część dokumentów bywa starsza niż kod; rozstrzyga kod.
- Poprzedni podwójny audyt (0.41, 2026-11-02) i jego realizacja: `docs/audyt-2026-11-02/` (RAPORT-KONCOWY.md, AUDYT-CLAUDE.md, AUDYT-ASTRA.md, POSTEP.md, PROBA-WLASCICIELA.md, sondy). Sprawdź, co z niego naprawiono, co nadal występuje, a co straciło aktualność.
- Analizy rozgrywki po audycie: `docs/analiza-rozgrywki-2026-11-02/` (PLAN.md, KIERUNEK-HYBRYDA.md, OGNISKO-ULEPSZENIA.md); ich surowe odpowiedzi są w `work/gameplay-consult/`, `work/hybrid-consult/`, `work/fire-upgrades-consult/`, `work/ammo-consult/`. Część tych propozycji wdrożono w 0.42 (zob. ZMIANY-0.42), część nie.
- Starsze plany i założenia: `game/docs/KIERUNEK-ARTYSTYCZNY.txt`, `game/docs/PLAN-SOULS-v13.md`, `game/docs/PLAN-WALKA-SOULS.md`, `game/docs/PLAN-STRZELANIE.md`, `game/docs/ANATOMIA-I-FIZYKA-0.28.txt`, `game/docs/SYSTEM-SWIATA-0.14.txt`, `game/docs/PLAN-v13-*`, `docs/AUDYT-GOTOWOSCI-BAZY-v11.md`, `docs/POSTEP-NAPRAW-AUDYTU.md`.
- Burza mózgów o strzelaniu: `work/brainstorm/`. Notatki dźwiękowe: `work/sounds/notes.md`.
- Podręczniki właściciela (tylko do odczytu): `game/docs/PORADNIK-EDYCJI-GRY.md`, `docs/podrecznik-codex/`.
- Kod: `game/src` (gra), `game/tests` (testy), `game/qa` (przeglądy, bot `game/qa/souls_bot.lua`, pomiary), `tools/` (architektura, build, narzędzia), skrypty `*.ps1` w katalogu głównym.

Uruchamianie (Windows, PowerShell, LÖVE 11.5 w `toolchain/love-11.5-win64`):

- `.\TEST.ps1 -Suite Architecture`, `-Suite Mechanics`, `-Suite Input`, `-Suite Render`, `-Suite All`, parametr `-TestTimeoutSeconds`; wyniki w `work/qa`.
- Jeden zestaw: `$env:SIGIL_UI_QA_DIR=(Resolve-Path work\qa).Path; toolchain\love-11.5-win64\lovec.exe game --suite=<id>` (identyfikatory w `game/tests/suite.lua`). Ręczne uruchomienia bez tej zmiennej piszą do `work/qa-direct`.
- Rendery kaplicy: `$env:SIGIL_UI_QA_DIR` ustawione na istniejący katalog, potem `toolchain\love-11.5-win64\love.exe game --chapel-look`. Powstają pliki `look-*.png`.
- Pomiar klatek: `--frame-watch` (parametry w `DEVELOPMENT.txt`); pomiary rdzenia: `.\MEASURE.ps1`, `--core-measure`, `--benchmark`.
- Gra normalnie: `toolchain\love-11.5-win64\love.exe game`. Okno z błędem Lua potrafi wisieć bez komunikatu: uruchamiaj QA z ukrytym oknem i czytaj raporty.
- Sondy bez okna: ustaw te same limity JIT co `game/main.lua`, inaczej mierzą rekompilacje (pozorne zawieszenie).
- Jeżeli zapis do `%APPDATA%` jest zablokowany przez piaskownicę, przed każdym uruchomieniem LÖVE ustaw `$env:APPDATA=(Resolve-Path work\appdata).Path` (katalog `work\appdata\LOVE\sigil-breach-qa` musi istnieć).

## Założenia projektu podane przez właściciela

To są decyzje właściciela, nie interpretacje. Interpretacje i propozycje oznaczaj osobno.

- Gra: FPS w LÖVE 11.5 i LuaJIT, który staje się grą w stylu Souls. Rycerz bez magii, dwie bronie palne (Exorcist, strzelba; Judge, rewolwer), ładunek prochowy (Q), flaska (F), kaplica z ogniskami.
- Styl: żywy mroczny fresk. Styl demonów, HUD i broni ma się nie zmieniać.
- Dolny pasek: właścicielowi podoba się jego obecny design. Charakter, kształt, kompozycja i styl są chronione. Zadanie nie jest zgodą na jego przeprojektowanie.
- Bossowie są odłożeni. Margrave i Furfur to na razie zwykłe najtrudniejsze moby (elity).
- Kaplica to poligon testowy, nie docelowa mapa. Etap 4 poprzedniego planu (zakończenie kaplicy, mapa, druga droga; decyzje D5, D6) jest odłożony i nie wolno go zaczynać bez nowej zgody.
- Call of Duty jest odniesieniem tylko dla nagrody i potwierdzenia po strzale, nie dla mechaniki strzelania. Gra ma zostać Souls-like. Doom jest odniesieniem dla znajdziek na mapie (wdrożone w 0.42 jako wariant „wracają przy odpoczynku i śmierci”).
- Strzał nie bierze wytrzymałości, kosztuje chwilę ciała po strzale (plan 1–6 w `PLAN-STRZELANIE.md`).
- Serie zabójstw dają bonusy tylko na broni, z której były robione. Medal pojawia się chwilowo u góry ekranu, stała informacja o serii jest cicha.
- Decyzje z 2026-11-02 (po poprzednim audycie):
  - D1: ognisko odmawia odpoczynku z powodem, gdy rycerza ściga czuwający stwór.
  - D2: amunicja pochodzi ze stworów: każda rodzina daje przewidywalny rodzaj naboi; zwykłe zabójstwo ma szansę na małą paczkę o lekko losowej wielkości; ryzykowna akcja (egzekucja z bliska) daje pewny, skromny zwrot; rzadka amunicja do najmocniejszej broni pochodzi z trudniejszych przeciwników.
  - D3: unik ogranicza tylko wytrzymałość (bez ładunków), regeneracja pod szybką walkę, zwykły ruch bez kosztu.
  - D4: zaalarmowane stwory w otwartej przestrzeni ruszają wszystkie, także te z tyłu; oddzielone części sali budzą się grupą przy wejściu albo gdy dotrze alarm; przed wykryciem część patroluje, część stoi na warcie.
  - D7: Furfur płaci tyle dusz co Margrave.
- Właściciel zgłaszał wcześniej: mobów, które widzi, nie powinno być widać czekających; wejście (strzał, unik) ma być responsywne; opóźnienia mają być widoczne, a nie wyglądać na zawieszenie; „ciągły brak naboi”; elity były „gąbkami”; stwory „stały i nic nie robiły”. Część z tego zmieniono w 0.42; nie zakładaj, że skutecznie.
- Zmiany 0.42 wprowadzone na prośbę lub za wyborem właściciela, ale bez potwierdzonej oceny po grze: znajdźki jak w Doomie (amunicja i łyki flaski na mapie), grawery i hartowanie broni przy ognisku, krótsze elity, pieczęcie Goecji jako śluby, ognisko zabezpieczające oczyszczone odcinki zamiast odradzania świata, odnawianie naboi Judge'a do 6. Oceń je tak samo krytycznie jak resztę.
- Tekst w grze i na nagraniach jest po angielsku. Dokumenty w `game/docs` po polsku.
- Usuwać, nie przenosić: stary kod odzyskuje się z historii. Rozmiar pracy nie jest powodem do odkładania.
- Bez budowania EXE i ZIP, dopóki właściciel nie poprosi. Uruchamia grę przez `love .`.
- Muzykę, dźwięki, grafikę, modele i nagrania wykonuje Codex; kod i mechaniki może robić Claude albo Codex.
- Właściciel: „pracujemy razem ja i wy, a nie wy dla mnie”. Jego spostrzeżenia (na końcu prompta) masz wziąć pod uwagę i przemyśleć, a nie przyjąć bez sprawdzenia.

Jeśli czegoś nie można ustalić, nazwij niepewność i oceń, czy blokuje analizę.

## Zakres audytu

### 2. USTAL STAN PROJEKTU I JEGO FILARY

Przeczytaj obowiązujące instrukcje repozytorium, dokumentację, wcześniejsze ustalenia i poprzedni audyt. Sprawdź, co zostało poprawione, co nadal występuje, a co straciło aktualność.

Wyodrębnij:
- główną pętlę rozgrywki i zamierzone doświadczenie gracza;
- styl artystyczny i charakter interfejsu;
- założenia dotyczące walki, tempa, trudności i progresji;
- istniejące inspiracje oraz ograniczenia techniczne;
- logikę całego kodu;
- silnik fizyczny świata: czy jest spójny;
- czy trzeba go dopracować;
- czy każdy pocisk jest osobny (czyli ma wysokość, szybkość, czy można go zdodgować);
- uwaga twórcy: może bronie potworów powinny być oddzielone od ich ciał (nawet jeśli nie graficznie, to na ciele potwora, by ciało mogło zachowywać się inaczej, a broń mieć jeszcze własne właściwości);
- ogólnie przemyśl całość.

Oddziel potwierdzone decyzje właściciela od swoich interpretacji i propozycji. Nie wymyślaj brakujących założeń. Jeżeli czegoś nie można ustalić, nazwij niepewność i oceń, czy rzeczywiście blokuje analizę.

### 3. AUDYT CAŁOŚCI KODU, JAKOŚCI I SKALOWALNOŚCI

Zmapuj cały kod projektu. Nie ograniczaj analizy do ostatnio zmienionych plików. Głębokość przeglądu dopasuj do znaczenia i ryzyka systemów, a na końcu wskaż zakres faktycznie sprawdzony i obszary nieweryfikowane.

Oceń:
- poprawność działania i zgodność implementacji z założeniami;
- architekturę, odpowiedzialności modułów, zależności i zarządzanie stanem;
- czytelność, duplikację, zbędną złożoność i dług techniczny;
- podatność na błędy i regresje;
- wydajność, zużycie zasobów oraz potencjalne wąskie gardła;
- możliwość dodawania kolejnych mechanik, przeciwników, broni, poziomów i treści;
- zachowanie przy większej liczbie obiektów, przeciwników, efektów i zdarzeń;
- możliwość testowania, diagnozowania problemów i utrzymywania projektu.

Rozróżnij skalowalność wydajnościową od skalowalności architektury i procesu tworzenia treści. Oceniaj je względem rzeczywistych potrzeb gry. Nie proponuj przepisywania systemów ani rozbudowanej infrastruktury bez konkretnej korzyści.

Każde istotne ustalenie poprzyj dowodem: plikiem i funkcją, zależnością, pomiarem albo odtwarzalnym scenariuszem. Wyraźnie oddziel potwierdzone błędy, ryzyka, hipotezy i preferencje projektowe.

### 4. ODBIÓR GRY I DOŚWIADCZENIE GRACZA

Oceń grę z perspektywy osoby, która nie zna kodu ani intencji autora.

Przeanalizuj pierwsze minuty, naukę zasad, zwykłą i intensywną walkę, porażkę, ponowną próbę oraz dalszą progresję.

Sprawdź:
- czy gracz rozumie cel i dostępne działania;
- czy sterowanie i reakcje gry są responsywne, czytelne i spójne;
- czy wiadomo, dlaczego gracz otrzymał obrażenia, przegrał albo odniósł sukces;
- czy tempo, poziom trudności, nagrody i kary wspierają zamierzone doświadczenie;
- gdzie występują frustracja, chaos informacyjny, przestoje lub niejasne reguły;
- czy mechaniki są satysfakcjonujące także w połączeniu, a nie tylko osobno;
- czy ogniska to na pewno dobry pomysł w tego typu grze. Właściciel ciągle daje propozycje pójścia bardziej w stronę Dooma z usunięciem ognisk (czyli zbieranie wzmocnień, sigili, heali, flasek itd. z ziemi i znajdziek jak w Doomie, ale inaczej; zamiast z ogniska, buffy do broni też jakoś). Trzeba to przemyśleć: czy to, co robimy, to na pewno dobra droga.

Oddziel zamierzoną trudność od trudności wynikającej z nieczytelności, opóźnień, błędów lub niespójnych zasad.

Jeżeli możesz uruchomić grę, sprawdź najważniejsze scenariusze w działaniu. Nie przedstawiaj czytania kodu jako playtestu ani własnej oceny jako opinii rzeczywistych graczy. Przy braku dostępu do gry oznacz ograniczenia i zaproponuj konkretne scenariusze weryfikacji.

### 5. GUI, CZYTELNOŚĆ I STYL ARTYSTYCZNY

BARDZO WAŻNE: właścicielowi podoba się obecny design dolnego paska. Zachowaj jego charakter, kształt, kompozycję i styl. Nie traktuj tego zadania jako zgody na jego przeprojektowanie.

Chodzi przede wszystkim o to, jak widoczne i zrozumiałe są prezentowane informacje:
- tekst, cyfry, ikony i komunikaty;
- wielkość i grubość fontów;
- kontrast względem tła;
- odstępy, wyrównanie i hierarchia informacji;
- obcinanie tekstu i nakładanie się elementów;
- skalowanie przy obsługiwanych rozdzielczościach;
- widoczność informacji podczas ruchu, walki i intensywnych efektów;
- szybkość odczytywania najważniejszych danych.

Oceń cały interfejs, ze szczególnym uwzględnieniem treści dolnego paska. Uwzględnij zarówno spokojne sytuacje, jak i najbardziej wymagające momenty rozgrywki.

Proponuj możliwie małe, skuteczne zmiany, które poprawiają czytelność i zachowują tożsamość wizualną gry. Nie zamieniaj charakterystycznej oprawy w generyczny interfejs.

Każdą ważną rekomendację opisz jako:
problem → sytuacja gracza → proponowana poprawka → spodziewany efekt → sposób sprawdzenia.

Jeżeli poprawa wymagałaby naruszenia chronionego designu, przedstaw ją osobno jako wariant wymagający decyzji właściciela.

### 6. MECHANIKI, TRUDNOŚĆ I SPÓJNOŚĆ INSPIRACJI

Zweryfikuj działanie mechanik względem ogólnych założeń projektu oraz istniejących inspiracji Souls, Call of Duty, Doom i innych wcześniej ustalonych punktów odniesienia.

Nie traktuj tych gier jako listy funkcji do skopiowania. Sprawdź, czy obecne inspiracje tworzą spójną całość i wspierają własną tożsamość projektu.

Przeanalizuj:
- tempo walki, mobilność i pozycjonowanie;
- responsywność sterowania i używania broni;
- zachowanie przeciwników oraz czytelność zagrożeń;
- zarządzanie zdrowiem, amunicją i innymi zasobami;
- ryzyko, nagradzanie decyzji i karanie błędów;
- krzywą trudności, uczenie się i progresję;
- przepływ rozgrywki i informacje zwrotne.

Uwzględniaj systemy faktycznie obecne lub zaplanowane w projekcie — nie zakładaj, że każda wymieniona mechanika musi istnieć.

Wskaż, co działa dobrze i należy zachować, gdzie inspiracje się wzmacniają, a gdzie ich założenia wchodzą w konflikt. Oceń skutki dla odbioru gracza, trudności, jakości, dalszej rozbudowy i kosztu utrzymania.

Nie upraszczaj automatycznie gry tylko dlatego, że jest trudna. Sprawdź, czy trudność jest zamierzona, uczciwa, czytelna i możliwa do opanowania.

### 7. WYMAGANY WYNIK AUDYTU

Przygotuj:
- krótką ocenę aktualnego stanu gry;
- mocne strony, które należy zachować;
- listę ustaleń z dowodami i poziomem pewności;
- najważniejsze ryzyka techniczne i problemy doświadczenia gracza;
- rekomendacje dotyczące GUI i mechanik;
- proponowany plan poprawek i rozwoju;
- ograniczenia analizy oraz pytania wymagające weryfikacji.

Każde zadanie w proponowanym planie powinno mieć:
- identyfikator i priorytet;
- opis problemu oraz dowód;
- proponowaną zmianę i jej zakres;
- korzyść dla gracza lub projektu;
- zależności i kolejność realizacji;
- orientacyjny nakład pracy oraz ryzyko regresji;
- sprawdzalne kryteria ukończenia.

Oddziel konieczne naprawy, usprawnienia i opcjonalny rozwój. Nie podawaj pozornie dokładnych terminów bez podstaw.

Odpowiedz też wprost (z dowodami) na pytania właściciela z punktów 2 i 4: spójność fizyki świata, czy każdy pocisk jest osobnym obiektem z wysokością i szybkością i czy da się go uniknąć, czy broń stwora powinna być oddzielona od jego ciała, oraz czy ogniska czy pętla bliższa Doomowi są lepszą drogą.

Zwięzłość: zależy nam na rzetelności, konkretnych dowodach i użytecznym planie, a nie na długości raportu.

## Spostrzeżenia właściciela do rozważenia

Właściciel: „to są moje spostrzeżenia, macie wziąć je pod uwagę, ale też przemyśleć; pracujemy razem ja i wy, a nie wy dla mnie”. To hipotezy do sprawdzenia w kodzie i w grze, nie decyzje. Oceń każdą: czy problem występuje w tej grze, dowód, i czy proponowane rozwiązanie pasuje do Souls-like z bronią palną.

Przewidywalne SI wrogów:
Czy wrogowie idą po prostej linii prosto na gracza? Wystarczy wtedy cofać się i strzelać (tzw. kite'owanie).
Rozwiązanie: Dodaj wrogów, którzy próbują flankować, skakać na boki, albo takich, którzy zostawiają za sobą strefy zagrożenia (np. trujące plamy/ogień), odcinając drogi ucieczki.

Szybkość pocisków przeciwników:
Jeśli pociski wrogów latają zbyt wolno, gracz z łatwością ich unika bez używania Perfect Dodge.
Rozwiązanie: Zwiększ prędkość pocisków lub dodaj wrogów z atakami obszarowymi / hitscanem (z krótkim telegrafowaniem – np. laserem celowniczym przed strzałem).

Za duże marginesy błędów przy unikach (I-frames):
Jeśli ramka nietykalności podczas uniku/parowania jest zbyt długa, mechanika przestaje wymagać wyczucia czasu, a staje się przyciskiem „darmowa ucieczka”.

W retro-FPS-ach uczucie mięsistego, satysfakcjonującego strzelania (tzw. gunplay) rzadko zależy od samego kodu broni – w 80% to kwestia audio-wizualnego feedbacku (tzw. game juice).

Brak/słaby Screen Shake: Wybuchy i strzały z mocniejszych broni potrzebują dynamicznego, krótkiego drgania kamery (z zależnością od dystansu).

Brak reakcji wrogów na trafienie (Hitstun / Hitstop):
Gdy wróg oberwie, powinien na ułamek sekundy (np. 2–3 klatki) zamrozić się w klatce bólowej lub odskoczyć w tył (knockback).
Brakuje mocniejszego efektu wizualnego na samym wrogu (np. błysk na biało przez 1 klatkę przy trafieniu – tzw. hit flash).

Animacja broni i odrzut (Kickback): Jeśli broń po strzale tylko lekko przesuwa się w dół i wraca, daje to wrażenie pistoletu na kulki. Potrzebne są silne, szybkie przesunięcia pistoletu/oręża w stronę gracza i obrót na boki z wolniejszym powrotem.

Dźwięk (Audio punch): Często bas w odgłosach strzałów i wybuchów jest zbyt płaski. Dobry dźwięk strzału ma warstwę basową, klik mechaniczny i wyraźny odgłos trafienia w cel (tzw. hit sound).

Ogólnie to tylko kilka takich, co przychodzi mi do głowy.
