class_name WallComponent
extends RefCounted

## Componente conexa de frontera de muros que agrupa uno o más bucles cerrados y/o cadenas abiertas.
## Representa la unidad fundamental para generación de mallas independientes (clusters).

var id: int = 0
var loops: Array[Array] = []         # Array de Array[Vector2i] (polígonos cerrados simplificados)
var open_chains: Array[Array] = []   # Array de Array[Vector2i] (tramos lineales no cerrados)
var bounds: Rect2i = Rect2i()

func _init(p_id: int = 0) -> void:
	id = p_id

func add_loop(loop: Array[Vector2i]) -> void:
	if loop.size() >= 3:
		loops.append(loop)
		_update_bounds_with_points(loop)

func add_chain(chain: Array[Vector2i]) -> void:
	if chain.size() >= 2:
		open_chains.append(chain)
		_update_bounds_with_points(chain)

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
