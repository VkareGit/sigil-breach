# SIGIL: BREACH — styl

Kierunek artystyczny: żywy mroczny fresk, HUD, broń, demony, atmosfera. Wzorzec malowanej architektury: `docs/art/painted-direction-2026-10-31.png`. Analiza czytelności obrazu i strzelania (V01) jest w `docs/HISTORIA.md`.

## Spis rozdziałów

- Kierunek artystyczny
- Kierunek atmosfery poligonu

## Kierunek artystyczny

_Dawniej: `game/docs/KIERUNEK-ARTYSTYCZNY.txt`_

SIGIL: BREACH — ożywiony fresk, kierunek oprawy 0.12
20 października 2026

CEL I GRANICE
Gracz nie ogląda współczesnej gry przez filtr „starego obrazu”. Chodzi po przestrzeni, której materiały, ludzie, demony, broń, gesty, znaki i litery zostały namalowane tym samym językiem. Punktem odniesienia jest przesłany przez użytkownika widok jasnej, starej kaplicy z ochrowymi demonami i malowanym pasem HUD. Horror nie oznacza samego obniżenia jasności.

Wciąż mamy jedno pole testowe: dotychczasową arenę 31×31, z nawą, bocznymi dziedzińcami i ołtarzem. Nie budujemy teraz kampanii ani następnych kręgów. Dopracowujemy oprawę, ruch, ataki, trafienia, broń, animację, interfejs i czytelność przed projektowaniem świata. F2 służy do powtarzalnych prób istniejących demonów, bossów, pieczęci i stanów walki. Człowiek pozostaje bez magii; manifest jest wskazówką dla jego wyglądu, nie nowym scenariuszem.

CZTERY PUNKTY ODNIESIENIA — RÓŻNE ROLE, WSPÓLNY JĘZYK
1. Giovanni da Modena, Inferno, kaplica Bolognini, San Petronio.
   To główne odniesienie dla potworów i materialności malowidła: hybrydy człowieka i zwierzęcia, wydłużone gesty, wyraźny kontur, rozpoznawalne sceny, okrutny porządek zamiast przypadkowego zbioru kolców. Przewodnik kaplicy opisuje układ Sądu nad Infernem i przypisanie kar do win; zastrzega, że część ikonografii kar jest starsza od Dantego. Nie nazywamy całego malowidła ilustracją Dantego.
   Wniosek projektowy: każdy typ ma odmienną sylwetkę i sposób grożenia. Róg, skrzydło czy dziób to czytelny znak tożsamości, nie dodatkowy prostokątny hitbox.
   Źródło: https://mmg.inera.it/frontend/bologna/oggetti-esposti/cappella-bolognini

2. Michał Anioł, Sąd Ostateczny, Kaplica Sykstyńska.
   Muzea Watykańskie opisują kompozycję z dominującą figurą Chrystusa w chwili poprzedzającej wyrok.
   Nasz wniosek z kompozycji: energia gestu powinna przebiegać przez całe ciało. Przygotowanie ciosu, uderzenie i bezwład po nim muszą być odrębnymi pozami, a nie samym przesunięciem ręki. Wielkie figury i małe postaci pozwalają odczuć skalę. Nie kopiujemy przedstawienia Chrystusa jako przeciwnika.
   Źródło: https://www.museivaticani.va/content/museivaticani/en/collezioni/musei/cappella-sistina/giudizio-universale.html

3. Hieronymus Bosch, Ogród rozkoszy ziemskich, szczególnie piekielne skrzydło.
   Prado zwraca uwagę na wysoki horyzont, kolejne plany i przekształcenie znajomych przedmiotów w narzędzia piekła.
   Wniosek projektowy: głębię tworzą nakładające się plany i małe, celowe zdarzenia. Panorama pokazuje odległe miasto i procesję. Gracz jest mały wobec tego porządku. Bliski przeciwnik pozostaje mocniejszym akcentem niż dalekie płomienie. Groteska nie powinna stać się komediowym potworkiem.
   Źródło: https://www.museodelprado.es/en/the-collection/art-work/triptych-garden-earthly-delights/02388242-6d6a-4e9e-a992-e1311eab3609

4. Hans Memling, Sąd Ostateczny, Muzeum Narodowe w Gdańsku.
   MNG opisuje oś symetrii, ważenie dusz oraz kontrast uporządkowanej i chaotycznej części kompozycji. To dzieło temperowo-olejne na desce, nie fresk.
   Wniosek projektowy: HUD i miejsca odpoczynku mają rytm, stabilne osie i spokojne wnętrza. Poczucie sądu wynika z układu, a nie z dodania czaszki do każdego przycisku. Ornament nie zabiera przestrzeni liczbom.
   Źródło: https://sadostateczny.mng.gda.pl/

Nie udajemy, że cztery prace powstały jedną techniką. Fresk jest wspólną konwencją gry; od pozostałych obrazów bierzemy kompozycję, anatomię i sens znaku.

