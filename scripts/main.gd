extends Node2D

@onready var scene_Bomb = preload("res://scenes/bomb.tscn")
@onready var board = $Board
@onready var opponent_portrait = $OpponentPortrait
@onready var bomb_socket = $BombSocket
@onready var health_bar = $HealthBar
@onready var attack_meter = $AttackMeter

var bomb: Bomb

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	board.on_pieces_cleared.connect(on_pieces_cleared)
	board.on_combo_finished.connect(on_combo_finished)
	opponent_attack_loop()

func opponent_attack_loop() -> void:
	attack_meter.on_full.connect(opponent_attack)
	while true:
		await get_tree().create_timer(1).timeout
		await attack_meter.increment(1)
		
func opponent_attack() -> void:
	attack_meter.clear()

func on_pieces_cleared(num_pieces: int, combo: int):
	var points = num_pieces * combo
	if not bomb:
		bomb = scene_Bomb.instantiate()
		add_child(bomb)
		bomb.transform.origin = bomb_socket.transform.origin
	bomb.add_points(num_pieces * combo)
	
func on_combo_finished():
	if not bomb:
		return
	if bomb.is_too_weak_to_send():
		bomb = null
		return
	var tween = create_tween()
	var bomb_in_transit = bomb
	bomb = null
	tween.tween_property(bomb_in_transit, "position", opponent_portrait.transform.origin, 1)
	await tween.finished
	opponent_portrait.hurt()
	health_bar.decrement(bomb_in_transit.get_damage())
	bomb_in_transit.queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
