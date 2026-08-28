# Data-Driven Destruction System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a completely decoupled, pure data-driven Destruction System that manages destructible props/fixtures via JSON definitions, components, and events without polluting procedural generation logic.

**Architecture:** 
Decoration and procedural generation determine what objects exist and where they spawn. The Destruction Module independently decides if an object is destructible, how it takes damage, when it changes state (INTACT -> DAMAGED -> CRITICAL -> DESTROYED), and emits events for audio, VFX, replacement, lighting, or gameplay reactions.

**Tech Stack:** Godot 4.6.1 GDScript, JSON schemas, typed contracts, headless Godot unit test runner.

**Spec:** User spec defined in conversation checkpoint: `src/destruction/` subsystem with `destruction.json` asset profile.

## Global Constraints
- **Decoupling Rule:** Zero destruction logic inside `DecorationCompositionPlanner`, `PropAssetRegistry`, or procedural geometry builders.
- **Data-Driven Rule:** Zero hardcoded IDs (`if prop_id == "urn"` is strictly forbidden). All properties (durability, modes, replacements, debris) are loaded from `resources/dungeon_profiles/assets/destruction.json`.
- **Non-Destructive Modes:** Support `BREAK`, `COLLAPSE`, `EXTINGUISH`, `REPLACE`, `DISABLE` (e.g. candles extinguish lighting without `queue_free`).
- **Event-Driven:** Systems communicate through `DestructionEvent` / signals; Destruction never directly mutates Navigation or Audio systems.
- **Test Discipline:** Every task must contain failing and passing headless Godot tests.

---

### File Structure Map

```text
resources/
└── dungeon_profiles/
    └── assets/
        └── destruction.json                                     [NEW] Data definitions for destructibles

src/
└── destruction/
    ├── core/
    │   ├── destruction_mode.gd                                  [NEW] Enum (BREAK, COLLAPSE, EXTINGUISH, REPLACE, DISABLE)
    │   ├── destruction_state.gd                                 [NEW] Enum (INTACT, DAMAGED, CRITICAL, DESTROYED)
    │   ├── destruction_hit.gd                                    [NEW] RefCounted hit payload (damage, type, pos, dir, source)
    │   ├── destructible_definition.gd                           [NEW] Typed Resource/RefCounted parsed from JSON
    │   └── destruction_event.gd                                 [NEW] Event emitted on damage/state/destruction
    │
    ├── runtime/
    │   ├── destruction_registry.gd                              [NEW] Lookup: asset_id / prop_id -> DestructibleDefinition
    │   ├── destruction_component.gd                             [NEW] Node component attached to destructible Node3D instances
    │   ├── destruction_binder.gd                                [NEW] Attaches component to spawned props/fixtures if registered
    │   └── destruction_service.gd                               [NEW] Runtime coordinator & query manager
    │
    └── integration/
        └── destruction_prop_spawner_adapter.gd                  [NEW] Connects PropSpawner with DestructionBinder cleanly

tests/
└── destruction/
    ├── test_destruction_json_schema.gd                          [NEW] Validates destruction.json parsing and typing
    ├── test_destruction_component_lifecycle.gd                  [NEW] Validates hits, durability, state transitions
    ├── test_destruction_modes_benchmark.gd                     [NEW] Benchmark: Urn (BREAK), Skull Pile (COLLAPSE), Candles (EXTINGUISH)
    └── test_destruction_pipeline_integration.gd                [NEW] E2E integration test with room generation and prop spawning
```

---

### Task 1: Create `destruction.json` and Core Enums

**Files:**
- Create: `resources/dungeon_profiles/assets/destruction.json`
- Create: `src/destruction/core/destruction_mode.gd`
- Create: `src/destruction/core/destruction_state.gd`
- Test: `tests/destruction/test_destruction_json_schema.gd`

**Interfaces:**
- Produces: `DestructionMode.Mode` (`BREAK`, `COLLAPSE`, `EXTINGUISH`, `REPLACE`, `DISABLE`), `DestructionState.State` (`INTACT`, `DAMAGED`, `CRITICAL`, `DESTROYED`)

