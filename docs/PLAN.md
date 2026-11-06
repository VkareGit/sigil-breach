# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-06: Margrave of Ash — analiza zakończona, plan DO AKCEPTACJI.**
Właściciel uważa obecną walkę za dobrą i zlecił całościowy przegląd.
Nie rozpoczęto wdrożenia. Rekomendacja: dopracować obecnego kata z tasakiem
oraz popiołem, bez dodatkowego dużego czaru. Zachować 2700 HP, pakiety
obrażeń, nagrodę, dwa akty i pękniętą gardę 1,2 s. Margrave pozostaje elitą,
nie bossem. Chroniony HUD i pozostałe postacie poza zakresem.
Pełne wyniki, inwentarz czynności, zależności i źródła są w HISTORII,
w rozdziale „Analiza Margrave'a (2026-11-06)”. Poprzedni PLAN Furfura
zachowano tam w całości.

## Proponowana kolejność po akceptacji

1. Utrwalić czerwone testy lądowania, nieograniczonej serii, rozjazdu
   kierunku ciała i ciosu, zapowiedzi pod graczem oraz oczekiwania w grupie.
   Dotychczasowe sondy i rendery pozostają dowodem wejściowym.
2. Naprawić kontakt lądowania: ciało zatrzymuje się 1,52 m od gracza,
   a trafienie sięga 1,32 m. Dopasować kontakt do widocznego uderzenia
   i popiołu; bez niewidocznego rozszerzania zasięgu. Zachować obrażenia 56,
   zamrożony cel lotu i ściany. Oddzielić lądowanie od następującej niskiej
   fali nowym, czytelnym oddechem: wstępnie około 0,5 s. Pomiar musi
   potwierdzić, że pierwsze trafienie nie wymusza drugiego. Nie zwiększać
   prędkości skoku tylko dlatego, że z 11 m nie dolatuje do samego celu.
3. Ograniczyć serię tasaka do najwyżej trzech ciosów, wliczając reakcję
   na przedwczesny unik. Zachować zmienne przytrzymania, serie 1–3 i pełne
   końcowe 1,2 s odpowiedzi. Opcjonalny parametr treści i wspólny licznik,
   bez wyjątku po nazwie Margrave'a. Stan licznika musi przeżyć Continue.
   To celowa zmiana balansu do przyjęcia, nie usuwanie błędu składni.
4. Powiązać widoczny obrót z rzeczywistym kierunkiem istniejących cięć,
   wykorzystując wspólny mechanizm `turnBody`. Nie dodawać naprowadzania.
   Włączyć Margrave'owi istniejące pierwszeństwo po oczekiwaniu na miejsce
   w grupie, wstępnie 0,9 s jak u Furfura. Nie podnosić limitów atakujących,
   nie przerywać cudzych serii. Zachować celowe przygotowania i powroty.
5. Zachować obecne rodziny ataków: cięcia/pchnięcie, skok i niska fala,
   trzy kolejne ogniska popiołu z osobnym pociskiem, bliski cios fizyczny
   i krótki wybuch żaru. Nie włączać siedmiu dawnych, nieużywanych definicji.
   Bliski `stomp` pokazać jako ciężkie uderzenie tasakiem w posadzkę:
   pojedynczy niski kontakt fizyczny, odmienny od utrzymującego się żaru.
   Zachować jego obszar i obrażenia; obraz musi objąć rzeczywisty obwód.
6. Rozróżnić gesty zamachu, ciosu powrotnego, pchnięcia, skoku, uderzenia
   w ziemię i czaru. Najpierw istniejące 32 klatki i ich poprawne przejścia.
   Zachować twarz, anatomię, fakturę, skalę detalu, ubranie i tasak. Nowa
   grafika wyłącznie przy faktycznym braku pozy, z bazą oraz Inferno jako
   referencjami i kontrolą przed podłączeniem. Nie zastępować bazy.
7. Usunąć mylący ognisty wygląd zwykłego fizycznego cięcia: ślad tasaka
   w zgaszonym materiale metalu/popielatej kości; ognisty ślad tasaka
   oznacza drugi akt (czary ognia istnieją już w pierwszym).
   Trzy ogniska popiołu mają pokazywać kolejne rzeczywiste miejsca erupcji,
   również spod poziomej kamery. Niska fala ma czytelny grzbiet do wysokości
   rzeczywistego kontaktu 0,5 m. Pocisk wychodzi z tasaka lub dłoni zgodnie
   z gestem i anatomią, w kierunku faktycznego lotu. Niegroźny popiół po
   wygaśnięciu różni się od trzysekundowego, nadal groźnego śladu cięcia.
   Bez neonów, nowych jasnych kręgów i przemalowania wspólnego ognia.
8. Dodać własny głos ciała: suchy, zdarty ludzki oddech, chrapliwy wysiłek
   i krótka wściekłość potępieńca. Osobno obecność, pościg, alarm, zamach,
   wypuszczenie, powrót, ból/przerwanie oraz trzy śmierci. Warianty i cisza
   między odgłosami. Tasak, kamień i żar osobno; własne profile Margrave'a,
   bez podmiany współdzielonych próbek innych stworów. Źródła, licencje,
   przetwarzanie; miks ze strzałami/muzyką/grupą i próbka do odsłuchu.
9. Trzy zapisane kontrole grafiki: każda zmieniona klatka/tekstura obok
   bazy w tej samej skali, rendery 3/6/10 m w tym samym świetle, przejścia
   wszystkich stanów. Anatomia, maski, cień, kierunek i punkty emisji.
   PASS testu i suma pliku nie zastępują oględzin ani odbioru właściciela.
