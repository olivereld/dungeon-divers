class_name ChunkData
extends WorldResult

## Estructura de datos desacoplada que almacena el contenido final de un chunk.
## Extiende WorldResult para compatibilidad polimórfica total con todos los stages.

var coord: Vector2i = Vector2i.ZERO
var core_bounds: Rect2i = Rect2i()
var generation_bounds: Rect2i = Rect2i()
var is_generated: bool = false

var seam_cells: Dictionary = {}

func _init(p_coord: Vector2i = Vector2i.ZERO, p_core: Rect2i = Rect2i(), p_gen: Rect2i = Rect2i()) -> void:
	coord = p_coord
	core_bounds = p_core
	generation_bounds = p_gen
	dimensions = p_core.size

## Elimina las celdas de halo temporales que caen fuera de core_bounds,
## pero preserva las celdas de costura (+1 en este, sur y sureste) para la continuidad de la malla.
func trim_to_core() -> void:
	var keys_to_remove: Array[Vector2i] = []
	for pos in cells:
		if not core_bounds.has_point(pos):
			if (pos.x >= core_bounds.position.x and pos.x <= core_bounds.end.x and
				pos.y >= core_bounds.position.y and pos.y <= core_bounds.end.y):
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
