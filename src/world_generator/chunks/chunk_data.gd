class_name ChunkData
extends WorldResult

## Estructura de datos desacoplada que almacena el contenido final de un chunk.
## Extiende WorldResult para compatibilidad polimórfica total con todos los stages.

var coord: Vector2i = Vector2i.ZERO
var core_bounds: Rect2i = Rect2i()
var generation_bounds: Rect2i = Rect2i()
var is_generated: bool = false

var seam_cells: Dictionary = {}
var pois: Array = []

func _init(p_coord: Vector2i = Vector2i.ZERO, p_core: Rect2i = Rect2i(), p_gen: Rect2i = Rect2i()) -> void:
	coord = p_coord
	core_bounds = p_core
	generation_bounds = p_gen
	dimensions = p_core.size

## Elimina las celdas de halo temporales que caen fuera de core_bounds,
## pero preserva las celdas de costura (+1 en todas direcciones y +2 en este/sur para vértices de frontera)
## garantizando que TerrainMeshBuilder disponga de todos los vecinos para calcular normales continuas C1.
func trim_to_core() -> void:
	var seam_rect := Rect2i(
		core_bounds.position.x - 1,
		core_bounds.position.y - 1,
		core_bounds.size.x + 3,
		core_bounds.size.y + 3
	)
	var keys_to_remove: Array[Vector2i] = []
	for pos in cells:
		if not core_bounds.has_point(pos):
			if seam_rect.has_point(pos):
				seam_cells[pos] = cells[pos]
			keys_to_remove.append(pos)
	for pos in keys_to_remove:
		cells.erase(pos)

func get_cell_or_seam(pos: Vector2i) -> WorldCell:
	var c: WorldCell = cells.get(pos, null)
	if c != null:
		return c
	return seam_cells.get(pos, null)

func get_dimensions() -> Vector2i:
	return core_bounds.size
