class_name ProfileRoomTemplateConstraints
extends RefCounted

## Restricciones y preferencias de RoomTemplates para una sala específica deserializadas desde rooms/*.json ("templates").

var allowed_templates: Array[StringName] = []
var preferred_templates: Array[StringName] = []
var forbidden_templates: Array[StringName] = []
var required_tags: Array[StringName] = []

func _init(
	p_allowed: Array[StringName] = [],
	p_preferred: Array[StringName] = [],
	p_forbidden: Array[StringName] = [],
	p_tags: Array[StringName] = []
) -> void:
	allowed_templates = p_allowed
	preferred_templates = p_preferred
	forbidden_templates = p_forbidden
	required_tags = p_tags

func is_template_allowed(template_id: StringName) -> bool:
	if is_template_forbidden(template_id):
		return false
	if allowed_templates.is_empty():
		return true
	return allowed_templates.has(template_id)

func is_template_preferred(template_id: StringName) -> bool:
	return preferred_templates.has(template_id)

func is_template_forbidden(template_id: StringName) -> bool:
	return forbidden_templates.has(template_id)
