# Plan v12, etap R9: raport

`tests/cases/v12_pack.lua` to jeden pakiet treści: postać z maną, broń bez amunicji
z glifem, broń z drugim trybem, zaklęcie z czasem rzucania, demon, typ obrażeń, stan,
pole, mapa, bieg dwuetapowy i wieżyczka. Przechodzi start, walkę, dziennik, zapis,
klatkę z renderera, drugi etap i wyrejestrowanie, bez zmian w `game/src`.

Dokumenty: przepisy na górze `ROZSZERZANIE.txt`, fundament na górze
`ARCHITEKTURA.txt`, sekcje 0.36 w `ZMIANY.txt` i `ODBIOR.txt`, `docs/KONTEKST.txt`.

Plan chciał osobnego katalogu `tests/support/extension/pack/`. Pakiet stoi w jednym
pliku testu, bo cała treść mieści się w nim czytelnie.

## Pakiet gracza

`installed-player` kończył się po 600 s bez śladu, bo plan ładowania z błędem czeka
na przycisk. Przyczyna: `Export-PlayerPackage` przepuszczał w `assets/` tylko `.png`
i `.lua`, a sale z 0.35 mają 25 tekstur `.jpg`. Komunikat po poprawce:
`Could not open file assets/art/chapel-hall/inferno-sky.jpg`.

Filtr jest teraz jeden (`Test-PlayerRuntimeFile` w `tools/package.ps1`) i nazywa to,
co zostaje poza grą, a nie to, co do niej wchodzi. Nowy format grafiki nie zniknie po
cichu. `--package-smoke` przy błędzie planu kończy się kodem 1 po 5 s. Fikstura
`tools/package-check.ps1` ma teraz plik `.jpg`.

## Koszt

Mediany i werdykty: sekcja 0.36 w `ODBIOR.txt`, surowe dane `work/v12-measure/final`.

Profil 256 ciał (`jit.profile`, 0.35 → 0.36) dał +10% próbek rozsianych po ścieżkach
na ciało, bez jednego winowajcy. Odzyskane:

- `Attributes.scale` przechodził katalog stanów także dla ciała bez stanów.
- `R.recover` pyta o mnożnik tylko przy niezerowej równowadze.
- `AbilityPose.select` tworzył tabelę na ciało i klatkę.
- `assert(x, 'tekst ' .. y)` w `Pose.base`, `Anim.poses`, `Anim.posed` i
  `AbilityPose.select` sklejał napis przy każdym udanym wywołaniu.

Reszta to nowa logika walki. Krok rośnie z 0,10 do 0,14 ms przy 20 ciałach, budżet
to 8,33 ms, więc koszt jest przyjęty, a nie ukryty.
