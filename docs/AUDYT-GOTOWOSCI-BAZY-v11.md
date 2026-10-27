# SIGIL: BREACH — audyt gotowości bazy v11

Data: 27 października 2026. Audytowany kod: `7a4787c`, po poprawkach Claude'a z `a4dada8` i ich odbiorze. Zakres: gotowość architektury do rozwijania zawartości; bez przebudowy grafiki, HUD-u, balansu ani świata.

## Ocena

**Projekt ma solidną strukturę do stopniowego dodawania broni, demonów, ataków, efektów i map w obrębie obecnego modelu gry. Nie wymaga kolejnej masowej przebudowy architektury. Nie nazwałbym jednak obecnego stanu bezwarunkowo domkniętą bazą.**

W dodatkowych reprodukcjach znalazłem trzy konkretne luki: utratę wejścia drugiego aktora przy dzieleniu większego kroku czasu, niepełną walidację strategii AI oraz utratę sprawcy okresowego efektu demona. To poprawki lokalnych kontraktów. Nie unieważniają wykonanej pracy v10/v11, ale należy je zamknąć, zanim uznamy te kontrakty za wzorzec dla nowej zawartości.

Odrębnie pozostają odbiór płynności i feelingu oraz nierozstrzygnięte kryterium regresji wydajności z punktu 7 v11. Testy potwierdzają wiele własności kodu; nie potwierdzają, że strzelanie jest satysfakcjonujące. Nie ma też podstaw do deklaracji stałych 60 FPS.

**Rekomendacja:** trzy ograniczone naprawy z testami, domknięcie pomiaru i odbiór normalnej gry; następnie rozwój małymi, kompletnymi rozszerzeniami. Nie proponuję kolejnego wielkiego „fundamentu v12” ani przygotowania całego przyszłego świata przed dodaniem pierwszej nowej broni.

## 1. Co sprawdzono i co zostało już wykonane

Najpierw zakończono część naprawczą i zapisano ją w `7a4787c`. Dwie poprawki Claude'a były już w repozytorium. Sprawdzono je, uzupełniono pominięty wariant nieznanego sprawcy obrażeń (`nil`) i wykonano pełną weryfikację. Szczegóły: [odbiór poprawek](ODBIOR-POPRAWEK-v11.md).

Audyt obejmuje przekrój całego projektu: katalogi zawartości i schematy, tworzenie sesji, aktorów i trybów, kolejność symulacji, ruch i kolizje, trafienia i obrażenia, AI, efekty, prezentację, UI, zasoby, zapisy, dziennik, testy oraz narzędzia weryfikacji i pakowania. Prześledzono drogi od definicji do wykonania i zapisu, a nie tylko nazwy folderów. Nie jest to deklaracja ręcznego sprawdzenia każdej linii każdego pliku ani matematyczny dowód braku błędów.

Inwentaryzacja `game/src` obejmuje **306 modułów Lua**, w tym 78 w `content`, 40 w `render`, 29 w `ui`, 25 w `combat`, 25 w `session`, 20 w `enemies` oraz pozostałe warstwy. Duże pliki wygenerowanych masek i anatomii zawierają dane, dlatego ich długości nie należy traktować jak złożoności algorytmu. Kontrola kompilacji całego drzewa obejmuje 519 plików Lua.

Dowody na audytowanym drzewie:

| Kontrola | Wynik i granica wniosku |
|---|---|
| `TEST.ps1 -Suite All` | PASS: 4288 sprawdzeń mechaniki/zasobów, 36 wejścia; kompilacja 519 Lua; zero naruszeń sprawdzanych reguł architektury |
| Golden i stan 0.33 | Referencje i sześć skrótów golden bez zmiany; nie przeliczano wzorca pod nowy wynik |
| 606 renderów względem E0 | 601 identycznych; pozostałe pięć ma te same różnice numeru wersji co wcześniej |
| Zasoby, osiem cykli | Stabilne liczby uchwytów po zwolnieniu, brak utrzymanych właścicieli cykli; nie jest to gwarancja pamięci dla dowolnie większego katalogu |
| Trzy pełne benchmarki | Mediany i p95 zwykłego poligonu w budżecie 16,67 ms; część p99 i pojedynczych klatek poza nim |
| Dodatkowy proces audytu | Trzy nowe problemy odtworzone poza źródłami gry, także z prawdziwymi sesjami; opis poniżej |

