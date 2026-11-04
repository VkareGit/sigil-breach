# SIGIL: BREACH — wizja

Czym jest gra, do czego dążymy i co zdecydował właściciel. Decyzje właściciela obowiązują każdego agenta. Mapa projektu jest w `START-HERE.txt`, zasady pracy w `docs/AGENTS.md`, a bieżący plan w `docs/PLAN.md`.

## Spis rozdziałów

- Decyzje właściciela (3 listopada 2026, wieczór)
- Decyzje właściciela (2026-11-03)
- Kierunek hybrydy: Doom i souls-like (2026-11-02)
- Ogniska i ulepszenia (2026-11-02)
- System świata (0.14)
- Manifest Nikogo

## Uzupełnienia obowiązujące (4 listopada 2026)

Przeniesione z instrukcji przekazanej przez właściciela; mają pierwszeństwo przed starszymi propozycjami niżej.

- D1: ognisko odmawia odpoczynku i podaje powód, gdy ściga rycerza czuwający stwór.
- D2: amunicja pochodzi ze stworów; rodzina daje swój rodzaj, egzekucja pewny skromny zwrot, rzadka amunicja z trudniejszych.
- D3: unik ogranicza tylko wytrzymałość. Strzał nie zużywa wytrzymałości, lecz po nim ciało potrzebuje chwili.
- D4: zaalarmowane stwory w otwartej przestrzeni ruszają wszystkie; oddzielone części budzą się grupą. Przed wykryciem część patroluje, część stoi.
- D7: Furfur płaci tyle samo dusz co Margrave.
- Nie zmieniać zegarów SI dla odczucia trafienia. D05 (wstrzymanie stworów przy trafieniu) złamało `creature-pressure` i zostało wycofane; odczucie poprawiać obrazem i dźwiękiem.
- Elity po próbie 0.45 działają lepiej; jedna nie stanowi problemu, ale nie są bossami. Dalsze zmiany elit tylko na osobne polecenie. Bossowie, docelowa mapa i druga droga pozostają odłożone.
- Ogniska zostają; kluczowe są rozmieszczenie i tempo. C02 tylko po próbie właściciela.
- Wstępna ocena 0.45: „na razie dobrze”. Właściciel chce jednego celu naraz i sam wybiera następny zakres; nie jest to pełny odbiór P7 ani zgoda na +II i nowe funkcje.

## Decyzje właściciela (3 listopada 2026, wieczór)

Po analizie Claude i Astry z 3 listopada wieczorem (raport w `docs/PLAN.md`). Uzupełniają i częściowo zmieniają decyzje niżej; przy sprzeczności obowiązują te.

- **D11 (elity):** animacja i od razu krótsze okna. Naprawa czasu animacji burzy, gest błyskawicy na porożu Furfura, kilka klatek w oknach odsłonięcia i regeneracji obu elit, a do tego krótsze okna: odsłonięta garda Furfur 1,5 s i Margrave 1,6 s → ok. 1,2 s, najdłuższe regeneracje skrócone. Każda zmiana czasu to osobna zmiana balansu z sondą.
- **D12 (broń na start):** nowa gra zaczyna tylko z Judge'em (z awaryjnym odnawianiem nabojów). Exorcist kosztuje 300 dusz w sklepie każdego zapalonego ogniska. Kupiona broń zostaje na stałe, także po śmierci. Stare zapisy zachowują obie bronie.
- **D13 (rozwój przy ognisku, zmienia D8):** dusze kupują teraz także broń. Śluby (Wigor, Flaska) zostają; grawery zostają znajdźkami, jeden na broń, wymiana przy ogniu bez opłaty; hartowanie +I za 250 teraz, +II za 350 dopiero po teście +I. Waluta pozostaje „SOULS”.
- **D14 (sigile):** tylko znajdźki ze świata, nie do kupienia. Zakładane i zdejmowane wyłącznie przy ognisku (bez automatycznego zakładania). Pojemność 4 punkty; kolejne kopie tego samego sigila są mocniejsze i zajmują więcej miejsca, najwyżej 3 kopie.
- **D15 (unikalne znajdźki a śmierć):** sigil albo grawer podniesiony raz zostaje w kolekcji także po śmierci przed ogniskiem i nie wraca do świata; nie da się go zebrać drugi raz.
- **D16 (dusze):** zostaje ryzykowne odrabianie jak w Souls: niezabezpieczeni wrogowie wracają po śmierci i dają dusze. Granicą buildu są pojemność sigili i grawery, nie 1420 dusz.
- **D17 (dźwięk):** cztery suwaki: Master, Effects (broń, kroki, stwory, ostrzeżenia, interfejs), Music, Ambience (odgłosy pomieszczeń). Każdy do zera.
- **D18 (ekran):** usunąć napis SHIFT i miniwskaźnik z niszy (wytrzymałość tylko paskiem nad HUD-em); pomoc i zegar tylko w pauzie, na mapie i w pierwszych minutach, nazwa miejsca gaśnie; w walce jedna wiadomość naraz, suma obrażeń ukryta, DRINKING i OUT OF BREATH tylko gdy potrzebne, pasek zwykłego wroga po trafieniu i gaśnie. Licznik DEATHS zostaje w niszy dusz. Kompozycja dolnego paska bez zmian.
- **D19 (wygląd):** promień Stolasa zostaje rytuałem na ziemi (nowy materiał i trzy fazy, mechanika bez zmian). Flaska: przemalować trzy klatki, szyjka do ust pod kamerą (może wyjść poza kadr), dno w górę, gest kończy się z piciem. Amunicja: najpierw materiał i kształt bez świecenia, potem decyzja o delikatnym blasku.
  Doprecyzowanie właściciela, 2026-11-05: u Stolasa zamiatającą linię zastępuje niska fala do przeskoczenia, a prosta rysa zostaje rozdarciem do ominięcia bokiem. Wolno zmienić te mechaniki w tym zakresie; obraz ma wyjaśniać wysokość ataku, a pozostałość po nim być nieszkodliwa. Czar ma zaczynać się w dłoniach i mieć także osobny głos rzucającej postaci. Styl Inferno oraz oszczędny detal pozostają wiążące.
