class_name DungeonVisualizer
extends Control

## Visualizador de depuración 2D en pantalla (HUD / Overlay) y controles interactivos por pasos.
## Paso 1: Muestra el plano 2D completo (habitaciones, pasillos, puertas, arcos).
## Paso 2: Al pulsar "Generar en 3D", oculta el plano 2D y activa la visualización 3D.

signal seed_submitted(seed_val: int)
signal random_seed_requested()
signal floors_changed(total_floors: int)
signal floor_view_mode_changed(floor_index: int)
signal generate_3d_requested()
signal toggle_2d_view_requested()

@export var max_minimap_size: float = 180.0
@export var show_grid: bool = true
@export var show_rooms: bool = true
@export var show_graph: bool = true
@export var show_info_panel: bool = true

var _last_result: DungeonResult = null
var _info_label: Label = null
var _seed_container: HBoxContainer = null
var _seed_line_edit: LineEdit = null
var _spin_floors: SpinBox = null
var _opt_floor_view: OptionButton = null
var _btn_generate_2d: Button = null
var _btn_random: Button = null
var _btn_copy: Button = null
var _btn_toggle_2d_3d: Button = null

# Componentes de la Vista Previa 2D
var _preview_overlay: ColorRect = null
var _preview_canvas: Control = null
var _btn_build_3d: Button = null
var _preview_stats_label: Label = null
var is_2d_preview_mode: bool = true

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_setup_info_panel()
	_setup_seed_controls()
	_setup_2d_preview_panel()

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

func _setup_seed_controls() -> void:
	if _seed_container != null:
		return

	var panel := PanelContainer.new()
	panel.name = "SeedControlPanel"
	panel.anchors_preset = Control.PRESET_TOP_RIGHT
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -700.0
	panel.offset_right = -20.0
	panel.offset_top = 20.0
	panel.offset_bottom = 68.0
	panel.mouse_filter = MOUSE_FILTER_STOP

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.09, 0.11, 0.16, 0.92)
	style_box.border_color = Color(0.35, 0.45, 0.65, 0.9)
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(6)
	style_box.content_margin_left = 10.0
	style_box.content_margin_right = 10.0
	style_box.content_margin_top = 6.0
	style_box.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style_box)

	_seed_container = HBoxContainer.new()
	_seed_container.add_theme_constant_override("separation", 8)
	panel.add_child(_seed_container)

	var label := Label.new()
	label.text = "Semilla:"
	label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98, 1.0))
	_seed_container.add_child(label)

	_seed_line_edit = LineEdit.new()
	_seed_line_edit.placeholder_text = "Semilla..."
	_seed_line_edit.custom_minimum_size = Vector2(95, 0)
	_seed_line_edit.select_all_on_focus = true
	_seed_line_edit.text_submitted.connect(_on_line_edit_submitted)
	_seed_container.add_child(_seed_line_edit)

	var label_floors := Label.new()
	label_floors.text = "Pisos:"
	label_floors.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98, 1.0))
	_seed_container.add_child(label_floors)

	_spin_floors = SpinBox.new()
	_spin_floors.name = "SpinFloors"
	_spin_floors.min_value = 1
	_spin_floors.max_value = 10
	_spin_floors.value = 1
	_spin_floors.tooltip_text = "Cantidad total de pisos a generar"
	_spin_floors.value_changed.connect(func(v: float):
		floors_changed.emit(int(v))
	)
	_seed_container.add_child(_spin_floors)

	# Selector de visualización de piso individual
	_opt_floor_view = OptionButton.new()
	_opt_floor_view.name = "OptFloorView"
	_opt_floor_view.custom_minimum_size = Vector2(120, 0)
	_opt_floor_view.tooltip_text = "Aislar visualmente un piso específico o ver todos apilados"
	_opt_floor_view.item_selected.connect(func(idx: int):
		var target_floor: int = _opt_floor_view.get_item_id(idx)
		floor_view_mode_changed.emit(target_floor)
	)
	_seed_container.add_child(_opt_floor_view)
	update_floor_view_options(1)

	_btn_generate_2d = Button.new()
	_btn_generate_2d.text = "Nuevo Plano"
	_btn_generate_2d.tooltip_text = "Generar nuevo plano 2D con esta semilla [Enter]"
	_btn_generate_2d.pressed.connect(_on_generate_pressed)
	_seed_container.add_child(_btn_generate_2d)

	_btn_random = Button.new()
	_btn_random.text = "🎲"
	_btn_random.tooltip_text = "Semilla aleatoria [R]"
	_btn_random.pressed.connect(_on_random_pressed)
	_seed_container.add_child(_btn_random)

	_btn_copy = Button.new()
	_btn_copy.text = "📋"
	_btn_copy.tooltip_text = "Copiar semilla al portapapeles"
	_btn_copy.pressed.connect(_on_copy_pressed)
	_seed_container.add_child(_btn_copy)

	_btn_toggle_2d_3d = Button.new()
	_btn_toggle_2d_3d.text = "🗺️ Plano 2D"
	_btn_toggle_2d_3d.tooltip_text = "Alternar entre Vista de Plano 2D y Vista 3D [Tab]"
	_btn_toggle_2d_3d.pressed.connect(_on_toggle_2d_3d_pressed)
	_seed_container.add_child(_btn_toggle_2d_3d)

	add_child(panel)

