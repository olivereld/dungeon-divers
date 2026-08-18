class_name DungeonVisualizer
extends Control

## Visualizador y Generador 2D interactivo a pantalla completa con transición a 3D.
## Provee todos los controles de configuración (semilla, algoritmo, pisos) y dibujo detallado
## del plano (habitaciones, pasillos, puertas, arcos, spawn del jugador y objetivos).

signal seed_submitted(seed_val: int)
signal random_seed_requested()
signal floors_changed(total_floors: int)
signal algorithm_changed(algo_name: String)
signal floor_view_mode_changed(floor_index: int)
signal generate_3d_requested()
signal toggle_2d_view_requested()

var _last_result: DungeonResult = null
var _last_semantic: DungeonSemanticResult = null

# Controles de Configuración en el Plano 2D
var _preview_overlay: ColorRect = null
var _preview_canvas: Control = null
var _seed_line_edit: LineEdit = null
var _opt_algorithm: OptionButton = null
var _spin_floors: SpinBox = null
var _opt_floor_view: OptionButton = null
var _btn_generate_2d: Button = null
var _btn_random: Button = null
var _btn_copy: Button = null
var _btn_build_3d: Button = null
var _btn_back_to_2d: Button = null
var _info_stats_label: RichTextLabel = null
var _hud_3d_panel: PanelContainer = null

var is_2d_preview_mode: bool = true

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_setup_2d_full_interface()
	_setup_3d_hud()

