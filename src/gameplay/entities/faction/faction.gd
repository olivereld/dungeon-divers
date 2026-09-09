# faction.gd
class_name Faction
extends RefCounted

var _id: FactionId.Type
var _display_name: String

func _init(p_id: FactionId.Type, p_display_name: String = "") -> void:
	_id = p_id
	_display_name = p_display_name

var id: FactionId.Type:
	get: return _id

var display_name: String:
	get: return _display_name

func is_same_faction(other: Faction) -> bool:
	return other != null and other.id == _id
