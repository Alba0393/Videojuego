class_name Hitbox
extends Area2D

## Área de impacto de un ataque.
##
## Se mantiene con `monitoring = true` de forma permanente para que la lista de
## solapamientos (`get_overlapping_areas`) esté siempre actualizada; el Fighter
## propietario es quien decide cuándo leerla (solo en los frames activos y con
## `set_active`). Esto evita el retardo de un frame que ocurre al alternar
## `monitoring` en caliente.

var fighter: Node = null  # Referencia al Fighter dueño de esta hitbox.
var is_active: bool = false

@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# Una hitbox nunca debe ser detectada por otras hitboxes...
	monitorable = false
	# ...pero sí necesita detectar las hurtbox rivales en todo momento.
	monitoring = true


## Marca la hitbox como activa o inactiva (bandera lógica).
func set_active(active: bool) -> void:
	is_active = active


## Devuelve la forma rectangular usada para configurar el alcance del ataque.
func get_rect_shape() -> RectangleShape2D:
	return collision.shape as RectangleShape2D
