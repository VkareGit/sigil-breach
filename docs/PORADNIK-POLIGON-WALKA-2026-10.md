# SIGIL: BREACH — praktyczny podręcznik edycji

Stan: 28.10.2026. Projekt: `C:\Users\nahiko\Documents\dev\sigil-breach`.
Ścieżki niżej są względem tego katalogu. Przykłady proponują Twoje edycje;
nie oznaczają dodatkowych, ukrytych zmian w grze.

## Uruchomienie i testowanie

W katalogu projektu uruchom `./RUN.ps1` albo:

```powershell
cd C:\Users\nahiko\Documents\dev\sigil-breach\game
love .
```

Po edycji Lua uruchom grę ponownie. RESET FIELD nie wczytuje plików ponownie.
F2 otwiera próby. Komnata zaczyna rzeczywistą walkę ze 100 HP i 40 osłony.
Katalog, strzelnica i podgląd animacji mogą używać nieśmiertelności/manekinów:
sprawdzaj DAMAGE ON i AI LIVE. Zmieniaj jeden problem naraz, w tej samej próbie.

## Gdzie czego szukać

| Co zmieniasz | Plik w `game/src/` |
|---|---|
| Układ poligonu, pokoje, ołtarze, światła | `content/maps/proving.lua` |
| Dostępny tryb i mapę | `app/release.lua` |
| Margrabiego / Furfura | `content/creatures/boss.lua` / `furfur.lua` |
| Zwykłe demony | Ten sam folder: `imp.lua`, `armored.lua`, `stolas.lua`, `buer.lua` |
| Parametry obrażeń broni i ruchu rycerza | `content/tuning.lua` |
| Profil, magazynek i odrzut broni | `content/weapons.lua` |
| Fizyczny ładunek pod Q | `content/abilities.lua` |
| Klatki i kotwice dłoni | `content/art/weapon_frames.lua` |
| Klatki i kotwice demonów | `content/art/sheets/` |
| Malowidła środowiska | `content/art/environment.lua` |
| Treść podpisów | `content/text.lua` |
| Dźwięki / muzykę | `audio/recipes.lua` / `audio/score.lua` |

Przepływ: **definicja → walidacja → stan postaci → symulacja → zdarzenie →
obraz/dźwięk**. Definicja jest wspólnym przepisem. Nie zapisuj w niej bieżącego
HP, magazynka ani cooldownu pojedynczego demona.

## Jak samemu zmienić bossa

Otwórz `content/creatures/boss.lua`. `body.hp` to życie; `armor` i
`locationArmor` to rating pancerza (nie procent); `poise` to odporność postawy;
`mass` wpływa na pchnięcia i przyspieszanie. `move.speed/accel` to m/s i m/s²,
`move.ideal` to dystans utrzymywany przez styl `keep`.

Przykład: w `ember-fan` zmień `windup = 0.65` na `0.85`, aby dać o 0,2 s
więcej na reakcję. `body.hp = 1200` zamiast `1000` wydłuży walkę, ale nie nauczy
bossa niczego nowego. Większe `move.ideal` odsuwa strzelca od strzelby, o ile
mapa daje miejsce na odwrót. Parametry każdego ataku:

| Pole | Znaczenie |
|---|---|
| `range`, `minRange` | Kiedy AI może rozpocząć atak; nie promień wybuchu |
| `windup` | Zapowiedź przed uderzeniem |
| `duration` | Stan wykonania; ruch może mieć własny czas, np. `lungeTime` |
| `recover` | Odpoczynek po wykonaniu, okno na kontrę |
| `cooldown` | Blokada następnego ataku po wykonaniu; biegnie równolegle z recover |
| `rest` | Blokada ponownego wyboru tego ruchu, od jego rozpoczęcia |
| `speed` | Prędkość pocisku albo szarży, zależnie od dostawy |
| `aimLead`, `leadFloor` | Przewidywanie obserwowanego ruchu przy rozpoczęciu |
| `packet(base, impact, typ)` | HP, impet postawy, rodzaj obrażeń |

Celowanie wykorzystuje `aimLead * max(leadFloor, tierLead)`. Cel zostaje
zamrożony przy zapowiedzi: zmiana kierunku ma pozwalać uniknąć. Nie skracaj
windup do zera. `packet(22,60,'fire')` nie gwarantuje straty 22 HP: osłona,
odporności i kontakt nadal działają. `push` jest osobnym impulsem fizycznym.

