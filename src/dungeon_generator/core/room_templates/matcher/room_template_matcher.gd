class_name RoomTemplateMatcher
extends RefCounted

## Emparejador inteligente de RoomTemplates según propósito semántico y criterios espaciales.

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _RegistryScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_registry.gd")
const _ValidatorScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_validator.gd")
const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")

var _registry: _RegistryScript = null
var _validator := _ValidatorScript.new()

func _init(p_registry: _RegistryScript = null) -> void:
	_registry = p_registry

## Determina si una plantilla es estrictamente compatible con una habitación y sus restricciones.
func is_compatible(
	template: _RoomTemplateScript,
	room: RoomData,
	profile: _ProfileRoomScript = null,
	entrances: Array[Vector2i] = []
) -> bool:
	if template == null or room == null:
		return false

	# 1. Compatibilidad de propósito semántico
	var effective_purpose: StringName = profile.id if profile != null else room.room_type
	if not template.allowed_purposes.is_empty():
		if not template.allowed_purposes.has(effective_purpose):
			return false

	# 2. Restricciones de ProfileRoom si existen
	if profile != null and profile.template_constraints != null:
		var tc = profile.template_constraints
		if tc.is_template_forbidden(template.id):
			return false
		if not tc.allowed_templates.is_empty() and not tc.is_template_allowed(template.id):
			return false
		for req_tag in tc.required_tags:
			if not template.tags.has(req_tag):
				return false

	# 3. Validación geométrica y de entradas mediante el Validator
	var val_res = _validator.validate_all(template, room.rect, entrances)
	return val_res.is_valid

## Explica detalladamente las razones de incompatibilidad de una plantilla (si las hay).
func explain_compatibility(
	template: _RoomTemplateScript,
	room: RoomData,
	profile: _ProfileRoomScript = null,
	entrances: Array[Vector2i] = []
) -> Array[String]:
	var reasons: Array[String] = []
	if template == null:
		reasons.append("Template is null")
		return reasons
	if room == null:
		reasons.append("Room is null")
		return reasons

	var effective_purpose: StringName = profile.id if profile != null else room.room_type
	if not template.allowed_purposes.is_empty():
		if not template.allowed_purposes.has(effective_purpose):
			reasons.append("Purpose '%s' not in allowed: %s" % [effective_purpose, str(template.allowed_purposes)])

	if profile != null and profile.template_constraints != null:
		var tc = profile.template_constraints
		if tc.is_template_forbidden(template.id):
			reasons.append("Template '%s' is explicitly forbidden in profile" % template.id)
		if not tc.allowed_templates.is_empty() and not tc.is_template_allowed(template.id):
			reasons.append("Template '%s' not in profile allowed list" % template.id)
		for req_tag in tc.required_tags:
			if not template.tags.has(req_tag):
				reasons.append("Missing required profile tag '%s'" % req_tag)

	var val_res = _validator.validate_all(template, room.rect, entrances)
	if not val_res.is_valid:
		for err in val_res.errors:
			reasons.append("Geometry/Entrance validation: %s" % err)

	return reasons

## Filtra y devuelve únicamente las plantillas compatibles de una lista.
func filter_compatible_templates(
	templates: Array[_RoomTemplateScript],
	room: RoomData,
	profile: _ProfileRoomScript = null,
	entrances: Array[Vector2i] = []
) -> Array[_RoomTemplateScript]:
	var compatible: Array[_RoomTemplateScript] = []
	for tpl in templates:
		if is_compatible(tpl, room, profile, entrances):
			compatible.append(tpl)
	return compatible

func find_compatible_templates(purpose_id: StringName) -> Array[_RoomTemplateScript]:
	var result: Array[_RoomTemplateScript] = []
	if _registry == null:
		return result

	for tpl in _registry.get_all_templates():
		if tpl.is_purpose_allowed(purpose_id):
			result.append(tpl)

	return result
