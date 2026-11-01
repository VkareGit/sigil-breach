# Plan v12, etap R9: raport

`tests/cases/v12_pack.lua` to jeden pakiet treści: postać z maną, broń bez amunicji
z glifem, broń z drugim trybem, zaklęcie z czasem rzucania, demon, typ obrażeń, stan,
pole, mapa, bieg dwuetapowy i wieżyczka. Przechodzi start, walkę, dziennik, zapis,
klatkę z renderera, drugi etap i wyrejestrowanie, bez zmian w `game/src`.

Dokumenty: przepisy na górze `ROZSZERZANIE.txt`, fundament na górze
`ARCHITEKTURA.txt`, sekcje 0.36 w `ZMIANY.txt` i `ODBIOR.txt`, `docs/KONTEKST.txt`.

Plan chciał osobnego katalogu `tests/support/extension/pack/`. Pakiet stoi w jednym
pliku testu, bo cała treść mieści się w nim czytelnie.
