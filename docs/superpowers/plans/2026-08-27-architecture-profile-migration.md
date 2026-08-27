# Architecture Profile Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrar la definición arquitectónica (suelo, paredes, puertas y escaleras) de las salas de la mazmorra desde resoluciones hardcodeadas en GDScript (`PresentationProfileResolver`) a un modelo verdaderamente **profile-driven / data-driven** gobernado por `architecture.json` y el bloque `"architecture"` en cada `rooms/*.json`.

**Architecture:** 
1. `resources/dungeon_profiles/assets/architecture.json` define el catálogo formal de definiciones arquitectónicas (`floors`, `walls`, `doors`, `stairs`).
2. Cada archivo de sala `rooms/*.json` declara su intención arquitectónica en un bloque `"architecture": { "floor": "catacomb_dirt", "walls": "dark_stone", "door": "stone_arch", "stairs": "stone" }`.
3. `ProfileLoader` carga el catálogo arquitectónico en `AssetRegistry` y parsea `ProfileRoomArchitecture` dentro de `ProfileRoom`.
4. `PresentationProfileResolver` pasa de ejecutar `match purpose` hardcodeados a resolver `ArchitecturalPresentationProfile` a partir de `room_profile.architecture`, manteniendo compatibilidad hacia atrás cuando no se provea un perfil JSON.

**Tech Stack:** Godot 4.6, GDScript, JSON, `RefCounted`, suites de tests `SceneTree` ejecutadas en modo headless.

**Spec:** [User Request / Brainstorming Specification on Data-Driven Architecture Profiles]

## Global Constraints

- **Separación de Responsabilidades:** El JSON de la sala (`tomb.json`) define el QUÉ semántico (`"floor": "catacomb_dirt"`), mientras que el catálogo (`architecture.json`) define su implementación/generador (`"generator": "procedural"`, `"style": "catacomb_dirt"`).
- **Inmutabilidad y Pureza:** Los loaders, resolvers y validadores son `RefCounted` puros, deterministas y sin dependencias de nodos 3D.
- **Compatibilidad Retroactiva:** Si un `PresentationRoomContext` o llamada a `PresentationProfileResolver` no tiene `room_profile`, debe ejecutarse el fallback existente sin errores.
- **Validación Estricta:** `ProfileValidator` debe verificar que cada identificador en `architecture` de una sala exista en `AssetRegistry.architecture` o en los estilos conocidos.
- **Sin Hardcoding de Salas:** Queda prohibido añadir nuevos `match` por nombre o tipo de sala en GDScript para estilos arquitectónicos.

---

## File Structure & Responsibilities

| File Path | Responsibility |
|---|---|
| `resources/dungeon_profiles/assets/architecture.json` | Catálogo de assets arquitectónicos (`floors`, `walls`, `doors`, `stairs`). |
| `src/dungeon_generator/profiles/assets/asset_architecture_entry.gd` | Estructura de datos tipada para entradas de `architecture.json`. |
| `src/dungeon_generator/profiles/asset_registry.gd` | Registro en memoria de props, fixtures, materials y arquitectura. |
| `src/dungeon_generator/profiles/profile_room_architecture.gd` | Estructura tipada que almacena la configuración de arquitectura de una sala (`floor`, `walls`, `door`, `stairs`). |
| `src/dungeon_generator/profiles/profile_room.gd` | Modelo tipado de sala extendido con el campo `architecture`. |
| `src/dungeon_generator/profiles/profile_loader.gd` | Carga de `assets/architecture.json` y parseo del bloque `"architecture"` en salas. |
| `src/dungeon_generator/profiles/profile_validator.gd` | Validación de integridad referencial para entradas arquitectónicas. |
| `resources/dungeon_profiles/rooms/*.json` | 9 perfiles JSON de salas actualizados con sus bloques `"architecture"`. |
| `src/presentation/architecture/presentation_profile_resolver.gd` | Resolución de `ArchitecturalPresentationProfile` impulsada por `ProfileRoom.architecture`. |
| `tests/profiles/test_architecture_profile_driven.gd` | Suite de tests exhaustiva que valida la carga, validación y resolución profile-driven. |

