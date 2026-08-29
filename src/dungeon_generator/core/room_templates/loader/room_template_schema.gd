class_name RoomTemplateSchema
extends RefCounted

## Validador y conversor de esquema para diccionarios crudos de RoomTemplates.

static func validate_raw_dict(dict: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if dict.is_empty():
		errors.append("Empty room template dictionary")
		return errors

	if not dict.has("id") or str(dict.get("id", "")).strip_edges().is_empty():
		errors.append("RoomTemplate missing valid 'id' property")

	var geom = dict.get("geometry", {})
	if geom is Dictionary and not geom.is_empty():
		var w_min = int(geom.get("width", {}).get("min", 1) if geom.get("width") is Dictionary else 1)
		var w_max = int(geom.get("width", {}).get("max", 1) if geom.get("width") is Dictionary else 1)
		if w_min > w_max:
			errors.append("Invalid geometry: min width (%d) > max width (%d)" % [w_min, w_max])

		var d_min = int(geom.get("depth", {}).get("min", 1) if geom.get("depth") is Dictionary else 1)
		var d_max = int(geom.get("depth", {}).get("max", 1) if geom.get("depth") is Dictionary else 1)
		if d_min > d_max:
			errors.append("Invalid geometry: min depth (%d) > max depth (%d)" % [d_min, d_max])

	return errors