CO ZNACZY „FRESK” W IMPLEMENTACJI
Pigment w fresku wiąże się z tynkiem. Materiał ma więc pochodzić z ilustracji przywiązanej do powierzchni, nie z pęknięć przyklejonych do kamery. Źródła konserwatorskie Getty opisują mokry wapienny tynk, pigmenty i rysunek przygotowawczy; nie wyprowadzamy z nich fikcyjnej „historycznej palety RGB”.
Źródło: https://www.getty.edu/conservation/publications_resources/pdf_publications/pdf/omwp_report.pdf

Nasza paleta robocza: stara kość słoniowa, ochra, żelazowa czerwień, umbra, siny grafit; szałwiowy płomień oznacza odpoczynek. Są to decyzje artystyczne dla gry, nie pomiary pigmentów konkretnych obrazów.

Objętość: szerokie malowane płaszczyzny na ciele i kamieniu, z miękką zmianą tonu i cienkim brunatnym rysunkiem. Żadnego wymuszonego spłaszczenia całego ekranu do kilkunastu kolorów. Bez plastikowego połysku i chromowanej broni. Zużycie nie może pokrywać każdego centymetra równomiernym szumem.

Trzy skale detalu:
- Z daleka: sylwetka potwora, kształt wejścia, źródło odpoczynku.
- Ze średniej odległości: gest ataku, żebra, szata, malowany motyw.
- Z bliska: ślad pędzla, wapienna skaza, cienki rysunek.
Jeśli trzecia skala niszczy pierwszą, upraszczamy ją.

GŁĘBIA I KLIMAT BEZ DŹWIĘKU
Świat: ciepły bliższy tynk, chłodniejsza i spokojniejsza dal, ciemne wnęki, warstwowa panorama. Mrok ma miejsca i powód. Nie zakrywamy przeciwników jednolitą czernią.
Człowiek: ciężki ubiór, zmęczona twarz, ludzkie spojrzenie. Portret jest częścią malowanego pola, bez prostokątnego naklejonego tła. Zmienia wyraz po trafieniu i przy niskim zdrowiu.
Demony: osobna anatomia, czytelna cisza przed ruchem i konsekwencja gestu. Stolas — sowa, Buer — niepokojący motyw lwa i odnóży, Furfur — jelenia forma i ogon, opancerzony sługa — obciążona żelazem sylwetka. Wszyscy należą do jednego malowidła.
Broń: palna, namacalna. Otwieranie komór, ładowanie i zamykanie mają czytelny stan wizualny. Malowane płomienie, krew i pył pozostają krótkie, by nie zasłaniać dalszego celu.
Otoczenie: figura żałobna, kości, relikwiarz, procesja i odległy świadek. Elementy dekoracyjne nie udają aktywnego przeciwnika. Dlatego daleki świadek pochodzi z panoramy, a nie z wielokrotnie powiększonego sprite'a bossa.

GOETIA
Źródłowe pieczęcie pozostają odrębnymi, niezmienionymi plikami i zachowują orientację. Nie regenerujemy historycznych znaków jako ornamentów. Kolor tuszu dopasowujemy do podłoża. Dekoracyjne łuki efektów nie są przedstawiane jako autentyczne pieczęcie. Kanał ESOTERICA wskazany przez użytkownika pozostaje dodatkową pomocą interpretacyjną; nazwy i znaki wymagają źródeł.

PORÓWNANIA Z GRAMI
Pentiment: studio deklaruje ograniczoną liczbę klatek, aby animacja zachowała charakter dawnych ilustracji. Istotna lekcja to wspólna reguła dla obrazu i ruchu. Zachowujemy dynamiczne sterowanie FPS, ale pozom nadajemy wyraźne akcenty zamiast płynnego gumowego zniekształcania obrazu. Strona pokazuje też osobne rozwiązania dla czytelności i stabilności kamery; styl nie usprawiedliwia nieczytelnego tekstu.
Źródło: https://pentiment.obsidian.net/

Apotheon: oficjalne materiały Alientrap prezentują akcję wewnątrz konsekwentnie stylizowanego świata greckiej mitologii. Nasza obserwacja wizualna: ograniczony język sylwetek i ornamentu daje wspólną tożsamość środowisku i postaciom. Nie przenosimy jego płaskiej estetyki wprost; nasze ciało potrzebuje malowanego modelunku.
Źródło: https://www.alientrap.com/games/apotheon/

Inkulinati: twórcy opisują grę osadzoną na stronach średniowiecznych rękopisów. Lekcja: historyczny nośnik staje się zasadą całego świata, nie dekoracyjną nakładką.
Źródło: https://news.xbox.com/en-us/2024/02/22/inkulinati-1-0-is-now-available-to-play/

Z tych przykładów nie wynika gwarancja sukcesu gry. To uzasadnienie konkretnych decyzji wizualnych.

