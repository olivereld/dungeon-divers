class_name RoomTemplateValidationResult
extends RefCounted

## Objeto de diagnóstico tipado para el resultado de validación de un RoomTemplate.

var is_valid: bool = true
var errors: Array[String] = []
var warnings: Array[String] = []

func _init(p_is_valid: bool = true, p_errors: Array[String] = [], p_warnings: Array[String] = []) -> void:
	is_valid = p_is_valid
	errors = p_errors
	warnings = p_warnings

func add_error(error_msg: String) -> void:
	errors.append(error_msg)
	is_valid = false

func add_warning(warn_msg: String) -> void:
	warnings.append(warn_msg)
