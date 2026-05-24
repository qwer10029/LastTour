# Next-steps plan — bugs + doc-gap items

> Source: comparison of `游戏开发建议书.md`, `终末旅行 — 技术设计说明书（草稿）.md`, and current code.
> Each task carries a **difficulty** rating: **S** (≤30 min, single small file), **M** (~1–3h, one system), **L** (½–1 day, cross-system), **XL** (multi-day, new subsystem).
> Each task also flags a recommended implementer (**Opus** for design/cross-system, **DeepSeek** for localized mechanical edits).

---

## Tier 0 — Known bugs (do first)

### Bug 1: Resource scene — invisible barriers block the player
**Where:** [game/scripts/main.gd:1616-1620](../game/scripts/main.gd#L1616-L1620) `_is_foot_blocked_at`, [game/scripts/world_map_data.gd:529-543](../game/scripts/world_map_data.gd#L529-L543) `is_foot_tile_blocked`, [game/scripts/main.gd:1829-1869](../game/scripts/main.gd#L1829-L1869) `_draw_foot_background`.

**Likely root cause (hypothesis to verify):** The visual barriers are drawn per-tile using `district_rect.position + tile * FOOT_TILE_SIZE`, but the player has a body radius (set in [player.gd](../game/scripts/player.gd) — needs verification) and probes the *target* position via the blocked checker. Because the checker maps a single point to a tile, the player gets blocked when its **center** crosses into the tile, but the player's *visible sprite edge* still appears to be on a clear tile. To the user this looks like an invisible wall ½ tile away from the visible obstacle.

A secondary possibility: the foot view draws an extended interior area (`interior_margin = 80`) outside the district `rect`. Players see a walkable-looking floor outside the district rect but can't enter it because `_clamp_to_cell` clamps to `rect`. This also reads as an invisible wall.

**Plan:**
1. Open [player.gd](../game/scripts/player.gd), confirm whether collision uses a radius/offset; log player center vs. blocked tile center on collision.
2. **Fix A (½-tile mismatch):** in `_is_foot_blocked_at`, probe 4 corner points of the player AABB instead of just `world_pos`, OR shrink the visual barrier rect to match the player's collision footprint. Pick whichever feels right after seeing the actual offset.
3. **Fix B (walkable-looking exterior):** in `_draw_foot_background`, restrict the tiled floor to within `rect` (drop `interior_margin`), or draw the exterior in a clearly-different "out of bounds" shade.
4. Test: walk along every edge of every barrier; barriers should feel flush with collision.

**Difficulty:** **S–M** (S if it's just shrinking the draw rect; M if it requires touching player collision).
**Recommended:** DeepSeek (mechanical, well-scoped once root cause is confirmed).

---

### Bug 2: Night TD — enemy routes are simple and repetitive
**Where:** [game/scripts/night_td/night_td_controller.gd:210-336](../game/scripts/night_td/night_td_controller.gd) (`_spawn_from_spec`, `_build_runtime_path`, `_update_enemies`), [game/data/night_td/waves/night_wave_demo.json](../game/data/night_td/waves/night_wave_demo.json), [game/scripts/night_td/night_td_wave_design.gd](../game/scripts/night_td/night_td_wave_design.gd).

**Root cause:** Single wave JSON defines one route per spawn point; every enemy of the same wave replays identical waypoints. No per-enemy variation, no alternate routes, no rerouting around player-placed barriers (barriers only apply `slow_factor`, [night_td_controller.gd:296-302](../game/scripts/night_td/night_td_controller.gd#L296-L302)).

**Plan (incremental — pick as many as time allows):**
1. **Author 2–3 alternate routes in the JSON** for the same spawn area, then in `_resolve_spawn_cell` / `_build_runtime_path` pick one at random per enemy. Cheapest big win.
2. **Add waypoint jitter:** in `_build_runtime_path`, offset each waypoint by a small random `Vector2` (within ±¼ cell) so visually enemies don't overlap.
3. **Per-enemy speed jitter:** ±15% on `speed` in `_spawn_from_spec` so the pack spreads out.
4. **(Stretch) Real pathfinding around barriers:** when a barrier exists, recompute waypoints via A* on the field grid. This is a bigger change — gate it behind a flag.

**Difficulty:** **M** for steps 1–3 (data + small spawn/path edits). **L** if step 4 included.
**Recommended:** DeepSeek for steps 1–3; Opus if step 4 is in scope (touches `night_td_field` grid + adds pathfinder).

---

### Bug 3: Post-night losses don't match the bag
**Where:** [game/scripts/night_td/night_td_controller.gd:529-561](../game/scripts/night_td/night_td_controller.gd#L529-L561) `_build_result`, [game/scripts/main.gd:1352-1359](../game/scripts/main.gd#L1352-L1359) `_apply_night_result`.

**Root cause (confirmed):**
- [night_td_controller.gd:531](../game/scripts/night_td/night_td_controller.gd#L531):
  ```gdscript
  var inv_loss: int = maxi(_exploration_inventory - _exploration_inventory, 0)
  ```
  This is `x - x = 0` — `inventory_loss` is **always 0**. The result message line at L545-546 (`" 物资损耗 %d"`) therefore never appears.
- `_apply_night_result` (main.gd:1352) only applies `outcome`, `fuel_loss`, and `base_hp` — it **never touches `_backpack`**. Even if `inventory_loss` were correct, the bag wouldn't change.

So the player sees a result message that mentions nothing concrete, while the bag is untouched — yet the doc promised "车外物资被拖走" as a real night risk.

**Plan:**
1. In `_build_result`, compute real inventory loss based on outcome (e.g., `partial → 1–2 random non-evidence items`, `fail → 3–5`, `vehicle_destroyed → all non-evidence`). Sample item IDs from the *current* backpack so the report reflects what was actually taken.
   - Add a `inventory_loss_items: Dictionary` field (item_id → count) to the result alongside `inventory_loss: int`.
   - Track loss decisions inside the controller using the `_exploration_inventory` snapshot already passed in via `start_session` — but to know *which* items, you need the actual `InventoryData`. Two options:
     - **(a) Pass backpack to TD:** extend `start_td_session` to accept the `InventoryData` reference; compute losses inside the controller.
     - **(b) Decide in main.gd:** the controller emits an abstract "loss severity"; `_apply_night_result` decides which items to remove. Cleaner separation.
   - Recommend **(b)**: keeps TD decoupled from inventory implementation.
2. In `_apply_night_result`, based on `outcome`, remove items from `_backpack` and pass the actual losses to the summary text builder.
3. In `_build_run_summary_text` ([main.gd:988-1030](../game/scripts/main.gd#L988-L1030)), add a `物资损耗：<list>` line when the last night had losses (store last-night losses on `self`).
4. Show the same loss list on the night-result HUD so the player sees it immediately, not just at run-end.

**Difficulty:** **M** (~2h). Touches 2 files, one new piece of state, no architecture change.
**Recommended:** DeepSeek — well-scoped, the bug is identified to the line.

---

## Tier 1 — Doc commitments that are partly built but not wired together

### Task 4: Wire 三选一终局 end-to-end
**Status:** The pieces exist — [communication_terminal.gd](../game/scripts/ui/communication_terminal.gd), [run_ending_defs.gd](../game/scripts/run_ending_defs.gd), [ending_outcome_overlay.gd](../game/scripts/ui/ending_outcome_overlay.gd), `MetaManager.management_rights_transferred`. [main.gd:905-967](../game/scripts/main.gd#L905-L967) shows the flow already calls them.

**What to do:**
1. Playtest the full chain: reach layer 3 (current top) → repair elevator → terminal opens → strike OR transfer → ceremony → three-choice modal → ending outcome → run summary. Find what's broken.
2. Confirm `RunEndingDefs.choice_title/summary` returns meaningful text for `stop_signal` / `message_only` / `fake_success`.
3. Add a credits scene for `stop_signal` (real ending). Currently `_on_final_ceremony_choice` only logs into Meta and shows the outcome overlay — the doc calls for "真结局·制作人员名单".
4. Confirm `MetaManager.evidence_count() >= EVIDENCE_THRESHOLD_FOR_TRANSFER` actually triggers the transfer branch, and that the threshold (3 per design doc) matches.

**Difficulty:** **M** (mostly integration testing + small fixes + a credits scene).
**Recommended:** Opus — needs judgment on what "polished enough" looks like for the emotional payoff scene.

---

### Task 5: 留言墙 (message wall)
**Status:** Not present. Doc highlights it as a key cross-run emotional beat: "将玩家的选择具象化为一个能被下一局读到的痕迹".

**Plan:**
1. In `MetaManager`, add `message_wall: Array` (each entry `{text, layer, day, choice_id, timestamp}`); persist to meta.json (already partly defined in [终末旅行 — 技术设计说明书（草稿）.md:599-614](../终末旅行%20—%20技术设计说明书（草稿）.md)).
2. In `_on_final_ceremony_choice` (or in the ceremony overlay), add an optional text-input step where the player writes a留言; append to `MetaManager.message_wall`; save meta.
3. Add a "前代勘探者留言墙" entry in the main menu ([main_menu.gd](../game/scripts/menu/main_menu.gd)) that scrolls through stored messages.

**Difficulty:** **M** (~3h: one data field, one save migration, one input UI, one viewer UI).
**Recommended:** DeepSeek — straightforward CRUD + small UI.

---

## Tier 2 — Doc gaps that change the game's feel substantially

### Task 6: Real `LayerElevatorSystem` and 5 layers (currently 3, no dedicated module)
**Plan:**
1. Extract layer/elevator logic from main.gd into `scripts/systems/layer_elevator_system.gd` with `LayerConfig` resources per layer (cost, threat table, color tint).
2. Add layers 4–5 with `LayerConfig.tres` files; vary `repair_cost`, enemy mix, color tint.
3. Apply layer tint to the foot/drive backgrounds via a single multiplier — cheapest way to deliver "层间视觉差异".

**Difficulty:** **L** (cross-file refactor + content).
**Recommended:** Opus.

---

### Task 7: 局间差异性 — procedural maps per layer
**Current state:** [world_map_data.gd:`generate`](../game/scripts/world_map_data.gd) generates a map but with bounded variety; districts/buildings/foot layouts use per-cell seeds but the macro layout is fixed-grid.
**Plan:** add a layer-level seed (from `run_id + layer_index`), vary district counts, junction patterns, elevator placement, and resource density per layer.

**Difficulty:** **L**.
**Recommended:** Opus (touches map structure and balancing).

---

### Task 8: Day combat — failure to deliver "白天抵御失控机械"
**Current state:** No `CombatSystem` exists. The pillar "白天搜集资源、抵御威胁" has the resource half but not the threat half.
**Plan:** Add a minimal patrol drone in foot/drive mode that damages the player or vehicle on contact; spawn 1–2 per district at higher layers. Reuse the night enemy templates.

**Difficulty:** **L** (new system, but can reuse night TD entity code).
**Recommended:** Opus.

---

### Task 9: Smart machine NPCs / EventDialogueSystem
**Status:** Doc spends significant space on this; no code yet.
**Plan:** Author a simple data-driven dialogue tree (JSON) + one NPC scene ("档案管理机") that gates one piece of evidence behind a trade. Defer the full NPC roster.

**Difficulty:** **L** (new system + content).
**Recommended:** Opus.

---

## Recommended sequencing

1. **Today:** Bug 3 (S–M, mechanical, immediate trust impact).
2. **Tomorrow:** Bug 1 + Bug 2 step 1 (data-only route variety).
3. **This week:** Task 4 (wire ending) + Task 5 (message wall) — together they make the game "feel finished" for a 28-day project.
4. **Next week (if time):** Task 6 (5 layers) + Task 7 (procedural). Skip 8/9 unless you have spare hands.

## Skip (per doc's MVP boundary)
- Five full分队 — 2 is enough.
- Multi-language, controller support, save-version migration polish — all called out as "暂不实现".
- Layer-by-layer unique art — modular tiles + tint suffice.
