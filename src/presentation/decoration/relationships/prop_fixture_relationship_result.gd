class_name PropFixtureRelationshipResult
extends RefCounted

## Contenedor estructurado de resultados y diagnósticos espaciales de relaciones Prop -> Fixture.

const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")

var directives: Array[_FixtureDirectiveScript] = []
var diagnostics: Array[Dictionary] = []

func _init(p_directives: Array[_FixtureDirectiveScript] = [], p_diagnostics: Array[Dictionary] = []) -> void:
	directives = p_directives
	diagnostics = p_diagnostics

func is_all_satisfied() -> bool:
	for diag in diagnostics:
		if not diag.get("satisfied", true):
			return false
	return true

func get_diagnostics_for_relation(relation_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for diag in diagnostics:
		if diag.get("relation_id", &"") == relation_id:
			result.append(diag)
	return result
