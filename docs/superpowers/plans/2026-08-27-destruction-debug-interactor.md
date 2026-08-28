# Destruction Debug Interactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a completely decoupled, interactive 3D mouse-click debug adapter (`DestructionDebugInteractor` and HUD overlay) that enables live testing of prop destruction (damage, progressive states, fatal hits, and mode resolution) via raycasting without requiring a player character, weapon, or combat system.

**Architecture:**
The input/debug layer performs 3D camera raycasts against collision shapes in the scene, identifies any target with a `DestructionComponent`, creates a `DestructionHit`, and submits it to `DestructionService`. Core destruction components remain 100% decoupled and unaware of mouse/input devices.

**Tech Stack:** Godot 4.6.1 GDScript, PhysicsDirectSpaceState3D raycasting, CanvasLayer/Control HUD, Headless Godot test runner.

**Spec:** Pure input/interactor adapter producing `DestructionHit` payloads with Left Click (10 damage) and Right Click (immediate fatal hit) plus real-time visual inspection HUD.

## Global Constraints
- **Decoupling Rule:** Zero input handling (`InputEventMouseButton`, `get_viewport().get_mouse_position()`) inside `DestructionComponent`, `DestructionService`, or `DestructibleDefinition`.
- **Target Resolution Rule:** Must cleanly resolve the destructible prop even when the raycast hits a child `StaticBody3D`, `CollisionShape3D`, or Mesh collider.
- **Visual Feedback:** Real-time debug HUD showing Asset ID, Current State, Durability / Max, Mode, and Last Hit info.
- **Safety:** Can be safely enabled in debug/test scenes (`dungeon_level.tscn`) and disabled/bypassed in production without modifying gameplay code.

---

### File Structure Map

```text
src/
└── destruction/
    └── debug/
        ├── destruction_debug_interactor.gd                      [NEW] 3D Camera raycast interactor & hit dispatcher
        └── destruction_debug_hud.gd                             [NEW] CanvasLayer HUD displaying target telemetry

scenes/
└── dungeon/
    └── dungeon_level_controller.gd                              [MODIFY] Wire interactor when 3D level is generated

tests/
└── destruction/
    ├── test_destruction_debug_interactor.gd                     [NEW] Unit test verifying raycast target resolution & hit dispatch
    └── test_destruction_debug_hud.gd                            [NEW] Unit test verifying HUD telemetry & state formatting
```

---

### Task 1: Create `DestructionDebugInteractor`

**Files:**
- Create: `src/destruction/debug/destruction_debug_interactor.gd`
- Test: `tests/destruction/test_destruction_debug_interactor.gd`

**Interfaces:**
- `DestructionDebugInteractor.resolve_destructible_from_collider(collider: Object) -> DestructionComponent`
- `DestructionDebugInteractor.interact_ray(camera: Camera3D, screen_pos: Vector2, is_fatal: bool = false, damage_amount: float = 10.0, damage_type: StringName = &"physical") -> Dictionary`
- `DestructionDebugInteractor.process_unhandled_input(event: InputEvent, camera: Camera3D) -> bool`
- Signals: `destructible_hit(node: Node3D, component: DestructionComponent, hit: DestructionHit)`, `hover_changed(node: Node3D, component: DestructionComponent)`

- [ ] **Step 1: Write the failing unit test for `DestructionDebugInteractor`**

Create `tests/destruction/test_destruction_debug_interactor.gd`:
```gdscript
extends SceneTree

const _DestructionDebugInteractorScript = preload("res://src/destruction/debug/destruction_debug_interactor.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_debug_interactor ---")
	print("==================================================================")

	var interactor := _DestructionDebugInteractorScript.new()
	var service := _DestructionServiceScript.new()
	interactor.set_service(service)

	# 1. Crear jerarquía física simulada (Prop -> StaticBody3D -> CollisionShape3D)
	var prop_root := Node3D.new()
	prop_root.name = "Prop_Urn_Test"
	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"enabled": true,
		"durability": 20.0,
		"damage_type_vulnerabilities": ["physical"],
		"destruction_mode": "break"
	})
	var comp := _DestructionCompScript.new(def)
	prop_root.add_child(comp)

	var static_body := StaticBody3D.new()
	prop_root.add_child(static_body)

	# 2. Testear resolución desde el collider hijo
	var resolved_comp = interactor.resolve_destructible_from_collider(static_body)
	assert(resolved_comp == comp, "FAIL: interactor must resolve component from child StaticBody3D")

	# 3. Testear ejecución de hit normal (10 damage)
	var hit_res = interactor.apply_hit_to_target(prop_root, 10.0, &"physical", false)
	assert(hit_res.success, "FAIL: hit must succeed")
	assert(comp.current_durability == 10.0, "FAIL: durability after 10 damage")
	assert(comp.current_state == _DestructionStateScript.State.DAMAGED, "FAIL: state must be DAMAGED")

	# 4. Testear ejecución de hit fatal (Right Click simulation)
	var fatal_res = interactor.apply_hit_to_target(prop_root, 10.0, &"physical", true)
	assert(fatal_res.success, "FAIL: fatal hit must succeed")
	assert(comp.is_destroyed(), "FAIL: prop must be destroyed immediately on fatal hit")

	prop_root.free()
	print("[PASS] test_destruction_debug_interactor passed with 100% success!")
	print("==================================================================")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_debug_interactor.gd"`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement `DestructionDebugInteractor`**

