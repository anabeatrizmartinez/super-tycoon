# SuperTycoon

A simple single-player **tycoon** map for **Fortnite / UEFN**, built in Verse. Buy a
generator, let it pay for itself, restore a haunted mansion and observatory one wing at a
time, and clear the guard that shows up when each one is finished.

The whole loop runs in **about a minute**: passive income, gated progression, a spend
curve, combat, XP rewards, an achievement, and a save that survives closing the game.

---

## Core loop

```
Start with 100 Gold
      ↓
Step on the Generator pad (100)  →  50 Gold/second, from then on
      ↓
Buy Wing 1 (200)  →  the first wing materializes
Buy Wing 2 (300)  →  the mansion is complete  →  a guard spawns
      ↓                                              ↓
                                          clear it to unlock Wing 3
      ↓
Buy Wing 3 (800)  →  Buy Wing 4 (1000)  →  the observatory is complete  →  a guard spawns
      ↓
Clear it  →  achievement
```

Only one pad is visible at the start: the generator. Each purchase reveals the next, so the
map never shows the player a pad they cannot use yet.

## What is in it

| System | How it works |
|---|---|
| **Economy** | Gold is a plain number the map owns. No device holds a balance: the generator adds to it on a timer, pads subtract from it, and the HUD renders the same variable the pads test. |
| **Progression** | Five pads, each revealing one group of props and the next pad. They unlock strictly in order. |
| **Combat** | Completing a building spawns one guard, armed with a DMR. The player starts with an automatic assault rifle. The buildings themselves are indestructible. |
| **XP** | A Medium accolade on the generator, on each of the four wings and on each guard cleared, plus a Very Large one for the achievement — native weight categories, never hardcoded XP numbers. |
| **Achievement** | One — *Lord of the Manor*, awarded for the real ending: all four wings bought *and* both guards cleared. |
| **Interface** | A live Gold counter, a badge listing the achievement as earned or locked, and a label on every pad naming what it buys and what it costs. Built in Verse code. |
| **Persistence** | The generator, wings bought, guards cleared and Gold in pocket survive leaving the session. Dying to a guard costs nothing but the walk back. |

## Tech notes

- **Verse owns the rules; devices do the work.** Gameplay state — what is unlocked, what has
  been paid for, when a guard spawns — lives in Verse. Granting Gold, revealing props,
  spawning guards, and awarding XP are delegated to UEFN devices driven from code.
- **The whole run is five values.** `Gen`, `Wings`, `Guards`, `Gold`, and a schema `Version`.
- **A failed load never overwrites a good save.** Start-up never writes, so a session that
  opens on a failed read and closes without buying anything leaves the stored save exactly
  as it was.
- **Props are revealed.** Every wing exists in the map from the start, hidden, and the
  buildings — built from Epic's Creative gallery — stay indestructible throughout.

## Layout

```
SuperTycoon.uefnproject   UEFN project file — open this
SuperTycoon.uplugin       plugin descriptor
Content/                  the island map, its assets, and all Verse code
  Core/                   costs, income rate, pad labels, pad tags, the save record
  Devices/                the one placed device: start-up order and the state machine
  UI/                     the Verse HUD
  Assets/                 HUD textures and the start-up fade sequence
  CustomProps/            the pad and button meshes
docs/GDD.md               design: loop, economy calibration, progression, combat, UI
docs/TDD.md               implementation: device map, Verse modules, persistence
Resources/                editor icon
```

## Running it

Open `SuperTycoon.uefnproject` in the UEFN editor, **Build Verse Code**, then **Launch
Session**.

Single-player by design.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Icons by [Icons8](https://icons8.com)
