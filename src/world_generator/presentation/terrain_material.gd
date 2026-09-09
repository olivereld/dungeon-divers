class_name TerrainMaterial
extends RefCounted

## Factory for procedural terrain materials leveraging vertex-color albedo.
static func create_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.90
	mat.metallic_specular = 0.05
	return mat
