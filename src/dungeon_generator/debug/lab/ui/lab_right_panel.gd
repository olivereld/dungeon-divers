class_name LabRightPanel
extends PanelContainer

## Cyber-blueprint styled right inspector panel for DungeonLab.
## Displays generation summary, 2x3 metrics grid, scrollable rooms list,
## and selected room details.

signal room_selected(room_id: int)

const LabColors = preload("res://src/dungeon_generator/debug/lab/ui/lab_colors.gd")

@onready var title_label: Label = %TitleLabel
@onready var status_badge: Label = %StatusBadge
@onready var seed_val_label: Label = %SeedVal
@onready var floors_val_label: Label = %FloorsVal
@onready var algo_val_label: Label = %AlgoVal

# Metrics cards labels
@onready var rooms_val: Label = %RoomsVal
@onready var corridors_val: Label = %CorridorsVal
@onready var doors_val: Label = %DoorsVal
@onready var stairs_val: Label = %StairsVal
@onready var templates_val: Label = %TemplatesVal
@onready var fallbacks_val: Label = %FallbacksVal
@onready var gen_time_val: Label = %GenTimeVal

# Rooms list
@onready var rooms_section_title: Label = %RoomsSectionTitle
@onready var rooms_list_container: VBoxContainer = %RoomsList

# Selected room detail
@onready var room_detail_card: PanelContainer = %RoomDetailCard
@onready var detail_title: Label = %DetailTitle
@onready var detail_type_badge: Label = %DetailTypeBadge
@onready var detail_pos_val: Label = %DetailPosVal
@onready var detail_size_val: Label = %DetailSizeVal
@onready var detail_template_val: Label = %DetailTemplateVal
@onready var detail_status_val: Label = %DetailStatusVal

# Backwards compatibility RichTextLabel
@onready var raw_inspector_text: RichTextLabel = %InspectorText

var _current_selected_room_id: int = -1
var _rooms_cache: Array = []

func _ensure_nodes() -> void:
	if title_label == null:
		title_label = find_child("TitleLabel", true, false) as Label
	if status_badge == null:
		status_badge = find_child("StatusBadge", true, false) as Label
	if seed_val_label == null:
		seed_val_label = find_child("SeedVal", true, false) as Label
	if floors_val_label == null:
		floors_val_label = find_child("FloorsVal", true, false) as Label
	if algo_val_label == null:
		algo_val_label = find_child("AlgoVal", true, false) as Label

	if rooms_val == null:
		rooms_val = find_child("RoomsVal", true, false) as Label
	if corridors_val == null:
		corridors_val = find_child("CorridorsVal", true, false) as Label
	if doors_val == null:
		doors_val = find_child("DoorsVal", true, false) as Label
	if stairs_val == null:
		stairs_val = find_child("StairsVal", true, false) as Label
	if templates_val == null:
		templates_val = find_child("TemplatesVal", true, false) as Label
	if fallbacks_val == null:
		fallbacks_val = find_child("FallbacksVal", true, false) as Label
	if gen_time_val == null:
		gen_time_val = find_child("GenTimeVal", true, false) as Label

	if rooms_section_title == null:
		rooms_section_title = find_child("RoomsSectionTitle", true, false) as Label
	if rooms_list_container == null:
		rooms_list_container = find_child("RoomsList", true, false) as VBoxContainer

	if room_detail_card == null:
		room_detail_card = find_child("RoomDetailCard", true, false) as PanelContainer
	if detail_title == null:
		detail_title = find_child("DetailTitle", true, false) as Label
	if detail_type_badge == null:
		detail_type_badge = find_child("DetailTypeBadge", true, false) as Label
	if detail_pos_val == null:
		detail_pos_val = find_child("DetailPosVal", true, false) as Label
	if detail_size_val == null:
		detail_size_val = find_child("DetailSizeVal", true, false) as Label
	if detail_template_val == null:
		detail_template_val = find_child("DetailTemplateVal", true, false) as Label
	if detail_status_val == null:
		detail_status_val = find_child("DetailStatusVal", true, false) as Label

	if raw_inspector_text == null:
		raw_inspector_text = find_child("InspectorText", true, false) as RichTextLabel

func _enter_tree() -> void:
	_ensure_nodes()

