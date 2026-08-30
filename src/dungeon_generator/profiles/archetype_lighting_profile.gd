class_name ArchetypeLightingProfile
extends RefCounted

## Typed data container for global architectural environment & directional lighting defined in Archetype JSONs.
## 100% pure data: completely independent of node instances and scene trees.

var ambient_enabled: bool = true
var ambient_color: Color = Color(0.08, 0.10, 0.16, 1.0)
var ambient_energy: float = 0.22

var directional_enabled: bool = true
var directional_color: Color = Color(0.67, 0.72, 0.84, 1.0)
var directional_energy: float = 0.40
var directional_shadows: bool = true

var fog_enabled: bool = false
var fog_color: Color = Color(0.06, 0.07, 0.11, 1.0)
var fog_density: float = 0.0

var exposure: float = 1.0
var tonemap: String = "ACES"

func _init(
	p_amb_enabled: bool = true,
	p_amb_color: Color = Color(0.08, 0.10, 0.16, 1.0),
	p_amb_energy: float = 0.22,
	p_dir_enabled: bool = true,
	p_dir_color: Color = Color(0.67, 0.72, 0.84, 1.0),
	p_dir_energy: float = 0.40,
	p_dir_shadows: bool = true,
	p_fog_enabled: bool = false,
	p_fog_color: Color = Color(0.06, 0.07, 0.11, 1.0),
	p_fog_density: float = 0.0,
	p_exposure: float = 1.0,
	p_tonemap: String = "ACES"
) -> void:
	ambient_enabled = p_amb_enabled
	ambient_color = p_amb_color
	ambient_energy = p_amb_energy
	directional_enabled = p_dir_enabled
	directional_color = p_dir_color
	directional_energy = p_dir_energy
	directional_shadows = p_dir_shadows
	fog_enabled = p_fog_enabled
	fog_color = p_fog_color
	fog_density = p_fog_density
	exposure = p_exposure
	tonemap = p_tonemap

static func from_dict(dict: Dictionary) -> ArchetypeLightingProfile:
	if dict.is_empty():
		return ArchetypeLightingProfile.new()

	var amb_raw: Dictionary = dict.get("ambient", {})
	var amb_enabled: bool = bool(amb_raw.get("enabled", true))
	var amb_color: Color = _parse_color(amb_raw.get("color", "#141A29"), Color("#141A29"))
	var amb_energy: float = float(amb_raw.get("energy", 0.22))

	var dir_raw: Dictionary = dict.get("directional", {})
	var dir_enabled: bool = bool(dir_raw.get("enabled", true))
	var dir_color: Color = _parse_color(dir_raw.get("color", "#AAB8D6"), Color("#AAB8D6"))
	var dir_energy: float = float(dir_raw.get("energy", 0.40))
	var dir_shadows: bool = bool(dir_raw.get("shadow_enabled", true))

	var fog_raw: Dictionary = dict.get("fog", {})
	var fog_enabled: bool = bool(fog_raw.get("enabled", false))
	var fog_color: Color = _parse_color(fog_raw.get("color", "#10131C"), Color("#10131C"))
	var fog_density: float = float(fog_raw.get("density", 0.0))

	var atmos_raw: Dictionary = dict.get("atmosphere", {})
	var exposure: float = float(atmos_raw.get("exposure", 1.0))
	var tonemap: String = str(atmos_raw.get("tonemap", "ACES"))

	return ArchetypeLightingProfile.new(
		amb_enabled, amb_color, amb_energy,
		dir_enabled, dir_color, dir_energy, dir_shadows,
		fog_enabled, fog_color, fog_density,
		exposure, tonemap
	)

static func _parse_color(val, default_color: Color) -> Color:
	if val is Color:
		return val
	if val is String and not val.is_empty():
		return Color.from_string(val, default_color)
	return default_color

func to_dict() -> Dictionary:
	return {
		"ambient": {
			"enabled": ambient_enabled,
			"color": "#" + ambient_color.to_html(false),
			"energy": ambient_energy
		},
		"directional": {
			"enabled": directional_enabled,
			"color": "#" + directional_color.to_html(false),
			"energy": directional_energy,
			"shadow_enabled": directional_shadows
		},
		"fog": {
			"enabled": fog_enabled,
			"color": "#" + fog_color.to_html(false),
			"density": fog_density
		},
		"atmosphere": {
			"exposure": exposure,
			"tonemap": tonemap
		}
	}
