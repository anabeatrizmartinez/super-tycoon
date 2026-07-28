# SuperTycoon

A simple single-player **tycoon** map for **Fortnite / UEFN**, built in Verse. Buy a
generator, let it pay for itself, restore a haunted mansion and observatory one wing at a
time, and clear the guard that shows up when each one is finished.

The whole loop runs in **about two minutes**: passive income, gated progression, a spend
curve, combat, XP rewards, an achievement, and a save that survives closing the game.

---

## Core loop

```
Start with 100 Gold
      ↓
Step on the Generator button  →  20 Gold/second, straight into your inventory
      ↓
Buy Wing 1 (200)  →  the first wing materializes
Buy Wing 2 (400)  →  the mansion is complete  →  a guard spawns
      ↓                                              ↓
                                          clear it to unlock Wing 3
      ↓
Buy Wing 3 (600)  →  Buy Wing 4 (800)  →  the observatory is complete  →  a guard spawns
      ↓
Clear it  →  achievement
```

Only two buttons are visible at the start: the generator and the first wing. Each purchase
reveals the next button, so the map never shows the player a button they cannot afford yet.

## What is in it

| System | How it works |
|---|---|
| **Economy** | Fortnite's native Gold. The generator grants it on a timer, purchase buttons consume it. The balance is visible in the HUD for free. |
| **Progression** | Four purchase buttons, each revealing one group of props and the next button. Buttons unlock strictly in order. |
| **Combat** | Completing a building spawns one guard. It attacks; the player starts with an assault rifle and infinite ammo. The buildings themselves are indestructible. |
| **XP** | An accolade on every purchase and every guard cleared, using native weight categories rather than hardcoded XP numbers. |
| **Achievement** | One, awarded for the real ending: all four wings bought *and* both guards cleared. |
| **Interface** | A live Gold counter, a panel listing the achievement as earned or locked, and a label on every pad naming what it buys. Built in Verse, not with devices. |
| **Persistence** | Wings bought and Gold in pocket survive leaving the session. Dying to a guard costs nothing but the walk back. |

## Tech notes

- **Verse owns the rules; devices do the work.** Gameplay state — what is unlocked, what has
  been paid for, when a guard spawns — lives in Verse. Granting Gold, revealing props,
  spawning guards, and awarding XP are delegated to UEFN devices driven from code.
- **Progression is a single integer.** The player's whole run is one value, 0–4, plus their
  Gold. That keeps the save inside UEFN's persistence budget, which rewards compact keys and
  punishes cumulative lists.
- **A failed load never overwrites a good save.** "Could not read" and "is empty" are handled
  as different cases, so a transient read failure cannot quietly reset a completed run.
- **Props are revealed, not spawned.** All four wings exist in the map from the start, hidden,
  and are shown on purchase — no runtime instantiation cost, and the buildings stay
  indestructible throughout.

## Layout

```
SuperTycoon.uefnproject   UEFN project file — open this
SuperTycoon.uplugin       plugin descriptor
Content/                  the island map, its assets, and all Verse code
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
