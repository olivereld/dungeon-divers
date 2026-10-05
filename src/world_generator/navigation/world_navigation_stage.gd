class_name WorldNavigationStage
extends WorldStage

## Etapa de materialización lógica de navegación.
## Convierte los datos definitivos producidos por Terrain, Hydrology, Ecology y Navigation
## en un WorldNavigationChunk inmutable y empaquetado para el core_bounds del chunk.
## No calcula pendientes ni decide caminabilidad (esa autoridad reside en NavigationStage).

const _NavChunkScript = preload("res://src/world_generator/navigation/world_navigation_chunk.gd")

func execute(context: WorldGenerationContext) -> void:
	if not (context.has_method("is_chunk_context") and context.is_chunk_context()):
		return

	var chunk_data = context.result
	if chunk_data == null:
		return

	var core_bounds: Rect2i = context.get_core_bounds() if context.has_method("get_core_bounds") else Rect2i()
	var coord: Vector2i = context.coord if "coord" in context else Vector2i.ZERO

	var nav_chunk = _NavChunkScript.from_cells(coord, core_bounds, chunk_data.cells)
	chunk_data.navigation_chunk = nav_chunk
