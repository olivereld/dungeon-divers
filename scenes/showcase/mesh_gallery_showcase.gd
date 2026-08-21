class_name MeshGalleryShowcase
extends Node3D

## Escena de Exhibición e Inspección de Modelos y Mallas 3D Procedurales.
## Permite examinar de forma individual y aislada cada prop, muro, suelo, puerta,
## escalera y antorcha generada por los algoritmos del Dungeon Generator.

const _DungeonGeometryGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
const _DoorManifestFactoryScript = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")
const _DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const _DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")

const _WallMeshBuilderScript = preload("res://src/wall_mesh_generator/core/wall_mesh_builder.gd")
const _WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")
const _FloorSurfaceMeshBuilderScript = preload("res://src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _DungeonLightingGeneratorScript = preload("res://src/dungeon_lighting/facade/dungeon_lighting_generator.gd")
const _DungeonLightSpawnerScript = preload("res://src/dungeon_lighting/presentation/dungeon_light_spawner.gd")
const _TorchLightControllerScript = preload("res://src/dungeon_lighting/presentation/torch_light_controller.gd")
const _LightingProfileScript = preload("res://src/dungeon_lighting/config/lighting_profile.gd")
const _DungeonDoorSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_door_spawner.gd")
const _DungeonDoorManifestScript = preload("res://src/dungeon_generator/core/data/dungeon_door_manifest.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
const _DungeonStairSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_stair_spawner.gd")
const _StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

@onready var camera_rig: Node3D = $IsometricCameraRig
@onready var gallery_root: Node3D = $GalleryRoot
@onready var ui_category_list: VBoxContainer = $UI/PanelContainer/Margin/HBox/Sidebar/CategoryList
@onready var ui_item_list: VBoxContainer = $UI/PanelContainer/Margin/HBox/Sidebar/Scroll/ItemList
@onready var ui_title_label: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/TitleLabel
@onready var ui_script_label: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/ScriptLabel
@onready var ui_stats_label: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/StatsLabel
@onready var ui_desc_label: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/DescLabel
@onready var ui_rotate_check: CheckBox = $UI/PanelContainer/Margin/HBox/InfoPanel/Controls/RotateCheck
@onready var ui_seed_spin: SpinBox = $UI/PanelContainer/Margin/HBox/InfoPanel/Controls/SeedHBox/SeedSpin

var _categories: Array[Dictionary] = []
var _current_category_idx: int = 0
var _current_item_idx: int = 0
var _spawned_pedestals: Array[Node3D] = []
var _auto_rotate: bool = true
var _rotation_speed: float = 0.8
var _current_seed: int = 1337

func _ready() -> void:
	_setup_showcase_data()
	_build_category_buttons()
	_select_category(0)
	_setup_controls()

func _process(delta: float) -> void:
	if _auto_rotate and _spawned_pedestals.size() > _current_item_idx:
		var current_p = _spawned_pedestals[_current_item_idx]
		if current_p != null and current_p.has_node("PropAnchor"):
			current_p.get_node("PropAnchor").rotation.y += _rotation_speed * delta

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if camera_rig != null and camera_rig.has_method("zoom_in"):
				camera_rig.zoom_in(2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if camera_rig != null and camera_rig.has_method("zoom_out"):
				camera_rig.zoom_out(2.0)

func _setup_showcase_data() -> void:
	_categories = [
		{
			"name": "🧱 Muros Procedurales 3D",
			"items": [
				{
					"name": "Muro Continuo con Ladrillos en Relieve",
					"script": "src/geometry_generator/facade/dungeon_geometry_generator.gd",
					"desc": "Malla volumétrica continua real del dungeon con zócalo, cornisa, bisel y ladrillos decorativos en relieve.",
					"builder": _build_continuous_wall,
					"args": {"layout": "STRAIGHT", "decoration": true}
				},
				{
					"name": "Esquina Convexa Continua (90°)",
					"script": "src/geometry_generator/facade/dungeon_geometry_generator.gd",
					"desc": "Esquina exterior con inglete automático y unión volumétrica cerrada.",
					"builder": _build_continuous_wall,
					"args": {"layout": "CORNER_CONVEX", "decoration": true}
				},
				{
					"name": "Esquina Cóncava Continua (Interior)",
					"script": "src/geometry_generator/facade/dungeon_geometry_generator.gd",
					"desc": "Esquina interior continua con biselado y transición limpia de zócalo.",
					"builder": _build_continuous_wall,
					"args": {"layout": "CORNER_CONCAVE", "decoration": true}
				},
				{
					"name": "Muro con Vano de Puerta Tallado",
					"script": "src/geometry_generator/facade/dungeon_geometry_generator.gd",
					"desc": "Muro continuo con hueco perimetral exacto tallado por WallOpeningManifest.",
					"builder": _build_continuous_wall,
					"args": {"layout": "STRAIGHT", "opening": true, "decoration": true}
				},
				{
					"name": "Habitación Pequeña Integrada (Muros + Suelo)",
					"script": "src/dungeon_generator/presentation/dungeon_presentation_builder.gd",
					"desc": "Habitación 4x4 completa mostrando el ensamble continuo de paredes y baldosas de suelo.",
					"builder": _build_continuous_wall,
					"args": {"layout": "ROOM_BOX", "decoration": true}
				}
			]
		},
		{
			"name": "🔲 Suelos & Patrones Estocásticos",
			"items": [
				{
					"name": "Piedra Estilizada (STYLIZED_STONE)",
					"script": "src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
					"desc": "Losas entrelazadas estilizadas tipo Zelda / Diablo con biseles perimetrales.",
					"builder": _build_floor_piece,
					"args": {"pattern": _FloorTileConfigScript.PatternType.STYLIZED_STONE}
				},
				{
					"name": "Adoquines de Piedra (COBBLESTONE)",
					"script": "src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
					"desc": "Adoquines pequeños de piedra con micro-desplazamientos de textura.",
					"builder": _build_floor_piece,
					"args": {"pattern": _FloorTileConfigScript.PatternType.COBBLESTONE}
				},
				{
					"name": "Ladrillo de Suelo (BRICK)",
					"script": "src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
					"desc": "Disposición de ladrillos rectangulares entrelazados con separación de mortero.",
					"builder": _build_floor_piece,
					"args": {"pattern": _FloorTileConfigScript.PatternType.BRICK}
				},
				{
					"name": "Losas Suaves Amplias (SMOOTH_SLABS)",
					"script": "src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
					"desc": "4 losas grandes con biselado suave y variación tonal.",
					"builder": _build_floor_piece,
					"args": {"pattern": _FloorTileConfigScript.PatternType.SMOOTH_SLABS}
				},
				{
					"name": "Suelo en Ruinas (RUINED_TILES)",
					"script": "src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
					"desc": "Suelo de mazmorra con losas rotas, huecos y micro-desplazamientos estocásticos.",
					"builder": _build_floor_piece,
					"args": {"pattern": _FloorTileConfigScript.PatternType.RUINED_TILES}
				}
			]
		},
		{
			"name": "🚪 Puertas & Portales",
			"items": [
				{
					"name": "Arco de Piedra Procedural",
					"script": "src/wall_mesh_generator/core/wall_mesh_builder.gd",
					"desc": "Arco de mampostería con jambas biseladas y dovelas talladas.",
					"builder": _build_wall_piece,
					"args": {"piece": _WallMeshConfigScript.PieceType.ARCH}
				},
				{
					"name": "Hoja de Puerta de Madera",
					"script": "src/wall_mesh_generator/core/wall_mesh_builder.gd",
					"desc": "Hoja de madera reforzada con herrajes metálicos y aldaba.",
					"builder": _build_wall_piece,
					"args": {"piece": _WallMeshConfigScript.PieceType.DOOR}
				},
				{
					"name": "Portal Completo Ensamblado",
					"script": "src/dungeon_generator/presentation/dungeon_door_spawner.gd",
					"desc": "Conjunto de arco de piedra + hoja de puerta batiente interactiva.",
					"builder": _build_assembled_door_piece,
					"args": {"door_type": _DoorTypeScript.DoorType.CLOSED_DOOR}
				},
				{
					"name": "Puerta con Candado (LOCKED_DOOR)",
					"script": "src/dungeon_generator/presentation/dungeon_door_spawner.gd",
					"desc": "Portal cerrado con cerradura dorada que requiere llave.",
					"builder": _build_assembled_door_piece,
					"args": {"door_type": _DoorTypeScript.DoorType.LOCKED_DOOR}
				}
			]
		},
		{
			"name": "🪜 Escaleras & Niveles",
			"items": [
				{
					"name": "Escalera de Subida (STAIRS_UP)",
					"script": "src/dungeon_generator/presentation/dungeon_stair_spawner.gd",
					"desc": "Escalera de peldaños de piedra con descansillo de embarque.",
					"builder": _build_stairs_piece,
					"args": {"is_downward": false}
				},
				{
					"name": "Escalera de Bajada (STAIRS_DOWN)",
					"script": "src/dungeon_generator/presentation/dungeon_stair_spawner.gd",
					"desc": "Escalera descendente hacia el piso inferior.",
					"builder": _build_stairs_piece,
					"args": {"is_downward": true}
				}
			]
		},
		{
			"name": "🔥 Antorchas & Iluminación",
			"items": [
				{
					"name": "Antorcha de Pared con Parpadeo Activo",
					"script": "src/dungeon_lighting/presentation/dungeon_light_spawner.gd",
					"desc": "Soporte de hierro forjado, vástago, llama emisiva, luz puntual y parpadeo orgánico por ruido continuo.",
					"builder": _build_torch_piece,
					"args": {}
				}
			]
		},
		{
			"name": "🏆 Marcadores & Gameplay Props",
			"items": [
				{
					"name": "Marcador de Spawn",
					"script": "src/dungeon_generator/presentation/dungeon_entity_spawner.gd",
					"desc": "Runa / pedestal de inicio de nivel para el jugador.",
					"builder": _build_prop_marker,
					"args": {"type": "SPAWN"}
				},
				{
					"name": "Marcador de Boss / Objetivo",
					"script": "src/dungeon_generator/presentation/dungeon_entity_spawner.gd",
					"desc": "Runa de objetivo final o cámara del jefe.",
					"builder": _build_prop_marker,
					"args": {"type": "BOSS"}
				},
				{
					"name": "Llave Dorada",
					"script": "src/dungeon_generator/presentation/dungeon_entity_spawner.gd",
					"desc": "Llave metálica coleccionable para abrir puertas bloqueadas.",
					"builder": _build_prop_marker,
					"args": {"type": "KEY"}
				}
			]
		}
	]

func _build_category_buttons() -> void:
	for child in ui_category_list.get_children():
		child.queue_free()

	for i in range(_categories.size()):
		var cat = _categories[i]
		var btn := Button.new()
		btn.text = cat.name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 38)
		btn.pressed.connect(_on_category_button_pressed.bind(i))
		ui_category_list.add_child(btn)

func _on_category_button_pressed(idx: int) -> void:
	_select_category(idx)

func _select_category(idx: int) -> void:
	_current_category_idx = idx
	_build_item_buttons()
	_spawn_category_pedestals()
	_select_item(0)

func _build_item_buttons() -> void:
	for child in ui_item_list.get_children():
		child.queue_free()

	var cat = _categories[_current_category_idx]
	var items: Array = cat.items

	for i in range(items.size()):
		var item = items[i]
		var btn := Button.new()
		btn.text = "• " + item.name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_item_button_pressed.bind(i))
		ui_item_list.add_child(btn)

func _on_item_button_pressed(idx: int) -> void:
	_select_item(idx)

func _select_item(idx: int) -> void:
	_current_item_idx = idx
	var cat = _categories[_current_category_idx]
	var item = cat.items[idx]

	ui_title_label.text = item.name
	ui_script_label.text = "Script: " + item.script
	ui_desc_label.text = item.desc

	# Actualizar cámara
	if _spawned_pedestals.size() > idx:
		var target_pedestal = _spawned_pedestals[idx]
		if camera_rig != null:
			if camera_rig.has_method("set_target"):
				camera_rig.set_target(target_pedestal)
				camera_rig.teleport_to_target()
			else:
				camera_rig.global_position = target_pedestal.global_position

		# Calcular métricas del modelo actual
		_update_mesh_statistics(target_pedestal)

func _spawn_category_pedestals() -> void:
	for child in gallery_root.get_children():
		child.queue_free()
	_spawned_pedestals.clear()

	var cat = _categories[_current_category_idx]
	var items: Array = cat.items
	var spacing: float = 7.0

	for i in range(items.size()):
		var item = items[i]
		var pedestal := Node3D.new()
		pedestal.name = "Pedestal_%d" % i
		pedestal.position = Vector3(float(i) * spacing, 0.0, 0.0)

		# 1. Base / Pedestal circular de piedra estilizada clara
		var base_mesh := MeshInstance3D.new()
		base_mesh.name = "Base"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.2
		cyl.bottom_radius = 2.4
		cyl.height = 0.3
		var base_mat := StandardMaterial3D.new()
		base_mat.albedo_color = Color(0.22, 0.25, 0.32, 1.0)
		base_mat.roughness = 0.7
		base_mesh.mesh = cyl
		base_mesh.material_override = base_mat
		base_mesh.position = Vector3(0.0, -0.15, 0.0)
		pedestal.add_child(base_mesh)

		# 2. Cartel flotante 3D con nombre
		var label := Label3D.new()
		label.text = item.name
		label.font_size = 28
		label.modulate = Color(0.95, 0.98, 1.0)
		label.outline_modulate = Color(0.0, 0.0, 0.0)
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0.0, -0.6, 2.5)
		pedestal.add_child(label)

		# 3. Ancla rotatoria para el prop
		var prop_anchor := Node3D.new()
		prop_anchor.name = "PropAnchor"
		pedestal.add_child(prop_anchor)

		# 4. Construir y montar el prop real
		if item.has("builder") and item.builder.is_valid():
			var generated_node: Node3D = item.builder.call(item.args)
			if generated_node != null:
				prop_anchor.add_child(generated_node)

		gallery_root.add_child(pedestal)
		_spawned_pedestals.append(pedestal)