- [ ] **Step 1: Write the failing test for schema loading**

Create `tests/destruction/test_destruction_json_schema.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	var f = FileAccess.open("res://resources/dungeon_profiles/assets/destruction.json", FileAccess.READ)
	assert(f != null, "FAIL: destruction.json must exist")
	var text = f.get_as_text()
	var json = JSON.parse_string(text)
	assert(json is Dictionary, "FAIL: destruction.json must be a Dictionary")
	assert(json.has("destructibles"), "FAIL: destruction.json must have 'destructibles'")
	var d = json["destructibles"]
	assert(d.has("crypt_urn_banded_floor") or d.has("urn"), "FAIL: must define urn destructible")
	assert(d.has("skull_pile"), "FAIL: must define skull_pile destructible")
	assert(d.has("candle_cluster") or d.has("candle_holder"), "FAIL: must define candle destructible")
	print("[PASS] test_destruction_json_schema")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_json_schema.gd"`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement `destruction.json`, `destruction_mode.gd`, and `destruction_state.gd`**

Create `src/destruction/core/destruction_mode.gd`:
```gdscript
class_name DestructionMode
extends RefCounted

enum Mode {
	BREAK = 0,
	COLLAPSE = 1,
	EXTINGUISH = 2,
	REPLACE = 3,
	DISABLE = 4
}

static func from_string(p_str: String) -> Mode:
	match p_str.to_lower():
		"break": return Mode.BREAK
		"collapse": return Mode.COLLAPSE
		"extinguish": return Mode.EXTINGUISH
		"replace": return Mode.REPLACE
		"disable": return Mode.DISABLE
		_: return Mode.BREAK
```

Create `src/destruction/core/destruction_state.gd`:
```gdscript
class_name DestructionState
extends RefCounted

enum State {
	INTACT = 0,
	DAMAGED = 1,
	CRITICAL = 2,
	DESTROYED = 3
}
```

Create `resources/dungeon_profiles/assets/destruction.json`:
```json
{
    "schema_version": 1,
    "destructibles": {
        "crypt_urn_banded_floor": {
            "enabled": true,
            "durability": 20.0,
            "damage_type_vulnerabilities": ["physical", "bludgeoning", "slashing", "fire"],
            "destruction_mode": "break",
            "replacement_asset": "crypt_rubble_corner",
            "debris": "ceramic_small",
            "effects": ["dust_small", "ceramic_break"]
        },
        "crypt_urn_relic_floor": {
            "enabled": true,
            "durability": 25.0,
            "damage_type_vulnerabilities": ["physical", "bludgeoning", "slashing"],
            "destruction_mode": "break",
            "replacement_asset": "crypt_rubble_corner",
            "debris": "ceramic_small",
            "effects": ["dust_small", "ceramic_break"]
        },
        "skull_pile": {
            "enabled": true,
            "durability": 15.0,
            "damage_type_vulnerabilities": ["physical", "bludgeoning", "crush"],
            "destruction_mode": "collapse",
            "replacement_asset": null,
            "debris": "bones_small",
            "effects": ["bone_scatter", "dust_small"]
        },
        "candle_cluster": {
            "enabled": true,
            "durability": 5.0,
            "damage_type_vulnerabilities": ["physical", "wind", "water", "ice"],
            "destruction_mode": "extinguish",
            "replacement_asset": null,
            "debris": null,
            "effects": ["candle_extinguish", "smoke_puff"]
        },
        "candle_holder": {
            "enabled": true,
            "durability": 5.0,
            "damage_type_vulnerabilities": ["physical", "wind", "water", "ice"],
            "destruction_mode": "extinguish",
            "replacement_asset": null,
            "debris": null,
            "effects": ["candle_extinguish", "smoke_puff"]
        },
        "fortress_chest_corner": {
            "enabled": true,
            "durability": 50.0,
            "damage_type_vulnerabilities": ["physical", "fire"],
            "destruction_mode": "break",
            "replacement_asset": null,
            "debris": "wood_splinters",
            "effects": ["wood_splinter", "dust_small"]
        },
        "mine_crate_corner": {
            "enabled": true,
            "durability": 20.0,
            "damage_type_vulnerabilities": ["physical", "fire"],
            "destruction_mode": "break",
            "replacement_asset": null,
            "debris": "wood_splinters",
            "effects": ["wood_splinter", "dust_small"]
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_json_schema.gd"`
Expected: PASS.

