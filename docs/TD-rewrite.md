# Night Tower-Defense — Rewrite spec

> Goal: turn the night phase from a "place towers, watch a deterministic animation" sequence into a
> reactive, micro-driven defense where enemies behave like a coordinated army (86 *Legion* under a
> shepherd), towers are built/recovered from real backpack resources, and the player keeps acting
> through combat (power routing + hacking).
>
> This follows the [plan_next_steps.md](plan_next_steps.md) convention. Each subtask carries a
> **difficulty** (**S** ≤30min/one small file · **M** ~1–3h/one system · **L** ½–1 day/cross-system ·
> **XL** multi-day/new subsystem) and a **recommended implementer** (**Opus** for design/cross-system
> judgement, **cheaper model** — DeepSeek/Sonnet-class — for localized mechanical edits once the
> contract is pinned). Difficulty is rated **per subtask** so cheap models can take the green ones
> even inside an Opus-led phase.
>
> **Verification gate:** every phase must leave the night scene runnable
> (`godot --headless --quit-after 2` compile-check, then a manual night run). Do not start phase N+1
> until phase N runs.

---

## Current state (what we are replacing)

- **No AI, no pathfinding.** Enemies replay hand-authored JSON waypoints
  ([night_wave_demo.json](../game/data/night_td/waves/night_wave_demo.json)); [`_update_enemies()`](../game/scripts/night_td/night_td_controller.gd#L303)
  walks waypoints then beelines the vehicle. Towers are never targeted — only the base is.
- **Fake economy.** Placement spends an abstract `td_base_deploy + day*3` budget
  ([`_compute_deploy_budget()`](../game/scripts/night_td/night_td_controller.gd#L139)),
  disconnected from the backpack. [`_on_cell_clicked()`](../game/scripts/night_td/night_td_controller.gd#L430)
  checks that budget, not inventory.
- **No combat-time agency.** After "start wave", [`_process_combat()`](../game/scripts/night_td/night_td_controller.gd#L173)
  runs autonomously; the player only watches. Result is a coarse HP-ratio bucket
  ([`_build_result()`](../game/scripts/night_td/night_td_controller.gd#L565)) → random item loss in
  [main.gd `_apply_night_result`](../game/scripts/main.gd#L1536).
- **Everything hardcoded.** 3 towers / 4 enemies live in
  [night_td_defs.gd](../game/scripts/night_td/night_td_defs.gd).

### Target architecture (new files)

| File | Role |
|---|---|
| `game/data/night_td/tower_defs.json` + `enemy_defs.json` + `energy.json` | data-driven defs (replace hardcoded) |
| `game/scripts/night_td/night_td_defs.gd` | thin loader over the JSON above (keep class name) |
| `game/scripts/night_td/night_td_flowfield.gd` | Dijkstra integration field → per-cell gradient; sample O(1) |
| `game/scripts/night_td/night_td_influence.gd` | tower threat field; feeds danger weight into the flow field |
| `game/scripts/night_td/night_td_commander.gd` | utility-AI "shepherd": groups, assigns flow fields, HTN-lite tactics |
| `game/scripts/night_td/night_td_energy.gd` | reactor production/cap + per-tower power allocation |
| `game/scripts/night_td/night_td_hacking.gd` | hack-tower target assignment + conversion state machine |
| `game/scripts/night_td/night_td_controller.gd` | orchestrates the above (slimmed; logic moves out) |

**Pathfinding decision: flow field, not A\*.** The night is many units → one base. A flow field computes
one shared integration field per frame-budget and every unit samples it O(1); A\* would re-search per
unit on every influence change. Critically, **threat-avoidance and pathing collapse into one pass**:
integration cost = `move_cost + danger_weight × influence`, so "avoid the turret's range" emerges from
the same Dijkstra. Power changes (hacking pulls energy from a tower → its threat drops) re-cost the
*cheap shared field* and the whole swarm flows through the new gap — the Legion "found a breach" feel,
cheaper and more coordinated than per-unit A\*. Trade-off: same-field units clump into a line; fixed
with separation steering + per-unit jitter + commander grouping. A\* is kept only as an optional
single-unit fallback; **AStarGrid2D is not used for the swarm.**

---

## Phase P0 — Data foundation (move defs to JSON)

*Pure refactor, no behavior change. Unblocks everyone; do first. Verifies the loader before any AI lands on top.*

### P0.1 — Author `tower_defs.json` / `enemy_defs.json` / `energy.json`
Mirror current [night_td_defs.gd](../game/scripts/night_td/night_td_defs.gd) values into JSON. Add
forward-looking fields now (even if unused): tower `build_cost: {parts, scrap, ...}`, `salvage: {...}`,
`power_curve` (dmg/firerate vs power), `is_hack_tower`; enemy `hack_resist`, `is_shepherd`, `armor`.
**Difficulty:** **S** · **Recommended:** cheaper model (transcription from existing dict literals).

### P0.2 — Rewrite `night_td_defs.gd` as a cached JSON loader
Keep `class_name NightTdDefs` and the existing static getters (`get_tower_def`, `get_enemy_def`,
`get_tower_button_text`) so callers don't change. Load+cache like
[item_defs.gd](../game/scripts/items/item_defs.gd) does. Fallback to a built-in dict if the JSON is missing.
**Difficulty:** **S–M** · **Recommended:** cheaper model (item_defs.gd is a direct template).

### P0.3 — Compile-check + night smoke test
Confirm towers still place/fire/draw identically with the data now coming from JSON.
**Difficulty:** **S** · **Recommended:** cheaper model.

---

## Phase P1 — Programmatic battlefield + flow-field pathing

*Delete hand-authored routes. Enemies flow toward the base around solid obstacles. This is the spine
the rest of the AI hangs on, so Opus owns the field math; the data deletion around it is cheap.*

### P1.1 — `night_td_flowfield.gd`: Dijkstra integration field + gradient
Multi-source Dijkstra from the vehicle cells over the grid; cost field → per-cell gradient vector
(8-neighbour). Public API: `rebuild(cost_grid, goal_cells)`, `sample_dir(cell) -> Vector2`,
`is_reachable(cell)`. Treat barrier/solid cells as impassable. Keep it pure (no node refs) so it's testable.
**Difficulty:** **L** · **Recommended:** Opus (core algorithm + perf budget; must be correct).

### P1.2 — Drive enemies with the field
Replace waypoint walking in [`_update_enemies()`](../game/scripts/night_td/night_td_controller.gd#L303)
with `sample_dir(current_cell)` steering. Add separation (push apart same-cell neighbours) + ±15% speed
jitter + small per-unit heading noise so the swarm spreads instead of single-filing.
**Difficulty:** **M** · **Recommended:** Opus (couples to field; steering feel needs judgement).

### P1.3 — Field rebuild triggers + cadence
Rebuild on: tower placed/removed (P6), barrier added, hack conversion, power change (P4). Throttle to a
max rebuild rate (e.g. ≤1/frame, dirty-flag coalesced) to protect the frame budget.
**Difficulty:** **M** · **Recommended:** Opus.

### P1.4 — Retire hand-authored routes
Drop route/waypoint consumption from [wave scheduler](../game/scripts/night_td/night_td_wave_scheduler.gd)
and [wave plan](../game/scripts/night_td/night_td_wave_design.gd); waves now specify only *what/when/where-spawned*,
not *which path*. Keep spawn points. Update [night_wave_demo.json](../game/data/night_td/waves/night_wave_demo.json)
to the trimmed schema.
**Difficulty:** **M** · **Recommended:** cheaper model (deletion + schema trim, once P1.2 defines the contract).

### P1.5 — Field debug overlay
Draw gradient arrows / cost heatmap behind the existing route-overlay toggle, replacing the now-dead red
route lines in [night_td_field.gd `_draw`](../game/scripts/night_td/night_td_field.gd#L161).
**Difficulty:** **S–M** · **Recommended:** cheaper model.

---

## Phase P2 — Influence map → danger-weighted pathing

*Make enemies actively avoid turret fire by folding a threat field into the flow-field cost. "Difficulty"
becomes the danger weight + commander cleverness (P3).*

### P2.1 — `night_td_influence.gd`: tower threat field
Per cell, sum `Σ tower_threat(dist)` for towers whose range covers it (Gaussian/linear falloff from
`range`,`damage`,`fire_interval`, scaled by current power from P4). API: `rebuild(towers)`,
`value(cell) -> float`, `total_threat()`.
**Difficulty:** **M** · **Recommended:** Opus (defines the threat model the whole AI reacts to).

### P2.2 — Fold danger into the integration cost
P1.1 cost becomes `base_move + danger_weight × influence(cell)`. `danger_weight = 0` on Easy (ignore
fire, current behavior) up to high on Hard (route around kill-zones). Single field rebuild covers both
pathing and avoidance.
**Difficulty:** **S–M** · **Recommended:** Opus (one formula, but it's the difficulty lever).

### P2.3 — Difficulty tiers wired to weight + recompute rate
Easy: `weight≈0`, slow/coarse recompute. Hard: high weight, frequent recompute → reacts to power
re-routing within a beat. Pull constants from `energy.json`/a new `night_td/difficulty.json`.
**Difficulty:** **S** · **Recommended:** cheaper model (constants table).

---

## Phase P3 — Commander (shepherd) AI: grouping + tactics

*The "Legion under a shepherd" behavior: concentrate force, feint, focus-fire towers one by one. Highest
design-judgement phase — Opus throughout.*

### P3.1 — `night_td_commander.gd`: utility scorer + group model
Partition spawned units into groups (assault / feint / reserve). Each group gets its own flow-field goal
(a tower to break, a staging cell, or the base). Utility inputs: group size, target tower HP/threat,
breach openings (low-influence corridors from P2). Re-score on a fixed tick.
**Difficulty:** **L** · **Recommended:** Opus.

### P3.2 — Multi-field goals (break towers, not just base)
Generalize the flow field to arbitrary goal cells so a group can target a specific tower. Enemies must be
able to *damage towers* now — add tower-as-target to [`_update_enemies`](../game/scripts/night_td/night_td_controller.gd#L303)
melee/attack (currently only the base takes damage). Reuse [`_damage_tower`](../game/scripts/night_td/night_td_controller.gd#L424).
**Difficulty:** **L** · **Recommended:** Opus (new damage path + flow generalization).

### P3.3 — HTN-lite tactic sequencing
Ordered tactics: `stage → mass up → coordinated push → exploit breach`. A group holds at a staging field
until size threshold, then commits. Differentiate difficulty by which tactics unlock (Easy = base rush
only; Hard = staging + feints + focus-fire).
**Difficulty:** **L** · **Recommended:** Opus.

### P3.4 — Commander debug HUD + log lines
Surface group intents ("3群集结于 D5,目标:信标#2") in the existing log panel so behavior is legible while tuning.
**Difficulty:** **S** · **Recommended:** cheaper model.

---

## Phase P4 — Energy economy + live power routing

*First combat-time agency: one shared energy pool from the base reactor; player throttles per-tower power.
No farming — energy comes only from the reactor, making allocation a real constraint.*

### P4.1 — `night_td_energy.gd`: reactor pool
`production_rate`, `capacity`, `current`. Energy accrues over combat; allocations drain it. Powered towers
consume `upkeep × power_level`. **Energy is reactor-only** — kills/hacks do not produce energy (recycling
moved to P6 end-of-night).
**Difficulty:** **M** · **Recommended:** Opus (defines the economy constraint).

### P4.2 — Power-curve on tower stats
Tower `damage`/`fire_interval` scale with assigned power via `power_curve` (P0.1). 0 power = idle (and its
P2 influence drops → enemies flow back in). Hook into [`_update_towers`](../game/scripts/night_td/night_td_controller.gd#L376).
**Difficulty:** **M** · **Recommended:** Opus (couples energy ↔ influence ↔ pathing — the system's heart).

### P4.3 — Combat-time power UI
Per-tower power slider/stepper usable *during* combat (current HUD locks all tools in
[`set_combat_mode`](../game/scripts/night_td/night_td_hud.gd#L144)). Show pool current/cap + draw.
Select a tower on the field → adjust its power.
**Difficulty:** **M** · **Recommended:** Opus (new interactive combat HUD; cheaper model can do the slider widget once layout is set → split as P4.3a widget = cheap).

### P4.4 — Re-cost flow field on power change
Wire P4.2 power deltas to the P1.3 rebuild trigger so the swarm visibly responds to power routing.
**Difficulty:** **S** · **Recommended:** cheaper model (one signal hookup).

---

## Phase P5 — Hacking towers + player-assigned targets + shepherd units

*Second combat-time agency: player picks a hack tower, then picks an enemy to convert. Manage multiple
hack towers, re-assign as the fight shifts.*

### P5.1 — `night_td_hacking.gd`: conversion state machine
Per hack tower: `target_enemy`, `progress`, drains energy (P4) while channeling; cost scales by enemy
`hack_resist`/type. On complete → enemy flips to player side, attacks other machines or retreats.
Shielded/high-resist enemies on higher difficulty.
**Difficulty:** **L** · **Recommended:** Opus.

### P5.2 — Player target assignment UI
Click hack tower → click enemy = assign. Show channeling beam + progress. Allow re-assign mid-channel.
This is the core micro. Extends the P4.3 combat HUD/selection.
**Difficulty:** **M** · **Recommended:** Opus (interaction design); widget pieces → cheaper model.

### P5.3 — Converted-ally behavior
Flipped units get a "defend" flow-field goal (intercept nearest hostile) or "retreat" command. They count
as friendly to towers and to the commander's threat assessment.
**Difficulty:** **M** · **Recommended:** Opus.

### P5.4 — Shepherd (commander) units as high-value hack targets
Add `is_shepherd` enemy type: while alive it boosts the P3 commander; hacking/killing it temporarily
degrades enemy AI (drops to base-rush for a window). The marquee hacking payoff.
**Difficulty:** **M** · **Recommended:** Opus (ties hacking ↔ commander).

---

## Phase P6 — Resource loop: build from backpack + end-of-night salvage

*Close the day↔night economy. Replace the fake deploy-point budget with real parts/scrap. Recovery is
resolved AFTER the battle, per your call.*

### P6.1 — Build towers from backpack resources
Replace `backpack_remaining`/`_compute_deploy_budget` with real inventory checks against `build_cost`
(P0.1). `start_session` receives the `InventoryData` ref (option (a) from the original plan-doc Bug 3
note) or a cost-callback. Placement in [`_on_cell_clicked`](../game/scripts/night_td/night_td_controller.gd#L430)
consumes parts/scrap; placement-phase right-click cancel refunds full cost (already structured at
[`_remove_tower_at_cell`](../game/scripts/night_td/night_td_controller.gd#L475)).
**Difficulty:** **M** · **Recommended:** Opus (touches the day/night boundary + save state); the inventory
check itself → cheaper model once the ref-passing contract is set.

### P6.2 — End-of-night salvage settlement
At night end (in [`_build_result`](../game/scripts/night_td/night_td_controller.gd#L565)): surviving
towers refund full `build_cost`; destroyed towers yield reduced `salvage` scrap; killed/hacked enemies
accumulate a scrap drop tally settled here (not mid-combat). Emit a `salvage: {item_id: count}` dict in
the result.
**Difficulty:** **M** · **Recommended:** Opus.

### P6.3 — Apply salvage + real losses to the backpack
[`_apply_night_result`](../game/scripts/main.gd#L1536) currently never touches `_backpack`. Add: credit
`salvage` items, and (fixing plan-doc Bug 3) debit real breach losses computed from the actual bag. Show
both in the night-result HUD and the run summary.
**Difficulty:** **M** · **Recommended:** cheaper model (well-scoped CRUD on `_backpack`; mirrors plan-doc Bug 3 fix).

### P6.4 — Build/salvage economy tuning pass
Set `build_cost`/`salvage` so a night is net-affordable but lossy — towers should feel like spent
resources, not free. Balance against [item_defs.json `repair_costs`](../game/data/item_defs.json) so
building doesn't starve elevator repair.
**Difficulty:** **M** · **Recommended:** Opus (balance judgement across day+night sinks).

---

## Phase P7 — Type variety, balance, polish

*Breadth + feel, after the systems are proven.*

### P7.1 — Tower roster
Beyond jammer/barrier/trap: e.g. slow-field, splash, long-range sniper, and the P5 hack-tower. Add as JSON
entries + draw cases in [night_td_field `_draw_placed_towers`](../game/scripts/night_td/night_td_field.gd#L387).
**Difficulty:** **M** · **Recommended:** cheaper model (data + draw cases; mechanics reuse P2/P4 hooks).

### P7.2 — Enemy roster
Armored, shielded (hack-resistant), fast swarm, the shepherd (P5.4), and a tower-killer. JSON + behavior
flags only.
**Difficulty:** **M** · **Recommended:** cheaper model.

### P7.3 — Variable battlefield size / layout per layer
Let grid_cols/rows + reactor position vary by layer (ties to plan-doc Task 6/7). Flow field already
handles arbitrary grids.
**Difficulty:** **M** · **Recommended:** Opus (layer coupling).

### P7.4 — HUD / draw / log polish
Power UI readability, hack beams, threat-heatmap toggle, commander intent log, salvage summary panel.
**Difficulty:** **M** · **Recommended:** cheaper model.

### P7.5 — Difficulty-mode final tuning
End-to-end pass on Easy/Normal/Hard: danger weight, commander tactic unlocks, hack resist, reactor rate,
enemy counts.
**Difficulty:** **M** · **Recommended:** Opus.

---

## Recommended sequencing

1. **P0** (cheap, fast) — unblocks data-driven everything.
2. **P1 → P2** (Opus-led) — the field is the spine; nothing reactive works without it.
3. **P3** (Opus) — the headline "intelligent army" behavior.
4. **P4 → P5** (Opus) — combat-time agency; P4 must land before P5 (hacking spends energy).
5. **P6** (mixed) — economy closure; can start P6.1 in parallel once P0 is done if a second pair of hands exists.
6. **P7** (mostly cheap) — breadth + polish last, on proven systems.

**Critical path (Opus):** P1.1 → P1.2/1.3 → P2.1/2.2 → P3.x → P4.1/4.2 → P5.1.
**Parallelizable on cheaper models:** P0.\*, P1.4/1.5, P2.3, P3.4, P4.4, P6.3, P7.1/7.2/7.4.

## Skip / defer (scope guard)

- A\* swarm pathfinding — flow field supersedes it; keep A\* only if a single boss-unit ever needs bespoke routing.
- Mid-combat energy *farming* from kills — explicitly rejected; reactor-only keeps allocation tense.
- Per-tower upgrade trees — out of scope; power routing (P4) is the depth lever instead.
- Full hack tech-tree / multi-stage shields — one resist stat (P5.1) is enough for MVP.
