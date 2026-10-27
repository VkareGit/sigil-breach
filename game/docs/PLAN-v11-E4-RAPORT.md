# Plan v11, etap E4: obserwator geometrii i obserwacje strzałów (C4)

Raport odbioru E4 planu `PLAN-FUNDAMENT-v11.md`.

## Kontrakt obserwatora

Każde zapytanie o geometrię malowanego ciała przyjmuje jawnego obserwatora,
czyli punkt, do którego obraca się billboard. Dotyczy to:
- `Pose.base`, `Pose.anchor`, `Pose.sample`;
- `Anim.pose` (wybór klatek tyłem);
- `Geometry.volumes`, `Geometry.find`;
- `Surface.top`, `Surface.prepare`;
- `Anchor.point`.

Symulacja nie pyta widza kamery. Moduły `enemies/*` nie wołają już
`Roles.viewer`, a zapadka `VIEWER IN SIMULATION` spadła z 3 do 0.

Kto jest obserwatorem:

| Zapytanie | Obserwator |
|---|---|
| strzał z obserwacją | oko strzelca w próbce, która mu ją pokazała (`O.capture`) |
| strzał bez obserwacji (bot, test) | oko strzelca w bieżącym kroku (`B.prepare(g, shooter)`) |
| pocisk w locie | żywy i obecny właściciel; martwy albo usunięty: punkt wystrzału (`Projectiles.observer`) |
| wzrok i oczy stworzenia (`R.eye`, kotwice, wierzch) | jego bieżący cel (`Pose.observerOf`); w produkcji sterowany rycerz |
| prezentacja (renderer, cienie, efekty, sztuka zdolności) | `Roles.viewer(g)`, czyli widz kamery |

Kompromis, nazwany w planie, zostaje: billboard pocisku obraca się do
bieżącego położenia żywego właściciela. Dwóch obserwatorów zobaczyłoby inną
sylwetkę w tym samym punkcie.

## Obserwacja strzału

- `O.capture(shown, owner, shooter)` zapisuje:
  - id strzelca (`shooter`);
  - generację obserwacji jego aktora (`actorGeneration`);
  - punkt wystrzału i ciała z tej samej próbki, widziane z oka tego
    strzelca.
- `O.valid` sprawdza sesję, generację świata, mapę, wiek, id strzelca
  komendy i generację jego aktora. Komenda A z obserwacją B jest odrzucana
  przed zużyciem amunicji i kadencji.
- `O.command(observation, g, shooter)` bierze kierunek strzelca z chwili
  komendy i korytarz z jego broni.
- `app/input.lua` trzyma obserwację na aktora (`observations[id]`):
  - `Input:present(game, shown, actor)` zapisuje obserwację aktora;
  - `Input:command(game, actor)` bierze jego własną.

## Zakresy unieważniania

- **Świat:** `O.invalidate`. Woła go wyjście z gry (pauza, mapa, utrata
  fokusu) i reset poligonu. Nowa sesja i zmiana mapy unieważniają przez
  sprawdzenie sesji i mapy.
- **Aktor:** `O.invalidateActor`, czyli pole rycerza `observationGeneration`.
  Woła go:
  - śmierć rycerza innego niż sterowany;
  - `actorLeave`;
  - `actorControl`, dla obu rycerzy.

  Obserwacje innych aktorów zostają.
- Teleport: gra nie ma polecenia teleportu aktora. Przesunięcie aktora nie
  unieważnia cudzych obserwacji, co sprawdza test. Reset poligonu, jedyne
  dzisiejsze przeniesienie, unieważnia świat.
- Dziennik v5 zapisuje w nagłówku generacje aktorów (`actorGenerations`)
  i odtwarza je razem z generacją świata. Dziennik rozpoczęty po zmianie
  sterowania odtwarza więc obserwacje wobec tych samych generacji. Pole jest
  opcjonalne, więc starsze dzienniki v5 i v2–v4 odtwarzają się jak dotąd.

## Odbiór

- **Zapadka `VIEWER IN SIMULATION`:** 0 (z 3).
- **Złoty wzorzec:** te same skróty.
- **Rzut stanu i referencje 0.33 (`v033-reference`):** identyczne.
- **Rendery:** 606/606 identyczne z bazą v11.
- **Bramki:** format, architektura (0 naruszeń), Mechanics 4211 sprawdzeń,
  Input, Render i Tools przechodzą.
- **Testy `observer` (22 sprawdzenia):**
  - obserwacja nazywa strzelca, zaczyna się w jego oku i obraca demona do
    niego;
  - komenda A z obserwacją B, a także B z obserwacją A, jest odrzucona bez
    zużycia amunicji i bez zmiany stanu;
  - B rusza się i obraca między próbką a komendą, a i tak trafia w głowę
    demona widzianego ze swojej strony. Punkt wystrzału pochodzi z próbki;
  - rysowanie B przed A nie zmienia trafień: ten sam stan;
  - buforowane naciśnięcie B po `maxAge` jest odrzucone bez amunicji;
  - przytrzymany spust B bierze najnowszą obserwację;
  - pocisk: wariant z właścicielem żywym (jego oko), martwym w puli
    i usuniętym (punkt wystrzału). Każdy wariant jest odtworzony
    z dziennika ze zgodnym stanem;
  - zakresy unieważniania:
    - śmierć B kończy tylko jego obserwacje;
    - przesunięcie innego rycerza nie kończy żadnej;
    - zmiana sterowania kończy obserwacje obu rycerzy, ale nie innych;
    - odejście rycerza kończy tylko jego obserwacje;
    - generacja świata i reset poligonu kończą wszystkie;
  - dodatkowa kamera, rysowana rendererem i przesuwana co klatkę, nie
    zmienia rzutu stanu po żadnym kroku ani stanu końcowego;
  - dwa widoki prezentowane co klatkę (A i B) dają jeden krok świata na
    klatkę, nie zmieniają stanu i zostawiają obserwację na aktora.
- **Próba dwóch aktorów na malowanym demonie:**
  - A celuje w tułów, B w głowę. Każdy strzela z własnej obserwacji
    przez wejście (`fireCommand`, `actors.knight2.fireCommand`);
  - każdy strzał B trafia w głowę, każdy strzał A trafia demona;
  - dziennik odtwarza próbę krok po kroku z równym rzutem i stanem
    końcowym.

Warunek końca planu jest spełniony: testy i próba są zielone, a złoty
wzorzec się nie zmienił. Raport E0 nie pokazał reguły, która zmienia
dzisiejsze wyniki.

Pomiar: zbiorczo w `PLAN-v11-POMIARY.md`.