---

## Task Decomposition

### Task 1: Asset Architecture Catalog (`architecture.json`, `AssetArchitectureEntry`, `AssetRegistry`)

**Files:**
- Create: `resources/dungeon_profiles/assets/architecture.json`
- Create: `src/dungeon_generator/profiles/assets/asset_architecture_entry.gd`
- Modify: `src/dungeon_generator/profiles/asset_registry.gd:1-45`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd:47-122`
- Test: `tests/profiles/test_architecture_profile_driven.gd`

**Interfaces:**
- Consumes: JSON parseado desde `base_path + "assets/architecture.json"`
- Produces: `AssetRegistry.architecture: Dictionary` (mapping `StringName -> AssetArchitectureEntry`) y métodos `register_architecture(entry)` / `get_architecture(id)` / `has_architecture(id)`.

- [ ] **Step 1: Crear archivo `tests/profiles/test_architecture_profile_driven.gd` con test que falla**

```gdscript
extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _AssetRegistryScript = preload("res://src/dungeon_generator/profiles/asset_registry.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_architecture_profile_driven ---")
	var loader := _ProfileLoaderScript.new()
	var assets: _AssetRegistryScript = loader.load_asset_registry()
	assert(assets != null, "FAIL: AssetRegistry must load")
	assert(assets.has_architecture(&"catacomb_dirt"), "FAIL: catacomb_dirt must be in architecture catalog")
	assert(assets.has_architecture(&"dark_stone"), "FAIL: dark_stone must be in architecture catalog")
	assert(assets.has_architecture(&"stone_arch"), "FAIL: stone_arch must be in architecture catalog")
	print("  [OK] Task 1: Architecture catalog loaded into AssetRegistry.")
	quit(0)
```

- [ ] **Step 2: Ejecutar test para verificar que falla**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_architecture_profile_driven.gd"`
Expected: FAIL (método `has_architecture` no existe en `AssetRegistry`).

- [ ] **Step 3: Crear `architecture.json`, `asset_architecture_entry.gd` y actualizar `asset_registry.gd` y `profile_loader.gd`**

`resources/dungeon_profiles/assets/architecture.json`:
```json
{
    "schema_version": 1,
    "floors": {
        "catacomb_dirt": { "category": "floor", "style": "catacomb_dirt", "generator": "procedural" },
        "ruined_stone": { "category": "floor", "style": "ruined_stone", "generator": "procedural" },
        "smooth_slabs": { "category": "floor", "style": "smooth_slabs", "generator": "procedural" },
        "cobblestone": { "category": "floor", "style": "cobblestone", "generator": "procedural" },
        "brick": { "category": "floor", "style": "brick", "generator": "procedural" },
        "temple_tiles": { "category": "floor", "style": "temple_tiles", "generator": "procedural" },
        "mine_rock": { "category": "floor", "style": "mine_rock", "generator": "procedural" },
        "generic_stone": { "category": "floor", "style": "generic_stone", "generator": "procedural" }
    },
    "walls": {
        "dark_stone": { "category": "wall", "style": "dark_stone", "generator": "procedural" },
        "fortress_stone": { "category": "wall", "style": "fortress_stone", "generator": "procedural" },
        "ancient_temple": { "category": "wall", "style": "ancient_temple", "generator": "procedural" },
        "rough_rock": { "category": "wall", "style": "rough_rock", "generator": "procedural" },
        "generic_stone": { "category": "wall", "style": "generic_stone", "generator": "procedural" }
    },
    "doors": {
        "stone_arch": { "category": "door", "style": "stone_arch", "generator": "procedural" },
        "iron_gate": { "category": "door", "style": "iron_gate", "generator": "procedural" },
        "temple_portal": { "category": "door", "style": "temple_portal", "generator": "procedural" },
        "wood_beam": { "category": "door", "style": "wood_beam", "generator": "procedural" },
        "generic_wood": { "category": "door", "style": "generic_wood", "generator": "procedural" }
    },
    "stairs": {
        "stone": { "category": "stairs", "style": "stone", "generator": "procedural" },
        "wood": { "category": "stairs", "style": "wood", "generator": "procedural" },
        "rough_rock": { "category": "stairs", "style": "rough_rock", "generator": "procedural" }
    }
}
```

