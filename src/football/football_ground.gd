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

signal goal_scored(goal_index: int, total: int)
signal ball_kicked(power: float)

var score := 0

var _balls: Array[Ball] = []
var _cooldown := 0.0
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

	# Balls start spread across the halfway line, not stacked on the centre
	# spot, or they spend the first second of the game shoving each other.
	for i in BALL_COUNT:
		var spread := (float(i) - float(BALL_COUNT - 1) * 0.5) * 3.0
		# Spread along the halfway line, and lifted by exactly one radius so
		# each ball rests on the grass rather than half-buried in it.
		var start := Vector3(centre.x, surface + Ball.RADIUS, centre.z + spread)
		var ball := Ball.new(start)
		ball.kicked.connect(func(power: float) -> void: ball_kicked.emit(power))
		add_child(ball)
		_balls.append(ball)

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		return

	for ball in _balls:
		if _check_goal(ball):
			return
		_recover_stray(ball)

## Where a ball actually is, whether or not this node has entered the tree.
func ball_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for ball in _balls:
		out.append(ball.position)
	return out

func _check_goal(ball: Ball) -> bool:
	for index in 2:
		if not Pitch.is_goal(index, ball.position, Ball.RADIUS):
			continue
		score += 1
		_cooldown = CELEBRATION
		goal_scored.emit(index, score)
		# Put it back on the centre spot after the celebration, the way a
		# restart works, rather than instantly, which reads as the ball
		# vanishing at the moment of triumph.
		var restart := Pitch.centre()
		restart.y = _field.height_at(restart.x, restart.z)
		var timer := get_tree().create_timer(CELEBRATION)
		timer.timeout.connect(func() -> void: ball.reset_to(restart))
		return true
	return false

## A ball in the river, down a hill, or halfway to the mountains comes back.
## Without this, three balls become zero balls within ten minutes and the pitch
## is useless for the rest of the save.
func _recover_stray(ball: Ball) -> void:
	var at := ball.position
	var centre := Pitch.centre()
	var strayed := (
		Vector2(at.x - centre.x, at.z - centre.z).length() > STRAY_DISTANCE
		or at.y < HeightField.WATER_LEVEL + 0.1
	)
	if not strayed:
		return
	if not ball.at_rest() and at.y > HeightField.WATER_LEVEL + 0.1:
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

func to_data() -> Dictionary:
	return {"score": score}

func from_data(data: Dictionary) -> void:
	score = int(data.get("score", 0))
