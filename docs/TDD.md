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
  Core/                           pure logic, never placed
    wing_config.verse             costs, income rate, pad labels, the nine tags. Constants only.
    save_data.verse               persistable class, the weak_map, guarded load/save.
  Devices/                        placed in the map
    tycoon_manager_device.verse   placed once. Start-up order and the state machine.
  UI/
    hud.verse                     widget construction and refresh. Renders state, owns none.
```

The folder is the module path segment, so the manager opens with
`using { /invaliddomain/SuperTycoon/Core }` and `using { /invaliddomain/SuperTycoon/UI }` —
which is also the dependency direction stated in one place: `Devices/` reads `Core/` and
`UI/`, and neither of those reads back.

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

### Live values and the snapshot

The manager holds `Gen`, `Wings`, `Guards` and `Gold` as four mutable fields, and those are
what every rule below reads and writes. `run_data` (§5) is the **format they are written out
in**, not where they live: it is constructed whole at each save and never mutated in place.
`Version` belongs to the snapshot alone.

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
| `trigger_device` | 5 | The step-on pad. `TriggeredEvent` is the only entry point to a purchase. |
| `billboard_device` | 5 | One per pad. World-space label naming what the pad buys. |
| `guard_spawner_device` | 2 | One per building. `Spawn()` on completion, `EliminatedEvent` to advance. |
| `accolades_device` | 2 | One Medium, awarded 6 times; one for the final achievement. |
| `hud_message_device` | 1 | Guard defeated, achievement unlocked. |
| `class_designer_device` | 1 | Holds the starting weapon in its Item List. Never called from Verse. |
| `player_spawner_device` | 1 | Already in the map. |

Seventeen devices. Everything the player watches appear or disappear — wings and pads
alike — is a tagged prop rather than a device.

### Gold is a number, not an inventory

`Gold` is an `int` living in the manager and nowhere else. No device holds a balance
and no device checks one: a purchase is a comparison and a subtraction, and the HUD counter
in §4 renders the same variable the pads test, so the two cannot disagree.

Being a number rather than an inventory is also what makes §7's *death costs nothing* true
for free. Elimination strips a player's items; it cannot touch a variable in the manager.
Dying to a guard is a normal event in this loop, not an edge case.

### Purchases

A pad is a bare `trigger_device`. It needs nothing else, because the cost is a number:

1. `trigger_device` on the floor signals `TriggeredEvent(agent)`.
2. Verse compares `Gold` against the cost in `wing_config.verse`.
3. If it covers, subtract, apply the purchase, save, and call `RefreshWorld()`.

A pad stepped on without the Gold does nothing at all — no partial state and no failure
branch beyond the comparison. Cost lives in `wing_config.verse` alone; no device carries a
number that could disagree with it.

### The starting weapon

The weapon sits in the `class_designer_device`'s Item List, and that class is the island's
default. The player spawns holding it and **respawns holding it** — the loadout is reapplied
by the class on every spawn, so the first death to a guard does not leave the player unarmed.
Class settings override island and team settings, so the loadout is decided in exactly one
place.

### Visibility is a tag

Everything that appears or disappears is a Creative prop carrying a Verse tag, and the
manager shows or hides it directly:

```verse
wing_props_1 := class(tag){}

for (Obj : FindCreativeObjectsWithTag(wing_props_1{}), Prop := creative_prop[Obj]):
    Prop.Hide()
