class_name RoomShapeGenerator
extends RefCounted

## Generador paramétrico de formas arquitectónicas para interiores de salas.
## Garantiza salas habitables, amplias (>= 70% transitable) y sin deformaciones ciegas.

enum ShapeType {
	OPEN_HALL,          ## Rectángulo completo 100% transitable
	PILLARED_HALL,      ## Rectángulo con columnas simétricas interiores espaciadas
	OCTAGONAL_CHAMBER,  ## Rectángulo con esquinas achaflanadas a 45° (muros en esquinas)
	CRUCIFORM_SANCTUARY ## Cámara cruciforme con esquinas rehundidas
}

static func apply_room_shape(
	grid: CellGrid,
	room: RoomData,
	shape_type: ShapeType,
	rng: RandomNumberGenerator = null
) -> void:
	if grid == null or room == null:
		return

	var rect := room.rect
	var w: int = rect.size.x
	var h: int = rect.size.y

	# Si la sala es pequeña (< 6 en alguna dimensión), aplicar siempre OPEN_HALL para máxima habitabilidad
	if w < 6 or h < 6:
		grid.fill_rect(rect, CellGrid.CellType.FLOOR)
		return

	match shape_type:
		ShapeType.OPEN_HALL:
			grid.fill_rect(rect, CellGrid.CellType.FLOOR)

		ShapeType.PILLARED_HALL:
			grid.fill_rect(rect, CellGrid.CellType.FLOOR)
			# Colocar 2 o 4 columnas simétricas si la sala es suficientemente grande
			if w >= 7 and h >= 7:
				var offset_x: int = 2
				var offset_y: int = 2
				var c1 := rect.position + Vector2i(offset_x, offset_y)
				var c2 := rect.position + Vector2i(w - 1 - offset_x, offset_y)
				var c3 := rect.position + Vector2i(offset_x, h - 1 - offset_y)
				var c4 := rect.position + Vector2i(w - 1 - offset_x, h - 1 - offset_y)

				grid.set_cell(c1, CellGrid.CellType.WALL)
				grid.set_cell(c2, CellGrid.CellType.WALL)
				grid.set_cell(c3, CellGrid.CellType.WALL)
				grid.set_cell(c4, CellGrid.CellType.WALL)

		ShapeType.OCTAGONAL_CHAMBER:
			grid.fill_rect(rect, CellGrid.CellType.FLOOR)
			# Biselar las 4 esquinas exteriores (1 o 2 celdas según tamaño)
			var bevel: int = 1 if (w <= 7 or h <= 7) else 2
			for b in range(bevel):
				# Esquina superior-izquierda
				grid.set_cell(rect.position + Vector2i(b, 0), CellGrid.CellType.WALL)
				grid.set_cell(rect.position + Vector2i(0, b), CellGrid.CellType.WALL)
				# Esquina superior-derecha
				grid.set_cell(rect.position + Vector2i(w - 1 - b, 0), CellGrid.CellType.WALL)
				grid.set_cell(rect.position + Vector2i(w - 1, b), CellGrid.CellType.WALL)
				# Esquina inferior-izquierda
				grid.set_cell(rect.position + Vector2i(0, h - 1 - b), CellGrid.CellType.WALL)
				grid.set_cell(rect.position + Vector2i(b, h - 1), CellGrid.CellType.WALL)
				# Esquina inferior-derecha
				grid.set_cell(rect.position + Vector2i(w - 1 - b, h - 1), CellGrid.CellType.WALL)
				grid.set_cell(rect.position + Vector2i(w - 1, h - 1 - b), CellGrid.CellType.WALL)

		ShapeType.CRUCIFORM_SANCTUARY:
			# Bloquear cuadrantes de esquinas (1 o 2 celdas de recorte)
			grid.fill_rect(rect, CellGrid.CellType.FLOOR)
			var cut: int = 1 if (w <= 7 or h <= 7) else 2
			for cy in range(cut):
				for cx in range(cut):
					grid.set_cell(rect.position + Vector2i(cx, cy), CellGrid.CellType.WALL)
					grid.set_cell(rect.position + Vector2i(w - 1 - cx, cy), CellGrid.CellType.WALL)
					grid.set_cell(rect.position + Vector2i(cx, h - 1 - cy), CellGrid.CellType.WALL)
					grid.set_cell(rect.position + Vector2i(w - 1 - cx, h - 1 - cy), CellGrid.CellType.WALL)

	# Asegurar que el centro de la sala sea siempre suelo
	grid.set_cell(room.get_center(), CellGrid.CellType.FLOOR)
