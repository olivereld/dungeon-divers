# Contratos Canónicos de Datos y Titularidad (Fase 1)

> **Documento Canónico de Propiedad de Datos e Invariantes Estructurales**
> **Fecha:** 2026-08-18
> **Estado:** Aprobado — Inmutable para las Fases 2 a 19.

---

## 1. Principio Fundamental de Titularidad

> **Cada dato debe tener un único propietario autorizado.**
> Si dos estructuras representan o manipulan la misma información, se elimina la redundancia y se elige la fuente canónica.

---

## 2. Mapa Canónico de Estructuras de Datos

### 2.1 `RoomData`
- **Definición**: `Identidad + Geometría AABB + Semántica básica`.
- **Campos Canónicos**:
  - `id: int`: Identificador numérico único de la habitación.
  - `rect: Rect2i`: Rectángulo delimitador 2D en coordenadas de cuadrícula.
  - `room_type: StringName`: Tipo arquetípico base (`&"start"`, `&"explore"`, `&"combat"`, `&"boss"`, `&"treasure"`, `&"puzzle"`, `&"goal"`).
  - `mission_node_id: int`: ID del nodo asociado en el grafo de misiones.
  - `is_required: bool`: Indica si la sala es obligatoria para la misión.
  - `depth_in_graph: int`: Profundidad en el árbol topológico.
- **Prohibido en `RoomData`**:
  - NO almacena aristas ni arrays de conexiones (`connections` / `connected_room_ids` eliminados). La topología pertenece a `RoomConnection`.

### 2.2 `RoomGraph` y `RoomConnection`
- **Definición**: `Relaciones y adyacencias topológicas no dirigidas entre habitaciones`.
- **Campos Canónicos de `RoomConnection`**:
  - `id: int`: ID único de la conexión lógica.
  - `room_a_id: int`: ID de la primera habitación.
  - `room_b_id: int`: ID de la segunda habitación.
  - `is_required: bool`: Si pertenece al Árbol de Expansión Mínima (MST) o es una arista de ciclo opcional.
  - `connection_type: StringName`: Tipo de enlace (`&"corridor"`, `&"staircase"`).
- **Propietario Exclusivo**: `RoomGraphBuilder` (creador) y `DungeonGenerationContext.connections`.

### 2.3 `CellGrid`
- **Definición**: `Única fuente de verdad del espacio discreto 2D`.
- **Estructura Interna**: Array lineal `PackedInt32Array` de tamaño `width * height`.
- **Tipos de Celda**: `VOID`, `WALL`, `FLOOR`, `DOOR`, `LOCKED_DOOR`, `STAIRS_DOWN`, `STAIRS_UP`, `SPAWN`, `OBJECTIVE`, `CORRIDOR`, `COLUMN`, `OBSTACLE`.
- **Mutadores Autorizados por Etapa**:
  1. `RoomShapeGenerator`: Escribe `FLOOR` en los recintos de salas.
  2. `AStarCarver`: Escribe `CORRIDOR` en las trayectorias de pasillos.
  3. `DoorResolver`: Escribe `DOOR` / `LOCKED_DOOR` en los umbrales de puerta.
  4. `MultiFloorGenerator`: Escribe `STAIRS_DOWN` / `STAIRS_UP`.
- **Lectores Puros**: Presentation 3D, Visualizer 2D, Exportadores, Validadores.

### 2.4 `EntrancePair` vs `DoorPair`
- **`EntrancePair` (Intermedio de Routing)**:
  - Par de candidatos geométricos perimetrales (`EntrancePoint`: celda muro, celda exterior, dirección de salida) producidos por `EntranceSolver`.
  - Utilizado exclusivamente por `AStarCarver` como puntos inicial y final para el tallado ortogonal.
- **`DoorPair` (Canónico Definitivo)**:
  - Contenedor final de las dos entidades de puerta (`DoorPlacement`) vinculadas a una `RoomConnection` aceptada.
  - Validado físicamente por `DoorPhysicalValidator` (existencia de jambas de muro laterales paralelas).
  - Utilizado por `SemanticOrchestrator` y `DungeonDoorSpawner` para la instanciación física 3D y 2D.

### 2.5 `DungeonSemanticResult` (Semántica y Progresión)
- **Definición**: `Contenedor inmutable de estado de juego, flujo crítico y pacing`.
- **Propietario Exclusivo**: `SemanticOrchestrator`.
- **Campos Canónicos**:
  - `start_room_id: int`, `boss_room_id: int`.
  - `critical_path_rooms: Array[int]`, `critical_path_connections: Array[int]`.
  - `depth_map: Dictionary`.
  - `key_placements: Array`, `locked_doors: Array`.
- **Invariante**: No muta `CellGrid` ni la topología física; aporta la capa lógica de progresión.

### 2.6 `DungeonResult` y `DungeonMultiFloorResult` (Transferencia)
- **Definición**: `Contenedores finales de entrega inmutables`.
- **Propietario**: Ensamblados al final del pipeline para ser consumidos por el sistema de juego / renderizador.

---

## 3. Matriz de Preguntas de Gate de la Fase 1

| Pregunta | Respuesta Canónica |
| :--- | :--- |
| **¿Dónde vive la geometría de una sala?** | En `RoomData.rect` (AABB) y sus celdas `FLOOR` en `CellGrid`. |
| **¿Dónde vive la topología y conectividad entre salas?** | En `RoomConnection` dentro de `DungeonResult.connections` (nunca en `RoomData`). |
| **¿Dónde vive el estado transitable/sólido de cada celda?** | Exclusivamente en `CellGrid`. |
| **¿Dónde viven las puertas físicas validadas?** | En `DoorPair` dentro de `DungeonResult.door_pairs`. |
| **¿Dónde viven las llaves y cerraduras?** | En `DungeonSemanticResult.key_placements` y `locked_doors`. |
| **¿Quién puede mutar el `CellGrid`?** | Únicamente las etapas activas del generador durante la fase de tallado (nunca el renderizador ni los validadores). |

---

## 4. Gate de Salida

- **PHASE GATE**: **`PASS`**
- Todos los contratos de datos han sido congelados y verificados con la suite de pruebas automatizadas.
