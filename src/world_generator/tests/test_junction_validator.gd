extends SceneTree

## Test de validación específico de Junctions (Bloque 3).
## Verifica que JunctionValidator detecte quads válidos y capture rigurosamente los 7 factores:
## 1. Crossing de bordes (bowtie self-intersection)
## 2. Inversión de quad (orientación de normales / áreas con signo invertidas)
## 3. Continuidad entre estaciones (discontinuidades verticales de cota)
## 4. Gaps entre ramas (convergencia divergente en salida downstream)
## 5. Anomalías de ancho (colapso < 0.05 m o ratio excesivo)
## 6. Anomalías de desplazamiento (avance nulo o retroceso retrógrado)
## 7. Continuidad junction <-> ribbon (acoplamiento con ribbons incidentes)

const _JunctionValidator = preload("res://src/world_generator/validation/junction_validator.gd")
const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("==========================================================")
	print("--- TEST BLOQUE 3: VALIDADOR ESPECÍFICO DE JUNCTIONS ---")
	print("==========================================================")

	# 1. Quad válido canónico
	var q_l0 := Vector3(-1, 0, 0)
	var q_r0 := Vector3(1, 0, 0)
	var q_l1 := Vector3(-1, 0, 2)
	var q_r1 := Vector3(1, 0, 2)
	var res_valid = _JunctionValidator.validate_quad(q_l0, q_r0, q_l1, q_r1)
	assert(res_valid["valid"], "Quad normal debe ser válido")
	assert(not res_valid["has_crossing"], "No debe tener cruce")
	assert(not res_valid["is_inverted"], "No debe estar invertido")

	# 2. Factor 1: Crossing de bordes (bowtie / auto-intersección lateral en XZ)
	var l1_crossed := Vector3(1.5, 0, 2)
	var r1_crossed := Vector3(-1.5, 0, 2)
	var res_crossed = _JunctionValidator.validate_quad(q_l0, q_r0, l1_crossed, r1_crossed)
	assert(not res_crossed["valid"], "Quad cruzado debe ser inválido")
	assert(res_crossed["has_crossing"], "Debe detectar flag has_crossing")

	# 3. Factor 2: Inversión de quad (vértices invertidos o normales hacia abajo)
	# Intercambiar left y right en estación 1 para invertir la orientación
	var res_inverted = _JunctionValidator.validate_quad(q_l0, q_r0, q_r1, q_l1)
	assert(not res_inverted["valid"], "Quad invertido debe ser inválido")
	assert(res_inverted["is_inverted"] or res_inverted["has_crossing"], "Debe marcar inversión o cruce")

	# 4. Factor 3: Continuidad entre estaciones (salto vertical de cota > 1.5 m)
	var q_l1_cliff := Vector3(-1, 3.0, 2)
	var q_r1_cliff := Vector3(1, 3.0, 2)
	var res_cliff = _JunctionValidator.validate_quad(q_l0, q_r0, q_l1_cliff, q_r1_cliff)
	assert(not res_cliff["valid"], "Quad con salto vertical debe ser inválido")
	assert(res_cliff["station_discontinuity"], "Debe detectar station_discontinuity")

	# 5. Factor 5: Anomalías de ancho (colapso absoluto < 0.05 m o ratio excesivo)
	var q_l1_pinched := Vector3(-0.01, 0, 2)
	var q_r1_pinched := Vector3(0.01, 0, 2)
	var res_pinched = _JunctionValidator.validate_quad(q_l0, q_r0, q_l1_pinched, q_r1_pinched)
	assert(not res_pinched["valid"], "Quad con ancho colapsado debe ser inválido")
	assert(res_pinched["width_anomaly"], "Debe detectar width_anomaly")

	# 6. Factor 6: Anomalías de desplazamiento (retroceso hacia atrás)
	var q_l1_back := Vector3(-1, 0, -2)
	var q_r1_back := Vector3(1, 0, -2)
	var res_retrograde = _JunctionValidator.validate_quad(q_l0, q_r0, q_l1_back, q_r1_back)
	assert(not res_retrograde["valid"], "Quad con retroceso retrógrado debe ser inválido")
	assert(res_retrograde["displacement_anomaly"], "Debe detectar displacement_anomaly")

	# 7. Factor 4: Gaps entre ramas (convergencia divergente en salida)
	var mock_grid_gap: Array = [
		[
			{"left": Vector3(-2, 0, 0), "right": Vector3(-1, 0, 0)},
			{"left": Vector3(-2, 0, 2), "right": Vector3(-1, 0, 2)}
		],
		[
			{"left": Vector3(1, 0, 0), "right": Vector3(2, 0, 0)},
			{"left": Vector3(0.5, 0, 2), "right": Vector3(2, 0, 2)} # Gap de 1.5 m con la rama anterior (-1 a 0.5)
		]
	]
	var res_gap = _JunctionValidator.validate_inter_branch_gaps(mock_grid_gap)
	assert(not res_gap["valid"], "Grid con gap entre ramas debe ser inválido")
	assert(res_gap["gap_count"] > 0, "Debe reportar gap_count > 0")

	# 8. Factor 7: Continuidad Junction <-> Ribbon en red real
	var net = _RiverNetwork.new()
	var r1 = _River.new(0, Vector2i(0, 0), [])
	r1.points = [Vector3(0, 0, 0), Vector3(5, 0, 2)]
	r1.widths = [1.2, 1.2]
	r1.depths = [0.2, 0.2]
	r1.downstream_river = 2

	var r2 = _River.new(1, Vector2i(0, 4), [])
	r2.points = [Vector3(0, 0, 4), Vector3(5, 0, 2)]
	r2.widths = [1.2, 1.2]
	r2.depths = [0.2, 0.2]
	r2.downstream_river = 2

	var r_down = _River.new(2, Vector2i(5, 2), [])
	r_down.points = [Vector3(5, 0, 2), Vector3(10, 0, 2)]
	r_down.widths = [2.0, 2.0]
	r_down.depths = [0.3, 0.3]
	r_down.upstream_rivers = [0, 1]

	net.add_river(r1)
	net.add_river(r2)
	net.add_river(r_down)

	var conf := {"position": Vector2i(5, 2), "upstream_rivers": [0, 1], "downstream_river": 2}
	var dummy_profile = WorldProfile.new()

	var station_grid = _RiverMeshBuilder._generate_explicit_junction_stations(conf, net, null, dummy_profile, 3)
	var res_ribbon_cont = _JunctionValidator.validate_junction_ribbon_continuity(conf, net, null, dummy_profile, station_grid)
	assert(res_ribbon_cont["valid"], "Continuidad ribbon debe ser válida: %s" % str(res_ribbon_cont["errors"]))

	# 9. Validación Integral Completa (validate_full_junction)
	var surf = _RiverMeshBuilder.build_confluence_surface(conf, null, dummy_profile, net, 3)
	var full_res = _JunctionValidator.validate_full_junction(conf, net, null, dummy_profile, surf, station_grid)

	assert(full_res["valid"], "Validación integral de junction debe ser exitosa: %s" % str(full_res["errors"]))
	assert(full_res["metrics"]["crossed_edges"] == 0, "Bordes cruzados deben ser 0")
	assert(full_res["metrics"]["inverted_quads"] == 0, "Quads invertidos deben ser 0")
	assert(full_res["metrics"]["station_discontinuities"] == 0, "Discontinuidades deben ser 0")
	assert(full_res["metrics"]["inter_branch_gaps"] == 0, "Gaps deben ser 0")
	assert(full_res["metrics"]["width_anomalies"] == 0, "Anomalías de ancho deben ser 0")
	assert(full_res["metrics"]["displacement_anomalies"] == 0, "Anomalías de desplazamiento deben ser 0")
	assert(full_res["metrics"]["ribbon_continuity_errors"] == 0, "Errores de continuidad con ribbon deben ser 0")

	print("TEST BLOQUE 3 (7 FACTORES ESPECÍFICOS): PASSED!")
	print("==========================================================")
	quit(0)
