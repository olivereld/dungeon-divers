class_name WallMaterialFactory
extends RefCounted

## Fábrica de materiales PBR (StandardMaterial3D) para paredes estilizadas.
## Desactiva el culling (CULL_DISABLED) para garantizar visibilidad 100% sólida desde cualquier ángulo y cámara.

enum MaterialPreset {
	STYLIZED_SLATE,      ## El estilo exacto de la referencia (molduras carbón, pared pizarra y ladrillos claros)
	DUNGEON_WARM_STONE,  ## Tono piedra de mazmorra cálida
	DARK_CRYPT,          ## Tono cripta oscura / obsidiana
	SANDSTONE_RUINS      ## Tono ruinas de arenisca
}

static func create_trim_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.70
	mat.metallic = 0.05
	mat.metallic_specular = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match preset:
		MaterialPreset.STYLIZED_SLATE:
			mat.albedo_color = Color(0.24, 0.25, 0.27) # Carbón / pizarra oscura
		MaterialPreset.DUNGEON_WARM_STONE:
			mat.albedo_color = Color(0.32, 0.26, 0.22)
		MaterialPreset.DARK_CRYPT:
			mat.albedo_color = Color(0.14, 0.15, 0.17)
		MaterialPreset.SANDSTONE_RUINS:
			mat.albedo_color = Color(0.45, 0.38, 0.28)

	return mat

static func create_panel_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.85
	mat.metallic = 0.0
	mat.metallic_specular = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match preset:
		MaterialPreset.STYLIZED_SLATE:
			mat.albedo_color = Color(0.48, 0.51, 0.55) # Pizarra medio limpio
		MaterialPreset.DUNGEON_WARM_STONE:
			mat.albedo_color = Color(0.58, 0.52, 0.46)
		MaterialPreset.DARK_CRYPT:
			mat.albedo_color = Color(0.25, 0.27, 0.30)
		MaterialPreset.SANDSTONE_RUINS:
			mat.albedo_color = Color(0.72, 0.63, 0.48)

	return mat

static func create_brick_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.60 # Más suave para que los biseles pillowed resalten con la luz
	mat.metallic = 0.0
	mat.metallic_specular = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match preset:
		MaterialPreset.STYLIZED_SLATE:
			mat.albedo_color = Color(0.54, 0.57, 0.61) # Ladrillos en relieve tono pizarra claro
		MaterialPreset.DUNGEON_WARM_STONE:
			mat.albedo_color = Color(0.66, 0.58, 0.50)
		MaterialPreset.DARK_CRYPT:
			mat.albedo_color = Color(0.32, 0.35, 0.38)
		MaterialPreset.SANDSTONE_RUINS:
			mat.albedo_color = Color(0.80, 0.70, 0.54)

	return mat

static func create_wood_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.76
	mat.metallic = 0.0
	mat.metallic_specular = 0.18
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match preset:
		MaterialPreset.STYLIZED_SLATE:
			mat.albedo_color = Color(0.38, 0.25, 0.17) # Roble envejecido cálido estilizado
		MaterialPreset.DUNGEON_WARM_STONE:
			mat.albedo_color = Color(0.44, 0.30, 0.20)
		MaterialPreset.DARK_CRYPT:
			mat.albedo_color = Color(0.20, 0.16, 0.15) # Madera ennegrecida
		MaterialPreset.SANDSTONE_RUINS:
			mat.albedo_color = Color(0.50, 0.38, 0.26)

	return mat

static func create_iron_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.42
	mat.metallic = 0.88
	mat.metallic_specular = 0.55
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match preset:
		MaterialPreset.STYLIZED_SLATE:
			mat.albedo_color = Color(0.20, 0.21, 0.24) # Hierro forjado oscuro
		MaterialPreset.DUNGEON_WARM_STONE:
			mat.albedo_color = Color(0.25, 0.24, 0.23)
		MaterialPreset.DARK_CRYPT:
			mat.albedo_color = Color(0.12, 0.13, 0.15)
		MaterialPreset.SANDSTONE_RUINS:
			mat.albedo_color = Color(0.30, 0.27, 0.24)

	return mat

static func apply_materials_to_mesh_instance(
	mesh_instance: MeshInstance3D,
	preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE
) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return

	var trim_mat := create_trim_material(preset)
	var panel_mat := create_panel_material(preset)
	var brick_mat := create_brick_material(preset)
	var wood_mat := create_wood_material(preset)
	var iron_mat := create_iron_material(preset)

	var mesh: Mesh = mesh_instance.mesh
	for s in range(mesh.get_surface_count()):
		var s_name: String = mesh.surface_get_name(s)
		match s_name:
			"Trims":
				mesh_instance.set_surface_override_material(s, trim_mat)
			"WallPanel":
				mesh_instance.set_surface_override_material(s, panel_mat)
			"Bricks":
				mesh_instance.set_surface_override_material(s, brick_mat)
			"DoorWood":
				mesh_instance.set_surface_override_material(s, wood_mat)
			"DoorIron":
				mesh_instance.set_surface_override_material(s, iron_mat)
			_:
				if s == 0:
					mesh_instance.set_surface_override_material(0, trim_mat)
				elif s == 1:
					mesh_instance.set_surface_override_material(1, panel_mat)
				elif s == 2:
					mesh_instance.set_surface_override_material(2, brick_mat)
