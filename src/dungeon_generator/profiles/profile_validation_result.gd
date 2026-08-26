class_name ProfileValidationResult
extends RefCounted

## Resultado de validación estricta para ProfileBundle, Archetypes y Rooms.

var is_valid: bool = true
var errors: Array[String] = []
var warnings: Array[String] = []

func add_error(msg: String) -> void:
	is_valid = false
	errors.append(msg)

func add_warning(msg: String) -> void:
	warnings.append(msg)

func merge(other: ProfileValidationResult) -> void:
	if other == null:
		return
	if not other.is_valid:
		is_valid = false
	errors.append_array(other.errors)
	warnings.append_array(other.warnings)

func to_summary_string() -> String:
	if is_valid:
		return "ProfileValidationResult: PASSED (%d warnings)" % warnings.size()
	return "ProfileValidationResult: FAILED (%d errors, %d warnings)\n- %s" % [
		errors.size(),
		warnings.size(),
		"\n- ".join(errors)
	]
