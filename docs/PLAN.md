# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-07: analiza Exorcista zakończona; plan czeka na akceptację.**
Nie rozpoczęto wdrażania. Stan gry: `8011e3a`, 0.45. Zlecenie dotyczy
odczucia noszenia strzelby, reakcji ciała/rąk/kamery, animacji oraz całego
jej audio. Judge służy jako kontrola regresji; jego dopracowanie będzie
osobnym zadaniem. Poprzedni PLAN audio sześciu stworów zachowano w całości
w HISTORII. Odsłuch właściciela tamtego pakietu pozostaje otwarty.

Kierunek: ciężka, dwuręczna strzelba człowieka w piekle. Żelazo, drewno,
proch, rękawice i rycerskie ciało. Mocny wystrzał, pewny chwyt i wyraźne
odzyskanie kontroli; nie nieustanne bujanie ani magiczny krzyk z broni.
Wygląd `baza/exorcist.png` i aktywny `shotgun-iron-v16.png` są wiążące.

## Potwierdzony stan

- Dwie lufy, wystrzał dwóch łusek; jedna pozostała łuska nadal działa.
  Cykl 0,94 s: otwarcie 0,26, załadunek 0,60, zamknięcie 0,82.
  Po strzale 0,22 s odzyskania gotowości do uniku. Nie zmieniać tych reguł
  dla samego odczucia. Strzał i trafienie rozlicza symulacja, obraz je pokazuje.
- Masa prezentacyjna 4, pęd 96, impuls pełnego strzału 24; Judge: 6.
  Podbicie widoku Exorcista około 2°, pojedynczej łuski około 1°.
  Istnieją sprężyny, bezwładność obrotu, kroki zależne od przebytej drogi,
  skok/lądowanie i reakcje na uderzenia. To działająca podstawa.
- Chód, skok, unik i ślizg wykorzystują wyłącznie klatkę `ready` z
  przesunięciami/obrotem. Unik ma wspólny cel opuszczenia 4 jednostki
  obrazu 450 px, ślizg 5; brak odrębnego gestu podtrzymania ciężkiej broni.
  Start/hamowanie mają wspólne parametry bezwładności obu broni.
- Strzał nadpisuje bieżący wstrząs: sonda 0,13 → 0,05. Pojedyncza łuska
  zmniejsza podbicie, ale nie `fire.shake` ani impuls FOV. Przy następnych
  zmianach nie dodawać kolejnych niezależnych drgań bez wspólnego limitu.
- W ustawieniach właściciela: `soundSet=classic`, MOTION włączony.
  Strzał oraz obsługa są syntezą; IRON AND POWDER i STONE AND EMBER
  zawierają po trzy nagrane strzały, lecz F7 nie zmienia przeładowania.
  Kroki/uniki/ślizg są wspólne dla rycerza; nie ma osobnej warstwy noszenia
  strzelby ani dźwięku jej dobycia. `shellIn` zawsze zawiera dwa osadzenia.
- Ręce mają 16 zatwierdzonych póz, w tym odrzut, powrót i cały mechanizm
  łamanej broni. Pokaz odrzutu trwa do 0,08 s, powrotu do 0,14 s, dalej
  wchodzi automatyczne przeładowanie. Przy 60 Hz poza `reach` w tym
  przejściu trwa zaledwie około jednej klatki; rytm wymaga przeglądu.

## Plan do akceptacji

1. **Zabezpieczyć punkt odniesienia i regresje.** Wykorzystać zachowane
   ślady 60/120/240 Hz, 50 renderów i eksporty obecnego audio. Przed
   poprawką dopisać czerwone testy wstrząsu po silniejszym uderzeniu,
   proporcji jednej/dwóch luf oraz rzeczywistych gestów i kontaktów.
   Nowe kryteria jakości ruchu odróżnić od błędów obecnej mechaniki.
2. **Ciężar noszenia.** Wspólne reakcje na przyspieszenie, hamowanie,
   zmianę kierunku, obrót, krok i lądowanie mają brać parametry z profilu
   prezentacji broni. Exorcist: podparcie obu rąk, niewielkie opóźnienie
   ciężkich luf i kontrolowane osiadanie. Cięższy nie znaczy większe
   kołysanie w każdej osi. Spoczynek oszczędny; drobne korekty chwytu
   wygaszane przez strzał/atak/obronę, bez blokowania wejścia gracza.
