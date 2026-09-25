class_name RockMaterial
extends RefCounted

## Fábrica y gestor de ShaderMaterial para rocas estilizadas.
## Aplica el gradiente canónico de Taiga a la geometría facetada.

const DEFAULT_SHADER_PATH: String = "res://src/rock_generation/shaders/rock_gradient.gdshader"
const DEFAULT_PALETTE_PATH: String = "res://assets/texture/world/stone/gradient_rocks_01.jpg"

static var _cached_shader: Shader = null
static var _cached_palette: Texture2D = null

## Crea un ShaderMaterial configurado para rocas
static func create_rock_material(
	palette_texture: Texture2D = null,
	min_height: float = -0.3,
	max_height: float = 1.8,
	roughness: float = 0.85
) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = _get_or_load_shader()
	mat.shader = shader

	var palette: Texture2D = palette_texture
	if palette == null:
		palette = _get_or_load_palette()

	if palette != null:
		mat.set_shader_parameter("gradient_palette", palette)

	mat.set_shader_parameter("min_height", min_height)
	mat.set_shader_parameter("max_height", max_height)
	mat.set_shader_parameter("normal_weight", 0.55)
	mat.set_shader_parameter("height_weight", 0.45)
	mat.set_shader_parameter("variation_strength", 0.15)
	mat.set_shader_parameter("roughness", roughness)
	mat.set_shader_parameter("specular", 0.15)

	return mat

static func _get_or_load_shader() -> Shader:
	if _cached_shader == null:
		if ResourceLoader.exists(DEFAULT_SHADER_PATH):
			_cached_shader = load(DEFAULT_SHADER_PATH) as Shader
	return _cached_shader

static func _get_or_load_palette() -> Texture2D:
	if _cached_palette == null:
		if ResourceLoader.exists(DEFAULT_PALETTE_PATH):
			_cached_palette = load(DEFAULT_PALETTE_PATH) as Texture2D
	return _cached_palette
