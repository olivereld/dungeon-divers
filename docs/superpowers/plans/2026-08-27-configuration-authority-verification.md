# Configuration Authority Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar una suite de pruebas de autoridad exhaustiva (`tests/profiles/test_configuration_authority.gd`) que demuestre y garantice que modificar los archivos JSON (`mausoleum.json`, `rooms/*.json`, `assets/*.json`) altera el resultado de generación, arquitectura, composición, iluminación y relaciones sin necesidad de modificar ni una sola línea de código GDScript.

**Architecture:**
1. `ProfileBundle` (`ProfileArchetype`, `ProfileRoom`, `AssetRegistry`) actúa como la única fuente de verdad (*WHAT/CUÁNTO*).
2. Los algoritmos (`RoomPurposeAssigner`, `PresentationProfileResolver`, `DecorationCompositionPlanner`, `DecorationLightingPlanner`) actúan como procesadores puros (*HOW/CÓMO*).
3. `test_configuration_authority.gd` realiza mutaciones dinámicas sobre las estructuras deserializadas de los perfiles JSON y verifica que el pipeline downstream refleja exactamente dichas mutaciones en cada subsistema.

**Tech Stack:** Godot 4.6, GDScript, JSON, `RefCounted`, suites de tests `SceneTree` ejecutadas en modo headless.

**Spec:** [User Request / Specification on Configuration Authority Audit & Verification]

## Global Constraints

- **Frontera de Autoridad Intocable:** Prohibido convertir lógica algorítmica (`calculate_clearance`, `score_candidate`, `resolve_orientation`, ocupación 2D) en JSON. El JSON gobierna el QUÉ, CUÁNTO y QUÉ ESTÁ PERMITIDO; el Algoritmo gobierna el CÓMO, DÓNDE y CÁLCULOS MATEMÁTICOS.
- **Determinismo y Pureza:** Todos los tests operan sobre instancias puras con semillas controladas, sin crear nodos 3D en el árbol de escena ni mutar `CellGrid`.
- **Aislamiento de Fallbacks:** Los fallbacks en GDScript existen exclusivamente como red de seguridad para arquetipos o salas sin JSON; cuando un perfil JSON existe, el fallback queda 100% bypassado.

---

## File Structure & Responsibilities

| File Path | Responsibility |
|---|---|
| `tests/profiles/test_configuration_authority.gd` | Suite principal de verificación de autoridad de configuración (Arquetipo, Arquitectura, Composición, Iluminación, Relaciones). |
| `src/dungeon_generator/profiles/profile_archetype.gd` | Documentación formal de `room_purpose_distribution` (distribución macro) vs `purpose_weights` (scoring contextual). |
| `src/presentation/decoration/composition/decoration_composition_planner.gd` | Verificación de respeto estricto del presupuesto `budget` de iluminación y ranuras `fixtures` desde `ProfileRoom`. |

---

## Task Decomposition

### Task 1: Archetype & Room Purpose Authority Test

**Files:**
- Create: `tests/profiles/test_configuration_authority.gd`
- Modify: `src/dungeon_generator/profiles/profile_archetype.gd:1-60`

**Interfaces:**
- Consumes: `ProfileLoader.load_full_archetype_bundle("mausoleum")`, `RoomPurposeAssigner.assign_purposes(...)`
- Produces: Verificación de que modificar `bundle.archetype.purpose_weights` altera la proporción de salas asignadas sin tocar GDScript.

- [x] **Step 1: Crear `tests/profiles/test_configuration_authority.gd` con la prueba de autoridad de Arquetipo**

```gdscript
extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _RoomPurposeAssignerScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose_assigner.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DungeonRoomScript = preload("res://src/dungeon_generator/core/dungeon_room.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_configuration_authority ---")
	print("==================================================================")

	var loader := _ProfileLoaderScript.new()
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	assert(bundle != null and bundle.archetype != null, "FAIL: Bundle must load")

	# --- 1. ARCHETYPE AUTHORITY TEST ---
	# Configuración A: Pesos por defecto (Crypt prioritario)
	var assigner := _RoomPurposeAssignerScript.new()
	var test_rooms: Array[_DungeonRoomScript] = []
	for i in range(1, 11):
		test_rooms.append(_DungeonRoomScript.new(i, Rect2i(i * 10, 0, 8, 8)))

	var assignments_default = assigner.assign_purposes(1, 10, test_rooms, [], bundle, 1337)
	var crypt_count_a: int = 0
	for r_id in assignments_default:
		if assignments_default[r_id] == _RoomPurposeScript.Type.CRYPT:
			crypt_count_a += 1

	# Configuración B: Modificación en JSON/Profile de propósito (Tomb = 100.0, Crypt = 0.0)
	bundle.archetype.purpose_weights[&"tomb"] = 100.0
	bundle.archetype.purpose_weights[&"crypt"] = 0.0
	var assignments_modified = assigner.assign_purposes(1, 10, test_rooms, [], bundle, 1337)
	var crypt_count_b: int = 0
	var tomb_count_b: int = 0
	for r_id in assignments_modified:
		if assignments_modified[r_id] == _RoomPurposeScript.Type.CRYPT:
			crypt_count_b += 1
		elif assignments_modified[r_id] == _RoomPurposeScript.Type.TOMB:
			tomb_count_b += 1

	assert(crypt_count_a > 0, "FAIL: Default mausoleum must assign crypts")
	assert(crypt_count_b == 0, "FAIL: Setting crypt weight to 0.0 in profile must prevent crypt assignments")
	assert(tomb_count_b > 0, "FAIL: Elevating tomb weight to 100.0 in profile must produce tomb assignments")
	print("  [OK] 1. Archetype authority validated (purpose_weights dynamically controls generation).")
	quit(0)
```

