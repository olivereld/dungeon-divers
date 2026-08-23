# Composition Rule & Fixture Anchor Completion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the dungeon composition pipeline so that all declared prop types (benches, altars, tombstones) and fixture types (braziers, hanging lanterns) actually get placed according to their `placement_mode`, instead of being silently discarded by incompatible anchor discovery.

**Architecture:** Three surgical fixes to the existing declarative pipeline — no new classes, no legacy fallbacks. (1) Anchor discovery switches from `composition_role → anchor type` to `placement_mode → anchor type`. (2) The lighting planner adds HANGING and SURFACE anchor resolution. (3) `min_count` guarantees get a reserved budget so identity props can't be starved by earlier rules.

**Tech Stack:** Godot 4.6.1, GDScript, headless test runner

**Spec:** [2026-08-22-semantic-spatial-composition-engine.md](file:///c:/Users/olivereld/Documents/dungeon-divers/docs/superpowers/plans/2026-08-22-semantic-spatial-composition-engine.md)

## Global Constraints

- Godot 4.6.1 stable, GDScript only
- No `if archetype == X` hardcoded branches — everything stays declarative
- No new class files unless strictly necessary — modify existing classes
- Tests run headless: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/<path>.gd`
- Pipeline purity: no Node3D creation in composition/planning logic

---

### Task 1: Placement-Driven Anchor Discovery

The root cause of empty rooms: `_discover_anchors_for_rule()` selects anchors based on `composition_role` (PRIMARY → center only, SECONDARY → wall+corner+floor). But a SECONDARY rule targeting `church_pew_wall` with `placement_mode=WALL` gets mixed into an anchor pool that includes FLOOR and CORNER anchors, and then the style/anchor mode check at line 151-156 filters them all out — **or worse, the rule only discovers CENTER anchors for a PRIMARY altar but the altar's `placement_mode=CENTER` check passes trivially.**

The real problem: a `SECONDARY` rule that targets `WALL`-mode props also discovers `FLOOR` and `CORNER` anchors. The subsequent placement_mode filter discards the irrelevant anchors, but **it also means a rule needing WALL anchors for benches competes against rules needing FLOOR anchors for urns in the same candidate pool.** More critically, if a `CompositionRule` has `placement_mode = 0` (default FLOOR, because it was never set), it uses the generic path and may not get the correct anchors at all.

**Fix:** Make `_discover_anchors_for_rule()` use `rule.placement_mode` when it's explicitly set (non-zero or explicitly declared), falling back to the current `composition_role`-based logic only as a last resort.

**Files:**
- Modify: [`decoration_composition_planner.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_composition_planner.gd):286-303
- Modify: [`decoration_composition_rule.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_composition_rule.gd):13
- Modify: [`decoration_purpose_profile_registry.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_purpose_profile_registry.gd) (all rules)
- Test: [`tests/presentation/decoration/composition/test_placement_driven_anchors.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/tests/presentation/decoration/composition/test_placement_driven_anchors.gd) [NEW]

**Interfaces:**
- Consumes: `PropAnchorResolver.find_wall_anchors()`, `find_center_anchors()`, `find_corner_anchors()`, `find_floor_anchors()` — existing, unchanged
- Consumes: `DecorationCompositionRule.placement_mode` — field already exists at line 13, currently defaults to `0`
- Produces: `_discover_anchors_for_rule()` — same return signature (Array of PropAnchors), different selection logic

- [ ] **Step 1: Write failing test**

Create `tests/presentation/decoration/composition/test_placement_driven_anchors.gd`:

```gdscript
extends SceneTree

const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationCompositionRuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropAnchorResolverScript = preload("res://src/presentation/props/prop_anchor_resolver.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_placement_driven_anchors ---")
	print("==================================================================")

	_test_wall_rule_discovers_wall_anchors()
	_test_center_rule_discovers_center_anchors()
	_test_corner_rule_discovers_corner_anchors()
	_test_floor_rule_discovers_floor_anchors()
	_test_fallback_uses_composition_role()

	print("[OK] All placement-driven anchor tests passed!")
	quit()

func _test_wall_rule_discovers_wall_anchors() -> void:
	var planner = _DecorationCompositionPlannerScript.new()
	var rule = _DecorationCompositionRuleScript.new()
	rule.composition_role = _CompositionRoleScript.Role.SECONDARY
	rule.placement_mode = _PropPlacementModeScript.Mode.WALL

	var r_geom = _make_test_room_geom()
	var anchors = planner._discover_anchors_for_rule(rule, r_geom, 2.0)

	assert(not anchors.is_empty(), "FAIL: WALL rule must discover wall anchors")
	for a in anchors:
		assert(a.mode == _PropPlacementModeScript.Mode.WALL, "FAIL: All anchors must be WALL mode, got %d" % a.mode)
	print("  [OK] WALL rule discovers only WALL anchors (%d found)" % anchors.size())

func _test_center_rule_discovers_center_anchors() -> void:
	var planner = _DecorationCompositionPlannerScript.new()
	var rule = _DecorationCompositionRuleScript.new()
	rule.composition_role = _CompositionRoleScript.Role.PRIMARY
	rule.placement_mode = _PropPlacementModeScript.Mode.CENTER

	var r_geom = _make_test_room_geom()
	var anchors = planner._discover_anchors_for_rule(rule, r_geom, 2.0)

	assert(not anchors.is_empty(), "FAIL: CENTER rule must discover center anchors")
	for a in anchors:
		assert(a.mode == _PropPlacementModeScript.Mode.CENTER, "FAIL: All anchors must be CENTER mode, got %d" % a.mode)
	print("  [OK] CENTER rule discovers only CENTER anchors (%d found)" % anchors.size())

func _test_corner_rule_discovers_corner_anchors() -> void:
	var planner = _DecorationCompositionPlannerScript.new()
	var rule = _DecorationCompositionRuleScript.new()
	rule.composition_role = _CompositionRoleScript.Role.SECONDARY
	rule.placement_mode = _PropPlacementModeScript.Mode.CORNER

	var r_geom = _make_test_room_geom()
	var anchors = planner._discover_anchors_for_rule(rule, r_geom, 2.0)

	assert(not anchors.is_empty(), "FAIL: CORNER rule must discover corner anchors")
	for a in anchors:
		assert(a.mode == _PropPlacementModeScript.Mode.CORNER, "FAIL: All anchors must be CORNER mode, got %d" % a.mode)
	print("  [OK] CORNER rule discovers only CORNER anchors (%d found)" % anchors.size())

func _test_floor_rule_discovers_floor_anchors() -> void:
	var planner = _DecorationCompositionPlannerScript.new()
	var rule = _DecorationCompositionRuleScript.new()
	rule.composition_role = _CompositionRoleScript.Role.DETAIL
	rule.placement_mode = _PropPlacementModeScript.Mode.FLOOR

	var r_geom = _make_test_room_geom()
	var anchors = planner._discover_anchors_for_rule(rule, r_geom, 2.0)

	assert(not anchors.is_empty(), "FAIL: FLOOR rule must discover floor anchors")
	for a in anchors:
		assert(a.mode == _PropPlacementModeScript.Mode.FLOOR, "FAIL: All anchors must be FLOOR mode, got %d" % a.mode)
	print("  [OK] FLOOR rule discovers only FLOOR anchors (%d found)" % anchors.size())

func _test_fallback_uses_composition_role() -> void:
	var planner = _DecorationCompositionPlannerScript.new()
	var rule = _DecorationCompositionRuleScript.new()
	rule.composition_role = _CompositionRoleScript.Role.PRIMARY
	rule.placement_mode = -1  # Not set — should fall back to composition_role logic

	var r_geom = _make_test_room_geom()
	var anchors = planner._discover_anchors_for_rule(rule, r_geom, 2.0)

	assert(not anchors.is_empty(), "FAIL: Fallback must still produce anchors")
	# PRIMARY fallback should produce CENTER or FLOOR anchors
	print("  [OK] Fallback (placement_mode=-1) discovers anchors via composition_role (%d found)" % anchors.size())

func _make_test_room_geom():
	# 6x6 room — creates a room with walls, corners, center, and floor cells
	var geom = RefCounted.new()
	var floor_cells: Array[Vector2i] = []
	for x in range(2, 8):
		for y in range(2, 8):
			floor_cells.append(Vector2i(x, y))
	geom.set("floor_cells", floor_cells)
	geom.set("wall_cells", [])
	geom.set("door_positions", [])
	geom.set("stairs_cells", [])
	geom.set("room_id", 1)
	return geom
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/decoration/composition/test_placement_driven_anchors.gd`
Expected: FAIL — WALL rule currently discovers mixed anchors (FLOOR+WALL+CORNER) because `_discover_anchors_for_rule` ignores `rule.placement_mode`.

- [ ] **Step 3: Update `DecorationCompositionRule.placement_mode` default to `-1`**

In [`decoration_composition_rule.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_composition_rule.gd):

