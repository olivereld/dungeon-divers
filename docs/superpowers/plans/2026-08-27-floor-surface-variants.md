# Architectural Floor Surface Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar un sistema de variantes de superficie arquitectónica de suelo (*Floor Surface Variants*) declarativo y gobernado por perfiles JSON (`rooms/*.json`), con resolución determinista basada en pesos acumulativos por celda espacial y empaquetado continuo en mallas de cluster sin explosión de nodos.

**Architecture:** El sistema extiende la arquitectura arquitectónica existente (`ProfileRoomArchitecture` -> `ArchitecturalPresentationProfile` -> `FloorVariantResolver` -> `DungeonFloorGenerator`). Soporta tanto el formato legacy (`"floor": "catacomb_dirt"`) como el formato estructurado (`"floor": { "base": "catacomb_dirt", "variants": [...] }`). La resolución por celda es 100% determinista mediante PRNG derivado de `(master_seed, room_id, cell_pos)`.

**Tech Stack:** Godot 4.6.1 GDScript, `CellGrid`, `FloorTileConfig`, `FloorTilePattern`, `DungeonFloorGenerator`, `ProfileLoader`, `ProfileValidator`.

**Spec:** [docs/superpowers/plans/2026-08-27-floor-surface-variants.md](file:///c:/Users/olivereld/Documents/dungeon-divers/docs/superpowers/plans/2026-08-27-floor-surface-variants.md)

## Global Constraints
- Total retrocompatibilidad: `"floor": "catacomb_dirt"` sigue funcionando con 100% de probabilidad base.
- Autoridad de configuración estricta: los porcentajes/pesos y estilos provienen exclusivamente del JSON, sin constantes estéticas cableadas en GDScript.
- Eficiencia de renderizado: todas las baldosas de una sala (base y variantes) se integran en la misma `ArrayMesh` del `FloorSurfaceCluster` de la sala, preservando el batching (1 nodo de malla por sala).
- Determinismo estricto: misma semilla + misma sala + misma celda = misma variante siempre.

---

## File Structure & Responsibilities

1. `src/dungeon_generator/profiles/profile_floor_variant_policy.gd` (NEW)
   - Contrato de datos inmutable/puro para la política de variantes de suelo de una sala (`base_style`, `base_weight`, `variants: Array[Dictionary]`, `distribution_mode`).
2. `src/dungeon_generator/profiles/profile_room_architecture.gd` (MODIFY)
   - Actualizar `floor` para soportar `StringName` y enlazar `floor_variants: ProfileFloorVariantPolicy`.
3. `src/dungeon_generator/profiles/profile_loader.gd` (MODIFY)
   - Deserializar `"floor"` polimórficamente (StringName o Dictionary con `base` y `variants`).
4. `src/dungeon_generator/profiles/profile_validator.gd` (MODIFY)
   - Validar coherencia de `floor_variants` (estilos válidos en el registry de arquitectura, pesos >= 0, suma total > 0).
5. `src/presentation/architecture/architectural_presentation_profile.gd` (MODIFY)
   - Almacenar `floor_variants: ProfileFloorVariantPolicy`.
6. `src/presentation/architecture/presentation_profile_resolver.gd` (MODIFY)
   - Propagar `floor_variants` desde `ProfileRoomArchitecture` al resolver el perfil.
7. `src/floor_tile_generator/variants/floor_variant_resolver.gd` (NEW)
   - Resolvedor puro de variantes por celda `resolve_cell_style(cell_pos, room_seed, policy) -> ArchitecturalStyle.FloorStyle`.
8. `src/floor_tile_generator/facade/dungeon_floor_generator.gd` (MODIFY)
   - Integrar `FloorVariantResolver` en `generate_floor_for_partition` para resolver el patrón específico de cada celda y construir los descriptores correspondientes.
9. `resources/dungeon_profiles/rooms/crypt.json` & `royal_tomb.json` (MODIFY)
   - Declarar variantes de suelo ponderadas para Criptas y Tumbas Reales.

---

### Task 1: Contrato de Datos `ProfileFloorVariantPolicy`

**Files:**
- Create: `src/dungeon_generator/profiles/profile_floor_variant_policy.gd`
- Modify: `src/dungeon_generator/profiles/profile_room_architecture.gd:1-26`
- Test: `tests/profiles/test_floor_variant_data.gd`

**Interfaces:**
- Produces: `ProfileFloorVariantPolicy` con campos `enabled: bool`, `base_style: StringName`, `base_weight: float`, `variants: Array[Dictionary]`, `distribution_mode: StringName`, métodos `get_total_weight() -> float`, `to_dict() -> Dictionary`.

- [ ] **Step 1: Escribir el test fallido para el contrato de datos**

```gdscript
# tests/profiles/test_floor_variant_data.gd
extends SceneTree

const _PolicyScript = preload("res://src/dungeon_generator/profiles/profile_floor_variant_policy.gd")

func _init() -> void:
	print("--- Running test_floor_variant_data ---")
	var p = _PolicyScript.new(
		true,
		&"catacomb_dirt",
		80.0,
		[
			{ "style": &"ruined_stone", "weight": 15.0 },
			{ "style": &"cracked_dirt", "weight": 5.0 }
		]
	)
	assert(p.enabled, "Policy must be enabled")
	assert(p.base_style == &"catacomb_dirt", "Base style mismatch")
	assert(p.get_total_weight() == 100.0, "Total weight should be 100.0")
	print("  [OK] ProfileFloorVariantPolicy data contract verified")
	print("[PASS] test_floor_variant_data passed!")
	quit(0)
```

- [ ] **Step 2: Ejecutar el test para comprobar que falla**
`powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_floor_variant_data.gd"`

- [ ] **Step 3: Implementar `ProfileFloorVariantPolicy` y actualizar `ProfileRoomArchitecture`**
Crear `src/dungeon_generator/profiles/profile_floor_variant_policy.gd` y añadir `var floor_variants: _ProfileFloorVariantPolicyScript = null` en `ProfileRoomArchitecture`.

- [ ] **Step 4: Ejecutar el test para comprobar que pasa**
`powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_floor_variant_data.gd"`

---

### Task 2: Deserialización y Validación en `ProfileLoader` y `ProfileValidator`

**Files:**
- Modify: `src/dungeon_generator/profiles/profile_loader.gd:100-140`
- Modify: `src/dungeon_generator/profiles/profile_validator.gd:80-130`
- Test: `tests/profiles/test_floor_variant_profile_resolution.gd`

**Interfaces:**
- Consumes: `ProfileFloorVariantPolicy`, `ProfileRoomArchitecture`.
- Produces: `ProfileLoader._parse_floor_architecture(raw_floor) -> Dictionary/ProfileFloorVariantPolicy`, `ProfileValidator.validate(profile)`.

- [ ] **Step 1: Escribir el test fallido para deserialización y validación**

```gdscript
# tests/profiles/test_floor_variant_profile_resolution.gd
extends SceneTree

const _LoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _ValidatorScript = preload("res://src/dungeon_generator/profiles/profile_validator.gd")

func _init() -> void:
	print("--- Running test_floor_variant_profile_resolution ---")
	var loader = _LoaderScript.new()
	var validator = _ValidatorScript.new()

	var json_str = """{
		"schema_version": 2,
		"id": "tomb_test",
		"display_name": "Tomb Test",
		"architecture": {
			"floor": {
				"base": "catacomb_dirt",
				"variants": [
					{ "style": "ruined_stone", "weight": 15.0 },
					{ "style": "cracked_dirt", "weight": 5.0 }
				]
			},
			"walls": "dark_stone",
			"door": "stone_arch",
			"stairs": "stone"
		}
	}"""
	var room_prof = loader.parse_room_from_json_string(json_str)
	assert(room_prof != null, "Room profile parse failed")
	assert(room_prof.architecture.floor == &"catacomb_dirt", "Base floor mismatch")
	assert(room_prof.architecture.floor_variants != null, "Floor variants policy missing")
	assert(room_prof.architecture.floor_variants.variants.size() == 2, "Variants size mismatch")

	var val_res = validator.validate_room(room_prof)
	assert(val_res.is_valid, "Validation failed: %s" % str(val_res.diagnostics))
	print("  [OK] Floor variant parsing and validation passed")
	print("[PASS] test_floor_variant_profile_resolution passed!")
	quit(0)
```

- [ ] **Step 2: Ejecutar el test para verificar que falla**
`powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_floor_variant_profile_resolution.gd"`

- [ ] **Step 3: Implementar parser en `profile_loader.gd` y reglas de validación en `profile_validator.gd`**
Soportar parsing polimórfico (`String` vs `Dictionary`) y validar que `base` y `variants` existan en `architecture.json` o enum de estilos.

- [ ] **Step 4: Ejecutar el test para comprobar que pasa**
`powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_floor_variant_profile_resolution.gd"`

---

### Task 3: Resolvedor Determinista `FloorVariantResolver`

**Files:**
- Create: `src/floor_tile_generator/variants/floor_variant_resolver.gd`
- Test: `tests/floor/test_floor_variant_determinism.gd`

**Interfaces:**
- Produces: `FloorVariantResolver.resolve_cell_floor_style(cell_pos: Vector2i, room_seed: int, policy: ProfileFloorVariantPolicy, fallback_style: int) -> int` (retorna `ArchitecturalStyle.FloorStyle`).

- [ ] **Step 1: Escribir el test fallido para el resolvedor determinista**

```gdscript
# tests/floor/test_floor_variant_determinism.gd
extends SceneTree

const _ResolverScript = preload("res://src/floor_tile_generator/variants/floor_variant_resolver.gd")
const _PolicyScript = preload("res://src/dungeon_generator/profiles/profile_floor_variant_policy.gd")
const _ArchStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	print("--- Running test_floor_variant_determinism ---")
	var resolver = _ResolverScript.new()
	var policy = _PolicyScript.new(
		true,
		&"catacomb_dirt",
		80.0,
		[
			{ "style": &"ruined_stone", "weight": 20.0 }
		]
	)

	var run1: Array[int] = []
	var run2: Array[int] = []

	for x in range(10):
		for y in range(10):
			run1.append(resolver.resolve_cell_floor_style(Vector2i(x, y), 54321, policy, _ArchStyleScript.FloorStyle.CATACOMB_DIRT))

	for x in range(10):
		for y in range(10):
			run2.append(resolver.resolve_cell_floor_style(Vector2i(x, y), 54321, policy, _ArchStyleScript.FloorStyle.CATACOMB_DIRT))

	assert(run1 == run2, "Determinism failed across independent runs")

	var ruined_count: int = 0
	for st in run1:
		if st == _ArchStyleScript.FloorStyle.RUINED_STONE:
			ruined_count += 1

	assert(ruined_count > 5 and ruined_count < 35, "Ruined variant distribution out of expected bounds: %d/100" % ruined_count)
	print("  [OK] Floor variant resolution is 100% deterministic and follows weights")
	print("[PASS] test_floor_variant_determinism passed!")
	quit(0)
```

- [ ] **Step 2: Ejecutar el test para comprobar que falla**
`powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/floor/test_floor_variant_determinism.gd"`

- [ ] **Step 3: Implementar `FloorVariantResolver`**
Implementar muestreo con acumulador de pesos y hash determinista de celda.

- [ ] **Step 4: Ejecutar el test para comprobar que pasa**
`powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/floor/test_floor_variant_determinism.gd"`

---

### Task 4: Integración en `ArchitecturalPresentationProfile` y `DungeonFloorGenerator`

**Files:**
- Modify: `src/presentation/architecture/architectural_presentation_profile.gd:10-25`
- Modify: `src/presentation/architecture/presentation_profile_resolver.gd:50-70`
- Modify: `src/floor_tile_generator/facade/dungeon_floor_generator.gd:40-75`
- Test: `tests/floor/test_floor_surface_variants_integration.gd`

**Interfaces:**
- Consumes: `ArchitecturalPresentationProfile.floor_variants`, `FloorVariantResolver`, `FloorTilePattern`, `FloorSurfaceMeshBuilder`.
- Produces: `DungeonFloorGenerator.generate_floor_for_partition` con soporte de variantes por celda.

- [ ] **Step 1: Escribir el test de integración de generación de suelo con variantes**

```gdscript
# tests/floor/test_floor_surface_variants_integration.gd
extends SceneTree

const _DungeonFloorGenScript = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const _PartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const _RoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _ArchProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _PolicyScript = preload("res://src/dungeon_generator/profiles/profile_floor_variant_policy.gd")
const _ArchStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const _StyleResolverScript = preload("res://src/presentation/architecture/architectural_style_config_resolver.gd")

func _init() -> void:
	print("--- Running test_floor_surface_variants_integration ---")
	var floor_gen = _DungeonFloorGenScript.new()
	var partition = _PartitionScript.new()
	var style_resolver = _StyleResolverScript.new()

	var cells: Array[Vector2i] = []
	for x in range(10):
		for y in range(10):
			cells.append(Vector2i(x, y))

	var prof = _ArchProfileScript.new(
		_ArchStyleScript.FloorStyle.CATACOMB_DIRT,
		_ArchStyleScript.WallStyle.DARK_STONE
	)
	prof.floor_variants = _PolicyScript.new(
		true,
		&"catacomb_dirt",
		70.0,
		[
			{ "style": &"ruined_stone", "weight": 30.0 }
		]
	)

	var r_geom = _RoomGeomScript.new(1, Rect2i(0, 0, 10, 10), cells, [], [], prof)
	partition.add_room_geometry(r_geom)

	var res = floor_gen.generate_floor_for_partition(partition, style_resolver, null, 1337)
	assert(res != null, "Result cannot be null")
	assert(res.clusters.size() == 1, "Must generate 1 cluster")
	assert(res.clusters[0].mesh != null, "Cluster mesh must be built")
	assert(res.clusters[0].descriptors.size() > 0, "Descriptors must be generated")

	print("  [OK] Floor generation integrates cell-level surface variants into unified cluster mesh")
	print("[PASS] test_floor_surface_variants_integration passed!")
	quit(0)
```

- [ ] **Step 2: Ejecutar el test para comprobar que falla**
`powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/floor/test_floor_surface_variants_integration.gd"`

- [ ] **Step 3: Conectar `floor_variants` en `presentation_profile_resolver.gd` y `DungeonFloorGenerator`**
Integrar `FloorVariantResolver` en el bucle celda a celda de `generate_floor_for_partition`.

- [ ] **Step 4: Ejecutar el test para comprobar que pasa**
`powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/floor/test_floor_surface_variants_integration.gd"`

---

### Task 5: Actualización de Perfiles JSON y Tests de Autoridad de Configuración

**Files:**
- Modify: `resources/dungeon_profiles/rooms/crypt.json`
- Modify: `resources/dungeon_profiles/rooms/royal_tomb.json`
- Modify: `tests/profiles/test_configuration_authority.gd`

**Interfaces:**
- Consumes: Toda la cadena de perfiles y generador de suelo.
- Produces: Salas con variantes visuales de suelo gobernadas al 100% por JSON.

- [ ] **Step 1: Declarar variantes en `crypt.json` y `royal_tomb.json`**
Añadir `floor.base` y `floor.variants` con pesos de `ruined_stone` y `cracked_dirt`.

- [ ] **Step 2: Actualizar `test_configuration_authority.gd` para incluir autoridad de variantes de suelo**
Añadir aserciones comprobando que cambiar los pesos en el JSON de suelo modifica la distribución resultante sin alterar GDScript.

- [ ] **Step 3: Ejecutar suite de pruebas completa y benchmark de 100 semillas**
- `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_configuration_authority.gd"`
- `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_crypt_benchmark_100_seeds.gd"`

---

## Verification Plan

### Automated Tests
1. `tests/profiles/test_floor_variant_data.gd`: Valida el contrato inmutable de datos.
2. `tests/profiles/test_floor_variant_profile_resolution.gd`: Valida deserialización polimórfica y validación de esquemas JSON.
3. `tests/floor/test_floor_variant_determinism.gd`: Valida reproducibilidad 100% y distribución estadística de pesos.
4. `tests/floor/test_floor_surface_variants_integration.gd`: Valida que `DungeonFloorGenerator` construya la malla de baldosas con variantes.
5. `tests/profiles/test_configuration_authority.gd`: Valida que la configuración de variantes en JSON mande sobre el resultado final.
6. `tests/presentation/decoration/test_crypt_benchmark_100_seeds.gd`: Benchmark masivo de 100 semillas / 707 salas garantizando 0 regresiones.
