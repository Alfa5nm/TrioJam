# Function Reference

How every script in the project works, grouped by system. Godot 4.6, GDScript.

Current playable flow: stairwell (`Scene0`) → rooftop (`Scene1`) → scoped target identification (`Scene2`) → Broadcast Interface.

---

## Broadcast Interface (`scenes/gameplay/`, `scripts/gameplay/`, `scripts/data/`)

The Storyteller-style news-report puzzle: drag a scene and up to two characters into each of the CAUSE / CONFLICT / OUTCOME frames, then BROADCAST. A resulting `BroadcastSequence` match drives a line-by-line reporter narration with frame highlighting.

Entry point: `scenes/gameplay/broadcast_interface.tscn`. It is reached after the correct target is selected in Scene2 and loads the Day 0 rooftop report by default.

## Scoped target identification (`scoped_target_scene.tscn`)

`ScopedTargetScene` bridges the rooftop plan animation and the first Broadcast Interface report.

- Mouse movement drives a gently stabilized scope position; left click fires.
- A shader keeps the circular scope opening clear while the surrounding scene remains visible at reduced opacity.
- Four generated character rows provide four-frame idle loops: smoking target, typist, clerk, and copier employee.
- `attempt_shot_at(screen_position)` resolves the subject beneath the reticle. Non-targets cycle internal-monologue rejection lines without ending the scene; the balcony official emits `target_confirmed` and advances to the Broadcast Interface.
- `ScopeReticle` draws the code-native crosshair and switches to a confirmed color after the correct selection.

### Data model — `scripts/data/`

**`character_def.gd` — `CharacterDef extends Resource`**
Plain data: `id: StringName`, `display_name: String`, `portrait_color: Color`. One instance per character (e.g. Soldier, MC).

**`action_def.gd` — `ActionDef extends Resource`**
Plain data: `id: StringName`, `display_name: String`. Represents a "scene" — the verb/event shown in a frame (e.g. "strikes", "Rooftop Scene").

**`shot_element.gd` — `ShotElement extends RefCounted`**
A transient (not saved) value object: one frame's current contents.
- `characters: Array[CharacterDef]`, `action: ActionDef`
- `_init(p_characters, p_action)` — constructor.
- `phrase() -> String` — human-readable summary, e.g. `"Soldier & Civilian · strikes"`.
- `is_complete() -> bool` — true once `action` is set and at least one character is present.
- `matches(other: ShotElement) -> bool` — exact-set comparison: same action id AND the same set of character ids (order-independent, no extras allowed).
- `has_character(character) -> bool` — membership check.

**`broadcast_sequence.gd` — `BroadcastSequence extends Resource`**
One authored "correct answer" (truthful or propaganda) for a report.
- `headline: String` — fallback dialogue text if no `broadcast_lines` are authored.
- `broadcast_lines: Array[String]` / `broadcast_line_frames: Array[int]` — parallel arrays: the reporter's narration, line by line, and which frame (0=cause, 1=conflict, 2=outcome, -1=none) each line should highlight while showing.
- `cause_characters` / `cause_action`, `conflict_characters` / `conflict_action`, `outcome_characters` / `outcome_action` — the expected contents of each of the 3 frames.
- `matches(placed: Array[ShotElement]) -> bool` — true iff all 3 placed shots match their expected slot (via `_slot_matches`, which builds a throwaway expected `ShotElement` and delegates to `ShotElement.matches`).

**`broadcast_report.gd` — `BroadcastReport extends Resource`**
One puzzle instance (one "day's report").
- `report_id: StringName`, `directive_text: String` (shown in the left dialogue panel before broadcasting).
- `characters: Array[CharacterDef]`, `available_actions: Array[ActionDef]` — the full roster/scene pool for this report.
- `truthful_sequence` / `propaganda_sequence: BroadcastSequence` — either may be `null` (Day 0 has no truthful route).
- `find_matching_sequence(placed: Array[ShotElement]) -> BroadcastSequence` — checks truthful first, then propaganda; returns `null` if neither matches.

