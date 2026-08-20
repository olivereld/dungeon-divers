# Isometric Camera Rig Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a reusable, fully decoupled presentation module (`IsometricCameraRig`) that provides orthogonal fixed-angle isometric projection, smooth accelerated target follow, smooth size-based zoom, and raycast-based occlusion detection with discrete state change events.

**Architecture:** The module is 100% presentation-layer (0 dependencies on `DungeonResult`, `CellGrid`, or procedural generation). An `IsometricCameraRig` (`Node3D`) maintains fixed isometric orientation (Yaw=45°, Pitch=~35.264°, Roll=0°) and moves its position smoothly toward the target in `_physics_process()`. A decoupled sub-component `CameraOcclusionDetector` casts multi-point rays (center, upper, lower) from the camera to the target to detect blocking obstacles and emit discrete `occlusion_started` / `occlusion_ended` signals.

**Tech Stack:** Godot 4.6.1 GDScript, `Camera3D` (Orthogonal projection), `PhysicsDirectSpaceState3D`, `PhysicsRayQueryParameters3D`, Headless Godot Test Runner.

**Spec:** Defined in the user architectural specification (Módulo de Cámara Isométrica Reutilizable y Desacoplado).

## Global Constraints
- Strictly 100% presentation layer: No dependencies on `DungeonResult`, `CellGrid`, `RoomData`, or generator logic.
- Camera projection must be `Camera3D.PROJECTION_ORTHOGONAL` with fixed isometric angle (Yaw=45°, Pitch=35.264°, Roll=0°). No free mouse rotation.
- Follow system must use kinematic distance-based acceleration/deceleration smoothing in `_physics_process()`, not instant snapping.
- Zoom must scale `Camera3D.size` smoothly without moving physical camera distance.
- Occlusion detection must use multi-ray sampling (center, upper, lower) and emit discrete edge-triggered signals (`occlusion_started`, `occlusion_ended`) only when state transitions occur.
- Full TDD coverage: Every task must have an automated test suite executable via Godot headless runner.

---

### File Structure Map

```text
src/presentation/camera/
├── isometric_camera_rig.gd          # Core Rig Controller: Target tracking, smooth follow, zoom, public API & signals
└── camera_occlusion_detector.gd     # Occlusion Subsystem: Multi-ray spatial queries, obstacle tracking, state transitions

scenes/presentation/camera/
└── isometric_camera_rig.tscn        # Reusable Scene with CameraPivot, Camera3D, and CameraOcclusionDetector

tests/presentation/
├── test_camera_contracts.gd         # Unit Tests: Instantiation, defaults, setters, getters, signal signatures
├── test_camera_smooth_follow.gd     # Unit Tests: Kinematic acceleration, deceleration, dead-zone, offset tracking
├── test_camera_zoom.gd              # Unit Tests: Orthogonal size scaling, clamping, smooth interpolation
├── test_camera_occlusion.gd         # Integration Tests: Multi-ray obstruction detection, state change transitions
└── test_camera_integration_e2e.gd   # Integration Tests: Player tracking and dungeon level presentation wiring
```

---

### Task 1: Camera Contracts & Isometric Orientation Scene (Commit 1)

**Files:**
- Create: `src/presentation/camera/isometric_camera_rig.gd`
- Create: `scenes/presentation/camera/isometric_camera_rig.tscn`
- Test: `tests/presentation/test_camera_contracts.gd`

