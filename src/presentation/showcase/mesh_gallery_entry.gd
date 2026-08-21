class_name MeshGalleryEntry
extends RefCounted

## Contrato declarativo inmutable para un elemento inspeccionable en el Mesh Generation Lab.

var id: StringName = &""
var category_id: StringName = &""
var category_name: String = ""
var group_id: StringName = &""
var group_name: String = ""
var variant_name: String = ""
var name: String = ""
var script_path: String = ""
var description: String = ""
var generator_id: StringName = &""
var default_params: Dictionary = {}

func _init(
	p_id: StringName = &"",
	p_cat_id: StringName = &"",
	p_cat_name: String = "",
	p_name: String = "",
	p_script: String = "",
	p_desc: String = "",
	p_generator_id: StringName = &"",
	p_params: Dictionary = {},
	p_group_id: StringName = &"",
	p_group_name: String = "",
	p_variant_name: String = ""
) -> void:
	id = p_id
	category_id = p_cat_id
	category_name = p_cat_name
	name = p_name
	script_path = p_script
	description = p_desc
	generator_id = p_generator_id
	default_params = p_params
	group_id = p_group_id if not p_group_id.is_empty() else p_id
	group_name = p_group_name if not p_group_name.is_empty() else p_name
	variant_name = p_variant_name if not p_variant_name.is_empty() else p_name

## Valida si la entrada cumple con los campos obligatorios.
func is_valid() -> bool:
	return not id.is_empty() and not generator_id.is_empty()

func _to_string() -> String:
	return "MeshGalleryEntry(id='%s', group='%s', var='%s', cat='%s', gen='%s')" % [id, group_id, variant_name, category_id, generator_id]

