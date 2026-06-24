# Final-week plan — bug fixes + 4 features

> Context: last week before submission. misaka (LEMyuemingxingxi) committed heavy night-TD
> changes on top of the TD rewrite; some regressed. qwer10029 / qwer10029a are both the user.
> Goal: fix all new regressions + land 4 features. Each task carries a **difficulty** (S/M/L/XL),
> an **owner** (which model/agent implements), and an **acceptance check**.
>
> **Model cost (user's data, units/M tokens):** codex-gpt5.5 ≈ 0.2 · haiku ≈ 0.2 · sonnet ≈ 0.6 · opus ≈ 1.0.
> **codex availability:** the `codex` CLI is NOT installed here, so I cannot spawn gpt5.5 as a
> subagent. Tasks marked `codex?` are self-contained enough that the user can hand the spec to
> codex manually; otherwise a Claude model is assigned.
>
> **Verify gate (every code task):** headless import must stay clean —
> `cd game && "$HOME/Downloads/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --editor --quit 2>&1 | grep -iE "SCRIPT ERROR|parse error"` → empty.

---

## Part A — Fix misaka's regressions (do first; small, unblock everything)

### A1 — Night grid centered under the right sidebar
**File:** `game/scripts/night_td/night_td_field.gd` (`_reflow_layout`, ~L75)
Grid is centered on `view_size * 0.5` but a 228px sidebar is reserved on the right → map slides
under the panel. Center on the **play-area** center (`_play_area_rect`) instead of the viewport
center. Re-check `right_reserved_px=216` / `top_reserved_px=80` against the actual panel rect.
**Difficulty:** S · **Owner:** sonnet (geometry, needs a screenshot sanity check) · **Check:** grid fully left of the sidebar at 1280×720 and 1920×1080.

### A2 — Power panel stays up / garbled orange bars during settlement
**File:** `game/scripts/night_td/night_td_hud.gd` (`show_result`, ~L549)
`show_result()` never hides the power panel or clears the looping amber highlight tweens →
they render over the settlement dialog. In `show_result()` call `show_power_panel(false)` +
`clear_power_highlight()`. Also call them from `hide_session_ui()` for safety.
**Difficulty:** S · **Owner:** haiku / `codex?` · **Check:** settlement screen shows no left-side panel or orange bars.

### A3 — Burn-fuel-for-power button permanently disabled
**Files:** `game/scripts/main.gd` (3 `start_td_session` call sites: ~L2473, ~L2536, ~L3185; also ~L3031)
Feature is fully built in controller+HUD but the call sites stop at `options` and never pass
`vehicle_fuel`/`vehicle_fuel_max`. Append `_fuel, fuel_max` to each call.
**Difficulty:** S · **Owner:** haiku / `codex?` · **Check:** in a night run with fuel >0, 应急供能 is enabled; pressing it burns fuel and adds +3/s reactor; settlement reports fuel spent.

### A4 — Directional waves + strip dead waypoint data
**Files:** `game/data/night_td/waves/*.json`
Two problems: (1) waves still spread across 3 fronts, defeating "concentrate threat to 1–2
sides"; (2) every wave file carries large `routes`/`waypoints`/`spawn_points`/`alternate_routes`
blocks that are **dead** — enemies move by flow field, only `spawn_side` is read. Rewrite each
wave to pin to 1–2 sides per wave (escalating across waves) and delete the dead blocks. Keep
`spawn_points` only if you want labelled spawn cells; otherwise drop. Update the scheduler to
stop forwarding `route_id`/`spawn_point`/`alternate_routes` once data is gone.
**Difficulty:** M · **Owner:** opus (design feel) drafts wave-1 demo + the pattern; sonnet applies
to the other 4 files · **Check:** each wave's enemies enter from ≤2 edges; import clean; a night run feels like a defendable front, not a swarm from everywhere.

### A5 — ESC/pause does not freeze night TD combat  *(this is feature #3)*
**Files:** `game/scripts/main.gd` (`_pause_game`/`_resume_from_pause`, ~L2755)
`_pause_game()` only pauses `time_system`; the TD controller's `_process` keeps running combat.
The controller already has `set_session_paused(bool)`. Wire it: in `_pause_game()` call
`night_defense._td.set_session_paused(true)` (guarded) when a night session is active; clear it
in `_resume_from_pause()`. Confirm the pause menu's CanvasLayer sits above the night HUD and
that input during pause can't place towers. Also confirm terminal-battle / boss sub-scenes honor
pause (they may run on their own nodes).
**Difficulty:** M · **Owner:** sonnet (cross-scene; must verify each night sub-mode) · **Check:** ESC during placement AND during combat halts spawns, enemy movement, the combat timer, and tower fire; resume continues cleanly.

---

## Part B — Feature 1: weapon-upgrade items → real tower upgrades

**Goal:** the story-reward items (`blueprint_pulse_tower`, `data_chip_radar_tower_mod`,
`composite_armor_panel`, `auto_turret_auth`) currently are `usable:false` flavor. Using one should
change real tower numbers and show the change.

**Design (persists across day↔night scenes via RunState):**
1. Add a `tower_upgrades: Dictionary` to `game/scripts/run_state.gd` (capture/restore + save dict),
   e.g. `{ "damage_mult": 1.0, "range_mult": 1.0, "tower_hp_mult": 1.0, "pulse_shield": false }`.
2. New data file `game/data/night_td/tower_upgrades.json` mapping each item_id → stat deltas +
   a player-facing `name`/`effect_text`. Single source of truth.
3. In `item_defs.json` flip those 4 items to `usable:true` (or add an "install" action distinct
   from "use" so they're not consumed like food). Decide: consumed-on-install (one-shot stat
   bump, stackable) vs. permanent toggle. **Recommend:** consumable stat bumps that accumulate
   (composite_armor_panel ×3 → +30% tower HP etc.), pulse_tower/turret_auth = one-time unlocks.
4. `main.gd._use_backpack_item`: on install, read the delta from the json, fold into
   `GameManager.run_state.tower_upgrades`, consume the item, toast a confirmation, refresh UI.
5. Night side: `night_td_controller` reads `run_state.tower_upgrades` at `start_session` and
   applies mults when building each tower (damage/range/hp) and gates `pulse_shield`/extra tower
   type on the unlock flags. `auto_turret_auth` → unlock/þdiscount the sniper(炮塔); `pulse_tower`
   → unlock splash/电弧 or a shield buff.
6. **Visibility:** (a) backpack/PDA install toast "雷达加固模块已写入：防御塔射程 +15%";
   (b) a small "防御塔强化" summary line in the night placement HUD showing active mults;
   (c) optional: tinted tower sprite or a ▲ badge when upgraded.

**Subtasks & owners:**
- B1 RunState field + save/load + tower_upgrades.json schema — **S/M, sonnet** (touches persistence; get it right once).
- B2 item_defs flip + `_use_backpack_item` install path + toast — **M, sonnet** (`codex?` for the mechanical json edit half).
- B3 controller applies mults at build + unlock gates — **M, opus** (balance + cross-system; this is the headline).
- B4 HUD "防御塔强化" indicator + install toast text — **S, haiku**.
**Check:** install radar mod in day → enter night → towers show +range, indicator lists the buff, numbers persist after a day/night round-trip and after save/load.

---

## Part C — Feature 2: night-TD tutorial scene

**Goal:** first-time players learn the night scene: place towers, view fire coverage (heatmap),
adjust power, burn fuel, hack enemies, read the directional threat. Use
`/home/l/Desktop/prepare_for_night.png` as the backdrop.

**Design:**
1. Import art → `game/assets/ui/tutorial/prepare_for_night.png` (+ .import).
2. New scene `game/scenes/tutorial/night_tutorial.tscn` + `night_tutorial.gd`: a CanvasLayer
   overlay with the backdrop, a stepped panel (Next/Skip), 5–7 cards each pointing at a real
   HUD region: 布防(place towers) → 火力覆盖(heatmap switch) → 电力调度(power +/−) →
   应急供能(burn fuel) → 入侵天线(hack) → 方向威胁(waves come from sides) → 开始波次.
3. Trigger: first time entering night setup. Persist "seen" in a settings/config file
   (`user://settings.cfg`) so it shows once; re-openable from the new Settings menu (Part E).
4. Keep it self-contained: static text + arrows/highlights over the existing HUD, OR a standalone
   illustrated walkthrough using the backdrop (simpler, no live-HUD coupling). **Recommend** the
   standalone illustrated version for robustness in the final week.

**Subtasks & owners:**
- C1 import image + scene skeleton + step framework — **M, sonnet**.
- C2 write the 6–7 tutorial card texts (zh) — **S, haiku** (`codex?`).
- C3 trigger + once-only persistence + hook into night entry — **M, sonnet** (touches main.gd/time flow).
- C4 art/layout polish over the backdrop — **S, haiku/sonnet**.
**Check:** new run → first night → tutorial appears once, Skip works, doesn't reappear next night, reachable from Settings.

---

## Part D — Feature 4: soundtrack wiring

**Status found:** `MusicManager` autoload is complete with cue slots already defined for
`day_exploration`, `night_combat`, `terminal`, `truth_reveal`, `final_choice`, etc. All current
`assets/music/*.wav` are procedural placeholders (`tools/generate_music_pack.py`).

**Available real tracks (in /mnt/hgfs/shared):** `day_exploration.wav`, `night_combat.wav`.
**Missing real tracks (user will generate later):** terminal-followed-then-shot (→ `terminal`),
player-gains-control-of-terminal (→ `truth_reveal`).

**Design:**
1. Replace `assets/music/day_exploration.wav` and `night_combat.wav` with the /mnt versions;
   re-import (delete stale `.import` so Godot regenerates, or run the editor import). Verify they
   load and loop.
2. Confirm the cues actually fire at the right moments — audit every `play_cue(...)` /
   `_play_music_cue(...)` call site (day exploration start, night combat start, terminal scene,
   truth-reveal beat, final choice). Fix any scene that doesn't trigger its cue. This is the real
   work — the wiring may be partial.
3. When the user delivers the 2 terminal tracks later, drop them in as `terminal.wav` /
   `truth_reveal.wav` (slots already exist; no code change).
4. **Suggested extra cues to generate** (return list to user): boss fight (thunder_leiting),
   elevator-repair/ascend sting, out-of-fuel tension, run-reset already exists. Map each to a
   scene so the user knows what to make.

**Subtasks & owners:**
- D1 swap the 2 real WAVs + re-import + load check — **S, haiku** (file ops + headless import).
- D2 audit & fix all music cue trigger points across scenes — **M, sonnet** (cross-scene tracing).
- D3 produce the "what music to generate next" list with scene mappings — **S, opus/sonnet** (taste).
**Check:** day exploration plays day track; entering night combat crossfades to night track; terminal/truth/final beats trigger their cues; no `unknown cue` / `could not load` warnings in log.

---

## Part E — Feature 4 (cont.): Settings menu

**Goal:** finish the placeholder Settings button (`main_menu.gd._on_placeholder_pressed`).

**Design:** real settings panel with: Master / Music / SFX volume sliders (wired to the Music bus
and an SFX bus), fullscreen toggle, "replay night tutorial" button (ties to Part C), language is
zh-only so skip. Persist to `user://settings.cfg`; load on boot.

**Subtasks & owners:**
- E1 settings panel scene + volume sliders → AudioServer buses + cfg persistence — **M, sonnet**.
- E2 wire menu button + boot-time load + tutorial-replay hook — **S, haiku**.
**Check:** sliders change volume live and persist across restart; tutorial replay works.

---

## Sequencing & allocation summary

1. **Part A first** (all small, unblock testing): A1,A2,A3 parallel (haiku/sonnet) → A4 (opus+sonnet) → A5 (sonnet).
2. **Part D1+D2** early (independent, makes playtesting pleasant) — haiku+sonnet.
3. **Part B** (opus-led headline feature) — sonnet persistence, opus the controller apply.
4. **Part C** tutorial — sonnet scene, haiku text.
5. **Part E** settings — sonnet, depends on D (audio buses) and C (replay hook).

**Opus (1.0):** A4 wave design, B3 controller upgrade-apply, D3 music taste call.
**Sonnet (0.6):** A1, A5, B1, B2, C1, C3, D2, E1 — anything cross-system or persistence.
**Haiku (0.2) / codex? (0.2):** A2, A3, B4, C2, C4, D1, E2 — localized mechanical edits.

**Risk notes:** B (item→upgrade) and A5 (pause) touch save/load and the day↔night boundary — most
likely to introduce subtle bugs; verify round-trips explicitly. Everything else is additive.