**Interfaces:**
- Consumes: `Node3D`, `Camera3D`
- Produces: `IsometricCameraRig` (`Node3D`) with `@export var target: Node3D`, `set_target(node: Node3D)`, `clear_target()`, `get_camera() -> Camera3D`, signals `target_changed(target: Node3D)`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/presentation/test_camera_contracts.gd
extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_contracts ---")
	print("==================================================================")

	var rig = IsometricCameraRigScript.new()
	assert(rig != null, "FAIL: IsometricCameraRig should instantiate")

	# Verificar configuración isométrica inicial
	assert(rig.yaw_degrees == 45.0, "FAIL: Default yaw should be 45 degrees")
	assert(is_equal_approx(rig.pitch_degrees, 35.264), "FAIL: Default pitch should be ~35.264 degrees (true isometric)")
	assert(rig.roll_degrees == 0.0, "FAIL: Default roll should be 0.0 degrees")

	# Verificar API de Target
	var dummy_target := Node3D.new()
	var signal_emitted := false
	var emitted_target: Node3D = null
	rig.target_changed.connect(func(t: Node3D):
		signal_emitted = true
		emitted_target = t
	)

	rig.set_target(dummy_target)
	assert(rig.target == dummy_target, "FAIL: set_target should assign target")
	assert(signal_emitted, "FAIL: set_target should emit target_changed signal")
	assert(emitted_target == dummy_target, "FAIL: target_changed should pass target node")

	signal_emitted = false
	rig.clear_target()
	assert(rig.target == null, "FAIL: clear_target should set target to null")
	assert(signal_emitted, "FAIL: clear_target should emit target_changed signal with null")

	dummy_target.free()
	rig.free()

	print("[PASS] test_camera_contracts completed successfully.")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_contracts.gd`
Expected: FAIL with "Cannot open file" or "Parse error".

- [ ] **Step 3: Write minimal implementation**

```gdscript
# src/presentation/camera/isometric_camera_rig.gd
class_name IsometricCameraRig
extends Node3D

## Módulo de Cámara Isométrica Desacoplado y Reutilizable.
## Mantiene proyección ortogonal y orientación fija (Yaw=45°, Pitch=~35.264°, Roll=0°).

signal target_changed(target: Node3D)
signal zoom_changed(value: float)
signal occlusion_started(occluders: Array[Node3D])
signal occlusion_ended(occluders: Array[Node3D])

@export_group("Target Tracking")
@export var target: Node3D = null:
	set(val):
		if target != val:
			target = val
			target_changed.emit(target)
@export var target_offset: Vector3 = Vector3(0.0, 0.7, 0.0)
@export var follow_enabled: bool = true

@export_group("Isometric Orientation")
@export var yaw_degrees: float = 45.0:
	set(val):
		yaw_degrees = val
		_update_orientation()
@export var pitch_degrees: float = 35.264:
	set(val):
		pitch_degrees = val
		_update_orientation()
@export var roll_degrees: float = 0.0:
	set(val):
		roll_degrees = val
		_update_orientation()
@export var camera_distance: float = 40.0

@export_group("Camera Settings")
@export var default_zoom: float = 24.0

var _pivot: Node3D = null
var _camera: Camera3D = null

func _ready() -> void:
	_setup_internal_hierarchy()
	_update_orientation()

func _setup_internal_hierarchy() -> void:
	_pivot = get_node_or_null("CameraPivot")
	if _pivot == null:
		_pivot = Node3D.new()
		_pivot.name = "CameraPivot"
		add_child(_pivot)

	_camera = _pivot.get_node_or_null("Camera3D")
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = default_zoom
		_pivot.add_child(_camera)

func _update_orientation() -> void:
	if _pivot == null:
		return
	_pivot.rotation = Vector3(
		deg_to_rad(-pitch_degrees),
		deg_to_rad(yaw_degrees),
		deg_to_rad(roll_degrees)
	)
	if _camera != null:
		_camera.position = Vector3(0.0, 0.0, camera_distance)

func set_target(p_target: Node3D) -> void:
	self.target = p_target

func clear_target() -> void:
	self.target = null

func get_camera() -> Camera3D:
	if _camera == null:
		_setup_internal_hierarchy()
	return _camera
```

Create `scenes/presentation/camera/isometric_camera_rig.tscn`:
```tscn
[gd_scene load_steps=2 format=3 uid="uid://iso_camera_rig_scene"]

[ext_resource type="Script" path="res://src/presentation/camera/isometric_camera_rig.gd" id="1_rig"]

