class_name NecropolisWoodProps
extends RefCounted

## Proveedor y configurador de mallas y especificaciones de tocones y troncos caídos
## para el entorno exterior de Necrópolis.

const _ScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
const _WorldRendererScript = preload("res://src/world_renderer/world_renderer.gd")

const STUMP_GLB_PATH: String = "res://models/nature/stump/STUMP.glb"
const STUMP_TEX_PATH: String = "res://models/nature/stump/STUMP_stump.png"
const WOOD_LOG_GLB_PATH: String = "res://models/nature/wood_log/wood_log.glb"
const WOOD_LOG_TEX_PATH: String = "res://models/nature/wood_log/wood_log_tree_log.png"

static var _cached_stump_mesh: Mesh = null
static var _cached_log_mesh: Mesh = null

static func get_stump_mesh() -> Mesh:
	if _cached_stump_mesh != null:
		return _cached_stump_mesh
	_cached_stump_mesh = _WorldRendererScript._create_stump_mesh()
	return _cached_stump_mesh

static func get_log_mesh() -> Mesh:
	if _cached_log_mesh != null:
		return _cached_log_mesh
	_cached_log_mesh = _WorldRendererScript._create_wood_log_mesh()
	return _cached_log_mesh

static func build_specs(profile: RefCounted, tree_anchor_points: Array = []) -> Array:
	var specs: Array = []

	var stump_mesh := get_stump_mesh()
	var log_mesh := get_log_mesh()

	# 1. Stumps (Tocones): anclados cerca de árboles muertos y en la zona funeraria/corrupción
	var stump_spec := _ScattererScript.DecorationSpec.new()
	stump_spec.id = "stump"
	stump_spec.mesh = stump_mesh
	stump_spec.density = profile.stump_density if "stump_density" in profile else 0.12
	stump_spec.min_distance = profile.fallen_wood_min_distance if "fallen_wood_min_distance" in profile else 2.0
	stump_spec.scale_min = 0.85
	stump_spec.scale_max = 1.35
	stump_spec.radius_min = profile.entrance_clear_radius + 1.0
	stump_spec.radius_max = profile.corruption_radius + 4.0
	stump_spec.forbidden_radius = profile.entrance_clear_radius
	stump_spec.ground_embed_m = 0.08
	stump_spec.align_to_terrain = true
	stump_spec.tilt_max_deg = 8.0
	stump_spec.cluster_anchor_points = tree_anchor_points
	stump_spec.cluster_bias = 0.45
	specs.append(stump_spec)

	# 2. Fallen Wood Logs (Troncos caídos): más densos en la zona de corrupción, orientados naturalmente
	var log_spec := _ScattererScript.DecorationSpec.new()
	log_spec.id = "wood_log"
	log_spec.mesh = log_mesh
	log_spec.density = profile.log_density if "log_density" in profile else 0.10
	log_spec.min_distance = profile.fallen_wood_min_distance if "fallen_wood_min_distance" in profile else 2.0
	log_spec.scale_min = 0.90
	log_spec.scale_max = 1.60
	log_spec.radius_min = profile.funeral_ground_radius - 2.0
	log_spec.radius_max = profile.transition_radius
	log_spec.forbidden_radius = profile.entrance_clear_radius + 0.5
	log_spec.ground_embed_m = 0.10
	log_spec.align_to_terrain = true
	log_spec.tilt_max_deg = 14.0
	log_spec.cluster_anchor_points = tree_anchor_points
	log_spec.cluster_bias = 0.30
	specs.append(log_spec)

	return specs
