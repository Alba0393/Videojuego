class_name PauseMenu
extends CanvasLayer

## Menú de pausa (ESC). Muestra los combos disponibles y los controles, y
## permite continuar. Se construye de forma dinámica desde ComboRecipes para
## que la lista siempre coincida con las recetas reales del juego.

signal paused_changed(paused: bool)

@onready var resume_button: Button = $Root/Panel/Resume
@onready var combo_list: VBoxContainer = $Root/Panel/ComboScroll/ComboList


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(_resume)
	_build_combo_list()


func _build_combo_list() -> void:
	for child in combo_list.get_children():
		child.queue_free()

	_add_section("— COMBOS DE TIERRA —")
	for recipe in ComboRecipes.RECIPES:
		if not recipe["air"]:
			_add_row(recipe)

	_add_section("— COMBOS AÉREOS —")
	for recipe in ComboRecipes.RECIPES:
		if recipe["air"]:
			_add_row(recipe)


func _add_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	combo_list.add_child(label)


func _add_row(recipe: Dictionary) -> void:
	var row := Label.new()
	row.text = "%s   ·   %s" % [recipe["name"], ComboRecipes.describe_short(recipe["seq"])]
	row.add_theme_font_size_override("font_size", 16)
	row.add_theme_color_override("font_color", Color(0.88, 0.90, 0.96))
	combo_list.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_set_paused(not get_tree().paused)


func is_paused() -> bool:
	return get_tree().paused


func _resume() -> void:
	_set_paused(false)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	visible = paused
	if paused:
		resume_button.grab_focus()
	paused_changed.emit(paused)