---

### Task 2: Core Contracts (`DestructionHit`, `DestructibleDefinition`, `DestructionEvent`)

**Files:**
- Create: `src/destruction/core/destruction_hit.gd`
- Create: `src/destruction/core/destructible_definition.gd`
- Create: `src/destruction/core/destruction_event.gd`
- Test: `tests/destruction/test_destruction_core_contracts.gd`

**Interfaces:**
- `DestructionHit.new(damage: float, damage_type: StringName, position: Vector3, direction: Vector3, source: Object)`
- `DestructibleDefinition.from_dict(id: StringName, dict: Dictionary) -> DestructibleDefinition`
- `DestructionEvent.new(target: Node3D, definition: DestructibleDefinition, old_state: int, new_state: int, hit: DestructionHit)`

- [ ] **Step 1: Write the failing test for contracts**

Create `tests/destruction/test_destruction_core_contracts.gd`:
```gdscript
extends SceneTree

const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")

func _init() -> void:
	var hit = _DestructionHitScript.new(15.0, &"physical", Vector3(1, 0, 1), Vector3.FORWARD, null)
	assert(hit.damage == 15.0, "FAIL: damage")
	assert(hit.damage_type == &"physical", "FAIL: damage_type")

	var dict = {
		"enabled": true,
		"durability": 20.0,
		"destruction_mode": "break",
		"replacement_asset": "crypt_rubble_corner",
		"debris": "ceramic_small",
		"effects": ["dust_small"]
	}
	var def = _DestructibleDefScript.from_dict(&"urn", dict)
	assert(def != null, "FAIL: def is null")
	assert(def.durability == 20.0, "FAIL: durability")
	assert(def.destruction_mode == _DestructionModeScript.Mode.BREAK, "FAIL: mode")
	assert(def.replacement_asset == &"crypt_rubble_corner", "FAIL: replacement")

	var evt = _DestructionEventScript.new(null, def, _DestructionStateScript.State.INTACT, _DestructionStateScript.State.DAMAGED, hit)
	assert(evt.new_state == _DestructionStateScript.State.DAMAGED, "FAIL: event new_state")

	print("[PASS] test_destruction_core_contracts")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_core_contracts.gd"`
Expected: FAIL (files missing).

- [ ] **Step 3: Implement core contract classes**

Create `src/destruction/core/destruction_hit.gd`:
```gdscript
class_name DestructionHit
extends RefCounted

var damage: float = 0.0
var damage_type: StringName = &"physical"
var impact_position: Vector3 = Vector3.ZERO
var impact_direction: Vector3 = Vector3.FORWARD
var source: Object = null

func _init(
	p_damage: float = 0.0,
	p_type: StringName = &"physical",
	p_pos: Vector3 = Vector3.ZERO,
	p_dir: Vector3 = Vector3.FORWARD,
	p_source: Object = null
) -> void:
	damage = p_damage
	damage_type = p_type
	impact_position = p_pos
	impact_direction = p_dir
	source = p_source
```

