class_name LabTopBar
extends PanelContainer

signal view_mode_changed(mode: int)
signal copy_ascii_requested()

const _LabColors = preload("res://src/dungeon_generator/debug/lab/ui/lab_colors.gd")

@onready var btn_2d: Button = %Btn2D
@onready var btn_3d: Button = %Btn3D
@onready var btn_ascii: Button = %ExportAsciiBtn
@onready var view_mode_btn: Button = %ViewModeBtn
@onready var status_label: Label = %StatusLabel

var current_view_mode: int = 0 # 0 = 2D, 1 = 3D
var _signals_setup := false

func _ensure_nodes() -> void:
	if btn_2d == null:
		btn_2d = find_child("Btn2D", true, false) as Button
	if btn_3d == null:
		btn_3d = find_child("Btn3D", true, false) as Button
	if btn_ascii == null:
		btn_ascii = find_child("ExportAsciiBtn", true, false) as Button
	if view_mode_btn == null:
		view_mode_btn = find_child("ViewModeBtn", true, false) as Button
	if status_label == null:
		status_label = find_child("StatusLabel", true, false) as Label

func _ready() -> void:
	_ensure_nodes()
	custom_minimum_size = Vector2(0, 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _LabColors.BG_PANEL
	sb.border_color = _LabColors.BORDER
	sb.border_width_bottom = 1
	add_theme_stylebox_override("panel", sb)

	if not _signals_setup:
		_signals_setup = true
		if btn_2d != null:
			btn_2d.pressed.connect(func(): set_view_mode(0))
		if btn_3d != null:
			btn_3d.pressed.connect(func(): set_view_mode(1))
		if btn_ascii != null:
			btn_ascii.pressed.connect(func(): copy_ascii_requested.emit())

	_update_toggle_styles()

func set_view_mode(mode: int) -> void:
	if current_view_mode == mode:
		return
	current_view_mode = mode
	_update_toggle_styles()
	view_mode_changed.emit(mode)

func set_status_text(text: String, is_error: bool = false) -> void:
	if status_label != null:
		status_label.text = text
		status_label.modulate = _LabColors.RED if is_error else _LabColors.TEXT_MUTED

func _update_toggle_styles() -> void:
	if btn_2d == null or btn_3d == null:
		return
	_style_segmented_button(btn_2d, current_view_mode == 0)
	_style_segmented_button(btn_3d, current_view_mode == 1)

func _style_segmented_button(btn: Button, is_active: bool) -> void:
	var sb := StyleBoxFlat.new()
	if is_active:
		sb.bg_color = _LabColors.AMBER
		sb.set_corner_radius_all(3)
		btn.add_theme_color_override("font_color", Color.BLACK)
		btn.add_theme_color_override("font_hover_color", Color.BLACK)
		btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	else:
		sb.bg_color = Color.TRANSPARENT
		btn.add_theme_color_override("font_color", _LabColors.TEXT_MUTED)
		btn.add_theme_color_override("font_hover_color", _LabColors.TEXT_PRIMARY)
		btn.add_theme_color_override("font_pressed_color", _LabColors.TEXT_PRIMARY)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
