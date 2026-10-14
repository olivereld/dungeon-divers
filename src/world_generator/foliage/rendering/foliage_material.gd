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
static func get_or_create_material(species: Resource, wind_strength: float = 0.25, wind_speed: float = 1.6) -> ShaderMaterial:
	if species == null:
		return null

	var actual_wind_strength: float = species.wind_strength if ("wind_strength" in species and species.wind_strength >= 0.0) else wind_strength
	var actual_wind_speed: float = species.wind_speed if ("wind_speed" in species and species.wind_speed >= 0.0) else wind_speed

	var sp_id: StringName = species.id if "id" in species else &"default"
	var cache_key := "%s_ws%.2f_sp%.2f" % [String(sp_id), actual_wind_strength, actual_wind_speed]

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

	if "gradient_texture_path" in species and not species.gradient_texture_path.is_empty():
		var grad_tex = load(species.gradient_texture_path)
		if grad_tex != null:
			mat.set_shader_parameter("gradient_texture", grad_tex)
			mat.set_shader_parameter("use_gradient_texture", true)
		else:
			mat.set_shader_parameter("use_gradient_texture", false)
	else:
		mat.set_shader_parameter("use_gradient_texture", false)

	var actual_gradient_influence: float = 0.20
	if "gradient_influence" in species and species.gradient_influence >= 0.0:
		actual_gradient_influence = species.gradient_influence
	elif "foliage_type" in species and species.foliage_type != 0:
		actual_gradient_influence = 0.85
	mat.set_shader_parameter("gradient_influence", actual_gradient_influence)

	if "use_upward_normals" in species:
		mat.set_shader_parameter("use_upward_normals", species.use_upward_normals)

	mat.set_shader_parameter("wind_strength", actual_wind_strength)
	mat.set_shader_parameter("wind_speed", actual_wind_speed)

	_material_cache[cache_key] = mat
	return mat

static func clear_cache() -> void:
	_material_cache.clear()
