class_name ArchitecturalStyleConfigResolver
extends RefCounted

## Resolvedor y traductor desacoplado de configuraciones geométricas y estéticas.
## Transforma un ArchitecturalPresentationProfile en configuraciones concretas
## (FloorTileConfig, DecorationConfig, WallGeometryConfig) sin acoplar la lógica visual al builder.

const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")

func resolve_floor_config(
	profile: _ArchitecturalPresentationProfileScript,
	base_config: _FloorTileConfigScript = null
) -> _FloorTileConfigScript:
	var cfg: _FloorTileConfigScript = null
	if base_config != null:
		if base_config.has_method("duplicate_config"):
			cfg = base_config.duplicate_config() as _FloorTileConfigScript
		else:
			cfg = base_config.duplicate() as _FloorTileConfigScript
	else:
		cfg = _FloorTileConfigScript.new()

	if profile == null:
		return cfg

	match profile.floor_style:
		_ArchitecturalStyleScript.FloorStyle.RUINED_STONE:
			cfg.pattern = _FloorTileConfigScript.PatternType.RUINED_TILES
		_ArchitecturalStyleScript.FloorStyle.COBBLESTONE:
			cfg.pattern = _FloorTileConfigScript.PatternType.COBBLESTONE
		_ArchitecturalStyleScript.FloorStyle.BRICK:
			cfg.pattern = _FloorTileConfigScript.PatternType.BRICK
		_ArchitecturalStyleScript.FloorStyle.SMOOTH_SLABS, _ArchitecturalStyleScript.FloorStyle.TEMPLE_TILES:
			cfg.pattern = _FloorTileConfigScript.PatternType.SMOOTH_SLABS
		_ArchitecturalStyleScript.FloorStyle.MINE_ROCK:
			cfg.pattern = _FloorTileConfigScript.PatternType.COBBLESTONE
		_ArchitecturalStyleScript.FloorStyle.CATACOMB_DIRT:
			cfg.pattern = _FloorTileConfigScript.PatternType.CATACOMB_DIRT
		_:
			cfg.pattern = _FloorTileConfigScript.PatternType.STYLIZED_STONE

	return cfg

func resolve_wall_decoration_config(
	profile: _ArchitecturalPresentationProfileScript,
	base_config: _DecorationConfigScript = null
) -> _DecorationConfigScript:
	var cfg: _DecorationConfigScript = null
	if base_config != null:
		cfg = base_config.duplicate() as _DecorationConfigScript
	else:
		cfg = _DecorationConfigScript.new()

	if profile == null:
		return cfg

	match profile.wall_style:
		_ArchitecturalStyleScript.WallStyle.FORTRESS_STONE:
			cfg.style = _DecorationConfigScript.DecorationStyle.FULL_MASONRY
			cfg.brick_density = 0.75
		_ArchitecturalStyleScript.WallStyle.DARK_STONE:
			cfg.style = _DecorationConfigScript.DecorationStyle.STYLIZED_CLUSTERS
			cfg.brick_density = 0.50
		_ArchitecturalStyleScript.WallStyle.TEMPLE_STONE:
			cfg.style = _DecorationConfigScript.DecorationStyle.STYLIZED_CLUSTERS
			cfg.brick_density = 0.35
		_ArchitecturalStyleScript.WallStyle.MINE_ROCK:
			cfg.style = _DecorationConfigScript.DecorationStyle.FULL_MASONRY
			cfg.brick_density = 0.60
		_:
			cfg.style = _DecorationConfigScript.DecorationStyle.STYLIZED_CLUSTERS
			cfg.brick_density = 0.55

	return cfg

func resolve_wall_geometry_config(
	profile: _ArchitecturalPresentationProfileScript,
	base_config: _WallGeometryConfigScript = null
) -> _WallGeometryConfigScript:
	var cfg: _WallGeometryConfigScript = null
	if base_config != null:
		if base_config.has_method("duplicate_config"):
			cfg = base_config.duplicate_config()
		else:
			cfg = base_config.duplicate() as _WallGeometryConfigScript
	else:
		cfg = _WallGeometryConfigScript.new()

	return cfg
