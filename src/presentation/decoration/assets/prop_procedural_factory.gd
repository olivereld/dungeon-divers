class_name PropProceduralFactory
extends RefCounted

## Fábrica y puente desacoplado hacia la fachada de generación de geometría procedural (DungeonMeshGenerator).
## Encapsula la llamada a constructores procedurales específicos sin exponerlos al Spawner ni al Provider.

const _DungeonMeshGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_mesh_generator.gd")

var _mesh_facade: RefCounted = null

func _init() -> void:
	_mesh_facade = _DungeonMeshGeneratorScript.new()

func build_procedural_prop(builder_id: StringName, params: Dictionary) -> Node3D:
	match builder_id:
		&"sarcophagus_prop":
			var style_idx: int = params.get("style", 0)
			var is_open: bool = params.get("is_open", false)
			var cfg = _mesh_facade._SarcophagusGeometryConfigScript.new(style_idx, is_open)
			var asset = _mesh_facade.generate_sarcophagus_fixture(cfg)
			return asset.to_node3d("Sarcophagus") if asset != null else null

		&"bench_prop":
			var style_idx: int = params.get("style", 0)
			var cfg = _mesh_facade._BenchGeometryConfigScript.new(style_idx)
			var asset = _mesh_facade.generate_bench_fixture(cfg)
			return asset.to_node3d("Bench") if asset != null else null

		&"altar_prop":
			var style_idx: int = params.get("style", 1)
			var cfg = _mesh_facade._AltarGeometryConfigScript.new(style_idx)
			var asset = _mesh_facade.generate_altar_fixture(cfg)
			return asset.to_node3d("Altar") if asset != null else null

		&"tombstone_prop":
			var style_idx: int = params.get("style", 0)
			var cfg = _mesh_facade._TombstoneGeometryConfigScript.new(style_idx)
			var asset = _mesh_facade.generate_tombstone_fixture(cfg)
			return asset.to_node3d("Tombstone") if asset != null else null

		&"table_prop":
			var style_idx: int = params.get("style", 0)
			var cfg = _mesh_facade._TableGeometryConfigScript.new(style_idx)
			var asset = _mesh_facade.generate_table_fixture(cfg)
			return asset.to_node3d("Table") if asset != null else null

		&"chair_prop":
			var style_idx: int = params.get("style", 0)
			var cfg = _mesh_facade._ChairGeometryConfigScript.new(style_idx)
			var asset = _mesh_facade.generate_chair_fixture(cfg)
			return asset.to_node3d("Chair") if asset != null else null

		&"bookshelf_prop":
			var style_idx: int = params.get("style", 0)
			var cfg = _mesh_facade._BookshelfGeometryConfigScript.new(style_idx)
			var asset = _mesh_facade.generate_bookshelf_fixture(cfg)
			return asset.to_node3d("Bookshelf") if asset != null else null

		&"chest_prop":
			var is_open: bool = params.get("is_open", false)
			var cfg = _mesh_facade._ChestGeometryConfigScript.new(is_open)
			var asset = _mesh_facade.generate_chest_fixture(cfg)
			return asset.to_node3d("Chest") if asset != null else null

		&"crate_prop":
			var cfg = _mesh_facade._CrateGeometryConfigScript.new()
			var asset = _mesh_facade.generate_crate_fixture(cfg)
			return asset.to_node3d("Crate") if asset != null else null

		&"barrel_prop":
			var cfg = _mesh_facade._BarrelGeometryConfigScript.new()
			var asset = _mesh_facade.generate_barrel_fixture(cfg)
			return asset.to_node3d("Barrel") if asset != null else null

		&"rubble_prop":
			var cfg = _mesh_facade._RubbleGeometryConfigScript.new()
			var asset = _mesh_facade.generate_rubble_fixture(cfg)
			return asset.to_node3d("Rubble") if asset != null else null

		&"sack_prop":
			var cfg = _mesh_facade._SackGeometryConfigScript.new()
			var asset = _mesh_facade.generate_sack_fixture(cfg)
			return asset.to_node3d("Sack") if asset != null else null

		_:
			push_warning("[PropProceduralFactory] Constructor procedural no reconocido: %s" % str(builder_id))
			return null
