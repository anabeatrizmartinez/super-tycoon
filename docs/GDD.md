# Game Design Document — SuperTycoon

> **Scope:** the **WHAT** and **WHY** — loop, economy, progression, combat.
> **HOW it is built** lives in [TDD.md](TDD.md).

---

## 1. Vision

SuperTycoon is a simple single-player tycoon with a short loop: about two minutes from
spawn to ending. The player earns Gold passively, spends it to restore a haunted mansion
and observatory, and defends the result against a guard when each one is finished.

One currency, one kind of purchase. A button costs Gold, stepping on it builds something,
and the finished building attracts trouble.

Pillars:

1. **Immediate legibility.** Every action's effect is visible in the world within a second
   of taking it. Nothing accumulates off-screen.
2. **No dead time.** Income never stops, so the player is always approaching the next
   purchase. The gaps between purchases are filled by combat, not by waiting.
3. **No failure state.** Dying to a guard costs progress nothing.

## 2. Core loop

```
Earn Gold (passive, continuous)
      ↓
Spend it on the next wing
      ↓
Wing appears · next button unlocks · XP awarded
      ↓
Every second wing completes a building → guard spawns → clear it to continue
      ↓
Four wings and two guards → achievement
```

## 3. Economy

Currency is **Fortnite's native Gold**. It lands in the player's inventory and shows in the
HUD, so the balance is readable without any custom UI.

| Value | Amount |
|---|---|
| Starting Gold | 100 |
| Generator cost | 100 |
| Generator output | 20 Gold/second |
| Wing 1 | 200 |
| Wing 2 | 400 |
| Wing 3 | 600 |
| Wing 4 | 800 |

The starting Gold exactly covers the generator, so the first purchase has one correct
answer and income starts within seconds of spawning.

Costs rise linearly (+200) rather than exponentially. An exponential curve suits a tycoon
that runs for hours and needs the late game to stay expensive; over a two-minute run it
would put the longest wait at the end.

### Calibrated timeline

Income runs continuously, including during combat, so time spent fighting is still time
spent earning.

| t | Event |
|---|---|
| 0:00 | Spawn with 100 Gold; buy the generator |
| 0:10 | Buy Wing 1 (200) |
| 0:30 | Buy Wing 2 (400) — mansion complete, **guard 1 spawns** |
| ~0:45 | Guard 1 cleared (≈300 Gold earned during the fight) |
| 1:00 | Buy Wing 3 (600) |
| 1:40 | Buy Wing 4 (800) — observatory complete, **guard 2 spawns** |
| ~1:55 | Guard 2 cleared → **achievement** |

Roughly **2 minutes** including movement between buttons.

## 4. Progression and gating

Four purchase buttons, unlocked strictly in order. A button becomes visible when it becomes
available, so what the player can see is what the player can use.

| Step | Visible buttons | Unlocked by |
|---|---|---|
| Start | Generator, Wing 1 | — |
| After generator | Wing 1 | purchase |
| After Wing 1 | Wing 2 | purchase |
| After Wing 2 | *none* | **guard 1 must be cleared** |
| After guard 1 | Wing 3 | kill |
| After Wing 3 | Wing 4 | purchase |
| After Wing 4 | *none* | **guard 2 must be cleared** |
| After guard 2 | — | achievement |

The guard gate is what makes combat part of the loop: progression resumes once the guard is
down.

Each wing corresponds to one group of props already present in the map but hidden. Buying
the wing reveals the group. Wings 1–2 restore the haunted mansion; wings 3–4 restore the
haunted observatory.

The generator is a one-time purchase.

## 5. Combat

- **One guard per restored building**, two in the run.
- The guard **attacks the player**. It is tuned to fall in roughly 15 seconds to the starting
  weapon — long enough to be a fight, short enough not to stall the loop.
- The player starts with a **single-fire long-range weapon (assault rifle, not burst, not
  sniper)** and **infinite ammo**. The same weapon carries the whole run.
- **Buildings are indestructible.** The player takes damage; the world does not. Purchases
  survive the fight they triggered.
- If the guard kills the player, the player **respawns with everything intact** and the guard
  is still alive. Retrying costs time, not progress.

## 6. Rewards

**XP** is awarded through accolades using **native weight categories**, never hardcoded XP
numbers, so Fortnite's own economy scales the reward:

| Event | Weight |
|---|---|
| Each wing purchased (×4) | Medium |
| Each guard cleared (×2) | Medium |

The generator purchase is the opening step and carries no accolade.

**One achievement**, awarded for the real ending: **all four wings bought and both guards
cleared**. Buying the four wings without clearing the second guard does not complete the
game.

## 7. Interface

Three pieces, all of them answering a question the player would otherwise have to guess at.

### Gold counter

A persistent readout in a corner of the screen, **updating in real time** as the generator
pays out. The player is always waiting to afford something, so the number they are waiting
on is on screen at all times rather than in a menu.

### Pad labels

Every purchase pad carries a **short world-space label naming what it buys**, readable
before stepping on it:

| Pad | Label |
|---|---|
| Generator | Gold Generator |
| Wing 1 | Mansion · Ground Floor |
| Wing 2 | Mansion · Upper Floor |
| Wing 3 | Observatory · Base |
| Wing 4 | Observatory · Tower |

The label shows the cost alongside the name, so "can I afford this yet" is answered by
looking at the pad and the counter together. A locked pad shows nothing — it is not there
to be read.

*(Labels should match what each prop group actually contains; adjust once the groups are
confirmed in the editor.)*

### Achievements readout

The HUD shows the achievement permanently, in both states, so the player can see it before
earning it:

| State | Shown as |
|---|---|
| Not earned | Name, its condition, marked locked |
| Earned | Name, marked earned |

Showing a single locked achievement is the point — it tells the player what finishing the
map means, which nothing else in the map states.

**It is a fixed row, not a button that opens a panel.** In Fortnite a UI control the player
can click has to hold the same input that moves and aims the character, so a button sitting
on screen for the whole match is movement taken away for the whole match. The row is small,
costs one corner, and states the goal without ever being opened.

## 8. Persistence

Two things survive the player leaving: **how many wings they have bought** and **how much
Gold is in their pocket**. On return, the map rebuilds to that point and play continues.
The achievement's earned state travels with them too.

Guard state is intentionally left out of the save: a returning player gets a clean
re-entry, and a guard that was left alive respawns with its building.

## 9. Scope

The map is single-player, and the world is fixed — the player spends Gold on the four wings
rather than placing or editing structures themselves.
