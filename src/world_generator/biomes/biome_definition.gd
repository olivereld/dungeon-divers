class_name BiomeDefinition
extends Resource

## Define la identidad y perfiles de datos de un bioma (fuente de verdad).
## Desacoplada de la lógica de selección de terreno o código de stages.

const _EcologyProfileScript = preload("res://src/world_generator/biomes/profiles/ecology_profile.gd")
const _VegetationProfileScript = preload("res://src/world_generator/biomes/profiles/vegetation_profile.gd")
const _RockProfileScript = preload("res://src/world_generator/biomes/profiles/rock_profile.gd")
const _RenderingProfileScript = preload("res://src/world_generator/biomes/profiles/rendering_profile.gd")

@export var id: StringName = &"taiga"
@export var display_name: String = "Taiga"

@export var ecology_profile: Resource
@export var vegetation_profile: Resource
@export var rock_profile: Resource
@export var rendering_profile: Resource

func _init(
	p_id: StringName = &"taiga",
	p_name: String = "Taiga",
	p_eco: Resource = null,
	p_veg: Resource = null,
	p_rock: Resource = null,
	p_rend: Resource = null
) -> void:
	id = p_id
	display_name = p_name
	ecology_profile = p_eco if p_eco != null else _EcologyProfileScript.new()
	vegetation_profile = p_veg if p_veg != null else _VegetationProfileScript.new()
	rock_profile = p_rock if p_rock != null else _RockProfileScript.new()
	rendering_profile = p_rend if p_rend != null else _RenderingProfileScript.new()
