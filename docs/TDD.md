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
    wing_config.verse             costs, income rate, pad labels, the five pad tags. Constants only.
    save_data.verse               persistable class, the weak_map, guarded load/save.
  Devices/                        placed in the map
    tycoon_manager_device.verse   placed once. Start-up order and the state machine.
  UI/
    hud.verse                     widget construction and refresh. Renders state, owns none.
  Assets/                         textures the HUD draws, and the start-up fade sequence.
  CustomProps/                    the pad and button meshes placed as the purchase pads.
```

The folder is the module path segment, so the manager opens with
`using { /invaliddomain/SuperTycoon/Core }` and `using { /invaliddomain/SuperTycoon/UI }` —
which is also the dependency direction stated in one place: `Devices/` reads `Core/` and
`UI/`, `UI/` reads `Assets/` for its textures, and none reads back.

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

`Guards` counts **guards cleared** — progression. Whether a guard is currently alive is
runtime state; it gets rebuilt on load.

### Live values and the snapshot

The manager holds `Gen`, `Wings`, `Guards` and `Gold` as four mutable fields, and those are
what every rule below reads and writes. `run_data` (§5) is the **format they are written out
in**, not where they live: it is constructed whole at each save and never mutated in place.
`Version` belongs to the snapshot alone.

### Derived gating

Everything visible on the map is a function of those values, recomputed after every event —
never toggled ad hoc:

| Element | Enabled when |
|---|---|
| Generator pad | `Gen = false` |
| Wing 1 pad | `Gen = true` and `Wings = 0` |
| Wing 2 pad | `Gen = true` and `Wings = 1` |
| Wing 3 pad | `Gen = true` and `Wings = 2` and `Guards >= 1` |
| Wing 4 pad | `Gen = true` and `Wings = 3` |
| Guard 1 | spawned when `Wings = 2` and `Guards = 0` |
| Guard 2 | spawned when `Wings = 4` and `Guards = 1` |
| Generator props | shown when `Gen = true` |
| Wing group *n* props | shown when `Wings >= n` |
| Achievement | `Wings = 4` and `Guards = 2` |

Every wing pad tests `Gen` as well as its own step. The generator is the first purchase and
nothing else is reachable before it, so the test is redundant in a played-through run — it
is there for the restored one: a save that somehow arrives with wings and no generator
opens no pad, instead of one whose income can never start.

One function, `RefreshWorld()`, applies this table. Load, purchase, and guard kill all end
by calling it, so a restored session and a live one go through identical code — the state
after a reload cannot drift from the state after playing to the same point.

### Spawning a guard is not idempotent

`RefreshWorld()` can run many times at a state that satisfies a guard's condition, and
`Spawn()` called twice puts two guards in the map. `HighestGuardSpawned` — the highest guard
index this session has spawned, held beside the saved values and never written to the save —
is the extra term in both guard rows. Guard *n* spawns only while the counter is below *n*,
and spawning it sets the counter to *n*:

| Guard | Spawns while | Then sets |
|---|---|---|
| 1 | `Wings = 2` and `Guards = 0` and `HighestGuardSpawned < 1` | `HighestGuardSpawned = 1` |
| 2 | `Wings = 4` and `Guards = 1` and `HighestGuardSpawned < 2` | `HighestGuardSpawned = 2` |

Testing and setting **the row's own index**, instead of a shared count incremented by
each spawn, is what lets a reload land past guard 1 and still spawn guard 2 exactly once
(§7).

## 3. Device mapping

**Driven from Verse** — the manager holds each of these as an `@editable` and calls it:

| Device | Count | Role |
|---|---|---|
| `trigger_device` | 5 | The step-on pad. `TriggeredEvent` is the only entry point to a purchase. |
| `billboard_device` | 5 | One per pad. World-space label naming what the pad buys. |
| `guard_spawner_device` | 2 | One per building. `Spawn()` on completion, `EliminatedEvent` to advance. |
| `accolades_device` | 2 | One Medium, awarded 7 times — the generator, four wings, two guards. One Very Large, awarded once for the achievement. |
| `hud_message_device` | 1 | Guard defeated, achievement unlocked. |
| `prop_manipulator_device` | 5 | One per wing group, one for the generator. `ShowProps()` / `HideProps()`. |
| `player_spawner_device` | 1 | `SpawnedEvent` starts the run and refreshes the HUD. |

**Configured in the editor, never called from Verse** — they set the frame the run plays
inside, and none of them has a state that progression can change:

| Device | Count | Role |
|---|---|---|
| `class_designer_device` | 1 | Holds the starting weapon — an automatic assault rifle — in its Item List; the island's default class. |
| `hud_controller_device` | 1 | Hides the build menu from Fortnite's own HUD. |
| `cinematic_sequence_device` | 1 | Autoplays the start-up fade; hides the HUD and takes input for its length. |
| `day_sequence_device` | 1 | Pins the time of day, globally, to one fixed hour. |
| `barrier_device` | 1 | Closes the play area off at its edge. |

Twenty-six devices, plus the manager itself and the island settings.

Nothing in the second table is subscribed, enabled, or read. A device the manager never
touches cannot desynchronise from the state (§2) — which is why the presentation layer is
allowed to be editor-configured while everything progression can move stays in Verse.

### Gold is a number, not an inventory

`Gold` is an `int` living in the manager and nowhere else. No device holds a balance
and no device checks one: a purchase is a comparison and a subtraction, and the HUD counter
in §4 renders the same variable the pads test, so the two cannot disagree.

Being a number, not an inventory, is also what makes §7's *death costs nothing* true for
free. Elimination strips a player's items; it cannot touch a variable in the manager. Dying
to a guard is a normal event in this loop.

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

### Visibility: tags for pads, manipulators for buildings

Everything that appears or disappears already exists in the map and is hidden — nothing is
instantiated at runtime, which is also why the buildings stay indestructible throughout.
Two mechanisms make it appear, split by how big the group is.

**Pads are tagged props.** A pad mesh is one prop, or a few, that the manager holds
directly:

```verse
pad_wing_1<public> := class(tag){}

