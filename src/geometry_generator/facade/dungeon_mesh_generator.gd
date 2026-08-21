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

const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _ArchGeometryConfigScript = preload("res://src/geometry_generator/config/arch_geometry_config.gd")
const _DoorGeometryConfigScript = preload("res://src/geometry_generator/config/door_geometry_config.gd")
const _StairGeometryConfigScript = preload("res://src/geometry_generator/config/stair_geometry_config.gd")

var _wall_generator: RefCounted = null
var _floor_generator: RefCounted = null
var _arch_builder: RefCounted = null
var _door_builder: RefCounted = null
var _stair_builder: RefCounted = null
var _torch_builder: RefCounted = null

func _init() -> void:
	_wall_generator = _DungeonGeometryGeneratorScript.new()
	_floor_generator = _DungeonFloorGeneratorScript.new()
	_arch_builder = _ArchGeometryBuilderScript.new()
	_door_builder = _DoorGeometryBuilderScript.new()
	_stair_builder = _StairGeometryBuilderScript.new()
	_torch_builder = _TorchGeometryBuilderScript.new()

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
