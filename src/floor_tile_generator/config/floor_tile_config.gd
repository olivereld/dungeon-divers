class_name FloorTileConfig
extends Resource

## Configuración modular y determinista para la generación de baldosas procedurales de suelo (Presentation Layer).

enum CollisionMode {
	NONE,            ## Sin colisión física
	BOX,             ## Caja única por cluster AABB
	COMPOUND_BOX,    ## Cajas simples optimizadas por sub-rectángulo continuo
	CONCAVE_TRIMESH  ## Colisión trimesh exacta basada en los triángulos de la malla
}

enum PatternType {
	STYLIZED_STONE,  ## Losas entrelazadas estilizadas tipo Zelda / Diablo
	COBBLESTONE,     ## Adoquines de piedra pequeños con jitter
	BRICK,           ## Ladrillos rectangulares entrelazados
	SMOOTH_SLABS,    ## 4 losas amplias con bisel suave
	RUINED_TILES,    ## Suelo con losas rotas, huecos y micro-desplazamientos
	CATACOMB_DIRT    ## Suelo de tierra de cripta con relieve 3D ondulante y baldosas/guijarros incrustados
}

@export var tile_size: float = 2.0
@export var margin: float = 0.035          ## Separación de mortero entre losas
@export var height_min: float = 0.045      ## Altura mínima de losa
@export var height_max: float = 0.075      ## Altura máxima de losa
@export var bevel_min: float = 0.022       ## Bisel mínimo
@export var bevel_max: float = 0.032       ## Bisel máximo
@export var tone_variation: float = 0.05   ## Rango de variación tonal por losa
@export var pattern: PatternType = PatternType.STYLIZED_STONE
@export var collision_mode: CollisionMode = CollisionMode.COMPOUND_BOX
@export var collision_depth: float = 0.5   ## Profundidad hacia abajo de la colisión física
@export var material_preset: int = 0       ## Preset en WallMaterialFactory
@export var seed: int = 1337

# Parámetros de Variación Estocástica y Ruido Espacial (Fases V1-V2)
@export var use_noise_modulation: bool = true
@export var noise_frequency: float = 0.05
@export var jitter_strength: float = 0.012

func duplicate_config() -> Resource:
	var cfg = (get_script() as GDScript).new()
	cfg.tile_size = tile_size
	cfg.margin = margin
	cfg.height_min = height_min
	cfg.height_max = height_max
	cfg.bevel_min = bevel_min
	cfg.bevel_max = bevel_max
	cfg.tone_variation = tone_variation
	cfg.pattern = pattern
	cfg.collision_mode = collision_mode
	cfg.collision_depth = collision_depth
	cfg.material_preset = material_preset
	cfg.seed = seed
	cfg.use_noise_modulation = use_noise_modulation
	cfg.noise_frequency = noise_frequency
	cfg.jitter_strength = jitter_strength
	return cfg
