class_name RockSizeConfig
extends RefCounted

## Configuración detallada para una categoría de tamaño de roca (Large, Medium, Small).
## Contiene parámetros de geometría, silueta, deformación y variación de instancia.

enum Category {
	LARGE = 0,
	MEDIUM = 1,
	SMALL = 2
}

var category: int = Category.MEDIUM
var category_name: String = "medium"

# --- GEOMETRÍA BASE ---
var num_variants: int = 4
var rings: int = 4
var segments: int = 8
var height_ratio: float = 1.0
var base_penetration: float = 0.25
var irregularity: float = 0.55

# --- SILUETA Y PERFIL ---
var base_radius_factor: float = 0.85
var body_bulge_factor: float = 1.15
var taper_power: float = 0.75
var peak_convergence_min: float = 0.15
var peak_convergence_max: float = 0.30
var apex_elevation_min: float = 0.10
var apex_elevation_max: float = 0.25

# --- DEFORMACIÓN ---
var radial_jitter: float = 0.60
var vertical_jitter: float = 0.35
var top_ring_y_jitter: float = 0.30
var mass_offset_strength: float = 0.20
var diagonal_alternation: bool = true

# --- VARIACIÓN DE INSTANCIA ---
var min_scale: float = 0.75
var max_scale: float = 1.10
var scale_x_range: Vector2 = Vector2(0.85, 1.20)
var scale_y_range: Vector2 = Vector2(0.85, 1.20)
var scale_z_range: Vector2 = Vector2(0.85, 1.20)
var max_tilt_degrees: float = 8.0
var slope_tilt_factor: float = 4.0

func to_dict() -> Dictionary:
	return {
		"category": category,
		"category_name": category_name,
		"geometry": {
			"num_variants": num_variants,
			"rings": rings,
			"segments": segments,
			"height_ratio": height_ratio,
			"base_penetration": base_penetration,
			"irregularity": irregularity
		},
		"silhouette": {
			"base_radius_factor": base_radius_factor,
			"body_bulge_factor": body_bulge_factor,
			"taper_power": taper_power,
			"peak_convergence_min": peak_convergence_min,
			"peak_convergence_max": peak_convergence_max,
			"apex_elevation_min": apex_elevation_min,
			"apex_elevation_max": apex_elevation_max
		},
		"deformation": {
			"radial_jitter": radial_jitter,
			"vertical_jitter": vertical_jitter,
			"top_ring_y_jitter": top_ring_y_jitter,
			"mass_offset_strength": mass_offset_strength,
			"diagonal_alternation": diagonal_alternation
		},
		"variation": {
			"min_scale": min_scale,
			"max_scale": max_scale,
			"scale_x_range": [scale_x_range.x, scale_x_range.y],
			"scale_y_range": [scale_y_range.x, scale_y_range.y],
			"scale_z_range": [scale_z_range.x, scale_z_range.y],
			"max_tilt_degrees": max_tilt_degrees,
			"slope_tilt_factor": slope_tilt_factor
		}
	}

func from_dict(d: Dictionary) -> void:
	if d.has("category"):
		category = int(d["category"])
	if d.has("category_name"):
		category_name = str(d["category_name"])

	if d.has("geometry") and d["geometry"] is Dictionary:
		var g: Dictionary = d["geometry"]
		num_variants = int(g.get("num_variants", num_variants))
		rings = int(g.get("rings", rings))
		segments = int(g.get("segments", segments))
		height_ratio = float(g.get("height_ratio", height_ratio))
		base_penetration = float(g.get("base_penetration", base_penetration))
		irregularity = float(g.get("irregularity", irregularity))

	if d.has("silhouette") and d["silhouette"] is Dictionary:
		var s: Dictionary = d["silhouette"]
		base_radius_factor = float(s.get("base_radius_factor", base_radius_factor))
		body_bulge_factor = float(s.get("body_bulge_factor", body_bulge_factor))
		taper_power = float(s.get("taper_power", taper_power))
		peak_convergence_min = float(s.get("peak_convergence_min", peak_convergence_min))
		peak_convergence_max = float(s.get("peak_convergence_max", peak_convergence_max))
		apex_elevation_min = float(s.get("apex_elevation_min", apex_elevation_min))
		apex_elevation_max = float(s.get("apex_elevation_max", apex_elevation_max))

	if d.has("deformation") and d["deformation"] is Dictionary:
		var df: Dictionary = d["deformation"]
		radial_jitter = float(df.get("radial_jitter", radial_jitter))
		vertical_jitter = float(df.get("vertical_jitter", vertical_jitter))
		top_ring_y_jitter = float(df.get("top_ring_y_jitter", top_ring_y_jitter))
		mass_offset_strength = float(df.get("mass_offset_strength", mass_offset_strength))
		diagonal_alternation = bool(df.get("diagonal_alternation", diagonal_alternation))

	if d.has("variation") and d["variation"] is Dictionary:
		var v: Dictionary = d["variation"]
		min_scale = float(v.get("min_scale", min_scale))
		max_scale = float(v.get("max_scale", max_scale))
		if v.has("scale_x_range") and v["scale_x_range"] is Array and v["scale_x_range"].size() >= 2:
			scale_x_range = Vector2(v["scale_x_range"][0], v["scale_x_range"][1])
		if v.has("scale_y_range") and v["scale_y_range"] is Array and v["scale_y_range"].size() >= 2:
			scale_y_range = Vector2(v["scale_y_range"][0], v["scale_y_range"][1])
		if v.has("scale_z_range") and v["scale_z_range"] is Array and v["scale_z_range"].size() >= 2:
			scale_z_range = Vector2(v["scale_z_range"][0], v["scale_z_range"][1])
		max_tilt_degrees = float(v.get("max_tilt_degrees", max_tilt_degrees))
		slope_tilt_factor = float(v.get("slope_tilt_factor", slope_tilt_factor))

