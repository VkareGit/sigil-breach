# SIGIL: BREACH — plan rozwoju

## Zakres i status

**2026-11-06: ponowny przegląd całego audio sześciu postaci — analiza
zakończona, plan czeka na akceptację właściciela. Wdrożenie nierozpoczęte.**
Zakres: Ember Thrall, Iron Thrall, Star Acolyte/Stolas, Plague Gardener/Buer,
Furfur i Margrave of Ash; głos ciała, ruch i uniki, przygotowanie,
wypuszczenie, przebieg i zakończenie ataków, trafienia, przerwanie i śmierć.
Cel: rozpoznawalne, niepokojące postacie oraz czytelne zagrożenia w walce.
Właściciel dopuszcza zmianę wszystkich tych odgłosów; najpierw wymaga planu.
Szczegółowa analiza i źródła: HISTORIA, „Analiza audio sześciu postaci
(2026-11-06)”. Poprzedni PLAN Margrave'a zachowany tam w całości.

## Proponowany kierunek

Wspólny świat: ciało potępieńca, oddech, kamień, żelazo, popiół,
zepsucie i obrzęd. Dziewięć kręgów piekła jako kierunek świata, bez
samodzielnego przypisywania obecnym stworom konkretnych kręgów.
Głos ciała i materiał ataku mają odmienne role. Krótkie ostrzeżenie musi
przekazywać czynność; dłuższy niepokojący odgłos może rozwijać jej charakter.
Nie każdy atak potrzebuje krzyku ani każda chwila obecności — pomruku.
Przetwarzanie ma zachować słyszalnego człowieka lub zwierzę pod deformacją.
Bez słownych kwestii, współczesnej mechaniki, ciągłego basu i ostrych pisków.

| Postać | Proponowany charakter i najważniejsze czynności |
| --- | --- |
| Ember Thrall | Krótki, urywany oddech wyniszczonego napastnika; wysiłek pazurów, skoku, odskoku i lądowania. Najczęstszy przeciwnik: oszczędna obecność, krótkie zakończenia i różne wykonania, żeby grupa nie zamieniała się w stały wrzask. |
| Iron Thrall | Ludzki głos uwięziony w pancerzu, napięcie płyt i łańcucha, ciężki kontakt z posadzką. Rozróżnić zamach, szarżę barkiem, cios powrotny, uderzenie w ziemię i zatrzymanie na murze; materiał nie może być tylko ogólnym szumem. |
| Stolas | Ptasio-ludzki celebrans; głos rzucającego oddzielony od głosów ofiar. Piekielna fala: narastający zbiorowy wdech i krzyk niesiony przez grzbiet. Rozdarcie: krótki chór rozerwany w rytmie otwarcia ziemi. Pociski, salwa i teleport zachowują odrębne sygnały; krzyki nie wypełniają każdego czaru. |
| Plague Gardener | Duszenie się, odruch wymiotny, napięcie brzucha i mokre rozpady; przygotowanie strumienia z ust odmienne od wysiewu i rozkwitu. Osobno kontakt wydzieliny, pękanie nasion i wyrywanie korzeni. Unikać komicznego bulgotu oraz jednego pomruku dla wszystkich czynności. |
| Furfur | Zniekształcony zwierzęcy głos, klatka piersiowa i poroże; kopyta, nabranie powietrza, szarża, nawrót i hamowanie. Burza ma głos przywołania, napięcie przed uderzeniem oraz grzmot z rzeczywistego miejsca kontaktu. Zwierzęcy charakter odróżnia go od Margrave'a. |
| Margrave | Zdarty ludzki głos kata: wysiłek przy ciężarze, wstrzymany oddech podczas przytrzymania i urwany wydech przy ciosie. Tasak, skok, kamień i żar mają własne materiały. Zimne cięcie i płonący ślad różnią się także dźwiękiem; nie kopiować chóru Stolasa. |