Create `src/destruction/debug/destruction_debug_interactor.gd`:
```gdscript
class_name DestructionDebugInteractor
extends Node

## Adaptador de Input/Raycast para interactuar y destruir objetos en tiempo de ejecución.
## Desacoplado: convierte eventos de mouse en DestructionHit y los envía a DestructionService.

const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")

signal destructible_hit(node: Node3D, component: _DestructionCompScript, hit: _DestructionHitScript)
signal hover_changed(node: Node3D, component: _DestructionCompScript)

@export var enabled: bool = true
@export var normal_damage: float = 10.0
@export var fatal_damage: float = 9999.0
@export var damage_type: StringName = &"physical"
@export var collision_mask: int = 0xFFFFFFFF

var _service: _DestructionServiceScript = null
var _last_hovered_node: Node3D = null
var _last_hovered_comp: _DestructionCompScript = null

func _init(service: _DestructionServiceScript = null) -> void:
	_service = service

func set_service(service: _DestructionServiceScript) -> void:
	_service = service

func get_service() -> _DestructionServiceScript:
	return _service

## Resuelve el DestructionComponent navegando el árbol hacia la raíz del prop
func resolve_destructible_from_collider(collider: Object) -> _DestructionCompScript:
	if collider == null:
		return null

	if collider is Node:
		var curr: Node = collider
		while curr != null:
			for child in curr.get_children():
				if child is _DestructionCompScript:
					return child as _DestructionCompScript
			curr = curr.get_parent()

	return null

## Aplica daño directo sobre un nodo destino
func apply_hit_to_target(
	target_node: Node3D,
	damage_val: float = 10.0,
	dmg_type: StringName = &"physical",
	is_fatal: bool = false,
	impact_pos: Vector3 = Vector3.ZERO,
	impact_dir: Vector3 = Vector3.DOWN
) -> Dictionary:
	if target_node == null:
		return {"success": false, "error": "target_node_null"}

	var comp: _DestructionCompScript = null
	for child in target_node.get_children():
		if child is _DestructionCompScript:
			comp = child
			break
	if comp == null:
		comp = resolve_destructible_from_collider(target_node)

	if comp == null or comp.is_destroyed():
		return {"success": false, "error": "no_active_component"}

	var final_damage = fatal_damage if is_fatal else damage_val
	var hit = _DestructionHitScript.new(final_damage, dmg_type, impact_pos, impact_dir, self)

	var applied := false
	if _service != null:
		applied = _service.apply_hit_to_node(target_node, hit)
	else:
		applied = comp.apply_hit(hit)

	if applied:
		destructible_hit.emit(target_node, comp, hit)
		return {
			"success": true,
			"target": target_node,
			"component": comp,
			"damage": final_damage,
			"durability": comp.current_durability,
			"state": comp.current_state,
			"destroyed": comp.is_destroyed()
		}

	return {"success": false, "error": "hit_rejected"}

## Lanza un rayo desde la cámara y aplica interacción si colisiona con un destructible
func interact_ray(
	camera: Camera3D,
	screen_pos: Vector2,
	is_fatal: bool = false
) -> Dictionary:
	if not enabled or camera == null:
		return {"success": false, "error": "disabled_or_no_camera"}

	var world_3d = camera.get_world_3d()
	if world_3d == null:
		return {"success": false, "error": "no_world_3d"}

	var space_state = world_3d.direct_space_state
	if space_state == null:
		return {"success": false, "error": "no_space_state"}

	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)
	var ray_length = camera.far if camera.far > 0.0 else 1000.0
	var ray_end = ray_origin + ray_dir * ray_length

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit_dict = space_state.intersect_ray(query)
	if hit_dict.is_empty():
		_update_hover(null, null)
		return {"success": false, "hit_geometry": false}

	var collider = hit_dict.get("collider", null)
	var hit_pos = hit_dict.get("position", Vector3.ZERO)
	var hit_normal = hit_dict.get("normal", Vector3.UP)
	var comp = resolve_destructible_from_collider(collider)

	if comp != null and comp.get_parent() is Node3D:
		var parent_3d = comp.get_parent() as Node3D
		_update_hover(parent_3d, comp)
		return apply_hit_to_target(parent_3d, normal_damage, damage_type, is_fatal, hit_pos, -hit_normal)

	_update_hover(null, null)
	return {"success": false, "hit_geometry": true, "collider": collider}

func _update_hover(node: Node3D, comp: _DestructionCompScript) -> void:
	if node != _last_hovered_node or comp != _last_hovered_comp:
		_last_hovered_node = node
		_last_hovered_comp = comp
		hover_changed.emit(node, comp)

func handle_input_event(camera: Camera3D, event: InputEvent) -> bool:
	if not enabled or camera == null:
		return false

	if event is InputEventMouseButton and event.pressed:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var res = interact_ray(camera, mb.position, false)
			return bool(res.get("success", false))
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			var res = interact_ray(camera, mb.position, true)
			return bool(res.get("success", false))

	return false
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_debug_interactor.gd"`
Expected: PASS.