PropsWithTag(TagType : castable_subtype(tag)) : []creative_prop =
    for (Obj : Self.FindCreativeObjectsWithTag(TagType), Prop := creative_prop[Obj]):
        Prop
```

| Tag | Covers | Shown when |
|---|---|---|
| `pad_generator` | Generator pad mesh | its pad is enabled |
| `pad_wing_1` | Wing 1 pad mesh | its pad is enabled |
| `pad_wing_2` | Wing 2 pad mesh | its pad is enabled |
| `pad_wing_3` | Wing 3 pad mesh | its pad is enabled |
| `pad_wing_4` | Wing 4 pad mesh | its pad is enabled |

Each tag is resolved **once at start-up** into a cached `[]creative_prop`; `RefreshWorld()`
iterates the cache instead of searching the world again on every purchase.
`creative_prop.Hide()` drops collision along with visibility, so a locked pad leaves no
obstacle behind.

**Buildings are `prop_manipulator_device`s.** One per wing group and one for the generator,
each with **Affects All Objects In a Zone** on and **Start Hidden** on, its volume enclosing
one group, shown and hidden with a single `ShowProps()` / `HideProps()` call.

A wing is a whole building — roughly 160 Epic gallery props, not a single mesh — and the
zone is what makes that one call. Membership is **spatial**: whatever falls inside the box
belongs to the group. The manager never holds an array whose size is a modelling decision;
adding a prop to a wing is placing it inside the box, not tagging it and hoping the tag was
not missed.

The cost of spatial membership is that the boxes are load-bearing geometry. A zone that
falls short leaves props standing, or invisible and still solid; a zone that overreaches
reveals a neighbour's. **The generator is the sharpest case:** its pad and its build occupy
the same spot and move in *opposite* directions inside a single `RefreshWorld()` call — the
pad hides as the build appears — so the build's zone must exclude the pad, or the pad
returns with the purchase that paid for it.

| Manipulator | Covers | Shown when |
|---|---|---|
| Wing manipulator 1 | Mansion wing 1 | `Wings >= 1` |
| Wing manipulator 2 | Mansion wing 2 | `Wings >= 2` |
| Wing manipulator 3 | Observatory wing 3 | `Wings >= 3` |
| Wing manipulator 4 | Observatory wing 4 | `Wings >= 4` |
| Generator manipulator | The generator machine | `Gen = true` |

Wings that stack vertically therefore need their zones separated in height, not just in
plan. That a hidden wing also loses its collision is checked in §7, not assumed.

### What the player sees at a pad

A pad is three things moving together: the `trigger_device` volume the player walks into,
the `billboard_device` naming what it buys, and its tagged pad prop. Locking is three
calls — disable the trigger, hide the billboard's text, hide the prop — and unlocking is
their opposites. `Disable()` stops a device responding without making it disappear (§8), so
the prop, not the trigger, is what carries "visible means usable".

### Income

The generator is a Verse loop: `Sleep(IncomeTickSeconds)` then `set Gold += IncomePerTick`,
no device timer involved. One place decides the rate — both constants come from
`wing_config.verse` — and it is the same variable a saved balance is restored into.

The loop is spawned exactly once, at whichever moment `Gen` first becomes true: the
generator purchase in a live run, or step 10 of start-up (§6) in a restored one. It has no
exit condition because `Gen` never goes back to false, and no second one can start because
the only two spawn sites are mutually exclusive — a restored `Gen = true` closes the
generator pad before it can be stepped on.

## 4. Interface

Two surfaces, built differently because they answer to different things: the pad labels are
in the world and follow a pad's state, the HUD is on screen and follows the player.

### Pad labels — devices

One `billboard_device` per pad, calling `SetText()` with the name and cost from
`wing_config.verse`. Both the text and its visibility are set inside `RefreshWorld()`: an
available pad's billboard is given its label and shown with `ShowText()`, a locked pad's is
set to the empty string and hidden with `HideText()`.

Blanking the text does separate work from hiding it. `HideText()` is what takes the label
out of the world; the empty string guarantees the device is never holding a stale line at
the moment it is shown again — a billboard's whole output is text, so a value set once and
left there outlives the state that set it. Together they make "visible means usable" true
of the labels as well as the pads.

Locking a label is the visibility pair alone. `Disable()` stops a device responding without
hiding it (§8), which buys nothing on a device whose only job is to display.

The label is the only reason `wing_config.verse` holds display names next to the costs: one
table produces both what a pad charges and what its sign says, so the two cannot disagree.

### HUD — Verse UI

Built in code with `player_ui` and the widget classes from
`/UnrealEngine.com/Temporary/UI`. A device cannot show a number that changes every second.

- **Gold counter** — a coin `texture_block` and a `text_block`, anchored to the left edge at
  mid-height, refreshed by the same loop that adds the income. **The counter is not a second
  source of truth**: it renders `Gold`, the same variable the purchase pads test, so there
  is no other balance for it to drift from.
- **Achievement badge** — anchored to the right edge at mid-height; an icon, the
  achievement's name, its condition, and a status line rendered as earned or locked from
  `Wings = 4 and Guards = 2`. Derived from the same state as everything else, so it needs no
  save field of its own and cannot show earned for a run that is not finished.

Both are the same widget shape: a `color_block` rim with a filled `color_block` inset over
it and the content padded on top, built by one `MakeBadge()` helper so the two agree by
construction, not by two sets of matching numbers. Gold and the achievement carry different
fill colours and nothing else different. The whole readout is one `canvas`, with each badge
in its own slot anchored to an edge, so the layout holds at any resolution.

The manager hands the HUD `Gold`, `Wings` and `Guards` on every refresh and the HUD decides
what to draw from them. It stores none of the three.

**Nothing on the HUD is clickable, and that is a platform constraint, not a preference.**
A `player_ui_slot` declares its input handling as either `ui_input_mode.None` or
`ui_input_mode.All`, with nothing between them: `All` takes movement, camera and fire away
from the player for as long as the widget is attached. A permanently clickable control is
therefore a permanently unplayable match. The whole HUD is one canvas attached with `None`.

Anything clickable added later needs a non-click opener — an input trigger key or a world
interaction — and its canvas must be attached on open and removed on close.

`RefreshWorld()` ends by refreshing the HUD, so the readout and the world can never disagree.

### The HUD is attached once and refreshed on every spawn

The widget hierarchy is built once at start-up and attached once. `Attach()` removes the
canvas from `player_ui` before adding it, so the call is idempotent — calling it again
cannot leave two counters stacked on each other.

The player spawner's `SpawnedEvent` is subscribed for the whole run, and what it does on
each spawn is refresh: push the current values back into the widgets. Dying to a guard is a
normal event in this loop, and a player who respawns must not be reading a balance from
before the fight.

Whether `player_ui` keeps the canvas across an elimination is the load-bearing assumption
here — a refresh writes into widgets that are still attached, and if a respawn drops them
the subscription would have to re-attach instead of refreshing. §7 checks it in-session
instead of the design assuming it.

### Status messages

Two messages share the single `hud_message_device` — *guard defeated* and *achievement
unlocked*. `SetText()` then `Show()` means the device holds whichever line was set last, so
two fired at once are not a queue. That happens once, on the second guard kill: *guard
defeated* is set first, *achievement unlocked* second, and the second is the one left
standing.

XP has no line here — the accolade device draws its own splash from its `Name` and
`Description` (§3).

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
signal here — reading the key succeeds or fails — so "no save yet" and "the save did not
come back" are indistinguishable at the call site, and the rule has to be built out of
*when* writes happen instead of out of telling the two apart:

- **Read succeeds** → restore it.
- **Read fails** → hold defaults in memory and play on, but **write nothing until the
  player earns something**.

A record whose `Version` is higher than this build's counts as a failed read: the load
rejects it rather than reading fields it cannot know the shape of.

Start-up never writes. That is the whole guard: a session that opens on a failed read and
is closed without buying anything leaves the stored save exactly as it was.

Gold is restored by assignment — `set Gold = Loaded.Gold`. There is no inventory to
reconstruct, so a restored balance is exact at any size.

Saving happens on each purchase and each guard kill, not on a timer: those are the only
moments the state changes, and both are already the end of a code path that calls
`RefreshWorld()`.

## 6. Start-up order

Ordering is the central concern of this file: every rule below exists because the opposite
order is visibly wrong in-session.

1. Resolve all five pad tags into cached `[]creative_prop` arrays.
2. Hide all four wing manipulators, the generator manipulator, and all five pad props.
   **Before the player can see the map** — otherwise a returning player watches wings they
   already own blink out and back.
3. Disable both guard spawners and all five pad triggers, and blank *and* hide all five
   billboards' text.
4. Take the player: the first one already in the playspace, or the first one the spawner
   reports if the map is not populated yet.
5. Load `run_data` for that player.
6. Set `Gold` from the save, or to `StartingGold` on a first run.
7. Build the HUD, attach it, and subscribe the spawn event to refresh it.
8. Subscribe every pad trigger and both guard spawners.
9. `RefreshWorld()` — shows owned wings and the generator, enables the reachable pad with
   its label and prop, spawns a guard if the save sits on a gate, and fills in the counter
   and the achievement badge.
10. Start the income loop if `Gen` is true.

Nothing may touch `Gold` before step 5 completes. Step 1 precedes step 2 because hiding
iterates the caches. Steps 2 and 3 run before the player is resolved, so an empty map is
already hidden and inert no matter how long the wait in step 4 lasts. The HUD is built
before the first `RefreshWorld()` because that call is what populates it — reversing them
shows the player an empty counter until the first purchase.

Two things are deliberately absent. The starting weapon comes from the class (§3), not from
a start-up call, which is why it survives a respawn. Billboard labels are written by
`RefreshWorld()` (§4), so start-up only has to blank and hide them.

The start-up fade is not a step. The cinematic device autoplays on its own and no Verse
call waits on it — it takes input and hides the native HUD for its length, covering the
same first moments this list spends hiding the map.

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
- **Reload on the second gate.** Leave at `Wings = 4` with guard 2 alive; on return the
  guard is spawned again, exactly once, and the achievement stays reachable. This is the
  load that lands *past* guard 1, so it is the one that proves `HighestGuardSpawned` (§2)
  is read as an index, not a count of spawns — a session that skips guard 1 must still
  spawn guard 2, and only once.
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

Two numbers are set by measurement, not by design, and both are read off a built map
instead of decided here:

- **Guard health**, set as `StartingHealth` / `Max Health` on `guard_spawner_device` so a
  guard armed with a DMR falls in roughly 15 seconds to the starting assault rifle.
  [GDD.md](GDD.md) calibrates the whole loop around that figure, and income runs during the
  fight — 15 seconds is ≈750 Gold, which is most of Wing 3's price. A guard that dies too
  fast leaves the player short at the gate it just opened; one that takes too long makes the
  gate feel like a wall.
- **Billboard text size and facing**, so a label reads from where the player approaches its
  pad, not only from on top of it.

## 8. Device behaviour this design rests on

Confirmed in the editor. Each one is load-bearing somewhere above.

- **`Disable()` does not hide a device.** A disabled device stops responding and stays
  visible; visibility is a separate editor property Verse cannot toggle. This is why a
  pad's visual is a tagged prop (§3), not the trigger itself.
- **`creative_prop` exposes `Hide()` and `Show()`,** and `Hide()` drops collision along with
  visibility — so hiding is total, and an unbought wing is not an invisible wall.
- **`creative_prop.Hide()` does not reach attached children.** Attachment propagates
  transform, not visibility, so hiding a group's anchor hides only the anchor — silently,
  with no log and no error, leaving the rest visible *and* the anchor invisible-but-solid.
  This is why a wing is a manipulator zone, not a tagged anchor (§3), and why every tag in
  the project sits on a single prop.
- **`billboard_device` shows and hides its own text** with `ShowText()` / `HideText()`,
  independently of `Enable()` / `Disable()` — which is what locks a label (§4).
- **`accolades_device` awards in total silence when misconfigured.** The on-screen splash is
  built from the device's `Name` and `Description`, so an empty pair draws nothing even
  though `Award()` fired correctly, and `Enabled During Phase` must cover gameplay or the
  device does not fire at all. `Award()` returns `void`, the device has no production event,
  and Verse cannot read XP — so **no code can observe whether an award landed**, and the two
  failures are indistinguishable from the code never running. A `Print` on the line before
  `Award()` is what splits them.
- **`prop_manipulator_device` exposes `ShowProps()` and `HideProps()`,** applying to every
  prop inside its zone — including Epic's read-only gallery `BuildingProp` actors, on groups
  of ~160, and dropping collision exactly as `creative_prop.Hide()` does. This is what lets a
  whole wing be one call (§3).
- **`class_designer_device` reapplies its Item List on every spawn** and overrides island
  and team inventory settings, which is what makes the starting weapon survive a death.
- **`conditional_button_device.Activate(agent)` consumes the required items.** An
  item-backed currency was therefore available; §3 keeps Gold as a number on other grounds.
- **`item_granter_device` grants a freely configured quantity,** but only with *On Grant
  Action* set to **Keep All** and *Grant Condition* to **Always** — otherwise a grant
  replaces the inventory instead of adding to it. No granter is placed in this build; the
  trap is recorded because any future one inherits it.
