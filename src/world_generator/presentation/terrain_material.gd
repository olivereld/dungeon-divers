class_name TerrainMaterial
extends RefCounted

## Fábrica de materiales de terreno procedural con soporte para ShaderMaterial
## (mezcla de texturas hand-painted en cuencas/orillas) y fallback a StandardMaterial3D.

const TERRAIN_SHADER_PATH: String = "res://src/world_renderer/shaders/terrain.gdshader"
const RIVERBED_TEXTURE_PATH: String = "res://assets/texture/world/stone/Stone_01.png"
const SAND_TEXTURE_PATH: String = "res://assets/texture/world/dirt/Dirt_01.png"
const GRASS_TEXTURE_PATH: String = "res://assets/texture/world/grass/Grass_01.png"

static var _cached_shader: Shader = null
static var _cached_riverbed_tex: Texture2D = null
static var _cached_sand_tex: Texture2D = null
static var _cached_grass_tex: Texture2D = null

static func _get_shader() -> Shader:
	if _cached_shader == null and ResourceLoader.exists(TERRAIN_SHADER_PATH):
		_cached_shader = load(TERRAIN_SHADER_PATH) as Shader
	return _cached_shader

static func _get_riverbed_texture() -> Texture2D:
	if _cached_riverbed_tex == null and ResourceLoader.exists(RIVERBED_TEXTURE_PATH):
		_cached_riverbed_tex = load(RIVERBED_TEXTURE_PATH) as Texture2D
	return _cached_riverbed_tex

static func _get_sand_texture() -> Texture2D:
	if _cached_sand_tex == null and ResourceLoader.exists(SAND_TEXTURE_PATH):
		_cached_sand_tex = load(SAND_TEXTURE_PATH) as Texture2D
	return _cached_sand_tex

static func _get_grass_texture() -> Texture2D:
	if _cached_grass_tex == null and ResourceLoader.exists(GRASS_TEXTURE_PATH):
		_cached_grass_tex = load(GRASS_TEXTURE_PATH) as Texture2D
	return _cached_grass_tex

static func create_material(profile: WorldProfile = null, use_shader: bool = true) -> Material:
	var shader: Shader = _get_shader() if use_shader else null
	var river_tex: Texture2D = _get_riverbed_texture() if use_shader else null
	var sand_tex: Texture2D = _get_sand_texture() if use_shader else null
	var grass_tex: Texture2D = _get_grass_texture() if use_shader else null

	if shader != null and river_tex != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("riverbed_texture", river_tex)
		var r_uv: float = float(profile.riverbed_uv_scale) if (profile != null and "riverbed_uv_scale" in profile) else 0.35
		var s_uv: float = float(profile.sand_uv_scale) if (profile != null and "sand_uv_scale" in profile) else 0.40
		var g_uv: float = float(profile.grass_uv_scale) if (profile != null and "grass_uv_scale" in profile) else 0.35
		mat.set_shader_parameter("riverbed_uv_scale", r_uv)
		if sand_tex != null:
			mat.set_shader_parameter("sand_texture", sand_tex)
		else:
			mat.set_shader_parameter("sand_texture", river_tex)
		mat.set_shader_parameter("sand_uv_scale", s_uv)

		if grass_tex != null:
			mat.set_shader_parameter("grass_texture", grass_tex)
		else:
			mat.set_shader_parameter("grass_texture", sand_tex)
		mat.set_shader_parameter("grass_uv_scale", g_uv)

		var rock_off: float = float(profile.shoreline_rock_offset) if (profile != null and "shoreline_rock_offset" in profile) else 0.35
		var rock_fade: float = float(profile.shoreline_rock_fade) if (profile != null and "shoreline_rock_fade" in profile) else 0.25
		var sand_off: float = float(profile.shoreline_sand_offset) if (profile != null and "shoreline_sand_offset" in profile) else -0.55
		var sand_fade: float = float(profile.shoreline_sand_fade) if (profile != null and "shoreline_sand_fade" in profile) else 0.35

		mat.set_shader_parameter("rock_edge_offset", rock_off)
		mat.set_shader_parameter("rock_to_sand_fade", rock_fade)
		mat.set_shader_parameter("sand_edge_offset", sand_off)
		mat.set_shader_parameter("sand_to_land_fade", sand_fade)

		mat.set_shader_parameter("roughness_land", 0.88)
		mat.set_shader_parameter("roughness_sand", 0.82)
		mat.set_shader_parameter("roughness_riverbed", 0.58)
		mat.set_shader_parameter("riverbed_tint", Color(1.0, 1.0, 1.0, 1.0))
		mat.set_shader_parameter("sand_tint", Color(1.0, 1.0, 1.0, 1.0))
		return mat

	# Fallback a StandardMaterial3D
	var std_mat := StandardMaterial3D.new()
	std_mat.vertex_color_use_as_albedo = true
	std_mat.roughness = 0.90
	std_mat.metallic_specular = 0.05
	return std_mat