- [x] **Step 2: Ejecutar test para verificar funcionamiento**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_configuration_authority.gd"`
Expected: PASS (`[OK] 1. Archetype authority validated`).

- [x] **Step 3: Documentar formalmente la semántica de `room_purpose_distribution` vs `purpose_weights` en `profile_archetype.gd`**

```gdscript
## room_purpose_distribution: Distribución macro objetivo porcentual en el dungeon (ej. {"crypt": 0.25, "tomb": 0.15}).
## purpose_weights: Peso relativo consumido contextualmente por RoomPurposeAssigner para resolver roles de gameplay (COMBAT, TREASURE, EXPLORE).
```

---

### Task 2: Room Architecture Authority Test

**Files:**
- Modify: `tests/profiles/test_configuration_authority.gd`
- Consumes: `ProfileRoom.architecture`, `PresentationProfileResolver.resolve_from_room_profile`
- Produces: Verificación de que cambiar `floor`, `walls`, `door`, `stairs` en `ProfileRoom.architecture` cambia el `ArchitecturalPresentationProfile` resultante sin modificar GDScript.

- [x] **Step 1: Añadir prueba de autoridad arquitectónica completa en `test_configuration_authority.gd`**

```gdscript
	# --- 2. ROOM ARCHITECTURE AUTHORITY TEST ---
	var pres_resolver := preload("res://src/presentation/architecture/presentation_profile_resolver.gd").new()
	var arch_style := preload("res://src/presentation/architecture/architectural_style.gd")
	var crypt_room = bundle.get_room(&"crypt")
	assert(crypt_room != null and crypt_room.architecture != null, "FAIL: Crypt room profile must exist")

	# Baseline Crypt: floor=ruined_stone, walls=dark_stone, door=stone_arch, stairs=stone
	var arch_baseline = pres_resolver.resolve_from_room_profile(crypt_room)
	assert(arch_baseline.floor_style == arch_style.FloorStyle.RUINED_STONE, "FAIL: Baseline floor must be RUINED_STONE")
	assert(arch_baseline.wall_style == arch_style.WallStyle.DARK_STONE, "FAIL: Baseline wall must be DARK_STONE")
	assert(arch_baseline.door_style == arch_style.DoorStyle.STONE_ARCH, "FAIL: Baseline door must be STONE_ARCH")
	assert(arch_baseline.stairs_style == arch_style.StairsStyle.STONE, "FAIL: Baseline stairs must be STONE")

	# Mutación JSON 1: Suelo a smooth_slabs, Muros a fortress_stone, Puerta a iron_gate, Escaleras a wood
	crypt_room.architecture.floor = &"smooth_slabs"
	crypt_room.architecture.walls = &"fortress_stone"
	crypt_room.architecture.door = &"iron_gate"
	crypt_room.architecture.stairs = &"wood"

	var arch_mutated_1 = pres_resolver.resolve_from_room_profile(crypt_room)
	assert(arch_mutated_1.floor_style == arch_style.FloorStyle.SMOOTH_SLABS, "FAIL: JSON mutation must yield SMOOTH_SLABS floor")
	assert(arch_mutated_1.wall_style == arch_style.WallStyle.FORTRESS_STONE, "FAIL: JSON mutation must yield FORTRESS_STONE wall")
	assert(arch_mutated_1.door_style == arch_style.DoorStyle.HEAVY_IRON, "FAIL: JSON mutation must yield HEAVY_IRON door")
	assert(arch_mutated_1.stairs_style == arch_style.StairsStyle.WOOD, "FAIL: JSON mutation must yield WOOD stairs")

	# Mutación JSON 2: Suelo a catacomb_dirt
	crypt_room.architecture.floor = &"catacomb_dirt"
	var arch_mutated_2 = pres_resolver.resolve_from_room_profile(crypt_room)
	assert(arch_mutated_2.floor_style == arch_style.FloorStyle.CATACOMB_DIRT, "FAIL: JSON mutation must yield CATACOMB_DIRT floor")

	# Restaurar valores
	crypt_room.architecture.floor = &"ruined_stone"
	crypt_room.architecture.walls = &"dark_stone"
	crypt_room.architecture.door = &"stone_arch"
	crypt_room.architecture.stairs = &"stone"
	print("  [OK] 2. Room architecture authority validated (floor, walls, door, stairs strictly governed by JSON).")
```

