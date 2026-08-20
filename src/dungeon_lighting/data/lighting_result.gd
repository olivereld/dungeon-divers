class_name LightingResult
extends RefCounted

## Contenedor DTO con los resultados de la generación de iluminación lógica.
## 100% libre de nodos de escena (Headless-safe).

var placements: Array[LightPlacement] = []
var diagnostics: Array[Dictionary] = []
var seed_used: int = 0
var generation_time_ms: float = 0.0

func has_lights() -> bool:
	return not placements.is_empty()

func get_room_lights(room_id: int) -> Array[LightPlacement]:
	var list: Array[LightPlacement] = []
	for p in placements:
		if p.room_id == room_id:
			list.append(p)
	return list

func get_corridor_lights(corridor_id: String = "") -> Array[LightPlacement]:
	var list: Array[LightPlacement] = []
	for p in placements:
		if p.room_id == -1:
			if corridor_id.is_empty() or p.corridor_id == corridor_id:
				list.append(p)
	return list

func add_diagnostic(code: String, level: String, msg: String) -> void:
	diagnostics.append({
		"code": code,
		"level": level,
		"message": msg
	})
