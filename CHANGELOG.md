# Changelog

## 3.1 — 2026-11-17

- The warning stays quiet in the open world while out of combat. It now only
  shows during combat, or anywhere inside an instance (dungeon, raid, BG).
  `/rfa move` and `/rfa test` still show the icon on demand.
- `/rfa` status line gained a `quiet` flag.

## 3.0 — 2026-11-15

- Rewritten as a standalone addon (no WeakAuras/ForeverAuras).
- Presence is read by spell ID (`C_UnitAuras.GetUnitAuraBySpellID("player", 25780)`
  and friends) instead of by aura name, which is what made name-based
  reminders fire in combat while the buff was up.
- Combat lockdown: a negative answer is only trusted once the same call
  returned a positive one during that fight; otherwise the last known state is
  kept.
- 3 second settle window after `PLAYER_ENTERING_WORLD` / `ZONE_CHANGED_NEW_AREA`,
  because the aura list is empty while zoning.
- Draggable icon (`RegisterForDrag`), saved position, `/rfa move`,
  `/rfa test`, `/rfa reset`, `/rfa sound`, `/rfa debug`.

## 2.x and earlier — 2026-11

- WeakAuras/ForeverAuras import strings. Removed: the aura's name check
  returned "missing" in combat, so the warning showed while Righteous Fury
  was up.