Śmierć również identyfikuje ciało: urwany skowyt i wydech Embera;
załamujący się ludzki głos i osiadanie pancerza Iron Thralla; utrata
ptasio-ludzkiego głosu Stolasa; zdławiony ostatni wydech Gardenera;
gasnący zwierzęcy ryk Furfura; zdarty wydech kata i ciężar upadającego
Margrave'a. Kontakt ciała/wyposażenia z ziemią ma przypadać na rzeczywisty
upadek, nie na początek całej animacji. Kilka wykonań każdej śmierci;
długie ogony ograniczane w tłumie, bez zasłaniania żywych zagrożeń.

## Proponowana kolejność wdrożenia po akceptacji

1. **Dowody wejściowe i testy regresji.** Uzupełnić zachowany inwentarz
   rzeczywistymi śladami zdarzeń każdej czynności, także odskoku, przerwania,
   zderzenia i śmierci. Utrwalić czerwone testy: położenie długiego głosu
   po obrocie/ruchu gracza, ściana dla alarmu/uniku/zderzenia, dwie różne
   aktywacje pola w tej samej chwili, przelot/trafienie przypisane do ataku.
   Sprawdzić koniec próbek w rzeczywistym oknie przygotowania i przytrzymania.
   Przed zmianą wykonać powtarzalne miksy walki oraz pomiar CPU/liczby źródeł.
2. **Spójne wyzwalanie i przestrzeń.** Rozszerzyć istniejące profile treści
   o potrzebne role ruchu oraz ataku, wykorzystując wspólne zdarzenia.
   Żadnych warunków po nazwie konkretnego moba. Głos ciała pochodzi z ciała,
   przelot z pocisku, a krzyk pola z pola. Długie głosy aktualizują położenie
   i tłumienie przy ruchu słuchacza/emisji. Ściany działają spójnie również
   dla alarmu, uniku i zderzenia. Ograniczony, mierzony koszt aktualizacji;
   to nie budowa nowego pełnego silnika propagacji akustycznej.
3. **Etapy i zakończenia.** Przygotowanie, wypuszczenie, groźny przebieg,
   kontakt i wygaszenie wynikają z rzeczywistej fazy czynności. Nie wycinać
   próbki na przypadkowej amplitudzie, ale też nie pozostawiać ostrzeżenia
   po przerwaniu. Kontrolowane krótkie wygaszenie nie przedłuża zagrożenia.
   Wiele znaków jednego rytuału może tworzyć jeden odgłos; osobne rytuały
   nie wyciszają się wzajemnie przez wspólny typ obrażeń. Już wypuszczony
   efekt zachowuje własne reguły życia po śmierci rzucającego.
4. **Brzmienie sześciu postaci.** Dobór/przeróbka nagranych wykonań i
   materiałów zgodnie z tabelą. Najpierw Stolas jako próbka kierunku,
   potem pozostała piątka w ramach tego samego zaakceptowanego zakresu.
   Warianty często powtarzanych odgłosów, co najmniej trzy śmierci, różne
   wysiłki zależne od czynności, oszczędna obecność i odzyskiwanie oddechu.
   Zachować dobre obecne wykonania; nie podmieniać banku dla samej wymiany.
   Krzyki potępionych oprzeć na odegranych ludzkich głosach i kontrolowanym
   nawarstwieniu, z czytelnym początkiem, bez ostrego ciągłego tonu.
   Źródła, licencje i przetwarzanie zapisać przy zasobach; bez audio z gier.
5. **Miks walki.** Strojenie w typowym zasięgu każdego ataku, dodatkowo
   przy 2/6/10/16 m, za kolumną, murem i poza ekranem. Priorytet bieżącego
   zagrożenia przed ozdobnym oddechem i dalekim echem. Zachować rozpoznawalność
   strzałów Judge'a/Exorcista. Najpierw barwa, rytm, tłumienie i ograniczenie
   nakładania; dopiero potem korekta głośności. W razie potrzeby krótkie,
   łagodne ściszanie mniej ważnych warstw, bez pompowania całego miksu.
   Zachować cztery suwaki oraz ograniczone pule źródeł; nie zwiększać
   limitu 28 tylko dlatego, że pojawiły się nowe warstwy. Osobno sprawdzić
   rywalizację o źródła przy równym priorytecie i przeciążenie.
