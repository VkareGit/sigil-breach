# SIGIL: BREACH — PLAN v7: trafienia zgodne z tym, co gracz widzi

Stan: przyjęty 2026-10-22. Zastępuje szkic PLAN-ROZWOJU-v6.md (jego wnioski o hitboxach
były częściowo błędne, a etapy H1 i H5 łamały zasady poniżej). Postęp etapów: sekcja 9.

Od 2026-10-25 nazwy ZMIANY-x.txt i ODBIOR-x.txt to nagłówki sekcji w game/docs/ZMIANY.txt
i ODBIOR.txt; PLAN-ROZWOJU-v6.md to sekcja docs/history/PLANY.txt.

Oznaczenia: **[K]** potwierdzone w kodzie, **[R]** wcześniejszy pomiar, **[H]** hipoteza,
**[T]** wymaga testu.

Aktualizacja 2026-10-23 / 0.31: powyższy kierunek pozostaje aktualny. Hitscan
otrzymał jawny kontrakt ostatnio pokazanej obserwacji z obsługą kliknięcia,
przytrzymania, bufora i replay. Kontrolowane wnętrza sylwetek w ponownym pomiarze
mają zero wcześniejszych chybień/zmian strefy, materiału i obrażeń. Nie jest to
gwarancja zgodności wszystkich pikselowych krawędzi. Doszły walidacja definicji,
katalog animacji/FX, kierunek impulsu od źródła i okrągłe kontakty granatu.
Zakres Foundation 0.31 zachowuje menu i HUD 0.30 oraz istniejący poligon,
bez nowego trybu. WAVE TRIAL sprawdza pojedynczą falę; pełny normalny cykl
fal/sklepu/śmierci/echo nie jest oferowany z menu. HUD wielu slotów wyposażenia
nie jest wdrożony i pozostaje zależnością przy dodawaniu kolejnego przedmiotu.
Kontrakt AbilityCast i katalog animacji pozostają w kodzie.
Pierwsze ładowanie galerii rozłożono na widoczne przygotowanie; koszt pamięci
nadal jest mierzony. Malowane medale i podpisy galerii nie zmieniają walki.
Styl pojedynczej nowej pozy chwytu został zaakceptowany. Jej ręczny retusz
pozostaje warsztatowy; pełny atlas nie jest zintegrowany. Odbiór całego cyklu
broni i feelingu przez człowieka nadal OTWARTY. Aktualne ograniczenia
i dalszy odbiór: ODBIOR-0.31.txt; dowody: work/qa-v31. Poniższy opis 0.30 jest
historią reprodukcji, a nie nieusuniętą usterką czasu strzału.

Aktualizacja 2026-10-23 / 0.30: rozszerzalność domknięta w zakresie opisanym w
ROZSZERZANIE.txt (broń jako kompozycja, dziedziczenie, dwa transporty, generic throw,
zapis slotów08, dowód render/HUD/save/replay). Poprawiono prawdziwość leczenia/gardy,
celownik przy szybkiej zamianie, zasłanianie tekstu i cache tuszu.
To nie zamyka całego odbioru trafień/B2. Nowy pomiar `--hit-timing` porównuje
faktyczny kontakt ze środkiem namalowanej powierzchni poprzednio pokazanej klatki:
held/buffer po 5 chybień i 4 zmiany strefy na 392 ważne próby; bezpośredni
mousepressed 1 chybienie na 381. Zmiany dyskretnej klatki dotyczą także nieruchomej
w przybliżeniu bryły; sam root-delta nie wystarcza. To kontrolowane scenariusze,
nie procent wszystkich strzałów graczy. Nie dodano aim assist ani większych hitboxów.
Przed oznaczeniem bazy jako w pełni odebranej rozstrzygnąć czas odniesienia hitscan
(ostatnio pokazana obserwacja vs bieżący krok) wraz z buforem i replay, następnie
powtórzyć pomiar. Nadal otwarte B2 i korekta fizycznego chwytu broni.

## 0. Cel i zasady