Create `src/destruction/core/destructible_definition.gd`:
```gdscript
class_name DestructibleDefinition
extends RefCounted

const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")

var id: StringName = &""
var enabled: bool = true
var durability: float = 20.0
var damage_vulnerabilities: Array[StringName] = []
var destruction_mode: int = _DestructionModeScript.Mode.BREAK
var replacement_asset: StringName = &""
var debris_id: StringName = &""
var effects: Array[String] = []

static func from_dict(p_id: StringName, d: Dictionary) -> DestructibleDefinition:
	var def := DestructibleDefinition.new()
	def.id = p_id
	def.enabled = bool(d.get("enabled", true))
	def.durability = float(d.get("durability", 20.0))

	var vulns: Array[StringName] = []
	for v in d.get("damage_type_vulnerabilities", []):
		vulns.append(StringName(str(v)))
	def.damage_vulnerabilities = vulns

	var mode_str = str(d.get("destruction_mode", "break"))
	def.destruction_mode = _DestructionModeScript.from_string(mode_str)

	var repl = d.get("replacement_asset", null)
	if repl != null and str(repl) != "" and str(repl) != "<null>":
		def.replacement_asset = StringName(str(repl))

	var deb = d.get("debris", null)
	if deb != null and str(deb) != "" and str(deb) != "<null>":
		def.debris_id = StringName(str(deb))

	var effs: Array[String] = []
	for e in d.get("effects", []):
		effs.append(str(e))
	def.effects = effs

	return def
```

Create `src/destruction/core/destruction_event.gd`:
```gdscript
class_name DestructionEvent
extends RefCounted

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")

var target: Node3D = null
var definition: _DestructibleDefScript = null
var old_state: int = 0
var new_state: int = 0
var hit: _DestructionHitScript = null
var timestamp_ms: int = 0

func _init(
	p_target: Node3D = null,
	p_def = null,
	p_old_state: int = 0,
	p_new_state: int = 0,
	p_hit = null
) -> void:
	target = p_target
	definition = p_def
	old_state = p_old_state
	new_state = p_new_state
	hit = p_hit
	timestamp_ms = Time.get_ticks_msec()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_core_contracts.gd"`
Expected: PASS.

---

### Task 3: Destruction Registry & ProfileLoader Deserialization

**Files:**
- Create: `src/destruction/runtime/destruction_registry.gd`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd`
- Test: `tests/destruction/test_destruction_registry_loading.gd`

**Interfaces:**
- `DestructionRegistry.register_definition(def: DestructibleDefinition)`
- `DestructionRegistry.get_definition(id: StringName) -> DestructibleDefinition`
- `DestructionRegistry.has_definition(id: StringName) -> bool`
- `ProfileLoader.populate_destruction_registry(registry: DestructionRegistry)`

- [ ] **Step 1: Write the failing test for DestructionRegistry**

Create `tests/destruction/test_destruction_registry_loading.gd`:
```gdscript
extends SceneTree

const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")

func _init() -> void:
	var reg := _DestructionRegistryScript.new()
	assert(reg.has_definition(&"crypt_urn_banded_floor"), "FAIL: registry must have crypt_urn_banded_floor")
	assert(reg.has_definition(&"skull_pile"), "FAIL: registry must have skull_pile")
	assert(reg.has_definition(&"candle_cluster"), "FAIL: registry must have candle_cluster")

	var urn_def = reg.get_definition(&"crypt_urn_banded_floor")
	assert(urn_def.durability == 20.0, "FAIL: urn durability")
	assert(urn_def.destruction_mode == _DestructionModeScript.Mode.BREAK, "FAIL: urn mode")

	var skull_def = reg.get_definition(&"skull_pile")
	assert(skull_def.destruction_mode == _DestructionModeScript.Mode.COLLAPSE, "FAIL: skull mode")

	print("[PASS] test_destruction_registry_loading")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_registry_loading.gd"`
Expected: FAIL.

- [ ] **Step 3: Implement `DestructionRegistry` and `ProfileLoader.populate_destruction_registry`**

Create `src/destruction/runtime/destruction_registry.gd`:
```gdscript
class_name DestructionRegistry
extends RefCounted

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

var _definitions: Dictionary = {}

func _init(autoload: bool = true) -> void:
	if autoload:
		var loader := _ProfileLoaderScript.new()
		loader.populate_destruction_registry(self)

func register_definition(def: _DestructibleDefScript) -> void:
	if def != null and def.id != &"":
		_definitions[def.id] = def

func get_definition(id: StringName) -> _DestructibleDefScript:
	return _definitions.get(id, null)

func has_definition(id: StringName) -> bool:
	return _definitions.has(id)

func clear() -> void:
	_definitions.clear()

func get_all_definitions() -> Array:
	return _definitions.values()
```