---

### Task 2: Create `DestructionDebugHUD`

**Files:**
- Create: `src/destruction/debug/destruction_debug_hud.gd`
- Test: `tests/destruction/test_destruction_debug_hud.gd`

**Interfaces:**
- `DestructionDebugHUD.update_telemetry(node: Node3D, comp: DestructionComponent, last_hit_damage: float)`
- `DestructionDebugHUD.clear_telemetry()`

- [ ] **Step 1: Write the failing unit test for `DestructionDebugHUD`**

Create `tests/destruction/test_destruction_debug_hud.gd`:
```gdscript
extends SceneTree

const _DestructionDebugHUDScript = preload("res://src/destruction/debug/destruction_debug_hud.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_debug_hud ---")
	print("==================================================================")

	var hud := _DestructionDebugHUDScript.new()
	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"enabled": true,
		"durability": 20.0,
		"damage_type_vulnerabilities": ["physical"],
		"destruction_mode": "break"
	})

	var prop := Node3D.new()
	prop.name = "Prop_Urn_Relic"
	var comp := _DestructionCompScript.new(def)
	prop.add_child(comp)

	hud.update_telemetry(prop, comp, 10.0)
	assert(hud.get_title_text().contains("crypt_urn_banded_floor"), "FAIL: HUD must display asset ID")
	assert(hud.get_durability_text().contains("20.0 / 20.0"), "FAIL: HUD must display durability")

	# Damage comp and update
	comp.apply_hit(_DestructionHitScript.new(10.0, &"physical"))
	hud.update_telemetry(prop, comp, 10.0)
	assert(hud.get_durability_text().contains("10.0 / 20.0"), "FAIL: HUD must update durability")
	assert(hud.get_state_text().contains("DAMAGED"), "FAIL: HUD must show DAMAGED state")

	prop.free()
	hud.free()
	print("[PASS] test_destruction_debug_hud passed with 100% success!")
	print("==================================================================")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_debug_hud.gd"`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement `DestructionDebugHUD`**

