class_name PropAssetDefinition
extends Resource

## Definición declarativa pura de cómo materializar un Room Prop.
## Desacopla la fuente de datos (PackedScene o Procedural Builder) del Spawner y del Renderer.

const _PropAssetSourceScript = preload("res://src/presentation/decoration/assets/prop_asset_source.gd")

@export var id: StringName = &""
@export var source_type: int = _PropAssetSourceScript.SourceType.PROCEDURAL
@export var scene: PackedScene = null
@export var scene_path: String = ""
@export var procedural_builder_id: StringName = &""
@export var procedural_params: Dictionary = {}
@export var default_scale: Vector3 = Vector3.ONE
@export var default_rotation_offset_y: float = 0.0

func _init(
	p_id: StringName = &"",
	p_source: int = _PropAssetSourceScript.SourceType.PROCEDURAL,
	p_builder_id: StringName = &"",
	p_params: Dictionary = {},
	p_scene: PackedScene = null,
	p_scale: Vector3 = Vector3.ONE,
	p_rot_y: float = 0.0,
	p_scene_path: String = ""
) -> void:
	id = p_id
	source_type = p_source
	procedural_builder_id = p_builder_id
	procedural_params = p_params
	scene = p_scene
	default_scale = p_scale
	default_rotation_offset_y = p_rot_y
	scene_path = p_scene_path

func get_packed_scene() -> PackedScene:
	if scene != null:
		return scene
	if scene_path != "" and ResourceLoader.exists(scene_path):
		scene = load(scene_path) as PackedScene
		return scene
	return null

static func create_scene_definition(p_id: StringName, p_scene: PackedScene, p_scale: Vector3 = Vector3.ONE, p_scene_path: String = "") -> Resource:
	var def = new(p_id, _PropAssetSourceScript.SourceType.PACKED_SCENE, &"", {}, p_scene, p_scale, 0.0, p_scene_path)
	return def

static func create_procedural_definition(p_id: StringName, p_builder_id: StringName, p_params: Dictionary = {}, p_scale: Vector3 = Vector3.ONE) -> Resource:
	var def = new(p_id, _PropAssetSourceScript.SourceType.PROCEDURAL, p_builder_id, p_params, null, p_scale)
	return def
