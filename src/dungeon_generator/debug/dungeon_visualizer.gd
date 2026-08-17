class_name DungeonVisualizer
extends Control

## Visualizador de depuración 2D en pantalla (HUD / Overlay).
## Renderiza el minimapa del CellGrid, las habitaciones y el grafo de misiones
## de forma compacta y ordenada bajo el panel de información.

@export var max_minimap_size: float = 180.0     # Tamaño máximo del minimapa en píxeles
@export var show_grid: bool = true
@export var show_rooms: bool = true
@export var show_graph: bool = true
@export var show_info_panel: bool = true

var _last_result: DungeonResult = null
var _info_label: Label = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_setup_info_panel()

func _setup_info_panel() -> void:
	if _info_label != null:
		return

	_info_label = Label.new()
	_info_label.position = Vector2(20, 20)
	_info_label.add_theme_color_override("font_color", Color.WHITE)
	_info_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_info_label.add_theme_constant_override("shadow_offset_x", 1)
	_info_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_info_label)

func set_dungeon_result(result: DungeonResult) -> void:
	_last_result = result
	_update_info_text()
	queue_redraw()

func _update_info_text() -> void:
	if _info_label == null or _last_result == null:
		return

	var text: String = "=== DUNGEON DIVERS GENERATOR ===\n"
	text += "Seed: %d | Piso: %d\n" % [_last_result.seed_used, _last_result.floor_number]
	text += "Dimensiones: %dx%d | Tiempo: %.2f ms\n" % [_last_result.grid.width, _last_result.grid.height, _last_result.generation_time_ms]
	text += "Habitaciones: %d | Fitness: %.2f\n" % [_last_result.rooms.size(), _last_result.fitness_score]
	text += "Winnable: %s (Largo camino: %d)\n" % [
		str(_last_result.validation.is_winnable),
		_last_result.validation.estimated_length
	]
	text += "Controles: [R/Espacio] Regenerar | [T/V] Vista (Iso/Top) | [F3] HUD | [1/2/3/4] Presets"
	_info_label.text = text

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			visible = not visible
			accept_event()

func _draw() -> void:
	if _last_result == null or not visible:
		return

	var grid: CellGrid = _last_result.grid
	if grid == null:
		return

	# Calcular escala del minimapa para que sea compacto
	var max_dim: float = float(maxi(grid.width, grid.height))
	var effective_cell_size: float = max_minimap_size / max_dim

	# Posicionar justo debajo del texto de información con margen limpio
	var label_height: float = _info_label.get_minimum_size().y if _info_label != null else 140.0
	var origin := Vector2(20, _info_label.position.y + label_height + 10.0)

	var map_width: float = float(grid.width) * effective_cell_size
	var map_height: float = float(grid.height) * effective_cell_size

	# Fondo oscuro semitransparente para el minimapa
	var bg_rect := Rect2(origin.x - 4, origin.y - 4, map_width + 8, map_height + 8)
	draw_rect(bg_rect, Color(0.08, 0.08, 0.12, 0.75), true)

	# 1. Dibujar Rejilla de Celdas (Minimapa compacto)
	if show_grid:
		for y in range(grid.height):
			for x in range(grid.width):
				var pos := Vector2i(x, y)
				var c_type: CellGrid.CellType = grid.get_cell(pos)
				if c_type == CellGrid.CellType.WALL:
					continue # No dibujar muros de fondo para mantenerlo limpio

				var color := _get_cell_color(c_type)
				var rect := Rect2(origin.x + x * effective_cell_size, origin.y + y * effective_cell_size, effective_cell_size, effective_cell_size)
				draw_rect(rect, color, true)

		# Borde exterior del grid
		draw_rect(Rect2(origin.x, origin.y, map_width, map_height), Color(1, 1, 1, 0.3), false, 1.0)

	# 2. Dibujar Habitaciones
	if show_rooms and not _last_result.rooms.is_empty():
		for room in _last_result.rooms:
			var r_rect := Rect2(
				origin.x + room.rect.position.x * effective_cell_size,
				origin.y + room.rect.position.y * effective_cell_size,
				room.rect.size.x * effective_cell_size,
				room.rect.size.y * effective_cell_size
			)
			draw_rect(r_rect, Color(0.2, 0.8, 1.0, 0.35), false, 1.0)

	# 3. Dibujar Conexiones del Grafo
	if show_graph and not _last_result.rooms.is_empty():
		for room in _last_result.rooms:
			var start_pt := origin + Vector2(room.get_center()) * effective_cell_size
			for target_id in room.connected_room_ids:
				if target_id >= 0 and target_id < _last_result.rooms.size():
					var target_room: RoomData = _last_result.rooms[target_id]
					var end_pt := origin + Vector2(target_room.get_center()) * effective_cell_size
					draw_line(start_pt, end_pt, Color(1.0, 0.9, 0.2, 0.6), 1.0)

func _get_cell_color(type: CellGrid.CellType) -> Color:
	match type:
		CellGrid.CellType.FLOOR:
			return Color("#d1d1d6")
		CellGrid.CellType.CORRIDOR:
			return Color("#a0a0a8")
		CellGrid.CellType.DOOR:
			return Color("#8b5e3c")
		CellGrid.CellType.LOCKED_DOOR:
			return Color("#e74c3c")
		CellGrid.CellType.SPAWN:
			return Color("#2ecc71")
		CellGrid.CellType.OBJECTIVE:
			return Color("#f1c40f")
		CellGrid.CellType.STAIRS_DOWN, CellGrid.CellType.STAIRS_UP:
			return Color("#3498db")
		_:
			return Color("#222228")
