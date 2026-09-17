class_name ChunkGenerationContext
extends WorldGenerationContext

## Contexto de generación para un chunk individual.
## Extiende WorldGenerationContext para cumplir 100% el contrato de tipos en todos los stages.

var coord: Vector2i = Vector2i.ZERO
var config: ChunkConfig = null

var core_bounds: Rect2i = Rect2i()
var generation_bounds: Rect2i = Rect2i()

## Parámetros de normalización determinista
var reference_min_height: float = 0.0
var reference_max_height: float = 0.0
var use_reference_height: bool = false

func _init(
	p_seed: int,
	p_profile: WorldProfile,
	p_coord: Vector2i,
	p_config: ChunkConfig = null,
	p_shared_hydro: RefCounted = null
) -> void:
	super(p_seed, p_profile, false)

	coord = p_coord
	config = p_config if p_config != null else ChunkConfig.new()

	var effective_margin: int = maxi(config.generation_margin, config.vegetation_margin)
	core_bounds = ChunkCoord.get_core_bounds(coord, config.chunk_size)
	generation_bounds = ChunkCoord.get_generation_bounds(coord, config.chunk_size, effective_margin)

	var chunk_data := ChunkData.new(coord, core_bounds, generation_bounds)
	chunk_data.master_seed = p_seed
	chunk_data.hydrology = p_shared_hydro
	result = chunk_data

	if config.use_reference_height_range:
		reference_min_height = config.reference_min_height
		reference_max_height = config.reference_max_height
		use_reference_height = true

	# Inicializar celdas únicamente en el área de generación del chunk (core + halo)
	for y in range(generation_bounds.position.y, generation_bounds.end.y):
		for x in range(generation_bounds.position.x, generation_bounds.end.x):
			var pos := Vector2i(x, y)
			result.cells[pos] = WorldCell.new(pos)

func get_chunk_data() -> ChunkData:
	return result as ChunkData

func get_core_bounds() -> Rect2i:
	return core_bounds

func get_generation_bounds() -> Rect2i:
	return generation_bounds

func is_chunk_context() -> bool:
	return true
