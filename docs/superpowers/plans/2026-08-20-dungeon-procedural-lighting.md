# Iluminación Procedural 3D para Mazmorras (Dungeon Lighting Module) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar un sistema modular, determinista y desacoplado de iluminación procedural 3D para mazmorras (`src/dungeon_lighting/`), que analice habitaciones y pasillos de `DungeonSemanticResult`, calcule posiciones de antorchas en paredes con espaciado inteligente y genere luces `OmniLight3D` con modulación de parpadeo orgánico (*flicker*) sin alterar la geometría base ni el ciclo de vida de la mazmorra.

**Architecture:** 
- **Capa de Configuración & Datos (Pure Data):** `DungeonLightingConfig`, `LightingProfile`, `LightPlacement`, `LightingResult`.
- **Capa de Planificación (Pure Logic / 0 Nodes):** `WallLightCandidateFinder` detecta muros libres descartando puertas y esquinas; `RoomLightPlanner` calcula densidad por área y espaciado mínimo; `CorridorLightPlanner` distribuye antorchas en tramos rectos largos y giros clave.
- **Capa de Fachada (Facade):** `DungeonLightingGenerator` orquesta la generación determinista a partir de semillas derivadas sin instanciar `Node3D`.
- **Capa de Presentación (3D Spawner):** `DungeonLightSpawner` materializa la jerarquía `Lighting/RoomLights` y `Lighting/CorridorLights` con `Torch` y `OmniLight3D`; `TorchLightController` modula la energía lumínica con `FastNoiseLite` continuo.

**Tech Stack:** Godot 4.6 (Forward+), GDScript tipado estricto, `OmniLight3D`, `FastNoiseLite`, `DungeonSemanticResult`.

**Spec:** Especificación de arquitectura modular de iluminación de mazmorra basada en evaluación semántica y colocación en paredes.

## Global Constraints
- `DungeonLightingGenerator` y todos los planners deben ser 100% libres de `Node3D` (ejecutables en modo headless).
- No mutar `CellGrid`, `RoomData`, `CorridorPath` ni `DoorPair` (solo lectura).
- No colocar luces sobre puertas (`DoorPair`) ni en esquinas conflictivas.
- Respetar la semilla de generación mediante derivación determinista (`DungeonSeedFactory` o hash de ID de sala/corredor).
- La presentación debe integrarse en el `StagingRoot` de `DungeonPresentationBuilder` antes del intercambio atómico (*Atomic Swap*).

---

## File Structure

```text
src/dungeon_lighting/
├── config/
│   ├── dungeon_lighting_config.gd
│   └── lighting_profile.gd
│
├── data/
│   ├── light_placement.gd
│   └── lighting_result.gd
│
├── planning/
│   ├── wall_light_candidate_finder.gd
│   ├── room_light_planner.gd
│   └── corridor_light_planner.gd
│
├── presentation/
│   ├── torch_light_controller.gd
│   └── dungeon_light_spawner.gd
│
└── facade/
    └── dungeon_lighting_generator.gd
```

---

## Tasks

### Task 1: Contratos de Datos y Configuración (`LightPlacement`, `LightingResult`, `DungeonLightingConfig`, `LightingProfile`)

**Files:**
- Create: `src/dungeon_lighting/data/light_placement.gd`
- Create: `src/dungeon_lighting/data/lighting_result.gd`
- Create: `src/dungeon_lighting/config/dungeon_lighting_config.gd`
- Create: `src/dungeon_lighting/config/lighting_profile.gd`
- Test: `tests/test_lighting_contracts.gd`

**Interfaces:**
- `LightPlacement`: `light_id: int`, `cell: Vector2i`, `wall_side: int` (NORTH=0, SOUTH=1, EAST=2, WEST=3), `room_id: int`, `corridor_id: int`, `kind: StringName` (`&"torch"`), `priority: float`, `world_offset: Vector3`.
- `LightingResult`: `placements: Array[LightPlacement]`, `diagnostics: Array[Dictionary]`, `seed_used: int`.
- `DungeonLightingConfig`: `enabled: bool`, `min_lights_per_room: int`, `max_lights_per_room: int`, `room_area_per_light: float`, `min_light_spacing: float`, `corridor_lighting_enabled: bool`, `corridor_min_length: int`, `corridor_spacing: int`.
- `LightingProfile`: `light_color: Color`, `energy: float`, `omni_range: float`, `shadow_enabled: bool`, `flicker_enabled: bool`, `flicker_amplitude: float`, `flicker_speed: float`, `torch_scene: PackedScene`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_lighting_contracts.gd
extends SceneTree

