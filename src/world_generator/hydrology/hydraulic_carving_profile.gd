class_name HydraulicCarvingProfile
extends RefCounted

## Abstracción conceptual unificada para el perfil de excavación geomorfológica hidráulica.
## Modela la sección transversal continua del lecho, lámina de agua y talud de orilla,
## aplicable tanto a geometrías radiales/2D de lagos como a ejes/centerlines de ríos.
##
## Zonas del perfil continuo (garantía de continuidad C0 estricta):
## 1. BED: Fondo plano a profundidad bed_depth bajo la lámina de agua.
## 2. SUBMERGED TRANSITION: Transición suave desde el fondo hasta la cota de agua.
## 3. WATERLINE: Cota exacta de la lámina de agua (water_y).
## 4. SHORE / BANK: Talud ascendente progresivo hacia la cresta / terreno natural.
## 5. RAW: Terreno original circundante intacto.

## Profundidad del lecho respecto al espejo de agua (water_y - bed_depth = bed_y)
var bed_depth: float = 0.40

## Semiancho del fondo plano sumergido (usado en canales fluviales)
var bed_width: float = 0.0

## Ancho de la transición sumergida desde el lecho plano hasta la línea de flotación
var transition_width: float = 1.0

## Ancho horizontal del talud de la orilla desde la línea de flotación hasta el terreno
var shore_width: float = 3.5

## Curvatura o factor de pendiente del talud de orilla (1.0 = lineal, 2.0 = smoothstep)
var shore_slope: float = 2.0

## Resguardo / cota mínima de coronación sobre el nivel del agua
var freeboard: float = 0.30

func _init(
	p_bed_depth: float = 0.40,
	p_shore_width: float = 3.5,
	p_transition_width: float = 1.0,
	p_bed_width: float = 0.0,
	p_freeboard: float = 0.30,
	p_shore_slope: float = 2.0
) -> void:
	bed_depth = maxf(0.01, p_bed_depth)
	shore_width = maxf(0.01, p_shore_width)
	transition_width = maxf(0.01, p_transition_width)
	bed_width = maxf(0.0, p_bed_width)
	freeboard = maxf(0.0, p_freeboard)
	shore_slope = maxf(0.1, p_shore_slope)

## Factoría para ríos: perfil transversal centrado en el eje (d >= 0)
static func create_for_river(
	depth: float,
	p_bed_width: float,
	p_transition_width: float,
	bank_width: float,
	p_freeboard: float = 0.25,
	slope_factor: float = 2.0
) -> RefCounted:
	var inst = (load("res://src/world_generator/hydrology/hydraulic_carving_profile.gd") as GDScript).new(
		depth,
		bank_width,
		p_transition_width,
		p_bed_width,
		p_freeboard,
		slope_factor
	)
	return inst

## Factoría para lagos: perfil radial/2D con distancia signada a la orilla
static func create_for_lake(
	depth: float,
	submerged_ramp_width: float,
	bank_width: float,
	p_freeboard: float = 0.30,
	slope_factor: float = 2.0
) -> RefCounted:
	var inst = (load("res://src/world_generator/hydrology/hydraulic_carving_profile.gd") as GDScript).new(
		depth,
		bank_width,
		submerged_ramp_width,
		0.0,
		p_freeboard,
		slope_factor
	)
	return inst

## Evalúa la máscara de influencia hidráulica continua [0.0, 1.0] para ríos según distancia al eje:
## 1.0 = canal/lecho y línea de agua (d <= r_water)
## 1.0 -> 0.0 = talud/transición (r_water < d < r_bank)
## 0.0 = terreno intacto (d >= r_bank)
func evaluate_influence_centerline(distance: float) -> float:
	var d: float = maxf(0.0, distance)
	var r_water: float = bed_width + transition_width
	var r_bank: float = r_water + shore_width
	if d <= r_water:
		return 1.0
	if d >= r_bank:
		return 0.0
	var denom_b: float = maxf(r_bank - r_water, 0.0001)
	var u: float = clampf((d - r_water) / denom_b, 0.0, 1.0)
	var s: float = smoothstep(0.0, 1.0, u) if shore_slope >= 1.5 else pow(u, shore_slope)
	return 1.0 - s

## Evalúa la máscara de influencia hidráulica continua [0.0, 1.0] para lagos según distancia signada a la orilla:
## 1.0 = cubeta/vaso interior y línea de agua (signed_distance <= 0.0)
## 1.0 -> 0.0 = talud exterior (0.0 < signed_distance < shore_width)
## 0.0 = terreno intacto (signed_distance >= shore_width)
func evaluate_influence_boundary(signed_distance: float) -> float:
	if signed_distance <= 0.0:
		return 1.0
	if signed_distance >= shore_width:
		return 0.0
	var u: float = clampf(signed_distance / maxf(shore_width, 0.0001), 0.0, 1.0)
	var s: float = smoothstep(0.0, 1.0, u) if shore_slope >= 1.5 else pow(u, shore_slope)
	return 1.0 - s

## Retorna la cota geométrica excavada de referencia (carved_height) para ríos:
## Lecho plano (bed_y) hasta rampa sumergida a water_y; en el talud la referencia base es water_y.
func evaluate_carved_height_centerline(distance: float, water_y: float) -> float:
	var d: float = maxf(0.0, distance)
	var bed_y: float = water_y - bed_depth
	var r_bed: float = bed_width
	var r_water: float = bed_width + transition_width
	if d <= r_bed:
		return bed_y
	if d < r_water:
		var denom_w: float = maxf(r_water - r_bed, 0.0001)
		var u: float = clampf((d - r_bed) / denom_w, 0.0, 1.0)
		return lerpf(bed_y, water_y, u * u)
	return water_y

## Retorna la cota geométrica excavada de referencia (carved_height) para lagos:
## Si se especifica custom_depth >= 0.0, utiliza la profundidad física del lecho provista por hydrology data.
func evaluate_carved_height_boundary(signed_distance: float, water_y: float, custom_depth: float = -1.0) -> float:
	var d_depth: float = custom_depth if custom_depth >= 0.0 else bed_depth
	var bed_y: float = water_y - d_depth
	if signed_distance <= -transition_width:
		return bed_y
	if signed_distance < 0.0:
		var u: float = clampf((signed_distance + transition_width) / maxf(transition_width, 0.0001), 0.0, 1.0)
		return lerpf(bed_y, water_y, u * u)
	return water_y

## Evaluación para ríos: distance es la distancia perpendicular al eje del río (d >= 0).
## Aplica: final_height = lerp(raw_height, carved_height, influence)
func evaluate_centerline(distance: float, water_y: float, raw_y: float) -> float:
	var influence: float = evaluate_influence_centerline(distance)
	if influence <= 0.0:
		return raw_y
	var carved_h: float = evaluate_carved_height_centerline(distance, water_y)
	if influence >= 1.0:
		return carved_h
	return lerpf(raw_y, carved_h, influence)

## Evaluación para lagos: signed_distance es la distancia signada a la orilla.
## Aplica: final_height = lerp(raw_height, carved_height, influence)
func evaluate_boundary(signed_distance: float, water_y: float, raw_y: float, custom_depth: float = -1.0) -> float:
	var influence: float = evaluate_influence_boundary(signed_distance)
	if influence <= 0.0:
		return raw_y
	var carved_h: float = evaluate_carved_height_boundary(signed_distance, water_y, custom_depth)
	if influence >= 1.0:
		return carved_h
	return lerpf(raw_y, carved_h, influence)
