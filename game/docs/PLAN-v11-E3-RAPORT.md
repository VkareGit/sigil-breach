# Plan v11, etap E3: niezależny stan aktora (C3)

Raport odbioru E3 planu `PLAN-FUNDAMENT-v11.md`.

Podetapy:
- E3a: osobny commit `8707dab`.
- E3b–E3e: jeden commit. Zmiany w poleceniach, systemach, dzienniku
  i łańcuchu obrażeń zależą od siebie, a testy obejmują je razem.

## E3a — broń, przeładowanie, intencja

Do komponentu rycerza przeszły pola aktora:
- slot w ręku `weapon`, `cooldown`;
- `reload`, `reloadWeapon`, `reloadStage`, `reloadDuration`, `reloadOffset`;
- `fireBuffer`, `fireCommand`;
- `shots`, `hits`;
- licznik sekwencji strzałów `shotSequence`.

Licznik strzału jest rozdzielony:
- `g.shotSerial` to id strzału świata: dziennik, zdarzenia, obserwacje;
- `shotSequence` aktora wybiera orientację rozrzutu i ziarna kontaktów.

Strzał niesie swojego strzelca i jego sekwencję, więc pocisk w locie
rozlicza się sekwencją, z którą wystrzelono.

## E3b — ruch i polecenia aktorów

- `systems/knight` (ruch, kontakt, spust, przeładowanie) i zegary obsługują
  każdego rycerza puli w jej kolejności. Rycerz martwy jest pomijany, poza
  sterowanym.
- Sterowany działa na wejściu kroku. Każdy inny na
  `input.actors[id]`: drugie urządzenie, bot albo dziennik.
- `Game:look`, `shoot`, `cast`, `reloadGun`, `switchWeapon` i `dash`
  przyjmują id aktora (domyślnie sterowany). Id, które nie wskazuje rycerza,
  jest odrzucane, a polecenie martwego nie ma efektu.
- Ruch innego aktora trzyma sprężyny kamery we własnej tabeli. Do widoku
  i wskazówek dźwiękowych trafia tylko ruch sterowanego, do czasu kontekstu
  prezentacji z E5.
- `content/weapons`, `combat/reload`, `combat/combat`, `player/intent`,
  `player/feel`, `combat/body_contact`, `combat/abilities`
  i `combat/explosives` biorą aktora jawnie.
- Uderzenie o ścianę dotyczy dowolnego rycerza. Pokwitowanie obrażeń sesji
  powstaje tylko dla sterowanego.
- Dziennik v5:
  - nagłówek ma `actors` (id rycerzy przy konstrukcji);
  - polecenia niosą id aktora;
  - dochodzą polecenia `actorJoin` (rekord rycerza w formacie członka puli
    z sekcji zapisu, `session/world.lua: memberRecord`), `actorLeave`
    i `actorControl`;
  - preflight buduje tabelę id i odrzuca polecenie przed `actorJoin`, po
    `actorLeave` albo dla id nigdy nieznanego, a także `actorJoin` z użytym
    id lub złym rekordem, zanim zmieni sesję;
  - nagrywanie odmawia polecenia dla nieobecnego rycerza;
  - dzienniki v4, v3 i v2 nadal się odtwarzają.

## E3c — wykonawca i cel w zdarzeniach

- `ShotFired`, `VolleyResolved` (`report.actor`), `ReloadStage`,
  `AbilityCast` i `ChargeThrown` niosą id wykonawcy.
- `BodyHit` i `EnemyKilled` niosą `owner` (właściciel łańcucha) i `target`.
- Do E5 prezentacja pokazuje tylko strzały, przeładowania i rzuty
  sterowanego. Zdarzenia mają znacznik `byControlled`, ustawiany przez
  symulację.

## E3d — łańcuch obrażeń

- Każde zadanie obrażeń demonowi niesie `owner`, czyli id ciała, które
  zaczęło łańcuch:
  - broń: strzelec;
  - ładunek: rzucający (`charge.owner`), a wybuch dziedziczy;
  - bełt: `owner` pocisku;
  - efekt okresowy: aplikujący (`sourceId` instancji);
  - pchnięcie: ciało pamięta `pushOwner` do końca pchnięcia;
  - uderzenie o ścianę i zderzenie: właściciel pchnięcia, który przechodzi
    dalej przy przekazaniu pędu;
  - cios demona: demon.
- Statystyki trafiają do księgi aktorów `g.stats` (`session/stats.lua`):
  zabójstwa, wynik, combo i jego okno, obrażenia przyjęte. Rekord
  zostaje po śmierci i odejściu aktora. Sesja i tryby czytają sumy
  (`Stats.total`), a HUD rekord sterowanego.
