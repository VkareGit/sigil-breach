SIGIL / PAINTED TYPE 0.16 — accepted B direction, restrained fresco lettering

ACTIVE RASTER SOURCES
assets/art/alphabet-upper-v16.png — 35 illustrated Latin / Polish capitals.
assets/art/alphabet-lower-v16.png — 35 illustrated Latin / Polish lowercase.
assets/art/numerals-v16.png — 12 illustrated numerical glyphs, 0123456789%/.
assets/art/alphabet-punctuation-v11.png — preserved illustrated punctuation.

The three new sheets were generated with the built-in image_gen tool.
Exact prompts, returned source paths and integration decisions are in
prompts-v16.json in this directory. These are genuine transparent PNGs:
there is no baked paper/background behind any runtime glyph.

The lettering follows B's severe, clear painted Roman / humanist hand.
Its open counters and simple serifs replace v11's heavy jagged Gothic stems.
The horror imagery and ornamental marginalia belong to the surrounding art,
not to flourishes inside every tiny gameplay label.

The runtime uses 15 PNG atlases with the previous line heights and top
positions. Each glyph retains its illustrated proportions and measured ink.
All 70 Latin/Polish letters are new; punctuation is deliberately preserved.
There is no runtime TTF, Font object, print/printf or outline synthesis.
Unsupported codepoints retain the existing illustrated question-mark policy.
Every glyph advance includes breathing room; Polish accents/ogoneks remain.

Eight literal title images use the exact same generated capital artwork.
The title importer composes glyph images into fixed English title PNGs;
it does not rasterize a separate digital font. Titles therefore match HUD
labels and body text instead of introducing another typographic family.

SOURCE SELECTION AND PACKING
source-map.lua records exact source crops. Newly generated letters are clean
isolated cells; no selector mask is needed. Each row baseline is calibrated
against its letter bodies, independently of accents and descenders.
Numeral cell gutters are measured, not assumed equal: the generator shifted
several letters across nominal grid positions. The source's extra dot next
to the slash is outside its selected crop and is never rendered.
The v11 punctuation sheet and comparison font atlases remain; retired
letter sheets and their selector masks are available in git history.

Sampling: original source alpha > .55; exact area coverage > .23.
RGB is area-weighted and blended 25% toward ivory for stable tiny lettering.
No morphology, outline generation, dilation or semantic redraw is performed.
catalog.lua stores sourceMap, sample dimensions and trims so independent
tests can reconstruct the silhouettes from the original raster.

Rebuild from project root:
  $env:SIGIL_FONT_SOURCE='<project>/game'
  & '<project>/toolchain/love-11.5-win64/lovec.exe' tools/art/bake_type_v16
Linux (bash, from the project root):
  SIGIL_FONT_SOURCE="$PWD/game" love tools/art/bake_type_v16

Offscreen visual/source review:
  & '<project>/toolchain/love-11.5-win64/lovec.exe' tools/art/review_type_v16
Linux: SIGIL_FONT_SOURCE="$PWD/game" xvfb-run -a love tools/art/review_type_v16

The importer disables graphics/audio; the specimen tool is hidden and muted,
uses no production saves and does not interact with desktop mouse or keyboard.
Specimens and test results: work/qa-typography-v16.
