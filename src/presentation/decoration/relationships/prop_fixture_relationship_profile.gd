class_name PropFixtureRelationshipProfile
extends Resource

## Perfil que agrupa el conjunto de relaciones semánticas Prop -> Fixture para un arquetipo o habitación.

const _PropFixtureRelationScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation.gd")

@export var profile_id: StringName = &"default_relations"
@export var relations: Array[_PropFixtureRelationScript] = []

func _init(p_id: StringName = &"default_relations", p_relations: Array[_PropFixtureRelationScript] = []) -> void:
	profile_id = p_id
	relations = p_relations

func get_relations_for_prop(prop_style_id: StringName) -> Array[_PropFixtureRelationScript]:
	var result: Array[_PropFixtureRelationScript] = []
	for r in relations:
		if r != null and r.prop_style_id == prop_style_id:
			result.append(r)
	return result

func is_fixture_forbidden(prop_style_id: StringName, fixture_type: int, fixture_id: StringName) -> bool:
	for r in relations:
		if r != null and r.prop_style_id == prop_style_id:
			if r.forbidden_fixture_types.has(fixture_type) or r.forbidden_fixture_ids.has(fixture_id):
				return true
	return false