Dopracowujemy jeden poligon, dwie bronie i obecnych przeciwników. Priorytet: zgodność
grafiki, animacji, geometrii, fizyki, obrażeń i informacji zwrotnej.

- Dokładność jest wymaganiem. Nie poprawiamy wyniku raportu ani wydajności kosztem
  widocznych błędów trafienia.
- Płynność strzelanki w duchu Dooma, czytelne zamachy, świadome uniki. Rycerz jest
  człowiekiem bez magii.
- Bez kampanii, nowych map, łupów i zaklęć gracza.
- Żywy, mroczny fresk (Giovanni da Modena, Michał Anioł, Bosch, Memling). Mrok i detal
  nie mogą zacierać anatomii, przerw między kończynami, zamachów ani słabych punktów.
- Liczba testów nie dowodzi perfekcji; nie jest też powodem do obniżania wymagań.

## 1. Ustalenia (weryfikacja 2026-10-22)

Poniższa sekcja opisuje stan bazowy 0.26–0.27, nie aktualną implementację 0.28.
Wynik wdrożenia i ograniczenia znajdują się w sekcji 9 oraz ANATOMIA-I-FIZYKA-0.28.txt.

### 1.1 Co mierzył raport hitboxów 0.26
- [K] Mierzył klatki podglądu (`previewFrame`): `Anim.pose` zwraca wtedy klatkę bez
  pochylenia, ściśnięcia, drgnięcia, unoszenia i wysokości skoku.
- [K] Mierzył też klatki widziane tylko u trupów (rozszerzony układ 17–18, zwarty 12);
  strzały pomijają ciała z hp <= 0 (`ballistics.lua`: prepare, traceVector).
- [K] Nie mierzył nakładek umiejętności (skok Sługi, unik Akolity, po 8 klatek); w tym
  czasie bryły idą za klatką bazową.
- [K] „Powietrze” to udział przekroju brył nad pikselami alfa <= 0,5 w jednym widoku
  z 8 m, nie odsetek błędnych strzałów. Renderer odrzuca piksele alfa < 0,30 i dla
  żywych ciał rysuje kontur o szerokości jednego teksela siatki 320×320.
- [R]→[K] Realne wady żywych póz: przewrócenie Sługi 15/16, Ogrodnika 10/11,
  Margrabiego 10/11 (bryła głowy w 96–100 % nad powietrzem); Furfur w bólu i
  przewróceniu (klatki 12–18) dostaje bryły chodu; Akolita nie ma czaszki dla 14–16.

### 1.2 Korekty szkicu v6
- Chwianie bossa (`exposed`) to klatka 9; 7 = cios, 8 = odzyskiwanie, 10 = przewrócenie.
- Czaszka bossa to stały słaby punkt (pancerz głowy 0 zawsze); `exposed` połowi
  pancerz (tułów 30 -> 15, nogi 45 -> 22,5). Pudło czaszki zaliczone jako tułów traci
  pancerz 0, mnożnik głowy (Sędzia 1,35, strzelba 1,15) i gardę głowy 1,25.
- Wycofane: „głowa = najwyższa grupa pigmentu” i progi „powietrza”.

### 1.3 Animacja a geometria
- [K] Skala nakładek umiejętności wynika z wysokości bryły głowy
  (`render/ability_art.lua`: resolve) — kalibracja hitboxu zmienia rozmiar demona.
- [K] Głowa to trzeci element tablicy brył (geometry, ability_art, showcase, testy);
  kształt = strefa obrażeń (bark Ogrodnika to czwarta bryła 'torso').
- [K] Kolejność części jednego ciała rozstrzyga głębokość walców (promień w stronę
  kamery), choć sprite jest płaski.
- [K] Wszystkie bryły to pionowe walce; brak kształtu leżącego.
- [K] Pasma brył liczone od `hover`, obraz od `baseY = hover - foot * height`.

