class_name RoomTemplateResolver
extends RefCounted

## Resolutor determinista y tolerante a fallos de RoomTemplates.
## Evalúa restricciones geométricas, espaciales y semánticas para seleccionar
## la plantilla idónea o recurrir a un fallback procedimental garantizado.

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeometryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntrancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _RegistryScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_registry.gd")
const _ValidatorScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_validator.gd")
const _MatcherScript = preload("res://src/dungeon_generator/core/room_templates/matcher/room_template_matcher.gd")
const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")

var _registry: _RegistryScript = null
var _validator: _ValidatorScript = null
var _matcher: _MatcherScript = null
var _fallback_template: _RoomTemplateScript = null

func _init(p_registry: _RegistryScript = null, p_validator: _ValidatorScript = null) -> void:
	_registry = p_registry
	_validator = p_validator if p_validator != null else _ValidatorScript.new()
	_matcher = _MatcherScript.new(_registry)
	_init_fallback_template()

func _init_fallback_template() -> void:
	var geom := _GeometryPolicyScript.new([&"open_rectangle", &"rectangle"], 1, 999, 1, 999, 1, 999999, 0.01, 100.0)
	var ent := _EntrancePolicyScript.new(0, 99, [&"north", &"south", &"east", &"west", &"corner"], true, 0)
	_fallback_template = _RoomTemplateScript.new(
		&"procedural_fallback",
		"Procedural Fallback Rectangle",
		[&"fallback", &"generic"],
		geom,
		ent
	)

func get_fallback_template() -> _RoomTemplateScript:
	return _fallback_template

func resolve_template(
	room: RoomData,
	profile: _ProfileRoomScript = null,
	entrances: Array[Vector2i] = [],
	p_seed: int = 0
) -> _RoomTemplateScript:
	if room == null:
		return _fallback_template

	if _registry == null:
		return _fallback_template

	var purpose: StringName = room.room_type
	var candidates: Array[_RoomTemplateScript] = []

	# 1. Obtener candidatos desde restricciones de ProfileRoom si existen
	if profile != null and profile.template_constraints != null:
		var tc = profile.template_constraints
		if not tc.allowed_templates.is_empty():
			for t_id in tc.allowed_templates:
				if not tc.is_template_forbidden(t_id):
					var tpl = _registry.get_template(t_id)
					if tpl != null:
						candidates.append(tpl)
		else:
			for tpl in _registry.get_all_templates():
				if not tc.is_template_forbidden(tpl.id):
					candidates.append(tpl)
	else:
		candidates = _registry.get_all_templates()

	if candidates.is_empty():
		return _fallback_template

	# 2. Filtrar y puntuar candidatos válidos
	var scored_candidates: Array[Dictionary] = [] # Array de { "template": RoomTemplate, "score": int }

	for tpl in candidates:
		if not _matcher.is_compatible(tpl, room, profile, entrances):
			continue

		var score: int = 0

		# 1. Preferencias explícitas de ProfileRoom
		if profile != null and profile.template_constraints != null:
			var tc = profile.template_constraints
			if tc.is_template_preferred(tpl.id):
				score += 100
			elif tc.is_template_allowed(tpl.id):
				score += 50

			# Required tags matching (+20)
			for req_tag in tc.required_tags:
				if tpl.tags.has(req_tag):
					score += 20

		# 2. Semantic Purpose matching
		if not purpose.is_empty():
			if tpl.preferred_purposes.has(purpose):
				score += 40
			elif tpl.allowed_purposes.has(purpose):
				score += 20
			elif tpl.allowed_purposes.is_empty():
				score += 5

		# 3. Size and aspect ratio fit bonus (+10)
		var geom = tpl.geometry
		if geom != null and room.rect.size.x >= geom.min_width and room.rect.size.y >= geom.min_depth:
			score += 10

		scored_candidates.append({
			"template": tpl,
			"score": score
		})

	if scored_candidates.is_empty():
		return _fallback_template

	# 3. Ordenar deterministamente por score DESC, luego ID ASC
	scored_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return str(a["template"].id) < str(b["template"].id)
	)

	var max_score: int = scored_candidates[0]["score"]
	var top_candidates: Array[_RoomTemplateScript] = []
	for item in scored_candidates:
		if item["score"] == max_score:
			top_candidates.append(item["template"])
		else:
			break

	if top_candidates.size() == 1:
		return top_candidates[0]

	# Selección pseudoaleatoria determinista entre los empatados
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var chosen_idx := rng.randi_range(0, top_candidates.size() - 1)
	return top_candidates[chosen_idx]
