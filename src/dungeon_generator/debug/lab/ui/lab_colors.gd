class_name LabColors
extends RefCounted

## Paleta cromática canónica para DungeonLab adaptada del prototipo web.

# Fondos y bordes
const BG_BASE := Color("#0a0c10")
const BG_DARK := BG_BASE
const BG_PANEL := Color("#111318")
const BG_CARD := Color("#161a22")
const BG_HOVER := Color("#1c2030")
const BG_CARD_HOVER := BG_HOVER
const BG_ACTIVE := Color("#232840")
const BORDER := Color("#232840")
const BORDER_COLOR := BORDER
const BORDER_BRIGHT := Color("#2e3650")
const BORDER_ACCENT := BORDER_BRIGHT

# Textos
const TEXT_PRIMARY := Color("#e2e8f0")
const TEXT_MAIN := TEXT_PRIMARY
const TEXT_SECONDARY := Color("#8892aa")
const TEXT_MUTED := Color("#4a5468")

# Acentos
const AMBER := Color("#f59e0b")
const ACCENT_AMBER := AMBER
const AMBER_DIM := Color("#92600a")
const CYAN := Color("#22d3ee")
const ACCENT_CYAN := CYAN
const BLUE := Color("#60a5fa")
const BLUE_DIM := Color("#1d4ed8")
const GREEN := Color("#22c55e")
const ACCENT_GREEN := GREEN
const GREEN_DIM := Color("#166534")
const RED := Color("#f87171")
const ACCENT_RED := RED
const RED_DIM := Color("#7f1d1d")
const PURPLE := Color("#a78bfa")
const INDIGO := Color("#818cf8")
const VIOLET := Color("#c084fc")
const SLATE := Color("#475569")

# Cuadrícula blueprint
const GRID_BG := Color("#0d1018")
const GRID_LINE := Color(0.13, 0.19, 0.31, 0.2)
const GRID_LINE_MAJOR := Color(0.18, 0.25, 0.40, 0.35)

# Mapeo de colores por tipo de sala
const ROOM_TYPE_COLORS: Dictionary = {
	"entrance": AMBER,
	"boss": RED,
	"checkpoint": GREEN,
	"crypt": PURPLE,
	"catacomb": BLUE,
	"sacristy": INDIGO,
	"royal_tomb": VIOLET,
	"combat": BLUE,
	"explore": INDIGO,
	"puzzle": VIOLET,
	"treasure": AMBER,
	"goal": GREEN,
	"none": SLATE,
	"procedural_fallback": Color("#334155")
}

static func get_room_stroke_color(room_type: String) -> Color:
	var key := room_type.to_lower()
	return ROOM_TYPE_COLORS.get(key, SLATE)

static func get_room_color(room_type: String) -> Color:
	return get_room_stroke_color(room_type)

static func get_room_fill_color(room_type: String) -> Color:
	var stroke := get_room_stroke_color(room_type)
	return Color(stroke.r, stroke.g, stroke.b, 0.08)

static func create_panel_stylebox(bg_color: Color = BG_PANEL, border_color: Color = BORDER, radius: int = 4, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

static func make_flat_panel(bg: Color = BG_PANEL, border: Color = BORDER, border_w: int = 1, radius: int = 4) -> StyleBoxFlat:
	return create_panel_stylebox(bg, border, radius, border_w)

static func make_card_style(bg: Color = BG_CARD, border: Color = BORDER, border_w: int = 1, radius: int = 6) -> StyleBoxFlat:
	return create_panel_stylebox(bg, border, radius, border_w)

static func make_badge_style(bg: Color, border: Color, border_w: int = 1, radius: int = 3) -> StyleBoxFlat:
	var sb := create_panel_stylebox(bg, border, radius, border_w)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb

static func create_btn_stylebox(bg_color: Color, border_color: Color = BORDER, radius: int = 4, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb
