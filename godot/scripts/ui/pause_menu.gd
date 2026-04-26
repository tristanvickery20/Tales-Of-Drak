extends CanvasLayer

## Simple pause menu — Esc toggles pause, Resume / Save / Load / Quit buttons.

@onready var panel: PanelContainer = $Panel
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var save_button: Button = $Panel/VBoxContainer/SaveButton
@onready var load_button: Button = $Panel/VBoxContainer/LoadButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	resume_button.pressed.connect(_on_resume)
	save_button.pressed.connect(_on_save)
	load_button.pressed.connect(_on_load)
	quit_button.pressed.connect(_on_quit)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if panel.visible:
			_resume_game()
		else:
			_pause_game()


func _pause_game() -> void:
	get_tree().paused = true
	panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _resume_game() -> void:
	get_tree().paused = false
	panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_resume() -> void:
	_resume_game()


func _on_save() -> void:
	var data = GameState.save_game() if GameState != null else {}
	SaveManager.save_data(data)
	_resume_game()


func _on_load() -> void:
	var data = SaveManager.load_data()
	if GameState != null and not data.is_empty():
		GameState.load_game(data)
		# Reload the test world to apply loaded state
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/test_world/test_world.tscn")


func _on_quit() -> void:
	get_tree().quit()