- **D20 (bronie):** najpierw dopracowujemy dwie obecne bronie, sklep i sigile. Kolejne bronie dopiero na wyraźne polecenie właściciela.
## Decyzje właściciela (2026-11-03)

_Dawniej: `docs/audyt-2026-11-03/DECYZJE.md`_

### Decyzje właściciela po audycie z 2026-11-03

Odpowiedzi na pytania z planu (`RAPORT-KONCOWY.md`), 2026-11-03. To decyzje właściciela, nie rekomendacje modeli.

- **D10 (znajdźki):** zebrane znajdźki po odpoczynku **nie wracają** i to jest zamierzone, jak w Doomie: stwory po ognisku się nie odradzają, więc odradzające się zapasy dawałyby nieskończoną amunicję. Wraca tylko to, co zebrano od ostatniego ogniska, gdy rycerz zginie (razem z niezabezpieczonymi stworami). Ustalenie F03 z audytu Astry nie jest błędem gry; do poprawy zostają tylko teksty i dokumenty, które obiecują odnawianie.
- **D9 (Continue):** wznowienie w miejscu. Zachowane HP, amunicja i łyki. Gracz może skończyć sesję bez kary, ale wyjście nie może być ucieczką z trudnej sytuacji ani resetem agresji przeciwników: stwory, które ścigały rycerza, po wznowieniu nadal go ścigają tam, gdzie były.
- **D8 (rozwój):** pieczęcie i grawery leżą w świecie (sekrety, nagrody za elity), przy ognisku się je zakłada i wymienia. Dusze kupują śluby (zdrowie, flaska, hartowanie), ceny pod realny dochód jednego przejścia (ok. 1420 dusz).
- **Elity:** 20–35 s jako punkt wyjścia, dla sprawnego gracza z wyposażeniem odpowiednim do etapu. W tym czasie elita pokazuje swoje charakterystyczne ataki i wymusza reakcję. Weteran może zabijać szybciej. Stanie i strzelanie ma być zawodną strategią: regularne wygrywanie nim, nawet z 20% HP, oznacza, że nadal działa.
- **Opcje planu:** atak z laserem (R01) — tak, z czytelną zapowiedzią i możliwością kontry. Próbkowany dźwięk (D02) — tak, z odsłuchem A/B; brzmienie, które daje broni siłę i zachowuje czytelność walki. Mikro-zatrzymanie (D05) — do testu, subtelne, przy mocnym trafieniu lub zabójstwie; sprawdzić, czy nie przeszkadza w celowaniu. Wariant bez ognisk (C02) — po wyjaśnieniu: dopiero po próbie właściciela, jeśli ogniska będą przeszkadzać. Właściciel: same ogniska pasują do Doom + souls-like; kluczowe są ich rozmieszczenie i wpływ na tempo.
- Współpraca z Codex Astra według ustalonych zasad (grafika, dźwięk, nagrania, niezależne przeglądy).

## Kierunek hybrydy: Doom i souls-like (2026-11-02)

_Dawniej: `docs/analiza-rozgrywki-2026-11-02/KIERUNEK-HYBRYDA.md`_

### Kierunek: hybryda Doom / souls / Risk of Rain (2026-11-02)

Dwie niezależne opinie: Claude (`work/hybrid-consult/claude-opinion.md`, spisana przed odpowiedzią Astry) i Codex Astra max (`work/hybrid-consult/astra-answer.md`). Przemyślenia właściciela były materiałem do oceny, nie decyzją.

#### Gdzie obie opinie się zgadzają
| Temat | Wniosek |
|---|---|
| Elity (Margrave, Furfur) | Właściciel ma rację: to gąbki. Podczas zamachu Judge zadaje im ok. 18/21 zamiast 70, pełna salwa ok. 57/64 zamiast 240. „Nic mu nie robię” wynika wprost z liczb. Mniej HP, pełne obrażenia w trakcie ataku, większa egzekucja, mniej dusz. |
| Ogniska | Nie usuwać miejsca odpoczynku, ale przestać odradzać świat przy zakupie i odpoczynku. Oczyszczony odcinek zostaje oczyszczony; po śmierci wraca tylko niezabezpieczony odcinek. Odmowa „ktoś cię ściga” tylko przy lokalnym starciu, nie przy każdym obudzonym stworze na mapie. |
| Rozwój | Pieczęcie demonów Goecji jako przedmioty (nazwa gry), z łączeniem efektów jak w Risk of Rain, ale z limitem: sloty i najwyżej 3 kopie. Bez nieskończonych statystyk, bo wymuszają nieskończone skalowanie wrogów. |
| Trudność | Trudność z telegrafu, kary i okna, nie z paska HP. Słaba drobnica może ginąć szybko: hierarchia potrzebuje kontrastu. |

