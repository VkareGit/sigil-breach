# Niezależny audyt SIGIL: BREACH

Wykonaj pełny, samodzielny audyt projektu gry. Drugi model wykonuje równolegle taki sam audyt z tej samej treści, ale nie widzisz jego wyników i nie wolno Ci na nie czekać ani ich szukać. Nie wdrażaj żadnych zmian: to wyłącznie analiza i plan. Nie przekazuj zadania nikomu dalej.

Odpowiadaj po polsku. Oceniaj kod w commicie `489e3a5` (katalog roboczy jest na tej wersji). Numery linii podawaj wobec tej wersji.

## Zasady pracy

- Nie modyfikuj niczego w `game/`, `tools/` ani w plikach głównych repozytorium. Nie rób commitów. Pliki robocze zapisuj tylko w `work/`.
- Pełny raport zapisz jako `AUDYT.md` w katalogu głównym repozytorium, w którym pracujesz, a na końcu wypisz ten sam raport jako odpowiedź końcową.
- Możesz uruchamiać testy, grę, bota i narzędzia pomiarowe. Oddziel to, co uruchomiłeś i zobaczyłeś, od tego, co tylko przeczytałeś. Jeżeli czegoś nie da się uruchomić, napisz dokładnie co i dlaczego.
- Nie ma żadnego zamówionego wyniku. Jeśli gra jest dobra w danym obszarze, napisz to. Nie zawyżaj liczby ustaleń.
- Nigdy nie zapisuj ani nie cytuj sekretów, tokenów i haseł, jeśli na jakieś trafisz.

## Materiały

Wszystkie ścieżki względem katalogu głównego repozytorium.

- Wejście i instrukcje: `START-HERE.txt`, `game/docs/DEVELOPMENT.txt`, `game/docs/ARCHITEKTURA.txt`, `game/docs/ROZSZERZANIE.txt`, `game/docs/KONWENCJE.txt`.
- Jak gra działa dziś: `game/docs/INSTRUKCJA.txt`, `game/docs/ZMIANY.txt`, `game/docs/ODBIOR.txt` (najnowsze sekcje na górze). Część dokumentów jest starsza niż kod; rozstrzyga kod.
- Założenia i plany: `docs/KONTEKST.txt`, `game/docs/KIERUNEK-ARTYSTYCZNY.txt`, `game/docs/PLAN-SOULS-v13.md`, `game/docs/PLAN-WALKA-SOULS.md`, `game/docs/PLAN-STRZELANIE.md`, `game/docs/PLAN-v13-*`, `docs/AUDYT-GOTOWOSCI-BAZY-v11.md`.
- Poprzedni audyt i jego naprawy: `work/audit/claude.md`, `work/audit/codex-report.md`, `docs/POSTEP-NAPRAW-AUDYTU.md`.
- Burza mózgów o strzelaniu: `work/brainstorm/`. Notatki dźwiękowe: `work/sounds/notes.md`.
- Podręczniki: `game/docs/PORADNIK-EDYCJI-GRY.md`, `docs/podrecznik-codex/`.
- Kod: `game/src` (gra), `game/tests` (testy), `game/qa` (przeglądy, bot, pomiary), `tools/` (architektura, build, narzędzia), skrypty `*.ps1` w katalogu głównym.

Uruchamianie (Windows, PowerShell, LÖVE 11.5 w `toolchain/love-11.5-win64`):

- `.\TEST.ps1 -Suite Architecture`, `-Suite Mechanics`, `-Suite Input`, `-Suite Render`, `-Suite All`, parametr `-TestTimeoutSeconds`; wyniki w `work/qa`.
- Jeden zestaw: `$env:SIGIL_UI_QA_DIR=(Resolve-Path work\qa).Path; toolchain\love-11.5-win64\lovec.exe game --suite=<id>`.
- Rendery kaplicy: `$env:SIGIL_UI_QA_DIR` ustawione na istniejący katalog, potem `love.exe game --chapel-look`. Powstają pliki `look-*.png`.
- Pomiar klatek: `--frame-watch`; pomiary rdzenia: `.\MEASURE.ps1`, `--core-measure`, `--benchmark`. Bot: `game/qa/souls_bot.lua`.
- Gra normalnie: `toolchain\love-11.5-win64\love.exe game`.
- Jeżeli zapis do `%APPDATA%` jest zablokowany przez piaskownicę, przed każdym uruchomieniem LÖVE ustaw `$env:APPDATA=(Resolve-Path work\appdata).Path` (katalog `work\appdata\LOVE\sigil-breach-qa` musi istnieć).

## Założenia projektu podane przez właściciela

To są decyzje właściciela, nie interpretacje. Interpretacje oznaczaj osobno.

- Gra: FPS w LÖVE 11.5 i LuaJIT, który staje się grą w stylu Souls. Rycerz bez magii, dwie bronie palne (Exorcist, strzelba; Judge, rewolwer), kaplica z ogniskami.
- Styl: żywy mroczny fresk. Styl demonów, HUD i broni ma się nie zmieniać.
- Dolny pasek: właścicielowi podoba się jego obecny design. Charakter, kształt, kompozycja i styl są chronione.
- Bossowie są odłożeni. Margrave i Furfur to na razie zwykłe najtrudniejsze moby.
- Call of Duty jest odniesieniem tylko dla nagrody i potwierdzenia po strzale, nie dla mechaniki strzelania. Gra ma zostać Souls-like.
- Strzał nie bierze wytrzymałości, kosztuje chwilę ciała po strzale (przyjęty plan 1–6 w `PLAN-STRZELANIE.md`).
- Serie zabójstw dają bonusy tylko na broni, z której były robione. Medal pojawia się chwilowo u góry ekranu, stała informacja o serii jest cicha.
- Właściciel zgłaszał: mobów, które widzi, nie powinno być widać czekających; wejście (strzał, unik) ma być responsywne; opóźnienia mają być widoczne, a nie wyglądać na zawieszenie. Zapas amunicji miał być raczej minimalnie większy.
- Tekst w grze i na nagraniach jest po angielsku. Dokumenty w `game/docs` po polsku.
- Usuwać, nie przenosić: stary kod odzyskuje się z historii. Rozmiar pracy nie jest powodem do odkładania.
- Bez budowania EXE i ZIP, dopóki właściciel nie poprosi. Uruchamia grę przez `love .`.
- Muzykę, dźwięki, grafikę, modele i nagrania wykonuje Codex.

Jeśli czegoś nie można ustalić, nazwij niepewność i oceń, czy blokuje analizę.

## Zakres audytu

### 2. USTAL STAN PROJEKTU I JEGO FILARY

Przeczytaj obowiązujące instrukcje repozytorium, dokumentację, wcześniejsze ustalenia i poprzedni audyt. Sprawdź, co zostało poprawione, co nadal występuje, a co straciło aktualność.

Wyodrębnij:
- główną pętlę rozgrywki i zamierzone doświadczenie gracza;
- styl artystyczny i charakter interfejsu;
- założenia dotyczące walki, tempa, trudności i progresji;
- istniejące inspiracje oraz ograniczenia techniczne.

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
- czy mechaniki są satysfakcjonujące także w połączeniu, a nie tylko osobno.

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

Zwięzłość: zależy nam na rzetelności, konkretnych dowodach i użytecznym planie, a nie na długości raportu.
