# Poligon, walka i oprawa — odbiór etapu 28.10.2026

Wdrożenie kontynuuje plan poligonu. Ostatnia decyzja użytkownika ma
pierwszeństwo: jedna postać bossa/jedno życie, wszystkie dotychczasowe
ruchy dostępne w tej walce, zachowanie HUD-u i bazowych demonów.
To raport zmian i ich weryfikacji, nie deklaracja ukończonej gry ani
ponowny audyt każdej linii całego projektu.

## Co jest w grze

Korekta portali po zgłoszeniu użytkownika: prześwitujące przywołania, zanikanie
bramy przy narodzinach demona i wyjście są rysowane po obiektach
nieprzezroczystych, z odczytem ich głębokości. Nie zastosowano rysowania
przez ściany. Test GPU obejmuje cztery rodzaje (także znak ołtarza), każdy
przed dekoracją, za dekoracją i za ścianą: 12 przypadków. Oryginalna kolejność
nie przechodzi kontroli negatywnej dla pojawienia się demona (0 widocznych
pikseli przed dalszą dekoracją); po zmianie wszystkie przypadki przechodzą.
Pełny zestaw Mechanics: 4947 sprawdzeń. Native rendery obejrzano w
`work/closure-28/portal-review`. Nie zmieniono PNG, HUD-u ani reguł walki.

| Commit | Wdrożony zakres |
|---|---|
| `ba8df4c` | Zamknięta bazylika, pełne zestawy ataków w jednym życiu, presja i odpowiedzi na zapowiedzi |
| `5ccd19b` | Kroki z animacji, głosy ostrzegawcze, priorytety, lot/kontakt pocisków, ambient pod stropem |
| `9449bb3` | Zatwierdzony obraz nisz grobowych, galerie i nazwany rejestr malowideł środowiska |
| `63f6a85` | Oddzielenie archiwalnych prób faz od aktualnych jednofazowych walk |
| `bca9642` | Nowe proporcje mapy: nawa procesyjna, absydy i dwie wysokie sale pojedynków, stanowiska mapy |
| `44f4060` | Jawna aktualizacja golden po udowodnieniu wpływu samych danych nowych ataków |
| `3a35b56` | Przygotowanie świata w widocznym ładowaniu i ograniczony cache kafelków cieni |

Poprzednie punkty 1–3 (kontakt sfery z ciałem, reset, wysokości ataków,
poligon bez handlu i fal) pozostają częścią bazy. Nie przywrócono Limbo
do publicznego menu. Zachowano kod dawnych trybów.

## Przestrzeń i klimat

Mapa `proving` ma 49×43 m. Nawa prowadzi ku podniesionemu prezbiterium;
do bocznych sal wchodzi się przez niższe progi. Każda sala pojedynku ma
15×18 m, wysokie sklepienie do 9,3 m, boczne kolumnady i absydę na końcu
osi. Środek pozostaje wolny od przypadkowych rekwizytów, żeby odczytywać
sylwetkę oraz tor ataku. Galerie grobowe mają 3 m wysokości.