10. Testy 60/120/240 Hz: kontakt/chybienie/skok/odejście/kontra, ściany,
    kolumny i wysokości, przerwanie/śmierć/przejście aktu, zapis na dysk
    i Continue we wszystkich fazach, odpoczynek, grupy i zwalnianie zasobów.
    Zachować zasadę, że już wypuszczony materialny ogień/pocisk może trwać
    po śmierci; nie kopiować automatycznie wygaszania burzy Furfura.
    Stare rozpoczęte czynności w zapisach wymagają świadomej migracji.
11. Pomiar przed/po w odrębnym klonie: solo, grupa mieszana, większa liczba
    ciał i faktycznie nakładające się efekty/głosy. Audio: dynamika, clipping,
    warianty, suwaki, dystans/ściany, limity, przerwanie/pauza/odpoczynek,
    zmiana świata i osobny RNG. Odsłuch właściciela osobno od pomiaru.
12. Dwa identyczne golden dla celowych zmian symulacji, z uzasadnieniem;
    nie ruszać wzorca Windows bez jego weryfikacji. Pełne Linux All
    (`scripts/linux/TEST.sh All --timeout 1800`), pozostałe bramy po błędzie,
    końcowy przegląd diffu, ZMIANY/ODBIOR i commity po zielonej bramie.
    Jedna zmiana balansu na commit. Push wyłącznie na polecenie.

## Postęp

- Punkt wejściowy: czysty `7b09c94`, wersja 0.45. Zweryfikowano dziewięć
  stabilnych świadectw ostatniego All Furfura zgodnych z obecną grą:
  7858 Mechanics/Assets, Input 50, Architecture 701 Lua / 0 problemów,
  Render i Tools PASS. To wcześniejszy przebieg, nie nowe All tej analizy.
- Nowe testy: `elite-art` PASS 89, `boss-pressure` PASS 30, `souls-gate`
  PASS 6. Sondy: 117 wymuszonych prób ataków, 36 scenariuszy swobodnej SI,
  120 prób kontaktu, 24 lądowania, 90 prób skoku, 100 serii, 21 odtworzeń
  stanu w pamięci i osiem śmierci. Aktualne testy nie wykrywają wszystkich
  opisanych problemów; PASS nie oznacza, że lądowanie działa poprawnie.
- Lądowanie: 0 trafień w 24 próbach nieruchomego gracza. Seria: brak limitu
  w kodzie; 10 ze 100 prób przekroczyło trzy ciosy, najdłuższa osiem ciosów
  i 10,53 s do końcowego odpoczynku. Rozjazd ciała i cięcia do 32,66 stopnia.
- Solo 8–11 wypuszczeń w 20 s; z czterema Emberami 1–6. W grupie do
  3,58 s bezruchu w stanie ruchu. Główne postoje solo to przygotowanie,
  atak i odzyskiwanie równowagi, nie zatkanie SI.
- Skok rzeczywiście omija niską falę i fizyczne uderzenie przy poprawnym
  czasie. Bardzo wąskie okno omija oba pulsy bliskiego żaru. Trzy ogniska
  popiołu istnieją, ale centralna zapowiedź pod graczem daje 0 widocznych
  pikseli sceny w badanym ujęciu poziomej kamery.
- 150 kadrów czynności, porównanie 32 klatek z bazą (poprawiona wersja r2),
  trzy dystanse, 22 pary renderów widoczności i trzy izolowane znaki.
  Własnych głosów ciała i wariantów śmierci brak; 15 istniejących próbek
  wyeksportowano i zmierzono. Bez wiarygodnego odsłuchu.
- Mediany trzech p95 aktualizacji CPU: 1/4/12/32 Margrave'ów —
  0,2064/0,5236/0,9642/1,2105 ms. Bez audio i oczekiwania na GPU;
  najwyżej 4–6 pól, więc to nie maksymalne obciążenie efektami.
  Własny klon pomiarowy i jego robocze wyniki usunięto po zachowaniu dowodów.
- Dowody i źródła sond: zewnętrzne `work/qa-direct/margrave-*-20261106`.
  Bez zmiany kodu, PNG, WAV, balansu ani golden. Windows niesprawdzony.

## Decyzja i odbiór

Do przyjęcia powyższy pakiet; istotne decyzje to najwyżej trzy ciosy,
naprawa lądowania wraz z przerwą przed falą, pierwszeństwo w grupie oraz
pokazanie bliskiego ciosu jako uderzenia tasakiem w ziemię. Rekomenduję
całość bez dodawania nowego dużego czaru. Dokładne parametry wykonawcze
podlegają pomiarom w zatwierdzonym kierunku, nie nowym pytaniom o każdą liczbę.

## Pozostaje poza zakresem

- Odbiór Furfura w grze, barwy jego głosu oraz wcześniejszych głosów Embera,
  Stolasa, Iron Thralla i Gardenera przez właściciela.
- Wcześniej potwierdzony przypadek wspólnej nawigacji Furfura: ciało
  o promieniu 0,55 m otrzymuje punkty przy murze, których nie może zająć.
  Nie zmieniać tutaj wspólnych klas nawigacji ani promieni innych stworów.
- Dawne odłożone kierunki i odbiory zachowane w archiwach PLAN w HISTORII;
  analiza Margrave'a nie upoważnia do nowych broni, bossów ani map.
