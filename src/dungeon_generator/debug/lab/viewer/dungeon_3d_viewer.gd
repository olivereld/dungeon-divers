class_name Dungeon3DViewer
extends Node3D

## Dedicated 3D presentation viewer for DungeonLevelLab.
## Directly integrates IsometricCameraRig for production-faithful camera presentation.

const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")
const _IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")
const _FramingScript = preload("res://src/dungeon_generator/debug/lab/viewer/dungeon_camera_framing.gd")
const _FocusScript = preload("res://src/dungeon_generator/debug/lab/viewer/dungeon_camera_focus.gd")

@export var dungeon_root: Node3D = null
@export var focus_target: Marker3D = null
@export var camera_rig: _IsometricCameraRigScript = null
@export var world_environment: WorldEnvironment = null
@export var directional_light: DirectionalLight3D = null

var _builder: _DungeonPresentationBuilderScript = null
var _current_presentation: Node3D = null
var _current_result: DungeonSemanticResult = null
var _current_config: DungeonConfig = null
var _current_biome: BiomeProfile = null

func _ready() -> void:
	_ensure_components()

func _ensure_components() -> void:
	if dungeon_root == null:
		var found_root = get_node_or_null("DungeonRoot")
		if found_root != null:
			dungeon_root = found_root as Node3D
		else:
			dungeon_root = Node3D.new()
			dungeon_root.name = "DungeonRoot"
			add_child(dungeon_root)

	if focus_target == null:
		var found_target = get_node_or_null("CameraFocusTarget")
		if found_target != null:
			focus_target = found_target as Marker3D
		else:
			focus_target = Marker3D.new()
			focus_target.name = "CameraFocusTarget"
			add_child(focus_target)

	if camera_rig == null:
		var found_rig = get_node_or_null("IsometricCameraRig")
		if found_rig != null:
			camera_rig = found_rig as _IsometricCameraRigScript
		else:
			camera_rig = _IsometricCameraRigScript.new()
			camera_rig.name = "IsometricCameraRig"
			add_child(camera_rig)

	if camera_rig != null:
		camera_rig.zoom_min = 4.0
		camera_rig.zoom_max = 250.0
		camera_rig.zoom_step = 2.0

	if world_environment == null:
		var found_env = get_node_or_null("WorldEnvironment")
		if found_env != null:
			world_environment = found_env as WorldEnvironment
		else:
			world_environment = WorldEnvironment.new()
			world_environment.name = "WorldEnvironment"
			if ResourceLoader.exists("res://resources/lighting/dungeon_lab_environment.tres"):
				world_environment.environment = load("res://resources/lighting/dungeon_lab_environment.tres")
			add_child(world_environment)

	if directional_light == null:
		var found_light = get_node_or_null("DirectionalLight3D")
		if found_light != null:
			directional_light = found_light as DirectionalLight3D
		else:
			directional_light = DirectionalLight3D.new()
			directional_light.name = "DirectionalLight3D"
			directional_light.transform = Transform3D(
				Vector3(0.707107, 0, -0.707107),
				Vector3(-0.5, 0.707107, -0.5),
				Vector3(0.5, 0.707107, 0.5),
				Vector3(0, 20, 0)
			)
			directional_light.light_color = Color(0.85, 0.9, 1.0, 1.0)
			directional_light.light_energy = 0.65
			directional_light.shadow_enabled = false
			add_child(directional_light)

## Cleans up existing presentation without leaving lingering nodes.
func clear() -> void:
	_ensure_components()
	for child in dungeon_root.get_children():
		dungeon_root.remove_child(child)
		child.queue_free()
	_current_presentation = null
	_current_result = null

