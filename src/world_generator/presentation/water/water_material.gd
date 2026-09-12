class_name WaterMaterial
extends RefCounted

## Fábrica de materiales de agua para el pipeline de presentación.
## Provee soporte dual: ShaderMaterial estilizado (con ondas de orilla, espuma y profundidad)
## o StandardMaterial3D de alto rendimiento.

const _ShaderRes = preload("res://src/world_generator/presentation/water/water_flow.gdshader")
static var _cached_noise_tex: NoiseTexture2D = null

static func _get_or_create_noise_texture() -> NoiseTexture2D:
	if _cached_noise_tex != null:
		return _cached_noise_tex

	var fnl := FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fnl.frequency = 0.035
	fnl.fractal_octaves = 2
	fnl.fractal_lacunarity = 2.0
	fnl.fractal_gain = 0.5

	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = fnl
	_cached_noise_tex = tex
	return _cached_noise_tex

static func create_water_material(profile: WorldProfile, use_shader: bool = true) -> Material:
	if profile == null:
		profile = WorldProfile.new()

	if use_shader and _ShaderRes != null:
		var mat := ShaderMaterial.new()
		mat.shader = _ShaderRes
		mat.set_shader_parameter("color_shallow", profile.water_color_shallow)
		mat.set_shader_parameter("color_deep", profile.water_color_lake)
		mat.set_shader_parameter("roughness", profile.water_roughness)
		mat.set_shader_parameter("noise_texture", _get_or_create_noise_texture())
		return mat
	else:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		mat.roughness = profile.water_roughness
		mat.metallic = 0.12
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return mat
