class_name MoveData
extends Resource

## Descripción de datos de un movimiento de combate.
##
## Centraliza todo lo que define a un golpe para que el Fighter solo tenga que
## leer datos y no contenga números mágicos. Los tiempos van en segundos
## (a 60 fps: 1 f ≈ 0.0167 s).

@export var id: String = ""
@export var display_name: String = ""
@export var kind: String = "light"          # "light" | "medium" | "heavy" | "special"
@export var airborne: bool = false          # ¿es un movimiento aéreo?

@export var damage: float = 5.0
@export var startup: float = 0.05           # frames de anticipación
@export var active: float = 0.05            # ventana en la que la hitbox está encendida
@export var recovery: float = 0.10          # recuperación (compromiso)

@export var hitbox_size: Vector2 = Vector2(54.0, 34.0)
@export var hitbox_offset: Vector2 = Vector2(38.0, -14.0)

@export var hitstun: float = 0.20           # stun causado al golpear
@export var blockstun: float = 0.10         # stun causado al ser bloqueado

@export var hitstop: int = 2                # frames de congelación al acertar
@export var block_hitstop: int = 1          # frames de congelación al bloquear

@export var knockback: Vector2 = Vector2(150.0, -70.0)
@export var launcher: bool = false          # lanza al rival por los aires
@export var invuln: float = 0.0             # invulnerabilidad al inicio (reversal)
@export var momentum: float = 0.0           # empuje propio hacia delante al iniciar

## Cadena de golpes: en qué movimientos se puede cancelar tras conectar.
@export var chain_into: PackedStringArray = PackedStringArray()
@export var max_chains: int = 2             # cuántas veces puede repetirse este id en un combo
@export var is_ender: bool = false          # termina el combo (no se puede cancelar)

## Telegraph visual (arco de color que aparece en los frames activos).
@export var slash_color: Color = Color(1.0, 0.95, 0.5, 0.85)
@export var slash_rotation: float = -0.3
