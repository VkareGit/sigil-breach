SIGIL: BREACH / archiwum starych plików (po wydaniu 0.31, 2026-10-23)

ZAWARTOŚĆ
SIGIL-BREACH-old-assets-0.31.zip - 88 plików pod pierwotnymi ścieżkami
projektu, 126,2 MiB przed spakowaniem:
  15 nieużywanych grafik (żadnego odwołania w grze, testach, QA ani tools),
  13 dawnych atlasów, które sprawdzały stare testy (te testy czytają teraz
     atlasy używane w grze: behavior, core, shotgun, movement, interface),
  12 wejść wycofanych narzędzi (alfabety i cyfry v08/v11 poza interpunkcją
     v11, napisy, pergamin, portret v11, tekstury v11),
  11 dawnych czcionek TTF (DejaVu, Grenze, VT323) z licencjami - gra rysuje
     wyłącznie malowane glify assets/fonts/painted-v16,
   8 plików 5 wycofanych narzędzi tools/art (bake_ui_font, fresco_repaint,
     preview_ui_font, fresco_textures, portrait_atlas),
  25 PNG z porządków 0.29 (dawniej work/archive-art-v29),
   4 zapisy tamtych porządków (notes/archive-art-v29; ich ścieżki wskazują
     dawny folder).
manifest.csv - ścieżka, rozmiar, SHA-256 i powód każdego pliku.
RESTORE.ps1  - bez parametrów sprawdza ZIP z manifestem i pokazuje, co by
               wróciło; z -Apply przywraca brakujące pliki, nigdy nie nadpisuje.

GIT
ZIP jest w .gitignore (za duży na repozytorium). README, manifest i
RESTORE.ps1 są w gicie. Pliki z game/ i tools/ są też w historii commitów
sprzed archiwizacji (git show <commit>:<ścieżka>); 25 PNG z 0.29 istnieje
tylko w tym ZIP-ie.

PRZYWRACANIE (z katalogu głównego projektu)
  .\old\RESTORE.ps1
  .\old\RESTORE.ps1 -Apply
Po przywróceniu wycofanego narzędzia lub dawnych testów sprawdź TEST.ps1.
