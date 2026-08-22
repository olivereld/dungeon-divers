class_name PropSpawner
extends RefCounted

## Materializador de Room Props a partir de PropDirective.
## Instancia PackedScene o genera la malla procedural correspondiente,
## aplicando posición, rotación, escala y metadatos sin decidir ubicaciones.

const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _DungeonMeshGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_mesh_generator.gd")

var _mesh_facade := _DungeonMeshGeneratorScript.new()

func spawn_prop(directive: _PropDirectiveScript, parent: Node3D = null) -> Node3D:
	if directive == null or directive.style == null:
		return null

	var node: Node3D = null

	# 1. Instanciar escena personalizada si existe
	if directive.style.custom_scene != null:
		node = directive.style.custom_scene.instantiate() as Node3D
	else:
		# 2. Generar nodo procedural según generator_id
		node = _create_procedural_prop_node(directive)

	if node == null:
		node = Node3D.new()

	node.name = "Prop_%s_Room%d" % [String(directive.prop_id), directive.room_id]
	node.position = directive.world_position
	node.rotation.y = deg_to_rad(directive.rotation_degrees_y)
	node.scale = Vector3.ONE * directive.style.scale

	if parent != null:
		parent.add_child(node)

	return node

func _create_procedural_prop_node(directive: _PropDirectiveScript) -> Node3D:
	var gen_id: StringName = directive.style.generator_id
	var params: Dictionary = directive.style.generator_params

	match gen_id:
		&"sarcophagus_prop":
			var sarc_cfg = _mesh_facade._SarcophagusGeometryConfigScript.new(
				params.get("style", 0),
				params.get("is_open", false)
			)
			var asset = _mesh_facade.generate_sarcophagus_fixture(sarc_cfg)
			return asset.to_node3d("Sarcophagus") if asset != null else null

		&"bench_prop":
			var bench_cfg = _mesh_facade._BenchGeometryConfigScript.new(
				params.get("style", 0)
			)
			var asset = _mesh_facade.generate_bench_fixture(bench_cfg)
			return asset.to_node3d("Bench") if asset != null else null

		&"altar_prop":
			var altar_cfg = _mesh_facade._AltarGeometryConfigScript.new(
				params.get("style", 1)
			)
			var asset = _mesh_facade.generate_altar_fixture(altar_cfg)
			return asset.to_node3d("Altar") if asset != null else null

		&"tombstone_prop":
			var tomb_cfg = _mesh_facade._TombstoneGeometryConfigScript.new(
				params.get("style", 0)
			)
			var asset = _mesh_facade.generate_tombstone_fixture(tomb_cfg)
			return asset.to_node3d("Tombstone") if asset != null else null

		&"table_prop":
			var table_cfg = _mesh_facade._TableGeometryConfigScript.new(
				params.get("style", 0)
			)
			var asset = _mesh_facade.generate_table_fixture(table_cfg)
			return asset.to_node3d("Table") if asset != null else null

		&"chair_prop":
			var chair_cfg = _mesh_facade._ChairGeometryConfigScript.new(
				params.get("style", 0)
			)
			var asset = _mesh_facade.generate_chair_fixture(chair_cfg)
			return asset.to_node3d("Chair") if asset != null else null

		&"bookshelf_prop":
			var shelf_cfg = _mesh_facade._BookshelfGeometryConfigScript.new(
				params.get("style", 0)
			)
			var asset = _mesh_facade.generate_bookshelf_fixture(shelf_cfg)
			return asset.to_node3d("Bookshelf") if asset != null else null

		&"chest_prop":
			var chest_cfg = _mesh_facade._ChestGeometryConfigScript.new(
				params.get("is_open", false)
			)
			var asset = _mesh_facade.generate_chest_fixture(chest_cfg)
			return asset.to_node3d("Chest") if asset != null else null

		&"crate_prop":
			var crate_cfg = _mesh_facade._CrateGeometryConfigScript.new()
			var asset = _mesh_facade.generate_crate_fixture(crate_cfg)
			return asset.to_node3d("Crate") if asset != null else null

		&"barrel_prop":
			var barrel_cfg = _mesh_facade._BarrelGeometryConfigScript.new()
			var asset = _mesh_facade.generate_barrel_fixture(barrel_cfg)
			return asset.to_node3d("Barrel") if asset != null else null

		&"rubble_prop":
			var rubble_cfg = _mesh_facade._RubbleGeometryConfigScript.new()
			var asset = _mesh_facade.generate_rubble_fixture(rubble_cfg)
			return asset.to_node3d("Rubble") if asset != null else null

		&"sack_prop":
			var sack_cfg = _mesh_facade._SackGeometryConfigScript.new()
			var asset = _mesh_facade.generate_sack_fixture(sack_cfg)
			return asset.to_node3d("Sack") if asset != null else null

		_:
			return null
