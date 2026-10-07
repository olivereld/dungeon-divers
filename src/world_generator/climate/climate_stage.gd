class_name ClimateStage
extends WorldStage

## Etapa de Clima (ClimateStage):
## Calcula los campos continuos de temperatura y humedad ambiental por celda en [0.0, 1.0],
## combinando ruido macro continental de baja frecuencia, efecto de altitud (lapse rate)
## e influencia hidrológica secundaria (riberas).

const DEFAULT_BASE_TEMPERATURE: float = 0.50
const DEFAULT_BASE_MOISTURE: float = 0.50
const DEFAULT_TEMPERATURE_LAPSE_RATE: float = 0.40
const DEFAULT_ELEVATION_MOISTURE_PENALTY: float = 0.15
const DEFAULT_RIPARIAN_MOISTURE_BOOST: float = 0.25
const DEFAULT_CLIMATE_FREQUENCY: float = 0.0012

func execute(context: WorldGenerationContext) -> void:
	run(context)

static func run(context: WorldGenerationContext) -> void:
	if context == null or context.result == null:
		return

	var profile: WorldProfile = context.profile
	var climate_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_CLIMATE)

	var freq: float = DEFAULT_CLIMATE_FREQUENCY
	if profile != null and "climate_frequency" in profile:
		freq = float(profile.get("climate_frequency"))

	# Campo de ruido de temperatura macro continental
	var temp_noise := FastNoiseLite.new()
	temp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	temp_noise.seed = climate_seed
	temp_noise.frequency = freq
	temp_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	temp_noise.fractal_octaves = 2
	temp_noise.fractal_gain = 0.35

	# Campo de ruido de humedad macro continental
	var moisture_noise := FastNoiseLite.new()
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.seed = climate_seed + 101
	moisture_noise.frequency = freq
	moisture_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	moisture_noise.fractal_octaves = 2
	moisture_noise.fractal_gain = 0.35

	var base_temp: float = DEFAULT_BASE_TEMPERATURE
	if profile != null and "climate_base_temperature" in profile:
		base_temp = float(profile.get("climate_base_temperature"))

	var base_moist: float = DEFAULT_BASE_MOISTURE
	if profile != null and "climate_base_moisture" in profile:
		base_moist = float(profile.get("climate_base_moisture"))

	var lapse_rate: float = DEFAULT_TEMPERATURE_LAPSE_RATE
	if profile != null and "climate_lapse_rate" in profile:
		lapse_rate = float(profile.get("climate_lapse_rate"))

	var elev_moist_pen: float = DEFAULT_ELEVATION_MOISTURE_PENALTY
	if profile != null and "climate_elevation_moisture_penalty" in profile:
		elev_moist_pen = float(profile.get("climate_elevation_moisture_penalty"))

	var riparian_boost: float = DEFAULT_RIPARIAN_MOISTURE_BOOST
	if profile != null and "climate_riparian_boost" in profile:
		riparian_boost = float(profile.get("climate_riparian_boost"))

	var region_origin: Vector2i = context.region_origin if ("region_origin" in context) else Vector2i.ZERO
	var cell_size: float = profile.cell_size if profile != null else 1.0

	var hydro: HydrologyResult = context.result.hydrology if context.result != null else null

	for pos in context.result.cells.keys():
		var cell: WorldCell = context.result.cells[pos]
		if cell == null:
			continue

		var sample_x: float = float(region_origin.x + pos.x) * cell_size
		var sample_y: float = float(region_origin.y + pos.y) * cell_size

		# 1. Temperatura: base continental + modulación macro en [-0.35, 0.35] - enfriamiento por altitud
		var raw_t: float = temp_noise.get_noise_2d(sample_x, sample_y)
		var t_val: float = base_temp + (raw_t * 0.35)
		t_val -= lapse_rate * cell.elevation_normalized
		cell.temperature = clampf(t_val, 0.0, 1.0)

		# 2. Humedad: base continental + modulación macro en [-0.35, 0.35] - penalización en cumbres + boost ripario
		var raw_m: float = moisture_noise.get_noise_2d(sample_x, sample_y)
		var m_val: float = base_moist + (raw_m * 0.35)
		m_val -= elev_moist_pen * cell.elevation_normalized

		var hydro_inf: float = cell.hydraulic_influence
		if hydro != null and hydro.has_method("is_water") and hydro.is_water(pos):
			hydro_inf = maxf(hydro_inf, 1.0)
		m_val += riparian_boost * hydro_inf
		cell.moisture = clampf(m_val, 0.0, 1.0)

	context.result.set_meta(&"climate_stage_executed", true)