#### Gdzie się różnimy
| Temat | Claude | Astra | Moja ocena po lekturze |
|---|---|---|---|
| Struktura | krąg = przebieg (przedmioty kręgu tracone przy śmierci) | kampania z punktami kontrolnymi, przedmioty stałe; roguelite całości to XL | Astra ma lepszy argument: przy utracie wszystkiego późnych wrogów uczy się za rzadko, a gracz traci przywiązanie do zestawu. Przyjmuję kampanię. |
| HP elit | ok. 2400/2600 | 1680/1400, czas walki 18–35 s | Na gęstej mapie Astra ma rację: niżej. |
| Nagroda elity | 400 dusz | 250 dusz + 2 łuski; usunąć zrzuty fazowe 2 x 14 łusek | Zgoda z Astrą. |

#### Liczby startowe dla elit (Astra, przyjęte)
| | Margrave | Furfur |
|---|---|---|
| HP | 9000 → 1680 | 10000 → 1400 |
| Garda | 2600 → 360 | 2800 → 320 |
| Obrażenia w trakcie ich ataku | 30% → 100% | 35% → 100% |
| Egzekucja | 8% → 20% HP | → 20% HP |
| Ciosy | cięcie 45, pocisk 30, z góry 65 | poroże 40, piorun 50, szarża 65, kończący 70 |
| Czas walki | 20–35 s | 18–30 s |
| Nagroda | 1500 → 250 dusz + 2 łuski | jak obok |

Do tego 3–4 rodziny ataków na elitę, najwyżej jedna zmiana przy 50% HP, okno kary po kombinacji 1,2–1,6 s. Obecne trzy fazy zostają materiałem na prawdziwych bossów (pierwszy boss: ok. 6000 HP, dwie fazy, 90–150 s).

