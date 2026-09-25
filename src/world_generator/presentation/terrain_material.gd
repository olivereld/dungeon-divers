class_name TerrainMaterial
extends RefCounted

## Fábrica de materiales de terreno procedural con soporte para ShaderMaterial
## (mezcla de texturas hand-painted en cuencas/orillas) y fallback a StandardMaterial3D.

const TERRAIN_SHADER_PATH: String = "res://src/world_renderer/shaders/terrain.gdshader"
const RIVERBED_TEXTURE_PATH: String = "res://assets/texture/world/stone/Stone_01.png"
const SAND_TEXTURE_PATH: String = "res://assets/texture/world/dirt/Dirt_01.png"
const GRASS_TEXTURE_PATH: String = "res://assets/texture/world/grass/Grass_01.png"
const FOREST_GRASS_TEXTURE_PATH: String = "res://assets/texture/world/grass/Grass_03.png"
const FOREST_DIRT_TEXTURE_PATH: String = "res://assets/texture/world/dirt/Dirt_04.png"
const CLIFF_TEXTURE_PATH: String = "res://assets/texture/world/cliff/cliff_02.jpg"

static var _cached_shader: Shader = null
static var _cached_riverbed_tex: Texture2D = null
static var _cached_sand_tex: Texture2D = null
static var _cached_grass_tex: Texture2D = null
static var _cached_forest_grass_tex: Texture2D = null
static var _cached_forest_dirt_tex: Texture2D = null
static var _cached_cliff_tex: Texture2D = null

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

static func _get_forest_grass_texture() -> Texture2D:
	if _cached_forest_grass_tex == null and ResourceLoader.exists(FOREST_GRASS_TEXTURE_PATH):
		_cached_forest_grass_tex = load(FOREST_GRASS_TEXTURE_PATH) as Texture2D
	return _cached_forest_grass_tex

static func _get_forest_dirt_texture() -> Texture2D:
	if _cached_forest_dirt_tex == null and ResourceLoader.exists(FOREST_DIRT_TEXTURE_PATH):
		_cached_forest_dirt_tex = load(FOREST_DIRT_TEXTURE_PATH) as Texture2D
	return _cached_forest_dirt_tex

static func _get_cliff_texture() -> Texture2D:
	if _cached_cliff_tex == null and ResourceLoader.exists(CLIFF_TEXTURE_PATH):
		_cached_cliff_tex = load(CLIFF_TEXTURE_PATH) as Texture2D
	return _cached_cliff_tex

static func create_material(profile: WorldProfile = null, use_shader: bool = true) -> Material:
	var shader: Shader = _get_shader() if use_shader else null
	var river_tex: Texture2D = _get_riverbed_texture() if use_shader else null
	var sand_tex: Texture2D = _get_sand_texture() if use_shader else null
	var grass_tex: Texture2D = _get_grass_texture() if use_shader else null
	var forest_grass_tex: Texture2D = _get_forest_grass_texture() if use_shader else null
	var forest_dirt_tex: Texture2D = _get_forest_dirt_texture() if use_shader else null
	var cliff_tex: Texture2D = _get_cliff_texture() if use_shader else null

	if shader != null and river_tex != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("riverbed_texture", river_tex)
		var r_uv: float = float(profile.riverbed_uv_scale) if (profile != null and "riverbed_uv_scale" in profile) else 0.35
		var s_uv: float = float(profile.sand_uv_scale) if (profile != null and "sand_uv_scale" in profile) else 0.40
		var g_uv: float = float(profile.grass_uv_scale) if (profile != null and "grass_uv_scale" in profile) else 0.35
		var fg_uv: float = float(profile.forest_grass_uv_scale) if (profile != null and "forest_grass_uv_scale" in profile) else 0.35
		var fd_uv: float = float(profile.forest_dirt_uv_scale) if (profile != null and "forest_dirt_uv_scale" in profile) else 0.35

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

		if forest_grass_tex != null:
			mat.set_shader_parameter("forest_grass_texture", forest_grass_tex)
		else:
			mat.set_shader_parameter("forest_grass_texture", grass_tex if grass_tex != null else river_tex)
		mat.set_shader_parameter("forest_grass_uv_scale", fg_uv)

		if forest_dirt_tex != null:
			mat.set_shader_parameter("forest_dirt_texture", forest_dirt_tex)
		else:
			mat.set_shader_parameter("forest_dirt_texture", sand_tex if sand_tex != null else river_tex)
		mat.set_shader_parameter("forest_dirt_uv_scale", fd_uv)

		if cliff_tex != null:
			mat.set_shader_parameter("cliff_texture", cliff_tex)
		else:
			mat.set_shader_parameter("cliff_texture", river_tex)
		var c_uv: float = float(profile.cliff_uv_scale) if (profile != null and "cliff_uv_scale" in profile) else 0.25
		mat.set_shader_parameter("cliff_uv_scale", c_uv)

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

		var g_tint := Color.WHITE
		var fg_tint := Color.WHITE
		var fd_tint := Color.WHITE
		var s_tint := Color.WHITE
		var r_tint := Color.WHITE
		var c_tint := Color.WHITE

		if profile != null:
			g_tint = profile.terrain_grass_color.lightened(0.20)
			fg_tint = profile.terrain_moss_color.lightened(0.15)
			fd_tint = profile.forest_floor_color.lightened(0.30)
			s_tint = profile.terrain_moss_color.lightened(0.25)
			r_tint = profile.terrain_rock_color.lightened(0.20)
			c_tint = profile.terrain_rock_color.lightened(0.10)

		mat.set_shader_parameter("riverbed_tint", r_tint)
		mat.set_shader_parameter("sand_tint", s_tint)
		mat.set_shader_parameter("grass_tint", g_tint)
		mat.set_shader_parameter("forest_grass_tint", fg_tint)
		mat.set_shader_parameter("cliff_tint", c_tint)

		var step_h: float = float(profile.elevation_step_height) if (profile != null and "elevation_step_height" in profile) else 2.0
		var base_h: float = float(profile.base_height) if (profile != null and "base_height" in profile) else 2.0
		mat.set_shader_parameter("elevation_step_height", step_h)
		mat.set_shader_parameter("base_height", base_h)
		mat.set_shader_parameter("overhang_depth", 0.35)
		mat.set_shader_parameter("overhang_noise_scale", 1.8)
		mat.set_shader_parameter("dirt_rim_width", 0.12)
		return mat

	# Fallback a StandardMaterial3D
	var std_mat := StandardMaterial3D.new()
	std_mat.vertex_color_use_as_albedo = true
	std_mat.roughness = 0.90
	std_mat.metallic_specular = 0.05
	return std_mat
