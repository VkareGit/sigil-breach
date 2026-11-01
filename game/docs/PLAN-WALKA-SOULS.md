# SIGIL: BREACH — walka souls-like: stwory i bossowie

Status: WYKONANY w 0.36, 1 listopada 2026. Odbiór gracza otwarty. Stan odniesienia: `3109330`, 0.35.
Zakres: sześć istniejących istot. Styl i modele zostają bez zmian.

## Diagnoza dzisiejszej walki

Walka jest uczciwa i czytelna, ale płytka:

| Fakt w kodzie | Skutek w grze |
|---|---|
| Każdy atak ma stały windup, cel zamraża się na początku | Unik zawsze w tym samym momencie wystarcza |
| Ciągi mają najwyżej 2 ciosy, po każdym pełne odsłonięcie | Bezpiecznie strzelasz niemal cały czas |
| Margrabia ma tasak, ale żadnego ciosu wręcz | Boss to działo, nie przeciwnik w zwarciu |
| Fazy istnieją w `enemies/encounter.lua`, żaden boss ich nie używa | Walka nie zmienia się przez całe starcie |
| Cios zwykłego stwora to 20 przy 100 HP i 40 osłony | Błąd kosztuje mało, można się wymieniać ciosami |
| Stwory działają osobno, bez presji stada | Tłum to suma pojedynczych pojedynków |

## Zasady projektu

1. **Błąd boli.** Cios bossa zabiera około połowy zdrowia, zwykłego stwora około
   czwartej części. Wymiana ciosów przestaje być opłacalna.
2. **Każdy cios można się nauczyć.** Żadnego losu w geometrii ani obrażeń, żadnego
   ciosu spoza widoku bez ostrzeżenia. Dotychczasowa reguła zostaje: windup nigdy
   nie jest skracany przez poziom trudności.
3. **Rytm zamiast szybkości.** Trudność bierze się z opóźnień, śledzenia i ciągów,
   a nie z krótszych telegrafów.
4. **Okno na karę trzeba wygrać.** Po pojedynczym ciosie bywa krótkie, po pełnym
   ciągu długie. Chciwy strzał w złym momencie jest karany.
5. **Boss ma etapy.** Co etap dochodzą ciosy i zmienia się rytm, a przejście samo
   jest pokazane i bezpieczne do odczytania.
6. **Poise działa w dwie strony.** Silne ciosy mają hyper-pancerz, a przełamanie
   gardy daje prawdziwą nagrodę: długie odsłonięcie i ranę.

## Nowe mechaniki silnika (dane, nie wyjątki)

| Mechanika | Pole | Działanie |
|---|---|---|
| Ciąg | `string = { into, gap, every }` | Cios przechodzi w następny bez pełnego odpoczynku; ostatni ma długie odsłonięcie |
| Opóźniony cios | `hold = { 0, 0.35, 0.7 }` | Po windupie ciało zawiesza się na wyznaczony czas; kolejność stała, nie losowa |
| Śledzenie | `track = 0.7` | Cel podąża za graczem przez tę część windupu, potem zamarza |
| Strefa ciosu | rodzaj `sweep` | Szeroki łuk wręcz z prawdziwym zasięgiem, omijany odskokiem lub skokiem |
| Pochwycenie | rodzaj `seize` | Trafienie unieruchamia i zadaje obrażenia po czasie; tylko unik ratuje |
| Fala | rodzaj `wave` | Rozchodzący się pierścień, trzeba przeskoczyć albo przebić unikiem |
| Promień | zagrożenie `sweepline` | Wiązka omiatająca salę, omijana skokiem lub filarem |
| Wezwanie | rodzaj `summon` | Boss przywołuje istniejące stwory, ograniczone limitem |
| Skażenie | `buildup` | Stan narasta do progu i wtedy dopiero wybucha skutkiem |

Filary i niszczenie (0.35) wchodzą do walki: boss może zawalić filar, za którym
chowa się gracz, a promień zatrzymuje się na stojącym kamieniu.

## Istoty

Liczby są punktem wyjścia; ostateczne ustalają boty i test uczciwości.