`src/dungeon_generator/profiles/assets/asset_architecture_entry.gd`:
```gdscript
class_name AssetArchitectureEntry
extends RefCounted

## Entrada deserializada desde resources/dungeon_profiles/assets/architecture.json.

var id: StringName = &""
var category: StringName = &"" # "floor", "wall", "door", "stairs"
var style: StringName = &""
var generator: StringName = &"procedural" # "procedural", "external"
var scene_path: String = ""

func _init(
	p_id: StringName = &"",
	p_category: StringName = &"",
	p_style: StringName = &"",
	p_generator: StringName = &"procedural",
	p_scene: String = ""
) -> void:
	id = p_id
	category = p_category
	style = p_style
	generator = p_generator
	scene_path = p_scene
```

`src/dungeon_generator/profiles/asset_registry.gd`:
Añadir diccionario `architecture: Dictionary = {}`, y métodos `register_architecture(entry)`, `get_architecture(id)`, `has_architecture(id)`.

`src/dungeon_generator/profiles/profile_loader.gd`:
En `load_asset_registry()`, añadir la lectura y deserialización de `assets/architecture.json` iterando sobre `"floors"`, `"walls"`, `"doors"`, `"stairs"`.

- [x] **Step 4: Ejecutar test para verificar que pasa**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_architecture_profile_driven.gd"`
Expected: PASS (`[OK] Task 1: Architecture catalog loaded into AssetRegistry.`).

---

### Task 2: Typed Room Architecture Model (`ProfileRoomArchitecture` y `ProfileRoom`)

**Files:**
- Create: `src/dungeon_generator/profiles/profile_room_architecture.gd`
- Modify: `src/dungeon_generator/profiles/profile_room.gd:1-35`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd:205-305`
- Test: `tests/profiles/test_architecture_profile_driven.gd`

**Interfaces:**
- Produces: `ProfileRoomArchitecture` con propiedades `floor: StringName`, `walls: StringName`, `door: StringName`, `stairs: StringName`.
- `ProfileRoom.architecture: ProfileRoomArchitecture`.

- [x] **Step 1: Escribir test para deserialización de `ProfileRoom.architecture`**

Añadir al test `test_architecture_profile_driven.gd`:
```gdscript
	# Validar Task 2: ProfileRoom.architecture
	var tomb_room = loader.load_room("tomb.json")
	assert(tomb_room != null, "FAIL: tomb.json must load")
	assert(tomb_room.architecture != null, "FAIL: tomb_room must have architecture object")
	assert(tomb_room.architecture.floor == &"catacomb_dirt", "FAIL: tomb floor must be catacomb_dirt")
	assert(tomb_room.architecture.walls == &"dark_stone", "FAIL: tomb walls must be dark_stone")
	print("  [OK] Task 2: ProfileRoom.architecture loaded properly.")
```

- [x] **Step 2: Ejecutar test para verificar que falla**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_architecture_profile_driven.gd"`
Expected: FAIL (`tomb_room.architecture` is null).

- [x] **Step 3: Crear `ProfileRoomArchitecture` y actualizar `profile_room.gd` y `profile_loader.gd`**

`src/dungeon_generator/profiles/profile_room_architecture.gd`:
```gdscript
class_name ProfileRoomArchitecture
extends RefCounted

## Configuración arquitectónica de la sala deserializada desde el bloque "architecture" en rooms/*.json.

var floor: StringName = &""
var walls: StringName = &""
var door: StringName = &""
var stairs: StringName = &""

func _init(
	p_floor: StringName = &"",
	p_walls: StringName = &"",
	p_door: StringName = &"",
	p_stairs: StringName = &""
) -> void:
	floor = p_floor
	walls = p_walls
	door = p_door
	stairs = p_stairs
```

