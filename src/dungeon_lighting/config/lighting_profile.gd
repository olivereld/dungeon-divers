class_name LightingProfile
extends Resource

## Perfil estético y visual de iluminación 3D (colores, intensidad, atenuación y flicker).

@export_group("Luz Base (OmniLight3D)")
@export var light_color: Color = Color(1.0, 0.62, 0.22, 1.0) # Ámbar cálido intenso tipo antorcha de fantasía
@export_range(0.1, 10.0, 0.1) var energy: float = 2.8
@export_range(1.0, 30.0, 0.5) var omni_range: float = 8.5
@export_range(0.1, 4.0, 0.1) var attenuation: float = 1.0
@export var shadow_enabled: bool = false
@export_range(0.0, 1.0, 0.05) var shadow_bias: float = 0.15

@export_group("Parpadeo Orgánico (Flicker)")
@export var flicker_enabled: bool = true
@export_range(0.01, 0.5, 0.01) var flicker_amplitude: float = 0.12 # Variación del +/-12% de energía
@export_range(0.5, 20.0, 0.5) var flicker_speed: float = 5.0       # Frecuencia temporal de parpadeo

@export_group("Modelo / Escena de Antorcha")
@export var torch_scene: PackedScene = null
@export var wall_mount_height: float = 1.65 # Altura en metros sobre el suelo
@export var wall_mount_offset: float = 0.35 # Desplazamiento hacia el interior desde la pared