func _setup_2d_full_interface() -> void:
	if _preview_overlay != null:
		return

	# Fondo oscuro inmersivo
	_preview_overlay = ColorRect.new()
	_preview_overlay.name = "Preview2DOverlay"
	_preview_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_preview_overlay.color = Color(0.07, 0.09, 0.13, 0.98)
	_preview_overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(_preview_overlay)

	# --- BARRA SUPERIOR DE OPCIONES DE CREACIÓN 2D ---
	var top_bar := PanelContainer.new()
	top_bar.name = "TopConfigBar"
	top_bar.anchors_preset = Control.PRESET_TOP_WIDE
	top_bar.offset_left = 20.0
	top_bar.offset_right = -20.0
	top_bar.offset_top = 15.0
	top_bar.offset_bottom = 68.0

	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.11, 0.14, 0.20, 0.95)
	top_style.border_color = Color(0.30, 0.42, 0.60, 0.8)
	top_style.set_border_width_all(1)
	top_style.set_corner_radius_all(8)
	top_style.content_margin_left = 15.0
	top_style.content_margin_right = 15.0
	top_style.content_margin_top = 8.0
	top_style.content_margin_bottom = 8.0
	top_bar.add_theme_stylebox_override("panel", top_style)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🏰 PLANO DE MAZMORRA 2D"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.25, 1.0))
	top_hbox.add_child(title_lbl)

	top_hbox.add_child(VSeparator.new())

	# Entrada de Semilla
	var seed_lbl := Label.new()
	seed_lbl.text = "Semilla:"
	seed_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98, 1.0))
	top_hbox.add_child(seed_lbl)

	_seed_line_edit = LineEdit.new()
	_seed_line_edit.placeholder_text = "Semilla..."
	_seed_line_edit.custom_minimum_size = Vector2(110, 0)
	_seed_line_edit.select_all_on_focus = true
	_seed_line_edit.text_submitted.connect(_on_line_edit_submitted)
	top_hbox.add_child(_seed_line_edit)

	_btn_copy = Button.new()
	_btn_copy.text = "📋 Copiar"
	_btn_copy.tooltip_text = "Copiar semilla actual"
	_btn_copy.pressed.connect(_on_copy_pressed)
	top_hbox.add_child(_btn_copy)

	_btn_random = Button.new()
	_btn_random.text = "🎲 Aleatoria [R]"
	_btn_random.tooltip_text = "Generar semilla aleatoria [R]"
	_btn_random.pressed.connect(_on_random_pressed)
	top_hbox.add_child(_btn_random)

	top_hbox.add_child(VSeparator.new())

	# Selector de Algoritmo
	var algo_lbl := Label.new()
	algo_lbl.text = "Algoritmo:"
	algo_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98, 1.0))
	top_hbox.add_child(algo_lbl)

	_opt_algorithm = OptionButton.new()
	_opt_algorithm.name = "OptAlgorithm"
	_opt_algorithm.add_item("Hybrid (Recomendado)", 0)
	_opt_algorithm.add_item("BSP (Arquitectónico)", 1)
	_opt_algorithm.add_item("CellularAutomata (Cuevas)", 2)
	_opt_algorithm.item_selected.connect(_on_algorithm_selected)
	top_hbox.add_child(_opt_algorithm)

	# Selector de Pisos
	var floors_lbl := Label.new()
	floors_lbl.text = "Pisos:"
	floors_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98, 1.0))
	top_hbox.add_child(floors_lbl)

	_spin_floors = SpinBox.new()
	_spin_floors.name = "SpinFloors"
	_spin_floors.min_value = 1
	_spin_floors.max_value = 10
	_spin_floors.value = 1
	_spin_floors.value_changed.connect(func(v: float):
		floors_changed.emit(int(v))
	)
	top_hbox.add_child(_spin_floors)

	# Selector de Vista de Piso 2D
	_opt_floor_view = OptionButton.new()
	_opt_floor_view.name = "OptFloorView"
	_opt_floor_view.tooltip_text = "Piso a visualizar en 2D"
	_opt_floor_view.item_selected.connect(func(idx: int):
		floor_view_mode_changed.emit(_opt_floor_view.get_item_id(idx))
	)
	top_hbox.add_child(_opt_floor_view)
	update_floor_view_options(1)

	_btn_generate_2d = Button.new()
	_btn_generate_2d.text = "🔄 Actualizar Plano"
	_btn_generate_2d.pressed.connect(_on_generate_pressed)
	top_hbox.add_child(_btn_generate_2d)

	_preview_overlay.add_child(top_bar)

	# --- LIENZO CENTRAL DEL PLANO 2D ---
	_preview_canvas = Control.new()
	_preview_canvas.name = "PreviewCanvas"
	_preview_canvas.anchors_preset = Control.PRESET_CENTER
	_preview_canvas.custom_minimum_size = Vector2(760, 600)
	_preview_canvas.draw.connect(_on_preview_canvas_draw)
	_preview_overlay.add_child(_preview_canvas)

	# --- PANEL LATERAL DE ESTADÍSTICAS Y DETALLES ---
	var stats_panel := PanelContainer.new()
	stats_panel.anchors_preset = Control.PRESET_TOP_LEFT
	stats_panel.offset_left = 25.0
	stats_panel.offset_top = 85.0
	stats_panel.offset_right = 260.0
	stats_panel.offset_bottom = 400.0

	var stats_style := StyleBoxFlat.new()
	stats_style.bg_color = Color(0.10, 0.12, 0.18, 0.90)
	stats_style.border_color = Color(0.25, 0.35, 0.50, 0.7)
	stats_style.set_border_width_all(1)
	stats_style.set_corner_radius_all(8)
	stats_style.content_margin_left = 12.0
	stats_style.content_margin_right = 12.0
	stats_style.content_margin_top = 10.0
	stats_style.content_margin_bottom = 10.0
	stats_panel.add_theme_stylebox_override("panel", stats_style)

	_info_stats_label = RichTextLabel.new()
	_info_stats_label.bbcode_enabled = true
	_info_stats_label.fit_content = true
	_info_stats_label.text = "[color=#8899aa]Generando estadísticas...[/color]"
	stats_panel.add_child(_info_stats_label)

	_preview_overlay.add_child(stats_panel)

	# --- LEYENDA VISUAL DE COLORES ---
	var legend_panel := PanelContainer.new()
	legend_panel.anchors_preset = Control.PRESET_CENTER_TOP
	legend_panel.offset_top = 75.0
	legend_panel.offset_bottom = 110.0
	legend_panel.offset_left = -380.0
	legend_panel.offset_right = 380.0

	var legend_style := StyleBoxFlat.new()
	legend_style.bg_color = Color(0.08, 0.10, 0.15, 0.90)
	legend_style.set_corner_radius_all(6)
	legend_style.content_margin_left = 12.0
	legend_style.content_margin_right = 12.0
	legend_style.content_margin_top = 6.0
	legend_style.content_margin_bottom = 6.0
	legend_panel.add_theme_stylebox_override("panel", legend_style)

	var legend_lbl := Label.new()
	legend_lbl.text = "🟡 Habitación  |  🟢 Pasillo  |  🔴 Puerta  |  🔵 Arco Libre  |  🧑 Spawn Jugador  |  💀 Boss"
	legend_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	legend_lbl.add_theme_font_size_override("font_size", 13)
	legend_panel.add_child(legend_lbl)

	_preview_overlay.add_child(legend_panel)

	# --- BARRA INFERIOR CON EL BOTÓN PRINCIPAL PARA GENERAR 3D ---
	var bottom_bar := PanelContainer.new()
	bottom_bar.anchors_preset = Control.PRESET_CENTER_BOTTOM
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -95.0
	bottom_bar.offset_bottom = -25.0
	bottom_bar.offset_left = -330.0
	bottom_bar.offset_right = 330.0

	var bottom_style := StyleBoxFlat.new()
	bottom_style.bg_color = Color(0.12, 0.16, 0.24, 0.98)
	bottom_style.border_color = Color(0.35, 0.75, 0.95, 0.9)
	bottom_style.set_border_width_all(2)
	bottom_style.set_corner_radius_all(10)
	bottom_style.content_margin_left = 18.0
	bottom_style.content_margin_right = 18.0
	bottom_style.content_margin_top = 10.0
	bottom_style.content_margin_bottom = 10.0
	bottom_bar.add_theme_stylebox_override("panel", bottom_style)

	var b_hbox := HBoxContainer.new()
	b_hbox.add_theme_constant_override("separation", 15)
	bottom_bar.add_child(b_hbox)

	_btn_build_3d = Button.new()
	_btn_build_3d.text = "🚀 CARGAR Y VISUALIZAR EN 3D [Espacio / Enter]"
	_btn_build_3d.custom_minimum_size = Vector2(400, 48)
	_btn_build_3d.add_theme_font_size_override("font_size", 15)
	_btn_build_3d.pressed.connect(_on_build_3d_pressed)
	b_hbox.add_child(_btn_build_3d)

	var btn_new_random := Button.new()
	btn_new_random.text = "🎲 Otra Semilla [R]"
	btn_new_random.custom_minimum_size = Vector2(190, 48)
	btn_new_random.add_theme_font_size_override("font_size", 14)
	btn_new_random.pressed.connect(_on_random_pressed)
	b_hbox.add_child(btn_new_random)

	_preview_overlay.add_child(bottom_bar)