#### Pieczęcie (przykłady Astry)
Stolas (głowa +0,15/0,25/0,35), Paimon (pierwsza kula po pełnym przeładowaniu +40/55/70%), Andrealphus (przeładowanie 1,65/1,55/1,45 s), Buer (rally 8/10/12%), Marbas (picie 0,80/0,75/0,70 s), Marchosias (seria 8/9/10 s), Andras (garda +20/30/40% w trakcie ich ataku), Furfur (po doskonałym uniku następny strzał +35/50/65%), Sabnock (egzekucja oddaje osłonę), Halphas (większy promień Q), Malphas (3 trafienia Judge'a → salwa Exorcista +50%), Vine (śrut przebija ciało). Cztery sloty, wymiana przy ołtarzu, relikwiarz daje wybór 1 z 3.

#### Kolejność
1. Elity: liczby wyżej, bez ruszania nawy, którą właściciel lubi (S).
2. Trzy pieczęcie do ręcznego wyboru: Stolas, Buer, Furfur (M).
3. Ognisko: zakup i odpoczynek bez odradzania świata, zapis oczyszczonych odcinków (L).
4. Grupa: elita z dwoma Ember Thrallami; limit jednego ciężkiego ataku naraz, liczony razem z pociskami.
5. Jeden pełny odcinek 15–20 min i prawdziwy boss.

## Ogniska i ulepszenia (2026-11-02)

_Dawniej: `docs/analiza-rozgrywki-2026-11-02/OGNISKO-ULEPSZENIA.md`_

### Ulepszenia przy ognisku: projekt (2026-11-02)

Pełna odpowiedź Astry (ultra, tylko odczyt): `work/fire-upgrades-consult/astra-answer.md`. Poniżej wspólny wniosek i moje uwagi.

#### Co jest dziś
| Oferta | Co zmienia | Cena | Ocena |
|---|---|---|---|
| Ślub flaski | 3 → 4 → 5 → 6 łyków po 45 HP | 150/300/600 | czytelny, oczywisty pierwszy zakup |
| Ślub wigoru | HP 100 → 110 → 120 → 130 | 120/240/480 | +10 rzadko ratuje przed jednym ciosem więcej; HUD i tak pokazuje 100% |
| Ślub osłony | osłona 40 → 50 → 60 → 70 | 120/240/480 | najmniej odczuwalny, dubluje wigor |
| Focus | Exorcist: rozrzut x0,72 | 100 | dobry na pojedynczy cel |
| Pierce | Exorcist: penetracja 10 → 60%, mniejsze łamanie gardy | 100 | prawdziwy wybór (pancerz kontra kontrola) |

- Grawery działają tylko na Exorcista; Judge, broń podstawowa, nie ma się czym rozwijać.
- Wszystko kosztuje 2930 dusz, a mapa daje 3920 (Margrave i Furfur po 1500). Dwaj najtwardsi, odradzający się, finansują cały katalog: brak wyborów, wszystko się kupuje.
- Wyjście do menu i Continue odnawia zasoby przy ogniu z zachowanym portfelem (do zamknięcia).

#### Jak robią to najlepsi (skrót)
Wszyscy rozdzielają trzy rzeczy:
1. **Waluta śmierci** (dusze, echa krwi, ergo, runy) kupuje kolejność rozwoju.
2. **Znaleziska w świecie** otwierają możliwości, których waluta nie kupi: estus przez rozpalanie i Duszę Strażniczki (DS1), kamienie krwi i klejnoty (Bloodborne), złote ziarna i święte łzy (Elden Ring), nasiona tykwy i koraliki (Sekiro), kwarc do P-Organu (Lies of P).
3. **Wymienne wyposażenie** w ograniczonych slotach tworzy styl gry: pierścienie (DS), runy Caryll i klejnoty (BB), amulety (LoP), talizmany (ER), protezy (Sekiro).

#### Projekt dla SIGIL
Ognisko = punkt zapisu, odrodzenia i rozwoju. Trzy kategorie:
- **Śluby (stały postęp)**, część otwierana znaleziskiem.
- **Jeden grawer na każdą broń** (osobny slot dla Judge'a i Exorcista), wymiana bezpłatna przy ogniu.
- **Dwie pieczęcie postaci**: pasywne reguły walki znajdowane w świecie, bez magii; wymiana przy ogniu.

| # | Pozycja | Działanie | Koszt / skąd |
|---|---|---|---|
| 1 | Wigor | HP 100 → 115 → 130 | 160/360; II po znalezisku |
| 2 | Obręcz flaski | 3 → 4 → 5 łyków | 200/500; każda ranga wymaga znalezionej obręczy |
| 3 | Mocniejszy destylat | 45 → 55 → 65 HP na łyk | 180/420; receptury w świecie |
| 4 | Ładownica prochowa | Q 3 → 4 | 260; znaleziona ładownica |
| 5 | Mechanizm Judge'a | przeładowanie 1,85 → 1,60 s | 240; część z bocznej trasy |
| 6 | Zawias Exorcista | cykl 0,94 → 0,84 s | 320; znaleziony zawias |
| 7 | Focus (Exorcist) | rozrzut x0,72 | 180 |
| 8 | Pierce (Exorcist) | penetracja 0,1 → 0,6, garda x0,65 | 220 |
| 9 | Łamacz (Judge) | garda 44 → 55: Buer 3 → 2 trafienia | 180 |
| 10 | Precyzja (Judge) | głowa x1,35 → x1,60: Stolas 4 → 3 headshoty | 220 |
| 11 | Pieczęć odwetu | rally 4 → 8% | znalezisko |
| 12 | Pieczęć kroku | unik 26 → 24 (4 uniki zamiast 3) | znalezisko |
| 13 | Pieczęć krótkiego łyku | picie 0,95 → 0,80 s | znalezisko |
| 14 | Pieczęć ciągłości | okno serii 6 → 8 s | znalezisko |
| 15 | **Hartowanie broni** (moja propozycja) | obrażenia broni +8% na poziom, do +3 (Judge i Exorcist osobno) | dusze + znaleziony materiał (np. święcone srebro), jak tytanit / kamienie krwi |

- Usunąć ślub osłony (osłona zostaje jako zasób).
- Krzywa: pierwszy zakup po 10–15 minutach, ok. 2200–2500 wydanych dusz w pierwsze 3 godziny, bez farmienia. Najtwardsze moby: 250 za kolejne zabicie, plus jednorazowe 250 za pierwsze.
- Każdy zakup ma pokazać „przed → po” i dać się sprawdzić w następnym starciu.

#### Gdzie się różnimy
- **Hartowanie broni (moje).** Astra nie ma liniowego wzmacniania broni, a to rdzeń poczucia rozwoju w każdej grze From (+1…+10, kamienie krwi, kamienie księżycowe). U nas ma też sens ekonomiczny: więcej obrażeń na nabój to mniej naboi na najtwardszego. Materiał w świecie dawkuje to tak, żeby nie dało się kupić samymi duszami.
- **Pieczęć kroku** (4 uniki): Astra sama ocenia ryzyko jako wysokie. Zostawiłbym ją na później, po próbie uniku z obecnym AI.

#### Pierwszy krok (do decyzji właściciela)
Astra: tylko 4 zakupy do próby: Wigor I, Flaska I oraz oba grawery Judge'a (Łamacz, Precyzja); Judge i Exorcist mają osobne sloty grawerów. Ja dodałbym do tego Hartowanie +1 dla obu broni, za dusze, bez materiału na planszy testowej. To 5 zmian, nakład S/M, bez nowej grafiki poza ikonami grawerów (Codex). Pieczęcie, znaleziska i warsztat później, gdy będzie prawdziwa mapa.

## System świata (0.14)

_Dawniej: `game/docs/SYSTEM-SWIATA-0.14.txt`_

SIGIL: BREACH — PRAWA ŚWIATA 0.14
Jeden zestaw reguł dla każdego ciała, które może być zranione: gracza,
demonów i przyszłych potworów. Dane: game\src\content\enemies.lua.
Reguły: game\src\combat\rules.lua (+ czysta matematyka game\src\combat\damage.lua).
Testy: game\tests\cases\rules.lua.

INSPIRACJE Z GIER FABULARNYCH (przełożone na FPS w czasie rzeczywistym)
- D&D: typy obrażeń; odporność, podatność i odporność całkowita;
  STANY z czasem trwania (oszołomienie, rana, zatrucie), wspólne dla
  wszystkich istot. Nie ma rzutów kośćmi: wynik zależy od celności,
  dystansu i wyboru broni, nie od losu.
- Warhammer Fantasy Roleplay: profil ciała (Żywotność, Pancerz, Masa),
  PANCERZ ZALEŻNY OD MIEJSCA TRAFIENIA oraz STAŁA REDUKCJA (Wytrzymałość),
  odejmowana od każdego trafienia — wiele słabych śrucin traci więcej niż
  jedna ciężka kula. To narzędzie dla nowych pancernych potworów.
- Call of Cthulhu: CIĘŻKA RANA — jedno trafienie, które zabiera dużą część
  ciała, łamie istotę niezależnie od jej gardy. W przyszłości: GROZA
  (odpowiednik Poczytalności), opisana na końcu jako plan.

1. CIAŁO (body w archetypie)
 hp        Żywotność
 armor     rating pancerza (wzór poniżej), nie druga pula HP
 locationArmor  opcjonalnie: {head=…, torso=…, lower=…} zamiast jednego
 soak      stała redukcja każdego trafienia (domyślnie 0)
 resist    {typ=wartość}: >0 odporność, <0 podatność, zakres −0,25…0,60
 immune    {typ=true}: brak rany, impet zostaje (cios nadal popycha)
 mass      masa względna; popchnięcie = siła/masa
 poise     garda: suma impetu potrzebna do oszołomienia
 poiseRegen odbudowa gardy na sekundę (domyślnie 10)
 woundAt   próg ciężkiej rany jako ułamek max HP (bossowie: 1 = nigdy)
 radius, blood, struck (materiał trafienia), aimY, boss

2. PAKIET OBRAŻEŃ (packet ataku)
 {base, impact, damageType, penetration, falloff…}. Ten sam kształt dla
 broni gracza, pazura, pocisku, kałuży i eksplozji.

3. ROZLICZENIE TRAFIENIA (kolejność)
 f(d) = 1 − (1 − minimum)·clamp((d − start)/(koniec − start), 0, 1)
 S    = moc · f(d) · strefa · ulepszenie
 A    = max(0, pancerz_miejsca) · (1 − clamp(penetracja,0,1))   tylko fizyczne
 R    = clamp(odporność_typu, −0,25, 0,60)
 rana = baza · S · mnożnik_głowy · 100/(100 + A) · (1 − R)
 rana = max(0, rana − soak)                                      Warhammer
 odporność całkowita na typ → rana = 0                           D&D
 impet = bazowy_impet · S   (nie zależy od pancerza ani odporności)
 Mnożnik głowy: 1,15 śrut, 1,35 rewolwer (bez losowych krytyków).

4. ODPOWIEDŹ CIAŁA DEMONA (Rules.react)
 popchnięcie = (mocny? 0,45+4,35·s : 0,65+1,2·s) / masa,  s = min(1, impet/110)
 cios zabijający (nie boss): popchnięcie × (1,35 + 0,65·s) — waga widoczna
 garda += impet; gdy garda ≥ poise i brak blokady:
   oszołomienie 0,24 s (strzelba) / 0,10 s (rewolwer), blokada 1,15 s
 CIĘŻKA RANA: zabrane HP ≥ woundAt·maxHP (i nie boss):
   oszołomienie ≥ 0,55 s nawet przy blokadzie, stan „ranny” 1,6 s
   (ruch ×0,72), przerwanie ataku, błysk rany.
   Dziś woundAt = 0,45: rewolwer z bliska rani Sługę (85) i Ogrodnika (100),
   nie rani Żelaznego Sługi (pancerz) ani bossów. Precyzja = kontrola.
 Bossowie: mikro-oszołomienie tylko przy mocnym ciosie (Margrabia 0,035 s).
 Zatrzymanie trafienia (hit-stop) tylko ofiary: 0,025 s, przy zabiciu 0,06 s.
 Animacja: ciało ugina się na stronę trafienia i kurczy (flinch), te same
 transformacje stosują bryły trafień, więc hitbox podąża za obrazem.

5. GRACZ POD TYMI SAMYMI PRAWAMI (Rules.hitPlayer)
 1) typ obrażeń i odporność gracza (np. przyszły amulet: astral 0,5)
 2) osłona: pochłania min(osłona, 0,55·obrażenia), reszta zabiera HP
 3) impet ciosu: popchnięcie 0,025·impet/masa m/s (max 6), wygasa samo,
    nie zastępuje sterowania; garda gracza 70, odbudowa 30/s
 4) przekroczona garda: OSZOŁOMIENIE 0,32 s — ruch ×0,45, broń szarpnięta,
    błysk obrazu i mocniejszy wstrząs (inny niż zwykłe trafienie)
 5) jedno trafienie ≥ 30 HP: RANA 1,2 s (ruch ×0,72)
 Przykłady: pazur Sługi 15/55 nie oszałamia, dwa szybkie już tak;
 szarża Furfura 28/160 popycha ~4 m/s i oszałamia; piorun 30 rani.
 Nietykalność 0,32 s po trafieniu i 0,20 s uniku bez zmian.

