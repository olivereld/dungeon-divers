# DungeonMeshGenerator
extends RefCounted

## Fachada orquestadora unificada de alto nivel para la generación geométrica de mazmorras (Arquitectura Unificada).
## Coordina exclusivamente los generadores y constructores geométricos especializados sin construir vértices directamente.
## Proporciona un único punto de entrada común para DungeonPresentationBuilder y MeshGalleryRenderer.

const _DungeonGeometryGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const _DungeonFloorGeneratorScript = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const _ArchGeometryBuilderScript = preload("res://src/geometry_generator/geometry/arch_geometry_builder.gd")
const _DoorGeometryBuilderScript = preload("res://src/geometry_generator/geometry/door_geometry_builder.gd")
const _StairGeometryBuilderScript = preload("res://src/geometry_generator/geometry/stair_geometry_builder.gd")
const _TorchGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/torch_geometry_builder.gd")
const _BrazierGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/brazier_geometry_builder.gd")
const _LanternGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/lantern_geometry_builder.gd")
const _CandleHolderGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/candle_holder_geometry_builder.gd")
const _CandleClusterGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/candle_cluster_geometry_builder.gd")
const _CrateGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/crate_geometry_builder.gd")

const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _ArchGeometryConfigScript = preload("res://src/geometry_generator/config/arch_geometry_config.gd")
const _DoorGeometryConfigScript = preload("res://src/geometry_generator/config/door_geometry_config.gd")
const _StairGeometryConfigScript = preload("res://src/geometry_generator/config/stair_geometry_config.gd")
const _BrazierGeometryConfigScript = preload("res://src/geometry_generator/config/brazier_geometry_config.gd")
const _LanternGeometryConfigScript = preload("res://src/geometry_generator/config/lantern_geometry_config.gd")
const _CandleHolderGeometryConfigScript = preload("res://src/geometry_generator/config/candle_holder_geometry_config.gd")
const _CandleClusterGeometryConfigScript = preload("res://src/geometry_generator/config/candle_cluster_geometry_config.gd")
const _CrateGeometryConfigScript = preload("res://src/geometry_generator/config/crate_geometry_config.gd")
const _BarrelGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/barrel_geometry_builder.gd")
const _BarrelGeometryConfigScript = preload("res://src/geometry_generator/config/barrel_geometry_config.gd")
const _ChestGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/chest_geometry_builder.gd")
const _ChestGeometryConfigScript = preload("res://src/geometry_generator/config/chest_geometry_config.gd")
const _SackGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/sack_geometry_builder.gd")
const _SackGeometryConfigScript = preload("res://src/geometry_generator/config/sack_geometry_config.gd")
const _RubbleGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/rubble_geometry_builder.gd")
const _RubbleGeometryConfigScript = preload("res://src/geometry_generator/config/rubble_geometry_config.gd")
const _AltarGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/altar_geometry_builder.gd")
const _AltarGeometryConfigScript = preload("res://src/geometry_generator/config/altar_geometry_config.gd")
const _TombstoneGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/tombstone_geometry_builder.gd")
const _TombstoneGeometryConfigScript = preload("res://src/geometry_generator/config/tombstone_geometry_config.gd")
const _TableGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/table_geometry_builder.gd")
const _TableGeometryConfigScript = preload("res://src/geometry_generator/config/table_geometry_config.gd")
const _ChairGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/chair_geometry_builder.gd")
const _ChairGeometryConfigScript = preload("res://src/geometry_generator/config/chair_geometry_config.gd")
const _BookshelfGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/bookshelf_geometry_builder.gd")
const _BookshelfGeometryConfigScript = preload("res://src/geometry_generator/config/bookshelf_geometry_config.gd")
const _WallShowcaseGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/wall_showcase_geometry_builder.gd")
const _WallShowcaseGeometryConfigScript = preload("res://src/geometry_generator/config/wall_showcase_geometry_config.gd")
const _SarcophagusGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/sarcophagus_geometry_builder.gd")
const _SarcophagusGeometryConfigScript = preload("res://src/geometry_generator/config/sarcophagus_geometry_config.gd")
const _BenchGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/bench_geometry_builder.gd")
const _BenchGeometryConfigScript = preload("res://src/geometry_generator/config/bench_geometry_config.gd")

