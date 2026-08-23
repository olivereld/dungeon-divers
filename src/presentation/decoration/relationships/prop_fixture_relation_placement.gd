class_name PropFixtureRelationPlacement
extends RefCounted

## Taxonomía de disposiciones espaciales relativas entre un Prop y su Fixture asociado.

enum Placement {
	NEAR = 0,    ## Cualquier celda adyacente válida (distancia 1-2 celdas)
	LEFT = 1,    ## Lado izquierdo local relativo a la orientación del prop
	RIGHT = 2,   ## Lado derecho local relativo a la orientación del prop
	ABOVE = 3,   ## Cenital / suspendido directamente sobre el prop
	FRONT = 4,   ## Frente al prop (dirección 'face room' / forward)
	BACK = 5,    ## Detrás del prop (entre prop y muro)
	SURFACE = 6  ## Sobre la superficie superior del prop (elevación Y=0.85m)
}