func _update_mesh_statistics(pedestal: Node3D) -> void:
	var total_verts: int = 0
	var total_faces: int = 0
	var mesh_count: int = 0
	var mesh_instances = pedestal.find_children("*", "MeshInstance3D", true, false)

	for mi in mesh_instances:
		if mi.name == "Base":
			continue
		if mi.mesh != null:
			mesh_count += 1
			for s in range(mi.mesh.get_surface_count()):
				var arrays = mi.mesh.surface_get_arrays(s)
				if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					total_verts += arrays[Mesh.ARRAY_VERTEX].size()
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
					total_faces += arrays[Mesh.ARRAY_INDEX].size() / 3

	ui_stats_label.text = "Geometría: %d mallas | %d vértices | %d triángulos" % [mesh_count, total_verts, total_faces]

# ==============================================================================
# BUILDERS DE MODO PROCEDURAL REAL
# ==============================================================================

func _build_continuous_wall(args: Dictionary) -> Node3D:
	var layout: String = args.get("layout", "STRAIGHT")
	var dec_enabled: bool = args.get("decoration", true)
	var has_opening: bool = args.get("opening", false)

	var geom_gen := _DungeonGeometryGeneratorScript.new()
	var wall_cfg := _WallGeometryConfigScript.new()
	wall_cfg.cube_size = 2.0
	wall_cfg.cubes_high = 2
	wall_cfg.seed = _current_seed

	var col_cfg := _CollisionConfigScript.new()
	col_cfg.mode = _CollisionConfigScript.CollisionMode.COMPOUND_BOX

	var dec_cfg := _DecorationConfigScript.new()
	dec_cfg.enabled = dec_enabled
	dec_cfg.seed = _current_seed

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

	var opening_manifest = null
	if has_opening:
		opening_manifest = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd").new()
		opening_manifest.add_opening(Vector2i(1, 0), _RoomEntranceScript.SOUTH, "showcase_door")

	var geom_res = geom_gen.generate_wall_clusters(grid, opening_manifest, wall_cfg, col_cfg, dec_cfg, 0)

	var container := Node3D.new()
	if not geom_res.generated_meshes.is_empty():
		var wall_inst := MeshInstance3D.new()
		wall_inst.name = "ContinuousWalls"
		wall_inst.mesh = geom_res.get_unified_mesh()
		wall_inst.position = Vector3(-float(grid_w) * 1.0, 0.0, -float(grid_h) * 1.0)
		container.add_child(wall_inst)

	# Si es habitación, añadir también suelo para ver la unión
	if layout == "ROOM_BOX":
		var floor_gen = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd").new()
		var floor_cfg := _FloorTileConfigScript.new()
		floor_cfg.tile_size = 2.0
		floor_cfg.seed = _current_seed
		var floor_res = floor_gen.generate_floor_surface(grid, floor_cfg, _current_seed)
		var floor_builder := _FloorSurfaceMeshBuilderScript.new()
		var floor_mesh = floor_builder.build_floor_mesh(floor_res, floor_cfg, null)
		var floor_inst := MeshInstance3D.new()
		floor_inst.mesh = floor_mesh
		floor_inst.position = Vector3(-float(grid_w) * 1.0, 0.0, -float(grid_h) * 1.0)
		container.add_child(floor_inst)

	return container