Odcisk drzewa `game/` przed i po reprodukcjach:
`7BB72ED4B96C5A1C748624E067CD37FD1F42BF9D4FEB2AA62FA35B1AD1D0CCDE`.

Lokalne dowody znajdują się w `work/v11-review-20261027/`: `evidence.json`, `all/`, `pixels.json`, `budget-summary.json`, `resources/`, `inventory.json`, `probes/main.lua`, `probes/audit.stdout.txt` i `probes/audit.evidence.json`. `work/` jest ignorowane przez Git; ten dokument zawiera istotne wyniki, ale surowe artefakty nie będą automatycznie dostępne po samym sklonowaniu repozytorium. Kod wyjścia 0 reprodukcji oznacza, że potwierdziła ona opisane błędy, a nie że zachowanie gry było prawidłowe.

## 2. Potwierdzone luki wymagające zamknięcia

### A. P2 — efekt okresowy demona traci tożsamość sprawcy

Miejsce: [session/damage_outcomes.lua](../game/src/session/damage_outcomes.lua), wiersze 53–54 i wywołanie w `creatureBlow`; [combat/effects.lua](../game/src/combat/effects.lua), `sourceOf`, `aliveSource` i wykonawca `periodic`.

`creatureBlow` przekazuje do `Outcomes.enemy` liczbowy identyfikator demona jako `owner`, ale etykietę `'creature'` jako `source`. Przy nakładaniu efektu kod zachowuje jawnego właściciela tylko wtedy, gdy jest on napisem, czyli identyfikatorem rycerza. Dla demona przekazuje dalej etykietę. `Effects.sourceOf` interpretuje taką wartość jako `knight`, bez identyfikatora.

**Reprodukcja:** dwa rycerze, demon-sprawca i demon-cel; cel ma 500 HP. Kontakt przez rzeczywiste `Game:damageBody` zawiera efekt `periodic`, 0,6 s długości, puls co 0,2 s, 6 obrażeń, `cancelOnSourceDeath=true`. Zapisana instancja ma `sourceSide='knight'`, `sourceId=nil`, mimo że sprawca ma ID 4. Po ustawieniu HP sprawcy na zero i przesunięciu czasu o 0,21 s cel traci kolejne 6 HP, a efekt nadal istnieje.

**Znaczenie:** nowy demon z podpaleniem lub podobną umiejętnością nie zachowuje poprawnie kontraktu źródła. Anulowanie sprawdza niewłaściwe ciało. Puls traci również identyfikator pierwotnego demona. Nie twierdzę, że każda obecna animacja czaru jest dotknięta tym problemem: reprodukcja wykorzystuje obsługiwany efekt okresowy, a nie sam wygląd pocisku.

**Poprawka:** przenosić tożsamość źródła niezależnie od etykiety zdarzenia. Nie odgadywać rycerza z samego braku tabeli. Zachować istniejącą regułę statystyk dla świata i jednego rycerza; `nil` nie może samoczynnie nabierać znaczenia innego sprawcy.

**Warunek odbioru:** demon → demon, demon → rycerz, drugi rycerz → demon, nieznane źródło; osobno anulowanie po śmierci i efekt, który ma przetrwać sprawcę. Sprawdzić `owner` pulsu/zabójstwa, snapshot i dziennik oraz brak rekursywnego nakładania efektu przez jego własny puls.

### B. P2 — większy krok symulacji odrzuca wejście dodatkowych aktorów