3. **Unik, ślizg, skok i dobycie.** Trzy fazy: przyjęcie ciężaru,
   podtrzymanie, odzyskanie chwytu. Podczas uniku strzelba bliżej ciała,
   reakcja zgodna z kierunkiem; w ślizgu niski chwyt i stabilne lufy,
   czytelne wyjście; w skoku opóźnienie rąk i przejęcie lądowania.
   Dobycie ma osadzenie kolby i chwytu, zamiast samego wysunięcia obrazka.
   Strzał nadal możliwy dokładnie wtedy, kiedy pozwala mechanika, także
   podczas przejść. Przeładowanie, flaska i proch mają jasne pierwszeństwo
   ręki; przerwanie nie pozostawia starego gestu. Bez nowego klawisza
   inspekcji i nowych blokad strzału w tym zakresie.
4. **Strzał: dłonie, bark i kamera.** Impuls wzdłuż luf, krótki odrzut
   i chwyt zatrzymujący broń; potem czytelne przejście do otwarcia.
   Przestroić nakładające się ruchy jako jeden gest. Kamera daje krótki,
   silny akcent, ręce niosą większość ciężaru. Jedna łuska odpowiednio
   słabsza; strzał w powietrze nadal ma moc, trafienie dodaje osobną
   informację. Bez zmiany celu, rozrzutu, HP, push ani kadencji.
5. **Wspólne impulsy prezentacji.** Rozwinąć istniejące sprężyny i
   mechanizm wstrząsów: zdarzenie + profil + kierunek + ewentualna pozycja
   i odległość → ograniczona odpowiedź rąk/kamery. Samo `damage` nie jest
   właściwą miarą huku ani mechanicznego odrzutu: chybiąca strzelba nadal
   kopie, a odległa rana nie trzęsie rycerzem. Impuls od broni bierze moc
   wypuszczenia i profil, kontakt pęd, zdarzenie przestrzenne maleje
   z dystansem. Łączyć i ograniczać współbieżne reakcje; słabszy impuls
   nie kasuje mocniejszego. Istniejące wybuchy/lądowania przeprowadzić
   przez wspólny mechanizm z zachowaniem ich dotychczasowej siły, bez
   samodzielnego dodawania nowych efektów stworom. MOTION wyłącza ruch
   i usuwa jego resztki; celownik wskazuje rzeczywisty kierunek strzału.
6. **Audio całego Exorcista.** Przygotować dwa krótkie kierunki A/B o
   wyrównanym poziomie odsłuchu: A — suche żelazo, gwałtowny huk i ciężki
   proch; B — ten sam czytelny atak, głębszy pomruk prochu i ciemniejszy
   pogłos kamienia. Rekomendacja: A jako rdzeń, oszczędny ogon B.
   Własne warianty wystrzału, jednej lufy, otwierania, wyrzutu i kontaktu
   łusek, wkładania jednej/dwóch, domknięcia, pustego spustu, dobycia,
   przejęcia ciężaru podczas uniku/ślizgu/lądowania. Kontakty wynikają
   z rzeczywistej czynności; nie odtwarzać dawnego kliknięcia po Continue.
   Nowe foley nie duplikuje kroków ani kolczugi. Brzmienie groźne przez
   dynamikę, materiały i odpowiedź sali; bez demonizowania głosu broni,
   ciągłego basu i pisków. Zostawić miejsce na ostrzeżenia stworów.
7. **Dźwięk i przestrzeń.** Oddzielić bezpośredni huk, mechanikę i ogon,
   żeby nie odtwarzać identycznej „kamiennej sali” wszędzie. Wykorzystać
   istniejącą geometrię/regiony i profile, jeśli wystarczą; ograniczyć
   próbkowanie przestrzeni do zdarzenia, nie budować pełnej akustyki map.
   Sprawdzić w kaplicy, przy ścianie i w otwartej części poligonu, z muzyką
   i sześcioma stworami. Pozostawić globalny F7 do decyzji właściciela:
   najpierw A/B Exorcista, potem jego zatwierdzony domyślny bank. Nie
   podmieniać przy tym Judge'a, trafień, ładunku ani ostatniego audio mobów.
