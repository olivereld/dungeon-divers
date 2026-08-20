class_name ContinuousWallMeshBuilder
extends RefCounted

## Ensamblador de malla continua fluida para la estructura de paredes de la mazmorra.
## Actúa como adaptador de retrocompatibilidad de alto nivel delegando a la arquitectura modular src/geometry_generator.

const _DungeonGeometryGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const _WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")

var _generator := _DungeonGeometryGeneratorScript.new()

## Construye la malla continua unificada de paredes para todo el CellGrid.
func build_dungeon_wall_mesh(
	grid: CellGrid,
	config: WallMeshConfig = null,
	material_preset: int = 0,
	opening_manifest: WallOpeningManifest = null
) -> ArrayMesh:
	if grid == null:
		return ArrayMesh.new()

	if config == null:
		config = _WallMeshConfigScript.new()

	var wall_cfg := _WallGeometryConfigScript.new()
	wall_cfg.cube_size = config.cube_size
	wall_cfg.cubes_high = config.cubes_high
	wall_cfg.wall_thickness = config.wall_thickness
	wall_cfg.top_trim_height = config.top_trim_height
	wall_cfg.top_trim_slope_height = config.top_trim_slope_height
	wall_cfg.bottom_trim_height = config.bottom_trim_height
	wall_cfg.bottom_trim_slope_height = config.bottom_trim_slope_height
	wall_cfg.trim_overhang = config.trim_overhang
	wall_cfg.seed = config.seed

	var dec_cfg := _DecorationConfigScript.new()
	dec_cfg.enabled = config.use_noise_distribution
	dec_cfg.brick_density = config.brick_density
	dec_cfg.noise_frequency = config.noise_frequency
	dec_cfg.brick_width = config.brick_width
	dec_cfg.brick_height = config.brick_height
	dec_cfg.brick_size_variance = config.brick_size_variance
	dec_cfg.brick_protrusion = config.brick_protrusion
	dec_cfg.brick_depth_variance = config.brick_depth_variance
	dec_cfg.pillowed_bevel = config.pillowed_bevel
	dec_cfg.brick_jitter_rot = config.brick_jitter_rot
	dec_cfg.seed = config.seed

	var col_cfg := _CollisionConfigScript.new()
	col_cfg.mode = _CollisionConfigScript.CollisionMode.NONE # La colisión física se gestiona en staging

	var res = _generator.generate_wall_clusters(
		grid,
		opening_manifest,
		wall_cfg,
		col_cfg,
		dec_cfg,
		material_preset
	)

	return res.get_unified_mesh()
