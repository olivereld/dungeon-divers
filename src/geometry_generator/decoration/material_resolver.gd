class_name MaterialResolver
extends RefCounted

## Asignador y resolvedor desacoplado de materiales y shaders para mallas geométricas (Fase M4).
## Resuelve materiales PBR estilizados según los nombres de superficie de cada GeneratedMesh.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func resolve_materials_for_mesh(
	g_mesh: GeneratedMesh,
	material_preset: int = 0,
	custom_materials: Dictionary = {}
) -> void:
	if g_mesh == null or g_mesh.mesh == null:
		return

	var preset_enum: _WallMaterialFactoryScript.MaterialPreset = material_preset as _WallMaterialFactoryScript.MaterialPreset

	var trim_mat := _WallMaterialFactoryScript.create_trim_material(preset_enum)
	var panel_mat := _WallMaterialFactoryScript.create_panel_material(preset_enum)
	var brick_mat := _WallMaterialFactoryScript.create_brick_material(preset_enum)
	var wood_mat := _WallMaterialFactoryScript.create_wood_material(preset_enum)
	var iron_mat := _WallMaterialFactoryScript.create_iron_material(preset_enum)

	var mesh: ArrayMesh = g_mesh.mesh
	for s in range(mesh.get_surface_count()):
		var s_name: String = mesh.surface_get_name(s)
		var chosen_mat: Material = null

		if custom_materials.has(s_name):
			chosen_mat = custom_materials[s_name]
		elif custom_materials.has(s):
			chosen_mat = custom_materials[s]
		else:
			match s_name:
				"Trims":
					chosen_mat = trim_mat
				"WallPanel":
					chosen_mat = panel_mat
				"Bricks":
					chosen_mat = brick_mat
				"DoorWood":
					chosen_mat = wood_mat
				"DoorIron":
					chosen_mat = iron_mat
				_:
					if s == 0:
						chosen_mat = trim_mat
					elif s == 1:
						chosen_mat = panel_mat
					elif s == 2:
						chosen_mat = brick_mat

		if chosen_mat != null:
			mesh.surface_set_material(s, chosen_mat)
			g_mesh.material_slots[s] = chosen_mat
