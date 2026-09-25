class_name WaterMaterial
extends RefCounted

## Fábrica de materiales de agua para el pipeline de presentación.
## Provee soporte dual: ShaderMaterial estilizado (con ondas de orilla, espuma y profundidad)
## o StandardMaterial3D de alto rendimiento.

const _ShaderRes = preload("res://src/world_generator/presentation/water/water_flow.gdshader")
const WATER_TEXTURE_PATH: String = "res://assets/texture/world/water/Water_01.png"
static var _cached_noise_tex: NoiseTexture2D = null
static var _cached_water_tex: Texture2D = null

static func _get_water_texture() -> Texture2D:
	if _cached_water_tex == null and ResourceLoader.exists(WATER_TEXTURE_PATH):
		_cached_water_tex = load(WATER_TEXTURE_PATH) as Texture2D
	return _cached_water_tex

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
		var col_shore: Color = profile.water_color_shallow.lightened(0.15)
		col_shore.a = 0.45
		var col_shallow: Color = profile.water_color_shallow
		col_shallow.a = 0.55
		var col_mid: Color = profile.water_color_medium
		col_mid.a = 0.75
		var col_deep: Color = profile.water_color_lake
		col_deep.a = 0.88

		mat.set_shader_parameter("color_shore", col_shore)
		mat.set_shader_parameter("color_shallow", col_shallow)
		mat.set_shader_parameter("color_mid", col_mid)
		mat.set_shader_parameter("color_deep", col_deep)
		mat.set_shader_parameter("roughness", profile.water_roughness)
		mat.set_shader_parameter("noise_texture", _get_or_create_noise_texture())
		var w_tex := _get_water_texture()
		if w_tex != null:
			mat.set_shader_parameter("water_texture", w_tex)

		var default_ripples: Array[Vector4] = []
		for i in range(8):
			default_ripples.append(Vector4(0.0, 0.0, -100.0, 0.0))
		mat.set_shader_parameter("ripples", default_ripples)
		mat.set_shader_parameter("player_pos", Vector3(0.0, -100.0, 0.0))
		mat.set_shader_parameter("player_speed", 0.0)
		mat.set_shader_parameter("player_in_water", 0.0)

		# Parámetros dedicados de cascadas
		mat.set_shader_parameter("waterfall_speed", 3.0)
		mat.set_shader_parameter("waterfall_scroll_speed", Vector2(0.0, -1.2))
		mat.set_shader_parameter("waterfall_wave_strength", 0.035)
		mat.set_shader_parameter("waterfall_alpha", 0.90)
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