### Żar (imp), stwór podstawowy
HP zostaje 112: podwójne zabójstwo jedną salwą to tożsamość strzelby. Pazur 20 → 28. Nowe: ciąg dwóch pazurów z opóźnieniem drugiego,
skok przechodzący w pazur, odskok po trafieniu. W stadzie atakuje na zmianę z flanki.

### Żelazny (armored), ciężki stwór
HP 170 → 260. Szarża 28 → 38. Nowe: szeroki zamach (`sweep`) z hyper-pancerzem,
zwód szarżą (`hold`), wbicie w ziemię z małą falą. Tył i nogi są słabym punktem.

### Akolita (stolas), mag
HP zostaje 76: szklane działo, trudnością jest dogonienie. Gwiazda 20 → 26. Nowe: krótki teleport po dostaniu w celownik,
trzy zawieszone gwiazdy wypuszczane kolejno, wiązka z ostrzeżeniem. Trzyma dystans
i ucieka od zwarcia, więc trzeba go dogonić albo zmusić do błędu.

### Ogrodnik (buer), obszar
HP 150 → 220. Nowe: narastająca trucizna (`buildup`), korzenie zatrzymujące ruch,
spóźniony wybuch kałuży. Odcina drogi i zmusza do ruchu.

### Margrabia Popiołu (boss)
HP 1000 → 2400, trzy etapy (100/66/33 %), na progach zapasy. Ciosy wręcz tasakiem: dwu- i trzyciosowe
ciągi z opóźnieniem, pochwycenie, doskok z falą. Etap 2: płonące cięcia zostawiające
ogień na linii, wezwanie dwóch Żarów. Etap 3: nowa szybkość ciągów i wielka
fala z absydy, po której boss jest długo odsłonięty.

### Furfur (boss)
HP 1400 → 2800, trzy etapy, na progach zapasy. Szarża z dwiema zmianami kierunku, ciosy porożem w
ciągach, burza w miejscach, gdzie gracz był przed chwilą. Etap 2: krzyż piorunów
idący ku graczowi, odskok z kontrpiorunem. Etap 3: burza na całej sali z bezpiecznym
kręgiem, który wędruje.

## Animacje i styl

Modele demonów są wzorcem i się nie zmieniają. Kolejność środków:

1. Istniejące namalowane pozy pod nowymi nazwami (`windup.<atak>`, `strike.<atak>`).
2. Istniejący mechanizm ruchu: pochylenie, skala, doskok, zawieszenie w `hold`.
3. Nowe efekty czarów (tu styl nie dotyka modelu) malowane przez Codexa astra
   na `high` lub `xhigh`.
4. Nowe klatki ciał tylko na sprawdzonej drodze leap/evade: arkusz modelu jako
   wzorzec, profil pigmentu, anatomia, maski trafień, porównanie w rozmiarze z gry.
   Atlas odstający od modelu nie wchodzi, zostaje punkt 1 i 2.

Bazowe atlasy pozostają nietknięte bajt w bajt.

## Odbiór

- `TEST.ps1 -Suite All`; zmiana złotego wzorca udokumentowana w `baseline.lua`.
- **Bot nieuważny** (stoi, krąży) ginie szybko.
- **Bot uczący się** (zna telegrafy, wykonuje uniki i kary) wygrywa każde starcie;
  to dowód, że żaden cios nie jest nieunikniony.
- Każdy nowy cios ma test: da się go uniknąć z przewidzianej odległości.
- Klatki każdego ciosu w grze, porównane z modelem bazowym.
- Ocena gracza jest osobna: boty nie mówią, czy walka jest przyjemna.

## Kolejność

Etapy v12 migrują kod bez zmiany wyników, a ten plan celowo je zmienia, więc nigdy
nie dzielą commita. v12 R0, R1, R2, R4, R5 (kontrakty potrzebne walce), potem
S1 silnik, S2 stwory, S3 Margrabia, S4 Furfur, S5 efekty i animacje, a dalej
v12 R3, R6, R7, R8, R9.
