# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-06: Furfur — analiza zakończona, plan DO AKCEPTACJI.**
Nie rozpoczęto wdrożenia. Właściciel zgłasza postoje i słabą widoczność
umiejętności. Sondy potwierdzają błędy kontaktu, wyboru dobitki, prezentacji
szarży, namierzania za ścianą i widoczności burzy. Zachować rolę elity,
2250 HP, obrażenia, nagrodę, dwa akty oraz okno pękniętej gardy 1,2 s.
Nie wzmacniać Margrave'a ani innych stworów. Chroniony HUD poza zakresem.
Poprzedni PLAN zachowano w całości w HISTORII; tam również pełna analiza,
inwentarz ataków, pomiary, źródła inspiracji i ograniczenia weryfikacji.

## Proponowany zakres do akceptacji

1. Naprawić działanie obecnego zestawu. Najpierw czerwone testy dobitki
   po szarży, geometrii reakcji na obejście, kierunku nawrotu i burzy
   namierzającej gracza za ścianą. Zachować obecne dowody przed zmianą.
2. Furfur jako ruchliwa, ciężka elita poroża i burzy. Spoczynek, obserwacja,
   podejście, hamowanie i odzyskanie równowagi mają mieć różne gesty.
   Nie usuwać uczciwych okien odpowiedzi i nie przyspieszać zegarów SI
   dla samego odczucia. Sprawdzić rzeczywiste blokady dużego ciała.
3. Rekomendowane uproszczenie szarży: jeden czytelny nawrót zamiast dwóch
   (maksymalnie dwa przebiegi zamiast trzech), widoczny obrót ciała podczas
   hamowania, kierunek zamrożony na czas każdego przebiegu, pełne 1,2 s
   odpowiedzi po zakończeniu. Dobitka dopiero po tym oknie, z nowym zamachem;
   naprawić jej dostępność i kontakt, bez niewidocznego powiększania trafień.
4. Rekomendowane zastąpienie wadliwego kopnięcia w tył: ograniczony prędkością
   zwrot i krótki cios porożem, z osobnym przygotowaniem. Zachować rolę
   reakcji na długie przebywanie z tyłu; obejście ma nadal dawać czas na
   strzał i odejście. Nie tworzyć natychmiastowego obrotu o 180 stopni.
5. Zachować serię poroża, mocny cios z góry, pojedynczy piorun, pięć uderzeń
   burzy po połowie HP i odskok z ponownym przywołaniem pioruna. Rozróżnić
   ich gesty, blokadę kierunku i końcówki. Nie uruchamiać dawnych ataków
   obszarowych przeznaczonych dla bossów i nie dodawać szóstego dużego czaru.
   Kolejne znaki burzy wymagają widoczności celu; już postawiony znak jest
   nieruchomy i kończy się zgodnie z zapowiedzią. Śmierć nadal je wygasza.
6. Ograniczyć zagładzanie Furfura przez drobnicę: wspólny, opcjonalny
   mechanizm pierwszeństwa po oczekiwaniu na wolne miejsce, włączony
   definicją Furfura. Bez podnoszenia limitów i przerywania rozpoczętych
   ataków innych stworów. To zmieni kolejność dopuszczania w grupie;
   sprawdzić kaplicę, cele, serie, utratę widoczności i zwalnianie rezerwacji.
7. Zachować zaakceptowane PNG ciała; najpierw złożyć czytelne sekwencje
   z istniejących 37 klatek. Powiązać krok/odgłos kopyt z rzeczywistą szarżą.
   Burza: widoczny z poziomej kamery sygnał przy porożu i w miejscu zagrożenia,
   przestrzenna zapowiedź ponad podłożem, oszczędny pionowy błysk o faktycznej
   wysokości, krótki niegroźny ślad po uderzeniu. Bez neonów, zasłaniania
   całego celu, dodatkowej szczegółowości i przemalowania ognia/ogona.
8. Własny chrapliwy, oddechowy głos potępionego jelenia: obecność, pościg,
   alarm, wysiłek różnych czynności, powrót, ból i trzy śmierci. Materiał
   poroża/kopyt i burzy osobno; warianty, pauzy, limity sali. Nie podmieniać
   wspólnych próbek Margrave'a. Techniczny miks i próbka do odsłuchu właściciela,
   ze źródłami/licencjami i przetwarzaniem. Pomiar nie potwierdza grozy barwy.
