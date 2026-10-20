class_name Hurtbox
extends Area2D

## Zona vulnerable del combatiente. No detecta nada por sí misma (monitoring = false),
## simplemente existe en una capa de física para que las Hitbox puedan encontrarla.

var fighter: Node = null  # Referencia al Fighter dueño de esta hurtbox.


func _ready() -> void:
	monitoring = false
	monitorable = true