`src/dungeon_generator/profiles/profile_room.gd`:
Añadir `var architecture: _ProfileRoomArchitectureScript = null` al constructor e inicialización.

`src/dungeon_generator/profiles/profile_loader.gd`:
En `load_room(filename)`:
```gdscript
	var arch_raw = dict.get("architecture", {})
	var architecture := _ProfileRoomArchitectureScript.new(
		StringName(arch_raw.get("floor", "")),
		StringName(arch_raw.get("walls", arch_raw.get("wall", ""))),
		StringName(arch_raw.get("door", arch_raw.get("doors", ""))),
		StringName(arch_raw.get("stairs", ""))
	)
```
Y pasar `architecture` a `_ProfileRoomScript.new(...)`.

Actualizar `resources/dungeon_profiles/rooms/tomb.json` con el bloque:
```json
    "architecture": {
        "floor": "catacomb_dirt",
        "walls": "dark_stone",
        "door": "stone_arch",
        "stairs": "stone"
    },
```

- [x] **Step 4: Ejecutar test para verificar que pasa**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_architecture_profile_driven.gd"`
Expected: PASS (`[OK] Task 2: ProfileRoom.architecture loaded properly.`).

---

### Task 3: Profile Validator Integration (`ProfileValidator`)

**Files:**
- Modify: `src/dungeon_generator/profiles/profile_validator.gd:1-120`
- Test: `tests/profiles/test_architecture_profile_driven.gd`

**Interfaces:**
- Consumes: `ProfileBundle.assets.architecture` y `ProfileBundle.rooms[k].architecture`
- Produces: Errores/warnings en `ValidationResult` si una sala referencia estilos arquitectónicos no registrados.

- [x] **Step 1: Escribir test de validación arquitectónica en `test_architecture_profile_driven.gd`**

```gdscript
	# Validar Task 3: ProfileValidator
	var validator := _ProfileValidatorScript.new()
	var bundle = loader.load_full_archetype_bundle("mausoleum")
	var result = validator.validate_bundle(bundle)
	assert(result.is_valid(), "FAIL: Mausoleum bundle validation failed: %s" % str(result.errors))
	print("  [OK] Task 3: ProfileValidator verified architectural references.")
```

- [x] **Step 2: Ejecutar test y verificar comportamiento**
- [x] **Step 3: Implementar validación de `room.architecture` en `profile_validator.gd`**

Verificar que:
1. `assets.architecture` no esté vacío.
2. Para cada sala en `bundle.rooms`:
   - Si `room.architecture.floor != &""`, verificar que `assets.has_architecture(room.architecture.floor)`.
   - Si `room.architecture.walls != &""`, verificar que `assets.has_architecture(room.architecture.walls)`.
   - Si `room.architecture.door != &""`, verificar que `assets.has_architecture(room.architecture.door)`.
   - Si `room.architecture.stairs != &""`, verificar que `assets.has_architecture(room.architecture.stairs)`.

- [x] **Step 4: Ejecutar test y verificar que pasa**

---

### Task 4: Migrar Todos los Perfiles JSON de Salas (`rooms/*.json`)

**Files:**
- Modify: `resources/dungeon_profiles/rooms/entrance.json`
- Modify: `resources/dungeon_profiles/rooms/hall.json`
- Modify: `resources/dungeon_profiles/rooms/chamber.json`
- Modify: `resources/dungeon_profiles/rooms/crypt.json`
- Modify: `resources/dungeon_profiles/rooms/catacomb.json`
- Modify: `resources/dungeon_profiles/rooms/tomb.json`
- Modify: `resources/dungeon_profiles/rooms/royal_tomb.json`
- Modify: `resources/dungeon_profiles/rooms/mortuary.json`
- Modify: `resources/dungeon_profiles/rooms/sacristy.json`
- Test: `tests/profiles/test_architecture_profile_driven.gd`