- [x] **Step 2: Ejecutar test y verificar que pasa al 100%**

---

### Task 3: Composition Authority Test (Counts & Tags Filtering)

**Files:**
- Modify: `tests/profiles/test_configuration_authority.gd`
- Consumes: `ProfileRoom.composition`, `DecorationCompositionResolver`, `DecorationCompositionPlanner`
- Produces: Verificación de que `min_count`, `max_count`, `asset_tags` y `forbidden_tags` gobiernan exactamente el conteo y tipo de props colocados.

- [x] **Step 1: Añadir prueba de autoridad de composición en `test_configuration_authority.gd`**

```gdscript
	# --- 3. COMPOSITION AUTHORITY TEST ---
	var comp_resolver := preload("res://src/presentation/decoration/decoration_composition_resolver.gd").new()
	var pal_resolver := preload("res://src/presentation/decoration/decoration_palette_resolver.gd").new()
	var geom_script := preload("res://src/presentation/geometry/presentation_room_geometry.gd")
	var ctx_script := preload("res://src/presentation/architecture/presentation_room_context.gd")

	var crypt_palette = pal_resolver.resolve_palette(1, int(_RoomPurposeScript.Type.CRYPT))

	# Geometría estándar 10x10
	var f_cells: Array[Vector2i] = []
	for x in range(2, 10):
		for y in range(2, 10):
			f_cells.append(Vector2i(x, y))
	var w_cells: Array[Vector2i] = []
	for x in range(1, 11):
		w_cells.append(Vector2i(x, 1))
		w_cells.append(Vector2i(x, 10))
	for y in range(2, 10):
		w_cells.append(Vector2i(1, y))
		w_cells.append(Vector2i(10, y))
	var test_geom = geom_script.new(1, Rect2i(1, 1, 10, 10), f_cells, w_cells, [Vector2i(5, 1)])

	var tomb_room_prof = bundle.get_room(&"tomb")
	var tomb_ctx = ctx_script.new(1, Rect2i(2, 2, 8, 8), int(_RoomPurposeScript.Type.TOMB), arch_baseline, 0, tomb_room_prof)

	# Prueba A: max_count = 1 en tumbas de pared
	tomb_room_prof.composition.secondary[0].min_count = 1
	tomb_room_prof.composition.secondary[0].max_count = 1
	tomb_room_prof.composition.secondary[1].min_count = 0
	tomb_room_prof.composition.secondary[1].max_count = 0
	if tomb_room_prof.composition.secondary.size() > 2:
		tomb_room_prof.composition.secondary[2].min_count = 0
		tomb_room_prof.composition.secondary[2].max_count = 0

	var comp_result_1 = comp_resolver.resolve_room_composition(tomb_ctx, crypt_palette, test_geom, null, 2026, 2.0)
	var tombstones_1: int = 0
	for d in comp_result_1.prop_directives:
		if d.prop_id == &"tombstone_classic_wall":
			tombstones_1 += 1
	assert(tombstones_1 == 1, "FAIL: max_count: 1 in JSON must produce exactly 1 wall tombstone, got %d" % tombstones_1)

	# Prueba B: max_count = 3 en tumbas de pared
	tomb_room_prof.composition.secondary[0].min_count = 3
	tomb_room_prof.composition.secondary[0].max_count = 3
	var comp_result_3 = comp_resolver.resolve_room_composition(tomb_ctx, crypt_palette, test_geom, null, 2026, 2.0)
	var tombstones_3: int = 0
	for d in comp_result_3.prop_directives:
		if d.prop_id == &"tombstone_classic_wall":
			tombstones_3 += 1
	assert(tombstones_3 == 3, "FAIL: max_count: 3 in JSON must produce 3 wall tombstones, got %d" % tombstones_3)

	# Prueba C: forbidden_tags excluye completamente un tipo de prop
	tomb_room_prof.composition.secondary[0].forbidden_tags.append(&"wall_decor")
	var comp_result_forbidden = comp_resolver.resolve_room_composition(tomb_ctx, crypt_palette, test_geom, null, 2026, 2.0)
	var tombstones_forbidden: int = 0
	for d in comp_result_forbidden.prop_directives:
		if d.prop_id == &"tombstone_classic_wall":
			tombstones_forbidden += 1
	assert(tombstones_forbidden == 0, "FAIL: Adding wall_decor to forbidden_tags in JSON must completely forbid wall tombstones")

	# Restaurar
	tomb_room_prof.composition.secondary[0].forbidden_tags.erase(&"wall_decor")
	tomb_room_prof.composition.secondary[0].min_count = 0
	tomb_room_prof.composition.secondary[0].max_count = 3
	print("  [OK] 3. Composition authority validated (counts, asset_tags and forbidden_tags strictly enforced).")
```

