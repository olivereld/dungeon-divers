class_name DisjointSet
extends RefCounted

## Estructura de datos Union-Find pura con compresión de caminos y unión por rango.
## Permite verificar y unir componentes conexas en tiempo casi lineal O(α(N)).

var _parent: Array[int] = []
var _rank: Array[int] = []
var _components: int = 0

func _init(size: int = 0) -> void:
	if size > 0:
		reset(size)

func reset(size: int) -> void:
	_parent.resize(size)
	_rank.resize(size)
	_components = size
	for i in range(size):
		_parent[i] = i
		_rank[i] = 0

func find(x: int) -> int:
	if x < 0 or x >= _parent.size():
		return -1
	var root: int = x
	while root != _parent[root]:
		root = _parent[root]
	# Compresión de camino
	var curr: int = x
	while curr != root:
		var nxt: int = _parent[curr]
		_parent[curr] = root
		curr = nxt
	return root

func union(a: int, b: int) -> bool:
	var root_a: int = find(a)
	var root_b: int = find(b)
	if root_a == -1 or root_b == -1 or root_a == root_b:
		return false

	if _rank[root_a] < _rank[root_b]:
		_parent[root_a] = root_b
	elif _rank[root_a] > _rank[root_b]:
		_parent[root_b] = root_a
	else:
		_parent[root_b] = root_a
		_rank[root_a] += 1

	_components -= 1
	return true

func connected(a: int, b: int) -> bool:
	var root_a: int = find(a)
	var root_b: int = find(b)
	return root_a != -1 and root_a == root_b

func get_component_count() -> int:
	return _components
