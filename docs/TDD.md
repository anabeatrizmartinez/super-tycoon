# Technical Design Document — SuperTycoon

> **Scope:** the **HOW** in UEFN — Verse layout, device mapping, state machine, persistence.
> The **WHAT/WHY** lives in [GDD.md](GDD.md).

---

## 1. Shape of the implementation

Verse holds the rules; devices do the work. One placed device owns the whole run — start-up
order, the progression state machine, and every subscription. The other two files are pure
logic and are never placed.

```
Content/
  tycoon_manager_device.verse   placed once. Start-up order and the state machine.
  wing_config.verse             costs, income rate, pad labels. Constants only.
  save_data.verse               persistable class, the weak_map, guarded load/save.
  hud.verse                     widget construction and refresh. Renders state, owns none.
```

`hud.verse` is separate because widget construction is bulky and has nothing to do with the
rules. It renders what it is handed and never decides anything — the manager stays the only
place progression is reasoned about.

Single-player, so authority is not contested: everything runs server-side in the manager,
and no gameplay value is ever read back from a client.

## 2. State model

The entire run is five saved values.

| Field | Type | Meaning |
|---|---|---|
| `Version` | `int` | Save schema version |
| `Gen` | `logic` | Generator purchased |
| `Wings` | `int` | Wings bought, 0–4 |
| `Guards` | `int` | Guards cleared, 0–2 |
| `Gold` | `int` | Gold in pocket at the time of saving |

`Gen` is stored rather than inferred. It looks derivable — anyone owning a wing must have
bought the generator first — but the inference breaks at `Wings = 0`: a player who buys the
generator and leaves before their first wing has already spent their starting Gold on it.
Restoring them with `Gen = false` and no Gold leaves them nothing to buy anything with. One
extra field removes the case.

`Guards` counts **guards cleared** — progression — not whether a guard is currently alive,
which is runtime state and gets rebuilt on load.

### Derived gating

Everything visible on the map is a function of those values, recomputed after every event
rather than toggled ad hoc:

| Element | Enabled when |
|---|---|
| Generator pad | `Gen = false` |
| Wing 1 pad | `Gen = true` and `Wings = 0` |
| Wing 2 pad | `Wings = 1` |
| Wing 3 pad | `Wings = 2` and `Guards >= 1` |
| Wing 4 pad | `Wings = 3` |
| Guard 1 | spawned while `Wings >= 2` and `Guards < 1` |
| Guard 2 | spawned while `Wings = 4` and `Guards < 2` |
| Wing group *n* props | shown when `Wings >= n` |
| Achievement | `Wings = 4` and `Guards = 2` |

One function, `RefreshWorld()`, applies this table. Load, purchase, and guard kill all end
by calling it, so a restored session and a live one go through identical code — the state
after a reload cannot drift from the state after playing to the same point.

## 3. Device mapping

| Device | Count | Role |
|---|---|---|
| `conditional_button_device` | 5 | The wallet. Holds the Gold cost and consumes it. |
| `trigger_device` | 5 | The step-on pad the player actually touches. |
| `prop_manipulator_device` | 4 | One per wing group. `HideProps()` at start, `ShowProps()` on purchase. |
| `guard_spawner_device` | 2 | One per building. `Spawn()` on completion, `EliminatedEvent` to advance. |
| `accolades_device` | 2 | One Medium, awarded 6 times; one for the final achievement. |
| `item_granter_device` | 4 | Starting weapon; Gold denominations 100 / 10 / 1. |
| `billboard_device` | 5 | One per pad. World-space label naming what the pad buys. |
| `hud_message_device` | 1 | Guard defeated, achievement unlocked. |
| `player_spawner_device` | 1 | Already in the map. |

### Purchases are a pad plus a wallet

The pads are step-on, and the device that can hold and consume a Gold cost —
`conditional_button_device` — is interact-driven. They are paired instead of chosen between:

1. `trigger_device` on the floor signals `TriggeredEvent(agent)`.
2. Verse asks the paired conditional button `HasAllItems(agent)`.
3. If true, Verse calls `Activate(agent)`; the button consumes the Gold and signals
   `ActivatedEvent`.
4. `ActivatedEvent` applies the purchase and calls `RefreshWorld()`.

The conditional buttons are placed out of the playable area. Cost lives in the device's required-item count, mirrored in `wing_config.verse`
so the numbers are readable in one place.

> **Verify first (§8).** If `Activate()` turns out not to consume the required items, the
> pads become plain interact Conditional Buttons and the triggers are deleted. Same state
> machine, `ActivatedEvent` still the entry point — the loss is step-on, not the design.

### Income

The generator is a Verse loop, not a device timer: `Sleep(1.0)` then grant 20 Gold via the
100/10/1 granters, for as long as `Gen` is true. Keeping the clock in Verse means one place
decides the rate, and it is the same code path that restores a saved balance.

### Props

All four wing groups exist in the map from the start. Each `prop_manipulator_device` volume
covers exactly one group; `HideProps()` runs on start-up before the player can see anything,
`ShowProps()` on purchase. Nothing is instantiated at runtime, and the buildings stay
indestructible throughout.

The volumes must not overlap — a prop inside two volumes answers to both devices. Wings that
stack vertically are separated by volume height.

## 4. Interface

Two surfaces, built differently because they answer to different things: the pad labels are
in the world and follow a pad's state, the HUD is on screen and follows the player.

### Pad labels — devices