[node name="IsometricCameraRig" type="Node3D"]
script = ExtResource("1_rig")

[node name="CameraPivot" type="Node3D" parent="."]
transform = Transform3D(0.707107, -0.408248, 0.57735, 0, 0.816497, 0.57735, -0.707107, -0.408248, 0.57735, 0, 0, 0)

[node name="Camera3D" type="Camera3D" parent="CameraPivot"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 40)
projection = 1
size = 24.0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_contracts.gd`
Expected: PASS with `[PASS] test_camera_contracts completed successfully.`

- [ ] **Step 5: Commit**

```bash
git add src/presentation/camera/isometric_camera_rig.gd scenes/presentation/camera/isometric_camera_rig.tscn tests/presentation/test_camera_contracts.gd
git commit -m "feat(camera): add IsometricCameraRig contracts and base orthogonal scene"
```

---

### Task 2: Kinematic Smooth Follow System (Commit 2)

**Files:**
- Modify: `src/presentation/camera/isometric_camera_rig.gd`
- Test: `tests/presentation/test_camera_smooth_follow.gd`

**Interfaces:**
- Consumes: Target position, `follow_speed: float`, `acceleration: float`, `deceleration: float`, `dead_zone: float`.
- Produces: Smooth physics-step position interpolation in `_physics_process()`, instant snap API `teleport_to_target()`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/presentation/test_camera_smooth_follow.gd
extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_smooth_follow ---")
	print("==================================================================")

	var rig = IsometricCameraRigScript.new()
	rig.follow_speed = 10.0
	rig.acceleration = 20.0
	rig.deceleration = 30.0
	rig.dead_zone = 0.05
	rig.target_offset = Vector3(0.0, 1.0, 0.0)

	var target := Node3D.new()
	target.global_position = Vector3(0.0, 0.0, 0.0)
	rig.set_target(target)

	# 1. Teleport inicial
	rig.teleport_to_target()
	assert(rig.global_position.is_equal_approx(Vector3(0.0, 1.0, 0.0)), "FAIL: teleport_to_target should immediately align to target + offset")

	# 2. Desplazar target 10 metros en X
	target.global_position = Vector3(10.0, 0.0, 0.0)

	# Simular un paso de físicas (0.016s)
	rig.process_physics_step(0.016)
	assert(rig.global_position.x > 0.0, "FAIL: Camera rig should accelerate towards target")
	assert(rig.global_position.x < 10.0, "FAIL: Camera rig should not snap instantly to target")

	# Simular 2 segundos de seguimiento
	for _i in range(120):
		rig.process_physics_step(0.016)

	assert(is_equal_approx(rig.global_position.x, 10.0), "FAIL: Camera rig should smoothly converge to target X position")
	assert(is_equal_approx(rig.global_position.y, 1.0), "FAIL: Camera rig should maintain target_offset Y")

	target.free()
	rig.free()

	print("[PASS] test_camera_smooth_follow completed successfully.")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_smooth_follow.gd`
Expected: FAIL with "Nonexistent function process_physics_step or teleport_to_target".

- [ ] **Step 3: Write minimal implementation**

In `src/presentation/camera/isometric_camera_rig.gd`, add kinematic follow properties and functions:

```gdscript
@export_group("Smooth Follow Physics")
@export var follow_speed: float = 12.0
@export var acceleration: float = 30.0
@export var deceleration: float = 40.0
@export var dead_zone: float = 0.05

var _current_velocity := Vector3.ZERO

func _physics_process(delta: float) -> void:
	process_physics_step(delta)

func process_physics_step(delta: float) -> void:
	if not follow_enabled or target == null or not is_instance_valid(target):
		_current_velocity = Vector3.ZERO
		return

	var desired_pos: Vector3 = target.global_position + target_offset
	var to_target: Vector3 = desired_pos - global_position
	var distance: float = to_target.length()

	if distance <= dead_zone:
		_current_velocity = _current_velocity.move_toward(Vector3.ZERO, deceleration * delta)
		return

	var dir: Vector3 = to_target / distance
	# Escalar velocidad deseada según la distancia para frenado natural
	var target_speed: float = minf(follow_speed, distance * (follow_speed * 0.5))
	var desired_vel: Vector3 = dir * target_speed

	var accel_rate: float = acceleration if desired_vel.length_squared() > _current_velocity.length_squared() else deceleration
	_current_velocity = _current_velocity.move_toward(desired_vel, accel_rate * delta)

	global_position += _current_velocity * delta

func teleport_to_target() -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position + target_offset
		_current_velocity = Vector3.ZERO

func set_follow_enabled(enabled: bool) -> void:
	follow_enabled = enabled
	if not enabled:
		_current_velocity = Vector3.ZERO
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_smooth_follow.gd`
Expected: PASS with `[PASS] test_camera_smooth_follow completed successfully.`

- [ ] **Step 5: Commit**

```bash
git add src/presentation/camera/isometric_camera_rig.gd tests/presentation/test_camera_smooth_follow.gd
git commit -m "feat(camera): implement smooth kinematic target following with acceleration and deceleration"
```

---

### Task 3: Smooth Orthogonal Zoom System (Commit 3)

**Files:**
- Modify: `src/presentation/camera/isometric_camera_rig.gd`
- Test: `tests/presentation/test_camera_zoom.gd`

**Interfaces:**
- Consumes: `zoom_min: float`, `zoom_max: float`, `zoom_speed: float`, `zoom_smoothing: float`.
- Produces: `set_zoom(val: float)`, `zoom_in(amount: float)`, `zoom_out(amount: float)`, `get_zoom() -> float`, signal `zoom_changed(value: float)`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/presentation/test_camera_zoom.gd
extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_zoom ---")
	print("==================================================================")

	var rig = IsometricCameraRigScript.new()
	rig.zoom_min = 8.0
	rig.zoom_max = 48.0
	rig.zoom_step = 2.0
	rig.default_zoom = 20.0
	rig.zoom_smoothing = 15.0

	var cam = rig.get_camera()
	assert(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "FAIL: Camera must be ORTHOGONAL")

	# 1. Verificar zoom inicial
	assert(is_equal_approx(rig.get_zoom(), 20.0), "FAIL: Initial zoom should match default_zoom")

	# 2. Zoom In y Clamping
	rig.zoom_in(4.0)
	assert(is_equal_approx(rig.target_zoom, 16.0), "FAIL: target_zoom should be 16.0 after zoom_in(4)")

	rig.zoom_in(100.0)
	assert(is_equal_approx(rig.target_zoom, 8.0), "FAIL: target_zoom should clamp to zoom_min (8.0)")

	# 3. Zoom Out y Clamping
	rig.zoom_out(100.0)
	assert(is_equal_approx(rig.target_zoom, 48.0), "FAIL: target_zoom should clamp to zoom_max (48.0)")

	# 4. Interpolación suave de zoom en process
	rig.set_zoom(24.0)
	rig.process_zoom_step(0.1)
	assert(cam.size < 48.0 and cam.size > 24.0, "FAIL: Camera size should smoothly interpolate towards target_zoom")

	for _i in range(60):
		rig.process_zoom_step(0.05)
	assert(is_equal_approx(cam.size, 24.0), "FAIL: Camera size should converge to target_zoom")

	rig.free()
	print("[PASS] test_camera_zoom completed successfully.")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_zoom.gd`
Expected: FAIL with "Nonexistent function zoom_in or target_zoom".

- [ ] **Step 3: Write minimal implementation**

In `src/presentation/camera/isometric_camera_rig.gd`, add zoom configuration and logic:

```gdscript
@export_group("Orthogonal Zoom")
@export var zoom_min: float = 8.0
@export var zoom_max: float = 48.0
@export var zoom_step: float = 2.0
@export var zoom_smoothing: float = 12.0

