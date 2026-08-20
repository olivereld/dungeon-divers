class_name WallComponent
extends RefCounted

## Componente conexa de frontera de muros que agrupa uno o más bucles cerrados y/o cadenas abiertas.
## Representa la unidad fundamental para generación de mallas independientes (clusters).

var id: int = 0
var loops: Array = []         # Array de Array[Vector2i] (bucles poligonales ordenados)
var open_chains: Array = []   # Array de Array[Vector2i] (tramos lineales no cerrados)
var bounds: Rect2i = Rect2i()

func _init(p_id: int = 0) -> void:
	id = p_id

func add_loop(loop: Array) -> void:
	if loop.size() >= 3:
		var typed_loop: Array[Vector2i] = []
		for pt in loop:
			typed_loop.append(pt as Vector2i)
		loops.append(typed_loop)
		_update_bounds_with_points(typed_loop)

func add_chain(chain: Array) -> void:
	if chain.size() >= 2:
		var typed_chain: Array[Vector2i] = []
		for pt in chain:
			typed_chain.append(pt as Vector2i)
		open_chains.append(typed_chain)
		_update_bounds_with_points(typed_chain)

func get_total_vertex_count() -> int:
	var total: int = 0
	for l in loops:
		total += l.size()
	for c in open_chains:
		total += c.size()
	return total

func is_empty() -> bool:
	return loops.is_empty() and open_chains.is_empty()

func _update_bounds_with_points(pts: Array[Vector2i]) -> void:
	for pt in pts:
		if bounds.size == Vector2i.ZERO and bounds.position == Vector2i.ZERO:
			bounds = Rect2i(pt, Vector2i.ONE)
		else:
			bounds = bounds.expand(pt)