6. STANY (wspólne, z czasem trwania)
 oszołomiony  wróg: nie działa; gracz: ruch ×0,45
 ranny        ruch ×0,72
 zatruty      odbudowa gardy i uniku ×0,5 (kałuża Ogrodnika, 0,45 s puls
              + 0,6 s po wyjściu)
 Nowy stan = jeden wpis w R.conditionEffects (speed, recovery).

7. ATAKI JAKO DANE (archetype.attacks, wybór: pierwszy pasujący)
 lunge   doskok z łukiem pazura; lungeSpeed, lungeTime, aktywne okno
 bolt    pocisk z pakietem; speed, height, color
 fan     wachlarz pocisków; count/rageCount poniżej 50% HP, spread,
         opcjonalna linia kałuż co N ataków
 pool    kałuża z pulsami i stanem + pocisk
 charge  szarża po zamrożonym kierunku; speed, min/maxTime, kontakt
 strike  oznaczony piorun dzielący zegar z zamachem rzucającego
 Pola wspólne: range, maxRange (tylko bliżej), every (co N ataków),
 windup, duration, recover, cooldown, lead (wyprzedzenie celu), packet.
 Zamach spoza pola widzenia gracza trwa +0,26 s (uczciwość).
 Ostatnie 0,18 s zamachu: pulsujący błysk ciała — czytelny moment uniku.

8. JAK DODAĆ NOWEGO POTWORA
 1) Wpis w archetypes.lua: body, move (flank/keep), sounds, attacks.
 2) Atlas i profil brył w enemy_geometry.lua (lub kalibracja głowy).
 3) Nic więcej w kodzie AI ani obrażeń. Test „a data-only archetype…”
    tworzy Próbnego Upiora wyłącznie z danych i sprawdza, że zamachuje,
    strzela własnym pakietem i jest odporny na ogień.