- Leczenie `breakKill` dostaje właściciel łańcucha, jeśli jest rycerzem
  obecnym i żywym. Martwy i usunięty nie dostaje nic, a jego zabójstwo
  i nagroda zostają przy jego id.
- Dusza wyprawy ma zapisanego właściciela (`pickup.owner`).
- Zgodność jednoosobowa:
  - łańcuch bez rycerza, czyli cios demona albo zderzenie, którego nie
    wywołał rycerz, w sesji z jednym rycerzem należy do niego, jak w 0.33;
  - referencja E0 przypisania (w tym zabójstwa źródłem `creature`, `slam`
    i `collision`) jest identyczna, więc balans się nie zmienia;
  - przy kilku rycerzach taki łańcuch należy do świata (`world`) i nikogo
    nie leczy.

## E3e — sterowanie, śmierć, usunięcie

- `actorControl` przełącza sterowanie, czyści bufor spustu tracącego
  sterowanie i unieważnia obserwacje (zakres opisuje E4).
- Śmierć sterowanego kończy walkę jak dziś. Śmierć innego to `KnightFell`.
  Martwy zostaje w puli bez efektu poleceń, aż do `actorLeave`.
- Ładunki, pociski i efekty odchodzącego aktora działają dalej z jego id.

## Zgodność zapisów i dzienników

- Sekcja `pools` zapisu sesji ma wersję 2: rycerz niesie stan aktora.
  Pliki wersji 1 wczytują się, a ich rycerze dostają wartości domyślne
  komponentu (migracja).
- Format sekcji `run` wyprawy jest bez zmian. Fixture SIGIL09 z 0.33 dają
  ten sam rzut stanu.
- Pola sesji przeniesione w E2 i E3 są wycofane. Odczyt lub zapis
  `g.weapon`, `g.kills`, `g.bossDead` itd. kończy się błędem, który wskazuje
  nowe miejsce.

## Odbiór

- **Zapadka ACTOR STATE ON THE SESSION:** 0 (z 172).
- **Złoty wzorzec:** te same skróty.
- **Rzut stanu, tabela pozy, przypisanie leczenia i nagród, fixture
  zapisów:** identyczne z 0.33.
- **Rendery:** 606/606 identyczne.
- **Bramki:** format, 0 naruszeń architektury, Mechanics 4189 sprawdzeń;
  Input, Render i Tools przechodzą.
- **Testy negatywne (`actors`):** odrzucone id, martwy bez efektu, zmiana
  broni A nie zmienia slotu B, a `actorJoin` z użytym id lub złym rekordem
  jest odrzucany.
- **Próba dwóch aktorów:**
  - A przeładowuje strzelbę, B strzela z rewolweru, obaj się ruszają;
  - A przerywa przeładowanie spustem;
  - B zmienia broń i ginie od demona (`KnightFell`);
  - dziennik v5 odtwarza całość krok po kroku: rzut obu aktorów jest równy
    po każdym kroku.
- **Test dziennika aktorów:**
  - drugi rycerz z inną pozycją i wyposażeniem wchodzi przez `actorJoin`
    przed pierwszą aktualizacją;
  - trzeci dołącza w trakcie, sterowanie przechodzi na niego, drugi
    odchodzi;
  - zapis tekstowy, odczyt i odtworzenie w świeżej sesji z
    `Journal.session` bez ręcznego tworzenia aktorów, ze zgodnym stanem
    początkowym i końcowym;
  - pięć wariantów uszkodzonego dziennika jest odrzucanych w preflight bez
    zmiany sesji.
- **Test licznika strzałów:**
  - strzały B między strzałami A nie zmieniają ziaren ani orientacji
    rozrzutu A;
  - licznik przetrwa zapis i odczyt sesji;
  - reset aktora go zeruje.
- **Test łańcucha (`damage-chain`), każdy wariant odtworzony z dziennika:**
  - ładunek A przy sterowanym B: zabójstwo, wynik, leczenie i dusza
    należą do A;
  - A ginie przed wybuchem, potem A odchodzi przed wybuchem: zabójstwo
    i dusza przy id A, bez leczenia;
  - efekt okresowy ze strzału A: łańcuch A.
- Uderzenie o ścianę po pchnięciu z właścicielem sprawdza test jednostkowy
  (zabójstwo właściciela pchnięcia), bez dziennika.

Pomiar: zbiorczo w `PLAN-v11-POMIARY.md`.
