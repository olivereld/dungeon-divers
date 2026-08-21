class_name MeshGalleryEntry
extends RefCounted

## Contrato declarativo inmutable para un elemento inspeccionable en el Mesh Generation Lab.

var id: StringName = &""
var category_id: StringName = &""
var category_name: String = ""
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
	p_params: Dictionary = {}
) -> void:
	id = p_id
	category_id = p_cat_id
	category_name = p_cat_name
	name = p_name
	script_path = p_script
	description = p_desc
	generator_id = p_generator_id
	default_params = p_params

## Valida si la entrada cumple con los campos obligatorios.
func is_valid() -> bool:
	return not id.is_empty() and not generator_id.is_empty()

func _to_string() -> String:
	return "MeshGalleryEntry(id='%s', cat='%s', gen='%s')" % [id, category_id, generator_id]
