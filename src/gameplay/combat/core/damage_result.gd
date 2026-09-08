class_name DamageResult
extends RefCounted

var raw_damage: float
var mitigated_damage: float
var final_damage: float

var damage_type: DamageType.Type

var was_critical: bool
var was_blocked: bool
var was_miss: bool