One `billboard_device` per pad, calling `SetText()` with the name and cost from
`wing_config.verse`. Text is set once at start-up rather than rebuilt, and the billboard is
enabled and disabled alongside its pad inside `RefreshWorld()` — a locked pad has no label,
which is what makes "visible means usable" true of the labels as well as the pads.

The label is the only reason `wing_config.verse` holds display names next to the costs: one
table produces both what a pad charges and what its sign says, so the two cannot disagree.

### HUD — Verse UI

Built in code with `player_ui` and the widget classes from
`/UnrealEngine.com/Temporary/UI`, not with a device — a device cannot show a number that
changes every second, and the achievements panel needs a button that opens something.

- **Gold counter** — a `text_block` in a corner, refreshed by the same loop that grants the
  income. **The counter is not a second source of truth**: it renders `State.Gold` after the
  grant, so it cannot drift from the wallet the purchase pads check.
- **Achievements button** — a button widget, always present, toggling the panel.
- **Achievements panel** — hidden by default; one row, the achievement's name and
  condition, rendered as earned or locked from `Wings = 4 and Guards = 2`. Derived from the
  same state as everything else, so it needs no save field of its own and cannot show
  earned for a run that is not finished.

The panel is built once and shown or hidden, not created and destroyed per open. It is one
row; rebuilding it per click adds a lifecycle to get wrong for no benefit.

`RefreshWorld()` ends by refreshing the HUD, so the panel and the world can never disagree.

## 5. Persistence

```verse
run_data := class<final><persistable>:
    Version:int = 1
    Gen:logic = false
    Wings:int = 0
    Guards:int = 0
    Gold:int = 0

var RunDataMap : weak_map(player, run_data) = map{}
```

Five integers-worth of state, no strings and no cumulative arrays — UEFN's persistence
budget rewards compact keys and punishes growth. `Version` is there because a persistable
type cannot be changed after publish; a new shape reads the old one through its version.

**A read that comes back empty must never be written back as defaults.** Verse gives one
signal here — reading the key either succeeds or fails — so "no save yet" and "the save did
not come back" are indistinguishable at the call site, and the rule has to be built out of
*when* writes happen rather than out of telling the two apart:

- **Read succeeds** → restore it.
- **Read fails** → hold defaults in memory and play on, but **write nothing until the
  player earns something**.

Start-up never writes. That is the whole guard: a session that opens on a failed read and
is closed without buying anything leaves the stored save exactly as it was.

Gold is restored by granting the saved amount through the 100/10/1 granters — greedy, at
most 25 calls for the largest balance the run can produce.

Saving happens on each purchase and each guard kill, not on a timer: those are the only
moments the state changes, and both are already the end of a code path that calls
`RefreshWorld()`.

## 6. Start-up order

Ordering matters more than anything else in this file: every rule below exists because the
opposite order is visibly wrong in-session.

1. Hide all four prop groups. **Before the player can see the map** — otherwise a returning
   player watches wings they already own blink out and back.
2. Disable both guard spawners, all five pads, and all five billboards.
3. Set every billboard's text from `wing_config.verse`. Static, done once.
4. Load `run_data` for the player.
5. Grant the starting weapon.
6. Restore Gold, or grant 100 on a first run.
7. Build the HUD and add it to the player's UI, panel hidden.
8. `RefreshWorld()` — shows owned wings, enables the reachable pad and its label, spawns a
   guard if the save sits on a gate, and fills in the counter and the panel.
9. Start the income loop if `Gen` is true.

Nothing may grant Gold before step 4 completes. The HUD is built before the first
`RefreshWorld()` because that call is what populates it — reversing them shows the player
an empty counter until the first purchase.

## 7. Verification

Each of these has a failure that only appears under that specific condition:

- **A gate cannot be skipped.** With `Wings = 2` and guard 1 alive, the Wing 3 pad does
  nothing.
- **Death costs nothing.** Die to a guard: Gold, wings, and the guard's remaining health
  survive the respawn.
- **The save survives a restart.** Buy two wings, leave the session, relaunch: two wings
  standing, the correct Gold, and the Wing 3 pad in the right state.
- **Reload on a gate.** Leave at `Wings = 2` with guard 1 alive; on return the guard is
  spawned again and Wing 3 stays locked.
- **The generator survives alone.** Buy only the generator and leave. On return it is owned
  and income resumes.
- **The counter tracks the wallet.** Watch it tick while the generator runs, then buy
  something: it drops by exactly the cost. A counter that only agrees at start-up is a
  second source of truth that has not diverged *yet*.
- **The panel reads locked until it does not.** Open it mid-run: locked. Open it after the
  second guard: earned. Reload a finished save and open it: still earned.
- **A locked pad has no label.** Wing 3's billboard is absent while guard 1 is alive.

## 8. To confirm in the editor

Open items whose answers change code that is not yet written. None blocks starting.

1. **Does `conditional_button_device.Activate(agent)` consume the required items?** The
   step-on pad depends on it. Fallback in §3.
2. **Does a disabled pad also stop being visible,** or does hiding it need the device's own
   visibility option?
3. **Gold grant granularity.** Whether `item_granter_device` can grant Gold in a configured
   quantity, or whether the 100/10/1 denominations are actually required.
4. **Guard time-to-kill** against the starting assault rifle, tuned to the ~15 seconds the
   calibration in [GDD.md](GDD.md) assumes.
5. **Does the HUD survive a respawn?** If widgets added to `player_ui` are dropped when the
   player is eliminated, the counter has to be re-added on respawn rather than only at
   start-up — and dying to a guard is a normal event here, not an edge case.
6. **Billboard legibility** — text size and facing, so a label is readable from where the
   player approaches its pad rather than only from on top of it.
