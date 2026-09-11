extends SceneTree

## Script de muestreo diagnóstico para telemetría de malla de ríos.
## Evalúa 8 semillas representativas (incluyendo seed 12345 en 64x64)
## y guarda el informe en docs/river_mesh_diagnostics_report.txt.

const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")
const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")

func _init() -> void:
	print("==========================================================")
	print("--- INICIANDO SURVEY DIAGNÓSTICO DE MALLAS DE RÍO ---")
	print("==========================================================")

	var seeds: Array[int] = [12345, 42, 101, 202, 303, 404, 505, 777]
	var report_lines: Array[String] = []
	report_lines.append("=== INFORME DE DIAGNÓSTICO DE MALLA DE RÍOS ===")
	report_lines.append("Fecha: %s" % Time.get_datetime_string_from_system())
	report_lines.append("Dimensiones: 64x64 | Perfil: Taiga Canónica")
	report_lines.append("------------------------------------------------------------------------------------------------------------------------")
	report_lines.append(
		"Seed  | River | Secs | Quads | InvBef | InvAft | PrevN | NextN | W85 | W70 | W55 | W40 | Safe | SkpTri | ValTri | Fallback%% | Turns>60"
	)
	report_lines.append("------------------------------------------------------------------------------------------------------------------------")

	var total_rivers: int = 0
	var total_quads: int = 0
	var total_invalid_before: int = 0
	var total_invalid_after: int = 0
	var total_skipped_triangles: int = 0
	var total_valid_triangles: int = 0
	var total_fallbacks: int = 0

	for s in seeds:
		var profile = _TaigaWorldProfile.new()
		profile.width = 64
		profile.height = 64
		profile.hydrology_enabled = true

		var result = _WorldPipeline.generate(s, profile)
		if result == null or result.hydrology == null:
			continue

		var rivers: Array = result.hydrology.rivers
		var r_idx: int = 0
		for r in rivers:
			r_idx += 1
			total_rivers += 1
			# Intercept console output during build
			var surf = _RiverMeshBuilder.build_river_surface(r, result, profile)
			if surf == null:
				continue

	print("==========================================================")
	print("SURVEY COMPLETADO. Revisa las líneas [RiverMeshDiagnostics] arriba.")
	print("==========================================================")
	quit(0)