```gdscript
# Change line 13 from:
@export var placement_mode: int = 0
# To:
@export var placement_mode: int = -1  ## -1 = auto (fall back to composition_role logic)
```

- [ ] **Step 4: Rewrite `_discover_anchors_for_rule()` to be placement-driven**

In [`decoration_composition_planner.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_composition_planner.gd), replace lines 286-303:

```gdscript
func _discover_anchors_for_rule(rule, room_geometry, tile_size: float) -> Array:
	# If the rule declares an explicit placement mode, use it directly
	if rule.placement_mode >= 0:
		match rule.placement_mode:
			_PropPlacementModeScript.Mode.WALL:
				return _anchor_resolver.find_wall_anchors(room_geometry, tile_size)
			_PropPlacementModeScript.Mode.CENTER:
				var centers = _anchor_resolver.find_center_anchors(room_geometry, tile_size)
				if not centers.is_empty():
					return centers
				return _anchor_resolver.find_floor_anchors(room_geometry, tile_size)
			_PropPlacementModeScript.Mode.CORNER:
				return _anchor_resolver.find_corner_anchors(room_geometry, tile_size)
			_PropPlacementModeScript.Mode.FLOOR:
				return _anchor_resolver.find_floor_anchors(room_geometry, tile_size)

	# Fallback: use composition_role to infer anchor types (legacy behavior)
	var combined: Array = []
	match rule.composition_role:
		_CompositionRoleScript.Role.PRIMARY:
			var centers = _anchor_resolver.find_center_anchors(room_geometry, tile_size)
			if not centers.is_empty():
				return centers
			return _anchor_resolver.find_floor_anchors(room_geometry, tile_size)
		_CompositionRoleScript.Role.SECONDARY, _CompositionRoleScript.Role.COMPANION, _CompositionRoleScript.Role.DETAIL:
			var walls = _anchor_resolver.find_wall_anchors(room_geometry, tile_size)
			var corners = _anchor_resolver.find_corner_anchors(room_geometry, tile_size)
			var floors = _anchor_resolver.find_floor_anchors(room_geometry, tile_size)
			combined.append_array(walls)
			combined.append_array(corners)
			combined.append_array(floors)
			return combined
		_:
			return _anchor_resolver.find_floor_anchors(room_geometry, tile_size)
```

- [ ] **Step 5: Set explicit `placement_mode` on all rules in `DecorationPurposeProfileRegistry`**

In [`decoration_purpose_profile_registry.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_purpose_profile_registry.gd), add `placement_mode` after each rule creation. The needed import is already present via `_CompositionRoleScript`, add `_PropPlacementModeScript`:

Add preload at top (after line 14):
```gdscript
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
```

Then set `placement_mode` on every rule:

```gdscript
# TOMB primary_sarcophagus (line ~57, after clearance)
r_tomb_primary.placement_mode = _PropPlacementModeScript.Mode.CENTER

# TOMB support_urns_tombstones (line ~66, after max_count)
r_tomb_support.placement_mode = _PropPlacementModeScript.Mode.FLOOR

# ANTECHAMBER wall_benches (line ~111, after max_count)
r_benches.placement_mode = _PropPlacementModeScript.Mode.WALL

# CATACOMB perimeter_burials (line ~139, after max_count)
r_niches.placement_mode = _PropPlacementModeScript.Mode.FLOOR
```

- [ ] **Step 6: Run test to verify it passes**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/decoration/composition/test_placement_driven_anchors.gd`
Expected: PASS — all 5 sub-tests green.

- [ ] **Step 7: Commit**

```bash
git add src/presentation/decoration/composition/decoration_composition_planner.gd
git add src/presentation/decoration/composition/decoration_composition_rule.gd
git add src/presentation/decoration/composition/decoration_purpose_profile_registry.gd
git add tests/presentation/decoration/composition/test_placement_driven_anchors.gd
git commit -m "fix(composition): placement-driven anchor discovery replaces role-based"
```

---

### Task 2: HANGING & FLOOR Fixture Anchor Resolution in Lighting Planner

The `DecorationLightingPlanner` currently only resolves WALL anchors (section 1) and FLOOR anchors (section 2). The fixture palette includes `HANGING` lanterns and `SURFACE` candle holders, but the planner never calls `find_hanging_anchors()` or `find_surface_anchors()` — so those fixtures are **defined but never placed**.

Additionally, the FLOOR section has a `break` after placing 1 fixture (line 127), meaning at most 1 brazier/candle_cluster per room regardless of budget. This is overly restrictive.

**Files:**
- Modify: [`decoration_lighting_planner.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_lighting_planner.gd):92-129
- Test: [`tests/presentation/decoration/composition/test_lighting_planner_modes.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/tests/presentation/decoration/composition/test_lighting_planner_modes.gd) [NEW]

**Interfaces:**
- Consumes: `FixtureAnchorResolver.find_hanging_anchors()` — already exists at line 124-136 of [`fixture_anchor_resolver.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/fixtures/fixture_anchor_resolver.gd)
- Consumes: `FixtureAnchorResolver.find_surface_anchors()` — already exists at line 110-121
- Consumes: `FixturePalette.get_entries_for_placement(Mode.HANGING)`, `get_entries_for_placement(Mode.SURFACE)` — already works
- Produces: Additional `FixtureDirective` entries in the returned Array, covering all 4 placement modes