const LightPlacement = preload("res://src/dungeon_lighting/data/light_placement.gd")
const LightingResult = preload("res://src/dungeon_lighting/data/lighting_result.gd")
const DungeonLightingConfig = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd")
const LightingProfile = preload("res://src/dungeon_lighting/config/lighting_profile.gd")

func _init() -> void:
	print("--- Running test_lighting_contracts ---")
	var p := LightPlacement.new()
	p.light_id = 1
	p.cell = Vector2i(10, 15)
	p.wall_side = 0
	p.room_id = 3
	p.kind = &"torch"
	assert(p.cell == Vector2i(10, 15), "LightPlacement cell ok")

	var res := LightingResult.new()
	res.placements.append(p)
	assert(res.placements.size() == 1, "LightingResult placements ok")

	var cfg := DungeonLightingConfig.new()
	assert(cfg.enabled == true, "Config enabled by default")
	assert(cfg.min_lights_per_room == 1, "min_lights_per_room ok")

	var prof := LightingProfile.new()
	assert(prof.light_color != Color.BLACK, "Profile has default color")
	assert(prof.flicker_enabled == true, "Profile has flicker enabled")

	print("[PASS] test_lighting_contracts")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_lighting_contracts.gd"`
Expected: FAIL (files not found)

- [ ] **Step 3: Implement data and config classes**
Implement `LightPlacement`, `LightingResult`, `DungeonLightingConfig`, and `LightingProfile`.

- [ ] **Step 4: Run test to verify it passes**
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_lighting_contracts.gd"`
Expected: PASS

---

### Task 2: Buscador de Candidatos en Muros (`WallLightCandidateFinder`)

**Files:**
- Create: `src/dungeon_lighting/planning/wall_light_candidate_finder.gd`
- Test: `tests/test_wall_light_candidates.gd`

**Interfaces:**
- `find_room_wall_candidates(room: RoomData, grid: CellGrid, door_pairs: Array[DoorPair]) -> Array[LightPlacement]`
- `find_corridor_wall_candidates(corridor: CorridorPath, grid: CellGrid) -> Array[LightPlacement]`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_wall_light_candidates.gd
extends SceneTree

const WallLightCandidateFinder = preload("res://src/dungeon_lighting/planning/wall_light_candidate_finder.gd")
const CellGrid = preload("res://src/dungeon_generator/core/cell_grid.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DoorPair = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const RoomEntrance = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

func _init() -> void:
	print("--- Running test_wall_light_candidates ---")
	var grid := CellGrid.new(20, 20)
	var room := RoomData.new(1, Rect2i(4, 4, 6, 6), RoomData.RoomType.NORMAL)
	for y in range(4, 10):
		for x in range(4, 10):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.ROOM_FLOOR, 1)

	var door_ent := RoomEntrance.new(Vector2i(7, 4), RoomEntrance.NORTH, 1)
	var door_p := DoorPair.new(door_ent, null, Vector2i(7, 4), Vector2i(7, 3), 0.0)

	var finder := WallLightCandidateFinder.new()
	var candidates = finder.find_room_wall_candidates(room, grid, [door_p])

	assert(candidates.size() > 0, "Candidates found on room walls")
	for c in candidates:
		assert(c.cell != Vector2i(7, 4), "Door position excluded from candidates")
		assert(grid.is_room_floor(c.cell), "Candidate must be a walkable room floor cell against a wall")

	print("[PASS] test_wall_light_candidates")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_wall_light_candidates.gd"`
Expected: FAIL

- [ ] **Step 3: Implement `WallLightCandidateFinder`**
Implement detection of perimeter cells adjacent to solid walls, filtering out door cells, corner pinch points, and computing correct `wall_side`.

- [ ] **Step 4: Run test to verify it passes**
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_wall_light_candidates.gd"`
Expected: PASS

---

### Task 3: Planificadores de Iluminación de Habitaciones y Corredores (`RoomLightPlanner`, `CorridorLightPlanner`)

**Files:**
- Create: `src/dungeon_lighting/planning/room_light_planner.gd`
- Create: `src/dungeon_lighting/planning/corridor_light_planner.gd`
- Test: `tests/test_room_and_corridor_light_planners.gd`

**Interfaces:**
- `RoomLightPlanner.plan_room_lights(room: RoomData, candidates: Array[LightPlacement], config: DungeonLightingConfig, seed_val: int) -> Array[LightPlacement]`
- `CorridorLightPlanner.plan_corridor_lights(corridor: CorridorPath, candidates: Array[LightPlacement], config: DungeonLightingConfig, seed_val: int) -> Array[LightPlacement]`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_room_and_corridor_light_planners.gd
extends SceneTree

