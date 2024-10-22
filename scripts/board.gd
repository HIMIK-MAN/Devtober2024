@tool

class_name Board
extends Node2D

class DoublePiece:
	enum Orientation { UP, LEFT, RIGHT, DOWN }
	const ORIENTATION_ORDER := [ Orientation.RIGHT, Orientation.UP, Orientation.LEFT, Orientation.DOWN ]
	var orientation_index := 1
	var origin := Vector2i(0, 0)
	func _init(p_origin: Vector2i) -> void:
		origin = p_origin
	func get_primary_coords() -> Vector2i:
		return origin
	func get_secondary_coords() -> Vector2i:
		match get_orientation():
			Orientation.UP:
				return origin + Vector2i(0, -1)
			Orientation.DOWN:
				return origin + Vector2i(0, 1)
			Orientation.LEFT:
				return origin + Vector2i(-1, 0)
			Orientation.RIGHT:
				return origin + Vector2i(1, 0)
		assert(false)
		return Vector2i(0, 0)
	func get_primary_pos(cell_size: int) -> Vector2:
		return Vector2(get_primary_coords() * cell_size) + Vector2(cell_size / 2, cell_size / 2)
	func get_secondary_pos(cell_size: int) -> Vector2:
		return Vector2(get_secondary_coords() * cell_size) + Vector2(cell_size / 2, cell_size / 2)
	func get_orientation() -> Orientation:
		return ORIENTATION_ORDER[orientation_index]
	func rotate_ccw():
		orientation_index = (orientation_index + 1) % len(ORIENTATION_ORDER)
	func rotate_cw():
		orientation_index = (orientation_index + len(ORIENTATION_ORDER) - 1) % len(ORIENTATION_ORDER)
	func move_left():
		origin.x -= 1
	func move_right():
		origin.x += 1
	func move_up():
		origin.y -= 1
	func move_down():
		origin.y += 1

const ATTACK1_CHANCE := 0.2
const TIME_TO_FALL_ONE_CELL := 1.0
const LINE_COLOR := Color(1, 1, 1, 0.2)
const BG_COLOR := Color(.1, .1, .1, 0.7)
const REPEAT_DELAY := 0.25
const REPEAT_PERIOD := 0.05
const PLACING_DELAY := 0.25

@onready var scene_Piece = preload("res://scenes/piece.tscn")

@onready var preview_pane = $PreviewPane

@export var board_width := 6
@export var board_height := 10
@export var cell_size := 64

var columns : Array
var dp: DoublePiece
var primary: Piece
var secondary: Piece
var fall_timer: SceneTreeTimer
var down_repeat_timer: SceneTreeTimer
var left_repeat_timer: SceneTreeTimer
var right_repeat_timer: SceneTreeTimer
var is_left_pressed := false
var is_right_pressed := false
var is_stopped := false
var next_primary: Piece
var next_secondary: Piece

signal on_pieces_cleared
signal on_settled
signal on_placed
signal on_player_move(not_blocked: bool)
signal on_player_rotate
signal on_lose
signal on_fall_start(p: Piece)
signal on_fall_end(p: Piece)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	columns = []
	for c in range(board_width):
		columns.append([])
	if not Engine.is_editor_hint():
		start()

func _input(event: InputEvent) -> void:
	if is_stopped:
		return
		
	if event.is_action_pressed("move_down"):
		hold_down()
	if event.is_action_released("move_down"):
		release_down()
	
	if event.is_action_pressed("move_left"):
		is_left_pressed = true
		if is_right_pressed:
			release_right()
		hold_left()
	if event.is_action_released("move_left"):
		is_left_pressed = false
		release_left()
		
	if event.is_action_pressed("move_right"):
		is_right_pressed = true
		if is_left_pressed:
			release_left()
		hold_right()
	if event.is_action_released("move_right"):
		is_right_pressed = false
		release_right()
		
	if event.is_action_pressed("rotate_cw"):
		if dp: rotate_cw()
	if event.is_action_pressed("rotate_ccw"):
		if dp: rotate_ccw()

func is_occupied(pos: Vector2i) -> bool:
	if pos.x < 0 or len(columns) <= pos.x:
		return true
	if pos.y >= board_height - len(columns[pos.x]):
		return true
	return false

func hold_down(started: bool = false) -> void:
	# soft drop doesn't use repeat delay
	if (!started):
		if dp: on_player_move.emit(move_down(), true)
	else:
		if dp: move_down()
	down_repeat_timer = get_tree().create_timer(REPEAT_PERIOD)
	down_repeat_timer.timeout.connect(hold_down.bind(true))

func release_down() -> void:
	down_repeat_timer.timeout.disconnect(hold_down)

func hold_left() -> void:
	if dp: on_player_move.emit(move_left())
	left_repeat_timer = get_tree().create_timer(REPEAT_DELAY)
	left_repeat_timer.timeout.connect(continue_holding_left)

