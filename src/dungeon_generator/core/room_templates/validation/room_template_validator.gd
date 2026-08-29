class_name RoomTemplateValidator
extends RefCounted

## Motor de validación geométrica y espacial de RoomTemplates.
## Evalúa si un candidato espacial (Rect2i, puntos de entrada, simetría) satisface las restricciones del template.

const _ValidationResultScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_validation_result.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")

func validate_rect(template: _RoomTemplateScript, rect: Rect2i) -> _ValidationResultScript:
	var result := _ValidationResultScript.new()
	if template == null:
		result.add_error("Null template provided for validation")
		return result

	var geom = template.geometry
	if geom == null:
		return result

	var w: int = rect.size.x
	var d: int = rect.size.y
	var area: int = w * d

	if w < geom.min_width:
		result.add_error("Room width (%d) is below minimum (%d)" % [w, geom.min_width])
	if w > geom.max_width:
		result.add_error("Room width (%d) exceeds maximum (%d)" % [w, geom.max_width])

	if d < geom.min_depth:
		result.add_error("Room depth (%d) is below minimum (%d)" % [d, geom.min_depth])
	if d > geom.max_depth:
		result.add_error("Room depth (%d) exceeds maximum (%d)" % [d, geom.max_depth])

	if area < geom.min_area:
		result.add_error("Room area (%d) is below minimum (%d)" % [area, geom.min_area])
	if area > geom.max_area:
		result.add_error("Room area (%d) exceeds maximum (%d)" % [area, geom.max_area])

	if d > 0:
		var aspect: float = float(w) / float(d)
		if aspect < geom.min_aspect_ratio:
			result.add_error("Aspect ratio (%.2f) is below minimum (%.2f)" % [aspect, geom.min_aspect_ratio])
		if aspect > geom.max_aspect_ratio:
			result.add_error("Aspect ratio (%.2f) exceeds maximum (%.2f)" % [aspect, geom.max_aspect_ratio])

	if geom.allowed_shapes.size() == 1 and geom.allowed_shapes[0] == &"square":
		if w != d:
			result.add_error("Template requires square shape, but dimensions are %dx%d" % [w, d])

	return result

func validate_entrances(template: _RoomTemplateScript, rect: Rect2i, entrance_points: Array[Vector2i]) -> _ValidationResultScript:
	var result := _ValidationResultScript.new()
	if template == null:
		result.add_error("Null template provided for validation")
		return result

	var ent = template.entrances
	if ent == null:
		return result

	# Si aún no se han colocado entradas (etapa previa de construcción de suelo), omitir validación
	if entrance_points.is_empty():
		return result

	var count: int = entrance_points.size()
	if count < ent.min_count:
		result.add_error("Entrance count (%d) is below minimum (%d)" % [count, ent.min_count])
	if count > ent.max_count:
		result.add_error("Entrance count (%d) exceeds maximum (%d)" % [count, ent.max_count])

	for i in range(count):
		var p: Vector2i = entrance_points[i]
		var side: StringName = _determine_side(rect, p)

		if side == &"corner" and not ent.allow_corner:
			result.add_error("Corner entrance at %s is forbidden by template" % str(p))
		elif side != &"unknown" and side != &"corner":
			if not ent.allows_side(side):
				result.add_error("Entrance at side '%s' (%s) is forbidden by template" % [str(side), str(p)])

		# Verificar espaciado mínimo con otras entradas
		for j in range(i + 1, count):
			var p2: Vector2i = entrance_points[j]
			var dist: int = abs(p.x - p2.x) + abs(p.y - p2.y)
			if dist < ent.min_spacing:
				result.add_error("Entrances at %s and %s are closer (%d) than min_spacing (%d)" % [
					str(p), str(p2), dist, ent.min_spacing
				])

	return result

func validate_shape_feasibility(template: _RoomTemplateScript, rect: Rect2i) -> _ValidationResultScript:
	var result := _ValidationResultScript.new()
	if template == null or template.geometry == null:
		return result

	var w: int = rect.size.x
	var d: int = rect.size.y
	var shapes = template.geometry.allowed_shapes
	if shapes.is_empty():
		return result

	var has_any_feasible: bool = false
	for sh in shapes:
		var is_feasible: bool = true
		match sh:
			&"pillared", &"pillared_hall", &"pillars":
				if w < 8 or d < 8:
					is_feasible = false
			&"cruciform", &"cruciform_sanctuary", &"cross":
				if w < 7 or d < 7:
					is_feasible = false
			&"chapel", &"central_nave", &"nave":
				if w < 8 or d < 8:
					is_feasible = false
			&"octagonal", &"octagonal_chamber", &"octagon":
				if w < 6 or d < 6:
					is_feasible = false
			&"niched_hall", &"niches":
				if w < 6 or d < 6:
					is_feasible = false
			&"rectangle", &"open_rectangle", &"square", &"custom", _:
				is_feasible = true

		if is_feasible:
			has_any_feasible = true
			break

	if not has_any_feasible:
		result.add_error("No allowed shapes (%s) are feasible for room dimensions %dx%d" % [str(shapes), w, d])

	return result

func validate_all(template: _RoomTemplateScript, rect: Rect2i, entrance_points: Array[Vector2i] = []) -> _ValidationResultScript:
	var res_geom := validate_rect(template, rect)
	var res_shape := validate_shape_feasibility(template, rect)
	for err in res_shape.errors:
		res_geom.add_error(err)
	for w in res_shape.warnings:
		res_geom.add_warning(w)

	if not entrance_points.is_empty():
		var res_ent := validate_entrances(template, rect, entrance_points)
		for err in res_ent.errors:
			res_geom.add_error(err)
		for w in res_ent.warnings:
			res_geom.add_warning(w)
	return res_geom

func _determine_side(rect: Rect2i, p: Vector2i) -> StringName:
	var x_min: int = rect.position.x
	var x_max: int = rect.end.x - 1
	var y_min: int = rect.position.y
	var y_max: int = rect.end.y - 1

	var is_top: bool = (p.y == y_min)
	var is_bot: bool = (p.y == y_max)
	var is_left: bool = (p.x == x_min)
	var is_right: bool = (p.x == x_max)

	if (is_top or is_bot) and (is_left or is_right):
		return &"corner"
	if is_top:
		return &"north"
	if is_bot:
		return &"south"
	if is_left:
		return &"west"
	if is_right:
		return &"east"
	return &"unknown"
