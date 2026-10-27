# Odbiór poprawek v11 — 27 października 2026

## Wynik

Dwie poprawki Claude'a były już zapisane w commicie `a4dada8`.
Sprawdzono je w źródłach i ponownym pełnym `TEST.ps1 -Suite All`.
Uzupełniono jeden pominięty wariant pierwszej poprawki: obrażenia
o nieznanym właścicielu (`nil`). Nie zmieniono wyglądu, balansu,
zapisów ani zawartości menu. HUD i assety pozostają dotychczasowe.

## Poprawki i ich granice

1. **Zabójstwo przez demona:** `feedback/recipient.lua` korzysta z reguły
   `Stats.owner`. Przy jednym rycerzu zdarzenie należy do niego,
   przy wielu do świata. To przywraca zachowanie 0.33.
2. **Drugie urządzenie:** `session/journal.lua` zapisuje zmieniane poza
   komendą pola innych rycerzy przez `actorSet`. Test przechodzi przez
   callbacki wejścia, zapis/odczyt dziennika i porównanie całego stanu.
   Wpis wymaga wersji 5, dozwolonego pola i obecnego aktora. Zachowano
   obsługę wcześniejszych formatów w ramach zgodnego wydania/źródeł;
   nie oznacza to odtwarzania dowolnego starego builda.
3. **Uzupełnienie: nieznany sprawca.** `Recipient.context(g, nil)` nadal
   oznacza domyślnego aktora komendy. Dla łańcucha obrażeń `nil` oznacza
   jednak nieznanego sprawcę. Nowe `Recipient.chain(g, owner)` rozwiązuje
   go przez `Stats.owner` przed wskazaniem widoku. Korzystają z niego
   BodyHit i EnemyKilled. Bez tego przy dwóch rycerzach komunikat
   trafiał do sterowanego, choć statystyki przypisywały zabójstwo światu.

Test trzeciego przypadku uruchomiono przed poprawką: zakończył się błędem
`an unknown damage-chain owner follows the same feedback rule as a demon owner`.
Po poprawce przechodzi. Dowód negatywny:
`../work/v11-review-20261027/red/`. Nie wycofywano poprawek na głównej
gałęzi ani nie zmieniano referencji w celu uzyskania PASS.

## Weryfikacja tego drzewa

- `FORMAT.ps1` i `FORMAT.ps1 -Check`: PASS.
- `TEST.ps1 -Suite All`: PASS; 4288 sprawdzeń mechaniki/zasobów,
  36 wejścia, 519 skompilowanych plików Lua, 0 naruszeń architektury.
- `view-context`: 46 sprawdzeń; oba urządzenia odtwarzają stan bit w bit.
- Referencje 0.33 i sześć skrótów golden bez zmian:
  `07f73bfa/a9192235`, `fe26df14/563c8d0f`, `c13bcaec/f105ca06`,
  `aab9a46e/299`, `4be34edb/671`, `663b77fc/178`.
- 606 renderów: 601 identycznych z E0. Pięć różnic to wyłącznie cyfra
  wersji 0.33 → 0.34 w menu. Pliki, prostokąty i liczby zmienionych
  pikseli są dokładnie takie same jak przy wcześniejszym odbiorze 0.34.
- Osiem cykli zasobów: po zwolnieniu 68 obrazów, 2 płótna,
  383,786 MiB tekstur; zero utrzymanych właścicieli cykli, również
  przed jednorazowym końcowym audytem JIT. Rozrzut sterty Lua ostatnich
  trzech cykli 925,344 KiB jest raportowany, nie zamieniany w fikcyjny PASS
  dowolnego progu pamięci.

Zbiorczy dowód 12 świeżych procesów:
`../work/v11-review-20261027/evidence.json`.
Każdy ma osobne ID, exitCode=0, sourceStable=true i ten sam odcisk źródeł:

`7BB72ED4B96C5A1C748624E067CD37FD1F42BF9D4FEB2AA62FA35B1AD1D0CCDE`

Odcisk LÖVE:
`243A44E76504DF3EACA801A60C8EFE76B190EEB9B1AA444A7276FB33DF1E0361`.
Kopie raportów All zachowano w `../work/v11-review-20261027/all/`.
`passed` w zbiorczym dowodzie oznacza poprawne zakończenie procesów,
nie automatyczne zaliczenie budżetu FPS ani odbioru B2.