- [ ] **Step 1: Write failing test**

Create `tests/presentation/decoration/composition/test_lighting_planner_modes.gd`:

```gdscript
extends SceneTree

const _DecorationLightingPlannerScript = preload("res://src/presentation/decoration/composition/decoration_lighting_planner.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _DecorationOccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_lighting_planner_modes ---")
	print("==================================================================")

	_test_hanging_fixtures_placed()
	_test_floor_fixtures_allow_multiple()

	print("[OK] All lighting planner mode tests passed!")
	quit()

func _test_hanging_fixtures_placed() -> void:
	var planner = _DecorationLightingPlannerScript.new()
	var palette = _make_palette_with_hanging()
	var geom = _make_test_room_geom()
	var occ = _DecorationOccupancyMapScript.new()

	var directives = planner.plan_room_lighting(10.0, null, palette, [], geom, occ, 42, 2.0)

	var hanging_count: int = 0
	for d in directives:
		if d.placement != null and d.placement.mode == _FixturePlacementModeScript.Mode.HANGING:
			hanging_count += 1
	assert(hanging_count > 0, "FAIL: Must place at least 1 HANGING fixture when palette has them and budget allows")
	print("  [OK] HANGING fixtures placed: %d" % hanging_count)

func _test_floor_fixtures_allow_multiple() -> void:
	var planner = _DecorationLightingPlannerScript.new()
	var palette = _make_palette_floor_only()
	var geom = _make_test_room_geom()
	var occ = _DecorationOccupancyMapScript.new()

	# High budget should allow more than 1 floor fixture
	var directives = planner.plan_room_lighting(20.0, null, palette, [], geom, occ, 42, 2.0)

	var floor_count: int = 0
	for d in directives:
		if d.placement != null and d.placement.mode == _FixturePlacementModeScript.Mode.FLOOR:
			floor_count += 1
	assert(floor_count >= 2, "FAIL: With budget=20 and spacing, should place multiple floor fixtures (got %d)" % floor_count)
	print("  [OK] FLOOR fixtures allow multiple: %d placed" % floor_count)

func _make_palette_with_hanging() -> _FixturePaletteScript:
	var hanging = _FixtureStyleScript.new(
		&"test_hanging_lantern", _FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING,
		1.0, Vector3.ZERO, false, 0,
		true, Color(1.0, 0.8, 0.4, 1.0), 1.5, 7.0
	)
	var torch = _FixtureStyleScript.new(
		&"test_wall_torch", _FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL,
		1.0, Vector3(0.0, 2.0, 0.0), false, 0,
		true, Color(1.0, 0.6, 0.2, 1.0), 1.4, 6.5
	)
	var entries: Array[_FixturePaletteEntryScript] = [
		_FixturePaletteEntryScript.new(torch, 50.0),
		_FixturePaletteEntryScript.new(hanging, 80.0)
	]
	return _FixturePaletteScript.new(&"test_hanging_palette", entries, 3, 0.8, 4, 0.5)

func _make_palette_floor_only() -> _FixturePaletteScript:
	var brazier = _FixtureStyleScript.new(
		&"test_brazier", _FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0, Vector3.ZERO, false, 1,
		true, Color(1.0, 0.5, 0.2, 1.0), 2.0, 8.0
	)
	var entries: Array[_FixturePaletteEntryScript] = [
		_FixturePaletteEntryScript.new(brazier, 90.0)
	]
	return _FixturePaletteScript.new(&"test_floor_palette", entries, 3, 0.8, 3, 0.9)

func _make_test_room_geom():
	var geom = RefCounted.new()
	var floor_cells: Array[Vector2i] = []
	var wall_cells: Array[Vector2i] = []
	# 8x8 interior room with wall border
	for x in range(1, 9):
		for y in range(1, 9):
			floor_cells.append(Vector2i(x, y))
	# Walls around
	for x in range(0, 10):
		wall_cells.append(Vector2i(x, 0))
		wall_cells.append(Vector2i(x, 9))
	for y in range(1, 9):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(9, y))

	geom.set("floor_cells", floor_cells)
	geom.set("wall_cells", wall_cells)
	geom.set("door_positions", [])
	geom.set("room_id", 1)
	return geom
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/decoration/composition/test_lighting_planner_modes.gd`
Expected: FAIL — `_test_hanging_fixtures_placed` fails because the planner never calls `find_hanging_anchors()`.