Add `populate_destruction_registry` to `src/dungeon_generator/profiles/profile_loader.gd`:
```gdscript
## Pobla el DestructionRegistry desde destruction.json
func populate_destruction_registry(target_registry) -> void:
	if target_registry == null:
		return

	var d_json = _read_json_file(base_path + "assets/destruction.json")
	if not (d_json is Dictionary and d_json.has("destructibles")):
		return

	var d_dict = d_json["destructibles"]
	for did in d_dict:
		var ddata = d_dict[did]
		if ddata is Dictionary:
			var def = _DestructibleDefinitionScript.from_dict(StringName(did), ddata)
			target_registry.register_definition(def)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_registry_loading.gd"`
Expected: PASS.

---

### Task 4: `DestructionComponent` Lifecycle & State Transitions

**Files:**
- Create: `src/destruction/runtime/destruction_component.gd`
- Test: `tests/destruction/test_destruction_component_lifecycle.gd`

**Interfaces:**
- `DestructionComponent.apply_hit(hit: DestructionHit) -> bool`
- `DestructionComponent.is_destroyed() -> bool`
- `DestructionComponent.current_durability: float`
- Signals: `damaged(hit: DestructionHit, current_durability: float)`, `state_changed(old_state: int, new_state: int)`, `destroyed(event: DestructionEvent)`

- [ ] **Step 1: Write the failing test for DestructionComponent**

Create `tests/destruction/test_destruction_component_lifecycle.gd`:
```gdscript
extends SceneTree

const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")

func _init() -> void:
	var def = _DestructibleDefScript.from_dict(&"urn", {
		"enabled": true,
		"durability": 20.0,
		"destruction_mode": "break"
	})

	var node := Node3D.new()
	var comp := _DestructionCompScript.new(def)
	node.add_child(comp)

	assert(comp.current_state == _DestructionStateScript.State.INTACT, "FAIL: initial state must be INTACT")
	assert(comp.current_durability == 20.0, "FAIL: initial durability")

	# Hit 1: 5 damage -> 15 durability (DAMAGED)
	var hit1 = _DestructionHitScript.new(5.0, &"physical")
	comp.apply_hit(hit1)
	assert(comp.current_durability == 15.0, "FAIL: durability after hit 1")
	assert(comp.current_state == _DestructionStateScript.State.DAMAGED, "FAIL: state after hit 1")

	# Hit 2: 10 damage -> 5 durability (CRITICAL, <= 25%)
	var hit2 = _DestructionHitScript.new(10.0, &"physical")
	comp.apply_hit(hit2)
	assert(comp.current_durability == 5.0, "FAIL: durability after hit 2")
	assert(comp.current_state == _DestructionStateScript.State.CRITICAL, "FAIL: state after hit 2")

	# Hit 3: 10 damage -> 0 durability (DESTROYED)
	var hit3 = _DestructionHitScript.new(10.0, &"physical")
	comp.apply_hit(hit3)
	assert(comp.current_durability == 0.0, "FAIL: durability after hit 3")
	assert(comp.is_destroyed(), "FAIL: must be destroyed")
	assert(comp.current_state == _DestructionStateScript.State.DESTROYED, "FAIL: state after hit 3")

	node.free()
	print("[PASS] test_destruction_component_lifecycle")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_component_lifecycle.gd"`
Expected: FAIL.

- [ ] **Step 3: Implement `DestructionComponent`**