func _build_wall_piece(args: Dictionary) -> Node3D:
	var builder := _WallMeshBuilderScript.new()
	var cfg := _WallMeshConfigScript.new()
	cfg.piece_type = args.get("piece", _WallMeshConfigScript.PieceType.WALL)
	cfg.cube_size = 2.0
	cfg.cubes_high = 2
	cfg.seed = _current_seed
	cfg.centered_origin = true

	var mesh: ArrayMesh = builder.build_wall_mesh(cfg)
	var mi := MeshInstance3D.new()
	mi.name = "WallPieceMesh"
	mi.mesh = mesh
	return mi

func _build_floor_piece(args: Dictionary) -> Node3D:
	var builder := _FloorSurfaceMeshBuilderScript.new()
	var cfg := _FloorTileConfigScript.new()
	cfg.pattern = args.get("pattern", _FloorTileConfigScript.PatternType.STYLIZED_STONE)
	cfg.tile_size = 2.0
	cfg.margin = 0.04
	cfg.use_noise_modulation = true
	cfg.seed = _current_seed

	var container := Node3D.new()
	var grid := _CellGridScript.new(3, 3)
	for x in range(3):
		for y in range(3):
			grid.set_cell(Vector2i(x, y), _CellGridScript.CellType.FLOOR)

	var floor_gen = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd").new()
	var floor_res = floor_gen.generate_floor_surface(grid, cfg, _current_seed)
	var mesh = builder.build_floor_mesh(floor_res, cfg, null)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(-3.0, 0.0, -3.0)
	container.add_child(mi)
	return container