var target_zoom: float = 24.0:
	set(val):
		var clamped: float = clampf(val, zoom_min, zoom_max)
		if not is_equal_approx(target_zoom, clamped):
			target_zoom = clamped
			zoom_changed.emit(target_zoom)

func _process(delta: float) -> void:
	process_zoom_step(delta)

func process_zoom_step(delta: float) -> void:
	if _camera != null and not is_equal_approx(_camera.size, target_zoom):
		_camera.size = lerpf(_camera.size, target_zoom, clampf(zoom_smoothing * delta, 0.0, 1.0))
		if absf(_camera.size - target_zoom) < 0.01:
			_camera.size = target_zoom

func set_zoom(val: float) -> void:
	self.target_zoom = val

func zoom_in(amount: float = -1.0) -> void:
	var amt: float = zoom_step if amount <= 0.0 else amount
	self.target_zoom -= amt

func zoom_out(amount: float = -1.0) -> void:
	var amt: float = zoom_step if amount <= 0.0 else amount
	self.target_zoom += amt

func get_zoom() -> float:
	return target_zoom
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_zoom.gd`
Expected: PASS with `[PASS] test_camera_zoom completed successfully.`

- [ ] **Step 5: Commit**

```bash
git add src/presentation/camera/isometric_camera_rig.gd tests/presentation/test_camera_zoom.gd
git commit -m "feat(camera): implement smooth orthogonal size-based zoom system with clamping"
```

---

### Task 4: Camera Occlusion Detector Subsystem (Commit 4)

**Files:**
- Create: `src/presentation/camera/camera_occlusion_detector.gd`
- Modify: `src/presentation/camera/isometric_camera_rig.gd`
- Test: `tests/presentation/test_camera_occlusion.gd`

**Interfaces:**
- Consumes: `Camera3D`, Target `Node3D`, `PhysicsDirectSpaceState3D`.
- Produces: `is_target_occluded() -> bool`, `get_active_occluders() -> Array[Node3D]`, discrete signals `occlusion_started(occluders: Array[Node3D])`, `occlusion_ended(occluders: Array[Node3D])`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/presentation/test_camera_occlusion.gd
extends SceneTree

const CameraOcclusionDetectorScript = preload("res://src/presentation/camera/camera_occlusion_detector.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_occlusion ---")
	print("==================================================================")

	var detector = CameraOcclusionDetectorScript.new()
	assert(detector != null, "FAIL: CameraOcclusionDetector should instantiate")
	assert(not detector.is_target_occluded(), "FAIL: Initial occlusion state should be false")

	# Mock de obstáculos
	var mock_wall := StaticBody3D.new()
	mock_wall.name = "WallObstacle"

	var started_fired := false
	var ended_fired := false
	var occluders_received: Array[Node3D] = []

	detector.occlusion_started.connect(func(occs: Array[Node3D]):
		started_fired = true
		occluders_received = occs
	)
	detector.occlusion_ended.connect(func(occs: Array[Node3D]):
		ended_fired = true
	)

	# Simular detección de obstáculo
	detector._update_occlusion_state([mock_wall])
	assert(detector.is_target_occluded(), "FAIL: Target should be marked as occluded")
	assert(started_fired, "FAIL: occlusion_started should be emitted on transition")
	assert(occluders_received.has(mock_wall), "FAIL: occluders array should contain blocking obstacle")

	# Misma lista no debe re-emitir la señal (evento de borde discreto)
	started_fired = false
	detector._update_occlusion_state([mock_wall])
	assert(not started_fired, "FAIL: occlusion_started must NOT emit redundantly without state change")

	# Limpiar obstáculo
	detector._update_occlusion_state([])
	assert(not detector.is_target_occluded(), "FAIL: Target should not be occluded")
	assert(ended_fired, "FAIL: occlusion_ended should be emitted when obstacle is cleared")

	mock_wall.free()
	detector.free()

	print("[PASS] test_camera_occlusion completed successfully.")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_occlusion.gd`
