class_name DungeonCameraRig
extends Node3D

## Isometric camera rig with orthographic framing, smooth zoom, and fixed angles.
## Strictly controls camera behavior for authoring and lab inspection without free WASD/orbit.

const _FramingScript = preload("res://src/dungeon_generator/debug/lab/viewer/dungeon_camera_framing.gd")

const DEFAULT_YAW_DEG: float = 45.0
const DEFAULT_PITCH_DEG: float = -35.264
const MIN_ORTHO_SIZE: float = 6.0
const MAX_ORTHO_SIZE: float = 250.0

@export var camera: Camera3D = null

var target_position: Vector3 = Vector3.ZERO
var target_ortho_size: float = 20.0
var target_distance: float = 40.0

var _pivot_node: Node3D = null

func _ready() -> void:
	_setup_nodes()
	reset_to_default_angle()

func _setup_nodes() -> void:
	if _pivot_node == null:
		var found_pivot = get_node_or_null("CameraPivot")
		if found_pivot != null:
			_pivot_node = found_pivot as Node3D
		else:
			_pivot_node = Node3D.new()
			_pivot_node.name = "CameraPivot"
			add_child(_pivot_node)
	
	if camera == null:
		var found_cam = _pivot_node.get_node_or_null("Camera3D")
		if found_cam != null:
			camera = found_cam as Camera3D
		else:
			camera = Camera3D.new()
			camera.name = "Camera3D"
			_pivot_node.add_child(camera)
	
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = target_ortho_size
	camera.position = Vector3(0, 0, target_distance)
	camera.current = true

func reset_to_default_angle() -> void:
	if _pivot_node == null:
		_setup_nodes()
	_pivot_node.rotation_degrees = Vector3(DEFAULT_PITCH_DEG, DEFAULT_YAW_DEG, 0.0)

func frame_aabb(aabb_min: Vector3, aabb_max: Vector3) -> void:
	if _pivot_node == null or camera == null:
		_setup_nodes()
	
	var framing: Dictionary = _FramingScript.compute_framing(
		aabb_min,
		aabb_max,
		_FramingScript.ProjectionMode.ORTHOGONAL,
		20.0
	)
	
	target_position = framing["center"]
	target_ortho_size = clampf(framing["ortho_size"], MIN_ORTHO_SIZE, MAX_ORTHO_SIZE)
	target_distance = framing["distance"]
	
	if is_inside_tree():
		global_position = target_position
	else:
		position = target_position
	camera.size = target_ortho_size
	camera.position = Vector3(0, 0, target_distance)
	reset_to_default_angle()

func frame_node(node: Node3D) -> void:
	var aabb_data: Dictionary = _FramingScript.compute_hierarchy_aabb(node)
	if aabb_data["valid"]:
		frame_aabb(aabb_data["min"], aabb_data["max"])
	else:
		frame_aabb(Vector3.ZERO, Vector3.ZERO)

func adjust_zoom(delta_steps: float) -> void:
	if camera == null:
		return
	var zoom_factor: float = 1.0 - (delta_steps * 0.1)
	target_ortho_size = clampf(camera.size * zoom_factor, MIN_ORTHO_SIZE, MAX_ORTHO_SIZE)
	camera.size = target_ortho_size

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.is_pressed():
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				adjust_zoom(1.0)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				adjust_zoom(-1.0)