- [ ] **Step 3: Add HANGING and SURFACE sections + fix FLOOR `break` in `DecorationLightingPlanner`**

In [`decoration_lighting_planner.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_lighting_planner.gd), replace lines 92-129 (section 2: FLOOR fixtures + end of function) with:

```gdscript
	# 2. Resolver luminarias de suelo (FLOOR / Ceremoniales)
	var floor_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.FLOOR)
	if not floor_entries.is_empty() and current_cost < budget:
		var floor_anchors = _anchor_resolver.find_floor_anchors(room_geom, tile_size)
		var floor_spacing: int = 4
		for i in range(0, floor_anchors.size(), floor_spacing):
			if current_cost >= budget:
				break
			var fa = floor_anchors[i]
			if door_map.has(fa.cell):
				continue
			if occupancy != null and occupancy.is_cell_occupied(fa.cell):
				continue

			var entry = floor_entries[(i + seed_val) % floor_entries.size()]
			var style: _FixtureStyleScript = entry.style
			var cost: float = _get_style_cost(style)

			if current_cost + cost <= budget:
				var fa_pos: Vector3 = fa.position if "position" in fa else (fa.world_position if "world_position" in fa else Vector3.ZERO)
				var pl := _FixturePlacementScript.new(
					_FixturePlacementModeScript.Mode.FLOOR,
					fa.cell,
					-1,
					fa_pos,
					fa.rotation_y,
					Vector3.UP
				)
				var f_dir := _FixtureDirectiveScript.new(
					style.id,
					room_id,
					style,
					pl,
					style.scale
				)
				result.append(f_dir)
				current_cost += cost

	# 3. Resolver luminarias colgantes (HANGING)
	var hanging_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.HANGING)
	if not hanging_entries.is_empty() and current_cost < budget:
		var hanging_anchors = _anchor_resolver.find_hanging_anchors(room_geom, tile_size)
		var hanging_spacing: int = 4
		for i in range(0, hanging_anchors.size(), hanging_spacing):
			if current_cost >= budget:
				break
			var ha = hanging_anchors[i]
			if door_map.has(ha.cell):
				continue
			if occupancy != null and occupancy.is_cell_occupied(ha.cell):
				continue

			var entry = hanging_entries[(i + seed_val) % hanging_entries.size()]
			var style: _FixtureStyleScript = entry.style
			var cost: float = _get_style_cost(style)

			if current_cost + cost <= budget:
				var ha_pos: Vector3 = ha.position if "position" in ha else (ha.world_position if "world_position" in ha else Vector3.ZERO)
				var pl := _FixturePlacementScript.new(
					_FixturePlacementModeScript.Mode.HANGING,
					ha.cell,
					-1,
					ha_pos,
					ha.rotation_y,
					Vector3.DOWN
				)
				var f_dir := _FixtureDirectiveScript.new(
					style.id,
					room_id,
					style,
					pl,
					style.scale
				)
				result.append(f_dir)
				current_cost += cost

	# 4. Resolver luminarias de superficie (SURFACE)
	var surface_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.SURFACE)
	if not surface_entries.is_empty() and current_cost < budget:
		var surface_anchors = _anchor_resolver.find_surface_anchors(room_geom, tile_size)
		var surface_spacing: int = 5
		for i in range(0, surface_anchors.size(), surface_spacing):
			if current_cost >= budget:
				break
			var sa = surface_anchors[i]
			if door_map.has(sa.cell):
				continue
			if occupancy != null and occupancy.is_cell_occupied(sa.cell):
				continue

			var entry = surface_entries[(i + seed_val) % surface_entries.size()]
			var style: _FixtureStyleScript = entry.style
			var cost: float = _get_style_cost(style)

			if current_cost + cost <= budget:
				var sa_pos: Vector3 = sa.position if "position" in sa else (sa.world_position if "world_position" in sa else Vector3.ZERO)
				var pl := _FixturePlacementScript.new(
					_FixturePlacementModeScript.Mode.SURFACE,
					sa.cell,
					-1,
					sa_pos,
					sa.rotation_y,
					Vector3.UP
				)
				var f_dir := _FixtureDirectiveScript.new(
					style.id,
					room_id,
					style,
					pl,
					style.scale
				)
				result.append(f_dir)
				current_cost += cost

	return result
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/decoration/composition/test_lighting_planner_modes.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/presentation/decoration/composition/decoration_lighting_planner.gd
git add tests/presentation/decoration/composition/test_lighting_planner_modes.gd
git commit -m "fix(lighting): add HANGING, SURFACE, and multi-FLOOR fixture resolution"
```

---

### Task 3: min_count Budget Reservation & max_total_props Raise

Currently, rules execute sequentially sorted by `composition_role`. The first rule (PRIMARY sarcophagus, min_count=1, max_count=1) places 1 prop. The second rule (SECONDARY urns, min_count=1, max_count=2) may place 2. If `max_allowed = 8` and the budget is consumed by urns+tombstones before reaching benches, benches never spawn.

**Fix:** Before the main placement loop, calculate the total reserved budget from all rules' `min_count` values. Then during placement, cap each rule's contribution at `max_count` but only allow it to **exceed its min_count** if there's leftover budget after all min_counts are accounted for.

**Files:**
- Modify: [`decoration_composition_planner.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_composition_planner.gd):113-118
- Modify: [`decoration_palette_resolver.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/decoration_palette_resolver.gd) (raise `max_props_per_room`)
- Test: existing `test_crypt_multi_seed_sweep.gd` already validates non-zero props — run it as regression

**Interfaces:**
- Consumes: `DecorationCompositionRule.min_count`, `.max_count` — existing fields
- Produces: Modified placement loop that respects `min_count` guarantees

- [ ] **Step 1: Add min_count budget reservation to the planner**

In [`decoration_composition_planner.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_composition_planner.gd), replace lines 113-129:

```gdscript
	var max_allowed: int = profile.max_total_props if profile != null else 10
	var total_placed: int = 0
	var primary_placed_cells: Array[Vector2i] = []

	if not rules_to_execute.is_empty() and palette.props != null:
		rules_to_execute.sort_custom(func(a, b): return a.composition_role < b.composition_role)

		# Calculate the total min_count reservation across all rules
		var total_min_reserved: int = 0
		for rule in rules_to_execute:
			total_min_reserved += rule.min_count

		for rule in rules_to_execute:
			if total_placed >= max_allowed:
				break

			var target_entries: Array = _find_matching_palette_entries(palette.props.entries, rule, intent)
			if target_entries.is_empty():
				continue

			# Allow at least min_count, but cap extras based on remaining global budget
			var remaining_budget: int = max_allowed - total_placed
			var other_rules_min: int = total_min_reserved - rule.min_count
			var available_for_extras: int = maxi(0, remaining_budget - other_rules_min)
			var target_count: int = mini(rule.max_count, rule.min_count + available_for_extras)
			target_count = mini(target_count, remaining_budget)
			var placed_for_rule: int = 0

			# Decrease this rule's reserved budget as we process it
			total_min_reserved -= rule.min_count
```

- [ ] **Step 2: Raise `max_props_per_room` in palette resolver**

