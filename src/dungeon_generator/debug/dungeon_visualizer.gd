class_name DungeonVisualizer
extends Control

## Visualizador de depuración 2D en pantalla (HUD / Overlay) y controles interactivos.
## Renderiza el minimapa del CellGrid, las habitaciones, el grafo de misiones
## y provee barra interactiva para introducir semillas, cambiar cantidad de pisos y aislar pisos individuales.

signal seed_submitted(seed_val: int)
signal random_seed_requested()
signal floors_changed(total_floors: int)
signal floor_view_mode_changed(floor_index: int)

@export var max_minimap_size: float = 180.0     # Tamaño máximo del minimapa en píxeles
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
var _btn_generate: Button = null
var _btn_random: Button = null
var _btn_copy: Button = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_setup_info_panel()
	_setup_seed_controls()

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
	panel.offset_left = -620.0
	panel.offset_right = -20.0
	panel.offset_top = 20.0
	panel.offset_bottom = 68.0
	panel.mouse_filter = MOUSE_FILTER_STOP

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.09, 0.11, 0.16, 0.9)
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
	_spin_floors.tooltip_text = "Cantidad total de pisos a generar (Fase 10 - Multi-Floor)"
	_spin_floors.value_changed.connect(func(v: float):
		floors_changed.emit(int(v))
	)
	_seed_container.add_child(_spin_floors)

	# Selector de visualización de piso individual
	_opt_floor_view = OptionButton.new()
	_opt_floor_view.name = "OptFloorView"
	_opt_floor_view.custom_minimum_size = Vector2(130, 0)
	_opt_floor_view.tooltip_text = "Aislar visualmente un piso específico o ver todos apilados [Teclas 0-9]"
	_opt_floor_view.item_selected.connect(func(idx: int):
		var target_floor: int = _opt_floor_view.get_item_id(idx)
		floor_view_mode_changed.emit(target_floor)
	)
	_seed_container.add_child(_opt_floor_view)
	update_floor_view_options(1)

	_btn_generate = Button.new()
	_btn_generate.text = "Generar"
	_btn_generate.tooltip_text = "Generar mazmorra con estos parámetros [Enter]"
	_btn_generate.pressed.connect(_on_generate_pressed)
	_seed_container.add_child(_btn_generate)

	_btn_random = Button.new()
	_btn_random.text = "🎲"
	_btn_random.tooltip_text = "Semilla aleatoria [R / Espacio]"
	_btn_random.pressed.connect(_on_random_pressed)
	_seed_container.add_child(_btn_random)

	_btn_copy = Button.new()
	_btn_copy.text = "📋"
	_btn_copy.tooltip_text = "Copiar semilla al portapapeles"
	_btn_copy.pressed.connect(_on_copy_pressed)
	_seed_container.add_child(_btn_copy)

	add_child(panel)

## Actualiza las opciones del menú desplegable de pisos.
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
	queue_redraw()
	_update_info_label()

func _update_info_label() -> void:
	if _info_label == null:
		return

	if _last_result == null:
		_info_label.text = "Sin mazmorra generada."
		return

	var text := "=== DUNGEON OVERLAY ===\n"
	text += "Semilla: %d (Floor: %d)\n" % [_last_result.seed_used, _last_result.floor_number]
	text += "Habitaciones: %d | Puertas: %d\n" % [_last_result.rooms.size(), _last_result.door_pairs.size()]
	text += "[WASD] Mover Camara  [Rueda] Zoom\n"
	text += "[Rueda Arrastrar] Orbitar Camara (Izquierda/Derecha)\n"
	text += "[Flechas] Mover Jugador\n"
	text += "[T] Cambiar Vista 3D / Cenital\n"
	text += "[0-9] Aislar Piso  [R] Semilla Aleatoria\n"
	_info_label.text = text