func continue_holding_left() -> void:
	if dp: move_left()
	left_repeat_timer = get_tree().create_timer(REPEAT_PERIOD)
	left_repeat_timer.timeout.connect(continue_holding_left)

func release_left() -> void:
	left_repeat_timer.timeout.disconnect(continue_holding_left)
	
func hold_right() -> void:
	if dp: on_player_move.emit(move_right())
	right_repeat_timer = get_tree().create_timer(REPEAT_DELAY)
	right_repeat_timer.timeout.connect(continue_holding_right)

func continue_holding_right() -> void:
	if dp: move_right()
	right_repeat_timer = get_tree().create_timer(REPEAT_PERIOD)
	right_repeat_timer.timeout.connect(continue_holding_right)

func release_right() -> void:
	right_repeat_timer.timeout.disconnect(continue_holding_right)

func move_left() -> bool:
	var primary_left = dp.get_primary_coords() + Vector2i(-1, 0)
	var secondary_left = dp.get_secondary_coords() + Vector2i(-1, 0)
	match dp.get_orientation():
		DoublePiece.Orientation.UP, DoublePiece.Orientation.DOWN:
			if is_occupied(primary_left) or is_occupied(secondary_left):
				return false
		DoublePiece.Orientation.LEFT:
			if is_occupied(secondary_left):
				return false
		DoublePiece.Orientation.RIGHT:
			if is_occupied(primary_left):
				return false
	dp.move_left()
	return true
	
func move_right() -> bool:
	var primary_right = dp.get_primary_coords() + Vector2i(1, 0)
	var secondary_right = dp.get_secondary_coords() + Vector2i(1, 0)
	match dp.get_orientation():
		DoublePiece.Orientation.UP, DoublePiece.Orientation.DOWN:
			if is_occupied(primary_right) or is_occupied(secondary_right):
				return false
		DoublePiece.Orientation.LEFT:
			if is_occupied(primary_right):
				return false
		DoublePiece.Orientation.RIGHT:
			if is_occupied(secondary_right):
				return false
	dp.move_right()
	return true

func move_down() -> bool:
	var primary_down = dp.get_primary_coords() + Vector2i(0, 1)
	var secondary_down = dp.get_secondary_coords() + Vector2i(0, 1)
	match dp.get_orientation():
		DoublePiece.Orientation.UP:
			if is_occupied(primary_down):
				place()
				return false
		DoublePiece.Orientation.LEFT, DoublePiece.Orientation.RIGHT:
			if is_occupied(primary_down) or is_occupied(secondary_down):
				place()
				return false
		DoublePiece.Orientation.DOWN:
			if is_occupied(secondary_down):
				place()
				return false
	dp.move_down()
	reset_fall_timer()
	return true

func rotate_cw():
	var primary_right = dp.get_primary_coords() + Vector2i(1, 0)
	var primary_left = dp.get_primary_coords() + Vector2i(-1, 0)
	var primary_down = dp.get_primary_coords() + Vector2i(0, 1)
	match dp.get_orientation():
		DoublePiece.Orientation.UP:
			if is_occupied(primary_right):
				move_left()
		DoublePiece.Orientation.LEFT:
			pass # no adjustment needed
		DoublePiece.Orientation.RIGHT:
			if is_occupied(primary_down):
				dp.move_up()
		DoublePiece.Orientation.DOWN:
			if is_occupied(primary_left):
				move_right()
	on_player_rotate.emit()
	dp.rotate_cw()

func rotate_ccw():
	var primary_right = dp.get_primary_coords() + Vector2i(1, 0)
	var primary_left = dp.get_primary_coords() + Vector2i(-1, 0)
	var primary_down = dp.get_primary_coords() + Vector2i(0, 1)
	match dp.get_orientation():
		DoublePiece.Orientation.UP:
			if is_occupied(primary_left):
				move_right()
		DoublePiece.Orientation.LEFT:
			if is_occupied(primary_down):
				dp.move_up()
		DoublePiece.Orientation.RIGHT:
			pass # no adjustment needed
		DoublePiece.Orientation.DOWN:
			if is_occupied(primary_right):
				move_left()
	on_player_rotate.emit()
	dp.rotate_ccw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, board_width * cell_size, board_height * cell_size), BG_COLOR)
	for i in range(1, board_width):
		var x = i * cell_size
		draw_line(Vector2(x, 0), Vector2(x, board_height * cell_size), LINE_COLOR)
	for i in range(1, board_height):
		var y = i * cell_size
		draw_line(Vector2(0, y), Vector2(board_width * cell_size, y), LINE_COLOR)
	
	if dp:
		var primary = dp.get_primary_pos(cell_size)
		var secondary = dp.get_secondary_pos(cell_size)
		draw_circle(primary, cell_size / 2 - 16, LINE_COLOR, false, 4.0, true)
		draw_circle(secondary, cell_size / 2 - 24, LINE_COLOR, false, 4.0, true)

