class_name BlockResult
extends RefCounted


var blocked: bool
var blocked_amount: float


func _init(
	p_blocked: bool,
	p_blocked_amount: float
) -> void:
	assert(p_blocked_amount >= 0.0)

	blocked = p_blocked
	blocked_amount = p_blocked_amount