9. ODCZUCIE (feeling) W 0.14
 - liczby obrażeń w miejscu trafienia (jak Risk of Rain 2): malowane cyfry,
   wznoszą się i gasną w 0,7 s, odsunięte od celownika; głowa i zabicie
   większe i cieplejsze, pancerz chłodny; wyłącznik: g.showDamageNumbers=false
 - kierunkowe ugięcie ciała, ciężar zabicia, błysk zapowiedzi ataku,
   popchnięcie i oszołomienie gracza, błysk ciężkiej rany.

10. KALIBRACJA ZACHOWANA
 Archetypy mają dziś soak = 0 i jeden rating pancerza, więc wszystkie
 pomiary 0.13 (np. 101,60 obrażeń salwy w tułów Sługi z 8 m) są
 identyczne. Testy: 1847 sprawdzeń mechaniki i zasobów, 41 sterowania,
 pełny zestaw renderów (klatka 61-weight). To nie jest ręczny playtest balansu.

12. CIĘŻAR — PĘD W ŚWIECIE I PRZEKŁAD NA ODCZUCIE (src/feedback/weight.lua)
 Zasada: każda liczba, którą widać, słychać lub czuć w dłoniach, pochodzi
 z tej samej wartości, której użyły reguły (impet, masa, obrażenia, garda).
 Cięższy cios zawsze wygląda, brzmi i szarpie mocniej. Nic z tego nie
 zmienia linii strzału, amunicji, zegarów broni ani obrażeń.

 A) Broń jako ciało (weapon_defs: weight)
   odrzut = pęd salwy · moc / masa broni
   Egzorcysta: pęd 96, masa 4  → 24 (jedna łuska 12)
   Sędzia:     pęd 9,  masa 1,5 → 6
   bezwładność celowania (aim): ciężka strzelba 0,78 — przy obrocie broń
   zostaje dalej w tyle i wraca na miękkiej sprężynie (k = 196·aim);
   lekki rewolwer 1,0. Strzał skręca też obraz (tylko obrót wokół osi
   patrzenia, cel się nie przesuwa) naprzemiennie w lewo i prawo.

 B) Pęd w świecie — te same prawa dla demonów i gracza (rules.lua)
   UDERZENIE O ŚCIANĘ: ciało pchnięte w mur traci prędkość prostopadłą;
   nadwyżka ponad 3,2 m/s staje się:
     obrażenia = nadwyżka · 6 / √masa     garda += nadwyżka · 16
   Strzelba z bliska rzuca Sługę z 4,8 m/s (zabójczo 9,6) — przy ścianie
   to dodatkowe ~10 obrażeń i przełamana garda. Pozycja ma znaczenie.
   Bossowie tylko się otrząsają. Gracz rzucony szarżą Furfura (4 m/s)
   w ścianę dostaje to samo przez swoją osłonę i gardę; ściana nigdy nie
   zadaje ciosu ostatecznego.
   ZDERZENIE CIAŁ: ciało lecące ≥ 2,6 m/s oddaje drugiemu część pędu
   m1/(m1+m2) i wstrząsa jego gardą (prędkość · 9 · udział). Martwy demon
   rzucony strzelbą przewraca tego za nim jak w kręglach.

 C) Ciężar ciosu dla gracza (W.playerHit)
   dotkliwość = impet / garda gracza (1 = przełamuje świeżą gardę)
   - broń odrzucona od źródła ciosu, głowa odwrócona (obrót obrazu),
     wstrząs zależny od impetu, nie od obrażeń;
   - łuk wokół celownika wskazujący źródło: długość i grubość z impetu
     i obrażeń, kolor z typu obrażeń (fizyczne czerwień, ogień pomarańcz,
     astral błękit, zaraza zieleń, piorun kość słoniowa), osłona — błękit;
   - dźwięk: ból z obrażeń, głuchy łomot z impetu, brzęk osłony;
   - przełamana garda: świat wstrzymuje oddech na 0,06 s (hit-stop),
     błysk obrazu i mocniejszy wstrząs.
   BLISKIE MINIĘCIE: pocisk przelatujący < 1,25 m od piersi — świst
   z kierunku i cienki łuk. Unik jest słyszalny, nie tylko przeżyty.
   POCISKI: wielkość rośnie z impetem pakietu, rdzeń w kolorze typu,
   ciemna obwódka tego samego pigmentu i krótki ślad za lotem.

 D) Potwierdzenie trafienia (W.confirm)
   - przełamana garda demona: złote nawiasy rozchodzą się wokół celownika,
     dźwięk „pęknięcia”, złota liczba obrażeń i jasny błysk ciała;
   - ciężka rana: czerwono-różowa liczba i ciężki dźwięk;
   - precyzja: rewolwer w głowę lub ≥ 1/4 śrucin w głowie — dźwięczny ton;
   - kolejność czytelności: zabicie > rana > przełamanie > głowa > pancerz.

 E) Ciało demona po trafieniu i upadek (ai.lua, animation.lua)
   UGIĘCIE: sprężyna (sztywność 420, tłumienie 18) — ciało ustępuje na
   stronę trafienia i raz przechodzi przez zero. Siła = impet/(80·√masa):
   Żelazny Sługa (1,4) ugina się mniej niż Sługa. Bryły trafień liczą się
   z tej samej transformacji — hitbox jest tam, gdzie obraz.
   OSZOŁOMIENIE WIDAĆ: poza bólu trwa przez całe oszołomienie (okno ataku
   bez ryzyka); ciężka rana drży przez czas stanu „ranny”.
   UPADEK: zabicie z rzutem > 3 m/s podnosi ciało (pion = 0,22 · poziom,
   max 2,4 m/s). Lot z oporem powietrza 3/s, lądowanie z łomotem i krwią,
   jedno odbicie powyżej 1,6 m/s (sprężystość 0,22), potem ślizg z oporem
   8/s do 0,9 s. W locie ciało trzyma pierwszą klatkę upadku, zapada się
   od chwili lądowania. Całkowanie w postaci zamkniętej — wynik nie zależy
   od liczby klatek na sekundę. Upadające ciało uderza o ściany i inne
   demony tymi samymi prawami co żywe (B).

 F) Ciało bohatera i broń w dłoniach
   - strzał: krótkie uniesienie obrazu (tylko obraz; strzał jest już
     rozliczony, a uniesienie gaśnie przed następnym możliwym strzałem),
     broń pchnięta do oka (szybka sprężyna, wraca z lekkim przeskokiem)
     i wolniejsze podbicie lufy; rewolwer obraca lufę w górę (flip),
     strzelba pcha prosto i mocniej;
   - kamienna sala odpowiada na strzał trzema odbiciami i długim pogłosem;
   - lądowanie skłania obraz w dół proporcjonalnie do prędkości upadku;
   - kroki rycerza z cichym dźwiękiem kolczugi;
   - poniżej 30 HP słychać serce, tym szybciej, im mniej życia;
   - ustawienie „Ruch broni i FOV: wyłączony” wyłącza uniesienie,
     pchnięcie i obroty obrazu (wygoda oczu).