**`broadcast_demo_data.gd` — `BroadcastDemoData`** (static factory, no instances)
- `checkpoint_killing_report() -> BroadcastReport` — "Day 1: The Checkpoint Killing." 3 characters (Soldier, Civilian, Witness), 6 reusable actions, both a truthful and a propaganda sequence.
- `rooftop_killing_report() -> BroadcastReport` — "Day 0: The First Shot." 3 characters (Opposition Person, MC, Government Official), 3 single-use scenes, propaganda-only (no truthful route), with the full 9-line reporter broadcast script attached.
- `_character(id, display_name, portrait_color)` / `_action(id, display_name)` — private constructors used by the two report builders above.

### UI / controller — `scripts/gameplay/`

**`character_chip.gd` — `CharacterChip extends VBoxContainer`** (scene: `character_chip.tscn`)
One draggable circular portrait in the roster.
- `setup(character)` — assigns the character and refreshes the visual (tints the circle to `portrait_color`, sets the initial letter + name label).
- `_get_drag_data(pos)` — returns `{"type": "broadcast_character", "character": character}` with a disconnected `Label` drag preview. Returns `null` if no character assigned.

**`character_roster.gd` — `CharacterRoster extends PanelContainer`** (scene: `character_roster.tscn`)
The "CHARACTERS" panel.
- `setup(characters: Array[CharacterDef])` — clears and repopulates its `GridContainer` with one `CharacterChip` (instanced from a `preload`ed scene) per character.