Margrabia ma wachlarz, linię ognia, kontynuację pociskiem i bliską erupcję.
Furfur ma szarże, piorun, krzyż i powrót. **Obaj mają jedno życie, bez drugiej
formy.** Biblioteka faz pozostaje na przyszłość; nie przywracaj starych faz
wyłącznie w celu zwiększenia trudności.

## Nowy atak bez przepisywania postaci

Przykład do tabeli `attacks` (Action i packet są już importowane w pliku):

```lua
Action.bolt({
  id = 'slow-cinder', range = 12, windup = 0.9,
  recover = 0.8, cooldown = 1.2, rest = 4,
  speed = 9, height = 1.9, aimHeight = 1.05,
  aimLead = 0.8, leadFloor = 1,
  color = { 0.95, 0.38, 0.12 },
  packet = packet(18, 35, 'fire'),
})
```

Jeśli demon ma `tactics.moves`, dopisz tam
`{attack='slow-cinder', ideal=8, min=4, weight=1}`. Inaczej polityka taktyczna
nie wybierze ataku. Większe weight zwiększa preferencję; ideal wskazuje najlepszy
dystans. `after` wiąże kontynuację z zakończonym ruchem, celem i oknem czasu.
Nie twórz łańcucha bez przerwy, w której gracz może odpowiedzieć.

Oprawę powiąż z tym samym id: `appearance.art[id]` wybiera animację ataku,
a `windupSound` jego ostrzeżenie. Dodanie danych obrażeń samo nie tworzy
nowych klatek. Sprawdź, czy widoczny gest pasuje do momentu kontaktu.

Gotowe dostawy: lunge, charge, leap, bolt, fan, pool, strike, pattern.
Schematy pól: `content/defs/action.lua`. Wykonawcy: `enemies/melee_kinds.lua`,
`ranged_kinds.lua`, `ground_pattern.lua`. Nowa dostawa wymaga lokalnego
wykonawcy, schematu, oprawy i testów; nie warunków po nazwie demona w rdzeniu.

## Wysokość, hitbox i obrażenia

`height` to wylot nad podłożem, `aimHeight` wysokość celowania, `radius`
rzeczywisty promień pocisku. Zagrożenia ziemne mają osobną objętość
(`content/defs/area.lua`): bottom/top i sample='feet' albo 'body'. Większy
obraz płomienia sam nie zwiększa damage ani wysokości kontaktu.

Uproszczenie fizycznych obrażeń w `combat/damage.lua`:
`baza × moc × spadek z dystansem × strefa × 100/(100+pancerz po penetracji)`.
Dalej działają odporności, materiał i soak. Przykład: baza 70, pancerz 30,
penetracja 0,5, reszta neutralna → `70*100/115 = 60,87`. Strzelba liczy osobne
śruciny; część może chybić albo trafić innego demona.

Zmiana HP nie wymaga zmiany maski. Nowa sylwetka wymaga dopasowania arkusza,
klatek, maski, anatomii i kotwic. Maska strzałów, kolizja ruchu i geometria
ciosu to osobne kontrakty; nie zastępuj ich wspólnym prostokątem.

## Edycja mapy i pokoi

Obecne `proving.lua` jest niezależną mapą **49×43**, nie kopią Limbo.
Jednostka to metr; x/z to plan, y wysokość. Środek komórki jest całkowity.
`yaw=math.pi` patrzy ku malejącemu z.

`rooms` otwiera podłogę: `{3,12,17,29}` oznacza x = 3–17, z = 12–29 włącznie.
Reszta jest ścianą. `pillars` dodaje przeszkody. `elevations` podnosi podłogę:

```lua
{ x1=8, z1=6, x2=12, z2=7, height=0.32 }
```

Próg chodu to 0,32 m (`tuning.terrain.stepHeight`); wyższy stopień może wymagać
skoku. Lokalne `bands` budują sklepienie: spring to podstawa, rise wznios,
centre oś, halfWidth rozpiętość. Pierwsze pasujące pasmo wygrywa. Wynikiem są
fizyczne decks. Sam łuk w decor.arches pozostaje dekoracją. Przy zmianie
pokoju dopasuj strop, przejścia, lampy i miejsca pojawiania się demonów.

`proving.chambers`: entry to start rycerza, slots to miejsca demonów.
`trials` wiąże gatunek z komnatą; `pads` daje stanowisko. Przykład:

```lua
-- trials:
{ id='iron_in_ash', chamber='ash', creature='armored' },
-- pads, na wolnej podłodze:
{ x=23, z=35, trial='iron_in_ash', spawn='armored' },
```