Expected: FAIL with "Cannot open file camera_occlusion_detector.gd".

- [ ] **Step 3: Write minimal implementation**

```gdscript
# src/presentation/camera/camera_occlusion_detector.gd
class_name CameraOcclusionDetector
extends Node

## Subsistema de Detección de Oclusión Desacoplado.
## Realiza queries de rayos múltiples (centro, superior, inferior) entre la cámara y el objetivo,
## emitiendo señales discretas por flanco únicamente cuando el estado de oclusión cambia.

signal occlusion_started(occluders: Array[Node3D])
signal occlusion_ended(occluders: Array[Node3D])

@export var enabled: bool = true
@export_flags_3d_physics var collision_mask: int = 1
@export var sample_offsets: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),   # Centro del objetivo
	Vector3(0.0, 0.6, 0.0),   # Torso / Cabeza
	Vector3(0.0, -0.5, 0.0)   # Base / Pies
]
@export_range(0.1, 1.0, 0.1) var occlusion_threshold: float = 0.5 # Proporción de rayos requerida

var _is_occluded: bool = false
var _active_occluders: Array[Node3D] = []

func is_target_occluded() -> bool:
	return _is_occluded

func get_active_occluders() -> Array[Node3D]:
	return _active_occluders

func perform_occlusion_check(camera: Camera3D, target: Node3D, space_state: PhysicsDirectSpaceState3D) -> void:
	if not enabled or camera == null or target == null or space_state == null:
		if _is_occluded:
			_update_occlusion_state([])
		return

	var cam_pos: Vector3 = camera.global_position
	var target_base: Vector3 = target.global_position
	var found_occluders: Array[Node3D] = []
	var hits: int = 0

	for offset in sample_offsets:
		var target_point: Vector3 = target_base + offset
		var query := PhysicsRayQueryParameters3D.create(cam_pos, target_point, collision_mask)
		# Excluir colisiones del propio objetivo
		if target is CollisionObject3D:
			query.exclude = [target.get_rid()]

		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			hits += 1
			var collider = result.get("collider")
			if collider is Node3D and not found_occluders.has(collider):
				found_occluders.append(collider)

	var hit_ratio: float = float(hits) / float(maxi(1, sample_offsets.size()))
	if hit_ratio >= occlusion_threshold and not found_occluders.is_empty():
		_update_occlusion_state(found_occluders)
	else:
		_update_occlusion_state([])

func _update_occlusion_state(new_occluders: Array[Node3D]) -> void:
	var will_be_occluded: bool = not new_occluders.is_empty()

	if will_be_occluded and not _is_occluded:
		_is_occluded = true
		_active_occluders = new_occluders
		occlusion_started.emit(_active_occluders)
	elif not will_be_occluded and _is_occluded:
		var prev_occluders = _active_occluders.duplicate()
		_is_occluded = false
		_active_occluders.clear()
		occlusion_ended.emit(prev_occluders)
	elif will_be_occluded and _is_occluded:
		_active_occluders = new_occluders
```

Integrate `CameraOcclusionDetector` into `IsometricCameraRig`:
In `src/presentation/camera/isometric_camera_rig.gd`:
- Instantiate `CameraOcclusionDetector` in hierarchy.
- Forward signals `occlusion_started` and `occlusion_ended`.
- Execute `perform_occlusion_check` during `_physics_process()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_occlusion.gd`
Expected: PASS with `[PASS] test_camera_occlusion completed successfully.`

- [ ] **Step 5: Commit**

```bash
git add src/presentation/camera/camera_occlusion_detector.gd src/presentation/camera/isometric_camera_rig.gd tests/presentation/test_camera_occlusion.gd
git commit -m "feat(camera): implement multi-ray CameraOcclusionDetector with edge-triggered state events"
```

---

### Task 5: Dungeon Scene Integration & World Occlusion Wiring (Commit 5)

