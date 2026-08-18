class_name DungeonVisualizer
extends Control

## Visualizador y Generador 2D interactivo a pantalla completa con transición a 3D.
## Estructura de diseño:
## - Panel Izquierdo: Configuración completa, Estadísticas de mazmorra, Leyenda y Botón de Generación 3D.
## - Panel Derecho: Vista amplia y centrada del Plano 2D sin solapamientos.

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
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = MOUSE_FILTER_IGNORE

	_setup_2d_full_interface()
	_setup_3d_hud()

func _setup_2d_full_interface() -> void:
	if _preview_overlay != null:
		return

	# 1. Fondo completo oscuro y elegante
	_preview_overlay = ColorRect.new()
	_preview_overlay.name = "Preview2DOverlay"
	_preview_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_preview_overlay.anchor_right = 1.0
	_preview_overlay.anchor_bottom = 1.0
	_preview_overlay.offset_right = 0.0
	_preview_overlay.offset_bottom = 0.0
	_preview_overlay.color = Color(0.06, 0.08, 0.12, 1.0)
	_preview_overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(_preview_overlay)

	# 2. Margen principal de pantalla completa
	var margin_container := MarginContainer.new()
	margin_container.anchors_preset = Control.PRESET_FULL_RECT
	margin_container.anchor_right = 1.0
	margin_container.anchor_bottom = 1.0
	margin_container.offset_right = 0.0
	margin_container.offset_bottom = 0.0
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	_preview_overlay.add_child(margin_container)

	# 3. Contenedor horizontal: Sidebar Izquierda + Canvas Derecho
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)
	main_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = SIZE_EXPAND_FILL
	margin_container.add_child(main_hbox)

	# ==========================================
	# SIDEBAR IZQUIERDA (Configuración + Estadísticas + Acciones)
	# ==========================================
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(370, 0)
	sidebar.size_flags_vertical = SIZE_EXPAND_FILL

	var sidebar_style := StyleBoxFlat.new()
	sidebar_style.bg_color = Color(0.10, 0.13, 0.18, 0.98)
	sidebar_style.border_color = Color(0.25, 0.35, 0.50, 0.8)
	sidebar_style.set_border_width_all(1)
	sidebar_style.set_corner_radius_all(10)
	sidebar_style.content_margin_left = 18.0
	sidebar_style.content_margin_right = 18.0
	sidebar_style.content_margin_top = 16.0
	sidebar_style.content_margin_bottom = 16.0
	sidebar.add_theme_stylebox_override("panel", sidebar_style)
	main_hbox.add_child(sidebar)

	var scroll_sidebar := ScrollContainer.new()
	scroll_sidebar.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll_sidebar.size_flags_vertical = SIZE_EXPAND_FILL
	sidebar.add_child(scroll_sidebar)

	var sidebar_vbox := VBoxContainer.new()
	sidebar_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	sidebar_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	sidebar_vbox.add_theme_constant_override("separation", 14)
	scroll_sidebar.add_child(sidebar_vbox)

	# Título
	var header_box := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "🏰 DUNGEON GENERATOR"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.30, 1.0))
	header_box.add_child(title_lbl)
	sidebar_vbox.add_child(header_box)

	var sep1 := HSeparator.new()
	sidebar_vbox.add_child(sep1)

	# --- SECCIÓN 1: PARÁMETROS DE GENERACIÓN ---
	var cfg_title := Label.new()
	cfg_title.text = "⚙️ PARÁMETROS"
	cfg_title.add_theme_font_size_override("font_size", 13)
	cfg_title.add_theme_color_override("font_color", Color(0.70, 0.80, 0.95, 1.0))
	sidebar_vbox.add_child(cfg_title)

	# Fila Semilla
	var seed_vbox := VBoxContainer.new()
	seed_vbox.add_theme_constant_override("separation", 6)

	var seed_lbl := Label.new()
	seed_lbl.text = "Semilla Actual:"
	seed_lbl.add_theme_font_size_override("font_size", 12)
	seed_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	seed_vbox.add_child(seed_lbl)

	var seed_input_hbox := HBoxContainer.new()
	seed_input_hbox.add_theme_constant_override("separation", 6)

	_seed_line_edit = LineEdit.new()
	_seed_line_edit.placeholder_text = "Semilla..."
	_seed_line_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_seed_line_edit.select_all_on_focus = true
	_seed_line_edit.text_submitted.connect(_on_line_edit_submitted)
	seed_input_hbox.add_child(_seed_line_edit)

	_btn_copy = Button.new()
	_btn_copy.text = "📋"
	_btn_copy.tooltip_text = "Copiar semilla"
	_btn_copy.pressed.connect(_on_copy_pressed)
	seed_input_hbox.add_child(_btn_copy)

	_btn_random = Button.new()
	_btn_random.text = "🎲 Aleatoria"
	_btn_random.tooltip_text = "Generar semilla aleatoria [R]"
	_btn_random.pressed.connect(_on_random_pressed)
	seed_input_hbox.add_child(_btn_random)

	seed_vbox.add_child(seed_input_hbox)
	sidebar_vbox.add_child(seed_vbox)

	# Fila Algoritmo
	var algo_vbox := VBoxContainer.new()
	algo_vbox.add_theme_constant_override("separation", 4)

	var algo_lbl := Label.new()
	algo_lbl.text = "Algoritmo de Generación:"
	algo_lbl.add_theme_font_size_override("font_size", 12)
	algo_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 1.0))
	algo_vbox.add_child(algo_lbl)

	_opt_algorithm = OptionButton.new()
	_opt_algorithm.add_item("Hybrid (Recomendado)", 0)
	_opt_algorithm.add_item("BSP (Arquitectónico)", 1)
	_opt_algorithm.add_item("CellularAutomata (Cuevas)", 2)
	_opt_algorithm.item_selected.connect(_on_algorithm_selected)
	algo_vbox.add_child(_opt_algorithm)
	sidebar_vbox.add_child(algo_vbox)

	# Fila Pisos
	var floors_hbox := HBoxContainer.new()
	floors_hbox.add_theme_constant_override("separation", 8)

	var floors_lbl := Label.new()
	floors_lbl.text = "Pisos:"
	floors_lbl.add_theme_font_size_override("font_size", 12)
	floors_hbox.add_child(floors_lbl)

	_spin_floors = SpinBox.new()
	_spin_floors.min_value = 1
	_spin_floors.max_value = 10
	_spin_floors.value = 1
	_spin_floors.value_changed.connect(func(v: float):
		floors_changed.emit(int(v))
	)
	floors_hbox.add_child(_spin_floors)

	_opt_floor_view = OptionButton.new()
	_opt_floor_view.size_flags_horizontal = SIZE_EXPAND_FILL
	_opt_floor_view.item_selected.connect(func(idx: int):
		floor_view_mode_changed.emit(_opt_floor_view.get_item_id(idx))
	)
	floors_hbox.add_child(_opt_floor_view)
	update_floor_view_options(1)
	sidebar_vbox.add_child(floors_hbox)

	_btn_generate_2d = Button.new()
	_btn_generate_2d.text = "🔄 Aplicar Semilla / Regenerar"
	_btn_generate_2d.pressed.connect(_on_generate_pressed)
	sidebar_vbox.add_child(_btn_generate_2d)

	var sep2 := HSeparator.new()
	sidebar_vbox.add_child(sep2)

	# --- SECCIÓN 2: ESTADÍSTICAS DEL PLANO ---
	var stats_title := Label.new()
	stats_title.text = "📊 INFORMACIÓN DEL PLANO"
	stats_title.add_theme_font_size_override("font_size", 13)
	stats_title.add_theme_color_override("font_color", Color(0.70, 0.80, 0.95, 1.0))
	sidebar_vbox.add_child(stats_title)

	var stats_panel := PanelContainer.new()
	var stats_box_style := StyleBoxFlat.new()
	stats_box_style.bg_color = Color(0.07, 0.09, 0.13, 0.8)
	stats_box_style.border_color = Color(0.20, 0.28, 0.40, 0.6)
	stats_box_style.set_border_width_all(1)
	stats_box_style.set_corner_radius_all(6)
	stats_box_style.content_margin_left = 10.0
	stats_box_style.content_margin_right = 10.0
	stats_box_style.content_margin_top = 8.0
	stats_box_style.content_margin_bottom = 8.0
	stats_panel.add_theme_stylebox_override("panel", stats_box_style)

	_info_stats_label = RichTextLabel.new()
	_info_stats_label.bbcode_enabled = true
	_info_stats_label.fit_content = true
	_info_stats_label.text = "[color=#8899aa]Calculando...[/color]"
	stats_panel.add_child(_info_stats_label)
	sidebar_vbox.add_child(stats_panel)

	# --- SECCIÓN 3: LEYENDA VISUAL ---
	var legend_title := Label.new()
	legend_title.text = "🗺️ LEYENDA"
	legend_title.add_theme_font_size_override("font_size", 13)
	legend_title.add_theme_color_override("font_color", Color(0.70, 0.80, 0.95, 1.0))
	sidebar_vbox.add_child(legend_title)

	var legend_panel := PanelContainer.new()
	var leg_style := StyleBoxFlat.new()
	leg_style.bg_color = Color(0.07, 0.09, 0.13, 0.8)
	leg_style.set_corner_radius_all(6)
	leg_style.content_margin_left = 10.0
	leg_style.content_margin_right = 10.0
	leg_style.content_margin_top = 8.0
	leg_style.content_margin_bottom = 8.0
	legend_panel.add_theme_stylebox_override("panel", leg_style)

	var leg_lbl := RichTextLabel.new()
	leg_lbl.bbcode_enabled = true
	leg_lbl.fit_content = true
	leg_lbl.text = "[color=#f1d240]■ Habitación[/color]   [color=#38b861]■ Pasillo[/color]\n[color=#ef4444]■ Puerta Roja[/color]   [color=#3b82f6]■ Arco Libre[/color]\n[color=#10b981]● Spawn Jugador[/color]   [color=#ef4444]● Boss[/color]"
	legend_panel.add_child(leg_lbl)
	sidebar_vbox.add_child(legend_panel)

	# Espaciador vertical
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	sidebar_vbox.add_child(spacer)

	# --- BOTÓN DE ACCIÓN DESTACADO ---
	_btn_build_3d = Button.new()
	_btn_build_3d.text = "🚀 GENERAR MAZMORRA 3D\n[ Espacio / Enter ]"
	_btn_build_3d.custom_minimum_size = Vector2(0, 56)
	_btn_build_3d.add_theme_font_size_override("font_size", 15)
	_btn_build_3d.pressed.connect(_on_build_3d_pressed)
	sidebar_vbox.add_child(_btn_build_3d)

	# ==========================================
	# ÁREA PRINCIPAL DERECHA (Canvas 2D Centrado)
	# ==========================================
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = SIZE_EXPAND_FILL

	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	right_style.border_color = Color(0.20, 0.30, 0.45, 0.7)
	right_style.set_border_width_all(1)
	right_style.set_corner_radius_all(10)
	right_style.content_margin_left = 15.0
	right_style.content_margin_right = 15.0
	right_style.content_margin_top = 15.0
	right_style.content_margin_bottom = 15.0
	right_panel.add_theme_stylebox_override("panel", right_style)
	main_hbox.add_child(right_panel)

	_preview_canvas = Control.new()
	_preview_canvas.name = "PreviewCanvas"
	_preview_canvas.size_flags_horizontal = SIZE_EXPAND_FILL
	_preview_canvas.size_flags_vertical = SIZE_EXPAND_FILL
	_preview_canvas.draw.connect(_on_preview_canvas_draw)
	right_panel.add_child(_preview_canvas)

