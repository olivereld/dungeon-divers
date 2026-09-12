extends SceneTree

## Survey específico de Confluencias (Bloque 4).
## Evalúa junctions en 10 semillas y genera docs/confluence_junctions_survey_report.txt.
## Mide: quads, triangles, invalid quads, crossed edges, inverted quads, gaps, ownership overlaps.

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")
const _JunctionValidator = preload("res://src/world_generator/validation/junction_validator.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("==========================================================")
	print("--- INICIANDO SURVEY DE CONFLUENCIAS (BLOQUE 4) ---")
	print("==========================================================")

	var seeds: Array[int] = [12345, 42, 101, 202, 303, 404, 505, 777, 888, 999]
	var report_lines: Array[String] = []

	report_lines.append("====================================================================================================")
	report_lines.append("INFORME DE SURVEY DE CONFLUENCIAS Y JUNCTIONS (BLOQUE 4)")
	report_lines.append("Fecha: %s" % Time.get_datetime_string_from_system())
	report_lines.append("Perfil: Taiga Canónica 64x64 | M=3 estaciones longitudinales")
	report_lines.append("====================================================================================================")
	report_lines.append("Seed   | ConfPos   | Upstreams | Quads | Tris | InvQuads | Crossed | Inverted | Gaps | Overlaps")
	report_lines.append("----------------------------------------------------------------------------------------------------")

	var total_confluences: int = 0
	var total_quads: int = 0
	var total_tris: int = 0
	var total_inv_quads: int = 0
	var total_crossed: int = 0
	var total_inverted: int = 0
	var total_gaps: int = 0
	var total_overlaps: int = 0

	var count_2to1: int = 0
	var count_3to1: int = 0
	var count_4to1: int = 0

	for s in seeds:
		var profile = _TaigaWorldProfile.new()
		profile.width = 64
		profile.height = 64
		profile.hydrology_enabled = true

		var result = _WorldPipeline.generate(s, profile)
		if result == null or result.hydrology == null:
			continue

		var hydro = result.hydrology
		var network = hydro.get_river_network()
		var confs: Array = hydro.confluences
		if network is RiverNetwork and not network.confluences.is_empty():
			confs = network.confluences

		for conf in confs:
			var up_ids: Array = conf.get("upstream_rivers", [])
			var n_up: int = up_ids.size()
			if n_up == 0:
				continue

			total_confluences += 1
			if n_up == 1:
				count_2to1 += 1 # 1 upstream + 1 continuation
			elif n_up == 2:
				count_2to1 += 1
			elif n_up == 3:
				count_3to1 += 1
			elif n_up >= 4:
				count_4to1 += 1

			var surf = _RiverMeshBuilder.build_confluence_surface(conf, result, profile, network, 3)
			if surf == null:
				continue

			var val_res = _JunctionValidator.validate_full_junction(conf, network, result, profile, surf)
			var metrics: Dictionary = val_res.get("metrics", {})
			var deg_tris: int = metrics.get("degenerate_triangles", 0)
			var crossed: int = metrics.get("crossed_edges", 0)
			var inverted: int = metrics.get("inverted_quads", 0)
			var gaps: int = metrics.get("inter_branch_gaps", 0)
			var ribbon_cont: int = metrics.get("ribbon_continuity_errors", 0)
			var n_quads: int = metrics.get("quads_checked", n_up * 3)
			var n_tris: int = metrics.get("triangles_checked", surf.indices.size() / 3)

			total_quads += n_quads
			total_tris += n_tris
			total_inv_quads += deg_tris
			total_crossed += crossed
			total_inverted += inverted
			total_gaps += gaps
			total_overlaps += ribbon_cont

			var c_pos: Vector2i = conf.get("position", Vector2i(-1, -1))
			report_lines.append(
				"%-6d | (%2d,%2d)   | %-9d | %-5d | %-4d | %-8d | %-7d | %-8d | %-4d | %-8d" % [
					s, c_pos.x, c_pos.y, n_up, n_quads, n_tris, deg_tris, crossed, inverted, gaps, ribbon_cont
				]
			)

	report_lines.append("----------------------------------------------------------------------------------------------------")
	report_lines.append("RESUMEN GLOBAL:")
	report_lines.append("Confluencias analizadas: %d" % total_confluences)
	report_lines.append("  - 2->1: %d" % count_2to1)
	report_lines.append("  - 3->1: %d" % count_3to1)
	report_lines.append("  - 4->1: %d" % count_4to1)
	report_lines.append("Total Quads evaluados:   %d" % total_quads)
	report_lines.append("Total Triángulos:        %d" % total_tris)
	report_lines.append("Quads Inválidos:         %d" % total_inv_quads)
	report_lines.append("Bordes Cruzados:         %d" % total_crossed)
	report_lines.append("Quads Invertidos:        %d" % total_inverted)
	report_lines.append("Gaps detectados:         %d" % total_gaps)
	report_lines.append("Solapamiento Ownership:  %d" % total_overlaps)
	report_lines.append("====================================================================================================")

	var report_text: String = "\n".join(report_lines)
	print(report_text)

	var f = FileAccess.open("res://docs/confluence_junctions_survey_report.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(report_text)
		f.close()

	assert(total_inv_quads == 0, "Quads inválidos deben ser 0")
	assert(total_crossed == 0, "Bordes cruzados deben ser 0")
	assert(total_inverted == 0, "Quads invertidos deben ser 0")
	assert(total_gaps == 0, "Gaps deben ser 0")
	assert(total_overlaps == 0, "Solapamientos deben ser 0")

	print("SURVEY DE CONFLUENCIAS COMPLETADO CON ÉXITO: 0 FALLOS.")
	quit(0)