### 1.4 Geometria według odpowiedzialności
- [K] Ruch: jedno koło body.radius (domyślnie 0,25 m), niezależne od brył trafień.
- [K] Pazur: abstrakcyjne kule (r 0,18 na 0,94 m, zasięg 0,25/0,55/0,86, łuk ±0,72 rad,
  aktywne 0,055–0,18 s, kroki 1/120 s, z ruchem rycerza); niezwiązane z namalowaną łapą.
- [K] Szarża: odcinek drogi z promieniem; lądowanie skoku: test odległości w chwili
  lądowania; pociski demonów: cała droga z własnym promieniem.
- [K] Pocisk rycerza: droga jako linia bez promienia; bryły liczone na nowo na pocisk.
- [K] Umierający i zwłoki są przezroczyści dla strzałów (reguła nieopisana).
- [K] Przesłony: tylko mapa (ściany, kolumny-walce, podłoga) i inne ciała.

### 1.5 Balans i telemetria
- [K] Zabójstwo przełamane: stun > 0, staggered, exposed albo przełamanie w ostatnich
  2 s; przełamaniem jest złamana garda, przewrócenie **i poważna rana**.
- [K + arytmetyka] Sługa 112 HP, próg rany 45 % = 50,4; Sędzia zadaje 70 (do 12 m, bez
  pancerza) i impet 44 > garda 36: każde trafienie to rana i przełamanie, drugie
  (0,38 s później) zabija. [H] Główne źródło 43 % w Twojej sesji; skrócenie okna nic
  tu nie zmieni.
- [K] Mikroogłuszenie bossa (0,035 s) liczy się jako przełamanie.
- [K] Leczenie: potencjalne 0,25 × garda; telemetria liczy tylko odzyskane; napis
  pokazuje potencjalne, także przy pełnym zdrowiu; niewykorzystane niemierzone.
- [K] Czas wroga od 0,6 s po pojawieniu (także nieświadomego); kontrola = stun albo
  hurt (z mikroogłuszeniem); czas zabicia od narodzin; „trafienia” = strzały z celem.
- [K] Reżyser tempa zmienia presję fal — porównania sesji wymagają stałych scenariuszy.

### 1.6 Powtórki i złoty wzorzec
- [K] Dziennik nie zapisywał akcji poligonu (cele, stacje, reset, tier, god, freeze,
  pozy, zasoby) — naprawa w H0.
- [K] Złoty wzorzec = odcisk regresji trzech scenariuszy (pola wybrane), nie wyrocznia
  poprawności; nie obejmuje części ciała, stanów, telemetrii ani poligonu.

## 2. Kolejność i zależności

```
D0 dokumentacja
H0 pomiar i stanowisko ──► H1 wspólny opis pozy ──► H2 kształty / strefy / materiały
                                                        │ (H1–H2 bez zmiany rozgrywki)
H3 przewrócenie + czaszka bossa ──► H4 kończyny, przerwy, nakładki ──► H5 materiały
H6 geometria ataków · H7 umierający i zwłoki · H8 wydajność · H9 powtórki i wzorzec
B1 definicje telemetrii ──► B2 ocena balansu
```
H1–H2 przed H3: poprawka głowy zmieniłaby dziś rozmiar nakładek [K], a rozdział kształtu
od strefy wymaga stabilnych identyfikatorów. Dwa najbardziej mylące przypadki są
**zweryfikowane jako pierwsze w H0** (testy oczekujące z liczbami).

## 3. Etapy

**D0 — spójna specyfikacja (tylko dokumenty).** Bez sprzeczności: leczenie za zabójstwo
przełamane, zapis SIGIL07 (czyta SIGIL06), pancerz głowy per część, zakres powtórek,
wysokość podłogi, „bez magii” (sloty F/C = wyposażenie). Specyfikacja oddzielona od
historii i pomysłów.

**H0 — co faktycznie mierzymy (bez zmiany rozgrywki).**
1. Akcje poligonu jako polecenia dziennika, warunki początkowe w nagłówku.
2. Stanowisko żywych póz: prawdziwa sesja, każdy stan (ruch, zamach, cios,
   odzyskiwanie, zachwiania, chwianie bossa, przewrócenie: upadek/leżenie/wstawanie,
   skok: kucnięcie/lot/lądowanie, unik, wyjście z portalu), próbki na granicach klatek.