Miejsce: [session/simulation.lua](../game/src/session/simulation.lua), wiersze 35–57.

`Simulation.update` dzieli czas na kroki do 1/120 s. Po pierwszym kroku z `dash` lub `slide` buduje nową, ręcznie wyliczoną tabelę wejścia. Nie przenosi `input.actors`, więc dalsze kroki nie dostają poleceń pozostałych rycerzy.

**Reprodukcja:** `update(1/30, {dash=true, actors={audit_second={forward=1}}})` wykonuje cztery podkroki. Pierwszy zawiera `actors`, pozostałe trzy już nie. W rzeczywistej pustej sesji drugi rycerz przebywa **0,004319106 m**, a przy czterech równoważnych wywołaniach po 1/120 s — **0,037777778 m**. Przycisk uniku pierwszego rycerza jest w obu wariantach aktywny tylko na początku.

**Granica:** aplikacja obecnie podaje stałe 1/120 s, więc ten wynik nie dowodzi utraty ruchu w zwykłej rozgrywce jednoosobowej. Dotyczy publicznej ścieżki `Game:update` użytej przez narzędzie, test, bota lub przyszły inny kontroler z większym krokiem. Komentarz tej funkcji obiecuje obsługę takich wywołań.

**Poprawka:** zachować pełną strukturę wejścia przy podziale czasu; wygaszać wyłącznie komendy jednorazowe zgodnie z ich kontraktem. Nie mutować tabeli dostarczonej przez wywołującego. Regułę rozpatrzyć także dla wejścia poszczególnych aktorów, zamiast dopisywać kolejną ręczną listę pól.

**Warunek odbioru:** równoważne 1/30 i cztery razy 1/120 dla ruchu dwóch rycerzy, z unikiem/ślizgiem i bez nich; bez powtarzania akcji jednorazowych. Sprawdzić odtworzenie i zachowanie oryginalnej tabeli wejścia.

### C. P2 — błędne nazwy zachowań AI przechodzą walidację zawartości

Miejsce: [session/content_contracts.lua](../game/src/session/content_contracts.lua), `Contracts.creature`; [enemies/ai.lua](../game/src/enemies/ai.lua), wiersz 321; [enemies/target.lua](../game/src/enemies/target.lua), wiersze 30–37.

Definicja demona sprawdza typ pól `move.style` i `move.targeting`, ale kontrakt połączenia danych z wykonawcami weryfikuje przede wszystkim ataki i efekty. Nie sprawdza istnienia obu strategii. Nieznany styl ruchu cicho zamienia się w `Styles.keep`; nieznana strategia celu wywołuje błąd dopiero przy wyborze celu.

**Reprodukcja:** wariant `imp` z `move.style='misspelled_style'`, `move.targeting='misspelled_target'`. `Creature.define`, `Contracts.creature`, utworzenie sesji i spawn przechodzą. Dopiero `Target.choose` kończy się `unknown targeting strategy misspelled_target`.

**Znaczenie:** dodawanie treści jest możliwe bez przebudowy AI, lecz literówka może zmienić zachowanie po cichu lub przerwać walkę. To bezpośrednio wpływa na wygodę i bezpieczeństwo dalszego rozwoju.

**Poprawka:** walidować istnienie i wywoływalność zarejestrowanych strategii na granicy kompozycji. W razie cyklu zależności wydzielić niewielki rejestr zachowań, zamiast importować symulację do definicji zawartości. Odróżnić jawny domyślny styl od nieprawidłowej podanej nazwy.

**Warunek odbioru:** błędna nazwa zostaje odrzucona przed rozpoczęciem świata; poprawny własny styl i selektor celu przechodzą. Wbudowane demony zachowują dotychczasowe wyniki i animacje.

## 3. Dlaczego obecna architektura jest dobrym fundamentem

To nie jest już porządek polegający tylko na przeniesieniu plików do folderów. Istnieją użyteczne, sprawdzane granice odpowiedzialności:

- **Definicja i instancja są rozdzielone.** Zawartość opisuje parametry i rodzaje zachowań, a aktor przechowuje własną broń, amunicję, czasy i wyposażenie. Testy wykrywają mutowanie współdzielonych definicji.
- **Mechanika i prezentacja mają osobny stan.** Zdarzenia symulacji uruchamiają feedback; widok nie jest właścicielem HP czy amunicji. Kontekst aktora i obserwatora usuwa dużą część dawnych założeń o jednym `player`.
- **Kolejność działania jest jawna.** `systems/index.lua` wyznacza porządek ruchu, kontaktów, ataków, pocisków, efektów i postępu trybu. Symulacja i dekoracja mają rozdzielone strumienie losowości.
- **Wspólne operacje mają jeden przebieg.** Definicja broni wybiera dostawę; kontakt prowadzi do wspólnego rozliczenia materiału, strefy, obrażeń i skutków. Nowa broń nie musi implementować własnego systemu nagród czy śmierci.
- **Istnieją dowody rozszerzalności.** Testy naprawdę wstawiają trzecią/czwartą broń, zmienioną anatomię, nowe pozy, tryb z celami, drugiego aktora i dodatkowy widok. Nie są to wyłącznie komentarze „tu kiedyś będzie można”.
- **Weryfikacja dotyczy określonych źródeł.** Golden, zapis źródła wyników, fixture starszego wydania, rendery i izolowane procesy utrudniają przypadkowe uznanie starego raportu za dowód nowej wersji.

Uproszczony przepływ odpowiedzialności:

```mermaid
flowchart TD
  Data[Definicje broni, demonów, map i działań] --> Schema[Schematy i kontrakty zawartości]
  Schema --> Session[Sesja, aktorzy, pule i stan trybu]
  Input[Wejście i polecenia z ID aktora] --> Step[Uporządkowany krok symulacji]
  Session --> Step
  Step --> Contact[Ruch, AI, dostawa i kontakt]
  Contact --> Outcome[Obrażenia i skutki]
  Outcome --> Sim[Statystyki, nagrody i postęp]
  Outcome --> Present[Zdarzenia prezentacji]
  Present --> View[Kontekst widoku, animacja, HUD i dźwięk]
  Session --> Storage[Snapshot, dziennik i wersjonowany zapis]
  View --> Observation[Jawna obserwacja pokazanej pozy]
  Observation --> Shot[Komenda strzału]
  Shot --> Contact
```

Ostatnie połączenie jest celowe: hitscan ma badać pokazaną pozycję demona według jawnego kontraktu. Nie oznacza to uzależnienia całej fizyki od bieżącej kamery ani wykonywania odczytu GPU przy każdym trafieniu.

Kompozycja danych i małych strategii lepiej odpowiada temu projektowi niż rozbudowana hierarchia klas typu `Demon → LatającyDemon → OgnistyLatającyDemon`. Dziedziczenie definicji służy tworzeniu wariantów; wykonawcy służą dodawaniu zachowania. Nie trzeba zmieniać silnika ani wprowadzać nowego frameworka ECS.

## 4. Ile realnie wymaga dodanie nowej zawartości