**`scene_frame.gd` — `SceneFrame extends PanelContainer`** (scene: `scene_frame.tscn`)
The single click-to-cycle scene preview box (the "SCENE" button's display).
- `setup(available_actions: Array[ActionDef])` — resets to no scene picked.
- `cycle_scene()` — advances to the next action in the list (wraps around), called by the SCENE button's `pressed` signal.
- `_get_drag_data(pos)` — once a scene is picked, returns `{"type": "broadcast_scene", "action": current_action}` so the frame itself can be dragged onto a slot. Returns `null` before any scene is picked.

**`frame_slot.gd` — `FrameSlot extends PanelContainer`** (scene: `frame_slot.tscn`, 3 instances: CAUSE/CONFLICT/OUTCOME)
Owns one frame's composition directly (drag targets are the slots themselves — there is no intermediate "composer" step).
- `slot_label: String` (export) — "CAUSE" / "CONFLICT" / "OUTCOME".
- `current_action: ActionDef`, `current_characters: Array[CharacterDef]` (max 2) — this slot's live state.
- `is_filled() -> bool` — action set AND at least one character.
- `clear()` — resets to empty.
- `place(shot: ShotElement)` — sets both fields at once from a `ShotElement` (used by tests and by direct data-driven setup).
- `remove_character(character)` — click-to-remove; called from the dynamically-built character chip buttons inside the slot.
- `current_shot() -> ShotElement` — builds a fresh snapshot for matching.
- `show_result(matched: bool)` — sets the slot's border to green (match) or red (no match) after a broadcast.
- `set_highlighted(active: bool)` — overrides the border to gold while this frame's reporter line is playing back; restores the previous (fill/result) color when turned off.
- `_can_drop_data` / `_drop_data` — Godot's Control drag-drop callbacks. Branches on payload `type`:
  - `"broadcast_scene"` — always accepted (replaces the current scene).
  - `"broadcast_character"` — rejected unless this slot already has a scene (scene-first rule), under the 2-character cap, and not already present.
- `composition_changed` signal — emitted after any drop or removal; `BroadcastInterface` listens to re-evaluate whether BROADCAST can be enabled.

**`broadcast_interface.gd` — `BroadcastInterface extends Control`** (scene: `broadcast_interface.tscn`, the screen root)
Wires everything together and owns the reporter-playback state machine.
- `report: BroadcastReport` — the currently loaded puzzle.
- `load_report(report)` — resets the scene frame, character roster, and all 3 slots for a new report; sets the directive text.
- `_on_slot_composition_changed` / `_update_broadcast_button` — BROADCAST is enabled only when all 3 slots are filled.
- `_on_broadcast_pressed()` — gathers the 3 slots' shots, calls `report.find_matching_sequence()`, colors all slots green/red, and either starts the reporter playback (if the matched sequence has `broadcast_lines`) or falls back to showing the single `headline`. Emits `broadcast_resolved(sequence, matched)`.
- `_start_playback(sequence)` / `_show_playback_line()` / `_advance_playback()` / `_end_playback()` — step through `broadcast_lines` one at a time, highlighting the associated `FrameSlot` per `broadcast_line_frames`, appending an "— End of broadcast —" marker once exhausted.
- `_on_continue_pressed()` — if a playback is active, advances it; otherwise emits `continue_pressed` (a passthrough hook for future non-broadcast dialogue, currently a no-op consumer).

---

## Side-scroller placeholder (`scripts/player/`, `scripts/interactions/`, `scripts/world/`)

The opening stairwell level (`scenes/main/main.tscn`) begins the connected sequence leading to the Broadcast Interface.

**`player.gd` — `Player extends CharacterBody2D`**
Platformer movement with coyote time and jump buffering.
- `_physics_process(delta)` — applies gravity, horizontal acceleration/friction (`Input.get_axis`), buffered/coyote-timed jumping, variable jump height (cutting velocity on early release), and flips `body_visual` to face movement direction. Emits `fell` once the player drops past `fall_limit`.
- `reset_to(spawn_position)` — teleports back to a checkpoint and re-enables control.

**`report_point.gd` — `ReportPoint extends Area2D`** (group: `report_points`)
A collectible in the level.
- `_on_body_entered` / `_on_body_exited` — show/hide the interact prompt when the `Player` overlaps.
- `_unhandled_input` — on the `interact` action while the player is nearby and it's not yet collected, marks it collected and emits `collected(report_id, headline)`.

**`newsroom_gate.gd` — `NewsroomGate extends Area2D`**
The level-exit gate.
- `set_unlocked(value)` — recolors the door and updates the prompt text based on whether both reports have been collected.
- `_unhandled_input` — on `interact` while nearby, emits `attempted` (whether or not it's actually unlocked; the caller decides what to do).

**`placeholder_level.gd`** (attached to `scenes/main/main.tscn` root, no `class_name`)
Ties the pieces above into the playable loop.
- `_ready()` — records the spawn position, connects to every `ReportPoint` in the `report_points` group and to the gate/player signals.
- `_unhandled_input` — `restart` action reloads the scene.
- `_on_report_collected` — increments the counter, updates the HUD message, and unlocks the gate once both reports are in.
- `_on_newsroom_attempted` — shows the completion panel if both reports were collected, otherwise nags the player.
- `_on_player_fell` — resets the player to the checkpoint (unless the level is already complete).
- `_update_hud` — refreshes the "REPORTS x / y" label.

---

## Tests (`tests/`)

The headless `SceneTree` smoke tests run via `godot --headless -s <path>`. Each script exits non-zero when an assertion fails.

- **`side_scroller_smoke_test.gd`** — verifies stair collision switching, traversal, railing depth, audio zones, door access, and fall recovery.
- **`rooftop_plan_smoke_test.gd`** — verifies rooftop traversal, restrained footstep cadence, plan prompt, rifle animation/audio cues, and the Scene2 connection.
- **`scoped_target_smoke_test.gd`** — verifies all four idle loops, the scope mask, three non-target rejection paths, correct target resolution, and the Broadcast Interface connection.
- **`broadcast_interface_smoke_test.gd`** — instantiates `broadcast_interface.tscn` and exercises: node wiring, the scene-first drop rule, the 2-character cap, the truthful/propaganda/unrecognized resolution paths for the checkpoint report, and the full Day 0 reporter-playback sequence (line-by-line text and per-frame highlighting) including the CONTINUE passthrough when no playback is active.

**Note:** whenever a new `class_name` script is added, Godot's global class cache must be refreshed before headless tests can resolve it by name — run `godot --headless --editor --path <project> --quit-after 60` once first.