## Zalecenie wydajnościowe Claude'a — wykonana kontrola

Sprawdzono dodatkowo budżet 60 FPS: 1000/60 = 16,6667 ms.
Trzy pełne benchmarki w nowych procesach, viewport 1280×720, 300 klatek
rozgrzewki i 720 próbek w scenach przygotowanych; cykle rzeczywistej
aplikacji mają po 540 próbek. Domyślny priorytet Normal, bez affinity.
Nie jest to nowa seria porównawcza E0/E5 w priorytecie High: historycznych
wyników względnych nie zastępowano tymi pomiarami.

Pomiar obejmuje aktualizację aplikacji, świat, postprocessing, bitmapowe
UI, rejestrację obserwacji i synchronizujący odczyt piksela. Nie mierzy
desktopowego present/vsync, opóźnienia wejścia ani wrażenia człowieka.
Sceny 96/256 ciał to diagnostyka poza limitem zwykłego katalogu (20).

| Scena | Mediana median, ms | Najgorsze p95 z 3 prób | Najgorsze p99 | Maksimum |
|---|---:|---:|---:|---:|
| Zamrożona scena 4, z efektami | 4,0872 | 6,2080 | 7,5984 | 18,0200 |
| Zamrożona scena 20, z efektami | 5,4693 | 7,2540 | 8,3802 | 21,5954 |
| Żywy poligon 4, cykl 1 | 5,5409 | 9,2175 | 12,0473 | 32,4807 |
| Żywy poligon 20, cykl 2 | 9,2204 | 16,2106 | 19,7328 | 21,3874 |
| Żywy poligon 4, cykl 3 | 5,3795 | 10,3167 | 12,2148 | 15,3185 |
| Żywy poligon 20, cykl 4 | 9,5412 | 16,4294 | 19,5773 | 43,9320 |
| Diagnostyka 20 żywych ciał | 7,3412 | 14,4007 | 17,6396 | 22,7879 |
| Diagnostyka 96 żywych ciał | 14,3164 | 33,2867 | 40,1345 | 53,5952 |
| Diagnostyka 256 żywych ciał | 23,4927 | 58,3525 | 69,2851 | 78,6620 |

Surowe dane, kwantyle każdej próby i wynik porównania z budżetem:
`../work/v11-review-20261027/budget-summary.json`, `budget-1/` … `budget-3/`.
Najgorsze kwantyle pochodzą z osobnych prób; nie są kwantylami połączonej
próbki. p95 znaczy, że 95% zmierzonych klatek nie przekracza tej wartości.

**Wniosek:** we wszystkich trzech próbach mediany i p95 zwykłego poligonu
mieszczą się w budżecie. p99 cięższej walki i pojedyncze skoki już nie.
Nie ma podstaw do stwierdzenia, że każda klatka zajmuje najwyżej 16,7 ms,
ani że problem przycięć został zamknięty. Z samego czasu ściennego nie
można przypisać skoków konkretnie GC, sterownikowi, UI lub symulacji.

Praktyczne porównanie proponowane w rozmowie ma postać
`(mediana_po <= 1,05 * mediana_przed) LUB (delta <= rozrzut_AA)`.
To alternatywa, nie dwa ograniczenia stosowane jednocześnie: duży rozrzut
w drugim członie nadal może przepuścić istotną regresję. Suma IQR to
heurystyka, nie przedział ufności ani dowód równoważności wersji.
Budżet klatki jest zatem odrębnym wymaganiem, łączonym przez **ORAZ**.

Zastosowano żądaną kontrolę obu aspektów, lecz nie zamknięto punktu 7
na podstawie samej mediany. Historyczny ścisły wynik pozostaje
nierozstrzygnięty, a automatyczne wyniki nie zastępują B2.
W przytoczonej wiadomości nie ma udokumentowanego testu użytkownika,
który pozwalałby potwierdzić stwierdzenie o braku problemów „na czuja”.

## Granice dostawy

Naprawy i ich odbiór poprzedzają osobny audyt gotowości architektury.
Nie dodano trybu, split-screenu, nowej grafiki, balansu ani funkcji menu.
Nie zmieniono `docs/podrecznik-codex/`. Nie wykonano push ani BUILD paczki.
