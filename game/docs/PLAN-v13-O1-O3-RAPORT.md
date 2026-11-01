# Plan v13, O1-O3: ogniska, posterunki, śmierć

Gra zaczyna się teraz od kaplicy: menu wchodzi do trybu `pilgrimage`
(`src/run/pilgrimage.lua`), a dane drogi są w `src/content/pilgrimage.lua`.

## Co działa

- **Posterunki.** 15 stworów stoi na mapie. Każdy ma miejsce, własny zasięg zauważenia,
  smycz i wraca na miejsce. Część patroluje, część czeka w zasadzce.
- **Hałas.** Stwór z posterunku słyszy strzał tylko w swoim zasięgu. Wcześniej jeden strzał
  budził 7 do 9 stworów naraz.
- **Ogniska.** Cztery. [E] leczy, napełnia flaski i amunicję, ustawia miejsce powrotu,
  podnosi wszystkie stwory, zapisuje grę i otwiera menu ognia: sklep i podróż.
- **Śmierć.** Dusze zostają w miejscu zgonu, druga śmierć je kasuje.
- **Drzwi.** Dwie komórki muru przy galeriach grobowych. Otwierają się tylko od strony sali
  i zostają otwarte w zapisie.
- **Zniszczenia.** To, co się zawaliło, zostaje po odpoczynku i w zapisie. Drobiazgi wracają.
- **Menu.** Nowa gra (z potwierdzeniem) i kontynuacja, poligon jako warsztat obok.

## Decyzja: na razie bez bossów

Decyzja gracza z 1 listopada 2026: wszystko to moby, tylko niektóre trudniejsze, bossami
zajmiemy się później. Margrabia i Furfur stoją więc na posterunkach jak reszta, wstają po
odpoczynku i nie kończą gry. Kod sal zamykanych na czas walki jest w commicie `b6b9ee3`,
do wzięcia, gdy wrócimy do bossów. Na razie gra nie ma zakończenia.

Testy bossów są przez to złagodzone i trzeba je przywrócić przy ich przeglądzie:
`souls_bots` tylko mierzy wygrane z Margrabią i Furfurem, a `souls_gate` wymaga 4 śmierci
na 6 zamiast 6 na 6 u rycerza, który tylko się rusza.

## Co pokazał bot na prawdziwej mapie

Pojedyncze stwory prawie nie trafiały bota, nawet przy 60% źle odczytanych ciosów.
Przyczyny znalezione w śladzie walki:

1. Cofanie się było tak szybkie jak bieg, więc uciekało przed każdym stworem.
2. Skok Żara lądował 4 m od rycerza, a cios po skoku sięgał 2 m.
3. Szarża Żelaznego leciała po prostej i samo chodzenie w bok ją omijało.
4. Jedna salwa przerywała Żara.

Zmiany: tam, gdzie płaci się wysiłkiem, rycerz idzie tyłem z 60% prędkości, a w bok z 85%.
Żar ma 360 HP, próg przerwania 140, prędkość 4,6 i doskok po lądowaniu. Akolita ma 320 HP.
Szarża Żelaznego skręca za rycerzem i ponawia się po chybieniu. Nawa jest rozstawiona na trzy
odcinki.

| Spotkanie | Bot bez błędów | Bot z 60% błędów |
|---|---|---|
| Żar, Akolita | 0 trafień | 0 trafień |
| Żelazny | 0 trafień | 1 trafienie |
| Trzy Żary | 3 trafienia, najniżej 43 HP, 7 z 8 wygranych | 2 trafienia, najniżej 69 HP |
| Żar i Żelazny | 3 trafienia, najniżej 42 HP, 6 z 8 wygranych | 3 trafienia, najniżej 22 HP, 6 z 8 wygranych |

Cała droga, 6 minut, 6 przebiegów: bot ginął od 6 do 14 razy. Do pierwszego ogniska doszedł
w 2 z 6 przebiegów, po około 2 i 4 minutach.

To górne oszacowanie tylko przy pojedynczych stworach, bo bot nie ma czasu reakcji. Przy drodze
jest inaczej: bot słabo wybiera miejsce walki i ciągnie za sobą kolejne stwory, więc tamte
liczby nie mówią, jak trudno będzie człowiekowi.

## Czego nie ma

- Stary kod fal, Limbo i klasycznej areny dalej jest w `src`, choć gracz do niego nie
  dojdzie. Służy za fiksturę ponad 60 plików testów i wymaga osobnego przenosin.
- Drzwi nie mają własnej grafiki: gracz znajduje je po napisie przy murze.
