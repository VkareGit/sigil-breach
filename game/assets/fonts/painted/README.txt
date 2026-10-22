SIGIL illustrated manuscript alphabet / version 2

ACTIVE SOURCES (all images, no font outlines):
  assets/art/alphabet-upper-v11.png       A-Z + ĄĆĘŁŃÓŚŹŻ
  assets/art/alphabet-lower-v11.png       a-z + ąćęłńóśźż
  assets/art/alphabet-punctuation-v11.png . , : ; ! ? + - ( ) [ ] degree infinity = times
  assets/art/numerals-v11.png             0123456789%/
The v11 sheets are the v08 illustrations repainted as fresco lettering by
tools/fresco_repaint (lime white body, red-ochre inlay, sinopia contour, brush
streaks). Alpha is copied unchanged, so every shape, crop and selector is the
v08 one. Rerun that tool before baking if a v08 source changes.
The exact Unicode strings and source mapping are in tools/bake_ui_font/main.lua.

99 illustrated codepoints plus ordinary/nonbreaking space. Unicode minus shares the
illustrated hyphen. Missing input characters are reported by coverage tests; their
visible replacement, if a new unvalidated string reaches the UI, is the illustrated '?'.

Each letter retains a uniform source scale. Shared cap/x-height and row baselines keep
words aligned; advance comes from the actual illustrated width plus a pixel of air.
Ordinary and nonbreaking spaces advance by max(4, ceil(cap-height * .38)) pixels,
keeping actual word gaps readable when the game is displayed at 960x540.
The upper/lower sheets have uneven rows and overlapping bounding boxes (e.g. E-ogonek
and the next Z-acute). Whole connected islands are assigned to a specific Unicode glyph;
selection-upper.png / selection-lower.png encode that codepoint in R + 256*G (byte values).
These masks SELECT original painted pixels; they do not synthesize new outlines.
source-map.lua records the source file, crop, baseline, selector and selector-mask file.

The fifteen active PNG alphabets use area sampling: original alpha > .55, weighted RGB,
output coverage > .23. Small glyphs blend 70% toward (.94,.89,.77) ivory pigment so source
black contours do not erase the bright core; large glyphs blend35%. Runtime tint retains
health/armor/ability colors. No extra contours or synthetic glyph shapes are introduced.
catalog.lua records sampleW/H and trimX/Y for independently reproducing every glyph.

REBUILD (PowerShell from the game folder):
  $env:SIGIL_FONT_SOURCE=(Get-Location).Path
  & '<path-to-love-or-lovec.exe>' 'tools/bake_ui_font'
The importer reads the four artworks and preserved line-height/baseline numbers, writes
15 sigil-size.png atlases, the two component selection maps, source-map.lua and catalog.lua.
Do not recapture layout metrics from a rebuilt atlas. The runtime loads only these PNGs,
uses nearest filtering and draws glyph-image quads. No runtime print/printf/newFont.