3. Prawda obrazu: promień przecina płaszczyznę sprite'a z transformacją renderera
   (rozciągnięcie, pochylenie, odbicie, siatka 320, próg alfa 0,30, kontur żywych ciał,
   nakładki umiejętności).
4. Trzy raporty: dopasowanie brył do obrazu; rozliczenie strzałów w żywe cele (część,
   strefa, obrażenia); umierający i zwłoki.
5. Macierz strzałów: 2/8/16/30 m, oko stojąc / w przysiadzie / w skoku, przesunięcia,
   ściana przed celem, cele w linii.
6. Niezależne punkty anatomiczne (czaszka, czoło, szczęka, żebra, nogi, przerwa między
   nogami, róg, skrzydło, powietrze przy konturze) — najpierw przewrócenie i boss.
7. Odstęp „poza widziana ↔ poza rozliczana” przy kilku krokach symulacji na klatkę.
8. Prototyp decyzji reprezentacji (sekcja 4).

Koniec: każda wada z 1.1–1.3 potwierdzona albo obalona liczbą; wady zapisane jako testy
oczekujące; złoty wzorzec bez zmian.

**H1 — wspólny opis pozy.** `enemies/pose`: arkusz (bazowy lub nakładka), klatka,
odbicie, transformacja, punkty zaczepienia. Wybór nakładki w symulacji (czyta tylko jej
pola). Nakładka rejestrowana do punktów pozy, nie do bryły głowy. Koniec: rendery
identyczne, złoty wzorzec bez zmian, test: zmiana kalibracji głowy nie zmienia grafiki.

**H2 — kształty, strefy, materiały (bez zmiany zachowania).** Stabilne identyfikatory
kształtów (`head`, `torso`, `shoulder`, `legL`, `legR`…) osobno od strefy obrażeń i od
materiału; jedno zapytanie o trafienie dla strzałów, pocisków i wybuchów. Koniec: brak
odwołań do pozycji w tablicy; złoty wzorzec bez zmian.

**H3 — przewrócenie i czaszka bossa (pierwsza zmiana rozgrywki).** Geometria dla klatek
przewrócenia wszystkich demonów i póz bossa 5, 7–11. Różnice złotego wzorca wyjaśnione
dziennikiem trafień przed i po. Koniec: testy oczekujące z H0 dla tych póz przechodzą.

**H4 — kończyny, przerwy, nakładki, przejścia.** Pełna macierz z H0 dla każdej klatki
osiągalnej przez żywe ciało.

**H5 — materiały i reakcje** (zasady do akceptacji):

| Element | Przecina | Zatrzymuje / przepuszcza | HP | Reakcja |
|---|---|---|---|---|
| róg, poroże | tak | śrucina stop; kula dalej z utratą | brak; garda tak | iskra, odprysk |
| płyta pancerza | tak | stop | przez rating części | iskra metalu |
| błona skrzydła | tak | przepuszcza z utratą | mały mnożnik | rozdarcie, drgnięcie |
| płaszcz, włosy, efekt | nie | — | — | ruch tkaniny |
| ciało | tak | śrucina stop | strefa | krew |

**H6 — geometria ataków.** Łuk i okno pazura z drogi dłoni w klatkach ciosu; szarża
przodem ciała; lądowanie obszarem ciała; pocisk rycerza z promieniem.

**H7 — umierający i zwłoki.** Jawna reguła (propozycja: padające ciało zatrzymuje śruciny,
bez HP); test „trup przed żywym”.

**H8 — wydajność.** Pomiar od H0 (20 śrucin × N ciał × kształty, koszt pozy, alokacje,
20 demonów, zmienny FPS). Wstępne odrzucenie tylko obwiednią udowodnioną jako pełną.
Każde obniżenie dokładności zmierzone i opisane — albo żadnego.