func clone():
	var copy = get_script().new()
	copy.from_dict(to_dict())
	return copy

static func create_large():
	var cfg = new()
	cfg.category = Category.LARGE
	cfg.category_name = "large"
	cfg.num_variants = 3
	cfg.rings = 5
	cfg.segments = 9
	cfg.height_ratio = 1.10
	cfg.base_penetration = 0.35
	cfg.irregularity = 0.75
	cfg.base_radius_factor = 0.85
	cfg.body_bulge_factor = 1.15
	cfg.taper_power = 0.75
	cfg.peak_convergence_min = 0.15
	cfg.peak_convergence_max = 0.30
	cfg.apex_elevation_min = 0.10
	cfg.apex_elevation_max = 0.25
	cfg.radial_jitter = 0.60
	cfg.vertical_jitter = 0.35
	cfg.top_ring_y_jitter = 0.30
	cfg.mass_offset_strength = 0.20
	cfg.min_scale = 1.30
	cfg.max_scale = 1.70
	cfg.scale_x_range = Vector2(0.85, 1.20)
	cfg.scale_y_range = Vector2(0.85, 1.20)
	cfg.scale_z_range = Vector2(0.85, 1.20)
	cfg.max_tilt_degrees = 8.0
	cfg.slope_tilt_factor = 4.0
	return cfg

static func create_medium():
	var cfg = new()
	cfg.category = Category.MEDIUM
	cfg.category_name = "medium"
	cfg.num_variants = 4
	cfg.rings = 4
	cfg.segments = 8
	cfg.height_ratio = 0.95
	cfg.base_penetration = 0.25
	cfg.irregularity = 0.55
	cfg.base_radius_factor = 0.85
	cfg.body_bulge_factor = 1.10
	cfg.taper_power = 0.75
	cfg.peak_convergence_min = 0.15
	cfg.peak_convergence_max = 0.30
	cfg.apex_elevation_min = 0.10
	cfg.apex_elevation_max = 0.25
	cfg.radial_jitter = 0.55
	cfg.vertical_jitter = 0.35
	cfg.top_ring_y_jitter = 0.30
	cfg.mass_offset_strength = 0.15
	cfg.min_scale = 0.75
	cfg.max_scale = 1.10
	cfg.scale_x_range = Vector2(0.85, 1.20)
	cfg.scale_y_range = Vector2(0.75, 1.18)
	cfg.scale_z_range = Vector2(0.85, 1.20)
	cfg.max_tilt_degrees = 8.0
	cfg.slope_tilt_factor = 4.0
	return cfg

static func create_small():
	var cfg = new()
	cfg.category = Category.SMALL
	cfg.category_name = "small"
	cfg.num_variants = 4
	cfg.rings = 3
	cfg.segments = 7
	cfg.height_ratio = 0.75
	cfg.base_penetration = 0.20
	cfg.irregularity = 0.40
	cfg.base_radius_factor = 0.85
	cfg.body_bulge_factor = 1.05
	cfg.taper_power = 0.70
	cfg.peak_convergence_min = 0.15
	cfg.peak_convergence_max = 0.30
	cfg.apex_elevation_min = 0.08
	cfg.apex_elevation_max = 0.20
	cfg.radial_jitter = 0.45
	cfg.vertical_jitter = 0.30
	cfg.top_ring_y_jitter = 0.25
	cfg.mass_offset_strength = 0.10
	cfg.min_scale = 0.25
	cfg.max_scale = 0.50
	cfg.scale_x_range = Vector2(0.85, 1.20)
	cfg.scale_y_range = Vector2(0.70, 1.15)
	cfg.scale_z_range = Vector2(0.85, 1.20)
	cfg.max_tilt_degrees = 10.0
	cfg.slope_tilt_factor = 4.0
	return cfg