func reindex_columns() -> void:
	for column in columns:
		(column as Array).clear()
	for child in get_children():
		if child is not Piece:
			continue
		if child.is_queued_for_deletion():
			continue
		var column_index = int(child.transform.origin.x / cell_size)
		if column_index < 0 or len(columns) <= column_index:
			push_warning("piece placed out of bounds")
			child.queue_free()
			continue
		columns[column_index].append(child)

# for even numbers of columns, return the index of the column left of center.
# e.g. for 6 columns, returns 2.
func get_center_column_index() -> int:
	return int((board_width - 1) / 2)

func create_new_double_piece() -> void:
	dp = DoublePiece.new(Vector2i(get_center_column_index(), 0))
	var pieces = preview_pane.pop()
	primary = pieces[0]
	secondary = pieces[1]
	on_piece_fall_start
	next_primary = null
	next_secondary = null
	primary.cell_size = cell_size
	secondary.cell_size = cell_size
	add_child(primary)
	add_child(secondary)
	update_primary_and_secondary()
	
func bind_piece(p):
	#p.start_animation_fall.connect(self.on_piece_fall_start.bind(p))
	pass

func stop() -> void:
	is_stopped = true
	cancel_fall_timer()

func cancel_fall_timer() -> void:
	if fall_timer: fall_timer.timeout.disconnect(move_down)
	
func reset_fall_timer() -> void:
	if fall_timer: fall_timer.timeout.disconnect(move_down)
	fall_timer = get_tree().create_timer(TIME_TO_FALL_ONE_CELL)
	fall_timer.timeout.connect(move_down)

func update_primary_and_secondary() -> void:
	if not dp:
		return
	primary.transform.origin = dp.get_primary_pos(cell_size)
	secondary.transform.origin = dp.get_secondary_pos(cell_size)
	
func place() -> void:
	on_placed.emit()
	dp = null
	simulate()

func simulate() -> void:
	cancel_fall_timer()
	reindex_columns()
	await settle()
	
	var num_cleared = await clear()
	var combo = 0
	while num_cleared > 0:
		combo += 1
		on_pieces_cleared.emit(num_cleared, combo)
		reindex_columns()
		await settle()
		num_cleared = await clear()
	
	if len(columns[get_center_column_index()]) >= board_height:
		on_lose.emit()
		return
	
	on_settled.emit()
	# whoever is listening to on_settled is responsible for calling start again to continue the game loop

func start():
	create_new_double_piece()
	reset_fall_timer()

func sort_columns() -> void:
	for column in columns:
		column.sort_custom(func(a, b):
			return a.transform.origin.y > b.transform.origin.y
		)

func settle() -> void:
	sort_columns()
	var changed_pieces := []
	for column in columns:
		for i in len(column):
			var new_y = cell_size / 2 + cell_size * (board_height - 1 - i)
			if column[i].transform.origin.y == new_y:
				continue
			changed_pieces.append(column[i])
			column[i].fall_to(new_y)
	for piece in changed_pieces:
		self.on_piece_fall_start(piece)
		await piece.done_animation_fall
		self.on_piece_fall_end(piece)

func clear() -> int:
	var pieces_to_clear = []
	var visited = {}
	for piece in get_children():
		if piece is not Piece:
			continue
		if piece.is_queued_for_deletion():
			continue
		if piece.kind == Piece.Kind.GARBAGE:
			continue
		if visited.has(hash(piece)):
			continue
		var cluster = piece.get_cluster(visited)
		if len(cluster) >= 4:
			pieces_to_clear.append_array(cluster)
	
	# find garbage adjacent to any clearing pieces
	var garbage_to_clear = []
	var visited_garbage = {}
	for piece in pieces_to_clear:
		for adj in piece.get_adj_pieces():
			if visited_garbage.has(hash(adj)):
				continue
			if adj.kind == Piece.Kind.GARBAGE:
				garbage_to_clear.append(adj)
				visited_garbage[hash(adj)] = true
	pieces_to_clear.append_array(garbage_to_clear)
	
	for piece in pieces_to_clear:
		piece.clear()
	for piece in pieces_to_clear:
		await piece.done_animation_clear
	for piece in pieces_to_clear:
		piece.queue_free()
	return len(pieces_to_clear)

func attack1() -> void:
	var piece_sample = []
	var num_pieces = 0
	for column in columns:
		for piece in column:
			if piece.kind == Piece.Kind.GARBAGE:
				continue
			num_pieces += 1
			if randf() < ATTACK1_CHANCE:
				piece_sample.append(piece)
	if num_pieces == 0:
		return
	if len(piece_sample) == 0:
		# retry until at least one piece is targeted
		attack1()
	for piece in piece_sample:
		await piece.set_kind(Piece.Kind.GARBAGE)

func on_piece_fall_start(p: Piece) -> void:
	on_fall_start.emit(p)
	pass

func on_piece_fall_end(p: Piece) -> void:
	on_fall_end.emit(p)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	queue_redraw()
	update_primary_and_secondary()
