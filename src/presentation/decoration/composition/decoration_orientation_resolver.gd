class_name DecorationOrientationResolver
extends RefCounted

## Resolver matemático y determinista de orientación angular para elementos de decoración.
## Garantiza que muebles pegados a muros miren hacia el interior de la sala (FACE_ROOM),
## o hacia el foco/centro (FACE_CENTER), sin hardcodes por tipo de objeto.

const _DecorationOrientationModeScript = preload("res://src/presentation/decoration/composition/decoration_orientation_mode.gd")

func resolve_rotation(anchor, mode: int, room_center_world: Vector3 = Vector3.ZERO) -> float:
	if anchor == null:
		return 0.0

	var anchor_rot: float = anchor.rotation_degrees_y

	match mode:
		_DecorationOrientationModeScript.Mode.FACE_ROOM:
			# El anclaje de pared ya calcula la rotación mirando hacia la sala (normal hacia el interior)
			return anchor_rot

		_DecorationOrientationModeScript.Mode.FACE_WALL:
			# Rotar 180° con respecto al frente del muro
			return fposmod(anchor_rot + 180.0, 360.0)

		_DecorationOrientationModeScript.Mode.FACE_CENTER:
			if room_center_world != Vector3.ZERO and anchor != null:
				var a_pos: Vector3 = anchor.world_position if "world_position" in anchor else Vector3.ZERO
				var dir: Vector3 = (room_center_world - a_pos).normalized()
				var angle_rad: float = atan2(dir.x, dir.z)
				return rad_to_deg(angle_rad)
			return anchor_rot

		_DecorationOrientationModeScript.Mode.ALIGN_WALL:
			# Alineación paralela al muro (+90° respecto a la normal)
			return fposmod(anchor_rot + 90.0, 360.0)

		_DecorationOrientationModeScript.Mode.ALIGN_AXIS:
			# Alinear al eje cardinal más cercano (0, 90, 180, 270)
			var snapped_deg = roundf(anchor_rot / 90.0) * 90.0
			return fposmod(snapped_deg, 360.0)

		_DecorationOrientationModeScript.Mode.FREE:
			return anchor_rot

		_:
			return anchor_rot
