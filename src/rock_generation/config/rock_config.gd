class_name RockConfig
extends RefCounted

## Contrato de configuración integral de generación de rocas para un bioma.
## Controla distribución, clustering, siluetas/geometría por tamaño y propiedades de sombreado.
## Soporta serialización bidireccional completa a JSON.

const RockSizeConfig = preload("res://src/rock_generation/config/rock_size_config.gd")

var version: int = 1
var biome: String = "taiga"

# --- DISTRIBUCIÓN GLOBAL ---
var distribution: Dictionary = {
	"density": 0.15,
	"min_slope_degrees": 15.0,
	"max_slope_degrees": 55.0,
	"category_weights": {
		"large": 0.20,
		"medium": 0.45,
		"small": 0.35
	}
}

# --- CLUSTERS Y SATÉLITES ---
var clustering: Dictionary = {
	"large": {
		"enabled": true,
		"probability": 0.65,
		"min_satellites": 2,
		"max_satellites": 3,
		"min_distance_mult": 0.8,
		"max_distance_mult": 1.6,
		"satellite_profiles": [
			{ "category": "medium", "weight": 0.35, "scale_min": 0.70, "scale_max": 0.95 },
			{ "category": "small", "weight": 0.65, "scale_min": 0.20, "scale_max": 0.40 }
		]
	},
	"medium": {
		"enabled": true,
		"probability": 0.40,
		"min_satellites": 1,
		"max_satellites": 1,
		"min_distance_mult": 0.6,
		"max_distance_mult": 1.2,
		"satellite_profiles": [
			{ "category": "small", "weight": 1.0, "scale_min": 0.18, "scale_max": 0.35 }
		]
	},
	"small": {
		"enabled": false,
		"probability": 0.0,
		"min_satellites": 0,
		"max_satellites": 0,
		"min_distance_mult": 0.0,
		"max_distance_mult": 0.0,
		"satellite_profiles": []
	}
}

# --- PERFILES POR TAMAÑO ---
var profiles: Dictionary = {} # int (RockSizeConfig.Category) -> RockSizeConfig

# --- MATERIAL Y SHADING ---
var material: Dictionary = {
	"palette_texture": "",
	"normal_weight": 0.55,
	"height_weight": 0.45,
	"variation_strength": 0.15,
	"roughness": 0.85,
	"specular": 0.15
}

func _init() -> void:
	profiles[RockSizeConfig.Category.LARGE] = RockSizeConfig.create_large()
	profiles[RockSizeConfig.Category.MEDIUM] = RockSizeConfig.create_medium()
	profiles[RockSizeConfig.Category.SMALL] = RockSizeConfig.create_small()

func get_profile(cat: Variant) -> RockSizeConfig:
	if cat is int:
		if profiles.has(cat):
			return profiles[cat]
	elif cat is String:
		var s: String = (cat as String).to_lower()
		if s == "large" and profiles.has(RockSizeConfig.Category.LARGE):
			return profiles[RockSizeConfig.Category.LARGE]
		elif s == "medium" and profiles.has(RockSizeConfig.Category.MEDIUM):
			return profiles[RockSizeConfig.Category.MEDIUM]
		elif s == "small" and profiles.has(RockSizeConfig.Category.SMALL):
			return profiles[RockSizeConfig.Category.SMALL]
	return profiles.get(RockSizeConfig.Category.MEDIUM, RockSizeConfig.create_medium())

func to_dict() -> Dictionary:
	var prof_dict: Dictionary = {}
	for cat in profiles.keys():
		var p: RockSizeConfig = profiles[cat]
		prof_dict[p.category_name] = p.to_dict()

	return {
		"version": version,
		"biome": biome,
		"distribution": distribution.duplicate(true),
		"clustering": clustering.duplicate(true),
		"profiles": prof_dict,
		"material": material.duplicate(true)
	}

