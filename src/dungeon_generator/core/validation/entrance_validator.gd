class_name EntranceValidator
extends RefCounted

## Validador de invariantes estructurales y geométricos para la resolución de entradas (Fase 4).

const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _EntranceResolutionResultScript = preload("res://src/dungeon_generator/core/solvers/entrance_resolution_result.gd")

class ValidationReport extends RefCounted:
	var is_valid: bool = true
	var errors: Array[String] = []
	var warnings: Array[String] = []

	func add_error(msg: String) -> void:
		is_valid = false
		errors.append(msg)

	func add_warning(msg: String) -> void:
		warnings.append(msg)

	func to_debug_string() -> String:
		var s := "EntranceValidationReport (Valid: %s)\n" % str(is_valid)
		for e in errors:
			s += "  [ERROR] %s\n" % e
		for w in warnings:
			s += "  [WARN]  %s\n" % w
		return s

static func validate(
	resolution: EntranceResolutionResult,
	rooms: Array[RoomData],
	connections: Array,
	grid: CellGrid
) -> ValidationReport:
	var report := ValidationReport.new()

	if resolution == null:
		report.add_error("Resolution result is null.")
		return report

	if not resolution.is_valid:
		report.add_error("Resolution result is explicitly marked invalid.")

	var room_map: Dictionary = {}
	for r in rooms:
		if r != null:
			room_map[r.id] = r

	var conn_map: Dictionary = {}
	for c in connections:
		if c != null:
			conn_map[c.id] = c

	var resolved_conn_ids: Dictionary = {}

	# 1. Validar cada par resuelto
	for pair in resolution.entrance_pairs:
		if pair == null:
			report.add_error("Entrance pair is null.")
			continue

		if not conn_map.has(pair.connection_id):
			report.add_error("EntrancePair references non-existent connection ID: %d" % pair.connection_id)
			continue

		var conn = conn_map[pair.connection_id]
		resolved_conn_ids[pair.connection_id] = true

		var ent_a: RoomEntrance = pair.entrance_a
		var ent_b: RoomEntrance = pair.entrance_b

		if ent_a == null or ent_b == null:
			report.add_error("Connection %d has null entrance endpoint(s)." % pair.connection_id)
			continue

		# Comprobar asignación de sala
		if ent_a.room_id != conn.room_a_id or ent_b.room_id != conn.room_b_id:
			report.add_error("Connection %d room IDs mismatch pair endpoints: (%d, %d) vs (%d, %d)" % [
				pair.connection_id, conn.room_a_id, conn.room_b_id, ent_a.room_id, ent_b.room_id
			])

		var room_a: RoomData = room_map.get(ent_a.room_id, null)
		var room_b: RoomData = room_map.get(ent_b.room_id, null)

		if room_a == null or room_b == null:
			report.add_error("Connection %d references missing RoomData." % pair.connection_id)
			continue

		# Validar geometría de Entrance A
		_validate_entrance_geometry(ent_a, room_a, grid, report, "Entrance A (Conn %d)" % pair.connection_id)

		# Validar geometría de Entrance B
		_validate_entrance_geometry(ent_b, room_b, grid, report, "Entrance B (Conn %d)" % pair.connection_id)

	# 2. Validar que toda conexión obligatoria (mandatory/MST) esté resuelta
	for c in connections:
		if c != null and c.is_required:
			if not resolved_conn_ids.has(c.id):
				report.add_error("Mandatory connection %d (Rooms %d <-> %d) was NOT resolved." % [
					c.id, c.room_a_id, c.room_b_id
				])

	return report

static func _validate_entrance_geometry(
	ent: RoomEntrance,
	room: RoomData,
	grid: CellGrid,
	report: ValidationReport,
	context: String
) -> void:
	if not grid.is_in_bounds(ent.position):
		report.add_error("%s position %s is out of grid bounds." % [context, str(ent.position)])
		return

	if not grid.is_in_bounds(ent.inner_cell):
		report.add_error("%s inner_cell %s is out of grid bounds." % [context, str(ent.inner_cell)])

	if not grid.is_in_bounds(ent.outer_cell):
		report.add_error("%s outer_cell %s is out of grid bounds." % [context, str(ent.outer_cell)])

	# inner_cell debe estar dentro del interior de la sala
	if not room.rect.has_point(ent.inner_cell):
		report.add_error("%s inner_cell %s is not inside room.rect %s." % [context, str(ent.inner_cell), str(room.rect)])

	# boundary_cell (position) debe estar en el perímetro exterior inmediato (no dentro del rect interior)
	if room.rect.has_point(ent.position):
		report.add_error("%s boundary_cell %s is inside room.rect (must be perimeter wall)." % [context, str(ent.position)])

	if not room.expanded(1).has_point(ent.position):
		report.add_error("%s boundary_cell %s is not on room perimeter wall ring." % [context, str(ent.position)])

	# outer_cell debe ser exterior a room.rect
	if room.rect.has_point(ent.outer_cell):
		report.add_error("%s outer_cell %s is inside room.rect." % [context, str(ent.outer_cell)])

	# Coherencia del vector de dirección
	var expected_outward := _RoomEntranceScript.side_to_direction(ent.side)
	if ent.outer_cell - ent.position != expected_outward:
		report.add_error("%s outer_cell delta does not match side outward vector." % context)
	if ent.position - ent.inner_cell != expected_outward:
		report.add_error("%s inner_cell delta does not match side inward vector." % context)
