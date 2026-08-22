class_name MeshGalleryRenderer
extends RefCounted

## Renderizador y adaptador de generación para el Mesh Generation Lab.
## Invoca las APIs de los generadores reales del proyecto sin duplicar lógica algorítmica interna.

const _EntryScript = preload("res://src/presentation/showcase/mesh_gallery_entry.gd")

# Fachada Unificada de Geometría
const _DungeonMeshGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_mesh_generator.gd")

# Generadores de Muros Reales
const _DungeonGeometryGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
const _DoorManifestFactoryScript = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")
const _DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const _DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
const _WallOpeningManifestScript = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

# Generadores de Piezas Modulares y Suelos
const _WallMeshBuilderScript = preload("res://src/wall_mesh_generator/core/wall_mesh_builder.gd")
const _WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _DungeonFloorGeneratorScript = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const _ArchGeometryConfigScript = preload("res://src/geometry_generator/config/arch_geometry_config.gd")
const _DoorGeometryConfigScript = preload("res://src/geometry_generator/config/door_geometry_config.gd")
const _StairGeometryConfigScript = preload("res://src/geometry_generator/config/stair_geometry_config.gd")
const _BrazierGeometryConfigScript = preload("res://src/geometry_generator/config/brazier_geometry_config.gd")
const _LanternGeometryConfigScript = preload("res://src/geometry_generator/config/lantern_geometry_config.gd")
const _CandleHolderGeometryConfigScript = preload("res://src/geometry_generator/config/candle_holder_geometry_config.gd")
const _CandleClusterGeometryConfigScript = preload("res://src/geometry_generator/config/candle_cluster_geometry_config.gd")
const _CrateGeometryConfigScript = preload("res://src/geometry_generator/config/crate_geometry_config.gd")
const _BarrelGeometryConfigScript = preload("res://src/geometry_generator/config/barrel_geometry_config.gd")
const _ChestGeometryConfigScript = preload("res://src/geometry_generator/config/chest_geometry_config.gd")
const _SackGeometryConfigScript = preload("res://src/geometry_generator/config/sack_geometry_config.gd")
const _RubbleGeometryConfigScript = preload("res://src/geometry_generator/config/rubble_geometry_config.gd")
const _AltarGeometryConfigScript = preload("res://src/geometry_generator/config/altar_geometry_config.gd")
const _TombstoneGeometryConfigScript = preload("res://src/geometry_generator/config/tombstone_geometry_config.gd")
const _TableGeometryConfigScript = preload("res://src/geometry_generator/config/table_geometry_config.gd")
const _ChairGeometryConfigScript = preload("res://src/geometry_generator/config/chair_geometry_config.gd")
const _BookshelfGeometryConfigScript = preload("res://src/geometry_generator/config/bookshelf_geometry_config.gd")
const _WallShowcaseGeometryConfigScript = preload("res://src/geometry_generator/config/wall_showcase_geometry_config.gd")
const _SarcophagusGeometryConfigScript = preload("res://src/geometry_generator/config/sarcophagus_geometry_config.gd")
const _BenchGeometryConfigScript = preload("res://src/geometry_generator/config/bench_geometry_config.gd")

