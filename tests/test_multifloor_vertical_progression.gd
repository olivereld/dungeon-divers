extends SceneTree

## Test suite para validar la Progresión Vertical Global (VerticalProgressionSolver).
## Verifica que el Boss solo se asigne en el piso final y que los roles semánticos sean correctos.

const VerticalProgressionSolver = preload("res://src/dungeon_generator/core/multilevel/vertical_progression_solver.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_multifloor_vertical_progression (Roles & Boss) ---")
	print("==================================================================")

	var solver := VerticalProgressionSolver.new()

	# 1. Caso 1: Mazmorra de 1 solo piso -> Boss activado
	var cfg1 := DungeonConfig.new()
	cfg1.total_floors = 1
	cfg1.boss_enabled = true
	var roles1 = solver.solve_progression_roles(cfg1)
	assert(roles1.size() == 1)
	assert(roles1[0].is_entry_floor == true)
	assert(roles1[0].is_boss_floor == true)
	assert(roles1[0].boss_enabled == true)
	assert(roles1[0].requires_stair_down == false)
	assert(roles1[0].requires_stair_up == false)
	print("  [OK] Caso 1: Mazmorra de 1 piso configurada con Boss y sin escaleras.")

	# 2. Caso 2: Torre de 3 pisos -> F0 (Start, sin Boss), F1 (Intermedio, sin Boss), F2 (Final, con Boss)
	var cfg3 := DungeonConfig.new()
	cfg3.total_floors = 3
	cfg3.boss_enabled = true
	var roles3 = solver.solve_progression_roles(cfg3)
	assert(roles3.size() == 3)

	# F0
	assert(roles3[0].floor_number == 0)
	assert(roles3[0].is_entry_floor == true)
	assert(roles3[0].is_boss_floor == false)
	assert(roles3[0].boss_enabled == false, "Floor 0 must NOT have boss when total_floors > 1")
	assert(roles3[0].requires_stair_down == true)
	assert(roles3[0].requires_stair_up == false)

	# F1
	assert(roles3[1].floor_number == 1)
	assert(roles3[1].is_entry_floor == false)
	assert(roles3[1].is_boss_floor == false)
	assert(roles3[1].boss_enabled == false, "Floor 1 must NOT have boss when total_floors > 1")
	assert(roles3[1].requires_stair_down == true)
	assert(roles3[1].requires_stair_up == true)

	# F2
	assert(roles3[2].floor_number == 2)
	assert(roles3[2].is_entry_floor == false)
	assert(roles3[2].is_boss_floor == true)
	assert(roles3[2].boss_enabled == true, "Floor 2 (Final) MUST have boss")
	assert(roles3[2].requires_stair_down == false)
	assert(roles3[2].requires_stair_up == true)
	print("  [OK] Caso 2: Progresión de 3 pisos validada (Boss aislado exclusivamente en el piso 2).")

	print("==================================================================")
	print("[PASS] test_multifloor_vertical_progression completado con éxito!")
	print("==================================================================")
	quit(0)