## Renders a single floor semantic result using the PresentationBuilder.
func load_dungeon(
	semantic_result: DungeonSemanticResult,
	builder: _DungeonPresentationBuilderScript = null,
	config: DungeonConfig = null,
	biome: BiomeProfile = null
) -> DungeonPresentationResult:
	_ensure_components()
	clear()

	if semantic_result == null:
		if camera_rig != null:
			camera_rig.clear_target()
		return null

	_current_result = semantic_result
	_current_config = config if config != null else DungeonConfig.new()
	_current_biome = biome if biome != null else _BiomeProfileScript.new()
	_builder = builder if builder != null else _DungeonPresentationBuilderScript.new()

	var presentation_node := Node3D.new()
	presentation_node.name = "FloorPresentation"
	dungeon_root.add_child(presentation_node)
	_current_presentation = presentation_node

	var pres_result = _builder.build_presentation(
		_current_result,
		presentation_node,
		_current_biome,
		_current_config,
		null,
		true
	)

	frame_dungeon(true)
	return pres_result

## Re-frames the camera around the active dungeon presentation.
func frame_dungeon(instant_teleport: bool = true) -> void:
	_ensure_components()
	if _current_presentation == null:
		if camera_rig != null:
			camera_rig.clear_target()
		return

	var aabb_data: Dictionary = _FramingScript.compute_hierarchy_aabb(_current_presentation)
	var center: Vector3 = _FocusScript.compute_center(aabb_data["min"], aabb_data["max"])
	var framing: Dictionary = _FramingScript.compute_framing(aabb_data["min"], aabb_data["max"])

	focus_target.global_position = center
	camera_rig.set_target(focus_target)
	camera_rig.set_zoom(framing["ortho_size"])

	if instant_teleport:
		camera_rig.teleport_to_target()

## Smoothly focuses the camera on a specific room.
func focus_room(room: RefCounted, cell_size: float = 2.0) -> void:
	_ensure_components()
	if room == null or camera_rig == null:
		return

	var room_pos: Vector3 = _FocusScript.compute_room_focus(room, cell_size)
	focus_target.global_position = room_pos
	camera_rig.set_target(focus_target)
	camera_rig.set_follow_enabled(true)

## Returns computed bounding box of the active presentation.
func get_dungeon_bounds() -> Dictionary:
	if _current_presentation == null:
		return {"min": Vector3.ZERO, "max": Vector3.ZERO, "center": Vector3.ZERO}

	var aabb_data: Dictionary = _FramingScript.compute_hierarchy_aabb(_current_presentation)
	var center_val: Vector3 = _FocusScript.compute_center(aabb_data["min"], aabb_data["max"])
	return {
		"min": aabb_data["min"] if aabb_data["valid"] else Vector3.ZERO,
		"max": aabb_data["max"] if aabb_data["valid"] else Vector3.ZERO,
		"center": center_val
	}

## Multi-floor reaction: rebuilds active floor presentation and teleports to new floor bounds.
func on_floor_changed(
	floor_idx: int,
	multi_result: DungeonMultiFloorResult,
	builder: _DungeonPresentationBuilderScript = null,
	config: DungeonConfig = null,
	biome: BiomeProfile = null
) -> void:
	if multi_result == null:
		clear()
		if camera_rig != null:
			camera_rig.clear_target()
		return

	var floor_numbers: Array[int] = multi_result.get_floor_numbers()
	if floor_idx < 0 or floor_idx >= floor_numbers.size():
		clear()
		if camera_rig != null:
			camera_rig.clear_target()
		return

	var fn: int = floor_numbers[floor_idx]
	var floor_data = multi_result.get_floor(fn)
	if floor_data != null and floor_data.semantic_result != null:
		load_dungeon(floor_data.semantic_result, builder, config, biome)
	else:
		clear()
		if camera_rig != null:
			camera_rig.clear_target()

## Generation failure reaction: clear scene, clear target, show empty state.
func on_generation_failed(_error_message: String = "") -> void:
	clear()
	if camera_rig != null:
		camera_rig.clear_target()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or camera_rig == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.is_pressed():
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_rig.zoom_in()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_rig.zoom_out()
