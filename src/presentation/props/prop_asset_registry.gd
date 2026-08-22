class_name PropAssetRegistry
extends RefCounted

## Registro modular y desacoplado de fábricas de assets y mallas para Room Props.
## Elimina bloques match gigantescos y permite extender la colección de props
## sin modificar PropSpawner ni el pipeline central.

const _DungeonMeshGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_mesh_generator.gd")

var _factories: Dictionary = {} # StringName -> Callable (params: Dictionary) -> Node3D
var _mesh_facade: RefCounted = null

func _init() -> void:
	_mesh_facade = _DungeonMeshGeneratorScript.new()
	_register_default_factories()

func register_factory(generator_id: StringName, factory: Callable) -> void:
	_factories[generator_id] = factory

func has_factory(generator_id: StringName) -> bool:
	return _factories.has(generator_id)

func create_node(generator_id: StringName, params: Dictionary) -> Node3D:
	if not _factories.has(generator_id):
		push_warning("[PropAssetRegistry] No existe fábrica registrada para: %s" % str(generator_id))
		return null
	var factory: Callable = _factories[generator_id]
	return factory.call(params) as Node3D

func _register_default_factories() -> void:
	# 1. Sarcófago (Sarcophagus)
	register_factory(&"sarcophagus_prop", func(params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._SarcophagusGeometryConfigScript.new(
			params.get("style", 0),
			params.get("is_open", false)
		)
		var asset = _mesh_facade.generate_sarcophagus_fixture(cfg)
		return asset.to_node3d("Sarcophagus") if asset != null else null
	)

	# 2. Bancas y Banquetas (Bench)
	register_factory(&"bench_prop", func(params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._BenchGeometryConfigScript.new(
			params.get("style", 0)
		)
		var asset = _mesh_facade.generate_bench_fixture(cfg)
		return asset.to_node3d("Bench") if asset != null else null
	)

	# 3. Altares de Piedra (Altar)
	register_factory(&"altar_prop", func(params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._AltarGeometryConfigScript.new(
			params.get("style", 1)
		)
		var asset = _mesh_facade.generate_altar_fixture(cfg)
		return asset.to_node3d("Altar") if asset != null else null
	)

	# 4. Lápidas (Tombstone)
	register_factory(&"tombstone_prop", func(params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._TombstoneGeometryConfigScript.new(
			params.get("style", 0)
		)
		var asset = _mesh_facade.generate_tombstone_fixture(cfg)
		return asset.to_node3d("Tombstone") if asset != null else null
	)

	# 5. Mesas de Mazmorra (Table)
	register_factory(&"table_prop", func(params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._TableGeometryConfigScript.new(
			params.get("style", 0)
		)
		var asset = _mesh_facade.generate_table_fixture(cfg)
		return asset.to_node3d("Table") if asset != null else null
	)

	# 6. Sillas y Taburetes (Chair)
	register_factory(&"chair_prop", func(params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._ChairGeometryConfigScript.new(
			params.get("style", 0)
		)
		var asset = _mesh_facade.generate_chair_fixture(cfg)
		return asset.to_node3d("Chair") if asset != null else null
	)

	# 7. Librerías de Mazmorra (Bookshelf)
	register_factory(&"bookshelf_prop", func(params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._BookshelfGeometryConfigScript.new(
			params.get("style", 0)
		)
		var asset = _mesh_facade.generate_bookshelf_fixture(cfg)
		return asset.to_node3d("Bookshelf") if asset != null else null
	)

	# 8. Cofres de Mazmorra (Chest)
	register_factory(&"chest_prop", func(params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._ChestGeometryConfigScript.new(
			params.get("is_open", false)
		)
		var asset = _mesh_facade.generate_chest_fixture(cfg)
		return asset.to_node3d("Chest") if asset != null else null
	)

	# 9. Cajas de Madera (Crate)
	register_factory(&"crate_prop", func(_params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._CrateGeometryConfigScript.new()
		var asset = _mesh_facade.generate_crate_fixture(cfg)
		return asset.to_node3d("Crate") if asset != null else null
	)

	# 10. Barriles de Madera (Barrel)
	register_factory(&"barrel_prop", func(_params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._BarrelGeometryConfigScript.new()
		var asset = _mesh_facade.generate_barrel_fixture(cfg)
		return asset.to_node3d("Barrel") if asset != null else null
	)

	# 11. Montones de Escombros (Rubble)
	register_factory(&"rubble_prop", func(_params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._RubbleGeometryConfigScript.new()
		var asset = _mesh_facade.generate_rubble_fixture(cfg)
		return asset.to_node3d("Rubble") if asset != null else null
	)

	# 12. Sacos de Arpillera (Sack)
	register_factory(&"sack_prop", func(_params: Dictionary) -> Node3D:
		var cfg = _mesh_facade._SackGeometryConfigScript.new()
		var asset = _mesh_facade.generate_sack_fixture(cfg)
		return asset.to_node3d("Sack") if asset != null else null
	)
