class_name RoomSpatialSeparator
extends RefCounted

## Separador espacial determinista de habitaciones (Fase 6).
## Garantiza que todas las habitaciones tengan al menos `min_padding` celdas de separación,
## estén completamente contenidas en los límites (`bounds`) y se procesen en orden estricto `room_id ascending`.

const MAX_ITERATIONS: int = 300
const DEFAULT_PADDING: int = 2

## Valida que ninguna habitación se solape, que todas respeten el padding mínimo y queden dentro de bounds.
static func validate_separation(rooms: Array[RoomData], bounds: Rect2i, min_padding: int = DEFAULT_PADDING) -> Dictionary:
	var overlaps: Array[Dictionary] = []
	var out_of_bounds: Array[int] = []

	# Orden canónico por room_id
	var sorted_rooms: Array[RoomData] = rooms.duplicate()
	sorted_rooms.sort_custom(func(a: RoomData, b: RoomData) -> bool:
		return a.id < b.id
	)

	for i in range(sorted_rooms.size()):
		var r_a := sorted_rooms[i]
		if not bounds.encloses(r_a.rect):
			out_of_bounds.append(r_a.id)

		for j in range(i + 1, sorted_rooms.size()):
			var r_b := sorted_rooms[j]
			var expanded_b := r_b.expanded(min_padding)
			if r_a.rect.intersects(expanded_b):
				overlaps.append({
					"room_a": r_a.id,
					"room_b": r_b.id,
					"rect_a": r_a.rect,
					"rect_b": r_b.rect
				})

	return {
		"is_valid": overlaps.is_empty() and out_of_bounds.is_empty(),
		"overlaps": overlaps,
		"out_of_bounds": out_of_bounds
	}

## Resuelve y separa habitaciones solapadas de manera determinista.
static func separate_rooms(
	rooms: Array[RoomData],
	bounds: Rect2i,
	rng: RandomNumberGenerator,
	min_padding: int = DEFAULT_PADDING,
	max_iterations: int = MAX_ITERATIONS
) -> Array[RoomData]:
	if rooms.size() <= 1:
		return rooms

	var val := validate_separation(rooms, bounds, min_padding)
	if val["is_valid"]:
		return rooms

	# Procesamiento determinista en orden room_id ascending
	var sorted_rooms: Array[RoomData] = rooms.duplicate()
	sorted_rooms.sort_custom(func(a: RoomData, b: RoomData) -> bool:
		return a.id < b.id
	)

	for iter in range(max_iterations):
		var has_collision := false

		for i in range(sorted_rooms.size()):
			var r_a := sorted_rooms[i]

			# Asegurar que r_a esté dentro de bounds
			if not bounds.encloses(r_a.rect):
				r_a.rect.position.x = clampi(r_a.rect.position.x, bounds.position.x, bounds.end.x - r_a.rect.size.x)
				r_a.rect.position.y = clampi(r_a.rect.position.y, bounds.position.y, bounds.end.y - r_a.rect.size.y)
				has_collision = true

			for j in range(i + 1, sorted_rooms.size()):
				var r_b := sorted_rooms[j]
				var exp_b := r_b.expanded(min_padding)

				if r_a.rect.intersects(exp_b):
					has_collision = true
					# Empujar r_b en dirección opuesta a r_a
					var delta: Vector2 = Vector2(r_b.get_center() - r_a.get_center())
					if delta.length_squared() < 0.001:
						var angle := rng.randf_range(0.0, TAU)
						delta = Vector2(cos(angle), sin(angle))
					else:
						delta = delta.normalized()

					var push_dist: int = maxi(1, min_padding)
					var new_pos_b := r_b.rect.position + Vector2i(int(round(delta.x * push_dist)), int(round(delta.y * push_dist)))

					# Clamp a bounds
					new_pos_b.x = clampi(new_pos_b.x, bounds.position.x, bounds.end.x - r_b.rect.size.x)
					new_pos_b.y = clampi(new_pos_b.y, bounds.position.y, bounds.end.y - r_b.rect.size.y)
					r_b.rect.position = new_pos_b

		if not has_collision:
			break

	# Validación post-separación
	var post_val := validate_separation(sorted_rooms, bounds, min_padding)
	if post_val["is_valid"]:
		return sorted_rooms

	# Si aún quedan colisiones tras max_iterations, podar salas opcionales o reubicar requeridas
	var filtered_rooms: Array[RoomData] = []
	for r in sorted_rooms:
		var collides_with_accepted := false
		for acc in filtered_rooms:
			if r.rect.intersects(acc.expanded(min_padding)):
				collides_with_accepted = true
				break

		if not collides_with_accepted:
			filtered_rooms.append(r)
		elif r.is_required or r.room_type == &"boss" or r.room_type == &"start" or r.room_type == &"goal":
			# Para salas obligatorias (especialmente boss, start, goal), buscar un hueco libre en bounds
			var placed := false

			# 1. Búsqueda aleatoria inicial
			for _att in range(50):
				var rx: int = rng.randi_range(bounds.position.x, bounds.end.x - r.rect.size.x)
				var ry: int = rng.randi_range(bounds.position.y, bounds.end.y - r.rect.size.y)
				var cand := Rect2i(rx, ry, r.rect.size.x, r.rect.size.y)
				var col := false
				for acc in filtered_rooms:
					if cand.intersects(acc.expanded(min_padding)):
						col = true
						break
				if not col:
					r.rect = cand
					filtered_rooms.append(r)
					placed = true
					break

			# 2. Búsqueda exhaustiva con reducción progresiva de tamaño y relajación de padding
			if not placed:
				var min_w: int = 5 if (bounds.size.x <= 32 or bounds.size.y <= 32) else 6
				var min_h: int = 5 if (bounds.size.x <= 32 or bounds.size.y <= 32) else 6
				var orig_w: int = r.rect.size.x
				var orig_h: int = r.rect.size.y
				
				for try_size in [
					Vector2i(orig_w, orig_h),
					Vector2i(maxi(min_w, orig_w - 2), maxi(min_h, orig_h - 2)),
					Vector2i(min_w, min_h),
					Vector2i(4, 4)
				]:
					if placed:
						break
					for pad in [min_padding, 1, 0]:
						if placed:
							break
						for y in range(bounds.position.y, bounds.end.y - try_size.y + 1):
							for x in range(bounds.position.x, bounds.end.x - try_size.x + 1):
								var cand := Rect2i(x, y, try_size.x, try_size.y)
								var col := false
								for acc in filtered_rooms:
									if pad > 0:
										if cand.intersects(acc.expanded(pad)):
											col = true
											break
									else:
										if cand.intersects(acc.rect):
											col = true
											break
								if not col:
									r.rect = cand
									filtered_rooms.append(r)
									placed = true
									break
							if placed:
								break

	return filtered_rooms