KOLEJNOŚĆ PRAC I WARUNKI ODBIORU
1. Zachowanie poprzedniej wersji i render porównawczy.
2. Nowe malowane atlasy sześciu archetypów, dwóch broni, ładunku, efektów, ogniska, dekoracji, materiałów, panoramy, malowideł i GUI.
3. Kontrola przezroczystości, oddzielania klatek i rejestracji stóp; celowane poprawki ilustracji tam, gdzie skrzydła lub broń przechodzą do sąsiedniej komórki.
4. Podłączenie ilustracji do istniejących czasów i stanów gry. Usunięcie posteryzacji i ekranowej siatki pęknięć.
5. Pismo nadal z atlasów PNG. Ciemny pigment na jasnym polu, jasny na nieobramowanym świecie. Liczby składane z glifów, nigdy nieskończona lista osobnych obrazów.
6. Kontrola HUD i wszystkich ekranów w pięciu formatach, również na bardzo długich liczbach, pustej amunicji, zranieniu i przeładowaniu. Liczy się wnętrze malowanego pola, nie sam prostokąt elementu.
7. Oglądanie prawdziwych renderów, animacji strzału i ataków bez dźwięku. Same testy prostokątów nie oceniają kompozycji.
8. Regresja fizyki, trafień, zapisów i prawdziwych callbacków sterowania. Osobny pomiar kosztu renderowania; nie nazywamy ograniczenia vsync pomiarem wydajności GPU.
9. Nowa paczka Windows, porównanie jej źródeł i hashy oraz powtórzenie testów na paczce.

To dokument decyzji i kryteriów, nie deklaracja, że subiektywna jakość osiągnęła „perfekcję”. Wykonane kontrole i ich faktyczne wyniki zapisujemy w raporcie wydania.

AKTUALIZACJA 0.16 — WYBRANY PRZEZ UŻYTKOWNIKA WARIANT B
Dominuje „Popiół i żelazo”: funkcjonalna, matowa broń, ciemne drewno,
zamknięty rycerski wizjer, spokojne wapienne pola i czytelne malowane litery.
Z C pozostają oszczędne figury na samych końcach HUD-u. Nie rozciągać
postaci na ramach menu, nie wypełniać pól liczników ornamentami.
Nowe napisy mają wspólne glify PNG; nie udają horroru nieczytelnymi kolcami.
Obrazy w projekcie: bronie iron-v16, reliquary-ash-v16, nosiciel-iron-v16,
alphabet-upper/lower-v16, numerals-v16, lettering-en-v16.
Dokładne prompty i pochodzenie są zapisane obok atlasów. Historycznych
pieczęci z biblioteki źródłowej nie zastępują nowe dekoracje.

DOPRECYZOWANIE 0.28 — ZACHOWAĆ MODELE POTWORÓW
Użytkownik odrzuca ostrzejszą reinterpretację pokazanych demonów. Istniejące
malowane modele są wzorcem. Rozwijać ich animacje, nie zmieniać twarzy, anatomii,
połysku, nasycenia ani skali detalu. Każda nowa klatka ma wyglądać jak dalszy
ciąg tego samego fresku. Unikać błyszczących krawędzi i ostrego mikrokontrastu.
W tej iteracji nie zmieniono żadnego z 155 plików obrazów względem wydania 0.27.
Broń łagodzimy w próbkowaniu pigmentu, bez rozmywania obrysu i bez zmiany alfa.

DOPRECYZOWANIE 0.29 — ANIMACJA TEGO SAMEGO MALOWIDŁA
Wzorcem pozostają imp-fresco-v12 i stolas-fresco-v12. Dodatkowe atlasy skoku
i uniku nie mogą podczas ruchu stawać się jaśniejsze, bardziej pomarańczowe
ani bardziej błyszczące od modelu spoczynkowego. Profile pigmentu w danych
ability_art wyrównują ton i grupują drobny detal RGB. Alfa pochodzi nadal
z oryginalnego obrazu; korekta nie zmienia sylwetki ani geometrii trafień.
Obejrzano wszystkie 16 klatek i pary w tym samym świetle areny. Pomiar alfa
przed/po jest osobny od oceny stylu. Próbę generatora zmieniającą kontury
odrzucono. Żaden produkcyjny PNG nie został zastąpiony nowym modelem.
Przy kolejnych animacjach najpierw zestawić ruch z modelem bazowym, również
w rozmiarze faktycznie widocznym w grze, zanim zaakceptuje się nowy atlas.
Sama korekta jasności nie wystarczyła: czerwona tkanina skoku nadal odstawała.
Osobny miękki próg nadmiaru czerwieni przesuwa ją ku brunatnemu pigmentowi
modelu bazowego. Nie nakładać tej korekty na całą scenę ani na modele bazowe.
Kontrole: wszystkie klatki, cień, błysk strzału i zamiana miejsc obu postaci.