Create `src/destruction/runtime/destruction_component.gd`:
```gdscript
class_name DestructionComponent
extends Node

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")

signal damaged(hit: _DestructionHitScript, remaining_durability: float)
signal state_changed(old_state: int, new_state: int)
signal destroyed(event: _DestructionEventScript)

var definition: _DestructibleDefScript = null
var current_durability: float = 100.0
var max_durability: float = 100.0
var current_state: int = _DestructionStateScript.State.INTACT

func _init(p_def: _DestructibleDefScript = null) -> void:
	if p_def != null:
		setup(p_def)

func setup(p_def: _DestructibleDefScript) -> void:
	definition = p_def
	max_durability = p_def.durability
	current_durability = max_durability
	current_state = _DestructionStateScript.State.INTACT

func apply_hit(hit: _DestructionHitScript) -> bool:
	if is_destroyed() or definition == null or not definition.enabled:
		return false
	if hit == null or hit.damage <= 0.0:
		return false

	# Filtrado por vulnerabilidades si están especificadas
	if not definition.damage_vulnerabilities.is_empty():
		var type_str = str(hit.damage_type).to_lower()
		var is_vulnerable := false
		for v in definition.damage_vulnerabilities:
			if str(v).to_lower() == type_str:
				is_vulnerable = true
				break
		if not is_vulnerable:
			return false

	var old_dur = current_durability
	current_durability = maxf(0.0, current_durability - hit.damage)
	damaged.emit(hit, current_durability)

	var old_st = current_state
	var new_st = _calculate_state(current_durability, max_durability)
	if new_st != old_st:
		current_state = new_st
		state_changed.emit(old_st, new_st)

	if current_state == _DestructionStateScript.State.DESTROYED:
		var parent_3d = get_parent() as Node3D
		var evt = _DestructionEventScript.new(parent_3d, definition, old_st, current_state, hit)
		destroyed.emit(evt)
		_execute_destruction_mode(evt)

	return true

func is_destroyed() -> bool:
	return current_state == _DestructionStateScript.State.DESTROYED

func _calculate_state(dur: float, max_dur: float) -> int:
	if dur <= 0.0:
		return _DestructionStateScript.State.DESTROYED
	var ratio = dur / max_dur if max_dur > 0.0 else 0.0
	if ratio <= 0.25:
		return _DestructionStateScript.State.CRITICAL
	elif ratio < 1.0:
		return _DestructionStateScript.State.DAMAGED
	return _DestructionStateScript.State.INTACT

func _execute_destruction_mode(evt: _DestructionEventScript) -> void:
	if definition == null or evt.target == null:
		return

	match definition.destruction_mode:
		_DestructionModeScript.Mode.BREAK, _DestructionModeScript.Mode.COLLAPSE:
			evt.target.visible = false
			for child in evt.target.get_children():
				if child is CollisionShape3D:
					child.set_deferred("disabled", true)
				elif child is StaticBody3D:
					for sub in child.get_children():
						if sub is CollisionShape3D:
							sub.set_deferred("disabled", true)

		_DestructionModeScript.Mode.EXTINGUISH:
			_extinguish_lights_recursive(evt.target)

		_DestructionModeScript.Mode.DISABLE:
			evt.target.process_mode = Node.PROCESS_MODE_DISABLED

static func _extinguish_lights_recursive(n: Node) -> void:
	if n is OmniLight3D or n is SpotLight3D:
		(n as Light3D).visible = false
	if n is GPUParticles3D or n is CPUParticles3D:
		n.emitting = false
	for c in n.get_children():
		_extinguish_lights_recursive(c)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_component_lifecycle.gd"`
Expected: PASS.

---

### Task 5: `DestructionService` & `DestructionBinder`

**Files:**
- Create: `src/destruction/runtime/destruction_binder.gd`
- Create: `src/destruction/runtime/destruction_service.gd`
- Modify: `src/presentation/props/prop_spawner.gd`
- Test: `tests/destruction/test_destruction_modes_benchmark.gd`

**Interfaces:**
- `DestructionBinder.bind_prop(node: Node3D, prop_id: StringName) -> DestructionComponent`
- `DestructionService.register_instance(node: Node3D, comp: DestructionComponent)`
- `DestructionService.apply_hit_to_node(node: Node3D, hit: DestructionHit) -> bool`

