# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-05: Ember Thrall — zaakceptowane wdrożenie zakończone i zweryfikowane na Linuxie.**
Zachować rolę najliczniejszego, lekkiego przeciwnika wręcz, 360 HP,
obrażenia i podstawowe czasy ataków. Dopracować gesty, odwrót, przejścia,
efekty i pełny głos ciała. Bez nowego czaru i reinterpretacji wyglądu.
Właściciel zaakceptował także naprawę wspólnego limitu atakujących podczas
kontynuacji serii. Nie stroić innych stworów; sprawdzić regresje ich walki.
Po wymaganej zielonej bramie commit bez ponownego pytania, bez push.
Poprzedni PLAN zachowano w całości w HISTORII, wraz z analizą Embera.

## Plan wykonania

1. Zachować dowody przed zmianą. Dodać czerwone testy limitu serii,
   mylącej prezentacji odskoku i brakujących ról audio.
2. Domknąć rezerwację miejsca przez serię, zachowując jej rytm oraz
   zwalnianie po przerwaniu, śmierci i utracie możliwości kontynuacji.
   Sprawdzić grupy, różnych odbiorców ataku i zapis w przerwie serii.
3. Rozróżnić gesty drugiego pazura, ciosu po skoku i odwrotu istniejącymi
   zaakceptowanymi klatkami. Dopasować powrót do chodu. Odwrót nie może
   pokazywać ani odtwarzać ostrzeżenia o ciosie. Nie zmieniać zegarów SI.
4. Sprawdzić kontakt pazurów, znak lądowania i fizyczne punkty efektów;
   stosować oszczędne, zaakceptowane malowane efekty. Zachować paletę,
   fakturę, twarz, anatomię, kontur i skalę detalu. Chroniony HUD poza zakresem.
5. Własny suchy, chrapliwy głos potępieńca: oddech, pościg, alarm,
   wysiłek, powrót, ból i trzy śmierci; oddzielnie materiał pazurów,
   wybicia, odwrotu i lądowania. Warianty, cisza i budżet tłumu; źródła,
   licencje i przetwarzanie zapisane przy nagraniach. Nie ruszać wspólnych
   próbek używanych przez inne postacie.
6. Sprawdzić zgodność masek, anatomii i cieni; wykonać trzy kontrole
   grafiki: klatki obok bazy w tej samej skali, rendery blisko/średnio/daleko
   w jednym świetle, rzeczywiste przejścia stanów. Audio sprawdzić
   technicznie i przygotować odsłuch właściciela; pomiar nie jest odsłuchem.
7. Próby 60/120/240 Hz, unik/skok/chybienie, ściany/kolumny/wysokości,
   przerwanie/śmierć, zapis/Continue/odpoczynek, grupy mieszane i koszty
   większej populacji. Testy osobno i razem. Golden: dwa identyczne przebiegi
   oraz uzasadnienie tylko świadomej zmiany symulacji; Windows bez aktualizacji.
8. Pełne `scripts/linux/TEST.sh All --timeout 1800`, dokończenie pozostałych
   bram po ewentualnym błędzie, przegląd diffu, ZMIANY/ODBIOR i commit.

## Postęp

- Stan wejściowy `304388d`, wersja 0.45, repo czyste. Historyczne All PASS:
  7328 Mechanics/Assets, Input 50, Architecture, Render i Tools; świadectwa
  odpowiadają obecnemu fingerprintowi głównego katalogu gry.
- Analiza: 90 prób czynności/reakcji, 18 prób grup, 94 kadry badawcze.
  Istniejące `attack-contact` PASS 30, `ability-art` PASS 85.
  Nowa sonda: 6/6 prób ośmiu Emberów osiąga czterech atakujących przy limicie 3.
  Odwrót używa gestu i odgłosu ciosu; brak własnych ról ciała i śmierci.
- Dowody w zewnętrznym `work/qa-direct/ember-*-20261105*`; punkt odniesienia
  czynności to `ember-analysis-20261105-r2` (pierwsza sonda miała niewłaściwe
  początkowe ustawienie kierunku). Własny klon pomiarowy usunięto.
- Pomiar wejściowy p95 aktualizacji CPU: 1/8/24/64 postacie —
  0,4006/0,9012/1,2644/2,2227 ms. Jedna seria, bez odtwarzania audio,
  bez GPU present; nie jest to FPS. Kod i zasoby wykonawcze zgodne z HEAD.
- Testy przed/po: `attack-slots` PASS 11, `ember-thrall` PASS 117,
  `creature-audio-mix` PASS 375. Zachowane czerwone próby rezerwacji,
  odwrotu, brakujących ról audio, kontaktu przez ścianę i nakładania sygnału.
  Pounce przez kamień: 34 → 0 HP; żywy wspólny cel w grupie ośmiu Emberów:
  4 → 3 atakujących, w grupie mieszanej 4–5 → 3. Pośmiertną końcówkę klatki
  raportuje osobny licznik; nie posłużyła do maskowania wyniku.
- Cztery PNG postaci, maski, anatomia, baza i użyty istniejący efekt pazurów
  są identyczne bajtowo. Trzy kontrole grafiki zapisane w ODBIOR: porównanie
  źródeł/bazy, 174 kadry blisko/średnio/daleko, rzeczywiste przejścia ataków
  oraz dodatkowe 36 kadrów trafienia i śmierci. Chroniony HUD bez zmian.
- 35 własnych próbek z wariantami; trzy śmierci, oddechy, konteksty ruchu,
  wysiłek i materiały. Końcowe 252 modele miksu z pełną muzyką i bronią
  bez przesterowania (szczyt 0,975). Odsłuch w `ember-audio-final-20261105`.
- Dwa identyczne golden i późniejszy PASS; zaktualizowany tylko Linux.
  Pełne All PASS: Architecture 695 Lua, Mechanics/Assets 7572, Input 50,
  Render i Tools. Dziewięć stabilnych świadectw, 701 s. Raporty zachowane
  w `ember-full-gate-20261105`; komplet wyników w bieżącym ODBIOR HISTORII.
- Powtórzony pomiar w izolowanym klonie (po trzy przebiegi): p95 CPU przy
  64 ciałach 1,7914 → 1,8778 ms, przy 24: 0,9782 → 1,1587 ms. Bez audio
  i GPU present; nie jest to pomiar FPS. Klon i jego katalog roboczy usunięto.
  Nie zmieniano plików gry podczas testów; końcowy diff przejrzany.

## Odbiór i ograniczenia

Odsłuch barwy, grozy i obecności Embera należy do właściciela. Środowisko
agenta nie udostępnia wiarygodnego odsłuchu. Windows poza zakresem.
Odbiór dźwięku trzech poprzednich postaci pozostaje osobnym otwartym punktem
z zakończonego planu; bieżące zlecenie nie zmienia ich próbek.