Inspiracją był rzeczywisty porządek przestrzenny, a nie zestaw osobnych
ozdobników: [arkady i prezbiterium San Nicola](https://www.basilicasannicola.it/sez/2/93/114/interno),
[krypta z rytmem kolumn](https://www.basilicasannicola.it/sez/2/95/la-cripta)
i [proporcje nawy Durham](https://www.durhamcathedral.co.uk/explore/the-cathedral-building-and-grounds/the-nave).
Nie jest to rekonstrukcja żadnego z tych zabytków. Przeniesiono zasadę
osi, rytmu podpór i kontrastu niskiego wejścia z wysokim wnętrzem.

Pieczęcie bossów należą do podniesionych ołtarzy. Podłogowy obwód ognia
pojawia się podczas aktywnej próby; znika po zakończeniu/resetowaniu.
Nie zadaje obrażeń i nie maskuje nieistniejącej kolizji. Sklepienie i jego
obrzeże są natomiast rzeczywistymi przeszkodami dla pocisków.

`git diff a48c555..3a35b56 -- game/assets game/src/ui` wykazuje tylko
dodanie zatwierdzonego `catacomb-loculi-fresco.png`. Żadna wcześniejsza
grafika demona, ręki, broni, portretu ani HUD-u nie została podmieniona;
kod układu HUD-u też nie jest zmieniony w tym zakresie. Nowe zachowania
korzystają z istniejących malowanych klatek i efektów.

## Walka i dźwięk

### Korekta zwykłych demonów po kolejnym zgłoszeniu

Cztery zwykłe typy mają krótsze przerwy, szybsze podejście lub dostawy,
a strzelcy przewidują obserwowany ruch już na TIER 1. Imp wykonuje silniejsze
dosunięcie pazurem i wcześniej wybiera skok; żelazny sługa ma szybszą,
przewidywaną szarżę. Stolas unika utrzymywanego na nim celownika na TIER 1,
Buer częściej zmusza do opuszczenia miejsca. Trafienia kosztują więcej HP.
HP demonów, ich bazowe grafiki, geometria i czasy zapowiedzi pozostały takie same.
Tempo zwykłego biegu nadal nie przewyższa biegu rycerza nawet na TIER 5.

`trial.readyDelay` to opcjonalne ustawienie spotkania, odrębne od czasu portalu,
pauzy pojawiania się i windup ataku. Zwykłe komnaty używają 0,2 s zamiast
domyślnych 1,2 s. Bossowie zachowują swoje otwarcia i jedno życie.

Nowe 45 sprawdzeń `creature-pressure` rozgrywa 16 walk: cztery komnaty,
dwie bronie, bezruch albo reakcja. Zwykłe magazynki, rezerwa i przeładowanie;
brak dopisywania życia czy amunicji. Przykład trzech żelaznych sług ze strzelbą:
stanie kończy z 83,8 HP / 9,2 osłony, reakcja ze 100 HP / 24,6 osłony.
Próby reaktywne pozostają wygrywalne. Idealne celowanie rewolwerem potrafi
przerwać słabych strzelców przed rzutem — to zachowana kontra, nie błąd testu.
Te wyniki nie są ludzką oceną trudności ani deklaracją ostatecznego balansu.

Obie bronie przeszły walki z rzeczywistym przeładowaniem; cała reaktywna
walka rewolwerem z żelaznymi sługami odtwarza się bitowo. Dodatkowe testy
sprawdzają zamrożony cel rzutu, zero/ujemny readyDelay, brak mutacji definicji
i zachowanie pauzy pojawienia się. Pełna mechanika: **5001 sprawdzeń PASS**.
Poprzednie sześć skrótów golden wraca po przywróceniu samych czterech
definicji demonów na nowym silniku. Dawne projekcje v0.33 nie zostały zmienione.
Test poleceń dwóch aktorów korzysta z zamrożonego dawnego napastnika, aby
nowy balans nie zabijał drugiego rycerza przed zaplanowanym przełączeniem broni.

### Zachowane walki bossów i audio

Margrabia łączy wachlarz z presją na kierunek ruchu, linię ognia na ziemi,
odpowiedź pociskiem po lancy oraz bliski wybuch wokół siebie. Furfur ma
pchnięcie, szarżę, powrót po szarży i wzory piorunów. Wyraźna zapowiedź
poprzedza zobowiązanie celu; kolejne uderzenie ma własną zapowiedź,
a po zakończeniu ciągu pozostaje dłuższe odsłonięcie. Nie zwiększono HP
tylko po to, aby zastąpić presję dłuższym strzelaniem.

Podstawą były czytelna sylwetka, ciężar i etapy ruchu opisywane przez
[twórców Demon's Souls](https://blog.playstation.com/2021/03/26/what-demons-souls-can-teach-stunt-performers-about-human-movement/).
To adaptacja zasad do szybkiego FPS-a, nie dowód równej jakości walki.

Próba deterministyczna: 30 s, bez strzelania, TIER 1, 100 HP / 40 osłony:

| Zachowanie sterownika | Margrabia | Furfur |
|---|---|---|
| Bezruch | śmierć 11,500 s | śmierć 13,258 s |
| Stały obieg | śmierć 26,458 s | śmierć 20,992 s |
| Reakcja na zapowiedzi | przeżywa, 80,2 HP | przeżywa, 62 HP |

To sprawdza zagrożenie oraz istnienie odpowiedzi. Nie zastępuje człowieka,
który celuje, przeładowuje, uczy się przestrzeni i ocenia przyjemność.

Kroki wykorzystują zegar malowanej animacji. Typ głosu wynika z definicji
demona; ostrzeżenie ma wyższy priorytet od kroku i chwilowo ścisza muzykę.
Dodano odgłosy pobliskich lotów/kontaktów oraz rzadki ambient pod stropem.
Eksport obejmuje 52 efekty i pięć warstw muzyki. Sprawdzono limity,
próbki i brak mutacji symulacji; nie deklarujemy wykonanego ludzkiego odsłuchu.

## Weryfikacja i granice

- Pełne `TEST.ps1 -Suite All -TestTimeoutSeconds 600`: mechanika, rzeczywiste
  wejście, render, smoke czterech narzędzi oraz pełny startup — PASS.
- Po ostatnim doprecyzowaniu transakcji tworzenia mapy stropu ponowiono
  mechanikę i Tools: **4935 sprawdzeń mechaniki/zasobów**, PASS. Wejście
  i render poprzedniego pełnego przebiegu mają odpowiednio 36 sprawdzeń
  sterowania i poprawne zrzuty. Zmiana transakcji nie zmienia obrazu.
- **558 plików Lua**, format poprawny, zero naruszeń architektury.
- 48 par ujęć przed/po optymalizacji światła: identyczne SHA-256 plików PNG.
  Obejrzano nawę, salę Margrabiego, ołtarz i galerię z niszami. Przegląd
  obejmuje też aktywne ataki, zakończenie, reset i różne rozmiary ekranu.
- Sześć poprzednich golden wraca po podstawieniu wyłącznie poprzednich
  definicji ataków/arkuszy na bieżącym silniku. Zmiana oczekiwań została
  przypisana do zamierzonego balansu. Zamrożone referencje 0.33 zachowane.
- Ostatnie pokwitowania testów wskazują stabilne źródła i kod wyjścia 0.
  Surowe artefakty są lokalnie w `work/qa-v33` i `work/basilica-duel`.

Wydajność i koszty ładowania są opisane w
[osobnym raporcie](PUNKT-1-WYDAJNOSC.md). Smoke narzędzia nie zamyka
kryterium wydajności. Pierwszy widok gry po przygotowaniu świata nie tworzy
odroczonych obrazów; w ostatnim pełnym startup miał 12,85 ms, katalog
10,59 ms. Ładowanie miało 63 widoczne kroki i 2,49 s do gotowości.
Najdłuższy provider trwał 149,44 ms; nie obiecujemy klatek 16,7 ms
podczas niepodzielnego dekodowania/uploadu obrazu.

Końcowe A/B tej samej mapy i ataków (`44f4060` / `3a35b56`), pięć par:
nieruchoma ciężka scena bez regresji; pozostałe trzy metryki mają wynik
nierozstrzygnięty, więc formalna bramka nie jest zaliczona. P95 publicznych
sal w pięciu przebiegach wynosi 9,23–11,56 ms; ich najgorsza klatka 38,76 ms.
Przy 20 walczących demonach p95 dochodzi do 18,11 ms. Nie ukrywamy skoków
za samą medianą. Osiem pełnych cykli testu zasobów nie wykazało narastania
obrazów/canvas/pamięci GPU; pokwitowanie źródeł jest stabilne.

## Skalowanie i co pozostaje świadomą granicą

Komnata, ołtarz, próba, stanowiska resetu/fizyki i nowy obraz ścienny
są danymi mapy. Zmiana tych danych nie wymaga nowego trybu ani gałęzi
renderera. Nowe ataki używają wspólnych dostaw, pakietów i nazwanych póz.
Zegary audio są tylko prezentacją. Cache światła ma limit i właściciela.

Pozostają konkretne ograniczenia: demony są płaskimi sprite'ami, mapa
używa geometrii 2.5D, strzelnica ma ustaloną oś, Q ma jeden publiczny slot,
a bank cieni przygotowuje najwyżej 64 różne pozycje lamp. Przekroczenie
tych założeń wymaga lokalnego rozszerzenia kontraktu, nie obietnicy, że
cała przyszła gra będzie wyłącznie zmianą liczb.

Ocena dłuższej gry i odsłuch należą do odbioru użytkownika. Starego
ujemnego wyniku względem E0 nie nazywamy zaliczonym przez zmianę progów
ani przez sam fakt ukończenia nowej mapy. Baza nadaje się do testowania
treści; określenie „perfekcyjna” nie wynika z raportu automatycznych testów.

Praktyczne przykłady zmian są w
[PORADNIK-POLIGON-WALKA-2026-10.md](PORADNIK-POLIGON-WALKA-2026-10.md).