func _build_assembled_door_piece(args: Dictionary) -> Node3D:
	var container := Node3D.new()
	var door_type: int = args.get("door_type", _DoorTypeScript.DoorType.CLOSED_DOOR)

	# 1. Arco
	var arch_node = _build_wall_piece({"piece": _WallMeshConfigScript.PieceType.ARCH})
	container.add_child(arch_node)

	# 2. Hoja
	if door_type != _DoorTypeScript.DoorType.OPEN_PASSAGE:
		var leaf_node = _build_wall_piece({"piece": _WallMeshConfigScript.PieceType.DOOR})
		if door_type == _DoorTypeScript.DoorType.LOCKED_DOOR:
			# Candado dorado
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

func _build_stairs_piece(args: Dictionary) -> Node3D:
	var container := Node3D.new()
	var is_downward: bool = args.get("is_downward", false)

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

		# Huella horizontal
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

func _build_torch_piece(_args: Dictionary) -> Node3D:
	var container := Node3D.new()

	# 1. Segmento de pared de respaldo para anclar la antorcha
	var wall_backing = _build_continuous_wall({"layout": "STRAIGHT", "decoration": false})
	wall_backing.position = Vector3(0.0, 0.0, -1.0)
	container.add_child(wall_backing)

	# 2. Antorcha con soporte, llama y luz con flicker activo
	var torch_root := Node3D.new()
	torch_root.name = "ShowcaseTorch"

	var bracket := MeshInstance3D.new()
	bracket.name = "TorchBracket"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.02
	cyl.height = 0.35
	bracket.mesh = cyl
	bracket.rotation.x = -PI * 0.14
	bracket.position = Vector3(0.0, 0.0, -0.04)
	var bracket_mat := StandardMaterial3D.new()
	bracket_mat.albedo_color = Color(0.25, 0.18, 0.12)
	bracket_mat.roughness = 0.8
	bracket.material_override = bracket_mat
	torch_root.add_child(bracket)

	var flame := MeshInstance3D.new()
	flame.name = "TorchFlame"
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.045
	flame_mesh.height = 0.11
	flame.mesh = flame_mesh
	flame.position = Vector3(0.0, 0.16, 0.06)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.55, 0.1)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.5, 0.05)
	flame_mat.emission_energy_multiplier = 4.0
	flame.material_override = flame_mat
	torch_root.add_child(flame)

	var light := OmniLight3D.new()
	light.name = "OmniLight"
	light.light_color = Color(1.0, 0.65, 0.28)
	light.light_energy = 1.6
	light.omni_range = 8.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = true
	light.position = Vector3(0.0, 0.22, 0.12)
	torch_root.add_child(light)

	var ctrl := _TorchLightControllerScript.new()
	ctrl.name = "TorchController"
	ctrl.base_energy = 1.6
	ctrl.flicker_amplitude = 0.35
	ctrl.flicker_speed = 6.0
	torch_root.add_child(ctrl)

	torch_root.position = Vector3(0.0, 1.2, 0.0)
	container.add_child(torch_root)
	return container