- [ ] **Step 1: Write the failing benchmark test**

Create `tests/destruction/test_destruction_modes_benchmark.gd`:
```gdscript
extends SceneTree

const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")

func _init() -> void:
	print("--- Running test_destruction_modes_benchmark ---")
	var reg := _DestructionRegistryScript.new()
	var service := _DestructionServiceScript.new()
	var binder := _DestructionBinderScript.new(reg, service)
	var provider := _PropAssetProviderScript.new()

	# Benchmark 1: Urn (BREAK)
	var urn = provider.materialize_by_id(&"crypt_urn_banded_floor")
	assert(urn != null, "FAIL: urn node")
	var comp1 = binder.bind_prop(urn, &"crypt_urn_banded_floor")
	assert(comp1 != null, "FAIL: urn must be destructible")
	service.apply_hit_to_node(urn, _DestructionHitScript.new(20.0, &"physical"))
	assert(comp1.is_destroyed(), "FAIL: urn must be destroyed")
	assert(not urn.visible, "FAIL: broken urn must hide main mesh")
	urn.free()

	# Benchmark 2: Skull Pile (COLLAPSE)
	var skulls = provider.materialize_by_id(&"skull_pile")
	assert(skulls != null, "FAIL: skulls node")
	var comp2 = binder.bind_prop(skulls, &"skull_pile")
	assert(comp2 != null, "FAIL: skulls must be destructible")
	service.apply_hit_to_node(skulls, _DestructionHitScript.new(15.0, &"physical"))
	assert(comp2.is_destroyed(), "FAIL: skull pile must be destroyed")
	skulls.free()

	# Benchmark 3: Candle Cluster (EXTINGUISH)
	var candle := Node3D.new()
	var light := OmniLight3D.new()
	candle.add_child(light)
	var comp3 = binder.bind_prop(candle, &"candle_cluster")
	assert(comp3 != null, "FAIL: candle must be destructible")
	assert(light.visible, "FAIL: candle light starts on")
	service.apply_hit_to_node(candle, _DestructionHitScript.new(5.0, &"wind"))
	assert(comp3.is_destroyed(), "FAIL: candle must be extinguished")
	assert(not light.visible, "FAIL: candle light must be turned off")
	candle.free()

	print("[PASS] test_destruction_modes_benchmark passed with 100% success!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_modes_benchmark.gd"`
Expected: FAIL.

- [ ] **Step 3: Implement `DestructionBinder`, `DestructionService`, and update `PropSpawner`**

Create `src/destruction/runtime/destruction_binder.gd`:
```gdscript
class_name DestructionBinder
extends RefCounted

const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")

var _registry: _DestructionRegistryScript = null
var _service: _DestructionServiceScript = null

func _init(reg: _DestructionRegistryScript = null, srv: _DestructionServiceScript = null) -> void:
	_registry = reg if reg != null else _DestructionRegistryScript.new()
	_service = srv

func bind_prop(node: Node3D, prop_id: StringName) -> _DestructionCompScript:
	if node == null or not _registry.has_definition(prop_id):
		return null

	var def = _registry.get_definition(prop_id)
	if def == null or not def.enabled:
		return null

	var comp := _DestructionCompScript.new(def)
	comp.name = "DestructionComponent"
	node.add_child(comp)

	if _service != null:
		_service.register_instance(node, comp)

	return comp
```

