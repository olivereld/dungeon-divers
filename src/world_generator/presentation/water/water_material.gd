class_name WaterMaterial
extends RefCounted

## Fábrica de materiales de agua para el pipeline de presentación.
## Provee soporte dual: ShaderMaterial direccional animado o StandardMaterial3D de alto rendimiento.

const _ShaderRes = preload("res://src/world_generator/presentation/water/water_flow.gdshader")

static func create_water_material(profile: WorldProfile, use_shader: bool = true) -> Material:
	if profile == null:
		profile = WorldProfile.new()

	if use_shader and _ShaderRes != null:
		var mat := ShaderMaterial.new()
		mat.shader = _ShaderRes
		mat.set_shader_parameter("color_shallow", profile.water_color_shallow)
		mat.set_shader_parameter("color_deep", profile.water_color_lake)
		mat.set_shader_parameter("roughness", profile.water_roughness)
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