Create `src/destruction/debug/destruction_debug_hud.gd`:
```gdscript
class_name DestructionDebugHUD
extends CanvasLayer

## Panel de telemetría y HUD en pantalla para inspeccionar impactos y estados de destrucción en tiempo real.

const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")
const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")

var _panel: PanelContainer = null
var _label_title: Label = null
var _label_state: Label = null
var _label_durability: Label = null
var _label_details: Label = null
var _progress_bar: ProgressBar = null

func _init() -> void:
	layer = 100
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DestructionDebugPanel"
	_panel.anchor_left = 0.02
	_panel.anchor_top = 0.02
	_panel.offset_left = 10
	_panel.offset_top = 10
	_panel.custom_minimum_size = Vector2(280, 140)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_label_title = Label.new()
	_label_title.text = "Destruction Inspector: [Idle]"
	_label_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(_label_title)

	_label_state = Label.new()
	_label_state.text = "State: N/A"
	vbox.add_child(_label_state)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(250, 16)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 100.0
	_progress_bar.show_percentage = false
	vbox.add_child(_progress_bar)

	_label_durability = Label.new()
	_label_durability.text = "Durability: -- / --"
	vbox.add_child(_label_durability)

	_label_details = Label.new()
	_label_details.text = "L-Click: 10 Dmg | R-Click: Instant Destroy"
	_label_details.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_label_details)

	add_child(_panel)

func update_telemetry(node: Node3D, comp: _DestructionCompScript, last_damage: float = 0.0) -> void:
	if comp == null or comp.definition == null:
		clear_telemetry()
		return

	var asset_id = String(comp.definition.id)
	var node_name = node.name if node != null else "Unknown"
	_label_title.text = "Asset: %s (%s)" % [asset_id, node_name]

	var state_name = _DestructionStateScript.to_name(comp.current_state)
	_label_state.text = "State: %s (Mode: %s)" % [state_name, _DestructionModeScript.to_name(comp.definition.destruction_mode)]

	_label_durability.text = "Durability: %.1f / %.1f (Hit: -%.1f)" % [comp.current_durability, comp.max_durability, last_damage]
	_progress_bar.max_value = comp.max_durability
	_progress_bar.value = comp.current_durability

	match comp.current_state:
		_DestructionStateScript.State.INTACT:
			_label_state.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		_DestructionStateScript.State.DAMAGED:
			_label_state.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		_DestructionStateScript.State.CRITICAL:
			_label_state.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		_DestructionStateScript.State.DESTROYED:
			_label_state.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

func clear_telemetry() -> void:
	_label_title.text = "Destruction Inspector: [Idle]"
	_label_state.text = "State: N/A"
	_label_state.remove_theme_color_override("font_color")
	_label_durability.text = "Durability: -- / --"
	_progress_bar.value = 0.0

func get_title_text() -> String:
	return _label_title.text if _label_title != null else ""

func get_state_text() -> String:
	return _label_state.text if _label_state != null else ""

func get_durability_text() -> String:
	return _label_durability.text if _label_durability != null else ""
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_debug_hud.gd"`
Expected: PASS.

---

### Task 3: Integrate into `DungeonLevelController` (`dungeon_level.tscn`)

**Files:**
- Modify: `scenes/dungeon/dungeon_level_controller.gd`
- Test: `tests/integration/test_dungeon_level_destruction_interactor.gd`

**Interfaces:**
- `dungeon_level_controller.gd` instantiates `DestructionDebugInteractor` and `DestructionDebugHUD`.
- `_unhandled_input(event)` routes clicks to `_destruction_interactor.handle_input_event(camera, event)`.
- Updates `_destruction_hud.update_telemetry` on hit.

- [ ] **Step 1: Write integration test for level controller interaction**

Create `tests/integration/test_dungeon_level_destruction_interactor.gd`:
```gdscript
extends SceneTree

const _DungeonLevelScene = preload("res://scenes/dungeon/dungeon_level.tscn")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_level_destruction_interactor ---")
	print("==================================================================")

	var scene_inst = _DungeonLevelScene.instantiate()
	assert(scene_inst != null, "FAIL: Could not instantiate dungeon_level.tscn")

	# Simular inicialización en 3D
	root.add_child(scene_inst)
	assert(scene_inst.has_node("DestructionDebugInteractor") or scene_inst.get("_destruction_interactor") != null, "FAIL: interactor must be present in controller")

	scene_inst.free()
	print("[PASS] test_dungeon_level_destruction_interactor passed 100%!")
	print("==================================================================")
	quit(0)
```

- [ ] **Step 2: Implement integration in `dungeon_level_controller.gd`**

Modify `scenes/dungeon/dungeon_level_controller.gd` to include:
- `const _DestructionDebugInteractorScript = preload("res://src/destruction/debug/destruction_debug_interactor.gd")`
- `const _DestructionDebugHUDScript = preload("res://src/destruction/debug/destruction_debug_hud.gd")`
- In `_ready()`: initialize `_destruction_interactor` and `_destruction_hud`.
- In `_unhandled_input(event)`: forward mouse input to `_destruction_interactor.handle_input_event(active_camera, event)`.

- [ ] **Step 3: Run integration test and full test suite**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_debug_interactor.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_debug_hud.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/integration/test_dungeon_level_destruction_interactor.gd"`
Expected: ALL PASS.