func _build_prop_marker(args: Dictionary) -> Node3D:
	var container := Node3D.new()
	var type: String = args.get("type", "SPAWN")

	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()

	match type:
		"SPAWN":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.7
			cyl.bottom_radius = 0.8
			cyl.height = 0.2
			mat.albedo_color = Color(0.2, 0.7, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.7, 1.0)
			mat.emission_energy_multiplier = 1.5
			mi.mesh = cyl
		"BOSS":
			var prism := PrismMesh.new()
			prism.size = Vector3(1.2, 1.2, 1.2)
			mat.albedo_color = Color(1.0, 0.2, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.2, 0.2)
			mat.emission_energy_multiplier = 2.0
			mi.mesh = prism
			mi.position = Vector3(0.0, 1.0, 0.0)
		"KEY":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.2
			torus.outer_radius = 0.4
			mat.albedo_color = Color(1.0, 0.85, 0.1)
			mat.metallic = 0.95
			mat.roughness = 0.15
			mi.mesh = torus
			mi.position = Vector3(0.0, 1.0, 0.0)

	mi.material_override = mat
	container.add_child(mi)
	return container

# ==============================================================================
# CONTROLES Y UI
# ==============================================================================

func _setup_controls() -> void:
	if ui_rotate_check != null:
		ui_rotate_check.toggled.connect(func(val: bool): _auto_rotate = val)
	if ui_seed_spin != null:
		ui_seed_spin.value = _current_seed
		ui_seed_spin.value_changed.connect(func(val: float):
			_current_seed = int(val)
			_spawn_category_pedestals()
			_select_item(_current_item_idx)
		)