| Zmiana | Miejsca pracy | Czego nie trzeba przebudowywać | Granica |
|---|---|---|---|
| Kolejna zwykła broń palna | `content/weapons`, definicja, teksty, atlas dłoni i animacje, sposób zdobycia | Ruchu postaci, wspólnego kontaktu, całego HUD-u i statystyk | Istniejące rodzaje dostawy i stan amunicji |
| Broń z nową dostawą | Rejestr `combat/weapon_delivery`, wykonawca i jego dane; grafika/feedback | Każdego przeciwnika i każdej funkcji strzału | Nowa fizyka dostawy wymaga kodu, nie tylko ID |
| Inny typ przeładowania | Mechanizm w `combat/reload`, metadane i sekwencja ręki | Logiki gracza i wszystkich innych broni | Nowe utrwalane pola broni trzeba dodać do kontraktu stanu/zapisu |
| Nowy demon z obecnymi zachowaniami | `content/creatures`, rejestracja w katalogu, wygląd, pozy, anatomia i bake maski | Ogólnego spawn, kontaktu i rozliczenia śmierci | Po poprawce C błędne strategie mają być odrzucane wcześnie |
| Nowy atak demona | Schemat działania, wykonawca `Attacks.kinds`, telegraph, kontakt i animacja | Całego AI każdego demona | Nowa wielofazowa polityka bossa wymaga własnej logiki faz |
| Nowy efekt kontaktu | Definicja `effect`, wykonawca apply/tick i feedback | Każdej broni, która go nakłada | Naprawić A; opisać stacking, anulowanie i sprawcę |
| Umiejętność/wyposażenie | Definicja w `content/abilities`, ewentualnie wykonawca `combat/abilities`, slot i art | Całej klasy postaci | Obsługa techniczna nie zmienia założenia „człowiek bez magii” |
| Inny układ mapy | Dane mapy i rejestr `content/maps/index` | Algorytmów ruchu, UI i każdego potwora | W obrębie obecnej siatki, wysokości i pokładów |
| Obiekt świata | Dane/stan i interakcja; `WorldObjects.register` do rysowania | Głównej pętli renderera | Sama rejestracja grafiki nie dodaje kolizji ani zapisu |
| Nowy tryb z celami | Rejestr `run/modes`, `modeData`, widoki zapytań i sekcja zapisu | Każdego ekranu i algorytmu walki | Kontrakt trybu obejmuje też reset, koniec i odtworzenie |

Główne źródła: [weapon_extension](../game/tests/cases/weapon_extension.lua), [hand_art_extension](../game/tests/cases/hand_art_extension.lua), [creature_extension](../game/tests/cases/creature_extension.lua), [content_contracts](../game/src/session/content_contracts.lua), [world_objects](../game/src/render/world_objects.lua) i [ROZSZERZANIE](../game/docs/ROZSZERZANIE.txt).

Przykład ważnego rozróżnienia: broń strzelająca skończonymi pociskami ognia może wykorzystać dostawę `projectile`, typ obrażeń `fire` oraz zdefiniowany efekt okresowy. Samo `damageType='fire'` nie tworzy płomienia, podpalenia ani animacji. Ciągły miotacz ognia potrzebuje wykonawcy emisji, reguły zużycia paliwa, kontaktu i prezentacji. To lokalne rozwinięcie istniejącego podziału, nie przepisanie przeciwników.

## 5. Matematyka, trafienia i animacje

**Obrażenia:** [combat/damage.lua](../game/src/combat/damage.lua) skupia czyste obliczenia: dystans, moc, strefę, pancerz, penetrację, odporność, osobno obrażenia HP, naruszenie gardy i impuls. Pancerz demona jest współczynnikiem, a ochrona rycerza zużywalną pulą. To jawnie różne modele, nie przypadkowo wymieszane zmienne. Współczynniki są regułami gry, nie deklaracją realistycznych dżuli.

**Ruch:** zamknięte wzory integracji w `physics/kinematics`, kontakt mas w `body_physics`, przesunięcia z kolizją w `collision`, lot w `ordnance_flight` i przecięcia w `sphere_cast` stanowią sensowny podział. Testy `terrain_motion` sprawdzają m.in. podparcie, lądowanie, przeszkody i zachowanie precyzji tuż nad podłożem. To silniejszy fundament niż regulowanie każdego ruchu osobnym losowym mnożnikiem. Nowy rodzaj fizycznego oddziaływania nadal wymaga określenia jednostek, czasu i kolejności zastosowania.