**H9 — powtórki i wzorzec.** Scenariusz złotego wzorca ze skrótem dziennika trafień
(część, strefa, materiał, obrażenia) i narzędzie różnic.

**B1 — telemetria.** Czasy: od pojawienia, od świadomości, od pierwszego trafienia,
aktywnej walki; kontrola z rodzajami; leczenie potencjalne / odzyskane / zmarnowane;
przyczyna premii (garda, przewrócenie, rana, mikroogłuszenie).

**B2 — balans.** Stałe scenariusze (ziarno, wyposażenie, skład, tier, reżyser wył./wł.),
kilka sesji człowieka z próbą fal; zmiany geometrii i nagród w osobnych krokach;
ocena także płynności, czytelności i poczucia kontroli.

## 4. Reprezentacja trafień — decyzja w H0
(a) więcej kapsuł na klatkę; (b) maska etykiet w płaszczyźnie sprite'a; (c) hybryda:
obwiednia + maska. [H] Rekomendacja: (c) — obraz to płaski billboard, więc prawdą
o trafieniu jest piksel w płaszczyźnie rysowania. Maski wypalane offline do danych Lua
(symulacja nie czyta obrazów). Obwiednia musi zawierać każdy piksel maski.

## 5. Zmiany architektury
1. `enemies/pose` — jedno źródło pozy dla symulacji i renderera.
2. Dane kształtów: identyfikator, strefa, materiał osobno; maski/kapsuły jako dane.
3. Jedno zapytanie o trafienie (strzał, pocisk, wybuch), jawna reguła zwłok.
4. Tabela materiałów w content, reakcje w słuchaczach prezentacji.
5. Akcje poligonu jako polecenia dziennika.
6. Złoty wzorzec z dziennikiem trafień i narzędziem różnic.
7. Definicje telemetrii.
Bez ogólnych systemów „części ciała” ponad potrzeby obecnych demonów.

## 6. Kryteria akceptacji (jednocześnie)
Trafienie w widoczną podatną część; pudło w wyraźnej pustce; właściwa strefa i materiał;
poprawny wynik obrażeń; reakcja zgodna z trafieniem; poprawna kolejność kontaktów i
zasłaniania. Strzały: między nogami, przy krawędzi głowy, w leżące ciało, przez przesłonę,
w kilka celów w linii; strzelba — każda śrucina i suma salwy; ślad, ślad na ścianie
i liczba w punkcie kontaktu, także przy ścianie. Tolerancje: jeden teksel siatki
renderera 320 na obwiedni obrazu (pas niepewności krawędzi wykazany osobno, nie
ukrywany).

## 7. Ryzyka
Animacja (rejestracja nakładek), fizyka (ruch niezależny od kształtów), obrażenia (czas
zabicia zmieni się — mierzymy, nie tłumimy), wydajność (pamięć masek, LuaJIT,
determinizm), praca nad etykietami (~170 klatek + 16 nakładek), brak głębi sprite'a.

## 8. Odłożone
Kampania, mapy, łupy, zaklęcia gracza, nowe bronie; kompensacja opóźnień sieciowych;
modele 3D; rysowanie podłogi innej niż 0 (dopóki mapa jej nie używa); niszczenie części
ciała jako mechanika.