func _ready() -> void:
	_ensure_nodes()
	custom_minimum_size.x = 280
	add_theme_stylebox_override("panel", LabColors.make_flat_panel(LabColors.BG_PANEL, LabColors.BORDER_COLOR, 1, 4))
	_style_cards()
	if room_detail_card != null:
		room_detail_card.visible = false

func _style_cards() -> void:
	_ensure_nodes()
	var summary_card = find_child("SummaryCard", true, false) as PanelContainer
	if summary_card != null:
		summary_card.add_theme_stylebox_override("panel", LabColors.make_card_style(LabColors.BG_CARD, LabColors.BORDER_COLOR, 1, 6))

	for c_name in ["CardRooms", "CardCorridors", "CardDoors", "CardStairs", "CardTemplates", "CardFallbacks", "CardGenTime"]:
		var c = find_child(c_name, true, false)
		if c is PanelContainer:
			c.add_theme_stylebox_override("panel", LabColors.make_card_style(LabColors.BG_CARD, LabColors.BORDER_COLOR, 1, 4))

	if room_detail_card != null:
		room_detail_card.add_theme_stylebox_override("panel", LabColors.make_card_style(LabColors.BG_CARD, LabColors.BORDER_ACCENT, 1, 6))

func update_summary(seed_val: int, floors: int, algo: String, is_valid: bool = true) -> void:
	_ensure_nodes()
	if seed_val_label != null:
		seed_val_label.text = str(seed_val)
	if floors_val_label != null:
		floors_val_label.text = str(floors)
	if algo_val_label != null:
		algo_val_label.text = algo

	if status_badge != null:
		if is_valid:
			status_badge.text = "VALID"
			status_badge.add_theme_color_override("font_color", LabColors.ACCENT_GREEN)
			status_badge.add_theme_stylebox_override("normal", LabColors.make_badge_style(Color(LabColors.ACCENT_GREEN, 0.15), LabColors.ACCENT_GREEN, 1, 3))
		else:
			status_badge.text = "ERROR"
			status_badge.add_theme_color_override("font_color", LabColors.ACCENT_RED)
			status_badge.add_theme_stylebox_override("normal", LabColors.make_badge_style(Color(LabColors.ACCENT_RED, 0.15), LabColors.ACCENT_RED, 1, 3))

func update_metrics(rooms: int, corridors: int, doors: int, stairs: int, templates: int, fallbacks: int, gen_time_ms: float = 0.0) -> void:
	_ensure_nodes()
	if rooms_val != null:
		rooms_val.text = str(rooms)
	if corridors_val != null:
		corridors_val.text = str(corridors)
	if doors_val != null:
		doors_val.text = str(doors)
	if stairs_val != null:
		stairs_val.text = str(stairs)
	if templates_val != null:
		templates_val.text = str(templates)
	if fallbacks_val != null:
		fallbacks_val.text = str(fallbacks)
	if gen_time_val != null:
		if gen_time_ms > 0.0:
			gen_time_val.text = "%.1f ms" % gen_time_ms
		else:
			gen_time_val.text = "< 15 ms"

func populate_rooms(rooms: Array, active_id: int = -1) -> void:
	_ensure_nodes()
	_rooms_cache = rooms
	_current_selected_room_id = active_id
	if rooms_list_container == null:
		return

	# Clear previous list
	for child in rooms_list_container.get_children():
		rooms_list_container.remove_child(child)
		child.queue_free()

	if rooms_section_title != null:
		rooms_section_title.text = "ROOMS (%d)" % rooms.size()

	for room in rooms:
		var r_id: int = room.id if "id" in room else 0
		var r_type: String = str(room.room_type if "room_type" in room else "none")
		var r_rect: Rect2i = room.rect if "rect" in room else Rect2i()
		var r_color: Color = LabColors.get_room_color(r_type)

		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 30
		btn.focus_mode = Control.FOCUS_NONE

		var is_selected := (r_id == _current_selected_room_id)
		var bg_c: Color = Color(LabColors.ACCENT_CYAN, 0.15) if is_selected else LabColors.BG_CARD
		var border_c: Color = LabColors.ACCENT_CYAN if is_selected else LabColors.BORDER_COLOR
		btn.add_theme_stylebox_override("normal", LabColors.make_flat_panel(bg_c, border_c, 1, 4))
		btn.add_theme_stylebox_override("hover", LabColors.make_flat_panel(Color(LabColors.BG_CARD_HOVER), LabColors.ACCENT_CYAN, 1, 4))
		btn.add_theme_stylebox_override("pressed", LabColors.make_flat_panel(Color(LabColors.ACCENT_CYAN, 0.25), LabColors.ACCENT_CYAN, 1, 4))

		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 6
		hbox.offset_right = -6
		hbox.add_theme_constant_override("separation", 8)

		# Color Swatch
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = r_color
		hbox.add_child(swatch)

		# Room Name / ID
		var lbl := Label.new()
		lbl.text = "#%d %s" % [r_id, r_type.capitalize()]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", LabColors.TEXT_MAIN)
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hbox.add_child(lbl)

		# Dimension badge
		var dim_lbl := Label.new()
		dim_lbl.text = "%dx%d" % [r_rect.size.x, r_rect.size.y]
		dim_lbl.add_theme_font_size_override("font_size", 10)
		dim_lbl.add_theme_color_override("font_color", LabColors.TEXT_MUTED)
		hbox.add_child(dim_lbl)

		btn.add_child(hbox)
		btn.pressed.connect(func():
			_on_room_btn_clicked(r_id, room)
		)
		rooms_list_container.add_child(btn)