const RoomLightPlanner = preload("res://src/dungeon_lighting/planning/room_light_planner.gd")
const CorridorLightPlanner = preload("res://src/dungeon_lighting/planning/corridor_light_planner.gd")
const DungeonLightingConfig = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd")
const LightPlacement = preload("res://src/dungeon_lighting/data/light_placement.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const CorridorPath = preload("res://src/dungeon_generator/core/data/corridor_path.gd")

func _init() -> void:
	print("--- Running test_room_and_corridor_light_planners ---")
	var config := DungeonLightingConfig.new()
	config.min_lights_per_room = 2
	config.max_lights_per_room = 4
	config.min_light_spacing = 3.0

	var room := RoomData.new(1, Rect2i(2, 2, 8, 8), RoomData.RoomType.NORMAL)
	var candidates: Array[LightPlacement] = []
	# Generar candidatos en 4 paredes
	for x in range(3, 9):
		var p1 := LightPlacement.new()
		p1.cell = Vector2i(x, 2)
		p1.room_id = 1
		p1.wall_side = 0
		candidates.append(p1)
		var p2 := LightPlacement.new()
		p2.cell = Vector2i(x, 9)
		p2.room_id = 1
		p2.wall_side = 1
		candidates.append(p2)

	var room_planner := RoomLightPlanner.new()
	var selected_room = room_planner.plan_room_lights(room, candidates, config, 12345)
	assert(selected_room.size() >= 2 and selected_room.size() <= 4, "Room lights count within min/max")
	# Validar espaciado
	for i in range(selected_room.size()):
		for j in range(i + 1, selected_room.size()):
			var d: float = selected_room[i].cell.distance_to(selected_room[j].cell)
			assert(d >= config.min_light_spacing - 0.01, "Spacing constraint met between lights")

	# Validar corredor corto vs largo
	var corr_planner := CorridorLightPlanner.new()
	var short_corr := CorridorPath.new("1-2", 1, 2)
	short_corr.carved_cells = [Vector2i(1,1), Vector2i(1,2), Vector2i(1,3)]
	var short_lights = corr_planner.plan_corridor_lights(short_corr, [], config, 12345)
	assert(short_lights.is_empty(), "Short corridor has 0 lights")

	print("[PASS] test_room_and_corridor_light_planners")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_room_and_corridor_light_planners.gd"`
Expected: FAIL

- [ ] **Step 3: Implement `RoomLightPlanner` and `CorridorLightPlanner`**
Implement Poisson/greedy spacing selection, area-based target count, and corridor turn/length pacing.

- [ ] **Step 4: Run test to verify it passes**
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_room_and_corridor_light_planners.gd"`
Expected: PASS

---

### Task 4: Fachada y Determinismo (`DungeonLightingGenerator`)

**Files:**
- Create: `src/dungeon_lighting/facade/dungeon_lighting_generator.gd`
- Test: `tests/test_lighting_determinism.gd`

**Interfaces:**
- `DungeonLightingGenerator.generate_lighting(semantic_result: DungeonSemanticResult, config: DungeonLightingConfig, seed_val: int) -> LightingResult`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_lighting_determinism.gd
extends SceneTree

const DungeonLightingGenerator = preload("res://src/dungeon_lighting/facade/dungeon_lighting_generator.gd")
const DungeonLightingConfig = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd")
const DungeonPipeline = preload("res://src/dungeon_generator/core/pipeline/dungeon_pipeline.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")

func _init() -> void:
	print("--- Running test_lighting_determinism ---")
	var d_cfg := DungeonConfig.new()
	d_cfg.seed = 998877
	d_cfg.use_fixed_seed = true

	var pipeline := DungeonPipeline.new()
	var d_res = pipeline.generate(d_cfg)
	var sem_orch := SemanticOrchestrator.new()
	var sem_res = sem_orch.generate_semantics(d_res, d_cfg)

	var l_cfg := DungeonLightingConfig.new()
	var gen := DungeonLightingGenerator.new()

	var run1 = gen.generate_lighting(sem_res, l_cfg, 998877)
	var run2 = gen.generate_lighting(sem_res, l_cfg, 998877)

	assert(run1.placements.size() == run2.placements.size(), "Exact placement count matches on same seed")
	for i in range(run1.placements.size()):
		assert(run1.placements[i].cell == run2.placements[i].cell, "Exact cell matches on same seed")
		assert(run1.placements[i].wall_side == run2.placements[i].wall_side, "Exact wall side matches")

	var run_diff = gen.generate_lighting(sem_res, l_cfg, 112233)
	print("Run 1 count: %d, Run Diff count: %d" % [run1.placements.size(), run_diff.placements.size()])

	print("[PASS] test_lighting_determinism")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_lighting_determinism.gd"`
Expected: FAIL

- [ ] **Step 3: Implement `DungeonLightingGenerator`**
Integrate `WallLightCandidateFinder`, `RoomLightPlanner`, and `CorridorLightPlanner` with deterministic seed derivation per room/corridor.

- [ ] **Step 4: Run test to verify it passes**
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_lighting_determinism.gd"`
Expected: PASS

---

### Task 5: Capa de Presentación (`TorchLightController`, `DungeonLightSpawner`) e Integración E2E

**Files:**
- Create: `src/dungeon_lighting/presentation/torch_light_controller.gd`
- Create: `src/dungeon_lighting/presentation/dungeon_light_spawner.gd`
- Modify: `src/dungeon_generator/config/dungeon_config.gd` (Add `@export var lighting_config: Resource = null`)
- Modify: `src/dungeon_generator/presentation/biome_profile.gd` (Add `@export var lighting_profile: Resource = null`)
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd` (Orchestrate lighting spawner in StagingRoot)
- Test: `tests/test_dungeon_lighting_spawner_e2e.gd`

**Interfaces:**
- `TorchLightController`: Modula `omni_light.light_energy` en `_process(delta)` usando `FastNoiseLite` continuo a partir de `base_energy`, `flicker_amplitude`, `flicker_speed`.
- `DungeonLightSpawner.spawn_lighting(lighting_result: LightingResult, staging_root: Node3D, profile: LightingProfile, tile_size: float)`: Crea `Lighting/RoomLights` y `Lighting/CorridorLights` con `OmniLight3D` + antorcha procedural/malla.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_dungeon_lighting_spawner_e2e.gd
extends SceneTree

const DungeonPresentationBuilder = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const DungeonPipeline = preload("res://src/dungeon_generator/core/pipeline/dungeon_pipeline.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const BiomeProfile = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("--- Running test_dungeon_lighting_spawner_e2e ---")
	var config := DungeonConfig.new()
	config.seed = 45678
	var biome := BiomeProfile.new()

	var pipeline := DungeonPipeline.new()
	var d_res = pipeline.generate(config)
	var sem_orch := SemanticOrchestrator.new()
	var sem_res = sem_orch.generate_semantics(d_res, config)

	var builder := DungeonPresentationBuilder.new()
	var pres_res = builder.build_presentation(sem_res, null, biome, config)

	assert(pres_res.success == true, "Presentation build success")
	var staging = pres_res.presentation_root
	assert(staging != null, "Presentation root exists")

	var lighting_node = staging.get_node_or_null("Lighting")
	assert(lighting_node != null, "Lighting node exists in hierarchy")
	assert(lighting_node.has_node("RoomLights"), "RoomLights container exists")
	assert(lighting_node.has_node("CorridorLights"), "CorridorLights container exists")

	var total_omnis: int = 0
	for r_light in lighting_node.get_node("RoomLights").get_children():
		var omni = r_light.get_node_or_null("OmniLight3D")
		if omni != null:
			total_omnis += 1
			assert(omni.light_energy > 0.0, "OmniLight has positive energy")

	assert(total_omnis > 0, "Room OmniLights spawned successfully")
	staging.free()

	print("[PASS] test_dungeon_lighting_spawner_e2e")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_dungeon_lighting_spawner_e2e.gd"`
Expected: FAIL

- [ ] **Step 3: Implement `TorchLightController`, `DungeonLightSpawner`, and connect into `DungeonPresentationBuilder`**
Implement the presentation spawner, noise flicker controller, and wire it into the staging root before atomic swap.

- [ ] **Step 4: Run test to verify it passes**
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_dungeon_lighting_spawner_e2e.gd"`
Expected: PASS

---

## Verification Plan

### Automated Tests
```bash
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_lighting_contracts.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_wall_light_candidates.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_room_and_corridor_light_planners.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_lighting_determinism.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_dungeon_lighting_spawner_e2e.gd
```

### Manual Verification
1. Abrir la escena principal:
   ```bash
   Godot_v4.6.1-stable_win64.exe res://scenes/dungeon/dungeon_level.tscn
   ```
2. Presionar **"🎮 Generar Mazmorra 3D"** (o barra espaciadora):
   - La mazmorra estará en una atmósfera oscura e inmersiva.
   - Las antorchas iluminarán cálidamente las habitaciones y los pasillos largos desde las paredes.
   - El parpadeo de las antorchas (*flicker*) será orgánico y suave gracias al controlador de ruido continuo.
