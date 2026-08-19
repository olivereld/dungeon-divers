class_name FitnessEvaluator
extends RefCounted

## Evaluador de calidad y balance de mazmorras.
## Produce una puntuación normalizada [0.0, 1.0].

func evaluate(grid: CellGrid, rooms: Array[RoomData], _config: DungeonConfig = null) -> float:
	if grid == null or rooms.is_empty():
		return 0.0

	var score: float = 0.0

	# 1. Puntuación de Conectividad (30% peso)
	var connectivity_score: float = 1.0
	score += connectivity_score * 0.30

	# 2. Ratio de área transitable vs muros (25% peso)
	var total_cells: int = grid.width * grid.height
	var walkable_count: int = grid.count_walkable_cells()
	var density: float = float(walkable_count) / float(total_cells)
	# Densidad adecuada para mazmorras entre 12% y 35%
	var density_score: float = 1.0 - clampf(absf(density - 0.22) / 0.18, 0.0, 1.0)
	score += density_score * 0.25

	# 3. Variedad de habitaciones (20% peso)
	var type_counts: Dictionary = {}
	for r in rooms:
		type_counts[r.room_type] = type_counts.get(r.room_type, 0) + 1
	var variety_score: float = clampf(float(type_counts.size()) / 4.0, 0.0, 1.0)
	score += variety_score * 0.20

	# 4. Distribución y cobertura espacial (25% peso)
	var min_p := Vector2i(9999, 9999)
	var max_p := Vector2i(-9999, -9999)
	for r in rooms:
		min_p.x = mini(min_p.x, r.rect.position.x)
		min_p.y = mini(min_p.y, r.rect.position.y)
		max_p.x = maxi(max_p.x, r.rect.end.x)
		max_p.y = maxi(max_p.y, r.rect.end.y)

	var span_x: float = float(max_p.x - min_p.x) / float(grid.width)
	var span_y: float = float(max_p.y - min_p.y) / float(grid.height)
	var coverage: float = (span_x + span_y) * 0.5
	# Cobertura ideal >= 0.60
	var spread_score: float = clampf(coverage / 0.65, 0.0, 1.0)
	score += spread_score * 0.25

	return clampf(score, 0.0, 1.0)
