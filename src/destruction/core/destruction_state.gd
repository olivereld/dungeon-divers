class_name DestructionState
extends RefCounted

## Estados de integridad física de un objeto destructible.

enum State {
	INTACT = 0,
	DAMAGED = 1,
	CRITICAL = 2,
	DESTROYED = 3
}

static func to_name(p_state: State) -> String:
	match p_state:
		State.INTACT: return "INTACT"
		State.DAMAGED: return "DAMAGED"
		State.CRITICAL: return "CRITICAL"
		State.DESTROYED: return "DESTROYED"
		_: return "INTACT"