Create `src/destruction/runtime/destruction_service.gd`:
```gdscript
class_name DestructionService
extends RefCounted

const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")

signal global_destruction_event(event: _DestructionEventScript)

var _instances: Dictionary = {} # Node3D -> DestructionComponent

func register_instance(node: Node3D, comp: _DestructionCompScript) -> void:
	if node != null and comp != null:
		_instances[node] = comp
		if not comp.destroyed.is_connected(_on_component_destroyed):
			comp.destroyed.connect(_on_component_destroyed)
		if not node.tree_exiting.is_connected(_on_node_exiting.bind(node)):
			node.tree_exiting.connect(_on_node_exiting.bind(node))

func unregister_instance(node: Node3D) -> void:
	if _instances.has(node):
		_instances.erase(node)

func get_component(node: Node3D) -> _DestructionCompScript:
	return _instances.get(node, null)

func apply_hit_to_node(node: Node3D, hit: _DestructionHitScript) -> bool:
	var comp = get_component(node)
	if comp != null:
		return comp.apply_hit(hit)
	# Check child component directly if not in registry map
	for c in node.get_children():
		if c is _DestructionCompScript:
			return (c as _DestructionCompScript).apply_hit(hit)
	return false

func _on_component_destroyed(event: _DestructionEventScript) -> void:
	global_destruction_event.emit(event)

func _on_node_exiting(node: Node3D) -> void:
	unregister_instance(node)
```

Update `src/presentation/props/prop_spawner.gd` to inject `DestructionBinder` cleanly:
```gdscript
# In prop_spawner.gd:
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
var _destruction_binder := _DestructionBinderScript.new()

# Inside spawn_prop(directive, parent):
	if directive != null:
		_destruction_binder.bind_prop(node, directive.prop_id)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_modes_benchmark.gd"`
Expected: PASS.

---

### Task 6: Full Integration Test (`test_destruction_pipeline_integration.gd`)

**Files:**
- Create: `tests/destruction/test_destruction_pipeline_integration.gd`

- [ ] **Step 1: Write and run the End-to-End integration test**

Create `tests/destruction/test_destruction_pipeline_integration.gd`:
```gdscript
extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DecorationCompPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _PresentationRoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")

func _init() -> void:
	print("--- Running test_destruction_pipeline_integration ---")
	var loader := _ProfileLoaderScript.new()
	var prof = loader.load_room("crypt.json")
	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(1, 10, null)
	var planner := _DecorationCompPlannerScript.new()
	var spawner := _PropSpawnerScript.new()
	var service := _DestructionServiceScript.new()

	var f_cells: Array[Vector2i] = []
	for x in range(2, 8):
		for y in range(2, 8):
			f_cells.append(Vector2i(x, y))

	var w_cells: Array[Vector2i] = []
	for x in range(1, 9):
		w_cells.append(Vector2i(x, 1))
		w_cells.append(Vector2i(x, 8))
	for y in range(2, 8):
		w_cells.append(Vector2i(1, y))
		w_cells.append(Vector2i(8, y))

	var room_geom = _PresentationRoomGeomScript.new(1337, Rect2i(2, 2, 6, 6), f_cells, w_cells, [Vector2i(4, 2)], null, [])
	var comp = planner.plan_room_composition(prof, palette, room_geom, {"room_id": 1, "room_purpose": 10, "room_type": "NORMAL"}, null, _PresentationSeedContextScript.for_room(1337, 1), 2.0)

	var parent := Node3D.new()
	var destructibles_found := 0
	for d in comp.prop_directives:
		var n = spawner.spawn_prop(d, parent)
		if n != null:
			var d_comp: _DestructionCompScript = null
			for c in n.get_children():
				if c is _DestructionCompScript:
					d_comp = c
			if d_comp != null:
				destructibles_found += 1
				service.register_instance(n, d_comp)
				# Apply fatal hit
				service.apply_hit_to_node(n, _DestructionHitScript.new(100.0, &"physical"))
				assert(d_comp.is_destroyed(), "FAIL: prop must be destroyed on fatal hit")

	print("  Found and destroyed %d procedural destructibles in generated crypt" % destructibles_found)
	assert(destructibles_found > 0, "FAIL: must have destructible props in room")

	parent.free()
	print("[PASS] test_destruction_pipeline_integration passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run all destruction and regression tests**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_json_schema.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_core_contracts.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_registry_loading.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_component_lifecycle.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_modes_benchmark.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_pipeline_integration.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_configuration_authority.gd"`
Expected: ALL PASS (0 errors).
