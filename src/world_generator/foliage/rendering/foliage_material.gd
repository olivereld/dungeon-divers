class_name FoliageMaterial
extends RefCounted

## Fábrica y caché de ShaderMaterial para foliage con shader de viento.
## Asigna texturas de albedo, parámetros de alpha scissor, gradientes de color y viento.

const SHADER_PATH: String = "res://src/world_renderer/shaders/foliage_wind.gdshader"
static var _shader: Shader = null
static var _material_cache: Dictionary = {}

static func get_shader() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader

## Crea o recupera del caché un ShaderMaterial configurado para la especie de foliage indicada
static func get_or_create_material(species: Resource, wind_strength: float = 0.35, wind_speed: float = 2.0) -> ShaderMaterial:
	if species == null:
		return null

	var sp_id: StringName = species.id if "id" in species else &"default"
	var cache_key := "%s_ws%.2f_sp%.2f" % [String(sp_id), wind_strength, wind_speed]

	if _material_cache.has(cache_key) and _material_cache[cache_key] != null:
		return _material_cache[cache_key]

	var mat := ShaderMaterial.new()
	mat.shader = get_shader()

	if "texture_path" in species and not species.texture_path.is_empty():
		var tex = load(species.texture_path)
		if tex != null:
			mat.set_shader_parameter("texture_albedo", tex)

	if "color_bottom" in species:
		mat.set_shader_parameter("color_bottom", species.color_bottom)
	if "color_top" in species:
		mat.set_shader_parameter("color_top", species.color_top)

	mat.set_shader_parameter("wind_strength", wind_strength)
	mat.set_shader_parameter("wind_speed", wind_speed)

	_material_cache[cache_key] = mat
	return mat

static func clear_cache() -> void:
	_material_cache.clear()