```

| Tag | Covers | Shown when |
|---|---|---|
| `wing_props_1` | Mansion wing 1 | `Wings >= 1` |
| `wing_props_2` | Mansion wing 2 | `Wings >= 2` |
| `wing_props_3` | Observatory wing 3 | `Wings >= 3` |
| `wing_props_4` | Observatory wing 4 | `Wings >= 4` |
| `pad_generator` | Generator pad mesh | its pad is enabled |
| `pad_wing_1` | Wing 1 pad mesh | its pad is enabled |
| `pad_wing_2` | Wing 2 pad mesh | its pad is enabled |
| `pad_wing_3` | Wing 3 pad mesh | its pad is enabled |
| `pad_wing_4` | Wing 4 pad mesh | its pad is enabled |

Each tag is resolved **once at start-up** into a cached `[]creative_prop`; `RefreshWorld()`
iterates the cache rather than searching the world again on every purchase.

`creative_prop.Hide()` drops collision along with visibility, so a hidden wing is not an
invisible wall and a locked pad is not an invisible obstacle. A tag has no spatial extent
either, so wings that stack vertically need no separation from each other — membership is
declared per prop, in the Outliner, by selecting a group and tagging it once.

Wings and pads use the same mechanism, so there is one way to make something visible in this
project. All four wing groups exist in the map from the start, hidden before the player can
see anything and shown on purchase: nothing is instantiated at runtime, and the buildings
stay indestructible throughout.

### What the player sees at a pad

A pad is three things moving together: the `trigger_device` volume the player walks into,
the `billboard_device` naming what it buys, and its tagged pad prop. Locking is three
calls — disable the trigger, disable the billboard, hide the prop — and unlocking is their
opposites. `Disable()` stops a device responding without making it disappear (§8), so the
prop, not the device, is what carries "visible means usable".

### Income

The generator is a Verse loop, not a device timer: `Sleep(IncomeTickSeconds)` then
`set Gold += IncomePerTick`, for as long as `Gen` is true. One place decides the rate — both
constants come from `wing_config.verse` — and it is the same variable a saved balance is
restored into.

## 4. Interface

Two surfaces, built differently because they answer to different things: the pad labels are
in the world and follow a pad's state, the HUD is on screen and follows the player.

### Pad labels — devices

One `billboard_device` per pad, calling `SetText()` with the name and cost from
`wing_config.verse`. Both the text and the enabled state are set inside `RefreshWorld()`:
an available pad's billboard is enabled and carries its label, a locked pad's is disabled
and carries the empty string.

Blanking the text is not redundant with disabling. `Disable()` stops a device responding
without hiding it (§8), and a billboard's whole output is text — so the empty string is what
actually removes the label from the world, and disabling is what stops it costing anything.
Together they make "visible means usable" true of the labels as well as the pads.

The label is the only reason `wing_config.verse` holds display names next to the costs: one
table produces both what a pad charges and what its sign says, so the two cannot disagree.

### HUD — Verse UI

Built in code with `player_ui` and the widget classes from
`/UnrealEngine.com/Temporary/UI`, not with a device — a device cannot show a number that
changes every second.

- **Gold counter** — a `text_block` in a corner, refreshed by the same loop that adds the
  income. **The counter is not a second source of truth**: it renders `Gold`, the same
  variable the purchase pads test, so there is no other balance for it to drift from.
- **Achievement row** — always visible under the counter; the achievement's name and
  condition, rendered as earned or locked from `Wings = 4 and Guards = 2`. Derived from the
  same state as everything else, so it needs no save field of its own and cannot show
  earned for a run that is not finished.

**Nothing on the HUD is clickable, and that is a platform constraint, not a preference.**
A `player_ui_slot` declares its input handling as either `ui_input_mode.None` or
`ui_input_mode.All`, with nothing between them: `All` takes movement, camera and fire away
from the player for as long as the widget is attached. A permanently clickable control is
therefore a permanently unplayable match. The whole HUD is one canvas attached with `None`.

Anything clickable added later needs an opener that is not a click — an input trigger key or
a world interaction — and its canvas must be attached on open and removed on close.

`RefreshWorld()` ends by refreshing the HUD, so the readout and the world can never disagree.

### The HUD is re-attached on every spawn

The widget hierarchy is built once and kept, but attaching it is subscribed to the player's
spawn event, not done only at start-up: each spawn removes the canvas from `player_ui` and
adds it again. Removing first makes the call idempotent, so a spawn that did not drop the
widget does not end up with two counters stacked on each other.

This costs one subscription and removes the question of whether `player_ui` survives an
elimination. Dying to a guard happens in a normal run, and a player who respawns with no
Gold counter has lost the only readout of the currency the whole loop is about.

## 5. Persistence

```verse
run_data<public> := class<final><persistable>:
    Version<public>:int = 1
    Gen<public>:logic = false
    Wings<public>:int = 0
    Guards<public>:int = 0
    Gold<public>:int = 0