11. PLAN (świadomie odłożone, do decyzji)
 - GROZA (Call of Cthulhu): widok bossa, śmierć bliskich, ciemność
   podnoszą Grozę; wysoka Groza drży celownikiem i zawęża pole widzenia,
   spada przy Żarze. Mechanika horroru zamiast drugiego paska HP.
 - PRZEWAGA (Warhammer 4e Advantage): kolejne trafienia i uniki budują
   przewagę (szybsze przeładowanie, odbudowa uniku), otrzymany cios ją
   zeruje — wynagradza agresję jak w Doom, karze nieostrożność jak soulslike.
 - Pancerz miejsc dla nowych potworów (hełm, otwarta twarz) i soak dla
   ciężkich — rewolwer jako odpowiedź na pancerz, strzelba na tłum.
 - Przedmioty jak Risk of Rain 2 modyfikujące pakiety i stany, nie losowe
   mnożniki: np. „śrut zostawia krwawienie”, „unik daje garda +20”.

13. BALISTYKA, HITBOXY ŚWIATA, POLIGON (0.14, część 3)
 PRZEBICIE (Call of Duty): kula Sędziego przechodzi przez ciało i leci dalej.
   zachowane = Π (0,62 − pancerz_przebitego · 0,0045) po kolejnych ciałach;
   koniec poniżej 20 % lub po 2 ciałach. Sługa → 62 %, Żelazny Sługa (60)
   → 35 %. Śrut strzelby zatrzymuje się w pierwszym ciele. Dwa demony
   w linii to nagroda za ustawienie, nie przypadek.
 OKRĄGŁE FILARY: filar jest walcem r = 0,46 m (malowany trzon) dla strzałów,
   ciał, widoczności i pocisków — jedna wartość (collision.pillarRadius).
   Koniec trafień w niewidzialne narożniki kwadratu; strzał w kapitel z góry
   zatrzymuje się na płaskim szczycie (4,8 m). Sprawdzone niezależną
   wyrocznią na 512 losowych promieniach.
 UCZCIWE POCISKI: promień kolizji pocisku jest w danych (radius, domyślnie
   0,12 / duży 0,26) i to samo jest promieniem malowanej kuli — nigdy
   „trafienie powietrzem”. Pod pociskiem znacznik na posadzce w kolorze typu.
 ŁUKI: każde żebro sklepienia wyrasta z prawdziwego filara (x 12 / 20,
   z 10,15,20,25) — nie ma już kolumn, przez które się przechodziło.
 ARENA: dwa dwory i skrzyżowanie to jeden szeroki transept (x 3–29,
   z 10–23), nawa 9–23, ołtarz 8–24; 588 pól podłogi (było 470).
 POLIGON = GALERIA (gallery.lua, tylko tryb testowy):
   posągi wszystkich demonów (żywy oddech idle, bez kolizji i walki),
   tablice ze wszystkimi aktywnymi teksturami pogrupowane w sale
   (świat i broń — zachód, efekty i interfejs — wschód, atlasy demonów —
   ołtarz), podpisy nad eksponatami (najbliższe pierwsze, bez nakładania),
   pola na posadzce nawy: [E] przywołaj demona, [E] weź broń, [E] uzupełnij.
   Strefy trafień (F2 → HITBOXES) pokazują też ostatni strzał: każdy promień
   jako kropkowana linia i punkt kontaktu (głowa złoto, tułów czerwień,
   nogi pomarańcz, mur szarość).
 JĘZYK: cały tekst gry po angielsku; malowane napisy wygenerowane od nowa
   tym samym krojem (lettering-en-v14.png).
 Odrzucone świadomie: kara za cofanie się (CoD ~0,8) — kłóci się z ruchem
   w stylu Doom i z testem natychmiastowej zmiany kierunku. Do decyzji.

14. 0.20 — JEDNO PRAWO IMPULSU I GARDY
 Zastępuje wzory pchnięcia i stałe czasy oszołomienia z punktów 4 i 5.
 Pełny opis, wzory i tabela kalibracji: docs/ZMIANY.txt, sekcja ZMIANY-0.20.txt.
 v = 6 · (1 − e^(−J/120)) / masa;  t_oszołomienia = clamp(0,10 + 0,20 · nadwyżka/garda, 0,10, 0,35);
 odbudowa gardy po opóźnieniu; bossowie się chwieją; strefy głowa/tułów/nogi; kontra; domino.