func _setup_3d_hud() -> void:
	if _hud_3d_panel != null:
		return

	_hud_3d_panel = PanelContainer.new()
	_hud_3d_panel.name = "HUD3DPanel"
	_hud_3d_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_hud_3d_panel.anchor_left = 1.0
	_hud_3d_panel.anchor_right = 1.0
	_hud_3d_panel.offset_left = -220.0
	_hud_3d_panel.offset_right = -20.0
	_hud_3d_panel.offset_top = 20.0
	_hud_3d_panel.offset_bottom = 68.0
	_hud_3d_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.18, 0.90)
	style.border_color = Color(0.35, 0.45, 0.65, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_hud_3d_panel.add_theme_stylebox_override("panel", style)

	_btn_back_to_2d = Button.new()
	_btn_back_to_2d.text = "🗺️ Volver al Plano 2D [Tab]"
	_btn_back_to_2d.tooltip_text = "Regresar al generador de planos 2D"
	_btn_back_to_2d.pressed.connect(_on_back_to_2d_pressed)
	_hud_3d_panel.add_child(_btn_back_to_2d)

	add_child(_hud_3d_panel)

## Dibuja el mapa 2D detallado
func _on_preview_canvas_draw() -> void:
	if _last_result == null or _last_result.grid == null or _preview_canvas == null:
		return

	var grid := _last_result.grid
	var gw: int = grid.width
	var gh: int = grid.height
	var canvas_size: Vector2 = _preview_canvas.size
	if canvas_size.x <= 1 or canvas_size.y <= 1:
		canvas_size = Vector2(760, 600)

	var tile_scale: float = minf((canvas_size.x - 30.0) / float(gw), (canvas_size.y - 30.0) / float(gh))
	var origin := Vector2(
		(canvas_size.x - (float(gw) * tile_scale)) * 0.5,
		(canvas_size.y - (float(gh) * tile_scale)) * 0.5
	)

	# 1. Dibujar celdas base
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
					_preview_canvas.draw_rect(rect, Color("#181b22")) # Muro oscuro
				CellGrid.CellType.COLUMN:
					_preview_canvas.draw_rect(rect, Color("#475569"))
				_:
					_preview_canvas.draw_rect(rect, Color("#0d1017"))

	# 2. Dibujar puertas y arcos
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
	if _last_result.door_pairs != null:
		for dp in _last_result.door_pairs:
			if dp == null:
				continue
			_draw_door_marker(dp.door_a, origin, tile_scale, DoorTypeScript)
			_draw_door_marker(dp.door_b, origin, tile_scale, DoorTypeScript)

	# 3. Dibujar cajas de habitaciones con bordes y nombres
	for r in _last_result.rooms:
		if r != null:
			var c_pos = origin + Vector2(r.rect.position.x, r.rect.position.y) * tile_scale
			var r_size = Vector2(r.rect.size.x, r.rect.size.y) * tile_scale
			var r_rect = Rect2(c_pos, r_size)
			_preview_canvas.draw_rect(r_rect, Color(1, 1, 1, 0.45), false, 1.5)

			var text_pos = c_pos + Vector2(4, 14)
			_preview_canvas.draw_string(
				ThemeDB.fallback_font,
				text_pos,
				"%s #%d" % [r.room_type.capitalize(), r.id],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				11,
				Color(0.1, 0.1, 0.1, 1.0)
			)

	# 4. Dibujar marcador de SPAWN del jugador y OBJETIVOS
	var spawn_pos := Vector2i.ZERO
	if _last_semantic != null:
		for obj in _last_semantic.objectives:
			if obj.type == ObjectiveData.ObjectiveType.SPAWN:
				spawn_pos = obj.position
				_draw_icon_marker(obj.position, origin, tile_scale, Color("#10b981"), "🧑 SPAWN")
			elif obj.type == ObjectiveData.ObjectiveType.BOSS:
				_draw_icon_marker(obj.position, origin, tile_scale, Color("#ef4444"), "💀 BOSS")
			elif obj.type == ObjectiveData.ObjectiveType.TREASURE:
				_draw_icon_marker(obj.position, origin, tile_scale, Color("#f59e0b"), "🗝️ TESORO")
			elif obj.type == ObjectiveData.ObjectiveType.QUEST_ITEM:
				_draw_icon_marker(obj.position, origin, tile_scale, Color("#f59e0b"), "🗝️ LLAVE")
			elif obj.type == ObjectiveData.ObjectiveType.STAIRS_DOWN or obj.type == ObjectiveData.ObjectiveType.STAIRS_UP:
				_draw_icon_marker(obj.position, origin, tile_scale, Color("#3b82f6"), "🏆 ESCALERAS")

	if spawn_pos == Vector2i.ZERO and not _last_result.rooms.is_empty():
		spawn_pos = _last_result.rooms[0].center
		_draw_icon_marker(spawn_pos, origin, tile_scale, Color("#10b981"), "🧑 SPAWN")

func _draw_icon_marker(grid_pos: Vector2i, origin: Vector2, tile_scale: float, color: Color, label: String) -> void:
	var center_pt = origin + (Vector2(grid_pos.x, grid_pos.y) + Vector2(0.5, 0.5)) * tile_scale
	_preview_canvas.draw_circle(center_pt, tile_scale * 0.9, color)
	_preview_canvas.draw_circle(center_pt, tile_scale * 0.9, Color.WHITE, false, 2.0)
	_preview_canvas.draw_string(
		ThemeDB.fallback_font,
		center_pt + Vector2(-tile_scale * 1.5, -tile_scale * 1.1),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		12,
		Color.WHITE
	)

func _draw_door_marker(door, origin: Vector2, tile_scale: float, DoorTypeScript) -> void:
	if door == null or _preview_canvas == null:
		return
	var pos: Vector2i = door.position
	var rect := Rect2(origin + Vector2(pos.x, pos.y) * tile_scale, Vector2(tile_scale, tile_scale))
	var is_open: bool = (door.door_type == DoorTypeScript.DoorType.OPEN_PASSAGE)
	var col: Color = Color("#3b82f6") if is_open else Color("#ef4444")

	_preview_canvas.draw_rect(rect, col)
	_preview_canvas.draw_rect(rect, Color.WHITE, false, 1.2)

func show_2d_preview(res: DungeonResult, semantic: DungeonSemanticResult = null) -> void:
	_last_result = res
	_last_semantic = semantic
	is_2d_preview_mode = true

	if _preview_overlay != null:
		_preview_overlay.visible = true
	if _hud_3d_panel != null:
		_hud_3d_panel.visible = false
	if _seed_line_edit != null and res != null:
		_seed_line_edit.text = str(res.seed_used)
	if _preview_canvas != null:
		_preview_canvas.queue_redraw()

	_update_stats_panel()

func hide_2d_preview() -> void:
	is_2d_preview_mode = false
	if _preview_overlay != null:
		_preview_overlay.visible = false
	if _hud_3d_panel != null:
		_hud_3d_panel.visible = true

func toggle_2d_preview() -> void:
	if is_2d_preview_mode:
		generate_3d_requested.emit()
	else:
		toggle_2d_view_requested.emit()

func _update_stats_panel() -> void:
	if _info_stats_label == null or _last_result == null:
		return

	var res := _last_result
	var closed_doors: int = 0
	var open_passages: int = 0
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")

	for dp in res.door_pairs:
		if dp.door_a.door_type == DoorTypeScript.DoorType.OPEN_PASSAGE: open_passages += 1
		else: closed_doors += 1
		if dp.door_b.door_type == DoorTypeScript.DoorType.OPEN_PASSAGE: open_passages += 1
		else: closed_doors += 1

	var spawn_pos_str := "N/A"
	if _last_semantic != null:
		for obj in _last_semantic.objectives:
			if obj.type == ObjectiveData.ObjectiveType.SPAWN:
				spawn_pos_str = "(%d, %d)" % [obj.position.x, obj.position.y]
				break

	var bb := "[b][color=#f1d240]DETALLES DE MAZMORRA[/color][/b]\n"
	bb += "----------------------------\n"
	bb += "[b]Semilla:[/b] [color=#60a5fa]%d[/color]\n" % res.seed_used
	bb += "[b]Piso Actual:[/b] %d\n" % res.floor_number
	bb += "[b]Habitaciones:[/b] [color=#34d399]%d[/color]\n" % res.rooms.size()
	bb += "[b]Corredores:[/b] [color=#34d399]%d[/color]\n" % res.corridor_paths.size()
	bb += "[b]Puertas Rojas:[/b] [color=#ef4444]%d[/color]\n" % closed_doors
	bb += "[b]Arcos Azules:[/b] [color=#3b82f6]%d[/color]\n" % open_passages
	bb += "[b]Spawn Jugador:[/b] [color=#10b981]%s[/color]\n" % spawn_pos_str
	bb += "[b]Tiempo Generación:[/b] %.1f ms\n" % res.generation_time_ms
	bb += "----------------------------\n"
	bb += "[color=#94a3b8]Atajos de Teclado:\n"
	bb += "• [Espacio/Enter]: Pasar a 3D\n"
	bb += "• [R]: Otra Semilla\n"
	bb += "• [Tab]: Alternar 2D/3D[/color]"

	_info_stats_label.text = bb

func update_floor_view_options(total_floors: int, selected_floor: int = -1) -> void:
	if _opt_floor_view == null:
		return
	_opt_floor_view.clear()
	_opt_floor_view.add_item("🏢 Todos los Pisos", -1)

	for f in range(total_floors):
		_opt_floor_view.add_item("🏢 Piso %d (%dm)" % [f, f * 6], f)

	var select_idx: int = 0
	if selected_floor >= 0 and selected_floor < total_floors:
		select_idx = selected_floor + 1
	_opt_floor_view.select(select_idx)

func _on_algorithm_selected(idx: int) -> void:
	var algo_names = ["Hybrid", "BSP", "CellularAutomata"]
	if idx >= 0 and idx < algo_names.size():
		algorithm_changed.emit(algo_names[idx])

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
		_show_temporary_feedback("✓ Copiado")

func _show_temporary_feedback(msg: String) -> void:
	if _btn_copy != null:
		var orig := _btn_copy.text
		_btn_copy.text = msg
		get_tree().create_timer(1.2).timeout.connect(func():
			if _btn_copy != null:
				_btn_copy.text = orig
		)

func _on_build_3d_pressed() -> void:
	generate_3d_requested.emit()

func _on_back_to_2d_pressed() -> void:
	toggle_2d_view_requested.emit()