var _wall_generator: RefCounted = null
var _floor_generator: RefCounted = null
var _arch_builder: RefCounted = null
var _door_builder: RefCounted = null
var _stair_builder: RefCounted = null
var _torch_builder: RefCounted = null
var _brazier_builder: RefCounted = null
var _lantern_builder: RefCounted = null
var _candle_holder_builder: RefCounted = null
var _candle_cluster_builder: RefCounted = null
var _crate_builder: RefCounted = null
var _barrel_builder: RefCounted = null
var _chest_builder: RefCounted = null
var _sack_builder: RefCounted = null
var _rubble_builder: RefCounted = null
var _altar_builder: RefCounted = null
var _tombstone_builder: RefCounted = null
var _table_builder: RefCounted = null
var _chair_builder: RefCounted = null
var _bookshelf_builder: RefCounted = null
var _wall_showcase_builder: RefCounted = null
var _sarcophagus_builder: RefCounted = null
var _bench_builder: RefCounted = null

func _init() -> void:
	_wall_generator = _DungeonGeometryGeneratorScript.new()
	_floor_generator = _DungeonFloorGeneratorScript.new()
	_arch_builder = _ArchGeometryBuilderScript.new()
	_door_builder = _DoorGeometryBuilderScript.new()
	_stair_builder = _StairGeometryBuilderScript.new()
	_torch_builder = _TorchGeometryBuilderScript.new()
	_brazier_builder = _BrazierGeometryBuilderScript.new()
	_lantern_builder = _LanternGeometryBuilderScript.new()
	_candle_holder_builder = _CandleHolderGeometryBuilderScript.new()
	_candle_cluster_builder = _CandleClusterGeometryBuilderScript.new()
	_crate_builder = _CrateGeometryBuilderScript.new()
	_barrel_builder = _BarrelGeometryBuilderScript.new()
	_chest_builder = _ChestGeometryBuilderScript.new()
	_sack_builder = _SackGeometryBuilderScript.new()
	_rubble_builder = _RubbleGeometryBuilderScript.new()
	_altar_builder = _AltarGeometryBuilderScript.new()
	_tombstone_builder = _TombstoneGeometryBuilderScript.new()
	_table_builder = _TableGeometryBuilderScript.new()
	_chair_builder = _ChairGeometryBuilderScript.new()
	_bookshelf_builder = _BookshelfGeometryBuilderScript.new()
	_wall_showcase_builder = _WallShowcaseGeometryBuilderScript.new()
	_sarcophagus_builder = _SarcophagusGeometryBuilderScript.new()
	_bench_builder = _BenchGeometryBuilderScript.new()

# ==============================================================================
# 1. MUROS Y ESTRUCTURAS CONTINUAS
# ==============================================================================

func generate_walls(
	grid,
	opening_manifest = null,
	wall_config = null,
	collision_config = null,
	decoration_config = null,
	seed_val: int = 1337
):
	if wall_config == null:
		wall_config = _WallGeometryConfigScript.new()
	if collision_config == null:
		collision_config = _CollisionConfigScript.new()
	if decoration_config == null:
		decoration_config = _DecorationConfigScript.new()

	return _wall_generator.generate_wall_clusters(
		grid, opening_manifest, wall_config, collision_config, decoration_config, seed_val
	)

# ==============================================================================
# 2. SUELOS ESTOCÁSTICOS MULTI-PATRÓN
# ==============================================================================

func generate_floors(
	grid,
	floor_config = null,
	seed_val: int = 1337
):
	if floor_config == null:
		floor_config = _FloorTileConfigScript.new()

	return _floor_generator.generate_floor_surface(grid, floor_config, seed_val)

# ==============================================================================
# 3. ARCOS Y PORTALES
# ==============================================================================

func generate_arch(arch_config = null):
	if arch_config == null:
		arch_config = _ArchGeometryConfigScript.new()

	return _arch_builder.build_arch_mesh(arch_config)

func generate_door_leaf(door_config = null):
	if door_config == null:
		door_config = _DoorGeometryConfigScript.new()

	return _door_builder.build_door_leaf_mesh(door_config)

func generate_door_portal(
	arch_config = null,
	door_config = null,
	is_open: bool = false,
	is_locked: bool = false
):
	if arch_config == null:
		arch_config = _ArchGeometryConfigScript.new()
	if door_config == null:
		door_config = _DoorGeometryConfigScript.new()

	return _door_builder.build_portal_assembly(arch_config, door_config, is_open, is_locked)

# ==============================================================================
# 4. ESCALERAS PROCEDURALES
# ==============================================================================

func generate_stairs(stair_config = null):
	if stair_config == null:
		stair_config = _StairGeometryConfigScript.new()

	return _stair_builder.build_stair_mesh(stair_config)

# ==============================================================================
# 5. FIXTURES Y LUMINARIAS
# ==============================================================================

func generate_torch_fixture(bracket_length: float = 0.42, flame_scale: float = 1.0):
	return _torch_builder.build_torch_fixture(bracket_length, flame_scale)

func generate_brazier_fixture(brazier_config = null):
	if brazier_config == null:
		brazier_config = _BrazierGeometryConfigScript.new()
	return _brazier_builder.build_brazier_fixture(brazier_config)

func generate_lantern_fixture(lantern_config = null):
	if lantern_config == null:
		lantern_config = _LanternGeometryConfigScript.new()
	return _lantern_builder.build_lantern_fixture(lantern_config)

func generate_candle_holder_fixture(candle_config = null):
	if candle_config == null:
		candle_config = _CandleHolderGeometryConfigScript.new()
	return _candle_holder_builder.build_candle_holder_fixture(candle_config)

func generate_candle_cluster_fixture(cluster_config = null):
	if cluster_config == null:
		cluster_config = _CandleClusterGeometryConfigScript.new()
	return _candle_cluster_builder.build_candle_cluster_fixture(cluster_config)

func generate_crate_fixture(crate_config = null):
	if crate_config == null:
		crate_config = _CrateGeometryConfigScript.new()
	return _crate_builder.build_crate_fixture(crate_config)

func generate_barrel_fixture(barrel_config = null):
	if barrel_config == null:
		barrel_config = _BarrelGeometryConfigScript.new()
	return _barrel_builder.build_barrel_fixture(barrel_config)

func generate_chest_base(chest_config = null):
	if chest_config == null:
		chest_config = _ChestGeometryConfigScript.new()
	return _chest_builder.build_chest_base(chest_config)

func generate_chest_lid(chest_config = null):
	if chest_config == null:
		chest_config = _ChestGeometryConfigScript.new()
	return _chest_builder.build_chest_lid(chest_config)

func generate_chest_fixture(chest_config = null):
	if chest_config == null:
		chest_config = _ChestGeometryConfigScript.new()
	return _chest_builder.build_chest_fixture(chest_config)

func generate_sack_fixture(sack_config = null):
	if sack_config == null:
		sack_config = _SackGeometryConfigScript.new()
	return _sack_builder.build_sack_fixture(sack_config)

func generate_rubble_fixture(rubble_config = null):
	if rubble_config == null:
		rubble_config = _RubbleGeometryConfigScript.new()
	return _rubble_builder.build_rubble_fixture(rubble_config)

func generate_altar_fixture(altar_config = null):
	if altar_config == null:
		altar_config = _AltarGeometryConfigScript.new()
	return _altar_builder.build_altar_fixture(altar_config)

func generate_tombstone_fixture(tombstone_config = null):
	if tombstone_config == null:
		tombstone_config = _TombstoneGeometryConfigScript.new()
	return _tombstone_builder.build_tombstone_fixture(tombstone_config)

func generate_table_fixture(table_config = null):
	if table_config == null:
		table_config = _TableGeometryConfigScript.new()
	return _table_builder.build_table_fixture(table_config)

func generate_chair_fixture(chair_config = null):
	if chair_config == null:
		chair_config = _ChairGeometryConfigScript.new()
	return _chair_builder.build_chair_fixture(chair_config)

func generate_bookshelf_fixture(bookshelf_config = null):
	if bookshelf_config == null:
		bookshelf_config = _BookshelfGeometryConfigScript.new()
	return _bookshelf_builder.build_bookshelf_fixture(bookshelf_config)

func generate_wall_showcase_fixture(wall_config = null):
	if wall_config == null:
		wall_config = _WallShowcaseGeometryConfigScript.new()
	return _wall_showcase_builder.build_wall_showcase_fixture(wall_config)

func generate_sarcophagus_base(sarcophagus_config = null):
	if sarcophagus_config == null:
		sarcophagus_config = _SarcophagusGeometryConfigScript.new()
	return _sarcophagus_builder.build_sarcophagus_base(sarcophagus_config)

func generate_sarcophagus_lid(sarcophagus_config = null):
	if sarcophagus_config == null:
		sarcophagus_config = _SarcophagusGeometryConfigScript.new()
	return _sarcophagus_builder.build_sarcophagus_lid(sarcophagus_config)

func generate_sarcophagus_fixture(sarcophagus_config = null):
	if sarcophagus_config == null:
		sarcophagus_config = _SarcophagusGeometryConfigScript.new()
	return _sarcophagus_builder.build_sarcophagus_fixture(sarcophagus_config)

func generate_bench_fixture(bench_config = null):
	if bench_config == null:
		bench_config = _BenchGeometryConfigScript.new()
	return _bench_builder.build_bench_fixture(bench_config)


