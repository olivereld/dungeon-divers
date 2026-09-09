# species.gd
# Componente de especie. Se adjunta vía Entity.add_capability("species", ...).
# Mismo patrón que Faction: envuelve un SpeciesId con identidad inmutable.
class_name Species
extends RefCounted

var _id: SpeciesId.Type
var _display_name: String

func _init(p_id: SpeciesId.Type, p_display_name: String = "") -> void:
	_id = p_id
	_display_name = p_display_name

var id: SpeciesId.Type:
	get: return _id

var display_name: String:
	get: return _display_name

func is_same_species(other: Species) -> bool:
	return other != null and other.id == _id