6. **Kontrola całości.** Solo, wszystkie sześć razem, zwykła kaplica oraz
   większa grupa z nakładającymi się efektami; obie bronie, wszystkie
   istniejące zestawy ich dźwięku i muzyka. Pomiar poziomów, krótkich okien,
   szczytów, maskowania pasm i przerw/końcówek; osobny odsłuch w słuchawkach
   i głośnikach. Testy 60/120/240 Hz, wariantów, braku powtórzeń, mute,
   pauzy, mapy, śmierci, odpoczynku i zmiany świata. Continue we wszystkich
   fazach, także starszy zapis, bez odtworzenia dawnej erupcji drugi raz.
   Zwolnienie/reużycie źródeł, brak zmiany RNG i symulacji. Porównanie
   wydajności przed/po w osobnym klonie, z jawnymi limitami badanej sceny.
7. **Odbiór i domknięcie.** Krótkie porównania audio przed/po dla sześciu
   postaci oraz fragmenty mieszanego starcia; osobno techniczny PASS i
   artystyczny odsłuch właściciela. W tej sesji agent nie miał wiarygodnego
   odsłuchu i nie może obiecać, że sam pomiar potwierdzi grozę brzmienia.
   Powiązane testy osobno i razem, pełne `scripts/linux/TEST.sh All --timeout
   1800`, pozostałe bramy po ewentualnym błędzie, golden bez zmiany wzorca.
   Przegląd diffu, ZMIANY/ODBIOR/Postęp i commit po wymaganej zielonej bramie.
   Windows niesprawdzony, push wyłącznie na polecenie.

## Postęp

- 2026-11-06: analiza zakończona na czystym `011d3dd`, wersja 0.45.
  Prześledzono definicje sześciu postaci, receptury, feedback, głosy ciała,
  pociski/pola, pulę źródeł, tłumienie, muzykę, obecne testy i pochodzenie
  nagrań. Badanie źródeł: Hunt, SOMA, Dead Space oraz prezentacja DOOM.
- Izolowany audyt wyeksportował 243 wykonania w 144 rodzinach, włącznie
  z ogólnymi odgłosami i nieużywanymi definicjami. Natywne sondy potwierdziły
  nieruchomą panoramę długiego głosu, pomijanie świata w części zdarzeń,
  kolizję dźwięków dwóch różnych pól oraz brak aktywacji audio fali Stolasa.
  Normalizowane pomiary warstw nie są wynikiem odsłuchu ani pełnego miksu.
- Nowe przebiegi: creature-audio-mix 627, star-acolyte-audio 59,
  iron-thrall-audio 47, plague-gardener-audio 59 — łącznie 792 PASS.
  Pięć stabilnych świadectw (audyt i cztery zestawy). Stare All Margrave'a
  nadal odpowiada grze: dziewięć świadectw, 8402 Mechanics/Assets, Input
  50, Architecture/Render/Tools PASS. To wcześniejsze All, nie nowe.
- Dowody: zewnętrzne `work/qa-direct/creature-audio-analysis-20261106/`.
  Własny klon i jego katalog wyników usunięto po zachowaniu pomiarów.
  Nie zmieniono gry, WAV, PNG ani golden. Aktualizacja wyłącznie dokumentów.

## Decyzja

Rekomendowany jest cały powyższy pakiet: sześć odrębnych charakterów,
krzyki ofiar jako warstwa piekielnych czarów Stolasa, naprawa wyzwalania
i przestrzeni oraz wspólny miks. Bez nowych umiejętności i zmian balansu.
Akceptacja planu upoważni do wdrożenia; dobór plików i dokładne parametry
są decyzjami wykonawczymi sprawdzanymi pomiarem i odsłuchem.

## Poza zakresem

- Zmiana wyglądu, animacji, masek, HUD-u, broni, muzyki jako kompozycji,
  zasad walki, HP, obrażeń, czasów SI oraz nowych czarów. Dopasowanie audio
  odbywa się do istniejącego działania i obrazu.
- Wcześniejszy problem punktów nawigacji Furfura przy murze, odbiór obrazu
  i walki Margrave'a oraz inne odłożone kierunki zachowane w archiwach.
- Przebudowa całej akustyki map, nowe postacie, bossowie, mapy i przypisanie
  dziewięciu kręgów do obecnych przeciwników. Bez nagrań wideo i pakowania.
