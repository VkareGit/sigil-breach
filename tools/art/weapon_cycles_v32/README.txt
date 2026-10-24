SIGIL: BREACH — painted firearm preparation v32

Inputs are the exact, unchanged built-in image_gen outputs. Prompts and SHA:
game/assets/art/weapon-provenance-v32.json. The user explicitly authorized
local retouch of both complete sheets on 2026-10-24.

Run with Windows PowerShell 5.1 (System.Drawing):
  powershell.exe -NoProfile -File clean-atlases.ps1
  powershell.exe -NoProfile -File retouch-reloads.ps1
  powershell.exe -NoProfile -File pack-atlases.ps1

Outputs stay alongside the inputs. No script overwrites game assets.
Compare *-cycle-packed.png and *-packed.json with the production atlas
and content/art/weapon_frames metadata before copying a reviewed revision.
Do not generate a different creature model or change the palette globally.

Cleanup removes low-alpha spill and replaces contaminated edge pixels from
the nearest opaque pigment. Reload variants clone painted bore and primer
pixels from the same sheet. Chamber patches preserve the foreground glove.
Live magazine state selects the authored leaf frame; graphics never decide
when ammunition loads. Fixed painted ejection is unused; breech event feedback
handles its actual spent count. The current cylinder mechanism does not report
spent cases and receives no invented ejection effect. Full-cycle review also checks latch timing,
partial reserve, interruption, swap and resumption.

Packing adds two transparent pixels around each pose, with no scaling or
pigment change. Exact ARGB copying avoids GDI+ premultiplication drift and
the script compares every retained source pixel after placement. Translate
each grip/muzzle/eject anchor by the same two pixels; keep logical cellWidth
and screenScale. Output sizes: shotgun1272x2544, revolver2544x2544.

These are offline authoring tools and source inputs, not runtime resources.
Final technical evidence and human B2 feedback are separate.

The canonical authored registration is game/src/content/art/weapon_frames.lua:
named base/leaf frames, exact rectangles, measured grip/muzzle/eject points,
screenScale, placement and phase timing. These are source data, not generated
at runtime. The PNG preparation scripts intentionally do not overwrite that
Lua file. Review and update its rectangle references if the packing changes;
run weapon-rounds and weapon-art-review afterwards. Experimental importers in
work/ are not part of this reproducible authoring workflow or its deliverable.
