SIGIL illustrated manuscript alphabet / version 2

RETIRED FROM PLAY: the game draws assets/fonts/painted-v16.
The 15 v11 PNG atlases and catalog.lua remain live comparison inputs for
qa/reviews/typography_review.lua. tools/art/bake_type_v16 reads catalog.lua
for line metrics and source-map.lua for punctuation crops. It replaces all
70 letter entries with the active v16 sheets; the old letter selector masks
are not read by that importer and have been removed.

The shared punctuation source is assets/art/alphabet-punctuation-v11.png.
Retired letter sources and selectors are available in git history. Old paths
inside source-map.lua describe the original alphabet; only the punctuation
entries are used when rebuilding v16. Current rebuild instructions and raster
provenance are in ../painted-v16/README.txt.
