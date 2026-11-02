class_name FootballGround
extends Node3D

## The football ground: two goals, a few balls, and the score.
##
## The pitch surface itself is not here — it is part of the terrain, levelled
## and painted by the height field, so it has collision and detail for free and
## can never drift out of alignment with the ground. What is here is everything
## the terrain cannot be: the goals, the balls, and the counting.

## How many balls lie about. More than one because two brothers will want one
## each, and because a ball kicked into the river should not end the game.
const BALL_COUNT := 3

## How long the "GOAL" moment lasts before the ball is put back on the spot.
const CELEBRATION := 2.2

## A ball this far outside the levelled ground has gone for a walk and comes
## home. Generous, so that chasing a long ball is still part of the fun.
const STRAY_DISTANCE := 46.0

## A goal went in at `goal_index`, and this is the score now: blue's, then red's.
signal goal_scored(goal_index: int, blue: int, red: int)

## The score changed any way at all — a goal, a new game, a load.
signal scores_changed(blue: int, red: int)

## Goals scored by each side. Blue defends the west goal and red the east, so
## the ball into the east goal is blue's goal and the other way round.
var blue := 0
var red := 0

var _board: Scoreboard

var _balls: Array[Ball] = []
var _cooldown := 0.0
## Balls that have scored and are still lying in the net waiting to be put back.
## The celebration clock is counted in physics ticks and the restart in the
## scene tree's timer; they can disagree by a frame, and a ball still over the
## line in that gap was given a second goal.
var _in_the_net: Dictionary = {}
var _field: HeightField

func _init(field: HeightField) -> void:
	_field = field
	# Built here rather than in _ready, because a node used before the scene
	# tree starts processing never receives _ready and the failure is silent.
	#
	# Everything below is placed in world coordinates, so this node must stay at
	# the origin: the children carry absolute positions and global_position has
	# to agree with them. Moving this node would silently offset the entire
	# pitch from the ground it was levelled into.
	position = Vector3.ZERO
	var centre := Pitch.centre()
	var surface := _field.height_at(centre.x, centre.z)

	for index in 2:
		var mouth := Pitch.goal_centre(index)
		mouth.y = _field.height_at(mouth.x, mouth.z)
		add_child(Goal.new(index, mouth))

	var foot := Pitch.scoreboard_foot()
	_board = Scoreboard.new(_field.height_at(foot.x, foot.z))
	add_child(_board)

	# Balls start spread across the halfway line, not stacked on the centre
	# spot, or they spend the first second of the game shoving each other.
	for i in BALL_COUNT:
		var spread := (float(i) - float(BALL_COUNT - 1) * 0.5) * 3.0
		# Spread along the halfway line, and lifted by exactly one radius so
		# each ball rests on the grass rather than half-buried in it.
		var start := Vector3(centre.x, surface + Ball.RADIUS, centre.z + spread)
		var ball := Ball.new(start)
		add_child(ball)
		_balls.append(ball)

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		return

	for ball in _balls:
		if _in_the_net.has(ball):
			continue
		if _check_goal(ball):
			return
		if _float_in_the_river(ball, delta):
			continue
		_recover_stray(ball)

## Where a ball actually is, whether or not this node has entered the tree.
func ball_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for ball in _balls:
		out.append(ball.position)
	return out

func _check_goal(ball: Ball) -> bool:
	for index in 2:
		var mouth := Pitch.goal_centre(index)
		var grass := _field.height_at(mouth.x, mouth.z)
		if not Pitch.is_goal(index, ball.position, Ball.RADIUS, grass):
			continue
		# The goal an end defends is the other side's to score in.
		if index == 1:
			blue += 1
		else:
			red += 1
		_cooldown = CELEBRATION
		_board.show_scores(blue, red)
		goal_scored.emit(index, blue, red)
		scores_changed.emit(blue, red)
		# Put it back on the centre spot after the celebration, the way a
		# restart works, rather than instantly, which reads as the ball
		# vanishing at the moment of triumph.
		var restart := Pitch.centre()
		restart.y = _field.height_at(restart.x, restart.z)
		_in_the_net[ball] = true
		var timer := get_tree().create_timer(CELEBRATION)
		timer.timeout.connect(func() -> void:
			# A new game may have fetched the ball already, and the child
			# kicked it since: it is not taken from them a second time.
			if not _in_the_net.has(ball):
				return
			_in_the_net.erase(ball)
			ball.reset_to(restart)
		)
		return true
	return false