func _setup_2d_preview_panel() -> void:
	if _preview_overlay != null:
		return

	_preview_overlay = ColorRect.new()
	_preview_overlay.name = "Preview2DOverlay"
	_preview_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_preview_overlay.color = Color(0.06, 0.08, 0.12, 0.94)
	_preview_overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(_preview_overlay)

	# Lienzo central para dibujar el mapa
	_preview_canvas = Control.new()
	_preview_canvas.name = "PreviewCanvas"
	_preview_canvas.anchors_preset = Control.PRESET_CENTER
	_preview_canvas.custom_minimum_size = Vector2(700, 600)
	_preview_canvas.draw.connect(_on_preview_canvas_draw)
	_preview_overlay.add_child(_preview_canvas)

	# Barra inferior con botón de acción destacado para generar 3D
	var bottom_panel := PanelContainer.new()
	bottom_panel.anchors_preset = Control.PRESET_CENTER_BOTTOM
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -100.0
	bottom_panel.offset_bottom = -25.0
	bottom_panel.offset_left = -320.0
	bottom_panel.offset_right = 320.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	panel_style.border_color = Color(0.3, 0.7, 0.9, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	bottom_panel.add_theme_stylebox_override("panel", panel_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	bottom_panel.add_child(hbox)

	_btn_build_3d = Button.new()
	_btn_build_3d.text = "🚀 GENERAR MAZMORRA 3D [Espacio / Enter]"
	_btn_build_3d.custom_minimum_size = Vector2(380, 50)
	_btn_build_3d.add_theme_font_size_override("font_size", 16)
	_btn_build_3d.pressed.connect(_on_build_3d_pressed)
	hbox.add_child(_btn_build_3d)

	var btn_new_random := Button.new()
	btn_new_random.text = "🎲 Otra Semilla [R]"
	btn_new_random.custom_minimum_size = Vector2(180, 50)
	btn_new_random.add_theme_font_size_override("font_size", 15)
	btn_new_random.pressed.connect(_on_random_pressed)
	hbox.add_child(btn_new_random)

	_preview_overlay.add_child(bottom_panel)

	# Leyenda de colores superior
	var legend_panel := PanelContainer.new()
	legend_panel.anchors_preset = Control.PRESET_CENTER_TOP
	legend_panel.offset_top = 25.0
	legend_panel.offset_bottom = 65.0
	legend_panel.offset_left = -350.0
	legend_panel.offset_right = 350.0

	var legend_style := StyleBoxFlat.new()
	legend_style.bg_color = Color(0.09, 0.11, 0.16, 0.85)
	legend_style.set_corner_radius_all(8)
	legend_style.content_margin_left = 15.0
	legend_style.content_margin_right = 15.0
	legend_panel.add_theme_stylebox_override("panel", legend_style)

	var legend_label := Label.new()
	legend_label.text = "🟡 Habitación  |  🟢 Pasillo  |  🔴 Puerta  |  🔵 Arco Libre  |  ⬛ Muro"
	legend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	legend_label.add_theme_font_size_override("font_size", 14)
	legend_panel.add_child(legend_label)

	_preview_overlay.add_child(legend_panel)

## Dibuja el mapa 2D en el lienzo central
func _on_preview_canvas_draw() -> void:
	if _last_result == null or _last_result.grid == null or _preview_canvas == null:
		return

	var grid := _last_result.grid
	var gw: int = grid.width
	var gh: int = grid.height
	var canvas_size: Vector2 = _preview_canvas.size
	if canvas_size.x <= 1 or canvas_size.y <= 1:
		canvas_size = Vector2(700, 600)

	var tile_scale: float = minf((canvas_size.x - 40.0) / float(gw), (canvas_size.y - 40.0) / float(gh))
	var origin := Vector2(
		(canvas_size.x - (float(gw) * tile_scale)) * 0.5,
		(canvas_size.y - (float(gh) * tile_scale)) * 0.5
	)

	# 1. Dibujar celdas
	for y in range(gh):
		for x in range(gw):
			var pos := Vector2i(x, y)
			var ctype: int = grid.get_cell(pos)
			var rect := Rect2(origin + Vector2(x, y) * tile_scale, Vector2(tile_scale, tile_scale))

			match ctype:
				CellGrid.CellType.FLOOR:
					_preview_canvas.draw_rect(rect, Color("#f1d240")) # Amarillo
				CellGrid.CellType.CORRIDOR:
					_preview_canvas.draw_rect(rect, Color("#38b861")) # Verde
				CellGrid.CellType.DOOR:
					_preview_canvas.draw_rect(rect, Color("#38b861"))
				CellGrid.CellType.WALL:
					_preview_canvas.draw_rect(rect, Color("#1f242e")) # Muro oscuro
				CellGrid.CellType.COLUMN:
					_preview_canvas.draw_rect(rect, Color("#475569"))
				_:
					_preview_canvas.draw_rect(rect, Color("#0f1218"))

	# 2. Dibujar puertas y arcos sobre las celdas de puerta
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
	if _last_result.door_pairs != null:
		for dp in _last_result.door_pairs:
			if dp == null:
				continue
			_draw_door_marker(dp.door_a, origin, tile_scale, DoorTypeScript)
			_draw_door_marker(dp.door_b, origin, tile_scale, DoorTypeScript)

	# 3. Dibujar etiquetas de salas
	for r in _last_result.rooms:
		if r != null:
			var c_pos = origin + Vector2(r.rect.position.x, r.rect.position.y) * tile_scale
			var r_size = Vector2(r.rect.size.x, r.rect.size.y) * tile_scale
			var r_rect = Rect2(c_pos, r_size)
			_preview_canvas.draw_rect(r_rect, Color(1, 1, 1, 0.4), false, 1.5)

			var text_pos = c_pos + Vector2(4, 14)
			_preview_canvas.draw_string(
				ThemeDB.fallback_font,
				text_pos,
				"%s (#%d)" % [r.room_type.capitalize(), r.id],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				11,
				Color.BLACK
			)

func _draw_door_marker(door, origin: Vector2, tile_scale: float, DoorTypeScript) -> void:
	if door == null or _preview_canvas == null:
		return
	var pos: Vector2i = door.position
	var rect := Rect2(origin + Vector2(pos.x, pos.y) * tile_scale, Vector2(tile_scale, tile_scale))

	var is_open: bool = (door.door_type == DoorTypeScript.DoorType.OPEN_PASSAGE)
	var col: Color = Color("#3b82f6") if is_open else Color("#ef4444") # Azul (Paso) o Rojo (Puerta)

	_preview_canvas.draw_rect(rect, col)
	_preview_canvas.draw_rect(rect, Color.WHITE, false, 1.0)

func show_2d_preview(res: DungeonResult) -> void:
	_last_result = res
	is_2d_preview_mode = true
	if _preview_overlay != null:
		_preview_overlay.visible = true
	if _preview_canvas != null:
		_preview_canvas.queue_redraw()
	if _btn_toggle_2d_3d != null:
		_btn_toggle_2d_3d.text = "🎮 Modo 3D"
	_update_info_label()

func hide_2d_preview() -> void:
	is_2d_preview_mode = false
	if _preview_overlay != null:
		_preview_overlay.visible = false
	if _btn_toggle_2d_3d != null:
		_btn_toggle_2d_3d.text = "🗺️ Plano 2D"
	_update_info_label()

func toggle_2d_preview() -> void:
	if is_2d_preview_mode:
		generate_3d_requested.emit()
	else:
		toggle_2d_view_requested.emit()

func _on_build_3d_pressed() -> void:
	generate_3d_requested.emit()

func _on_toggle_2d_3d_pressed() -> void:
	toggle_2d_preview()

func update_floor_view_options(total_floors: int, selected_floor: int = -1) -> void:
	if _opt_floor_view == null:
		return
	_opt_floor_view.clear()
	_opt_floor_view.add_item("👁️ Todos los Pisos", -1)

	for f in range(total_floors):
		_opt_floor_view.add_item("🏢 Piso %d (%dm)" % [f, f * 6], f)

	var select_idx: int = 0
	if selected_floor >= 0 and selected_floor < total_floors:
		select_idx = selected_floor + 1
	_opt_floor_view.select(select_idx)

func _on_line_edit_submitted(new_text: String) -> void:
	_apply_seed_input(new_text)

func _on_generate_pressed() -> void:
	if _seed_line_edit != null:
		_apply_seed_input(_seed_line_edit.text)

func _apply_seed_input(text: String) -> void:
	var trimmed := text.strip_edges()
	var final_seed: int = 0
	if trimmed.is_valid_int():
		final_seed = int(trimmed)
	elif trimmed != "":
		final_seed = trimmed.hash()
	else:
		random_seed_requested.emit()
		if _seed_line_edit != null:
			_seed_line_edit.text = ""
		return

	seed_submitted.emit(final_seed)

func _on_random_pressed() -> void:
	random_seed_requested.emit()

func _on_copy_pressed() -> void:
	if _last_result != null:
		DisplayServer.clipboard_set(str(_last_result.seed_used))
		_show_temporary_feedback("¡Semilla copiada!")

func _show_temporary_feedback(msg: String) -> void:
	if _btn_copy != null:
		var orig := _btn_copy.text
		_btn_copy.text = "✓"
		get_tree().create_timer(1.0).timeout.connect(func():
			if _btn_copy != null:
				_btn_copy.text = orig
		)

func set_dungeon_result(res: DungeonResult) -> void:
	_last_result = res
	if _seed_line_edit != null and res != null:
		_seed_line_edit.text = str(res.seed_used)
	if _preview_canvas != null:
		_preview_canvas.queue_redraw()
	_update_info_label()

func _update_info_label() -> void:
	if _info_label == null:
		return

	if _last_result == null:
		_info_label.text = "Sin mazmorra generada."
		return

	var mode_str := "VISTA PREVIA 2D" if is_2d_preview_mode else "EXPLORACIÓN 3D"
	var text := "=== MODO: %s ===\n" % mode_str
	text += "Semilla: %d (Piso: %d)\n" % [_last_result.seed_used, _last_result.floor_number]
	text += "Habitaciones: %d | Puertas: %d\n" % [_last_result.rooms.size(), _last_result.door_pairs.size()]
	if is_2d_preview_mode:
		text += "[Espacio / Enter] Generar y Pasar a 3D\n"
		text += "[R] Otra Semilla Aleatoria\n"
	else:
		text += "[Tab] Volver al Plano 2D\n"
		text += "[WASD] Mover Cámara  [Rueda] Zoom\n"
		text += "[Rueda Arrastrar] Orbitar Cámara (Izquierda/Derecha)\n"
		text += "[Flechas] Mover Jugador  [T] Vista Cenital\n"
		text += "[R] Nueva Semilla\n"
	_info_label.text = text
