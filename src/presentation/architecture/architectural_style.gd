class_name ArchitecturalStyle
extends RefCounted

## Normalizador y utilidades de estilo arquitectónico y decorativo.
## Desacoplado de enums de contenido; opera puramente con identificadores StringName.

static func normalize(value: Variant, default_val: StringName = &"generic") -> StringName:
	if value is StringName:
		return value if not value.is_empty() else default_val
	if value is String:
		var s := (value as String).strip_edges().to_lower()
		return StringName(s) if not s.is_empty() else default_val
	return default_val

static func floor_from_name(name_str: String, default_style: Variant = &"generic_stone") -> StringName:
	var def := normalize(default_style, &"generic_stone")
	var s := name_str.strip_edges().to_lower()
	return StringName(s) if not s.is_empty() else def

static func wall_from_name(name_str: String, default_style: Variant = &"generic_stone") -> StringName:
	var def := normalize(default_style, &"generic_stone")
	var s := name_str.strip_edges().to_lower()
	return StringName(s) if not s.is_empty() else def

static func door_from_name(name_str: String, default_style: Variant = &"stone_arch") -> StringName:
	var def := normalize(default_style, &"stone_arch")
	var s := name_str.strip_edges().to_lower()
	return StringName(s) if not s.is_empty() else def

static func stairs_from_name(name_str: String, default_style: Variant = &"stone") -> StringName:
	var def := normalize(default_style, &"stone")
	var s := name_str.strip_edges().to_lower()
	return StringName(s) if not s.is_empty() else def

static func fixture_from_name(name_str: String, default_style: Variant = &"torch") -> StringName:
	var def := normalize(default_style, &"torch")
	var s := name_str.strip_edges().to_lower()
	return StringName(s) if not s.is_empty() else def

static func palette_from_name(name_str: String, default_palette: Variant = &"generic") -> StringName:
	var def := normalize(default_palette, &"generic")
	var s := name_str.strip_edges().to_lower()
	return StringName(s) if not s.is_empty() else def

static func floor_to_name(style: Variant) -> String:
	return str(normalize(style, &"generic_stone")).to_upper()

static func wall_to_name(style: Variant) -> String:
	return str(normalize(style, &"generic_stone")).to_upper()

static func door_to_name(style: Variant) -> String:
	return str(normalize(style, &"stone_arch")).to_upper()

static func stairs_to_name(style: Variant) -> String:
	return str(normalize(style, &"stone")).to_upper()

static func fixture_to_name(style: Variant) -> String:
	return str(normalize(style, &"torch")).to_upper()

static func palette_to_name(palette: Variant) -> String:
	return str(normalize(palette, &"generic")).to_upper()
