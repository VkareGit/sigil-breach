# Poligon — przestrzeń, pigment i dźwięk

28 października 2026. Korekta po uwadze o bordiurze przecinającej wejście.
Stan: błędy osadzenia dekoracji poprawione; nowa kolorystyka i przebieg
muzyki są **niezaakceptowaną propozycją**, dostępną w podglądach QA. Zwykła
gra zachowuje dotychczasową paletę, miks, HUD, broń i demony.
Po podglądzie użytkownik wskazał główny problem: „Brak grozy i znaczenia —
miejsce nadal nie wywołuje emocji”. Sama korekta temperatury koloru nie
jest wystarczającym następnym wdrożeniem.

## Co osłabia obecny obraz

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

## Jedna idea porządkująca miejsce

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

## Konkretne podglądy i ich granice

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

## Korekta kierunku: ślady przerwanego obrzędu

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

## Wdrożenie po akceptacji, bez drugiego silnika atmosfery

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