9. Trzy zapisane kontrole grafiki: każda zmieniona klatka/tekstura obok bazy
   w tej samej skali; bliski/średni/daleki render w jednakowym świetle;
   rzeczywiste przejścia stanów. Anatomia, maski, cień i punkty emisji.
   Generowanie tylko rzeczywiście brakującego elementu z bazą i Inferno,
   bez reinterpretacji postaci. Odbiór artystyczny nie wynika z sumy pliku.
10. Testy 60/120/240 Hz, kontr/skok/unik/chybienie, ściany/kolumny/wysokości,
    przerwanie/śmierć/przejście aktu, zapis/Continue/odpoczynek, grupy mieszane,
    warunki kanałów audio i osobny RNG. Powtórzyć pomiary w izolowanym klonie,
    także przy faktycznie nakładających się efektach i głosach. Golden według
    procedury: dwa identyczne przebiegi celowej zmiany symulacji, uzasadnienie;
    Windows bez zmiany wzorca na podstawie Linuxa.
11. Pełne `scripts/linux/TEST.sh All --timeout 1800`, pozostałe bramy po
    ewentualnym błędzie, końcowy diff, ZMIANY/ODBIOR, commit po zielonej
    weryfikacji. Jedna zmiana balansu na commit. Push wyłącznie na polecenie.

## Postęp analizy

- Stan wejściowy `162aa88`, wersja 0.45, czyste repo. Historyczne All PASS
  dla aktualnego fingerprintu: 7572 Mechanics/Assets, Input 50, Architecture,
  Render i Tools. W tym etapie nie powtarzano pełnego All.
- 81 izolowanych prób czynności, 36 poprawionych prób swobodnej SI,
  18 prób dwóch wadliwych kontaktów, 15 przywróceń stanu w pamięci,
  cztery próby śmierci podczas czarów, 100 kadrów czynności i dodatkowe
  pary renderów widoczności. `elite-art` PASS 89, `boss-pressure` PASS 29,
  `souls-gate` PASS 6. Istniejące testy nie wykrywają opisanych usterek.
- Dobitka: dostępność 1 s po szarży, wymuszony odpoczynek 1,2 s; nawet
  wymuszona mija ciało o 3 cm. Kopnięcie: 0 trafień w dziewięciu próbach.
  Nawrót: kierunek ruchu zmienia się o około 85 stopni przy starej orientacji
  ciała i tej samej klatce. Burza po schowaniu celu za ścianą stawia cztery
  nowe znaki i zabiera 200 HP; wynik zgodny w 60/120/240 Hz.
- Przy nieruchomym graczu Furfur samotnie wypuszcza 11–14 czynności/20 s;
  z czterema Impami 2–5. Bezruch w stanie ruchu dochodzi w grupie do 2,81 s
  ciągiem. Większość bezruchu samotnego Furfura to przygotowanie/atak,
  nie bezczynna SI. Jeden przypadek utraty celu przy przeszkodzie wymaga
  osobnej próby trasy, zanim uzna się go za błąd szukania drogi.
- W widoku poziomym z 7 m znaki i piorun pod graczem nie zmieniły ani
  jednego piksela badanego obszaru sceny; po cofnięciu były widoczne.
  Kontrola ze spojrzeniem w dół również potwierdziła obecność znaków.
  To problem projekcji i czytelności, nie tylko jasności materiału.
- Własnych głosów ciała brak. RMS ostrzeżenia burzy około 7,3 dB niższy
  od ostrzeżenia szarży; to pomiar próbek, nie dowód słyszalności pełnego miksu.
- Pomiar wejściowy w izolowanym klonie, mediany trzech przebiegów p95 CPU:
  1/4/12/32 Furfurów — 0,1596/0,2185/0,2980/0,5788 ms. Bez audio i GPU
  present; w scenariuszu najwyżej jeden znak naraz. Nie jest to FPS ani
  test maksymalnej burzy. Klon i jego wyniki robocze usunięto po zachowaniu
  dowodów w zewnętrznym `qa-direct/furfur-performance-before-20261106`.
- Dowody i źródła sond: zewnętrzne `work/qa-direct/furfur-*-20261106`.
  Szczegółowa interpretacja, odrzucone pomiary i ścieżki w HISTORII.

## Odbiór i ograniczenia

Do akceptacji cały powyższy kierunek, szczególnie skrócenie szarży do jednego
nawrotu, zastąpienie kopnięcia zwrotem z porożem i pierwszeństwo po oczekiwaniu
w grupie. Kod gry, grafika, dźwięk i golden nie zostały zmienione.
Windows niesprawdzony. Nie wykonano wiarygodnego odsłuchu ani pełnego miksu
na tym etapie. Pozostają osobne odbiory audio Embera i trzech poprzednich
postaci; zlecenie Furfura nie zmienia ich materiałów.