AKTUALIZACJA 0.32 — CAŁE CYKLE BRONI
shotgun-fresco-v32 i revolver-fresco-v32 zachowują zaakceptowany matowy,
freskowy styl nowego chwytu w całych cyklach. Retusz lokalny obu arkuszy
został jawnie zaakceptowany przez użytkownika. Metal, rękawica i drewno
mają czytelne granice, bez dodatkowego ostrzenia. Widoczne komory odczytują
amunicję gry; małe warianty nie stanowią odrębnych mechanizmów strzelania.
Dokładne prompty i źródła: git show e44c509:old/weapon-art-v32-v33/weapon-provenance-v32.json
(ścieżka od katalogu repozytorium).
Modele, atlasy animacji i pigment demonów nie zostały zmienione w tym etapie.
Wzorce dwóch atlasów są w historii gita: commit e44c509, folder old/weapon-art-v32-v33.
Techniczny filmstrip nie zastępuje osobnej oceny użytkownika w ruchu.

STAN PO 998b189 — W GRZE ZNÓW ARKUSZE v16
Powyższa aktualizacja opisuje etap F12. Przed wydaniem 0.32 gra wróciła
do sprawdzonych arkuszy shotgun-iron-v16 i revolver-iron-v16 (źródła:
assets/art/weapon-provenance-v16.json). Arkusze fresco-v32/v33 czekają
poza grą, w historii gita (e44c509, old/weapon-art-v32-v33), na następcę.
Katalog zachował warianty widocznej amunicji, więc nowy atlas wejdzie
jako dane. Nowy arkusz broni wymaga osobnej akceptacji użytkownika w ruchu.

POLIGON — MALOWANA ARCHITEKTURA (31 października 2026)
Wzorzec: docs/art/painted-direction-2026-10-31.png, przyciemniony.
Mapa nie jest siatką z teksturami. Obie sale, nawa i mniejsze pomieszczenia
są zbudowane tym samym sposobem, scena rysuje się w 1080 liniach. Każda ściana ma jedno malowidło i układ
w metrach (content/art/chapel_hall.lua). Ten sam układ daje szablon dla malarza
(tools/art/chapel_hall) i relief bryły, więc farba i geometria się nie rozjeżdżają.
Światło jest wypieczone w wierzchołkach (render/kit/light.lua). Podłoga, stopnie,
sarkofagi i rumowisko wynikają z wysokości mapy, więc kolizja zgadza się z obrazem.
Nowa sala: wpis w content/maps/proving_halls.lua i własne malowidła. Mniejsze
pomieszczenie: prostokąt i nazwa malowanej ściany (render/kit/rooms.lua).
Prompty i sumy: assets/art/chapel-hall-provenance-v35.json.

ŻYWA MAPA (31 października 2026)
Co się niszczy, opisuje content/breakables.lua, a gdzie stoi: decor.breakables
mapy. Nowy rodzaj to wpis tam i jego wygląd w render/kit/props.lua.
Ciosy pochodzą z rozstrzygniętych strzałów i wybuchów (combat/destruction.lua),
więc mur albo ciało przed celem nadal go chronią. Stan żyje w świecie i trafia
do zapisu; rysowanie tylko go czyta. Filar po upadku zabiera sklepienie nad sobą,
a filar przy zewnętrznej ścianie także górę muru, i odsłania piekło. Kształt ruiny
(content/maps/breakables.lua) jest jeden dla fizyki i obrazu. Cała ruina jest
przygotowana przy wczytaniu, więc upadek nie zatrzymuje klatki.

## Kierunek atmosfery poligonu

_Dawniej: `docs/KIERUNEK-ATMOSFERY-POLIGONU.md`_

### Poligon — przestrzeń, pigment i dźwięk

28 października 2026. Korekta po uwadze o bordiurze przecinającej wejście.
Stan: użytkownik **zaakceptował drugi szkic przerwanego obrzędu do wdrożenia**.
Pierwsza korekta samej kolorystyki nie uzyskała akceptacji. Poniżej zachowano
rozumowanie i historię podglądów; stan wdrożenia opisuje końcowa sekcja.
Po podglądzie użytkownik wskazał główny problem: „Brak grozy i znaczenia —
miejsce nadal nie wywołuje emocji”. Sama korekta temperatury koloru nie
jest wystarczającym następnym wdrożeniem.

#### Co osłabia obecny obraz

1. Bordiury biegnące przez otwór i półki bez ściany podważają wiarygodność
   miejsca. Przegląd obejmował obie strony obu przejść, narthex i absydy.
   Naprawiono także końce malowideł wystające poza mur przy galeriach.
2. Zbliżone wartości brązu obejmują kamień, malowidło, podłogę i demona.
   Duży kontrast mają powtarzane misy ognia. Wzrok przeskakuje między nimi,
   zamiast odczytywać kierunek i znaczenie ołtarza.
3. Powtarzanie tej samej sceny na kolejnych ścianach daje rytm galerii.
   Każde pole próbuje być istotne. Potrzebujemy także spokojnych powierzchni,
   na których można odczytać sylwetkę oraz kierunek ataku.
4. Zużycie materiału powtarza się równomiernie. Sensowniejsze są ślady
   użytkowania i rozpadu: wytarta droga, kopcenie nad paleniskiem, ubytek
   przy spoinie, skupisko gruzu pod konkretnym uszkodzeniem.