func from_dict(d: Dictionary) -> void:
	if d.has("version"):
		version = int(d["version"])
	if d.has("biome"):
		biome = str(d["biome"])

	if d.has("distribution") and d["distribution"] is Dictionary:
		distribution = d["distribution"].duplicate(true)

	if d.has("clustering") and d["clustering"] is Dictionary:
		clustering = d["clustering"].duplicate(true)

	if d.has("profiles") and d["profiles"] is Dictionary:
		var p_dict: Dictionary = d["profiles"]
		for cat_key in p_dict.keys():
			var sub_dict: Dictionary = p_dict[cat_key]
			var cat_id: int = -1
			var key_str: String = str(cat_key).to_lower()
			if key_str == "large" or key_str == "0":
				cat_id = RockSizeConfig.Category.LARGE
			elif key_str == "medium" or key_str == "1":
				cat_id = RockSizeConfig.Category.MEDIUM
			elif key_str == "small" or key_str == "2":
				cat_id = RockSizeConfig.Category.SMALL

			if cat_id >= 0:
				if not profiles.has(cat_id):
					profiles[cat_id] = RockSizeConfig.new()
				profiles[cat_id].from_dict(sub_dict)

	if d.has("material") and d["material"] is Dictionary:
		material = d["material"].duplicate(true)

func to_json_string(pretty: bool = true) -> String:
	var indent: String = "\t" if pretty else ""
	return JSON.stringify(to_dict(), indent)

func from_json_string(json_text: String) -> Error:
	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		return err
	if not (json.data is Dictionary):
		return ERR_INVALID_DATA
	from_dict(json.data)
	return OK

func save_to_json(file_path: String) -> Error:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_json_string(true))
	file.close()
	return OK

func load_from_json(file_path: String) -> Error:
	if not FileAccess.file_exists(file_path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var text: String = file.get_as_text()
	file.close()
	return from_json_string(text)

func clone():
	var copy = get_script().new()
	copy.from_dict(to_dict())
	return copy

# =========================================================================
# PRESETS CANÓNICOS
# =========================================================================

static func create_default_taiga():
	var cfg = new()
	cfg.biome = "taiga"
	cfg.distribution["density"] = 0.15
	cfg.distribution["min_slope_degrees"] = 15.0
	cfg.distribution["max_slope_degrees"] = 55.0
	cfg.distribution["category_weights"] = {
		"large": 0.20,
		"medium": 0.45,
		"small": 0.35
	}
	cfg.material["normal_weight"] = 0.55
	cfg.material["height_weight"] = 0.45
	cfg.material["variation_strength"] = 0.15
	cfg.material["roughness"] = 0.85
	cfg.material["specular"] = 0.15
	return cfg

static func create_default_desert():
	var cfg = new()
	cfg.biome = "desert"
	cfg.distribution["density"] = 0.10
	cfg.distribution["min_slope_degrees"] = 10.0
	cfg.distribution["max_slope_degrees"] = 45.0
	cfg.distribution["category_weights"] = {
		"large": 0.15,
		"medium": 0.35,
		"small": 0.50
	}
	# En el desierto las rocas son más aplastadas, estratificadas y facetadas (arenisca/lajas)
	for cat in cfg.profiles.keys():
		var p = cfg.profiles[cat]
		p.height_ratio *= 0.70
		p.base_radius_factor = 1.10
		p.taper_power = 0.60
		p.peak_convergence_min = 0.25
		p.peak_convergence_max = 0.45
		p.apex_elevation_min = 0.05
		p.apex_elevation_max = 0.15

	cfg.material["normal_weight"] = 0.65
	cfg.material["height_weight"] = 0.35
	cfg.material["roughness"] = 0.90
	cfg.material["variation_strength"] = 0.20
	return cfg

static func create_default_mountain():
	var cfg = new()
	cfg.biome = "mountain"
	cfg.distribution["density"] = 0.25
	cfg.distribution["min_slope_degrees"] = 20.0
	cfg.distribution["max_slope_degrees"] = 70.0
	cfg.distribution["category_weights"] = {
		"large": 0.35,
		"medium": 0.40,
		"small": 0.25
	}
	# En alta montaña las rocas son monolíticas, afiladas y escarpadas
	for cat in cfg.profiles.keys():
		var p: RockSizeConfig = cfg.profiles[cat]
		p.height_ratio *= 1.35
		p.irregularity = min(1.0, p.irregularity * 1.25)
		p.radial_jitter = min(1.0, p.radial_jitter * 1.2)
		p.apex_elevation_min = 0.20
		p.apex_elevation_max = 0.40

	cfg.material["normal_weight"] = 0.70
	cfg.material["height_weight"] = 0.30
	cfg.material["roughness"] = 0.80
	cfg.material["specular"] = 0.25
	return cfg
