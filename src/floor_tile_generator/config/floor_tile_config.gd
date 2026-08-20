class_name FloorTileConfig
extends Resource

## Configuración modular y determinista para la generación de baldosas procedurales de suelo (Presentation Layer).

enum CollisionMode {
	NONE,          ## Sin colisión física
	COMPOUND_BOX,  ## Cajas simples por sub-rectángulo continuo de región
	SIMPLE_BOX     ## Caja única por cluster AABB
}

@export var tile_size: float = 2.0
@export var margin: float = 0.035          ## Separación de mortero entre losas
@export var height_min: float = 0.045      ## Altura mínima de losa
@export var height_max: float = 0.075      ## Altura máxima de losa
@export var bevel_min: float = 0.022       ## Bisel mínimo
@export var bevel_max: float = 0.032       ## Bisel máximo
@export var tone_variation: float = 0.04   ## Rango de variación tonal por losa
@export var collision_mode: CollisionMode = CollisionMode.COMPOUND_BOX
@export var collision_depth: float = 0.5   ## Profundidad hacia abajo de la colisión física
@export var material_preset: int = 0       ## Preset en WallMaterialFactory
@export var seed: int = 1337

func duplicate_config() -> Resource:
	var cfg = (get_script() as GDScript).new()
	cfg.tile_size = tile_size
	cfg.margin = margin
	cfg.height_min = height_min
	cfg.height_max = height_max
	cfg.bevel_min = bevel_min
	cfg.bevel_max = bevel_max
	cfg.tone_variation = tone_variation
	cfg.collision_mode = collision_mode
	cfg.collision_depth = collision_depth
	cfg.material_preset = material_preset
	cfg.seed = seed
	return cfg