5. Obecny `soundscape.mood` rozróżnia walkę, bossa, menu i odpoczynek,
   ale nie nawę i kryptę. Rzadka kropla w `world_cues` jest ustawiana
   względem słuchacza, zamiast pochodzić ze stałego miejsca w pomieszczeniu.
   Muzyka i dźwięki mają więc słabe powiązanie z architekturą.

#### Jedna idea porządkująca miejsce

Propozycja scenograficzna: **dawne miejsce sądu, przekształcone w miejsce
wiązania demonów**. Jest to pomysł dla poligonu, a nie zatwierdzona fabuła
kampanii. Najpierw gracz widzi ludzki porządek: procesję, miarowy rytm
podpór, znaki wykonywanego obrzędu. Dalej widzi koszt jego utrzymania:
ossuarium, uszkodzone malowidła, ślady żaru. Przy ołtarzu zastaje nadal
czytelną pieczęć i obecność, którą miała powstrzymać.

Giovanni da Modena pozostaje wzorcem demonów i scen zintegrowanych z
architekturą; Michał Anioł — ciężaru figury; Bosch — ciemnych planów i
punktowego ognia; Memling — porządku obramowań. Malowane, matowe formy
obecnych demonów wyznaczają gęstość detalu. Nie potrzeba nowych ostrych
atlasów, by sprawdzić kompozycję i światło.

| Miejsce i rola | Obraz, kolor, światło | Dźwięk i znaczenie |
|---|---|---|
| Wejście — orientacja | Czytelna droga, przygaszona ochra i czerwony pigment, mało konkurujących jasnych punktów | Niski podtrzymany ton, wyraźny własny krok; chorał dociera z głębi |
| Nawa — skala i kierunek | Chłodniejszy popiół kamienia, powtarzalne podpory, ciepło tylko przy źródłach; oś kończy się malowidłem | Głos staje się pełniejszy, długi zanik zdradza dużą pustą przestrzeń |
| Krypta — bliskość i pamięć | Niska przestrzeń, kości w uporządkowanych niszach; jeden lokalny akcent. Przejścia nadal widoczne | Chorał oddala się, pozostaje mało warstw; kropla lub kruszenie ma konkretne źródło |
| Ołtarz — oczekiwanie | Spokojne pole wapna za demonem; pieczęć jest najważniejszym małym znakiem, czerwień pozostałością obrzędu | Przed aktywacją krótki spadek gęstości; następnie pojedynczy akcent i narastanie warstw |
| Walka — zagrożenie | Najważniejsze są sylwetka, przygotowanie i obszar ataku. Żar przy obrzeżu nie konkuruje z pociskiem | Zapowiedzi mają pierwszeństwo przed muzyką; rytm wynika z realnego stanu starcia |
| Po walce — pustka | Zanika obwód aktywnej próby, architektura ponownie dominuje | Cofnięcie pulsu i dzwonów, pozostaje zanik i ciche tło, bez automatycznej triumfalnej fanfary |