8. **Grafika bez reinterpretacji.** Najpierw istniejące pozy, rejestracja
   chwytu i wspólny ruch. Brakujące gesty podparcia/tuck dopiero z bazy
   konkretnej strzelby i Inferno, z pokazaniem przed podłączeniem.
   Zachować żelazo, drewno, rękawice, proporcje, fakturę i skalę detalu.
   Żadnego gumowego zginania atlasu, nowego połysku ani ostrzenia.
   Trzy zapisane kontrole: baza obok każdej zmiany; rendery w tej samej
   skali/świetle; przejścia wszystkich gestów. Emisja błysku/dymu i łusek
   zgodna z widocznym wylotem/komorą. Chroniony HUD poza zakresem.
9. **Weryfikacja i commit.** Macierz ruch × strzał × reload, jedna/dwie
   łuski, brak zapasu, anulowanie, flaska/Q, szybka zamiana, strzał przed
   pełnym osiadaniem, ściana, schody, lot, pauza, śmierć, ognisko, Continue,
   MOTION off/on i obserwator. 30/60/120/240 Hz oraz nieregularne kroki.
   Test fikcyjnego trzeciego profilu bez dodawania broni do gry, brak
   przecieku stanu między aktorami i RNG prezentacji niezależne od symulacji.
   Sprawdzić zachowanie starszych zapisów: metadane prezentacji nie mogą
   przypadkiem zmieniać zamrożonej definicji walki lub golden.
   Mierzyć CPU, źródła, clipping, szczyty/krótkie okna i maskowanie;
   odsłuch A/B oraz normalna gra osobno od technicznego PASS.
   Po wymaganych testach pełne Linux All, golden bez zmiany wzorców,
   przegląd diffu i trzy kontrole grafiki. PLAN/HISTORIA, commit; bez push.

## Postęp i dowody

- 2026-11-07: analiza źródeł, zależności i materiałów producentów DOOM,
  Modern Warfare, Hunt oraz Dead Space zakończona. Szczegółowe źródła
  i pomiary w HISTORII, „Analiza Exorcista — ciężar, animacje i audio”.
- W izolowanym klonie: weapons 441, weight 882, shotgun 43 PASS — 1366
  nowych sprawdzeń. Sonda eksportu i 50 PNG: PASS, stabilne źródła.
  Ślady potwierdzają jednolitą pozę ruchu, brak odrębnego audio noszenia,
  ten sam wstrząs jednej/dwóch luf i kasowanie silniejszego impulsu.
- Nie uruchamiano nowego All, bo gra nie była zmieniana. Poprzednie
  All audio na `8011e3a`: 8808, Input 50, pozostałe bramy PASS; to punkt
  odniesienia, nie nowy przebieg. Windows nie był sprawdzany.
- Dowody poza repo: work/qa-direct/exorcist-analysis-20261107/.
  Porównanie trzech obecnych zestawów to montaż z poziomami runtime,
  nie natywny miks walki. Agent nie miał wiarygodnego odsłuchu.
  Po sprawdzeniu kopii dowodów usunięto własny klon pomiarowy i jego
  tymczasowy katalog wyników; zachowany raport należy do głównego repo.

## Decyzja właściciela

Do akceptacji: cały pakiet powyżej, z ciężarem przekazywanym przez gest,
obraz i dźwięk oraz zachowaniem obecnej szybkości ruchu, kadencji i zasad
celowania. Rekomenduję ten zakres. Zmniejszenie prędkości rycerza przez
noszenie strzelby byłoby osobnym zadaniem balansu, nie warunkiem ciężaru.
Dokładny wybór brzmienia A/B należy do odsłuchu przed przyjęciem banku.
Nowy atlas, gdy okaże się niezbędny, wymaga odbioru spójności przed użyciem.

## Poza zakresem

Nowe bronie/tryby strzału/ADS, obrażenia, rozrzut, amunicja i jej ekonomia,
czasy przeładowania/uniku, AI i balans stworów, przebudowa postaci rycerza,
HUD, muzyka jako kompozycja, całkowicie nowy silnik dźwięku, usunięcie F7,
zmiany Windows, pakowanie i wideo. Nie zmieniać innych broni dla przejścia
sondy. Odłożone sprawy i wcześniejsze plany pozostają w HISTORII.