## 9. Postęp
- **D0 — wykonane w 0.27** (ZMIANY-0.27.txt, punkt 1).
- **H0 — wykonane w 0.27** (ZMIANY-0.27.txt, punkty 2–4; raporty work/qa-v27/hit-*).
  Narzędzia: qa/hit_truth.lua (prawda obrazu, zgodna z GPU w 99,9 % poza pasem
  krawędzi), qa/reviews/hit_truth.lua (`lovec game --hit-review`),
  qa/data/hit_landmarks.lua + tests/cases/hit_landmarks.lua (101 punktów, 54
  znane wady: 41 → H3, 13 → H4), tools/art/landmarks/crops.ps1 (oznaczanie).
  Nowe ustalenia H0 (do etapów):
  - **Strzał z bliska** [zmierzone]: oko rycerza wewnątrz bryły Sługi/Żelaznego/
    Furfura w 39 % / 33 % / 5 % żywych kroków przebiegów — każdy strzał trafia
    wtedy tułów lub nogi, w dowolnym kierunku. Należy do H3 (zapytanie
    o trafienie musi liczyć wejście promienia w obraz, nie start w bryle).
  - **Bryły zależą od renderera** [zmierzone, do 0,69 m] — H1 (opis pozy
    należy do symulacji).
  - **Bossowie nie są przewracani za życia** — ich klatki upadku to zwłoki (H7).
  - **Lądowanie skoku na rycerzu** przesuwa Sługę o 0,42 m w jednym kroku
    (kontakt ciał) — do sprawdzenia w H6.
  - Decyzja reprezentacji (sekcja 4): koszt nie rozstrzyga (bryły 0,075 µs,
    maska 0,015 µs na promień); maska jest zgodna z obrazem z definicji
    (99,9 % względem GPU), walce nie (patrz hit-fit.txt). Rekomendacja (c)
    podtrzymana; maska bitowa ~13 kB na klatkę.
- **0.28 — wdrożenie po H0:**
  - H1: katalogi klatek i enemies/pose są niezależne od GPU; renderer tylko
    dołącza obraz. Test zimnego startu bez grafiki i zmiany kalibracji głowy.
  - H2–H4: enemies/surface, wypiekane maski pigmentu i autorskie regiony
    wszystkich 168 klatek (w tym skok/unik). Osobne id/zone/material i dowolna
    liczba części. Oryginalne 101 punktów, bez przesuwania współrzędnych:
    poprawne trafienia z 3/8/16 m. Brak kontaktu przy strzale odwróconym od
    dotykającego ciała w 9735 próbkach. Salwa zamraża pozę przed hałasem.
  - H5: tabela materiałów wdrożona. Doprecyzowanie: szata na ciele i grzywa
    należąca do sylwetki nie uodparniają ciała; luźna tkanina i odłączone
    efekty są pomijane. Kość czaszki jest podatna; róg nie zabiera HP.
    Metal zatrzymuje przebicie, błona ma współczynnik 0,25. Rykoszet nie
    został dodany: normalna płaskiego billboardu nie opisuje krzywizny rogu.
  - H6: punkty dłoni/pyska + fizyczny zasięg; ciągły kontakt szarży i niskiego
    skoku z poruszającym się graczem; czas lądowania; promień pocisków demonów
    także przeciw światu. Hitscan pozostaje promieniem bez promienia kuli.
    Sweep maski jest konserwatywny, z tolerancją połowy przekątnej komórki.
  - H7: padający trup blokuje do corpse.settle, bez HP/nagród; potem przepuszcza.
    Osobna regresja żywego celu za padającym i osiadłym ciałem.
  - H8: prawdziwe B.prepare + 20 promieni dla 1/10/20 mieszanych demonów,
    alokacje i rozkład czasów; hit-performance.txt/csv. Wynik nie jest FPS-em
    całej gry. Obwiednia jest pełnym quadem, bez odcinania wystających części.
  - H9: Journal v2 sprawdza stan początkowy/końcowy i wskazuje pierwszy różny
    kontakt; złoty wzorzec zawiera skrót części, materiału i wyniku każdej kuli.
    Uzasadnienie zmiany wzorca: ZMIANY-0.28.txt, nie sama potrzeba zielonego testu.
  - B1: czas od pojawienia/świadomości/pierwszej rany, aktywna walka, rodzaje
    kontroli i potencjalne/odzyskane/zmarnowane leczenie są mierzone osobno.
  - B2: regresje i boty uruchamiane, HP i bazowa moc broni bez retuningu.
    **Sesje człowieka i ocena odczucia pozostają do wykonania przez gracza.**
  - Uczciwa granica H0/H4: pomiar GPU ma 289 rozbieżności poza pasem krawędzi
    na 1 159 492 promienie (47 460 w pasie); CPU nie modeluje mipmap idealnie.
    Nie oznaczamy tego jako matematycznie identycznego renderowania. Raport
    hit-timing.csv pokazuje też odstęp ostatniej wyświetlonej i rozliczonej
    pozy przy 30/60/120/144/240 FPS i jitterze; interpolacja nie znika.
  - Styl: wszystkie 155 PNG/JPG identyczne SHA-256 z 0.27. Bez nowych modeli
    potworów; broń ma łagodniejszy pigment przy identycznej alfie i obrysie.