**Files:**
- Modify: `scenes/dungeon/dungeon_level.tscn`
- Modify: `scenes/dungeon/dungeon_level_controller.gd`
- Test: `tests/presentation/test_camera_integration_e2e.gd`

**Interfaces:**
- Consumes: `IsometricCameraRig.tscn`, `DungeonLevelController`, `PlayerTest`.
- Produces: Seamless player follow in 3D mode, mouse wheel smooth zoom, automated transparency/visibility toggling on occluding wall clusters.

- [ ] **Step 1: Write the failing E2E test**

```gdscript
# tests/presentation/test_camera_integration_e2e.gd
extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")
const PlayerTestScript = preload("res://src/character_test/player_test.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_integration_e2e ---")
	print("==================================================================")

	var root := Node3D.new()
	var rig = IsometricCameraRigScript.new()
	var player = PlayerTestScript.new()

	root.add_child(rig)
	root.add_child(player)

	player.position = Vector3(14.0, 0.0, 14.0)
	rig.set_target(player)
	rig.teleport_to_target()

	assert(is_equal_approx(rig.global_position.x, 14.0), "FAIL: Rig should be positioned at player X")
	assert(is_equal_approx(rig.global_position.z, 14.0), "FAIL: Rig should be positioned at player Z")

	# Test Zoom In / Zoom Out API
	var initial_zoom = rig.get_zoom()
	rig.zoom_in()
	assert(rig.target_zoom < initial_zoom, "FAIL: zoom_in should decrease orthogonal size")

	rig.zoom_out()
	assert(is_equal_approx(rig.target_zoom, initial_zoom), "FAIL: zoom_out should restore orthogonal size")

	player.free()
	rig.free()
	root.free()

	print("[PASS] test_camera_integration_e2e completed successfully.")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_integration_e2e.gd`
Expected: PASS/FAIL validation.

- [ ] **Step 3: Wire `IsometricCameraRig` into `dungeon_level.tscn` and `dungeon_level_controller.gd`**

1. Replace legacy manual `Camera3D` with instance of `IsometricCameraRig.tscn` in `scenes/dungeon/dungeon_level.tscn`.
2. In `scenes/dungeon/dungeon_level_controller.gd`:
   - When player spawns in `build_3d_presentation()`, call `camera_rig.set_target(_player)` and `camera_rig.teleport_to_target()`.
   - Connect mouse wheel events to `camera_rig.zoom_in()` and `camera_rig.zoom_out()`.
   - Connect `camera_rig.occlusion_started` and `camera_rig.occlusion_ended` to modulate occluder wall visibility/fade cleanly.

- [ ] **Step 4: Run all automated test suites to ensure zero regressions**

Run:
```bash
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_contracts.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_smooth_follow.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_zoom.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_occlusion.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_integration_e2e.gd
```
Expected: ALL 5 suites PASS.

- [ ] **Step 5: Commit**

```bash
git add scenes/dungeon/dungeon_level.tscn scenes/dungeon/dungeon_level_controller.gd tests/presentation/test_camera_integration_e2e.gd
git commit -m "feat(camera): integrate IsometricCameraRig into dungeon level controller and presentation"
```

---

### Verification Plan

#### Automated Tests
Execute the 5 dedicated headless test suites:
```bash
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_contracts.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_smooth_follow.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_zoom.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_occlusion.gd
Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/test_camera_integration_e2e.gd
```

#### Manual Verification
1. Run main scene:
   `Godot_v4.6.1-stable_win64.exe res://scenes/dungeon/dungeon_level.tscn`
2. Press `Espacio` to generate 3D dungeon.
3. Move player with arrow keys: Verify camera follows with smooth acceleration/deceleration at a fixed isometric 45° angle.
4. Scroll mouse wheel: Verify smooth orthogonal zoom without camera distance distortion.
5. Move player behind a high wall: Verify occlusion detection detects blocking walls and triggers clean presentation response.