func _setup_3d_hud() -> void:
	if _hud_3d_panel != null:
		return

	_hud_3d_panel = PanelContainer.new()
	_hud_3d_panel.name = "HUD3DPanel"
	_hud_3d_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_hud_3d_panel.anchor_left = 1.0
	_hud_3d_panel.anchor_right = 1.0
	_hud_3d_panel.offset_left = -230.0
	_hud_3d_panel.offset_right = -20.0
	_hud_3d_panel.offset_top = 20.0
	_hud_3d_panel.offset_bottom = 70.0
	_hud_3d_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.18, 0.92)
	style.border_color = Color(0.35, 0.45, 0.65, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_hud_3d_panel.add_theme_stylebox_override("panel", style)

	_btn_back_to_2d = Button.new()
	_btn_back_to_2d.text = "🗺️ Volver al Plano 2D [Tab]"
	_btn_back_to_2d.tooltip_text = "Regresar al generador de planos 2D"
	_btn_back_to_2d.pressed.connect(_on_back_to_2d_pressed)
	_hud_3d_panel.add_child(_btn_back_to_2d)

	add_child(_hud_3d_panel)

## Dibuja el mapa 2D centrado y escalado dentro del área derecha
func _on_preview_canvas_draw() -> void:
	if _last_result == null or _last_result.grid == null or _preview_canvas == null:
		return

	var grid := _last_result.grid
	var gw: int = grid.width
	var gh: int = grid.height
	var canvas_size: Vector2 = _preview_canvas.size
	if canvas_size.x <= 20 or canvas_size.y <= 20:
		return

	var padding: float = 30.0
	var tile_scale: float = minf(
		(canvas_size.x - padding * 2.0) / float(gw),
		(canvas_size.y - padding * 2.0) / float(gh)
	)

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
			_preview_canvas.draw_rect(r_rect, Color(1, 1, 1, 0.40), false, 1.5)

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

	var bb := "• [b]Semilla:[/b] [color=#60a5fa]%d[/color]\n" % res.seed_used
	bb += "• [b]Piso:[/b] %d\n" % res.floor_number
	bb += "• [b]Habitaciones:[/b] [color=#34d399]%d[/color]\n" % res.rooms.size()
	bb += "• [b]Corredores:[/b] [color=#34d399]%d[/color]\n" % res.corridor_paths.size()
	bb += "• [b]Puertas Rojas:[/b] [color=#ef4444]%d[/color]\n" % closed_doors
	bb += "• [b]Arcos Azules:[/b] [color=#3b82f6]%d[/color]\n" % open_passages
	bb += "• [b]Spawn Jugador:[/b] [color=#10b981]%s[/color]\n" % spawn_pos_str
	bb += "• [b]Tiempo Lógico:[/b] %.1f ms" % res.generation_time_ms

	_info_stats_label.text = bb

func update_floor_view_options(total_floors: int, selected_floor: int = -1) -> void:
	if _opt_floor_view == null:
		return
	_opt_floor_view.clear()
	_opt_floor_view.add_item("🏢 Todos", -1)

	for f in range(total_floors):
		_opt_floor_view.add_item("🏢 Piso %d" % f, f)

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
		_show_temporary_feedback("✓")

func _show_temporary_feedback(msg: String) -> void:
	if _btn_copy != null:
		var orig := _btn_copy.text
		_btn_copy.text = msg
		get_tree().create_timer(1.0).timeout.connect(func():
			if _btn_copy != null:
				_btn_copy.text = orig
		)

func _on_build_3d_pressed() -> void:
	generate_3d_requested.emit()

func _on_back_to_2d_pressed() -> void:
	toggle_2d_view_requested.emit()
