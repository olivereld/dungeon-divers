class_name HydrologyRegionCache
extends RefCounted

## Administrador desacoplado de hidrología regional con caché y estados explícitos.
## Garantiza que múltiples chunks colindantes compartan la misma región hidrológica
## sin recalcularla múltiples veces en paralelo.

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

enum RegionState {
	UNREQUESTED = 0,
	GENERATING = 1,
	READY = 2
}

var seed_val: int = 0
var profile: WorldProfile = null

## Mapeo de regiones calculadas (Vector2i -> HydrologyResult)
var _regions: Dictionary = {}

## Estados por región (Vector2i -> RegionState)
var _states: Dictionary = {}

## Resultado unificado acumulado
var shared_hydrology: HydrologyResult = null

var _mutex: Mutex = null

# Telemetría de caché
var cache_hits: int = 0
var cache_misses: int = 0

func _init(p_seed: int = 0, p_profile: WorldProfile = null) -> void:
	seed_val = p_seed
	profile = p_profile
	_mutex = Mutex.new()

## Obtiene o genera la hidrología para una región macro dada.
## Es thread-safe y reutiliza resultados ya generados.
func get_or_generate_region(macro_coord: Vector2i, macro_w: int, macro_h: int) -> HydrologyResult:
	_mutex.lock()
	if _regions.has(macro_coord) and _states.get(macro_coord, RegionState.UNREQUESTED) == RegionState.READY:
		cache_hits += 1
		var res: HydrologyResult = _regions[macro_coord]
		_mutex.unlock()
		return res

	cache_misses += 1
	_states[macro_coord] = RegionState.GENERATING
	_mutex.unlock()

	var reg_origin := Vector2i(macro_coord.x * macro_w, macro_coord.y * macro_h)
	var reg_hydro: HydrologyResult = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile, reg_origin)

	_mutex.lock()
	_regions[macro_coord] = reg_hydro
	_states[macro_coord] = RegionState.READY

	if shared_hydrology == null:
		shared_hydrology = reg_hydro
	else:
		var c_size: float = profile.cell_size if profile != null else 1.0
		shared_hydrology.merge(reg_hydro, c_size)

	_mutex.unlock()
	return reg_hydro

## Asegura que todas las macro-regiones que cubren un Rect2i estén generadas.
func ensure_bounds(bounds: Rect2i, macro_w: int, macro_h: int) -> HydrologyResult:
	var min_mx: int = int(floor(float(bounds.position.x) / float(macro_w)))
	var max_mx: int = int(floor(float(bounds.end.x - 1) / float(macro_w)))
	var min_my: int = int(floor(float(bounds.position.y) / float(macro_h)))
	var max_my: int = int(floor(float(bounds.end.y - 1) / float(macro_h)))

	for my in range(min_my, max_my + 1):
		for mx in range(min_mx, max_mx + 1):
			var m_coord := Vector2i(mx, my)
			get_or_generate_region(m_coord, macro_w, macro_h)

	return shared_hydrology

## Limpia la caché si cambia la semilla
func clear() -> void:
	_mutex.lock()
	_regions.clear()
	_states.clear()
	shared_hydrology = null
	cache_hits = 0
	cache_misses = 0
	_mutex.unlock()