var RunDataMap : weak_map(player, run_data) = map{}
```

`RunDataMap` is internal to `Core/`: the record is reachable only through the load and save
functions beside it, and from nowhere else in the project.

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

Gold is restored by assignment — `set Gold = Loaded.Gold`. There is no inventory to
reconstruct, so a restored balance is exact at any size.

Saving happens on each purchase and each guard kill, not on a timer: those are the only
moments the state changes, and both are already the end of a code path that calls
`RefreshWorld()`.

## 6. Start-up order

Ordering matters more than anything else in this file: every rule below exists because the
opposite order is visibly wrong in-session.

1. Resolve all nine tags into cached `[]creative_prop` arrays.
2. Hide all four wing groups and all five pad props. **Before the player can see the map** —
   otherwise a returning player watches wings they already own blink out and back.
3. Disable both guard spawners, all five pad triggers, and all five billboards, and blank
   every billboard's text.
4. Load `run_data` for the player.
5. Set `Gold` from the save, or to `StartingGold` on a first run.
6. Build the HUD and subscribe re-attachment to the player's spawn event.
7. `RefreshWorld()` — shows owned wings, enables the reachable pad with its label and prop,
   spawns a guard if the save sits on a gate, and fills in the counter and the achievement row.
8. Start the income loop if `Gen` is true.

Nothing may touch `Gold` before step 4 completes. Step 1 precedes step 2 because
hiding iterates the caches. The HUD is built before the first `RefreshWorld()` because that
call is what populates it — reversing them shows the player an empty counter until the first
purchase.

Two things are deliberately absent. The starting weapon comes from the class (§3), not from
a start-up call, which is why it survives a respawn. Billboard labels are written by
`RefreshWorld()` rather than here (§4), so start-up only has to blank them.

## 7. Verification

Each of these has a failure that only appears under that specific condition:

- **A gate cannot be skipped.** With `Wings = 2` and guard 1 alive, the Wing 3 pad does
  nothing.
- **Death costs nothing.** Die to a guard: Gold, wings, the starting weapon, and the guard's
  remaining health survive the respawn.
- **The save survives a restart.** Buy two wings, leave the session, relaunch: two wings
  standing, the correct Gold, and the Wing 3 pad in the right state.
- **Reload on a gate.** Leave at `Wings = 2` with guard 1 alive; on return the guard is
  spawned again and Wing 3 stays locked.
- **The generator survives alone.** Buy only the generator and leave. On return it is owned
  and income resumes.
- **The counter tracks the balance.** Watch it tick while the generator runs, then buy
  something: it drops by exactly the cost. A counter that only agrees at start-up is a
  second source of truth that has not diverged *yet*.
- **The achievement row reads locked until it does not.** Locked mid-run; earned after the
  second guard; still earned after reloading a finished save.
- **The HUD never takes the controls.** From the first second the player can walk, turn the
  camera and fire, and no cursor is drawn over the game.
- **A locked pad is not there.** While guard 1 is alive, Wing 3's billboard, its pad mesh,
  and its trigger are all absent — and walking through where the pad was does nothing.
- **A hidden wing is not a wall.** Walk through the space an unbought wing will occupy: no
  collision until it is bought.
- **The HUD comes back.** Die to a guard and respawn: exactly one Gold counter, showing the
  balance the run was at.

### Calibration

Two numbers are set by measurement rather than by design, and both are read off a built
map rather than decided here:

- **Guard health**, set on `guard_spawner_device` so a guard falls in roughly 15 seconds to
  the starting assault rifle. [GDD.md](GDD.md) calibrates the two-minute loop around that
  figure, and income runs during the fight, so a guard that dies too fast shortens the run
  and one that takes too long makes the gate feel like a wall.
- **Billboard text size and facing**, so a label reads from where the player approaches its
  pad rather than only from on top of it.

## 8. Device behaviour this design rests on

Confirmed in the editor. Each one is load-bearing somewhere above.

- **`Disable()` does not hide a device.** A disabled device stops responding and stays
  visible; visibility is a separate editor property, not something Verse toggles. This is
  why a pad's visual is a tagged prop (§3) and why a locked billboard is blanked as well as
  disabled (§4).
- **`creative_prop` exposes `Hide()` and `Show()`,** and `Hide()` drops collision along with
  visibility — so hiding is total, and an unbought wing is not an invisible wall.
- **`class_designer_device` reapplies its Item List on every spawn** and overrides island
  and team inventory settings, which is what makes the starting weapon survive a death.
- **`conditional_button_device.Activate(agent)` consumes the required items.** An
  item-backed currency was therefore available; §3 keeps Gold as a number on other grounds.
- **`item_granter_device` grants a freely configured quantity,** but only with *On Grant
  Action* set to **Keep All** and *Grant Condition* to **Always** — otherwise a grant
  replaces the inventory instead of adding to it. No granter is placed in this build; the
  trap is recorded because any future one inherits it.
