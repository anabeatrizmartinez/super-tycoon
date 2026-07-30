# Game Design Document — SuperTycoon

> **Scope:** the **WHAT** and **WHY** — loop, economy, progression, combat.
> **HOW it is built** lives in [TDD.md](TDD.md).

---

## 1. Vision

SuperTycoon is a simple single-player tycoon with a short loop: about a minute from
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

Currency is **Gold**, a single number the map owns. Nothing the player carries is a
balance, so nothing they lose can be one — the counter in §7 is the only place the number
is read.

| Value | Amount |
|---|---|
| Starting Gold | 100 |
| Generator cost | 100 |
| Generator output | 50 Gold/second |
| Wing 1 | 200 |
| Wing 2 | 300 |
| Wing 3 | 800 |
| Wing 4 | 1000 |

The starting Gold exactly covers the generator, so the first purchase has one correct
answer and income starts within seconds of spawning.

The curve has two steps, split at the guard: the mansion pair (200, 300) is cheap, the
observatory pair (800, 1000) is steep. The step from 300 to 800 is paid for by guard 1's
fight — see the timeline below.

Costs rise linearly. An exponential curve suits a tycoon that runs for hours and needs its
late game to stay expensive; that is the wrong shape for a one-minute run.

### Calibrated timeline

Income runs continuously, including during combat, so time spent fighting is still time
spent earning.

| t | Event |
|---|---|
| 0:00 | Spawn with 100 Gold; buy the generator (100) |
| ~0:07 | Buy Wing 1 (200) |
| ~0:13 | Buy Wing 2 (300) — mansion complete, **guard 1 spawns** |
| ~0:28 | Guard 1 cleared (≈750 Gold earned during the fight) |
| ~0:30 | Buy Wing 3 (800) — the fight has already paid for it |
| ~0:50 | Buy Wing 4 (1000) — observatory complete, **guard 2 spawns** |
| ~1:05 | Guard 2 cleared → **achievement** |

Roughly **one minute** including movement between pads.

## 4. Progression and gating

Four purchase buttons, unlocked strictly in order. A button becomes visible when it becomes
available, so what the player can see is what the player can use.

| Step | Visible buttons | Unlocked by |
|---|---|---|
| Start | Generator | — |
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

The generator is a one-time purchase, and it has a group of its own: buying it reveals the
machine that pays out, giving the income a visible source in the world.

## 5. Combat

- **One guard per restored building**, two in the run.
- The guard **attacks the player with a DMR**. It is tuned to fall in roughly 15 seconds to
  the starting weapon — long enough to be a fight, short enough not to stall the loop.
- The player starts with an **automatic assault rifle** — not burst, not sniper — and
  **infinite ammo**. The same weapon carries the whole run.
- **Buildings are indestructible.** The player takes damage; the world does not. Purchases
  survive the fight they triggered.
- If the guard kills the player, the player **respawns with everything intact** and the guard
  is still alive. Retrying costs time, not progress.

## 6. Rewards

**XP** is awarded through accolades using **native weight categories**, never hardcoded XP
numbers, so Fortnite's own economy scales the reward:

| Event | Weight |
|---|---|
| Generator purchased (×1) | Medium |
| Each wing purchased (×4) | Medium |
| Each guard cleared (×2) | Medium |
| Achievement earned (×1) | Very Large |

Every step pays the same Medium weight; only the ending pays more.

Each accolade draws its own on-screen splash from its `Name` and `Description` — both named
`XP`, described by their weight — confirming the award at the moment it is earned.

**One achievement**, awarded for the real ending: **all four wings bought and both guards
cleared**. Buying the four wings without clearing the second guard does not complete the
game.

## 7. Interface

Four pieces, all of them answering a question the player would otherwise have to guess at.

### Gold counter

A persistent readout **updating in real time** as the generator pays out. The player is
always waiting to afford something, so the number they are waiting on stays on screen at
all times.

It sits against the **left edge at mid-height**, as a coin icon and the number on a filled
badge. The corners of a Fortnite screen already belong to the game's own readouts, so
mid-height is where the badge stays legible over whatever the player is walking past.

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

### Achievements readout

The HUD shows the achievement permanently, in both states, so the player can see it before
earning it. It mirrors the Gold counter — a filled badge against the **right edge at
mid-height**, carrying an icon, the achievement's name, its condition, and its state:

| Field | Text |
|---|---|
| Name | Lord of the Manor |
| Condition | Restore the Manor and clear the guards. |
| State | `LOCKED` until `Wings = 4` and `Guards = 2`, then `EARNED` |

Showing a single locked achievement is the point — it tells the player what finishing the
map means, which nothing else in the map states.

**It is a fixed badge, never a button.** In Fortnite a clickable UI control holds the same
input that moves and aims the character, so a button sitting on screen for the whole match
is movement taken away for the whole match. The badge is small, costs one edge, and states
the goal without ever being opened.

### Status messages

Two moments get a short line across the screen, and they are the only ones: **guard
defeated** and **achievement unlocked**. Each marks an instant, not an ongoing state — the
two badges already carry the continuous state.

XP has a surface of its own — the accolade splash of §6, which confirms the award where it
happens. Keeping it off this one leaves a player who is usually mid-fight with a single line
to read.

## 8. Persistence

Four things survive the player leaving: **whether they own the generator**, **how many
wings they have bought**, **how many guards they have cleared**, and **how much Gold they
have**. On return, the map rebuilds to that point and play continues. The achievement's
earned state travels with them too — it is read off the wings and the guards, so it cannot
disagree with them.

What is *not* saved is whether a guard is currently alive. A returning player gets a clean
re-entry: a guard that was left standing is spawned again with its building, and one that
was already cleared stays cleared.

## 9. Scope

The map is single-player, and the world is fixed — the player spends Gold on the four
wings; nothing is placed or edited. Building is off and the build menu is hidden, so the
only way to add anything to the map is a pad. A barrier closes the play area at its edge.

The map runs at a **fixed hour**, not a day/night cycle: the mansion and the observatory
are lit the same way at 0:10 and at 1:55. A **fade** opens the run, covering the moment the
map is being hidden and shown for the first time.
