class_name IsometricCameraRig
extends Node3D

## Módulo de Cámara Isométrica Desacoplado y Reutilizable.
## Mantiene una proyección ortogonal y orientación fija en ángulo isométrico (Yaw=45°, Pitch=~35.264°, Roll=0°).
## Incluye seguimiento cinemático suavizado, zoom ortogonal con interpolación y detección de oclusión multi-rayo.

signal target_changed(target: Node3D)
signal zoom_changed(value: float)
signal occlusion_started(occluders: Array[Node3D])
signal occlusion_ended(occluders: Array[Node3D])

const _CameraOcclusionDetectorScript = preload("res://src/presentation/camera/camera_occlusion_detector.gd")

var _target: Node3D = null
var _target_zoom: float = 24.0

@export_group("Target Tracking")
@export var target: Node3D:
	get:
		return _target
	set(val):
		set_target(val)
@export var target_offset: Vector3 = Vector3(0.0, 0.7, 0.0)
@export var follow_enabled: bool = true

@export_group("Smooth Follow Physics")
@export var follow_speed: float = 12.0
@export var acceleration: float = 30.0
@export var deceleration: float = 40.0
@export var dead_zone: float = 0.05

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

@export_group("Orthogonal Zoom")
@export var default_zoom: float = 24.0
@export var zoom_min: float = 8.0
@export var zoom_max: float = 48.0
@export var zoom_step: float = 2.0
@export var zoom_smoothing: float = 12.0

@export_group("Occlusion Detection")
@export var occlusion_enabled: bool = true:
	set(val):
		occlusion_enabled = val
		if _occlusion_detector != null:
			_occlusion_detector.enabled = val

var target_zoom: float:
	get:
		return _target_zoom
	set(val):
		set_zoom(val)

var _pivot: Node3D = null
var _camera: Camera3D = null
var _current_velocity := Vector3.ZERO
var _occlusion_detector: _CameraOcclusionDetectorScript = null

func _ready() -> void:
	_setup_internal_hierarchy()
	_update_orientation()
	_target_zoom = default_zoom

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

	_occlusion_detector = get_node_or_null("CameraOcclusionDetector")
	if _occlusion_detector == null:
		_occlusion_detector = _CameraOcclusionDetectorScript.new()
		_occlusion_detector.name = "CameraOcclusionDetector"
		_occlusion_detector.enabled = occlusion_enabled
		add_child(_occlusion_detector)

	if not _occlusion_detector.occlusion_started.is_connected(_on_occlusion_started):
		_occlusion_detector.occlusion_started.connect(_on_occlusion_started)
	if not _occlusion_detector.occlusion_ended.is_connected(_on_occlusion_ended):
		_occlusion_detector.occlusion_ended.connect(_on_occlusion_ended)

func _update_orientation() -> void:
	if _pivot == null:
		_setup_internal_hierarchy()
	_pivot.rotation = Vector3(
		deg_to_rad(-pitch_degrees),
		deg_to_rad(yaw_degrees),
		deg_to_rad(roll_degrees)
	)
	if _camera != null:
		_camera.position = Vector3(0.0, 0.0, camera_distance)

func _physics_process(delta: float) -> void:
	process_physics_step(delta)
	_process_occlusion_check()

func process_physics_step(delta: float) -> void:
	if not follow_enabled or _target == null or not is_instance_valid(_target):
		_current_velocity = Vector3.ZERO
		return

	var desired_pos: Vector3 = _target.global_position + target_offset
	var to_target: Vector3 = desired_pos - global_position
	var distance: float = to_target.length()

	if distance <= dead_zone:
		_current_velocity = _current_velocity.move_toward(Vector3.ZERO, deceleration * delta)
		return

	var dir: Vector3 = to_target / distance
	var target_speed: float = minf(follow_speed, distance * (follow_speed * 0.5))
	var desired_vel: Vector3 = dir * target_speed

	var accel_rate: float = acceleration if desired_vel.length_squared() > _current_velocity.length_squared() else deceleration
	_current_velocity = _current_velocity.move_toward(desired_vel, accel_rate * delta)

	global_position += _current_velocity * delta

func _process(delta: float) -> void:
	process_zoom_step(delta)

func process_zoom_step(delta: float) -> void:
	if _camera != null and not is_equal_approx(_camera.size, _target_zoom):
		var weight: float = 1.0 - exp(-zoom_smoothing * delta)
		_camera.size = lerpf(_camera.size, _target_zoom, weight)
		if absf(_camera.size - _target_zoom) < 0.01:
			_camera.size = _target_zoom

func _process_occlusion_check() -> void:
	if _occlusion_detector != null and _camera != null and _target != null and is_inside_tree():
		var space := get_world_3d().direct_space_state if get_world_3d() != null else null
		if space != null:
			_occlusion_detector.perform_occlusion_check(_camera, _target, space)

func _on_occlusion_started(occluders: Array[Node3D]) -> void:
	occlusion_started.emit(occluders)

func _on_occlusion_ended(occluders: Array[Node3D]) -> void:
	occlusion_ended.emit(occluders)

func is_target_occluded() -> bool:
	return _occlusion_detector.is_target_occluded() if _occlusion_detector != null else false

func get_occlusion_detector() -> _CameraOcclusionDetectorScript:
	if _occlusion_detector == null:
		_setup_internal_hierarchy()
	return _occlusion_detector

func set_target(p_target: Node3D) -> void:
	if _target != p_target:
		_target = p_target
		target_changed.emit(_target)

func clear_target() -> void:
	set_target(null)

func teleport_to_target() -> void:
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position + target_offset
		_current_velocity = Vector3.ZERO

func set_follow_enabled(enabled: bool) -> void:
	follow_enabled = enabled
	if not enabled:
		_current_velocity = Vector3.ZERO

func set_zoom(val: float) -> void:
	var clamped: float = clampf(val, zoom_min, zoom_max)
	if not is_equal_approx(_target_zoom, clamped):
		_target_zoom = clamped
		zoom_changed.emit(_target_zoom)

func zoom_in(amount: float = -1.0) -> void:
	var amt: float = zoom_step if amount <= 0.0 else amount
	set_zoom(_target_zoom - amt)

func zoom_out(amount: float = -1.0) -> void:
	var amt: float = zoom_step if amount <= 0.0 else amount
	set_zoom(_target_zoom + amt)

func get_zoom() -> float:
	return _target_zoom

func get_camera() -> Camera3D:
	if _camera == null:
		_setup_internal_hierarchy()
	return _camera
