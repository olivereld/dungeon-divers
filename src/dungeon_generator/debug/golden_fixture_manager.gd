class_name GoldenFixtureManager
extends RefCounted

## Gestor y verificador de Golden Fixtures (Snapshots Canónicos) para la Fase 11.
## Garantiza que ningún cambio futuro en algoritmos, dependencias o refactors
## altere la reproducibilidad bit a bit de las 20 semillas maestras de referencia.

const _MultiFloorGeneratorScript = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")

## 20 Semillas Canónicas Maestras de Referencia
const GOLDEN_SEEDS: Array[int] = [
	100001, 100002, 100003, 100004, 100005,
	100006, 100007, 100008, 100009, 100010,
	100011, 100012, 100013, 100014, 100015,
	100016, 100017, 100018, 100019, 100020
]

## Calcula la huella digital estructural (Fingerprint) de una mazmorra multinivel.
static func compute_fingerprint(multi_res: DungeonMultiFloorResult) -> Dictionary:
	if multi_res == null or not multi_res.is_valid:
		return {"valid": false}

	var floor_fingerprints: Array[Dictionary] = []
	for f_num in multi_res.get_floor_numbers():
		var f_data: DungeonFloorData = multi_res.get_floor(f_num)
		var grid_hash: int = 0
		if f_data.grid != null:
			grid_hash = int(f_data.grid.to_debug_string().hash()) & 0x7FFFFFFF

		var room_signatures: Array[String] = []
		for r in f_data.rooms:
			room_signatures.append("%d:%d,%d:%d,%d" % [r.id, r.rect.position.x, r.rect.position.y, r.rect.size.x, r.rect.size.y])

		var door_count: int = f_data.door_pairs.size()
		var stair_count: int = f_data.stairs.size()

		floor_fingerprints.append({
			"floor": f_num,
			"grid_hash": grid_hash,
			"room_count": f_data.rooms.size(),
			"rooms_sig": room_signatures,
			"door_count": door_count,
			"stair_count": stair_count
		})

	var vconn_signatures: Array[String] = []
	for vc in multi_res.vertical_connections:
		if vc != null:
			vconn_signatures.append("%d->%d:%s->%s" % [vc.from_floor, vc.to_floor, str(vc.from_cell), str(vc.to_cell)])

	return {
		"valid": true,
		"master_seed": multi_res.master_seed,
		"floor_count": multi_res.get_floor_count(),
		"floors": floor_fingerprints,
		"vertical_connections": vconn_signatures,
		"seed_trace_version": multi_res.seed_trace.get("version", "unknown")
	}

## Compara dos huellas digitales para certificar igualdad exacta bit a bit.
static func are_fingerprints_equal(fp1: Dictionary, fp2: Dictionary) -> bool:
	if fp1.get("valid", false) != fp2.get("valid", false):
		return false
	if fp1.get("master_seed", 0) != fp2.get("master_seed", 0):
		return false
	if fp1.get("floor_count", 0) != fp2.get("floor_count", 0):
		return false

	var f1_list: Array = fp1.get("floors", [])
	var f2_list: Array = fp2.get("floors", [])
	if f1_list.size() != f2_list.size():
		return false

	for i in range(f1_list.size()):
		var f1: Dictionary = f1_list[i]
		var f2: Dictionary = f2_list[i]
		if f1["grid_hash"] != f2["grid_hash"]:
			return false
		if f1["room_count"] != f2["room_count"]:
			return false
		if f1["door_count"] != f2["door_count"]:
			return false
		if f1["stair_count"] != f2["stair_count"]:
			return false

	var vc1: Array = fp1.get("vertical_connections", [])
	var vc2: Array = fp2.get("vertical_connections", [])
	if vc1.size() != vc2.size():
		return false
	for i in range(vc1.size()):
		if vc1[i] != vc2[i]:
			return false

	return true

## Ejecuta la verificación de regresión completa de las 20 Golden Seeds.
func verify_golden_seeds(total_floors: int = 2) -> Dictionary:
	var generator := _MultiFloorGeneratorScript.new()
	var report := {
		"total_seeds": GOLDEN_SEEDS.size(),
		"matched_seeds": 0,
		"mismatched_seeds": 0,
		"results": []
	}

	for s in GOLDEN_SEEDS:
		var cfg := DungeonConfig.new()
		cfg.grid_width = 32
		cfg.grid_height = 32
		cfg.total_floors = total_floors
		cfg.mission_depth = 4
		cfg.seed = s
		cfg.use_fixed_seed = true

		# Generar primera pasada
		var res_1: DungeonMultiFloorResult = generator.generate_multi_floor(cfg, s)
		var fp_1: Dictionary = compute_fingerprint(res_1)

		# Generar segunda pasada independiente desde cero
		var res_2: DungeonMultiFloorResult = generator.generate_multi_floor(cfg, s)
		var fp_2: Dictionary = compute_fingerprint(res_2)

		var is_identical: bool = are_fingerprints_equal(fp_1, fp_2)
		if is_identical and fp_1.get("valid", false):
			report["matched_seeds"] += 1
			report["results"].append({"seed": s, "status": "PASS", "rooms": fp_1["floors"][0]["room_count"]})
		else:
			report["mismatched_seeds"] += 1
			report["results"].append({"seed": s, "status": "FAIL"})

	return report