To propozycja emocjonalnego przebiegu. Samo zapisanie jej ani podgląd jednej
klatki nie potwierdzają odbioru gracza. Twórcy *Amnesii* opisują porządkowanie
projektu wokół zamierzonego odczucia i ograniczanie elementów, które mu nie
służyły. Przejmujemy tę zasadę selekcji; nasza walka pozostaje FPS-em.
[Frictional Games — Amnesia: Post-Mortem](https://frictionalgames.com/2011-07-amnesia-post-mortem/).

#### Konkretne podglądy i ich granice

`work/atmosphere-review/final/21-current-*.png` i `22-proposal-*.png`
pokazują te same kamery, czas, HUD i bazowego demona. Propozycja ma chłodniejszy
kamień, mniejsze/powściągliwsze ognie, przerwy pomiędzy plamami światła,
mniej powtórzeń scen oraz spokojne tło ołtarza. To render gry, bez generacji
nowych obrazów. Ujęcia obejmują nawę, próg, absydę i kryptę; absyda dodatkowo
960×540 oraz 1024×768. Podgląd krypty nadal odsłania zbyt dużo sąsiedniej sali:
ochrona intymności przejść wymaga osobnego przeglądu linii widoku. Tego nie
naprawi zmiana koloru. Podglądy nie udają gotowej przebudowy akustyki.

`work/atmosphere-review/atmosphere-route-proposal.wav` to 44-sekundowy szkic
z już istniejących warstw: 0 s wejście, 6 s nawa, 16 s krypta, 24 s
wycofanie przed przywołaniem, 27 s walka, 38 s pustka po walce. To sam miks
mono, bez kroków, wystrzałów i przestrzennego pogłosu. Nie jest nową ścieżką
dźwiękową ani dowodem dobrego miksu pełnej walki. Próbka dekoduje się poprawnie,
nie przesterowuje; peak 0,27857, RMS 0,03191. Jest poza zasobami gry.

#### Korekta kierunku: ślady przerwanego obrzędu

To nadal propozycja scenograficzna do obejrzenia, nie nowy kanon fabuły.
Ma wywołać pytanie: **co próbowano tutaj zatrzymać i czy zabezpieczenia
jeszcze działają?** Układ musi pozwalać wywnioskować związek między śladami,
zanim wyjaśni go opis. Trzy ujęcia szkicu pokazują:

1. **Ludzki porządek.** Niski próg, zadbana nisza wotywna, wydeptana droga
   i wysoka nawa. Małe przedmioty podają skalę człowieka. Ołtarz jest
   widoczny fragmentarycznie; pełne odsłonięcie następuje przy wejściu do
   sali. Fresk prowadzi spojrzeniem figur w tę samą stronę co architektura.
2. **Ślad niepowodzenia.** Zerwane mocowanie łańcucha, przemieszczone
   naczynie, przerwany stary ślad obrzędu i kierunkowe osmalenie. To jedna
   grupa przyczynowo powiązanych śladów przy progu, nie gruz na całej arenie.
   Stary ślad jest matowy; nie udaje aktywnej pieczęci ani pola obrażeń.
3. **Obecność.** Ołtarz i obecny demon stają się punktem skupienia. Wysoka
   przestrzeń pozostaje pusta nad graczem, tło za sylwetką spokojniejsze,
   światło boczne oszczędne. Gracz widzi ciało i przygotowanie ataku.

Pierwszy wygenerowany szkic miał zbyt ostry kamień i zbyt wiele palenisk.
Drugi upraszcza pigment oraz wygasza większość mis. Oba są ilustracjami
koncepcyjnymi, **nie renderami LÖVE ani gotowymi teksturami**. Nie potwierdzają
grozy w grze. Generowany znak na pulpicie nie zastępuje źródłowego PNG
Goetii; w implementacji korzystamy z obecnych reprodukcji. Widoczna w szkicu
szczelina nie zatwierdza nowej przeszkody: płytki ślad może być dekoracją,
ale rzeczywista wyrwa musi mieć zgodną geometrię, kolizję i nawigację.

Dźwięk powinien dopowiadać tę samą sytuację: głos z konkretnej głębi,
wycofanie warstw przy aktywacji, odpowiedź powiązana z rozpoczęciem próby,
czytelna zapowiedź pierwszego ataku i pustka po zakończeniu. Nie losowe
odgłosy udające pociski lub przeciwników za plecami. W testowym trybie
powtarzanie starcia nie może wymuszać długiego wstępu ani odbierać sterowania.

Frictional opisuje budowanie oczekiwania i znaczenia otoczenia oraz utratę
grozy, gdy gracz rozpozna nieskuteczność przeciwnika. Przejmujemy te obserwacje,
bez przenoszenia do FPS-a rezygnacji z walki lub niejasnych zasad obrażeń.
[9 Years, 9 Lessons on Horror](https://frictionalgames.com/2019-10-9-years-9-lessons-on-horror/).
Prado opisuje przemianę instrumentów muzycznych w narzędzia kary u Boscha.
Inspiracją jest tutaj zmiana znaczenia znajomego przedmiotu — ochronne
mocowanie staje się dowodem porażki — a nie zwiększanie liczby ozdób.
[Prado — The Garden of Earthly Delights](https://www.museodelprado.es/en/the-collection/art-work/the-garden-of-earthly-delights-triptych/02388242-6d6a-4e9e-a992-e1311eab3609).

Odbiór sprawdzamy najpierw na krótkim przebiegu wejście–próg–ołtarz,
z niezmienionym HUD-em, bronią i demonem, bez rozszerzania całej mapy.
Bez wyjaśnienia słownego gracz powinien móc wskazać ślad uszkodzenia,
powiązać go z ołtarzem i odróżnić starą pozostałość od aktywnej pieczęci.
Osobno oceniamy oczekiwanie przed walką i zagrożenie w walce: dekoracja
nie zamyka problemów z AI, animacjami, czytelnością ani wydajnością.

#### Wdrożenie po akceptacji, bez drugiego silnika atmosfery

1. Przenieść zatwierdzone ustawienia światła i rozmieszczenia z podglądu
   do danych mapy. Sprawdzić kierunek wejście → próg → ołtarz i powrót,
   przy przeciwniku w środku, z boku oraz blisko ściany. Zachować margines
   czytelności przy domyślnej jasności, bez podnoszenia detalu demonów.
2. Opisać regiony prezentacji danymi: granice, płynne przejście, profil
   istniejących warstw muzycznych i stałe źródła ambience. Wyznaczanie
   regionu ma być wspólne, a interpretacja osobna dla światła i audio.
   Bez sprawdzania nazw bossów lub map w wykonawcach.
3. Obecne stany próby sterują wejściem, starciem i zakończeniem. Miks
   korzysta z istniejących zapętlonych warstw i płynnej zmiany głośności;
   nie restartuje chorału przy przekroczeniu progu. Priorytet ostrzeżeń
   i limity głosów pozostają. Stałe źródła kropli podlegają osłonie ścian.
4. Ograniczyć dekoracyjne rozbłyski: najpierw odróżnić zagrożenie od żaru
   tła, potem oglądać realne pociski i nakładające się ataki w ruchu.
   Zmiana wyglądu efektu nie zmienia jego obrażeń ani granic kontaktu.
5. Odbiór: ta sama trasa z dźwiękiem i bez, ten sam boss, trzy odległości,
   normalna i niska rozdzielczość, reset oraz ponowne wejście. Mierzyć koszt
   i przycięcia; liczba ozdób i zdane testy nie są kryterium klimatu.

Weryfikacja napraw: 5047 sprawdzeń mechaniki/zasobów PASS, w tym siedem
regresji osadzenia dekoracji; 577 plików Lua i zero błędów architektury.
Rodzime ujęcia kontrolują brak mutacji symulacji podczas renderowania.
Ten przegląd nie zamyka pozostałych gestów demonów 7C–7F ani otwartego
kryterium wydajności punktów 1/8.

#### Wdrożenie zaakceptowanego kierunku — obraz

Wejście ma rzeczywiste obniżone sklepienie 3,2–3,8 m, a boczne progi
profil łuku zamiast płaskiego nadproża. Dalej odsłania się istniejąca wysoka
nawa. Kolizja i render czytają ten sam profil dachu. Zachowano miejsca
prób, otwarte tory walki i sterowanie; HUD, broń oraz atlasy demonów bez zmian.

Wygaszono większość palenisk, ograniczono powtarzane malowidła i usunięto
ozdobne kręgi mylące się z aktywnymi pieczęciami. Przy obu progach są
zerwane mocowania, przewrócone kadzielnice i płaskie ślady osmalenia;
druga pozostałość znajduje się pod absydą. Nowa grafika korzysta z tych
samych nazwanych zasobów, filtrów i oświetlenia co istniejące rekwizyty.

`chapel-ritual-remains-v34.png`: nowa generacja wbudowanym imagegen,
28.10.2026, 1254 × 1254 RGBA. Skopiowano oryginalne PNG bez retuszu.
Referencje: `props-fresco-v12.png`, `boss-idle-fresco-v13.png` i drugi
zaakceptowany szkic. Zlecenie: przezroczysty atlas 2 × 2, zimny trójnożny
kosz paleniska, wyrwane żelazne mocowanie z łańcuchem, przewrócona
kadzielnica z woskiem oraz widziany z góry stary ślad spalenizny.
Matowe pigmenty fresku, ograniczony detal, bez nowych znaków Goetii.
Kadry i proporcje opisuje `content/art/environment.lua`.

Nowe `decor.floorArt` to dekoracja powierzchni, nie hazard. Walidator
odrzuca ślad przecinający ścianę, podporę lub stopień; jeden quad jest
używany ponownie przez renderer. Nie dopisuje się stanu do symulacji.
Przegląd pierwszych ujęć ujawnił zbyt słabo widoczne mocowanie oraz półkę
schowaną pod freskiem; poprawiono ich położenie. Ujęcia kontrolne:
`work/atmosphere-implementation/visual-final/23-*.png`; bieżący przegląd
obejmuje także aktywne próby obu bossów i obraz 4:3.

Kontrola wdrożenia: mechanika/zasoby 5012 PASS (liczba obejmuje także
sprawdzenia zależne od liczby świateł), architektura 580 plików Lua / zero
błędów. Dziesięć nowych regresji sprawdza podparcie płaskich śladów i
rzeczywistą wysokość wejścia. Po ostatniej korekcie półki ponowiono rodzime
rendery; każdy kontroluje brak mutacji symulacji. Nie są oceną gracza.

#### Wdrożenie po obrazie — dźwięk

Zgodnie z kolejnością wskazaną przez użytkownika najpierw zapisano obraz
w `06f2051`, następnie rozszerzono audio. Muzyka nadal ma pięć zsynchronizowanych
warstw istniejącego chorału, organum, dronu, pulsu i dzwonów. Nie są to
nagrania chóru: brzmienia powstają z receptur syntezy. Nie dodano drugiego
odtwarzacza ani restartowania utworu przy przekroczeniu drzwi.

`content/maps/proving_soundscape.lua` opisuje stonowane wejście, pełniejszą
nawę, cofnięcie chorału przy zerwanym wiązaniu, krypty i oczekiwanie przy
absydach. Wspólny widok trybu udostępnia status oraz czasy próby. Portal
wycofuje warstwy walki; żywy przeciwnik wprowadza puls, a bliskość, zapowiedź
i wykonanie ataku oraz zdrowie obserwowanego rycerza podnoszą napięcie.
Po ukończonej próbie pozostaje sześć sekund spokojnego dronu, potem powrót
do miksu sali przez osiem sekund. Nie jest to nowa faza bossa ani zmiana AI.

Margrave ma cztery różne odgłosy przygotowania. Furfur rozróżnia bliski
cios, szarżę, powrót poroża, pojedynczy piorun i krzyż burzy. Przywołanie,
wejście i upadek mają własne dźwięki wybierane przez dane postaci.
`AttackCancelled`, uwolnienie ataku i śmierć kończą jego odgłos przygotowania.
Bilet konkretnego odtworzenia chroni przed zatrzymaniem innego dźwięku,
który dostał ten sam Source z puli.

Opóźnione pola brzmią przy rzeczywistym przejściu do aktywności. Osiem
równoczesnych plam ognia nie uruchamia ośmiu nałożonych wybuchów; późniejsze
uderzenia lancy i krzyża nadal są osobnymi odgłosami. Odgłosy łańcuchów,
kropli, muru i żaru mają stałe pozycje, odległość odsłuchu i tłumienie przez
ściany. Zaległe odgłosy nie nadrabiają po przycięciu. Zachowano limit
28 głosów i 28 buforowanych Source oraz priorytet ostrzeżeń nad tłem.

Kontrola: 5120 sprawdzeń mechaniki/zasobów PASS, 586 plików Lua / zero
błędów architektury. Nowe sprawdzenia obejmują prawdziwe polecenie próby,
przywołanie i koniec walki, przerwanie dźwięku, ponowne użycie Source,
czas aktywacji hazardu, nakładanie wybuchów, walidację odwołań do głosów,
ciągłość przejścia między regionami i brak zmiany symulacji.
Eksport początkowo ujawnił zbyt duży poziom oddechów; skorygowano ich
wzmocnienie i dodano sprawdzenie zapasu oraz końcówki każdej nowej receptury.

Dowody: `work/atmosphere-implementation/audio-final/` (73 efekty, pięć warstw,
sześć miksów i 48-sekundowy przykład przejścia), `av-final/` (rodzime rendery),
`work/qa-v33/test-results.txt`. Ostatni fingerprint źródeł:
`AD61DDB2358E0D799E2ED6D42CE2988D575E3CB767651E734555245C1384053A`.
Przykład odsłuchowy jest zmontowany z prawdziwych receptur i miksów, nie jest
nagraniem sesji gry. Szczyt 0,432, RMS 0,051, ponowne odkodowanie WAV PASS.
Pomiary próbek nie potwierdzają subiektywnego odbioru grozy ani ostatecznego
balansu głośności podczas długiej gry. Zakres 7C–7F i kryterium kosztu
punktów 1/8 pozostają osobnymi, otwartymi pracami.

#### Korekta osadzenia dekoracji — 29 października 2026

Zgłoszony napis Goetii rzeczywiście wychodził poza jasny tynk. Jego
niezależne współrzędne były poprawne względem muru, lecz nie względem
malowidła. Odtworzono to w rodzimym rendererze przed zmianą. Teraz
inskrypcja wskazuje id powierzchni, lokalny środek u/v oraz prostokąt
z marginesem. Skala glifów pozostaje jednolita. Walidacja odrzuca obszar
poza tynkiem, niejednoznacznego rodzica i stare niezależne współrzędne.
Przesunięcie lub obrót obrazu przenosi również jego napis.

Pierwszy podgląd nowego układu ujawnił, że centralny napis zlewa się
z pieczęcią stojącą przed nim. Ostatecznie cytaty są po bocznej stronie
tynku, poza znakiem w widoku podejścia do ołtarza. Nie zwiększano ich
kontrastu ani szczegółowości i nie zmieniono istniejących PNG ani treści
cytatów. Ukrycie malowidła w danym trybie ukrywa także jego inskrypcję.

Freski przedsionka dopasowano do rzeczywistej wysokości niskiego sklepienia;
wcześniej dach przecinał górną część scen. Pełne figury mieszczą się teraz
pod gzymsem. Bordiury powtarzają motyw z istniejącego atlasu w odpowiedniej
proporcji zamiast zgniatać go na długiej ścianie. Powtórzenie nadal korzysta
z jednego quada; zwykłe malowidła i sprite'y zachowują poprzednie UV.

Obejrzane ujęcia: oba ołtarze, bok i krawędź zachodniego fresku, niski
przedsionek, tylna inskrypcja, odczyt w 960 × 540 i podejście w 1024 × 768
(4:3). Dowody przed/po: `work/map-polish-29/before/`, `review-02/`.
To korekta osadzenia i proporcji, nie akceptacja całej oprawy przez gracza
ani zamknięcie otwartych 7C–7F. Drogi ruchu, kolizje, czasy walki, audio,
HUD, broń i bazowe grafiki demonów pozostały bez zmian.

Kontrola: `TEST.ps1 -Suite All` zakończony poprawnie, 5148 sprawdzeń
mechaniki/zasobów (28 nowych w `inscriptions`), 36 wejścia, 588 plików Lua
i zero naruszeń architektury. Wszystkie osiem etapów natywnych oraz checker
miały kod 0 i stabilne źródła. Fingerprint przed dopisaniem tej informacji
do dziennika zmian: `205449FA016D7BF6DFC8B8E65A27C6B91A4B0B823D8EBDEBA144C89F943D3010`.
Przebiegi narzędzi benchmark/core/step/audio w tym zestawie są testami smoke,
nie nowym pomiarem wydajności ani oceną odsłuchową.
