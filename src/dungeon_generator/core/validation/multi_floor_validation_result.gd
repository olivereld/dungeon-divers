class_name MultiFloorValidationResult
extends RefCounted

## Resultado de validación formal de mazmorra multinivel (Fase 10).

var is_valid: bool = false
var is_connected: bool = false
var endpoints_valid: bool = false
var path_exists: bool = false
var errors: Array[String] = []
var warnings: Array[String] = []

func add_error(msg: String) -> void:
	errors.append(msg)
	is_valid = false

func add_warning(msg: String) -> void:
	warnings.append(msg)

func to_debug_string() -> String:
	var s := "=== MULTI-FLOOR VALIDATION RESULT (Valid: %s) ===\n" % str(is_valid)
	s += "  Connected: %s, Endpoints: %s, Path: %s\n" % [
		str(is_connected), str(endpoints_valid), str(path_exists)
	]
	if not errors.is_empty():
		s += "  Errors (%d):\n" % errors.size()
		for err in errors:
			s += "    - [ERROR] %s\n" % err
	if not warnings.is_empty():
		s += "  Warnings (%d):\n" % warnings.size()
		for warn in warnings:
			s += "    - [WARN] %s\n" % warn
	return s