func _on_room_btn_clicked(r_id: int, room: RefCounted) -> void:
	_current_selected_room_id = r_id
	# Refresh highlights in list
	var idx := 0
	for child in rooms_list_container.get_children():
		if child is Button:
			var item_id: int = _rooms_cache[idx].id if ("id" in _rooms_cache[idx]) else int(_rooms_cache[idx].get("id", -1))
			var is_sel: bool = (idx < _rooms_cache.size() and item_id == _current_selected_room_id)
			var bg_c: Color = Color(LabColors.ACCENT_CYAN, 0.15) if is_sel else LabColors.BG_CARD
			var border_c: Color = LabColors.ACCENT_CYAN if is_sel else LabColors.BORDER_COLOR
			child.add_theme_stylebox_override("normal", LabColors.make_flat_panel(bg_c, border_c, 1, 4))
		idx += 1

	show_room_details({
		"id": r_id,
		"type": str(room.room_type if "room_type" in room else "none"),
		"pos": room.rect.position if "rect" in room else Vector2i.ZERO,
		"size": room.rect.size if "rect" in room else Vector2i.ZERO,
		"template_id": room.custom_data.get("resolved_template_id", "procedural_fallback") if "custom_data" in room else "procedural_fallback",
		"is_fallback": room.custom_data.get("resolved_template_id", "") in ["", "procedural_fallback", "none"] if "custom_data" in room else true,
	})
	room_selected.emit(r_id)

func show_room_details(data: Dictionary) -> void:
	if room_detail_card == null:
		return
	room_detail_card.visible = true

	var r_id: int = data.get("id", 0)
	var r_type: String = str(data.get("type", "none"))
	var r_pos: Vector2i = data.get("pos", Vector2i.ZERO)
	var r_size: Vector2i = data.get("size", Vector2i.ZERO)
	var t_id: String = str(data.get("template_id", "procedural_fallback"))
	var is_fallback: bool = data.get("is_fallback", true)

	if detail_title != null:
		detail_title.text = "ROOM #%d" % r_id
	if detail_type_badge != null:
		detail_type_badge.text = r_type.to_upper()
		var type_color = LabColors.get_room_color(r_type)
		detail_type_badge.add_theme_color_override("font_color", type_color)
		detail_type_badge.add_theme_stylebox_override("normal", LabColors.make_badge_style(Color(type_color, 0.15), type_color, 1, 3))

	if detail_pos_val != null:
		detail_pos_val.text = "(%d, %d)" % [r_pos.x, r_pos.y]
	if detail_size_val != null:
		detail_size_val.text = "%d × %d" % [r_size.x, r_size.y]
	if detail_template_val != null:
		detail_template_val.text = t_id
		detail_template_val.add_theme_color_override("font_color", LabColors.ACCENT_AMBER if is_fallback else LabColors.ACCENT_GREEN)
	if detail_status_val != null:
		detail_status_val.text = "FALLBACK" if is_fallback else "RESOLVED"
		detail_status_val.add_theme_color_override("font_color", LabColors.ACCENT_AMBER if is_fallback else LabColors.ACCENT_GREEN)

func set_raw_bbcode(bbcode: String) -> void:
	if raw_inspector_text != null:
		raw_inspector_text.text = bbcode
