class_name DestructionMode
extends RefCounted

## Modos de resolución de destrucción para props y fixtures.

enum Mode {
	BREAK = 0,
	COLLAPSE = 1,
	EXTINGUISH = 2,
	REPLACE = 3,
	DISABLE = 4
}

static func from_string(p_str: String) -> Mode:
	match p_str.to_lower():
		"break": return Mode.BREAK
		"collapse": return Mode.COLLAPSE
		"extinguish": return Mode.EXTINGUISH
		"replace": return Mode.REPLACE
		"disable": return Mode.DISABLE
		_: return Mode.BREAK

static func to_name(p_mode: Mode) -> String:
	match p_mode:
		Mode.BREAK: return "BREAK"
		Mode.COLLAPSE: return "COLLAPSE"
		Mode.EXTINGUISH: return "EXTINGUISH"
		Mode.REPLACE: return "REPLACE"
		Mode.DISABLE: return "DISABLE"
		_: return "BREAK"