Opcjonalne `readyDelay = 0.2` w próbie skraca początkową blokadę ataku po
pojawieniu się. Nie usuwa portalu, ochronnej pauzy narodzin ani zapowiedzi
samego ciosu. Pominięte pole zachowuje domyślne 1,2 s; zero też jest dozwolone.
To ustawienie konkretnego spotkania, nie nowa globalna trudność gatunku.

Ołtarz Margrabiego przenosisz w seals: id asmoday, obecnie (10, 7).
Stanowisko `{altar='asmoday', trial='ash', spawn='boss'}` dziedziczy położenie;
nie dodawaj drugiego x/z. Fire w komnacie jest wizualnym obwodem aktywnej walki,
nie ukrytą ścianą ani damage. `proving.stations.start` ustala reset i strzelnicę;
po przeniesieniu sprawdź cały odcinek 20 m przed nią.

Nowa mapa wymaga rejestracji w `content/maps/index.lua` oraz wskazania
sessionMaps.field w `app/release.lua`. Publicznie dostępny pozostaje poligon;
fale, sklep i wyprawa pozostają zachowaną biblioteką.

## Broń, wygląd, dźwięk

Parametry broni są w tuning.lua, profile w weapons.lua. `attack.base` dotyczy
pocisku/śruciny, fire.pellets ich liczby, fire.rounds zużycia amunicji.
`attack.falloffStart`, `falloffEnd` i `minPower` określają spadek; weight opisuje odrzut i kołysanie.

Nowa broń: `Weapons.define({extends=Weapons.get('judge'), ...})`, unikatowe id
oraz napisy. Dopisz id do defaultLoadout albo do stanowiska przez weapon.
Amunicja należy do `player.arsenal[id]`. Wykonywany przykład ognistego pocisku:
`tests/cases/weapon_extension.lua`. Nowy demon: plik creatures/id.lua,
rejestracja w content/enemies.lua, napisy, atlas/anatomia i katalog.
Przykład: `tests/cases/creature_extension.lua`.

Dłonie to shotgun-iron-v16.png i revolver-iron-v16.png, arkusze 4×4.
`weapon_frames.lua` opisuje kadry i kotwice chwytu/lufy/wyrzutu. Sama podmiana
PNG nie naprawi kotwic przy innym układzie. Obraz przeładowania musi pasować
do momentu doładowania w combat/reload.lua; renderer nie dopisuje amunicji.

Nowe malowidło: wpis w art/environment.lua, umieszczenie w decor.murals.
Nie tworzy automatycznie kolizji. Zachowaj paletę i skalę detalu obecnych
demonów; HUD i bazowe modele pozostają wzorcem. Przezroczyste portale są
rysowane po obiektach nieprzezroczystych, nadal z kontrolą głębokości.

`sounds.step/alert/windup/strike` wybiera dźwięki demona; attack.windupSound
szczególną zapowiedź. Receptury są w audio/recipes.lua, muzyka w score.lua.
Po edycji odsłuchaj kilka demonów z wystrzałami. Eksport WAV nie dowodzi,
że ostrzeżenie da się dobrze usłyszeć w walce.

## Sprawdzenie przed commitem

Z katalogu głównego, w PowerShell:

```powershell
cd C:\Users\nahiko\Documents\dev\sigil-breach
.\FORMAT.ps1
.\TEST.ps1 -Suite All -TestTimeoutSeconds 600
```

Szybsze zestawy tego samego TEST.ps1: `-Suite Mechanics`, `-Suite Render`,
`-Suite Architecture`.
Nie aktualizuj golden tylko po to, żeby test przeszedł; wyjaśnij różnicę.
Po zmianie ataku sprawdź zapowiedź, trafienie, chybienie, unik, przerwanie,
śmierć, reset i replay. Po zmianie mapy: dojścia, osłony i portale.

Nowy wariant powinien korzystać z danych. Nowy mechanizm może potrzebować
lokalnego modułu i testu kontraktu. Baza nie oznacza, że dowolną przyszłą
funkcję da się dodać bez żadnej zmiany kodu.

Jeżeli dodajesz **nowy stan w czasie gry**, np. temperaturę pojedynczej broni,
przechowuj go w jej rekordzie. Dla nowego pola aktora sprawdź
`session/components.lua`, a dla pola sesji `session/fields.lua`. Uzupełnij
reset, snapshot/zapis i replay; przetestuj dwie instancje, żeby jedna nie
zmieniała drugiej. To najważniejsza różnica między nowym wariantem danych
a nową mechaniką.