- [x] **Step 2: Ejecutar test y verificar que pasa al 100%**

---

### Task 4: Lighting & Relational Authority Test

**Files:**
- Modify: `tests/profiles/test_configuration_authority.gd`
- Consumes: `ProfileRoom.lighting`, `ProfileRoom.relationships`, `DecorationCompositionPlanner`
- Produces: Verificación de que `budget`, slots de luminarias y relaciones prop-fixture en JSON gobiernan las luminarias colocadas.

- [x] **Step 1: Añadir prueba de autoridad de iluminación y relaciones en `test_configuration_authority.gd`**

```gdscript
	# --- 4. LIGHTING & RELATIONSHIP AUTHORITY TEST ---
	# Prueba A: Presupuesto bajo (budget = 1.0) vs Presupuesto alto (budget = 6.0)
	tomb_room_prof.lighting.budget = 1.0
	tomb_room_prof.lighting.wall.min_count = 1
	tomb_room_prof.lighting.wall.max_count = 1
	tomb_room_prof.lighting.floor.min_count = 0
	tomb_room_prof.lighting.floor.max_count = 0
	tomb_room_prof.lighting.hanging.min_count = 0
	tomb_room_prof.lighting.hanging.max_count = 0

	var comp_light_low = comp_resolver.resolve_room_composition(tomb_ctx, crypt_palette, test_geom, null, 777, 2.0)
	var fixtures_low_count = comp_light_low.fixture_directives.size()
	assert(fixtures_low_count <= 1, "FAIL: Low budget (1.0) in JSON must strictly cap fixtures count, got %d" % fixtures_low_count)

	# Presupuesto alto (budget = 6.0)
	tomb_room_prof.lighting.budget = 6.0
	tomb_room_prof.lighting.wall.min_count = 2
	tomb_room_prof.lighting.wall.max_count = 3
	tomb_room_prof.lighting.floor.min_count = 2
	tomb_room_prof.lighting.floor.max_count = 2
	var comp_light_high = comp_resolver.resolve_room_composition(tomb_ctx, crypt_palette, test_geom, null, 777, 2.0)
	var fixtures_high_count = comp_light_high.fixture_directives.size()
	assert(fixtures_high_count > fixtures_low_count, "FAIL: Increasing lighting budget in JSON must increase placed fixtures count")

	# Prueba B: Relaciones prop-fixture gobernadas por JSON
	# Vaciar relationships -> ninguna vela relacional debe spawnear alrededor del sarcófago
	var saved_rels = tomb_room_prof.relationships.duplicate()
	tomb_room_prof.relationships.clear()
	var comp_no_rels = comp_resolver.resolve_room_composition(tomb_ctx, crypt_palette, test_geom, null, 1337, 2.0)
	var has_rel_candle: bool = false
	for f in comp_no_rels.fixture_directives:
		if f.role == 4: # FOCAL_COMPANION / RELATIONAL
			has_rel_candle = true
	assert(not has_rel_candle, "FAIL: Clearing relationships in JSON must prevent any relational companion fixtures")

	# Restaurar
	tomb_room_prof.relationships = saved_rels
	tomb_room_prof.lighting.budget = 4.0
	print("  [OK] 4. Lighting & Relationship authority validated (budget, slots and relations strictly enforced).")
	print("==================================================================")
	print("[PASS] ALL Configuration Authority tests passed successfully!")
	print("==================================================================")
```

- [x] **Step 2: Ejecutar test y verificar que pasa al 100%**

---

### Task 5: Suite Execution & Verification Handoff

**Files:**
- Test: `tests/profiles/test_configuration_authority.gd`
- Test: `tests/profiles/test_architecture_profile_driven.gd`
- Test: `tests/profiles/test_profile_driven_composition.gd`
- Test: `tests/presentation/crypt/test_crypt_profile.gd`
- Test: `tests/presentation/decoration/test_crypt_benchmark_100_seeds.gd`

- [x] **Step 1: Ejecutar la suite completa de pruebas de autoridad y regresión**
- [x] **Step 2: Verificar que 100 semillas de benchmark se ejecutan con 0 errores**

---

## Execution Choice

Two execution options:
1. **Subagent-Driven (recommended)** - Execute task-by-task with verification gates.
2. **Inline Execution** - Execute tasks directly in this session with checkpoints.
