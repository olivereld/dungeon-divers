class_name DungeonPresentationResult
extends RefCounted

## Contenedor de datos del resultado de la materialización 3D (Fase 8).
## Encapsula el estado de la presentación activa, conteo de tiles, entidades y diagnósticos.

var success: bool = false
var staging_committed: bool = false
var previous_presentation_preserved: bool = false
var presentation_root: Node3D = null # Representa siempre la presentación actualmente ACTIVA en escena
var spawned_entities: Array = []     # Array[Node]
var total_tiles_rendered: int = 0
var diagnostics: Array[Dictionary] = []

func has_blocking_errors() -> bool:
	for d in diagnostics:
		var sev: String = str(d.get("severity", "INFO")).to_upper()
		if sev == "ERROR" or sev == "FATAL":
			return true
	return false

func can_commit() -> bool:
	return not has_blocking_errors()

func add_diagnostic(
	code: String,
	severity: String,
	stage: String,
	message: String,
	entity_id = null
) -> void:
	diagnostics.append({
		"code": code,
		"severity": severity.to_upper(),
		"stage": stage,
		"entity_id": entity_id,
		"message": message
	})

func to_debug_string() -> String:
	var s := "=== DUNGEON PRESENTATION RESULT ===\n"
	s += "Success: %s, Staging Committed: %s, Previous Preserved: %s\n" % [
		str(success), str(staging_committed), str(previous_presentation_preserved)
	]
	s += "Active Root: %s, Tiles Rendered: %d, Spawned Entities: %d\n" % [
		str(presentation_root), total_tiles_rendered, spawned_entities.size()
	]
	if not diagnostics.is_empty():
		s += "Diagnostics (%d):\n" % diagnostics.size()
		for d in diagnostics:
			s += "  [%s] (%s) %s: %s\n" % [
				str(d.get("severity")), str(d.get("stage")), str(d.get("code")), str(d.get("message"))
			]
	return s
