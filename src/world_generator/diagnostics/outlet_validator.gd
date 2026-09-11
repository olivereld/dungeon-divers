class_name OutletValidator
extends RefCounted

## Cierre formal de validación topológica de Outlets (Salidas de drenaje).
## Clasifica cada outlet en MAP_BOUNDARY, LAKE_SPILLWAY o INVALID.

enum OutletType {
	MAP_BOUNDARY = 0,
	LAKE_SPILLWAY = 1,
	INVALID = 2
}

static func is_boundary(pos: Vector2i, width: int, height: int) -> bool:
	return pos.x == 0 or pos.x == width - 1 or pos.y == 0 or pos.y == height - 1

static func is_registered_spillway(pos: Vector2i, hydro: RefCounted) -> bool:
	for lake in hydro.lakes:
		if lake.get("spillway_pos", Vector2i(-1, -1)) == pos:
			return true
	return false

static func classify_outlet(outlet: Vector2i, hydro: RefCounted, width: int, height: int) -> int:
	if is_boundary(outlet, width, height):
		return OutletType.MAP_BOUNDARY
	if hydro.is_lake(outlet) or is_registered_spillway(outlet, hydro):
		return OutletType.LAKE_SPILLWAY
	return OutletType.INVALID

static func validate_outlets(
	outlets: Array,
	cells: Dictionary,
	flow_to: Dictionary,
	hydro: RefCounted,
	width: int,
	height: int,
	profile: WorldProfile = null
) -> Dictionary:
	var outlets_boundary: int = 0
	var outlets_lake_spillway: int = 0
	var outlets_invalid: int = 0
	var outlets_suspicious_boundary: int = 0
	var outlet_types: Dictionary = {}

	# Calibración de umbral de altura anómala de borde (p. ej. percentil 90 o cota de relieve alto)
	var boundary_elevation_warn_threshold: float = 12.0
	if profile != null:
		boundary_elevation_warn_threshold = profile.base_height + profile.get_macro_amplitude() * 0.85

	for o in outlets:
		var outlet: Vector2i = o
		var o_type: int = classify_outlet(outlet, hydro, width, height)
		outlet_types[outlet] = o_type

		match o_type:
			OutletType.MAP_BOUNDARY:
				outlets_boundary += 1
				var c: WorldCell = cells.get(outlet)
				if c != null:
					var h_raw: float = c.raw_height if c.raw_height != 0.0 else c.height
					if h_raw > boundary_elevation_warn_threshold:
						outlets_suspicious_boundary += 1
			OutletType.LAKE_SPILLWAY:
				outlets_lake_spillway += 1
			_:
				outlets_invalid += 1

	# Verificación de inflow a lagos
	var lakes_without_inflow: int = 0
	for lake in hydro.lakes:
		var lake_cells: Array = lake.get("cells", [])
		var lake_set: Dictionary = {}
		for lc in lake_cells:
			lake_set[lc] = true

		var has_external_inflow: bool = false
		for pos in flow_to:
			if lake_set.has(pos):
				continue
			var dest: Vector2i = flow_to[pos]
			if lake_set.has(dest):
				has_external_inflow = true
				break

		if not has_external_inflow:
			lakes_without_inflow += 1

	return {
		"outlets_boundary": outlets_boundary,
		"outlets_lake_spillway": outlets_lake_spillway,
		"outlets_invalid": outlets_invalid,
		"outlets_suspicious_boundary": outlets_suspicious_boundary,
		"lakes_without_inflow": lakes_without_inflow,
		"outlet_types": outlet_types
	}