# Puertas, Escaleras e Iluminación
const _DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
const _DungeonDoorSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_door_spawner.gd")
const _DungeonDoorManifestScript = preload("res://src/dungeon_generator/core/data/dungeon_door_manifest.gd")
const _DungeonStairSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_stair_spawner.gd")
const _DungeonLightSpawnerScript = preload("res://src/dungeon_lighting/presentation/dungeon_light_spawner.gd")
const _LightingResultScript = preload("res://src/dungeon_lighting/data/lighting_result.gd")
const _LightPlacementScript = preload("res://src/dungeon_lighting/data/light_placement.gd")
const _TorchLightControllerScript = preload("res://src/dungeon_lighting/presentation/torch_light_controller.gd")
const _LightingProfileScript = preload("res://src/dungeon_lighting/config/lighting_profile.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

var _mesh_facade = _DungeonMeshGeneratorScript.new()

## Genera el nodo 3D completo a partir de una entrada del catálogo y una semilla.
func render_entry(entry: MeshGalleryEntry, seed: int, param_overrides: Dictionary = {}) -> Node3D:
	if entry == null or not entry.is_valid():
		return null

	var params: Dictionary = entry.default_params.duplicate()
	for k in param_overrides:
		params[k] = param_overrides[k]

	match entry.generator_id:
		&"wall_continuous":
			return _render_continuous_wall(params, seed)
		&"wall_modular":
			return _render_modular_wall(params, seed)
		&"wall_showcase_prop":
			return _render_wall_showcase(params, seed)
		&"floor_surface":
			return _render_floor_surface(params, seed)
		&"door_portal":
			return _render_door_portal(params, seed)
		&"stairs":
			return _render_stairs(params, seed)
		&"torch_light":
			return _render_torch(params, seed)
		&"brazier_light":
			return _render_brazier(params, seed)
		&"lantern_light":
			return _render_lantern(params, seed)
		&"candle_holder_light":
			return _render_candle_holder(params, seed)
		&"candle_cluster_light":
			return _render_candle_cluster(params, seed)
		&"crate_prop":
			return _render_crate(params, seed)
		&"barrel_prop":
			return _render_barrel(params, seed)
		&"chest_prop":
			return _render_chest(params, seed)
		&"sack_prop":
			return _render_sack(params, seed)
		&"rubble_prop":
			return _render_rubble(params, seed)
		&"altar_prop":
			return _render_altar(params, seed)
		&"tombstone_prop":
			return _render_tombstone(params, seed)
		&"table_prop":
			return _render_table(params, seed)
		&"chair_prop":
			return _render_chair(params, seed)
		&"bookshelf_prop":
			return _render_bookshelf(params, seed)
		&"sarcophagus_prop":
			return _render_sarcophagus(params, seed)
		&"bench_prop":
			return _render_bench(params, seed)
		_:
			push_warning("[MeshGalleryRenderer] Generador desconocido: %s" % str(entry.generator_id))
			return null

# ==============================================================================
# DISPATCHERS DE GENERACIÓN REAL
# ==============================================================================

func _render_continuous_wall(params: Dictionary, seed: int) -> Node3D:
	var layout: String = params.get("layout", "STRAIGHT")
	var dec_enabled: bool = params.get("decoration", true)
	var has_opening: bool = params.get("opening", false)

	var geom_gen := _DungeonGeometryGeneratorScript.new()
	var wall_cfg := _WallGeometryConfigScript.new()
	wall_cfg.cube_size = 2.0
	wall_cfg.cubes_high = 2
	wall_cfg.seed = seed

	var col_cfg := _CollisionConfigScript.new()
	col_cfg.mode = _CollisionConfigScript.CollisionMode.COMPOUND_BOX

	var dec_cfg := _DecorationConfigScript.new()
	dec_cfg.enabled = dec_enabled
	dec_cfg.seed = seed

	var grid_w := 3
	var grid_h := 3
	if layout == "ROOM_BOX":
		grid_w = 4
		grid_h = 4

	var grid := _CellGridScript.new(grid_w, grid_h, _CellGridScript.CellType.FLOOR)

	match layout:
		"STRAIGHT":
			for x in range(3):
				grid.set_cell(Vector2i(x, 0), _CellGridScript.CellType.WALL)
		"CORNER_CONVEX":
			for x in range(3):
				grid.set_cell(Vector2i(x, 0), _CellGridScript.CellType.WALL)
			for y in range(3):
				grid.set_cell(Vector2i(0, y), _CellGridScript.CellType.WALL)
		"CORNER_CONCAVE":
			grid.set_cell(Vector2i(0, 0), _CellGridScript.CellType.WALL)
		"ROOM_BOX":
			for x in range(4):
				grid.set_cell(Vector2i(x, 0), _CellGridScript.CellType.WALL)
				grid.set_cell(Vector2i(x, 3), _CellGridScript.CellType.WALL)
			for y in range(4):
				grid.set_cell(Vector2i(0, y), _CellGridScript.CellType.WALL)
				grid.set_cell(Vector2i(3, y), _CellGridScript.CellType.WALL)

	var opening_manifest: WallOpeningManifest = null
	if has_opening:
		opening_manifest = _WallOpeningManifestScript.new()
		opening_manifest.add_opening(Vector2i(1, 0), _RoomEntranceScript.SOUTH, "showcase_door")

	var geom_res = geom_gen.generate_wall_clusters(grid, opening_manifest, wall_cfg, col_cfg, dec_cfg, 0)

	var container := Node3D.new()
	container.name = "ContinuousWallGroup"

	# Desglosar por cada GeneratedMesh (Clusters individuales) para inspección precisa
	var clusters_container := Node3D.new()
	clusters_container.name = "Clusters"
	container.add_child(clusters_container)

	var collision_container := Node3D.new()
	collision_container.name = "Collision"
	container.add_child(collision_container)

	for i in range(geom_res.generated_meshes.size()):
		var g_mesh = geom_res.generated_meshes[i]
		if g_mesh.mesh != null:
			var mi := MeshInstance3D.new()
			mi.name = "Cluster_%02d" % i
			mi.mesh = g_mesh.mesh
			mi.position = Vector3(-float(grid_w) * 1.0, 0.0, -float(grid_h) * 1.0)
			clusters_container.add_child(mi)

		if not g_mesh.collision_shapes.is_empty():
			var body: StaticBody3D = g_mesh.create_collision_body()
			body.name = "Body_Cluster_%02d" % i
			body.position = Vector3(-float(grid_w) * 1.0, 0.0, -float(grid_h) * 1.0)
			collision_container.add_child(body)

	# Si es habitación, añadir también suelo para ver la unión continua
	if layout == "ROOM_BOX":
		var floor_gen := _DungeonFloorGeneratorScript.new()
		var floor_cfg := _FloorTileConfigScript.new()
		floor_cfg.tile_size = 2.0
		floor_cfg.seed = seed
		var floor_res = floor_gen.generate_floor_surface(grid, floor_cfg, seed)

		var floor_container := Node3D.new()
		floor_container.name = "Floor"
		container.add_child(floor_container)

		var floor_clusters := Node3D.new()
		floor_clusters.name = "FloorClusters"
		floor_container.add_child(floor_clusters)

		for i in range(floor_res.clusters.size()):
			var cluster = floor_res.clusters[i]
			if cluster.mesh != null:
				var floor_inst := MeshInstance3D.new()
				floor_inst.name = "FloorCluster_%02d" % i
				floor_inst.mesh = cluster.mesh
				floor_inst.position = Vector3(-float(grid_w) * 1.0, 0.0, -float(grid_h) * 1.0)
				floor_clusters.add_child(floor_inst)

	return container

func _render_modular_wall(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "ModularWallGroup"

	var piece = params.get("piece", _WallMeshConfigScript.PieceType.WALL)

	if piece == _WallMeshConfigScript.PieceType.ARCH:
		var arch_cfg := _ArchGeometryConfigScript.new()
		arch_cfg.seed = seed
		arch_cfg.centered_origin = true
		var gm = _mesh_facade.generate_arch(arch_cfg)
		if gm != null:
			var mi: MeshInstance3D = gm.to_mesh_instance("ArchPiece")
			container.add_child(mi)
		return container

	if piece == _WallMeshConfigScript.PieceType.DOOR:
		var door_cfg := _DoorGeometryConfigScript.new()
		door_cfg.seed = seed
		door_cfg.centered_origin = true
		var gm = _mesh_facade.generate_door_leaf(door_cfg)
		if gm != null:
			var mi: MeshInstance3D = gm.to_mesh_instance("DoorLeafPiece")
			container.add_child(mi)
		return container

	var builder := _WallMeshBuilderScript.new()
	var cfg := _WallMeshConfigScript.new()
	cfg.piece_type = piece
	cfg.cube_size = 2.0
	cfg.cubes_high = 2
	cfg.seed = seed
	cfg.centered_origin = true

	var mesh: ArrayMesh = builder.build_wall_mesh(cfg)
	var mi := MeshInstance3D.new()
	mi.name = "ModularPieceMesh"
	mi.mesh = mesh
	_WallMaterialFactoryScript.apply_materials_to_mesh_instance(mi)
	container.add_child(mi)
	return container

func _render_floor_surface(params: Dictionary, seed: int) -> Node3D:
	var cfg := _FloorTileConfigScript.new()
	cfg.pattern = params.get("pattern", _FloorTileConfigScript.PatternType.STYLIZED_STONE)
	cfg.tile_size = 2.0
	cfg.margin = 0.04
	cfg.use_noise_modulation = true
	cfg.seed = seed

	var container := Node3D.new()
	container.name = "FloorGroup"

	var grid := _CellGridScript.new(3, 3)
	for x in range(3):
		for y in range(3):
			grid.set_cell(Vector2i(x, y), _CellGridScript.CellType.FLOOR)

	var floor_res = _mesh_facade.generate_floors(grid, cfg, seed)

	var clusters_container := Node3D.new()
	clusters_container.name = "Clusters"
	container.add_child(clusters_container)

	for i in range(floor_res.clusters.size()):
		var cluster = floor_res.clusters[i]
		if cluster.mesh != null:
			var mi := MeshInstance3D.new()
			mi.name = "FloorCluster_%02d" % i
			mi.mesh = cluster.mesh
			mi.position = Vector3(-3.0, 0.0, -3.0)
			clusters_container.add_child(mi)

	return container

func _render_door_portal(params: Dictionary, seed: int) -> Node3D:
	var door_type: int = params.get("door_type", _DoorTypeScript.DoorType.CLOSED_DOOR)
	var is_open: bool = (door_type == _DoorTypeScript.DoorType.OPEN_PASSAGE)
	var is_locked: bool = (door_type == _DoorTypeScript.DoorType.LOCKED_DOOR)

	var arch_cfg := _ArchGeometryConfigScript.new()
	arch_cfg.seed = seed
	arch_cfg.centered_origin = true

	var door_cfg := _DoorGeometryConfigScript.new()
	door_cfg.seed = seed
	door_cfg.centered_origin = true

	var portal_asset = _mesh_facade.generate_door_portal(arch_cfg, door_cfg, is_open, is_locked)
	if portal_asset != null:
		return portal_asset.to_node3d("DoorPortal")

	return Node3D.new()

func _render_stairs(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	var is_downward: bool = params.get("is_downward", false)

	var stair_cfg := _StairGeometryConfigScript.new()
	stair_cfg.tile_size = 2.0
	stair_cfg.stair_rise = 1.8
	stair_cfg.is_downward = is_downward
	stair_cfg.seed = seed

	var gm = _mesh_facade.generate_stairs(stair_cfg)
	if gm != null:
		var mi: MeshInstance3D = gm.to_mesh_instance("Stairs")
		container.add_child(mi)

	return container

func _render_torch(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "TorchShowcaseGroup"

	var builder := _WallMeshBuilderScript.new()

	# 1. Segmento de pared recta procedural estilizada centrada en (0, 0, 0)
	var wall_cfg := _WallMeshConfigScript.new()
	wall_cfg.piece_type = _WallMeshConfigScript.PieceType.WALL
	wall_cfg.cube_size = 2.0
	wall_cfg.cubes_high = 2
	wall_cfg.seed = seed
	wall_cfg.centered_origin = true

	var wall_mesh: ArrayMesh = builder.build_wall_mesh(wall_cfg)
	var wall_inst := MeshInstance3D.new()
	wall_inst.name = "WallSegment"
	wall_inst.mesh = wall_mesh
	_WallMaterialFactoryScript.apply_materials_to_mesh_instance(wall_inst)
	wall_inst.position = Vector3.ZERO
	container.add_child(wall_inst)

	# 2. Losa de suelo estocástica real alineada exactamente frente a la pared (Z = 0.20 a 2.20)
	var floor_cfg := _FloorTileConfigScript.new()
	floor_cfg.pattern = _FloorTileConfigScript.PatternType.STYLIZED_STONE
	floor_cfg.tile_size = 2.0
	floor_cfg.margin = 0.03
	floor_cfg.seed = seed

	var grid := _CellGridScript.new(1, 1)
	grid.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)

	var floor_gen := _DungeonFloorGeneratorScript.new()
	var floor_res = floor_gen.generate_floor_surface(grid, floor_cfg, seed)

	var floor_container := Node3D.new()
	floor_container.name = "FloorBase"
	for i in range(floor_res.clusters.size()):
		var cluster = floor_res.clusters[i]
		if cluster.mesh != null:
			var mi := MeshInstance3D.new()
			mi.name = "FloorCluster_%02d" % i
			mi.mesh = cluster.mesh
			# Alinear exactamente con la cara frontal del muro Z = 0.20
			mi.position = Vector3(-1.0, 0.0, 0.20)
			floor_container.add_child(mi)
	container.add_child(floor_container)

	# 3. Antorcha procedural del DungeonLightSpawner anclada visiblemente al frente del muro (Z = 0.22)
	var spawner := _DungeonLightSpawnerScript.new()
	var prof := _LightingProfileScript.new()
	prof.energy = params.get("energy", 2.2)
	prof.flicker_enabled = params.get("flicker", true)

	var light_res := _LightingResultScript.new()
	var placement := _LightPlacementScript.new()
	placement.light_id = 0
	placement.cell = Vector2i(0, 0)
	placement.wall_side = _LightPlacementScript.WallSide.NORTH
	placement.kind = &"torch"
	light_res.placements.append(placement)

	var lighting_staging := Node3D.new()
	lighting_staging.name = "LightingStaging"
	# Anclar la antorcha para que torch_root coincida en X=0.0, Y=1.40, Z=+0.24 (sobre la cara frontal del muro)
	lighting_staging.position = Vector3(-1.0, -0.25, 0.0)
	spawner.spawn_lighting(light_res, lighting_staging, prof, 2.0)
	container.add_child(lighting_staging)

	return container

func _render_brazier(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "BrazierShowcaseGroup"

	# 1. Base de suelo de losas estocásticas 2x2 para ambientación
	var floor_cfg := _FloorTileConfigScript.new()
	floor_cfg.pattern = _FloorTileConfigScript.PatternType.STYLIZED_STONE
	floor_cfg.tile_size = 2.0
	floor_cfg.margin = 0.03
	floor_cfg.seed = seed

	var grid := _CellGridScript.new(1, 1)
	grid.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)

	var floor_gen := _DungeonFloorGeneratorScript.new()
	var floor_res = floor_gen.generate_floor_surface(grid, floor_cfg, seed)

	var floor_container := Node3D.new()
	floor_container.name = "FloorBase"
	for i in range(floor_res.clusters.size()):
		var cluster = floor_res.clusters[i]
		if cluster.mesh != null:
			var mi := MeshInstance3D.new()
			mi.name = "FloorCluster_%02d" % i
			mi.mesh = cluster.mesh
			mi.position = Vector3(-1.0, 0.0, -1.0)
			floor_container.add_child(mi)
	container.add_child(floor_container)

	# 2. Generar el Brazier procedural
	var brazier_cfg := _BrazierGeometryConfigScript.new()
	brazier_cfg.seed = seed
	var brazier_asset = _mesh_facade.generate_brazier_fixture(brazier_cfg)
	if brazier_asset != null:
		var brazier_node = brazier_asset.to_node3d("BrazierFixture")
		brazier_node.position = Vector3(0.0, 0.0, 0.0)
		container.add_child(brazier_node)

		# 3. Luz cálida y controlador de parpadeo realista (OmniLight3D)
		var omni := OmniLight3D.new()
		omni.name = "BrazierLight"
		omni.light_color = Color(1.0, 0.65, 0.25, 1.0)
		omni.light_energy = params.get("energy", 2.6)
		omni.omni_range = 8.5
		omni.omni_attenuation = 1.4
		omni.shadow_enabled = true
		omni.position = Vector3(0.0, 1.18, 0.0)
		container.add_child(omni)

		if params.get("flicker", true):
			var ctrl := _TorchLightControllerScript.new()
			ctrl.name = "BrazierFlicker"
			ctrl.base_energy = omni.light_energy
			ctrl.flicker_amplitude = 0.18
			omni.add_child(ctrl)

	return container

func _render_lantern(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "LanternShowcaseGroup"

	var is_wall_mounted: bool = params.get("is_wall_mounted", false)

	if is_wall_mounted:
		# 1. Segmento de pared procedural para montaje
		var builder := _WallMeshBuilderScript.new()
		var wall_cfg := _WallMeshConfigScript.new()
		wall_cfg.piece_type = _WallMeshConfigScript.PieceType.WALL
		wall_cfg.cube_size = 2.0
		wall_cfg.cubes_high = 2
		wall_cfg.seed = seed
		wall_cfg.centered_origin = true

		var wall_mesh: ArrayMesh = builder.build_wall_mesh(wall_cfg)
		var wall_inst := MeshInstance3D.new()
		wall_inst.name = "WallSegment"
		wall_inst.mesh = wall_mesh
		_WallMaterialFactoryScript.apply_materials_to_mesh_instance(wall_inst)
		wall_inst.position = Vector3.ZERO
		container.add_child(wall_inst)

		# 2. Suelo frontal
		var floor_cfg := _FloorTileConfigScript.new()
		floor_cfg.pattern = _FloorTileConfigScript.PatternType.STYLIZED_STONE
		floor_cfg.tile_size = 2.0
		floor_cfg.margin = 0.03
		floor_cfg.seed = seed

		var grid := _CellGridScript.new(1, 1)
		grid.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)

		var floor_gen := _DungeonFloorGeneratorScript.new()
		var floor_res = floor_gen.generate_floor_surface(grid, floor_cfg, seed)

		var floor_container := Node3D.new()
		floor_container.name = "FloorBase"
		for i in range(floor_res.clusters.size()):
			var cluster = floor_res.clusters[i]
			if cluster.mesh != null:
				var mi := MeshInstance3D.new()
				mi.name = "FloorCluster_%02d" % i
				mi.mesh = cluster.mesh
				mi.position = Vector3(-1.0, 0.0, 0.20)
				floor_container.add_child(mi)
		container.add_child(floor_container)

		# 3. Farol de pared anclado
		var lantern_cfg := _LanternGeometryConfigScript.new()
		lantern_cfg.seed = seed
		lantern_cfg.is_wall_mounted = true
		lantern_cfg.glass_color = params.get("glass_color", Color(1.0, 0.85, 0.40, 1.0))
		var lantern_asset = _mesh_facade.generate_lantern_fixture(lantern_cfg)
		if lantern_asset != null:
			var lantern_node = lantern_asset.to_node3d("WallLanternFixture")
			# Posicionar placa a Z=0.20 (cara de la pared)
			var mount_pos := Vector3(0.0, 1.45, 0.48)
			lantern_node.position = mount_pos
			container.add_child(lantern_node)

			var omni := OmniLight3D.new()
			omni.name = "LanternLight"
			omni.light_color = lantern_cfg.glass_color
			omni.light_energy = params.get("energy", 2.2)
			omni.omni_range = 8.0
			omni.omni_attenuation = 1.3
			omni.shadow_enabled = true
			omni.position = mount_pos
			container.add_child(omni)

			if params.get("flicker", true):
				var ctrl := _TorchLightControllerScript.new()
				ctrl.name = "LanternFlicker"
				ctrl.base_energy = omni.light_energy
				ctrl.flicker_amplitude = 0.15
				omni.add_child(ctrl)
	else:
		# Farol colgante exento
		var floor_cfg := _FloorTileConfigScript.new()
		floor_cfg.pattern = _FloorTileConfigScript.PatternType.STYLIZED_STONE
		floor_cfg.tile_size = 2.0
		floor_cfg.margin = 0.03
		floor_cfg.seed = seed

		var grid := _CellGridScript.new(1, 1)
		grid.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)

		var floor_gen := _DungeonFloorGeneratorScript.new()
		var floor_res = floor_gen.generate_floor_surface(grid, floor_cfg, seed)

		var floor_container := Node3D.new()
		floor_container.name = "FloorBase"
		for i in range(floor_res.clusters.size()):
			var cluster = floor_res.clusters[i]
			if cluster.mesh != null:
				var mi := MeshInstance3D.new()
				mi.name = "FloorCluster_%02d" % i
				mi.mesh = cluster.mesh
				mi.position = Vector3(-1.0, 0.0, -1.0)
				floor_container.add_child(mi)
		container.add_child(floor_container)

		var lantern_cfg := _LanternGeometryConfigScript.new()
		lantern_cfg.seed = seed
		lantern_cfg.is_wall_mounted = false
		lantern_cfg.glass_color = params.get("glass_color", Color(0.85, 0.25, 0.95, 1.0))
		var lantern_asset = _mesh_facade.generate_lantern_fixture(lantern_cfg)
		if lantern_asset != null:
			var lantern_node = lantern_asset.to_node3d("LanternFixture")
			lantern_node.position = Vector3(0.0, 0.65, 0.0)
			container.add_child(lantern_node)

			var omni := OmniLight3D.new()
			omni.name = "LanternLight"
			omni.light_color = lantern_cfg.glass_color
			omni.light_energy = params.get("energy", 2.2)
			omni.omni_range = 7.5
			omni.omni_attenuation = 1.3
			omni.shadow_enabled = true
			omni.position = Vector3(0.0, 0.65, 0.0)
			container.add_child(omni)

			if params.get("flicker", true):
				var ctrl := _TorchLightControllerScript.new()
				ctrl.name = "LanternFlicker"
				ctrl.base_energy = omni.light_energy
				ctrl.flicker_amplitude = 0.15
				omni.add_child(ctrl)

	return container

func _render_candle_holder(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "CandleHolderShowcaseGroup"

	# 1. Base de suelo de losas estocásticas 2x2 para ambientación
	var floor_cfg := _FloorTileConfigScript.new()
	floor_cfg.pattern = _FloorTileConfigScript.PatternType.STYLIZED_STONE
	floor_cfg.tile_size = 2.0
	floor_cfg.margin = 0.03
	floor_cfg.seed = seed

	var grid := _CellGridScript.new(1, 1)
	grid.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)

	var floor_gen := _DungeonFloorGeneratorScript.new()
	var floor_res = floor_gen.generate_floor_surface(grid, floor_cfg, seed)

	var floor_container := Node3D.new()
	floor_container.name = "FloorBase"
	for i in range(floor_res.clusters.size()):
		var cluster = floor_res.clusters[i]
		if cluster.mesh != null:
			var mi := MeshInstance3D.new()
			mi.name = "FloorCluster_%02d" % i
			mi.mesh = cluster.mesh
			mi.position = Vector3(-1.0, 0.0, -1.0)
			floor_container.add_child(mi)
	container.add_child(floor_container)

	# 2. Generar Candelabro Gótico procedural
	var candle_cfg := _CandleHolderGeometryConfigScript.new()
	candle_cfg.seed = seed
	var holder_asset = _mesh_facade.generate_candle_holder_fixture(candle_cfg)
	if holder_asset != null:
		var holder_node = holder_asset.to_node3d("CandleHolderFixture")
		holder_node.position = Vector3.ZERO
		container.add_child(holder_node)

		# 3. Luz cálida envolvente de velas y parpadeo realista
		var omni := OmniLight3D.new()
		omni.name = "CandleLight"
		omni.light_color = Color(1.0, 0.72, 0.35, 1.0)
		omni.light_energy = params.get("energy", 1.8)
		omni.omni_range = 6.5
		omni.omni_attenuation = 1.4
		omni.shadow_enabled = true
		omni.position = Vector3(0.0, 0.82, 0.0)
		container.add_child(omni)

		if params.get("flicker", true):
			var ctrl := _TorchLightControllerScript.new()
			ctrl.name = "CandleFlicker"
			ctrl.base_energy = omni.light_energy
			ctrl.flicker_amplitude = 0.20
			omni.add_child(ctrl)

	return container

func _render_candle_cluster(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "CandleClusterShowcaseGroup"

	# 1. Base de suelo de losas estocásticas 2x2 para ambientación
	var floor_cfg := _FloorTileConfigScript.new()
	floor_cfg.pattern = _FloorTileConfigScript.PatternType.STYLIZED_STONE
	floor_cfg.tile_size = 2.0
	floor_cfg.margin = 0.03
	floor_cfg.seed = seed

	var grid := _CellGridScript.new(1, 1)
	grid.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)

	var floor_gen := _DungeonFloorGeneratorScript.new()
	var floor_res = floor_gen.generate_floor_surface(grid, floor_cfg, seed)

	var floor_container := Node3D.new()
	floor_container.name = "FloorBase"
	for i in range(floor_res.clusters.size()):
		var cluster = floor_res.clusters[i]
		if cluster.mesh != null:
			var mi := MeshInstance3D.new()
			mi.name = "FloorCluster_%02d" % i
			mi.mesh = cluster.mesh
			mi.position = Vector3(-1.0, 0.0, -1.0)
			floor_container.add_child(mi)
	container.add_child(floor_container)

	# 2. Generar Cúmulo de Velas estocástico procedural
	var cluster_cfg := _CandleClusterGeometryConfigScript.new()
	cluster_cfg.seed = seed
	cluster_cfg.candle_count = params.get("candle_count", 12)
	cluster_cfg.density = params.get("density", _CandleClusterGeometryConfigScript.ClusterDensity.MEDIUM)

	var cluster_asset = _mesh_facade.generate_candle_cluster_fixture(cluster_cfg)
	if cluster_asset != null:
		var cluster_node = cluster_asset.to_node3d("CandleClusterFixture")
		cluster_node.position = Vector3.ZERO
		container.add_child(cluster_node)

		# 3. Luz cálida difusa de cúmulo de velas
		var omni := OmniLight3D.new()
		omni.name = "CandleClusterLight"
		omni.light_color = Color(1.0, 0.70, 0.32, 1.0)
		omni.light_energy = params.get("energy", 2.4)
		omni.omni_range = 7.5
		omni.omni_attenuation = 1.3
		omni.shadow_enabled = true
		omni.position = Vector3(0.0, 0.45, 0.0)
		container.add_child(omni)

		if params.get("flicker", true):
			var ctrl := _TorchLightControllerScript.new()
			ctrl.name = "CandleClusterFlicker"
			ctrl.base_energy = omni.light_energy
			ctrl.flicker_amplitude = 0.22
			omni.add_child(ctrl)

	return container

func _render_crate(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "CrateShowcaseGroup"

	# Configuración de Caja
	var is_stack: bool = params.get("stack", false)
	var crate_cfg := _CrateGeometryConfigScript.new()
	crate_cfg.seed = seed

	if not is_stack:
		# Caja individual en el centro
		var crate_asset = _mesh_facade.generate_crate_fixture(crate_cfg)
		if crate_asset != null:
			var crate_node = crate_asset.to_node3d("WoodenCrate")
			crate_node.position = Vector3.ZERO
			container.add_child(crate_node)
	else:
		# Apilamiento dinámico de 3 cajas
		var crate_asset1 = _mesh_facade.generate_crate_fixture(crate_cfg)
		if crate_asset1 != null:
			# Caja 1 (Base izquierda)
			var node1 = crate_asset1.to_node3d("Crate_Base_Left")
			node1.position = Vector3(-0.35, 0.0, 0.10)
			node1.rotation.y = deg_to_rad(8.0)
			container.add_child(node1)

			# Caja 2 (Base derecha)
			var node2 = crate_asset1.to_node3d("Crate_Base_Right")
			node2.position = Vector3(0.42, 0.0, -0.15)
			node2.rotation.y = deg_to_rad(-14.0)
			container.add_child(node2)

			# Caja 3 (Superior apilada y rotada)
			var node3 = crate_asset1.to_node3d("Crate_Top_Stack")
			node3.position = Vector3(-0.10, 0.85, 0.02)
			node3.rotation.y = deg_to_rad(22.0)
			node3.rotation.x = deg_to_rad(-3.0)
			container.add_child(node3)

	return container

func _render_barrel(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "BarrelShowcaseGroup"

	# Configuración de Barril
	var is_cluster: bool = params.get("cluster", false)
	var barrel_cfg := _BarrelGeometryConfigScript.new(1.0, 12, seed)

	if not is_cluster:
		# Barril individual de pie en el centro
		var barrel_asset = _mesh_facade.generate_barrel_fixture(barrel_cfg)
		if barrel_asset != null:
			var barrel_node = barrel_asset.to_node3d("WoodenBarrel")
			barrel_node.position = Vector3.ZERO
			container.add_child(barrel_node)
	else:
		# Dúo de barriles: uno erguido y otro tumbado
		var barrel_asset = _mesh_facade.generate_barrel_fixture(barrel_cfg)
		if barrel_asset != null:
			# Barril 1: De pie
			var node1 = barrel_asset.to_node3d("Barrel_Standing")
			node1.position = Vector3(-0.28, 0.0, 0.12)
			node1.rotation.y = deg_to_rad(15.0)
			container.add_child(node1)

			# Barril 2: Tumbado de lado en el suelo
			var node2 = barrel_asset.to_node3d("Barrel_Tipped")
			node2.position = Vector3(0.32, 0.36, -0.08)
			node2.rotation.z = deg_to_rad(90.0)
			node2.rotation.y = deg_to_rad(-40.0)
			container.add_child(node2)

	return container

func _render_chest(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "ChestShowcaseGroup"

	# Construcción de Cofre Articulado en 2 Partes (Cajón Base + Tapa con Bisagra)
	var chest_cfg := _ChestGeometryConfigScript.new(1.0, seed)
	var open_angle_deg: float = float(params.get("open_angle_deg", 0.0 if not params.get("open", false) else 145.0))
	var has_loot: bool = params.get("loot", false)

	var chest_root := Node3D.new()
	chest_root.name = "ArticulatedChest"
	chest_root.position = Vector3(0.0, 0.0, 0.0)

	# A. Cajón Base
	var base_asset = _mesh_facade.generate_chest_base(chest_cfg)
	if base_asset != null:
		var base_node = base_asset.to_node3d("ChestBase")
		chest_root.add_child(base_node)

	# B. Tapa Abovedada con Bisagra Trasera
	var lid_asset = _mesh_facade.generate_chest_lid(chest_cfg)
	if lid_asset != null:
		var lid_node = lid_asset.to_node3d("ChestLid")
		# Posicionar en la bisagra trasera superior
		lid_node.position = Vector3(0.0, chest_cfg.base_height, -chest_cfg.depth * 0.50)
		# Rotación sobre la bisagra hacia atrás (eje X negativo)
		lid_node.rotation.x = deg_to_rad(-open_angle_deg)
		chest_root.add_child(lid_node)

	# C. Efecto de Botín / Luz Dorada Interior si está abierto con loot
	if has_loot:
		var loot_light := OmniLight3D.new()
		loot_light.name = "LootGlow"
		loot_light.light_color = Color(1.0, 0.82, 0.25, 1.0) # Oro resplandeciente
		loot_light.light_energy = 2.4
		loot_light.omni_range = 3.5
		loot_light.omni_attenuation = 1.2
		loot_light.shadow_enabled = true
		loot_light.position = Vector3(0.0, chest_cfg.base_height * 0.70, 0.0)
		chest_root.add_child(loot_light)

		var flicker := _TorchLightControllerScript.new()
		flicker.name = "LootShimmer"
		flicker.base_energy = loot_light.light_energy
		flicker.flicker_amplitude = 0.15
		loot_light.add_child(flicker)

	container.add_child(chest_root)
	return container

func _render_sack(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "SackShowcaseGroup"

	# Configuración de Saco
	var is_cluster: bool = params.get("cluster", false)
	var sack_cfg := _SackGeometryConfigScript.new(1.0, 10, seed)

	if not is_cluster:
		# Saco individual erguido de pie en el centro
		var sack_asset = _mesh_facade.generate_sack_fixture(sack_cfg)
		if sack_asset != null:
			var sack_node = sack_asset.to_node3d("BurlapSack")
			sack_node.position = Vector3.ZERO
			container.add_child(sack_node)
	else:
		# Grupo orgánico de 3 sacos de pie con diferentes escalas y rotaciones
		var sack_asset = _mesh_facade.generate_sack_fixture(sack_cfg)
		if sack_asset != null:
			# Saco 1: Grande (Atrás izquierda)
			var node1 = sack_asset.to_node3d("Sack_Standing_Large")
			node1.position = Vector3(-0.16, 0.0, -0.08)
			node1.scale = Vector3(1.15, 1.15, 1.15)
			node1.rotation.y = deg_to_rad(12.0)
			container.add_child(node1)

			# Saco 2: Mediano (Delante derecha)
			var node2 = sack_asset.to_node3d("Sack_Standing_Medium")
			node2.position = Vector3(0.22, 0.0, 0.12)
			node2.scale = Vector3(0.95, 0.95, 0.95)
			node2.rotation.y = deg_to_rad(-38.0)
			container.add_child(node2)

			# Saco 3: Pequeño (Delante izquierda)
			var node3 = sack_asset.to_node3d("Sack_Standing_Small")
			node3.position = Vector3(-0.28, 0.0, 0.22)
			node3.scale = Vector3(0.78, 0.82, 0.78)
			node3.rotation.y = deg_to_rad(65.0)
			container.add_child(node3)

	return container

func _render_rubble(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "RubbleShowcaseGroup"

	# Configuración de Escombros y Derrumbe
	var preset_idx: int = int(params.get("preset", 1))
	var include_props: bool = bool(params.get("include_props", false))
	var rubble_cfg := _RubbleGeometryConfigScript.new(
		preset_idx as _RubbleGeometryConfigScript.RubbleSize,
		include_props,
		seed
	)

	var rubble_asset = _mesh_facade.generate_rubble_fixture(rubble_cfg)
	if rubble_asset != null:
		var rubble_node = rubble_asset.to_node3d("DungeonRubble")
		rubble_node.position = Vector3.ZERO
		container.add_child(rubble_node)

	# Props aplastados/enterrados opcionales
	if include_props:
		# Caja de madera medio enterrada e inclinada
		var crate_cfg := _CrateGeometryConfigScript.new(0.85, _CrateGeometryConfigScript.DiagonalStyle.SINGLE_Z, seed + 10)
		var crate_asset = _mesh_facade.generate_crate_fixture(crate_cfg)
		if crate_asset != null:
			var crate_node = crate_asset.to_node3d("CrushedCrate")
			crate_node.position = Vector3(-0.35, 0.05, 0.18)
			crate_node.rotation.x = deg_to_rad(18.0)
			crate_node.rotation.y = deg_to_rad(32.0)
			crate_node.rotation.z = deg_to_rad(-14.0)
			container.add_child(crate_node)

		# Barril de madera caído y aplastado
		var barrel_cfg := _BarrelGeometryConfigScript.new(0.80, 10, seed + 20)
		var barrel_asset = _mesh_facade.generate_barrel_fixture(barrel_cfg)
		if barrel_asset != null:
			var barrel_node = barrel_asset.to_node3d("CrushedBarrel")
			barrel_node.position = Vector3(0.36, 0.18, -0.15)
			barrel_node.rotation.x = deg_to_rad(78.0)
			barrel_node.rotation.y = deg_to_rad(-24.0)
			barrel_node.rotation.z = deg_to_rad(15.0)
			container.add_child(barrel_node)

	return container

func _render_altar(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "AltarShowcaseGroup"

	# Configuración de Altar de Piedra
	var preset_idx: int = int(params.get("preset", 1))
	var altar_cfg := _AltarGeometryConfigScript.new(
		preset_idx as _AltarGeometryConfigScript.AltarSize,
		1.0,
		seed
	)

	var altar_asset = _mesh_facade.generate_altar_fixture(altar_cfg)
	if altar_asset != null:
		var altar_node = altar_asset.to_node3d("StoneAltar")
		altar_node.position = Vector3.ZERO
		container.add_child(altar_node)

	# Luz cálida mística de ambientación ceremonial
	var altar_light := OmniLight3D.new()
	altar_light.name = "AltarAuraLight"
	altar_light.light_color = Color(1.0, 0.78, 0.45, 1.0)
	altar_light.light_energy = 1.4
	altar_light.omni_range = 3.0
	altar_light.omni_attenuation = 1.3
	altar_light.shadow_enabled = true
	altar_light.position = Vector3(0.0, altar_cfg.height + 0.25, 0.0)
	container.add_child(altar_light)

	var flicker := _TorchLightControllerScript.new()
	flicker.name = "AltarLightFlicker"
	flicker.base_energy = altar_light.light_energy
	flicker.flicker_amplitude = 0.12
	altar_light.add_child(flicker)

	return container

func _render_tombstone(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "TombstoneShowcaseGroup"

	# Configuración de Lápida
	var style_idx: int = int(params.get("style", 0))
	var tombstone_cfg := _TombstoneGeometryConfigScript.new(
		style_idx as _TombstoneGeometryConfigScript.TombstoneStyle,
		1.0,
		seed
	)

	var tombstone_asset = _mesh_facade.generate_tombstone_fixture(tombstone_cfg)
	if tombstone_asset != null:
		var tombstone_node = tombstone_asset.to_node3d("Tombstone")
		tombstone_node.position = Vector3.ZERO
		container.add_child(tombstone_node)

	# Luz espectral azulada/fría tenue de cementerio
	var grave_light := OmniLight3D.new()
	grave_light.name = "GraveyardAura"
	grave_light.light_color = Color(0.70, 0.85, 1.0, 1.0) # Azul gélido espectral
	grave_light.light_energy = 0.9
	grave_light.omni_range = 2.8
	grave_light.position = Vector3(0.0, tombstone_cfg.height * 0.85, 0.20)
	container.add_child(grave_light)

	return container

func _render_table(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "TableShowcaseGroup"

	# Configuración de Mesa
	var style_idx: int = int(params.get("style", 0))
	var table_cfg := _TableGeometryConfigScript.new(
		style_idx as _TableGeometryConfigScript.TableStyle,
		1.0,
		seed
	)

	var table_asset = _mesh_facade.generate_table_fixture(table_cfg)
	if table_asset != null:
		var table_node = table_asset.to_node3d("TavernTable")
		table_node.position = Vector3.ZERO
		container.add_child(table_node)

	return container

func _render_chair(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "ChairShowcaseGroup"

	# Configuración de Silla
	var style_idx: int = int(params.get("style", 0))
	var chair_cfg := _ChairGeometryConfigScript.new(
		style_idx as _ChairGeometryConfigScript.ChairStyle,
		1.0,
		seed
	)

	var chair_asset = _mesh_facade.generate_chair_fixture(chair_cfg)
	if chair_asset != null:
		var chair_node = chair_asset.to_node3d("TavernChair")
		chair_node.position = Vector3.ZERO
		container.add_child(chair_node)

	return container

func _render_bookshelf(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "BookshelfShowcaseGroup"

	# Configuración de Librería
	var style_idx: int = int(params.get("style", 1))
	var shelf_cfg := _BookshelfGeometryConfigScript.new(
		style_idx as _BookshelfGeometryConfigScript.BookshelfStyle,
		1.0,
		seed
	)

	var shelf_asset = _mesh_facade.generate_bookshelf_fixture(shelf_cfg)
	if shelf_asset != null:
		var shelf_node = shelf_asset.to_node3d("DungeonBookshelf")
		shelf_node.position = Vector3.ZERO
		container.add_child(shelf_node)

	return container

func _render_wall_showcase(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "WallShowcaseGroup"

	# Configuración de Muro Recto 3x2
	var variant_idx: int = int(params.get("variant", 0))
	var wall_cfg := _WallShowcaseGeometryConfigScript.new(
		variant_idx as _WallShowcaseGeometryConfigScript.WallVariant,
		1.0,
		seed
	)

	var wall_asset = _mesh_facade.generate_wall_showcase_fixture(wall_cfg)
	if wall_asset != null:
		var wall_node = wall_asset.to_node3d("WallShowcase3x2")
		wall_node.position = Vector3.ZERO
		container.add_child(wall_node)

	return container

func _render_sarcophagus(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "SarcophagusShowcaseGroup"

	var style_idx: int = int(params.get("style", 0))
	var is_open: bool = bool(params.get("is_open", false))
	var sarc_cfg := _SarcophagusGeometryConfigScript.new(
		style_idx as _SarcophagusGeometryConfigScript.Style,
		is_open,
		1.0,
		seed
	)

	var sarc_asset = _mesh_facade.generate_sarcophagus_fixture(sarc_cfg)
	if sarc_asset != null:
		var sarc_node = sarc_asset.to_node3d("Sarcophagus")
		sarc_node.position = Vector3.ZERO
		container.add_child(sarc_node)

	return container

func _render_bench(params: Dictionary, seed: int) -> Node3D:
	var container := Node3D.new()
	container.name = "BenchShowcaseGroup"

	var style_idx: int = int(params.get("style", 0))
	var bench_cfg := _BenchGeometryConfigScript.new(
		style_idx as _BenchGeometryConfigScript.BenchStyle,
		1.0,
		seed
	)

	var bench_asset = _mesh_facade.generate_bench_fixture(bench_cfg)
	if bench_asset != null:
		var bench_node = bench_asset.to_node3d("Bench")
		bench_node.position = Vector3.ZERO
		container.add_child(bench_node)

	return container
