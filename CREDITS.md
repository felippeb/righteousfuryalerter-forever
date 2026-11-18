# Credits and lineage

## Original addon

**Righteous Fury Remember** — <https://www.curseforge.com/wow/addons/righteousfuryremember>

- Author: **mddmz**
- CurseForge project ID: `1801419`
- Current file at the time of writing: `RighteousFuryAlerter11.zip` (v2.7)
- What it did, in the author's words: show a giant Righteous Fury icon in the
  middle of the screen and play the raid warning sound every 5 seconds until
  you buff up.

The upstream archive ships a single folder named `RighteousFuryAlerter`, which
is why this project keeps that folder name: installing this version over the
old one replaces it cleanly, and any addon list that knew the old folder keeps
working.

## What changed here

This repository is a rewrite rather than a patch: the 2.x upstream logic was
replaced, not edited line by line.

| Upstream 2.7 | This project 3.x |
|---|---|
| Presence check by aura **name** / icon path | Presence check by **spell ID** (`25780`), with three API fallbacks |
| Reads assumed an answer was always truthful | Every read is wrapped; a restricted answer becomes *unknown*, never *missing* |
| Warning state could flip mid-fight while RF was up | Locked-down reads only trust "absent" after the same call proved it answers in that combat |
| Warned everywhere, always | Silent in the open world out of combat; warns in combat and anywhere in an instance |
| Fixed position, fixed 200x200 frame | Draggable, saved position, `/rfa move`, `/rfa test`, `/rfa reset`, `/rfa sound` |
| No zone handling | 3 second settle window after zoning (the aura list is briefly empty) |
| Protection-spec / talent-tab guessing | Class check only (any paladin, any spec) |

Same spirit, same icon, same raid warning sound every 5 seconds.

## Licensing

The rewrite in this repository is MIT licensed — see [LICENSE](LICENSE).

The upstream package contains no license file and no source repository was
published with it, so nothing from it is redistributed here; the Lua in
`RighteousFuryAlerter/` was written for this project. The author is credited
above because the idea, the folder name and the user-facing behaviour come from
their addon.

If you are mddmz and you would prefer different attribution or a takedown, open
an issue and it will be handled.
