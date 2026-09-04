class_name LabLoadingOverlay
extends PanelContainer

## Cyber-blueprint styled loading overlay for DungeonLab.
## Displayed during 2D <-> 3D transitions and asynchronous generations.

const _LabColors = preload("res://src/dungeon_generator/debug/lab/ui/lab_colors.gd")

@onready var spinner_label: Label = %SpinnerLabel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var center_card: PanelContainer = %CenterCard

var _spin_angle: float = 0.0

func _ensure_nodes() -> void:
	if spinner_label == null:
		spinner_label = find_child("SpinnerLabel", true, false) as Label
	if title_label == null:
		title_label = find_child("TitleLabel", true, false) as Label
	if subtitle_label == null:
		subtitle_label = find_child("SubtitleLabel", true, false) as Label
	if center_card == null:
		center_card = find_child("CenterCard", true, false) as PanelContainer

func _ready() -> void:
	_ensure_nodes()
	# Full panel dark semi-transparent scrim
	var scrim_sb := StyleBoxFlat.new()
	scrim_sb.bg_color = Color(0.04, 0.05, 0.07, 0.88)
	add_theme_stylebox_override("panel", scrim_sb)

	if center_card != null:
		var card_sb := StyleBoxFlat.new()
		card_sb.bg_color = _LabColors.BG_CARD
		card_sb.border_color = _LabColors.ACCENT_CYAN
		card_sb.set_border_width_all(1)
		card_sb.set_corner_radius_all(8)
		card_sb.shadow_color = Color(0, 0, 0, 0.6)
		card_sb.shadow_size = 12
		card_sb.content_margin_left = 24
		card_sb.content_margin_right = 24
		card_sb.content_margin_top = 16
		card_sb.content_margin_bottom = 16
		center_card.add_theme_stylebox_override("panel", card_sb)

	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_spin_angle += delta * 6.0
	if spinner_label != null:
		var glyphs := ["❖", "✦", "◆", "✦"]
		var idx := int(_spin_angle) % glyphs.size()
		spinner_label.text = glyphs[idx]
		var pulse := 0.7 + 0.3 * sin(_spin_angle * 2.0)
		spinner_label.modulate = Color(0.13, 0.83, 0.93, pulse)

func show_loading(title: String, subtitle: String = "") -> void:
	_ensure_nodes()
	if title_label != null:
		title_label.text = title.to_upper()
	if subtitle_label != null:
		subtitle_label.text = subtitle
		subtitle_label.visible = not subtitle.is_empty()
	z_index = 20
	visible = true
	move_to_front()
	set_process(true)

func hide_loading() -> void:
	visible = false
	set_process(false)