- **0.29 — dopracowanie rdzenia 0.28 (ZMIANY-0.29.txt), bez zmiany złotego wzorca:**
  - HITBOXES rysuje maskę/regiony/strefy/materiały, pierścień ruchu i kontakt
    ataku (wcześniej stare walce).
  - H7 poprawione: padające ciało zasłania do ostatniej klatki upadku (nie tylko
    0,33 s osiadania) i zatrzymuje także pociski rycerza (enemies/corpse.lua).
  - Przyczyny przełamania ustalane raz w Rules.offBalance i niesione zdarzeniem.
  - Walce malowanych demonów usunięte; appearance.hit wybiera reprezentację.
  - Anatomia: jedna konwencja współrzędnych, maski RLE związane ze źródłem,
    walidacja Anatomy.problems, appearance.regions, materiał debris.
  - Koszt: Snapshot 6×, pociski 9× szybsze; telemetria bez wycieku rekordów.
  - Test rozbudowy creature-extension (istota na istniejącym obrazie).
  - Domknięcie audytu: wielokąty regionów mają kontrolę niezerowego pola,
    a region zastępczy wymaga czterech różnych narożników w kolejności obwodu.
    Wszystkie 168 masek sprawdza SHA-256 całego PNG, prostokąt klatki,
    filtrowanie i klasyfikator. Ponowny wypiek nie zmienił żadnego z 53 760 wierszy.
  - Snapshot ma jawny kontrakt niezmiennych definicji oraz
    invalidateDefinitions() dla narzędzi dodających zagnieżdżone definicje.
    Oddzielny raport wybranej grupy testów nie nadpisuje pełnej regresji.
  - Skok i unik: korekta samego pigmentu RGB istniejących atlasów. Sylwetki,
    alfa i hitboxy zachowane; osobny render przed/po wszystkich 16 klatek.
    Odrzucono próbę generowania zmieniającą kontury zamiast podmieniać modele.
  - Z assets/art przeniesiono 25 nieużywanych PNG (47,77 MiB) do odwracalnego
    archiwum work/archive-art-v29 z sumami SHA-256 i skryptem przywracania.
    Źródłowe pieczęcie, obrazy używane przez testy i warsztat pozostają.

Następny etap odbioru: sesje B2 z dziennikiem F9 (w tym decyzje: poważna rana
jako przełamanie, materiał piór) i dalsza ocena resztkowych różnic obrazu na
krawędzi/mipmapach. Nie rozpoczynamy kampanii ani nowych map.

## 10. Źródła porównawcze
- Valve: Hitbox, CCollisionProperty, Lag Compensation (developer.valvesoftware.com) —
  hitboxy obrażeń osobno od bryły ruchu; rozliczenie względem tego, co gracz widział.
- Doom Wiki: Hitscan, Flawed collision detection — jeden przekrój na potwora (znana wada).
- Doom Wiki: Destructible demons; Bethesda „Designing Demons” — słaby punkt wyłącza atak,
  większość zniszczeń kosmetyczna (materiały prasowe, nie implementacja).
- Kiranico / Fextralife (Monster Hunter) — strefa i niszczenie części jako osobne osie
  (dokumentacja społeczności).
- Street Fighter 6 (infil.net, EventHubs) — aktywne klatki ataku jawne dla gracza.
- Erin Catto, Continuous Collision, GDC 2013 — czas pierwszego kontaktu.
