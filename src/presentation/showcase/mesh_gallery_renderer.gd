class_name MeshGalleryRenderer
extends RefCounted

## Renderizador y adaptador de generación para el Mesh Generation Lab.
## Invoca las APIs de los generadores reales del proyecto sin duplicar lógica algorítmica interna.

const _EntryScript = preload("res://src/presentation/showcase/mesh_gallery_entry.gd")

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
		&"floor_surface":
			return _render_floor_surface(params, seed)
		&"door_portal":
			return _render_door_portal(params, seed)
		&"stairs":
			return _render_stairs(params, seed)
		&"torch_light":
			return _render_torch(params, seed)
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

	var builder := _WallMeshBuilderScript.new()
	var cfg := _WallMeshConfigScript.new()
	cfg.piece_type = params.get("piece", _WallMeshConfigScript.PieceType.WALL)
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

	var floor_gen := _DungeonFloorGeneratorScript.new()
	var floor_res = floor_gen.generate_floor_surface(grid, cfg, seed)

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
	var container := Node3D.new()
	var door_type: int = params.get("door_type", _DoorTypeScript.DoorType.CLOSED_DOOR)

	# 1. Arco
	var arch_node = _render_modular_wall({"piece": _WallMeshConfigScript.PieceType.ARCH}, seed)
	container.add_child(arch_node)

	# 2. Hoja
	if door_type != _DoorTypeScript.DoorType.OPEN_PASSAGE:
		var leaf_node = _render_modular_wall({"piece": _WallMeshConfigScript.PieceType.DOOR}, seed)
		if door_type == _DoorTypeScript.DoorType.LOCKED_DOOR:
			var lock_mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.2, 0.25, 0.1)
			var gold_mat := StandardMaterial3D.new()
			gold_mat.albedo_color = Color(1.0, 0.8, 0.2)
			gold_mat.metallic = 0.9
			gold_mat.roughness = 0.2
			lock_mi.mesh = box
			lock_mi.material_override = gold_mat
			lock_mi.position = Vector3(0.0, 1.2, 0.15)
			leaf_node.add_child(lock_mi)
		container.add_child(leaf_node)

	return container

func _render_stairs(params: Dictionary, _seed: int) -> Node3D:
	var container := Node3D.new()
	var is_downward: bool = params.get("is_downward", false)

	var stair_mesh := MeshInstance3D.new()
	stair_mesh.name = "Stairs"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.38, 0.42)
	mat.roughness = 0.85
	st.set_material(mat)

	var steps: int = 6
	var step_w: float = 1.8
	var step_d: float = 2.0 / float(steps)
	var step_h: float = 2.0 / float(steps)

	for i in range(steps):
		var y: float = float(steps - 1 - i) * step_h if is_downward else float(i) * step_h
		var z: float = float(i) * step_d - 1.0

		var p0 := Vector3(-step_w * 0.5, y + step_h, z)
		var p1 := Vector3(step_w * 0.5, y + step_h, z)
		var p2 := Vector3(step_w * 0.5, y + step_h, z + step_d)
		var p3 := Vector3(-step_w * 0.5, y + step_h, z + step_d)

		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)
		st.add_vertex(p0)
		st.add_vertex(p2)
		st.add_vertex(p3)

	var m := ArrayMesh.new()
	st.commit(m)
	stair_mesh.mesh = m
	container.add_child(stair_mesh)
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
	placement.wall_side = _LightPlacementScript.WallSide.SOUTH
	placement.kind = &"torch"
	light_res.placements.append(placement)

	var lighting_staging := Node3D.new()
	lighting_staging.name = "LightingStaging"
	# Anclar la antorcha para que torch_root coincida en X=0.0, Y=1.40, Z=+0.26 (sobre la cara frontal del muro)
	lighting_staging.position = Vector3(-1.0, -0.25, -1.39)
	spawner.spawn_lighting(light_res, lighting_staging, prof, 2.0)
	container.add_child(lighting_staging)

	return container
