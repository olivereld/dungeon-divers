class_name RoomPlacer
extends RefCounted

## Ejecutor de colocación espacial de habitaciones.
## Responsabilidad única: Aplica las decisiones contenidas en un RoomPlacementPlan
## sobre las instancias físicas de RoomData.
## No reinterpreta la estrategia ni recalcula posiciones espaciales.

const RoomPlacementPlan = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")

## Aplica las posiciones y metadatos del plan a las habitaciones.
## Retorna el número de habitaciones colocadas con éxito.
func apply_plan(rooms: Array[RoomData], plan: RoomPlacementPlan) -> int:
	if plan == null:
		push_error("[RoomPlacer] Cannot apply null RoomPlacementPlan.")
		return 0

	var placed_count: int = 0
	for room in rooms:
		if room == null:
			continue
		if plan.has_placement(room.id):
			var pos: Vector2i = plan.get_position(room.id)
			room.rect.position = pos
			room.is_placed = true
			
			var reg: StringName = plan.get_region(room.id)
			if reg != &"":
				room.region = reg
			
			placed_count += 1
		else:
			room.is_placed = false

	return placed_count

## Valida que las habitaciones colocadas según el plan no colisionen geométricamente
## utilizando el tamaño real canónico de RoomData.rect.size.
func validate_placement_integrity(rooms: Array[RoomData], margin: int = 0) -> bool:
	for i in range(rooms.size()):
		var r_a := rooms[i]
		if not r_a.is_placed:
			continue
		var rect_a := r_a.expanded(margin) if margin > 0 else r_a.rect
		for j in range(i + 1, rooms.size()):
			var r_b := rooms[j]
			if not r_b.is_placed:
				continue
			var rect_b := r_b.rect
			if rect_a.intersects(rect_b):
				return false
	return true
