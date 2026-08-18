class_name DungeonDiagnosticExporter
extends RefCounted

## Exportador canónico de diagnóstico forense y observabilidad estructurada (Fase 17).
## Captura el estado completo de la mazmorra (semillas, timings, capas espaciales, topología,
## puertas, distancias y ASCII) y proporciona reproducibilidad 100% determinista.

const _DungeonAsciiExporterScript = preload("res://src/dungeon_generator/debug/dungeon_ascii_exporter.gd")

## Exporta un reporte forense completo estructurado como Dictionary / JSON.
static func export_diagnostic_report(result: DungeonResult, config: DungeonConfig = null) -> Dictionary:
	if result == null or result.grid == null:
		return {
			"error": "INVALID_DUNGEON_RESULT",
			"message": "DungeonResult or its CellGrid is null"
		}

	var report: Dictionary = {}

	# 1. Metadatos Globales de Identificación
	report["metadata"] = {
		"seed": result.seed_used,
		"floor": result.floor_number,
		"checksum": result.checksum,
		"generation_time_ms": result.generation_time_ms,
		"fitness_score": result.fitness_score,
		"grid_dimensions": {
			"width": result.grid.width,
			"height": result.grid.height,
			"cell_size": config.cell_size if config != null else 2.0
		}
	}

	# 2. Trazabilidad de Semillas y Tiempos por Etapa
	report["seed_trace"] = result.seed_trace

	# 3. Métricas Estructurales y Estéticas
	report["metrics"] = {
		"room_count": result.rooms.size(),
		"connection_count": result.connections.size(),
		"entrance_pair_count": result.entrance_pairs.size(),
		"corridor_path_count": result.corridor_paths.size(),
		"door_count": result.doors.size(),
		"door_pair_count": result.door_pairs.size(),
		"total_walkable_cells": result.grid.count_walkable_cells()
	}
	if "metrics" in result.seed_trace:
		report["metrics"]["pipeline_metrics"] = result.seed_trace["metrics"]

	# 4. Capa de Habitaciones
	var rooms_diag: Array[Dictionary] = []
	for r in result.rooms:
		if r != null:
			rooms_diag.append({
				"id": r.id,
				"room_type": str(r.room_type),
				"rect": {
					"x": r.rect.position.x,
					"y": r.rect.position.y,
					"w": r.rect.size.x,
					"h": r.rect.size.y
				},
				"center": {
					"x": r.get_center().x,
					"y": r.get_center().y
				}
			})
	report["rooms"] = rooms_diag

	# 5. Capa de Topología y Conexiones (MST & Loops)
	var conns_diag: Array[Dictionary] = []
	for c in result.connections:
		if c != null:
			conns_diag.append({
				"id": c.id,
				"room_a": c.room_a_id,
				"room_b": c.room_b_id,
				"is_required": c.is_required,
				"is_loop": not c.is_required
			})
	report["connections"] = conns_diag

	# 6. Capa de Entradas y Puertas
	var doors_diag: Array[Dictionary] = []
	for d in result.doors:
		if d != null:
			doors_diag.append({
				"room_id": d.room_id,
				"connection_id": d.connection_id,
				"position": {"x": d.position.x, "y": d.position.y},
				"side": d.side,
				"door_type": str(d.door_type)
			})
	report["doors"] = doors_diag

	# 7. Capa de Corredores y Estrategias de Ruteo
	var corridors_diag: Array[Dictionary] = []
	for p in result.corridor_paths:
		if p != null:
			var cl_len: int = p.centerline_cells.size() if ("centerline_cells" in p) else 0
			corridors_diag.append({
				"connection_id": p.connection_id,
				"turn_count": p.turn_count,
				"length": cl_len,
				"routing_strategy": str(p.routing_strategy)
			})
	report["corridors"] = corridors_diag

	# 8. Visualización ASCII Integrada
	report["ascii_map"] = _DungeonAsciiExporterScript.export_ascii(result, null, true)

	# 9. Comando de Reproducción Determinista
	report["reproducibility"] = {
		"seed": result.seed_used,
		"floor": result.floor_number,
		"instruction": "var pipeline = DungeonPipeline.new(); var cfg = DungeonConfig.new(); cfg.seed = %d; cfg.use_fixed_seed = true; var res = pipeline.generate(cfg);" % result.seed_used
	}

	return report

## Exporta el reporte estructurado como string JSON formateado.
static func export_json_string(result: DungeonResult, config: DungeonConfig = null, indent: String = "\t") -> String:
	var report := export_diagnostic_report(result, config)
	return JSON.stringify(report, indent)
