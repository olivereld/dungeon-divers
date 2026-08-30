class_name Dungeon3DViewer
extends Node3D

## Dedicated 3D presentation viewer for DungeonLevelLab.
## Purely consumes DungeonSemanticResult / PresentationBuilder and renders/frames the 3D scene.

const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")
const _CameraRigScript = preload("res://src/dungeon_generator/debug/lab/viewer/dungeon_camera_rig.gd")
const _FramingScript = preload("res://src/dungeon_generator/debug/lab/viewer/dungeon_camera_framing.gd")

@export var dungeon_root: Node3D = null
@export var camera_rig: _CameraRigScript = null
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
	
	if camera_rig == null:
		var found_rig = get_node_or_null("CameraRig")
		if found_rig != null:
			camera_rig = found_rig as _CameraRigScript
		else:
			camera_rig = _CameraRigScript.new()
			camera_rig.name = "CameraRig"
			add_child(camera_rig)
	
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
			directional_light.light_color = Color(0.4, 0.55, 0.75, 1.0)
			directional_light.light_energy = 0.18
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
		frame_dungeon()
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
	
	frame_dungeon()
	return pres_result

## Re-frames the camera around the active dungeon presentation.
func frame_dungeon() -> void:
	_ensure_components()
	if _current_presentation != null:
		camera_rig.frame_node(_current_presentation)
	else:
		camera_rig.frame_aabb(Vector3.ZERO, Vector3.ZERO)

## Returns computed bounding box of the active presentation.
func get_dungeon_bounds() -> Dictionary:
	if _current_presentation == null:
		return {"min": Vector3.ZERO, "max": Vector3.ZERO, "center": Vector3.ZERO}
	
	var aabb_data: Dictionary = _FramingScript.compute_hierarchy_aabb(_current_presentation)
	var center_val: Vector3 = (aabb_data["min"] + aabb_data["max"]) * 0.5 if aabb_data["valid"] else Vector3.ZERO
	return {
		"min": aabb_data["min"] if aabb_data["valid"] else Vector3.ZERO,
		"max": aabb_data["max"] if aabb_data["valid"] else Vector3.ZERO,
		"center": center_val
	}

## Multi-floor reaction: rebuilds active floor presentation.
func on_floor_changed(
	floor_idx: int,
	multi_result: DungeonMultiFloorResult,
	builder: _DungeonPresentationBuilderScript = null,
	config: DungeonConfig = null,
	biome: BiomeProfile = null
) -> void:
	if multi_result == null:
		clear()
		return
	
	var floor_numbers: Array[int] = multi_result.get_floor_numbers()
	if floor_idx < 0 or floor_idx >= floor_numbers.size():
		clear()
		return
	
	var fn: int = floor_numbers[floor_idx]
	var floor_data = multi_result.get_floor(fn)
	if floor_data != null and floor_data.semantic_result != null:
		load_dungeon(floor_data.semantic_result, builder, config, biome)
	else:
		clear()

## Generation failure reaction: clear scene and show empty state.
func on_generation_failed(error_message: String = "") -> void:
	clear()
	frame_dungeon()