## How long a ball may ride the river before it is fetched home. Long enough
## to watch it go; short enough that three balls never become none.
const AFLOAT_FOR := 20.0

## How long each ball has been afloat in the river, in seconds.
var _afloat: Dictionary = {}

## A ball that lands in the river floats on it and goes downstream with the
## water, rather than sinking to the bed and being whisked home the moment it
## stops. Returns whether the ball is afloat in a current, in which case it is
## not a stray yet. Ponds and the pool have no current, so a ball in them is
## still sunk and fetched, as before.
func _float_in_the_river(ball: Ball, delta: float) -> bool:
	var at := ball.position
	var current := _field.river_current_at(at.x, at.z)
	var level := _field.water_level_at(at.x, at.z)
	if current == Vector2.ZERO or at.y > level + Ball.RADIUS:
		_afloat.erase(ball)
		return false
	var time: float = float(_afloat.get(ball, 0.0)) + delta
	_afloat[ball] = time
	if time > AFLOAT_FOR:
		_afloat.erase(ball)
		return false
	# A spring to the surface that exactly cancels weight there, with some
	# damping so it bobs once and settles; and the water's own pace pulling the
	# ball's sideways speed round to the current's.
	ball.apply_central_force(Vector3(
		0.0,
		ball.mass * (ball.gravity_strength() + 14.0 * (level - at.y) - 3.0 * ball.linear_velocity.y),
		0.0
	))
	var pull := Vector3(current.x - ball.linear_velocity.x, 0.0, current.y - ball.linear_velocity.z)
	ball.apply_central_force(pull * ball.mass * 2.0)
	return true

## A ball in the river, down a hill, or halfway to the mountains comes back.
## Without this, three balls become zero balls within ten minutes and the pitch
## is useless for the rest of the save.
func _recover_stray(ball: Ball) -> void:
	var at := ball.position
	var centre := Pitch.centre()
	# The water here, not the world's: a ball kicked into the lake up the hill
	# is eleven metres above the sea and was counted as perfectly dry.
	var wet_at := _field.water_level_at(at.x, at.z) + 0.1
	var strayed := (
		Vector2(at.x - centre.x, at.z - centre.z).length() > STRAY_DISTANCE
		or at.y < wet_at
	)
	if not strayed:
		return
	if not ball.at_rest() and at.y > wet_at:
		# Still travelling and still dry: let the child watch it fly.
		return
	var spot := ball.home
	spot.y = _field.height_at(spot.x, spot.z)
	ball.reset_to(spot)

## The nearest ball within striking distance, or null.
func ball_near(from: Vector3) -> Ball:
	var best: Ball = null
	var best_distance := Ball.KICK_REACH + Ball.RADIUS
	for ball in _balls:
		# position, not global_position: this is asked during _process and also
		# from headless checks where the node may not be in the tree, and the
		# two disagree in exactly the case that is hardest to notice.
		var offset := ball.position - from
		offset.y = 0.0
		var distance := offset.length()
		if distance <= best_distance:
			best_distance = distance
			best = ball
	return best

## Start the game again: both scores to nothing and every ball back where it
## began, on the halfway line, as when the world was made.
func new_game() -> void:
	blue = 0
	red = 0
	_cooldown = 0.0
	_in_the_net.clear()
	_afloat.clear()
	for ball in _balls:
		var spot := ball.home
		spot.y = _field.height_at(spot.x, spot.z)
		ball.reset_to(spot)
	_board.show_scores(blue, red)
	scores_changed.emit(blue, red)

## The board's own digits, for the checks.
func board_digits() -> PackedStringArray:
	return _board.digits()

func to_data() -> Dictionary:
	return {"blue": blue, "red": red}

func from_data(data: Dictionary) -> void:
	# A save from before there were two sides holds one number, "score", for
	# goals in either end, and there is no telling now whose they were. It is
	# loaded as 0:0 rather than handed to blue: a child should not open the game
	# to a lead that one of two brothers never scored.
	blue = maxi(int(data.get("blue", 0)), 0)
	red = maxi(int(data.get("red", 0)), 0)
	_board.show_scores(blue, red)
	scores_changed.emit(blue, red)