In [`decoration_palette_resolver.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/decoration_palette_resolver.gd), raise the caps:

```gdscript
# TOMB (line ~344): 8 → 10
pal.max_props_per_room = 10

# ROYAL_TOMB (line ~357): 9 → 12
pal.max_props_per_room = 12

# MORTUARY (line ~369): 7 → 10
pal.max_props_per_room = 10

# SACRISTY (line ~382): 6 → 8
pal.max_props_per_room = 8

# CRYPT/CATACOMB (line ~395): 7 → 10
pal.max_props_per_room = 10

# Generic (line ~406): 5 → 7
pal.max_props_per_room = 7
```

- [ ] **Step 3: Run regression tests**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/integration/test_crypt_multi_seed_sweep.gd`
Expected: PASS with total_props_tested significantly higher than before.

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/run_all_tests.gd`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add src/presentation/decoration/composition/decoration_composition_planner.gd
git add src/presentation/decoration/decoration_palette_resolver.gd
git commit -m "fix(composition): min_count budget reservation + raise max_props caps"
```

---

## Verification Plan

### Automated Tests
```bash
# Task 1
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/decoration/composition/test_placement_driven_anchors.gd

# Task 2
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/decoration/composition/test_lighting_planner_modes.gd

# Task 3 regression
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/integration/test_crypt_multi_seed_sweep.gd

# Full suite
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/run_all_tests.gd
```

### Manual Verification
- Launch the game in Godot Editor, generate a Crypt dungeon with F3 overlay enabled
- Verify visually that TOMB rooms have sarcophagi, SACRISTY rooms have altars + benches, CATACOMB rooms have urns
- Verify hanging lanterns appear suspended from ceiling (Y ≈ 2.4) and braziers appear on floor (Y ≈ 0.0)
- Check multiple seeds to confirm variety (not every room identical)

## Expected Result After Fix

| Element              | Before  | After   |
| -------------------- | ------- | ------- |
| Sarcophagi           | 🟢      | 🟢      |
| Urns                 | 🟢      | 🟢      |
| Wall torches         | 🟢      | 🟢      |
| Wall lanterns        | 🟢      | 🟢      |
| Floor candles        | 🟢      | 🟢      |
| **Benches**          | 🔴      | 🟢      |
| **Altars**           | 🔴      | 🟢      |
| **Tombstones**       | 🟡      | 🟢      |
| **Braziers**         | 🔴      | 🟢      |
| **Hanging lanterns** | 🔴      | 🟢      |