**Detalle de Mapeos por Sala:**
- `entrance.json`: `"floor": "smooth_slabs", "walls": "dark_stone", "door": "stone_arch", "stairs": "stone"`
- `hall.json`: `"floor": "smooth_slabs", "walls": "dark_stone", "door": "stone_arch", "stairs": "stone"`
- `chamber.json`: `"floor": "smooth_slabs", "walls": "dark_stone", "door": "stone_arch", "stairs": "stone"`
- `crypt.json`: `"floor": "ruined_stone", "walls": "dark_stone", "door": "stone_arch", "stairs": "stone"`
- `catacomb.json`: `"floor": "catacomb_dirt", "walls": "dark_stone", "door": "stone_arch", "stairs": "stone"`
- `tomb.json`: `"floor": "catacomb_dirt", "walls": "dark_stone", "door": "stone_arch", "stairs": "stone"`
- `royal_tomb.json`: `"floor": "smooth_slabs", "walls": "dark_stone", "door": "stone_arch", "stairs": "stone"`
- `mortuary.json`: `"floor": "ruined_stone", "walls": "dark_stone", "door": "stone_arch", "stairs": "stone"`
- `sacristy.json`: `"floor": "smooth_slabs", "walls": "dark_stone", "door": "stone_arch", "stairs": "stone"`

- [x] **Step 1: Actualizar los 9 archivos JSON de sala añadiendo el bloque `"architecture"`**
- [x] **Step 2: Escribir test que carga los 9 perfiles y valida que cada uno tiene su arquitectura definida**
- [x] **Step 3: Ejecutar test y verificar que pasa al 100%**

---

### Task 5: Profile-Driven `PresentationProfileResolver` Integration

**Files:**
- Modify: `src/presentation/architecture/architectural_style.gd:1-80`
- Modify: `src/presentation/architecture/presentation_profile_resolver.gd:1-182`
- Modify: `src/presentation/architecture/presentation_context_builder.gd:20-50`
- Test: `tests/profiles/test_architecture_profile_driven.gd`
- Test: `tests/presentation/crypt/test_crypt_profile.gd`

**Interfaces:**
- `PresentationProfileResolver.resolve_from_room_profile(p_room_profile: ProfileRoom, fallback_archetype: int = 0, fallback_purpose: int = 0) -> ArchitecturalPresentationProfile`
- Mapeo de string a enum en `ArchitecturalStyle`:
  - `floor_from_name(name_str: String) -> FloorStyle`
  - `wall_from_name(name_str: String) -> WallStyle`
  - `door_from_name(name_str: String) -> DoorStyle`
  - `stairs_from_name(name_str: String) -> StairsStyle`

- [x] **Step 1: Añadir funciones de conversión string->enum en `architectural_style.gd`**
- [x] **Step 2: Escribir test en `test_architecture_profile_driven.gd` que resuelve perfiles desde `ProfileRoom`**
- [x] **Step 3: Implementar `resolve_from_room_profile` en `presentation_profile_resolver.gd` y conectarlo en `presentation_context_builder.gd`**
- [x] **Step 4: Ejecutar tests y verificar resolución automática desde JSON**

---

### Task 6: Comprehensive Regression & Verification

**Files:**
- Test: `tests/profiles/test_architecture_profile_driven.gd`
- Test: `tests/profiles/test_profile_driven_composition.gd`
- Test: `tests/presentation/crypt/test_crypt_profile.gd`
- Test: `tests/presentation/decoration/composition/test_crypt_vertical_slice_e2e.gd`
- Test: `tests/presentation/decoration/test_crypt_benchmark_100_seeds.gd`

- [x] **Step 1: Ejecutar la suite completa de tests de perfiles y presentación**
- [x] **Step 2: Verificar que cambiar `"floor": "smooth_slabs"` en un JSON modifica la arquitectura resultante sin tocar GDScript**
- [x] **Step 3: Validar que 100 semillas de benchmark se ejecutan con 0 errores**

---

## Execution Choice

Two execution options:
1. **Subagent-Driven (recommended)** - Execute task-by-task with verification gates.
2. **Inline Execution** - Execute tasks directly in this session with checkpoints.
