extends SceneTree

## Test unitario de validación de geometrías y accesos para RoomTemplate

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeometryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntrancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _ValidatorScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_validator.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_validator ---")
	var validator := _ValidatorScript.new()

	var geom := _GeometryPolicyScript.new([&"rectangle"], 7, 13, 7, 15, 49, 195, 0.65, 1.5)
	var ent := _EntrancePolicyScript.new(1, 2, [&"north", &"south", &"east", &"west"], false, 3)
	var tpl := _RoomTemplateScript.new(&"sacristy", "Sacristy", [], geom, ent)

	# 1. Rectángulo válido (9x11 -> Area: 99, Aspect: 0.81)
	var valid_rect := Rect2i(10, 10, 9, 11)
	var res_valid = validator.validate_rect(tpl, valid_rect)
	assert(res_valid.is_valid, "FAIL: 9x11 rect should be valid")

	# 2. Rectángulo degenerado (2x20 -> Demasiado estrecho, Aspect: 0.1)
	var invalid_narrow := Rect2i(0, 0, 2, 20)
	var res_narrow = validator.validate_rect(tpl, invalid_narrow)
	assert(not res_narrow.is_valid, "FAIL: 2x20 rect must be rejected")

	# 3. Rectángulo demasiado pequeño (4x4 -> Area: 16)
	var invalid_small := Rect2i(0, 0, 4, 4)
	var res_small = validator.validate_rect(tpl, invalid_small)
	assert(not res_small.is_valid, "FAIL: 4x4 rect must be rejected")

	# 4. Validar accesos válidos
	var entrances_valid: Array[Vector2i] = [
		Vector2i(14, 10), # Norte
		Vector2i(14, 20)  # Sur (espaciado > 3)
	]
	var res_ent_valid = validator.validate_entrances(tpl, valid_rect, entrances_valid)
	assert(res_ent_valid.is_valid, "FAIL: valid entrances should pass")

	# 5. Validar acceso en esquina prohibida
	var entrances_corner: Array[Vector2i] = [
		Vector2i(10, 10) # Esquina noroeste
	]
	var res_corner = validator.validate_entrances(tpl, valid_rect, entrances_corner)
	assert(not res_corner.is_valid, "FAIL: corner entrance must be rejected")

	# 6. Validar accesos demasiado juntos (distancia < 3)
	var entrances_close: Array[Vector2i] = [
		Vector2i(12, 10),
		Vector2i(13, 10)
	]
	var res_close = validator.validate_entrances(tpl, valid_rect, entrances_close)
	assert(not res_close.is_valid, "FAIL: entrances with spacing < 3 must be rejected")

	print("PASS: test_room_template_validator passed successfully!")
	quit(0)