**Anatomia:** kształt ma identyfikator niezależny od strefy obrażeń i materiału. Dwie kończyny mogą należeć do tej samej strefy. Testy wariantów anatomii potwierdzają rozdzielenie liczby kształtów od logiki obrażeń. Aktualne demony są trafiane przez opisaną, malowaną powierzchnię z maską, a nie jeden prostokąt.

**Rogi:** obecny materiał `horn` ma zerowy udział w obrażeniach HP i własną reakcję kontaktu; nie implementuje fizycznego odbicia trajektorii. Rykoszet to osobny przyszły kontrakt dostawy: normalna, kierunek po odbiciu, pozostała energia i ograniczenie liczby odbić. Nie należy twierdzić, że jest gotowy tylko dlatego, że istnieje materiał o tej nazwie.

**Pozy i trafienie:** nazwane pozy, kotwice i metadane CPU oddzielają rozmieszczenie grafiki od kolejności brył. `combat/observation` przenosi obserwowaną geometrię wraz z aktorem, czasem i ważnością; pociski lecące używają kontaktu w bieżącej symulacji. Dzięki temu dopisanie klatek nie powinno automatycznie przesuwać ręki, głowy czy kontaktu ataku. Własny arkusz nadal trzeba poprawnie oznaczyć i sprawdzić na granicach klatek.

**Świadoma granica:** demon pozostaje billboardem. Jawny obserwator nie czyni płaskiego malowidła modelem 3D. Opcjonalny katalog `hit_volumes` istnieje, ale w grze jest pusty. Pełna, niezależna od obserwatora objętość wszystkich potworów nie została wykonana i nie jest potrzebna do zwykłego dodania kolejnego malowanego demona.

**Feeling:** `feedback/weapon_motion` reaguje na ruch, zmianę kierunku, chód, lot i lądowanie, korzystając ze sprężyn. Architektura pozwala dostrajać te reakcje bez zmiany obrażeń. Sam fakt istnienia tych wzorów nie potwierdza dobrego odczucia ciężaru. Odbiór powinien objąć obie bronie, trafienie/chybienie, przerwanie ataku, śmierć, skok, lądowanie, ślizg i powrót z przeładowania, w zwykłej walce.

## 6. Mapy, skala i koszty

Mapa nie jest już na stałe kwadratem dawnej areny. Schemat przechowuje szerokość i głębokość; test `space_scale` sprawdza także nawigację na 256×256. `floor_layers` obejmuje mapę 256×128 z mostem, ruchem nad i pod nim, pociskami oraz oświetleniem. Oznacza to działanie konkretnych algorytmów na takich danych, nie obietnicę pełnej gry w 60 FPS z dowolną liczbą obiektów.

`world/arena` aktualizuje rewizję geometrii; renderer i nawigacja uwzględniają ją przy odświeżaniu danych. Przyszła modyfikacja mapy powinna korzystać z tej ścieżki, a nie zmieniać wyłącznie tabeli widocznych kafli. Lokalne pola nawigacji, cache i indeks przestrzenny ograniczają koszt. Dowolne ruchome platformy, strumieniowany otwarty świat czy pełne geometryczne wnętrza 3D byłyby nowymi funkcjami.

**Obecny pomiar płynności:** w cięższych zwykłych scenach 20 przeciwników najgorsze p95 z trzech prób wyniosło 16,4294 ms, a p99 19,7328 ms. Pojedynczy pomiar klatki doszedł do 43,9320 ms. Sceny diagnostyczne 96/256 ciał są wyraźnie droższe. Pomiar nie obejmuje desktopowego present/vsync, więc nie jest pomiarem opóźnienia całego toru do monitora. Szczegóły i warunki są w raporcie odbioru.

Kryterium Claude'a „+5% **lub** w granicach szumu A/A” nie daje dwóch jednoczesnych ograniczeń. Duży szum nadal może przepuścić regresję. Dlatego historyczny wynik względny pozostaje nierozstrzygnięty; nowa seria absolutna nie zastępuje pomiaru par przed/po. Nie zamknięto punktu 7 samą zmianą opisu progu.

