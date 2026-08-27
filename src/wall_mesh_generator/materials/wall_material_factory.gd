class_name WallMaterialFactory
extends RefCounted

## Fábrica de materiales PBR (StandardMaterial3D) para paredes y suelos estilizados.
## Desactiva el culling (CULL_DISABLED) para garantizar visibilidad 100% sólida desde cualquier ángulo y cámara.

enum MaterialPreset {
	STYLIZED_SLATE,      ## El estilo exacto de la referencia (molduras carbón, pared pizarra y ladrillos claros)
	DUNGEON_WARM_STONE,  ## Tono piedra de mazmorra cálida
	DARK_CRYPT,          ## Tono cripta oscura / obsidiana
	SANDSTONE_RUINS      ## Tono ruinas de arenisca
}

static func create_trim_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.58
	mat.metallic = 0.05
	mat.metallic_specular = 0.35
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
	mat.roughness = 0.62
	mat.metallic = 0.0
	mat.metallic_specular = 0.35
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
	mat.roughness = 0.48 # Acabado semi-liso para que los biseles pillowed resalten con la luz cálida
	mat.metallic = 0.0
	mat.metallic_specular = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match preset:
		MaterialPreset.STYLIZED_SLATE:
			mat.albedo_color = Color(0.56, 0.59, 0.64) # Ladrillos en relieve tono pizarra claro
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

static func create_urn_body_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE, style_idx: int = 0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.48 # Cerámica estilizada semi-lisa para reflejos cálidos
	mat.metallic = 0.04
	mat.metallic_specular = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match style_idx:
		1: # SKULL_RELIC_URN: Ocre arcilloso sepulcral / Cerámica de Cripta
			mat.albedo_color = Color(0.76, 0.58, 0.40)
		2: # CEREMONIAL_PEDESTAL: Terracota ceremonial fina
			mat.albedo_color = Color(0.82, 0.54, 0.32)
		3: # CANOPIC_JAR: Cerámica vidriada ámbar
			mat.albedo_color = Color(0.85, 0.60, 0.34)
		_: # BANDED_STONE_URN / Default: Terracota clásica cálida y vibrante (Ánfora)
			mat.albedo_color = Color(0.80, 0.46, 0.26)

	match preset:
		MaterialPreset.DUNGEON_WARM_STONE:
			mat.albedo_color = mat.albedo_color.lightened(0.06)
		MaterialPreset.SANDSTONE_RUINS:
			mat.albedo_color = Color(0.86, 0.64, 0.38)
		MaterialPreset.DARK_CRYPT:
			# Resaltar vivamente incluso en criptas oscuras
			mat.albedo_color = mat.albedo_color.lerp(Color(0.84, 0.50, 0.28), 0.5)

	return mat

static func create_urn_trim_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE, style_idx: int = 0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.32 # Acabado pulido para latón / oro antiguo
	mat.metallic = 0.82
	mat.metallic_specular = 0.68
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Bandas horizontales y brocales en bronce / oro antiguo brillante que contrastan fuertemente
	mat.albedo_color = Color(0.92, 0.74, 0.36)

	return mat

static func create_floor_slab_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.65
	mat.metallic = 0.02
	mat.metallic_specular = 0.30
	mat.vertex_color_use_as_albedo = true # Habilita las variaciones de tono por losa
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match preset:
		MaterialPreset.STYLIZED_SLATE:
			mat.albedo_color = Color(0.92, 0.94, 0.96) # Modula el vertex color con base pizarra
		MaterialPreset.DUNGEON_WARM_STONE:
			mat.albedo_color = Color(1.05, 0.98, 0.90) # Modula hacia tono cálido
		MaterialPreset.DARK_CRYPT:
			mat.albedo_color = Color(0.60, 0.62, 0.66) # Modula hacia tono oscuro
		MaterialPreset.SANDSTONE_RUINS:
			mat.albedo_color = Color(1.10, 1.00, 0.82) # Modula hacia arenisca

	return mat

static func create_floor_mortar_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.metallic_specular = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match preset:
		MaterialPreset.STYLIZED_SLATE:
			mat.albedo_color = Color(0.16, 0.16, 0.18) # Mortero oscuro entre losas
		MaterialPreset.DUNGEON_WARM_STONE:
			mat.albedo_color = Color(0.22, 0.19, 0.16)
		MaterialPreset.DARK_CRYPT:
			mat.albedo_color = Color(0.09, 0.10, 0.11)
		MaterialPreset.SANDSTONE_RUINS:
			mat.albedo_color = Color(0.28, 0.24, 0.18)

	return mat

static func create_floor_dirt_material(preset: MaterialPreset = MaterialPreset.STYLIZED_SLATE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.98
	mat.metallic = 0.0
	mat.metallic_specular = 0.02
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match preset:
		MaterialPreset.STYLIZED_SLATE:
			mat.albedo_color = Color(0.30, 0.24, 0.20) # Tierra sepulcral neutra
		MaterialPreset.DUNGEON_WARM_STONE:
			mat.albedo_color = Color(0.42, 0.30, 0.22) # Tierra marrón cálida / arcillosa
		MaterialPreset.DARK_CRYPT:
			mat.albedo_color = Color(0.20, 0.16, 0.14) # Tierra de cripta muy oscura y húmeda
		MaterialPreset.SANDSTONE_RUINS:
			mat.albedo_color = Color(0.50, 0.40, 0.28) # Suelo terroso de ruinas áridas

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
	var floor_slab_mat := create_floor_slab_material(preset)
	var floor_mortar_mat := create_floor_mortar_material(preset)
	var floor_dirt_mat := create_floor_dirt_material(preset)

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
			"FloorSlabs":
				mesh_instance.set_surface_override_material(s, floor_slab_mat)
			"FloorMortar":
				mesh_instance.set_surface_override_material(s, floor_mortar_mat)
			"FloorDirt":
				mesh_instance.set_surface_override_material(s, floor_dirt_mat)
			_:
				if s == 0:
					mesh_instance.set_surface_override_material(0, trim_mat)
				elif s == 1:
					mesh_instance.set_surface_override_material(1, panel_mat)
				elif s == 2:
					mesh_instance.set_surface_override_material(2, brick_mat)
