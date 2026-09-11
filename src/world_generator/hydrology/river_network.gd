class_name RiverNetwork
extends RefCounted

## Contrato de datos explícito para la Red Hidrográfica completa.
## Modela el grafo dirigido acíclico (DAG) de ríos, fuentes, confluencias, lagos y salidas.

var rivers: Array = []
var sources: Array = []
var confluences: Array = []
var lakes: Array = []
var outlets: Array = []

var _rivers_by_id: Dictionary = {}  # id -> River / Dict

func add_river(river: Variant) -> void:
	rivers.append(river)
	if river is River or "id" in river:
		_rivers_by_id[river.id] = river
	elif river is Dictionary:
		_rivers_by_id[river.get("id", river.get("index", -1))] = river

func get_river(id: int) -> Variant:
	return _rivers_by_id.get(id, null)

func has_river(id: int) -> bool:
	return _rivers_by_id.has(id)

func get_headwaters() -> Array:
	var result: Array = []
	for r in rivers:
		var up: Array = r.upstream_rivers if (r is River or "upstream_rivers" in r) else r.get("upstream_rivers", [])
		if up.is_empty():
			result.append(r)
	return result

func get_terminal_rivers() -> Array:
	var result: Array = []
	for r in rivers:
		var down: int = r.downstream_river if (r is River or "downstream_river" in r) else r.get("downstream_river", -1)
		if down == -1:
			result.append(r)
	return result

func to_dict() -> Dictionary:
	var rivers_dicts: Array = []
	for r in rivers:
		if r is River or r.has_method("to_dict"):
			rivers_dicts.append(r.to_dict())
		elif r is Dictionary:
			rivers_dicts.append(r)

	return {
		"rivers": rivers_dicts,
		"sources": sources,
		"confluences": confluences,
		"lakes": lakes,
		"outlets": outlets
	}