**Start i katalog:** zmierzone pierwsze wejście na poligon trwało 888,590 ms rozłożone na 17 wyświetlonych zadań, największy dostawca 57,367 ms; pierwsza grająca klatka poligonu 7,996 ms, bez leniwego ładowania PNG. Podział poprawia możliwość pokazania ładowania, lecz nie oznacza, że każde zadanie mieści się w jednej klatce 60 Hz.

`render/weapon.loadAtlases` i `render/ability_art.load` przechodzą przez zarejestrowane katalogi. Osiem cykli potwierdza zwalnianie obecnych zasobów; nie dowodzi stałego kosztu przy stu unikalnych arkuszach. Gdy katalog realnie urośnie, należy wybierać zestaw potrzebny sesji/poziomowi i mierzyć VRAM oraz czasy wejścia. Nie trzeba dziś budować pełnego streamingu dla dwóch broni.

## 7. Zapis, odtworzenie, UI i utrzymywalność

**Zapis to kilka różnych kontraktów.** Snapshot bieżącej sesji, dziennik poleceń, zapis sekcji sesji i checkpoint wyprawy nie są tym samym. `Save.declare` pozwala deklarować sekcje u właścicieli; walidacja poprzedza przywrócenie. Dziennik ma kontrolę wersji i źródeł; obsługa starszego formatu nie oznacza replaya dowolnego wydania.

Przykład istotny dla przyszłych broni: checkpoint `run_save` zachowuje z ekwipunku przede wszystkim ID, kolejność oraz `mag` i `reserve`. Nie zapisze automatycznie nowej temperatury, zużycia, ulepszenia czy specjalnego ładunku, tylko dlatego że dopisano pole do tabeli broni. Wprowadzenie takiego stanu wymaga decyzji, czy przetrwa zapis, śmierć i reset, oraz stosownej sekcji/migracji. To oczekiwana lokalna praca przy nowej funkcji, a nie wada wymagająca obecnie generalnego przepisywania zapisu.

**Pola zmieniane poza poleceniem** muszą trafiać do dziennika. Naprawa `actorSet` jest właśnie przykładem tego wymagania. Nowy kontroler powinien przejść rzeczywisty cykl wejście → polecenie → zapis/odczyt → porównanie stanu, nie tylko test wywołania pojedynczej funkcji.

**UI obsługuje więcej niż dwie bronie, ale ma granice.** Testy trzeciego/czwartego slotu przechodzą. Checkpoint ma limit dziewięciu broni, a obecne powiązania wejścia i widoczny układ mają własną pojemność. To nie jest gotowy dowolnie duży ekwipunek ani automatyczny layout. UI operuje na projektowej przestrzeni 1280×720; nowe długie nazwy, glify, liczby i języki wymagają sprawdzenia faktycznego rysunku. Nie jest to zalecenie zmiany zaakceptowanego HUD-u.

**Własność zasobów jest wyraźniejsza.** Rejestr zasobów rozróżnia warianty obrazów i ich właścicieli; renderer ma ścieżkę zwalniania. Dźwięki mają katalog receptur i ponowne użycie głosów. Nowy efekt powinien korzystać z tych właścicieli, zamiast zakładać wieczny globalny obraz lub tworzyć źródło dźwięku na każdy pellet.

**Nie wszystkie katalogi mają identyczne API.** Część korzysta z `Registry`, część udostępnia zwykłe tablice strategii, a stworzenia mają listę ID i wpisy katalogu. Nie uniemożliwia to rozwoju. Nie należy jednak opisywać obecnego stanu jako jednolitego systemu pluginów z identyczną walidacją wszędzie. Poprawka C powinna uszczelnić konkretną granicę; stopniowe ujednolicenie rejestracji można robić przy realnej potrzebie.

