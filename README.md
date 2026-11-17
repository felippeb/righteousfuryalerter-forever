# Righteous Fury Alerter Forever

A big pulsing icon with **RIGHTEOUS FURY OFF!** whenever the paladin buff
Righteous Fury (spell `25780`) is missing — for **WoW Forever** (`_forever_`,
interface `16001`).

No dependencies, no libraries, no WeakAuras/ForeverAuras needed. One addon
folder, one Lua file.

## Why this exists

Every "remind me when Righteous Fury drops" aura I tried had the same bug: it
popped up **in combat while the buff was up**. On Forever the client hides aura
*names* in combat (secret values), so a name-based check reads "no such aura"
and happily reports the buff as missing.

This addon asks for the buff **by spell ID** instead
(`C_UnitAuras.GetUnitAuraBySpellID("player", 25780)`), which the client still
answers while names are hidden, and then treats everything it cannot read as
*unknown* rather than *missing*.

## Behaviour

| Where | When | Warning |
|---|---|---|
| Open world | out of combat | quiet |
| Open world | in combat | yes |
| Instance (dungeon, raid, BG) | out of combat | yes |
| Instance (dungeon, raid, BG) | in combat | yes |
| Dead / ghost | | quiet |

The icon is a 96px spell icon with a red border, a pulsing alpha and a short
warning sound every 5 seconds.

## Commands

```
/rfa          one status line (what the client answered, zone, quiet flag)
/rfa debug    log only when the state changes
/rfa move     unlock the icon, drag it, /rfa move again to lock
/rfa test     show it for 5 seconds
/rfa reset    back to screen centre
/rfa sound    toggle the beep
```

## Install

1. Copy the `RighteousFuryAlerter` folder into
   `World of Warcraft\_forever_\Interface\AddOns\`.
2. Restart the client (new `.toc` metadata is only read at launch).
3. Enable **Righteous Fury Alerter** in the AddOns list at character select.

Or grab a zip from the releases page and unpack it into `Interface\AddOns`.

## How it stays honest in combat

- Presence is read by spell ID, with `GetPlayerAuraBySpellID`,
  `GetUnitAuraBySpellID` and `AuraUtil.FindAuraBySpellId` as fallbacks.
- Every read is wrapped so a restricted/secret answer becomes *unknown*.
- While the client is locked down (`InCombatLockdown()` or
  `C_Secrets.ShouldAurasBeSecret()`), a "not there" answer is only believed for
  the rest of that fight if the same call already answered "there is" earlier in
  it. Otherwise the last known state is kept, which is what prevents the false
  alarm.
- After a zone or instance change the aura list is briefly empty, so "missing"
  results are ignored for 3 seconds.

## License

MIT — see [LICENSE](LICENSE).
