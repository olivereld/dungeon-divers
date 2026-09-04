class_name LabViewportToolbar
extends PanelContainer

signal zoom_in_pressed()
signal zoom_out_pressed()
signal frame_pressed()
signal reset_pressed()
signal grid_toggled(enabled: bool)
signal rotate_left_pressed()
signal rotate_right_pressed()

# Aliases
signal zoom_in_requested()
signal zoom_out_requested()
signal frame_requested()
signal reset_view_requested()
signal rotate_left_requested()
signal rotate_right_requested()

const _LabColors = preload("res://src/dungeon_generator/debug/lab/ui/lab_colors.gd")

@onready var btn_zoom_in: Button = %BtnZoomIn
@onready var btn_zoom_out: Button = %BtnZoomOut
@onready var btn_frame: Button = %FrameDungeonBtn
@onready var btn_reset: Button = %BtnReset
@onready var btn_grid: Button = %BtnGrid
@onready var sep_3d: VSeparator = %Sep3D
@onready var btn_rot_left: Button = %RotateLeftBtn
@onready var btn_rot_right: Button = %RotateRightBtn

var is_grid_enabled: bool = true
var is_3d_mode: bool = false
var _signals_setup := false

func _ensure_nodes() -> void:
	if btn_zoom_in == null:
		btn_zoom_in = find_child("BtnZoomIn", true, false) as Button
	if btn_zoom_out == null:
		btn_zoom_out = find_child("BtnZoomOut", true, false) as Button
	if btn_frame == null:
		btn_frame = find_child("FrameDungeonBtn", true, false) as Button
	if btn_reset == null:
		btn_reset = find_child("BtnReset", true, false) as Button
	if btn_grid == null:
		btn_grid = find_child("BtnGrid", true, false) as Button
	if sep_3d == null:
		sep_3d = find_child("Sep3D", true, false) as VSeparator
	if btn_rot_left == null:
		btn_rot_left = find_child("RotateLeftBtn", true, false) as Button
	if btn_rot_right == null:
		btn_rot_right = find_child("RotateRightBtn", true, false) as Button

func _ready() -> void:
	_ensure_nodes()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.92)
	sb.border_color = _LabColors.BORDER_BRIGHT
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	if not _signals_setup:
		_signals_setup = true
		if btn_zoom_in != null:
			btn_zoom_in.pressed.connect(func():
				zoom_in_pressed.emit()
				zoom_in_requested.emit()
			)
		if btn_zoom_out != null:
			btn_zoom_out.pressed.connect(func():
				zoom_out_pressed.emit()
				zoom_out_requested.emit()
			)
		if btn_frame != null:
			btn_frame.pressed.connect(func():
				frame_pressed.emit()
				frame_requested.emit()
			)
		if btn_reset != null:
			btn_reset.pressed.connect(func():
				reset_pressed.emit()
				reset_view_requested.emit()
			)
		if btn_grid != null:
			btn_grid.pressed.connect(func():
				is_grid_enabled = not is_grid_enabled
				_update_grid_btn()
				grid_toggled.emit(is_grid_enabled)
			)
		if btn_rot_left != null:
			btn_rot_left.pressed.connect(func():
				rotate_left_pressed.emit()
				rotate_left_requested.emit()
			)
		if btn_rot_right != null:
			btn_rot_right.pressed.connect(func():
				rotate_right_pressed.emit()
				rotate_right_requested.emit()
			)

	_update_grid_btn()
	set_3d_mode(is_3d_mode)
	set_view_mode(0)

func set_3d_mode(enabled: bool) -> void:
	set_view_mode(1 if enabled else 0)

func set_view_mode(mode: int) -> void:
	is_3d_mode = (mode == 1)
	if sep_3d != null:
		sep_3d.visible = is_3d_mode
	if btn_rot_left != null:
		btn_rot_left.visible = is_3d_mode
	if btn_rot_right != null:
		btn_rot_right.visible = is_3d_mode

func _update_grid_btn() -> void:
	if btn_grid != null:
		btn_grid.modulate = _LabColors.AMBER if is_grid_enabled else _LabColors.TEXT_MUTED