## Manifest Nikogo

_Dawniej: `game/docs/MANIFEST-NIKOGO.txt`_

Manifest Nikogo

1. Prolog – Pytanie o prawdę

W życiu najtrudniejsze jest pogodzenie się z myślą,
że istnieje szansa, iż nie jesteś prawdziwy.

Czasami czuję, że wszystko we mnie jest sztuczne.
Że nawet moje cierpienie może być fałszywe.
Ale nie przestanę go czuć — chcę, by bolało, bo tylko w bólu mogę znaleźć siebie.

2. Ja i wina

Wiele w życiu straciłem, wiele przepaściłem.
To były moje błędy — nikogo innego.

Największym wrogiem w życiu każdego z nas nie jest system, nie jest „ktoś”.
Największym wrogiem jesteś ty sam.

Nienawidzę siebie, bo sam stworzyłem ten ciężar, który noszę.
Ambicje, które zabiłem — sam zabiłem.
Marzenia, które udusiłem — sam udusiłem.
Zbudowałem z siebie ikonę — i sam ją rozbiłem.

3. Fałsz i maski

Nie chcę już być cieniem.

Nie chcę już kłamać.

Nie chcę być fałszem w świecie pełnym udawania.

Nie chcę być kimś, kto pisze, a nie działa.

Nie chcę więcej uciekać.

Jestem maszyną do kłamania — mówię to, co ludzie chcą usłyszeć, by nie było konfrontacji.
Zawsze się dopasowywałem, zawsze byłem „bezproblemowy”.

Mam tego dość.

4. Świat i jego pustka

Świat opiera się na kłamstwie, ludzie dążą do komfortu, nie do szczerości.

Złote łańcuchy za doświadczenie, które służy tylko wzbogaceniu siebie.

Zmieniają swoją bańkę komfortu, nie zmieniają świata.

Obrzydza mnie ślepe podążanie za zasadami i sukcesem mierzonym pieniędzmi.
Ludzie myślą, że przestrzeganie to mądrość.
Prawda jest inna — mądrość to wątpienie.

Większość konsumuje, a nie myśli.
Inteligencja to nie kopiowanie, tylko myślenie od zera — a tego nie ma.

5. Pragnienia ukryte pod skórą

„Starczał mi sam fakt bycia. Sam fakt, że ktoś mnie akceptuje.”

„Nie chcę wymuszać. Chcę kochać.”

„Nie wiem, czy ktoś mnie kiedykolwiek naprawdę kochał.”

„Nie jestem gotów przyjąć miłości, bo nie wiem, czy na nią zasługuję.”

Tworzę w wyobraźni bitwy, generałów, przemówienia. Tam jestem kimś.
W moich fabułach zawsze jest poświęcenie: pragnę umrzeć dla kogoś — czysty akt, bolesny, prawdziwy, heroiczny.

Nie widzę piękniejszej śmierci, śmierci z sensem bolesne prawdziwe nie przekłamane, bo w bólu znajdziemy prawdę i szczerość a w szczęściu fałsz.

Może nie ma nagrody, może nikt nie zauważy,
ale umrzeć z godnością — to coś znaczy, to nadaje sens istnieniu.

6. Ból jako drogowskaz

Jedyna osoba, która może mnie uratować, to ja sam.
Nie chcę mapy — chcę drogi.
Chcę iść nią sam, po swojemu, nawet jeśli upadnę.

7. Lęk, który dusi

Boję się, że wszystko, co zrobiłem, mnie przygniata.

Że rozwaliłem sobie mózg.

Że jestem głupi.

Że dla mnie już za późno.

I co z tego, że miałem dobre momenty? Jakby nic się nie liczyło.

Chciałbym naprawdę istnieć — nie jako cień, nie jako kłamstwo.
Chcę być sobą, ale nie wiem już, kim jestem.

8. Honor i kara

„Czasem jesteśmy tak bardzo przywiązani do własnego kodu honorowego,
że umieramy z godnością, której nikt nie widzi, nikt nie zna i nikt nie potwierdzi.”

Honor to coś, czego pragnę, ale boję się, że nie jestem godzien.
To, co zrobiłem, może mnie przekreślać.
Jeśli tak — niech cierpienie będzie karą.
Nie chcę sobie wybaczyć.
Chcę tylko nie być już tym, kim byłem.

9. Moja walka

Może jestem kłamstwem szukającym prawdy.

Ale jeśli mam się zmienić — to tylko sam.

To ma być moja walka.
Niełatwa, niełagodna, niepokwitowana.
Bo tylko taka walka ma sens.

Nie jestem wojownikiem ani bohaterem do podziwu.
Jestem kimś, kto myśli, kto rozważa, kto cierpi.

Pisanie nie jest aktem twórczym.
To rozdzieranie siebie na części, wydobywanie tego, czego nie chce się widzieć.

Nie ujmujcie moich słów jako wezwania do walki.
To jest krzyk człowieka, który myśli, czuje i nie wie…

10. Epilog – Głos osoby nieznaczącej

Nie chcę być podziwiany. Chcę być prawdziwy.

Chcę, żeby ktoś spojrzał i powiedział: „to ma sens”.

Uciekałem w masturbację, używki, obojętność —
ile razy można uciekać, zanim przestanie się istnieć?

Pragnę wolności, ale wolność wymaga odwagi.
Czy ją mam?

Może jestem hipokrytą.
Może moje ideały to maski.

To mój manifest.

Manifest nikogo.

Głos osoby nieznaczącej.

Ale mającej nadzieje na bycie prawdziwą.