**Duży plik nie zawsze jest problemem.** Wygenerowanych masek nie należy ręcznie „upraszczać”. Większe moduły AI, dziennika, zapisu i renderera mają rozpoznawalne odpowiedzialności. Dalszy podział ma sens wtedy, gdy nowe zachowanie zaczyna mnożyć warunki po ID broni/demona lub mieszać wykonawcę z zapisem i prezentacją. Sam limit liczby linii nie jest dobrym powodem refaktoru.

**Narzędzia pomagają zachować kontrolę.** Kompilacja, kontrola architektury, izolowanie QA i odciski pakietów są przydatną częścią bazy. W tym zadaniu nie tworzono nowej paczki BUILD i nie publikowano wydania. Przegląd skryptów pakowania nie jest równoznaczny z przetestowaniem świeżego instalatora.

## 8. Zalecany warunek zamknięcia i następny krok

Przed nazwaniem bazy domkniętą:

1. Naprawić A — źródło efektu okresowego — i dodać testy właściciela, śmierci źródła oraz odtworzenia.
2. Naprawić B — wejście w podkrokach — i udowodnić równoważny ruch dwóch aktorów bez wielokrotnego wykonania przycisków jednorazowych.
3. Naprawić C — walidację strategii AI — bez zmiany zachowania istniejących demonów.
4. Wykonać pełne All na końcowych, stabilnych źródłach. Zachować referencje i nie poprawiać golden po to, żeby ukryć zmianę mechaniki. Rendery/HUD mają pozostać zgodne.
5. Domknąć punkt 7 uczciwym wynikiem par przed/po lub jawną decyzją o udokumentowanym odstępstwie. Równolegle ocenić kwantyle i zacięcia zwykłej gry; nie redukować płynności do mediany.
6. Przeprowadzić B2 na obecnym poligonie. Oddzielić konkretne uwagi gracza o strzelaniu, ruchu i czytelności od wyników automatycznych.

Po tym proponuję **jeden mały pionowy etap zawartości**, a nie od razu dziewięć kręgów: jedna broń lub jeden demon obejmujący definicję, animację, kontakt, feedback, zapis i test. To praktyczne potwierdzenie, że autor nie musi dopisywać wyjątków w kilkunastu rdzeniowych modułach. Jeśli musi — poprawić ten punkt rozszerzenia na podstawie konkretnego przypadku.

Każde rozszerzenie powinno odpowiedzieć na sześć pytań:

- Kto jest właścicielem stanu i gdzie go resetuje?
- Który istniejący wykonawca działań obsługuje zachowanie, a co jest naprawdę nowe?
- Jak przebiegają kontakt, obrażenia, sprawca i anulowanie?
- Co zapisujemy i jak odtwarzamy ten stan?
- Kto ładuje/zwalnia art i jak sprawdzamy zgodność animacji z trafieniem?
- Który test wykaże błąd i jaki jest koszt przy planowanej liczbie instancji?

Nie wymaga to produkcyjnego split-screenu, sieci, pełnego 3D ani dowolnego systemu modów. Te cechy nie są warunkiem dobrej bazy obecnego FPS-a.

## 9. Odpowiedź na główne pytanie

**Tak: obecna konstrukcja pozwala dodawać typową broń, demona, atak lub układ mapy bez masowego przepisywania kodu. Nie: nie daje jeszcze podstaw do bezwarunkowego stwierdzenia, że wszystkie fundamenty są zamknięte i dalsze rozszerzenia nie ujawnią żadnych luk.**

Najważniejsze zmiany architektoniczne są już wykonane. Pozostałe potwierdzone problemy mają mały, określony zakres. Po ich naprawie i uczciwym odbiorze wydajności/feelingu rozsądniej będzie rozwijać zawartość na istniejących kontraktach niż ponownie projektować całą bazę od początku.

W trakcie tej drugiej, audytowej części zadania nie zmieniono plików gry. Nie zmieniono także `docs/podrecznik-codex/`, grafiki, HUD-u ani zawartości menu.
