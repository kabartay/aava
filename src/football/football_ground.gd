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
const CELEBRATION := 3.0

## A match is won by the first side to this many goals. The board and the
## announcement say so, and a new game begins by itself after WIN_PAUSE — long
## enough to enjoy the confetti, short enough that two children are playing
## again before they have started arguing about who is next.
const WIN_SCORE := 5
const WIN_PAUSE := 6.0

## A ball that has crossed the touchline or the goal line without scoring is
## put back this long afterwards, at the nearest point this far inside the
## touchline: a throw-in, simplified. Far enough in that it is not out again.
const OUT_FOR := 3.0
const OUT_INSET := 1.0

## A ball this far outside the levelled ground has gone for a walk and comes
## home. Generous, so that chasing a long ball is still part of the fun.
const STRAY_DISTANCE := 46.0

## A goal went in at `goal_index`, and this is the score now: blue's, then red's.
signal goal_scored(goal_index: int, blue: int, red: int)

## The score changed any way at all — a goal, a new game, a load.
signal scores_changed(blue: int, red: int)

## A side (0 blue, 1 red) reached WIN_SCORE, and this is the score.
signal match_won(side: int, blue: int, red: int)

## The host struck a ball on a guest's behalf, with this strength from 0 to 1,
## so it can make the sound of it: the guest's own phone does already.
signal guest_kicked(strength: float)

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
## The side that has won the match being shown, or -1; and how long each ball
## has been out of play, in seconds.
var _winner := -1
var _out_for: Dictionary = {}

# --- playing together ---------------------------------------------------------
#
# When two children share a valley the football is the host's. The host's phone
# simulates the balls and keeps the score and tells the guest, ten or twelve
# times a second, where the balls are; the guest's phone draws them there and
# does not simulate them at all. A guest's kick is a request: it goes to the host
# as the velocity the guest's own aim worked out, and the host applies it if it is
# a kick somebody standing there could have given. Alone, or once the connection
# is gone, every phone plays its own game exactly as it always did.

## How often the host sends where the balls are.
const BALL_INTERVAL := 1.0 / 12.0
## Even a still game is told again this often, so a lost update cannot leave a
## guest's ball somewhere it is not for long.
const BALL_HEARTBEAT := 1.0
## A ball this far from where the host says it is has been put back on the spot
## or fetched from the river, and jumps there rather than sliding across.
const SNAP_DISTANCE := 4.0
## How long a guest's own kick is shown by this phone before the host's balls
## are believed again: long enough for the request to reach the host and the ball
## to start moving there, so the kick is felt at once and not a round trip later.
const PREDICT_FOR := 0.3
## How far past the kick's own reach a guest may be from a ball when the host
## hears of the kick: the ball and the child both moved while it travelled.
const KICK_SLACK := 3.0

var _session: Session = null
## Following the host's game rather than playing one.
var _following := false
## The guest's own score, put away while the host's is on the board.
var _own_blue := 0
var _own_red := 0
var _since_sent := 0.0
var _since_full := 0.0
var _send_at_once := false
var _last_sent := PackedFloat32Array()
## What each ball is being drawn doing, as a guest: where it was and is going to
## be, how long since the host last spoke about it, and its own kick if any.
var _drawn: Array[Dictionary] = []

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
		_drawn.append({"known": false, "predicting": 0.0})

func _physics_process(delta: float) -> void:
	_sync_role()
	# A guest does not play the game: the host does, and this phone only draws it.
	if not _following:
		_play(delta)
		_carry_guests(delta)
	_share(delta)

func _play(delta: float) -> void:
	# The celebration only holds off the next goal. The other balls are still
	# physical things: one in the river keeps floating, and a stray one still
	# goes home. Returning early here left a ball in the water with nothing
	# holding it up for the two seconds of the cheer, so it sank to the bed.
	var celebrating := _cooldown > 0.0
	if celebrating:
		_cooldown -= delta
		# A won match ends with the pause: the next game begins by itself.
		if _cooldown <= 0.0 and _winner >= 0:
			new_game()
			return

	for ball in _balls:
		if _in_the_net.has(ball):
			continue
		if not celebrating and _check_goal(ball):
			return
		if _float_in_the_river(ball, delta):
			continue
		# Not while a goal is being cheered: a ball lying in the net is behind
		# the goal line, and fetched back as "out" it was gone before the next
		# goal could be judged.
		if not celebrating and _bring_back(ball, delta):
			continue
		_recover_stray(ball)

## A side has won the match: say so on the board, and hold play for the pause.
## On a guest's phone too, which has been told the score and no more.
func _win(side: int) -> void:
	_winner = side
	_cooldown = WIN_PAUSE
	_board.show_winner(side, WIN_PAUSE)
	match_won.emit(side, blue, red)

## Which match is being shown as won, 0 blue and 1 red, or -1 for none.
func winner() -> int:
	return _winner

## A ball that is over the touchline or the goal line, and did not go in, is
## brought back after OUT_FOR seconds to the nearest point inside the
## touchline, rather than left rolling off down the valley. Returns whether it
## has just been put back.
func _bring_back(ball: Ball, delta: float) -> bool:
	var at := ball.position
	if Pitch.is_in_play(at.x, at.z):
		_out_for.erase(ball)
		return false
	var time: float = float(_out_for.get(ball, 0.0)) + delta
	if time < OUT_FOR:
		_out_for[ball] = time
		return false
	_out_for.erase(ball)
	var spot := Pitch.nearest_inside(at.x, at.z, OUT_INSET)
	spot.y = _field.height_at(spot.x, spot.z)
	ball.reset_to(spot)
	return true

## Which side this phone's child plays: 0 for blue and 1 for red when two are
## playing — the host is blue and attacks the red goal, a guest is red — and -1
## when alone, where a child plays both ways and every goal is theirs.
func my_side() -> int:
	if _session == null:
		return -1
	if _session.is_following():
		return 1
	if _session.is_host() and _session.has_company():
		return 0
	return -1

## Is a goal into `goal`'s net this phone's child's own? Alone, any goal is; with
## a brother, only one for the child's own side.
func scored_for_me(goal: int) -> bool:
	var side := my_side()
	return side < 0 or side == 1 - goal

# --- the children's own bodies ---------------------------------------------------

## How far from the pitch a guest still has a body here. Further than that the
## capsule would only be an invisible post in somebody's way.
const BODY_RANGE := 12.0
## The fastest a guest's body is moved to catch up with the position it was told,
## so that it pushes a ball at a believable pace; further behind than TELEPORT it
## is set down at once.
const BODY_PACE := 9.0
const BODY_TELEPORT := 6.0

## A kinematic capsule the size of a child for each guest near the pitch, on the
## host: running into a ball pushes it there, and the guest sees it move because
## the host sends the balls. Kinematic, so it goes where the guest's phone says
## and nothing here pushes a child about.
var _bodies: Dictionary = {}

func _carry_guests(delta: float) -> void:
	var told: Dictionary = {}
	if _session != null and _session.is_host():
		for id: int in _session.guest_positions:
			if _session.guests.has(id):
				var at: Vector3 = _session.guest_positions[id]
				if Pitch.is_beside(at.x, at.z, BODY_RANGE):
					told[id] = at
	for id: int in _bodies.keys():
		if not told.has(id):
			(_bodies[id] as Node).queue_free()
			_bodies.erase(id)
	for id: int in told:
		var target: Vector3 = (told[id] as Vector3) + Vector3.UP * Player.HEIGHT * 0.5
		var body: AnimatableBody3D = _bodies.get(id)
		if body == null:
			body = _make_body()
			body.position = target
			add_child(body)
			_bodies[id] = body
		var from := body.position
		if from.distance_to(target) > BODY_TELEPORT:
			body.position = target
		else:
			body.position = from.move_toward(target, BODY_PACE * maxf(delta, 0.0001))
		var pace := (body.position - from) / maxf(delta, 0.0001)
		dribble(body.position - Vector3.UP * Player.HEIGHT * 0.5, pace, delta)

func _make_body() -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = "GuestBody"
	# A layer only the ball looks for, and no mask: it moves, nothing moves it —
	# and the host's own child walks through it as the guest does through them,
	# rather than being shoved by a body that is nowhere on their screen.
	body.collision_layer = TerrainSpec.LAYER_VISITORS
	body.collision_mask = 0
	var shape := CapsuleShape3D.new()
	shape.height = Player.HEIGHT
	shape.radius = Player.RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	return body

## How many guests have a body here, for the checks.
func body_count() -> int:
	return _bodies.size()

func body_of(id: int) -> AnimatableBody3D:
	return _bodies.get(id)

## A gentle touch for a child on foot at `from`, moving at `velocity`: a ball
## they are walking or jogging at is kept near their feet instead of being
## shoved off (see Ball.touch_velocity). The game of whoever hosts, or plays
## alone; a guest's phone only shows it, see `feel`.
func dribble(from: Vector3, velocity: Vector3, delta: float) -> void:
	if _following:
		return
	for ball in _balls:
		if _in_the_net.has(ball):
			continue
		var now := Ball.touch_velocity(ball.position, ball.linear_velocity, from, velocity, delta)
		if now != ball.linear_velocity:
			ball.sleeping = false
			ball.linear_velocity = now

## A guest's phone shows the same touch at once, without waiting for the host's
## ball to answer, for as long as it is in contact; the host's word takes over
## a moment after, and is the same.
func feel(from: Vector3, velocity: Vector3, delta: float) -> void:
	if not _following:
		return
	for i in _balls.size():
		var shown := _drawn[i]
		if not shown["known"]:
			continue
		var ball := _balls[i]
		var going: Vector3 = shown["guess"] if float(shown["predicting"]) > 0.0 else shown["velocity"]
		var now := Ball.touch_velocity(ball.position, going, from, velocity, delta)
		if now != going:
			shown["guess"] = now
			shown["predicting"] = maxf(float(shown["predicting"]), TOUCH_PREDICT_FOR)

## How long a guest's own touch is shown before the host's word is believed
## again. Shorter than a kick's: a touch is renewed every frame it lasts.
const TOUCH_PREDICT_FOR := 0.12

## Where a ball actually is, whether or not this node has entered the tree.
func ball_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for ball in _balls:
		out.append(ball.position)
	return out

func _check_goal(ball: Ball) -> bool:
	for index in 2:
		var mouth := Pitch.goal_centre(index)
		# Whether the ball is anywhere near the goal is asked first, with the
		# height test made to pass: the grass under the goal is a read of the
		# whole height field, and it was made twice for every ball on every
		# physics tick, nearly always for a ball in the middle of the pitch.
		if not Pitch.is_goal(index, ball.position, Ball.RADIUS, INF):
			continue
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
		_board.celebrate(1 - index, CELEBRATION)
		goal_scored.emit(index, blue, red)
		scores_changed.emit(blue, red)
		_tell_guests(index)
		if blue >= WIN_SCORE or red >= WIN_SCORE:
			# Guests work this out for themselves from the score they are told.
			_win(1 - index)
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
	# The game is the host's: a guest asks, and sees it begin again when the
	# host's scores and balls arrive.
	if _following:
		_session.report_new_game()
		return
	blue = 0
	red = 0
	_cooldown = 0.0
	_winner = -1
	_in_the_net.clear()
	_afloat.clear()
	_out_for.clear()
	for ball in _balls:
		var spot := ball.home
		spot.y = _field.height_at(spot.x, spot.z)
		ball.reset_to(spot)
	_board.show_winner(-1, 0.0)
	_board.show_scores(blue, red)
	scores_changed.emit(blue, red)
	_tell_guests(-1)

## Take part in a shared game through this session, as host or as guest.
func attach(session: Session) -> void:
	_session = session
	session.remote_balls.connect(_on_remote_balls)
	session.remote_football_scores.connect(_on_remote_scores)
	session.remote_kick.connect(_on_remote_kick)
	session.remote_new_game.connect(_on_remote_new_game)
	session.guest_arrived.connect(_on_guest_arrived)

func is_following() -> bool:
	return _following

func has_ball(ball: Ball) -> bool:
	return _balls.has(ball)

func _process(delta: float) -> void:
	_sync_role()
	if _following:
		_draw_the_hosts_balls(delta)

## Notice that this phone has become a guest in somebody's valley, or stopped
## being one, and change what it does with the balls to match. Looked at every
## tick rather than waited for as a signal, so a connection that drops in any
## way at all hands the game back.
func _sync_role() -> void:
	var now := _session != null and _session.is_following()
	if now == _following:
		return
	_following = now
	_cooldown = 0.0
	_winner = -1
	_in_the_net.clear()
	_afloat.clear()
	_out_for.clear()
	_board.show_winner(-1, 0.0)
	if now:
		# Bodies kept for this valley's own guests would stay behind otherwise,
		# because _carry_guests only runs for whoever plays the game: invisible
		# solid capsules left standing on the pitch, in this child's way.
		for id: int in _bodies.keys():
			(_bodies[id] as Node).queue_free()
		_bodies.clear()
		# What is on the board is the host's from here, until the host says.
		# A match won a moment ago is not carried home as it stood: its pause
		# is cancelled here, and nothing would begin the next game.
		var own := unfinished(blue, red)
		_own_blue = own.x
		_own_red = own.y
		blue = 0
		red = 0
		for i in _balls.size():
			_balls[i].follow_the_host(true)
			_drawn[i] = {"known": false, "predicting": 0.0}
	else:
		blue = _own_blue
		red = _own_red
		for i in _balls.size():
			var ball := _balls[i]
			ball.follow_the_host(false)
			# Left going the way the host last had it, so a ball in flight
			# comes down rather than stopping in the air.
			if _drawn[i]["known"]:
				ball.linear_velocity = _drawn[i]["velocity"]
	_board.show_scores(blue, red)
	scores_changed.emit(blue, red)

# --- the host's side ----------------------------------------------------------

## Tell guests the score, and which end a goal went into if one did. Anybody who
## has just arrived is told alone, and the balls are sent at once with it.
func _tell_guests(goal: int, to_peer := 0) -> void:
	if _session == null or not _session.is_host():
		return
	_session.report_football_scores(blue, red, goal, to_peer)
	_send_at_once = true

func _on_guest_arrived(id: int, _who: String, _shirt: int) -> void:
	_tell_guests(-1, id)

## Where every ball is: position, velocity and turn, in the pitch's order.
func _states() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for ball in _balls:
		var turn := ball.basis.orthonormalized().get_rotation_quaternion()
		var v := ball.linear_velocity
		out.append_array(PackedFloat32Array([
			ball.position.x, ball.position.y, ball.position.z, v.x, v.y, v.z,
			turn.x, turn.y, turn.z, turn.w,
		]))
	return out

## Send the balls to the guests, when somebody is there to see them and
## something has moved — or the last word was a second ago, or a guest has just
## come in, or a game has just begun.
func _share(delta: float) -> void:
	_since_sent += delta
	_since_full += delta
	if _session == null or not _session.is_host() or not _session.has_company():
		return
	if _since_sent < BALL_INTERVAL:
		return
	var states := _states()
	if not _send_at_once and _since_full < BALL_HEARTBEAT and not _moved_since(states):
		return
	_since_sent = 0.0
	_since_full = 0.0
	_send_at_once = false
	_last_sent = states
	_session.report_balls(states)

func _moved_since(states: PackedFloat32Array) -> bool:
	if _last_sent.size() != states.size():
		return true
	for i in states.size():
		if absf(states[i] - _last_sent[i]) > 0.002:
			return true
	return false

## A guest asks for a ball to be kicked. Believed if somebody standing where that
## guest last said they were could have given it.
func _on_remote_kick(from: int, index: int, velocity: Vector3) -> void:
	if _session == null or not _session.is_host() or index < 0 or index >= _balls.size():
		return
	var ball := _balls[index]
	if not _session.guest_positions.has(from):
		return
	var offset: Vector3 = ball.position - (_session.guest_positions[from] as Vector3)
	offset.y = 0.0
	if offset.length() > Ball.KICK_REACH + Ball.RADIUS + KICK_SLACK:
		return
	var speed := velocity.length()
	if speed < 0.1 or speed > Ball.KICK_SPEED_CEILING + 0.5:
		return
	var strength := Ball.strength_of(velocity)
	ball.strike(velocity, strength, Ball.loft_of(velocity))
	guest_kicked.emit(strength)
	# Tell the guests now rather than at the next tick: the kicker is waiting.
	_send_at_once = true

func _on_remote_new_game(_from: int) -> void:
	if _session != null and _session.is_host():
		new_game()

# --- the guest's side ---------------------------------------------------------

## Kick a ball: on a guest's phone by asking the host, and showing the kick at
## once so that it feels instant; anywhere else by kicking it.
func kick(
	ball: Ball, from: Vector3, facing: Vector3, sprinting: bool, strength := 1.0,
	loft := 0.25, look := Vector3.ZERO
) -> float:
	var index := _balls.find(ball)
	if not _following or index < 0:
		return ball.kick(from, facing, sprinting, strength, loft, look)
	var offset := ball.position - from
	offset.y = 0.0
	if offset.length() > Ball.KICK_REACH + Ball.RADIUS:
		return 0.0
	var launch := Ball.launch_velocity(ball.position, from, facing, sprinting, strength, loft, look)
	_session.report_kick(index, launch)
	var shown := _drawn[index]
	shown["predicting"] = PREDICT_FOR
	shown["guess"] = launch
	ball.kicked.emit(clampf(strength, 0.0, 1.0), clampf(loft, 0.0, 1.0))
	return launch.length()

func _on_remote_scores(new_blue: int, new_red: int, goal: int) -> void:
	_sync_role()
	if not _following:
		return
	blue = new_blue
	red = new_red
	_board.show_scores(blue, red)
	if goal >= 0:
		_board.celebrate(1 - goal, CELEBRATION)
		goal_scored.emit(goal, blue, red)
	else:
		# A new game, or a score told to somebody arriving: nobody has just won.
		_winner = -1
		_board.show_winner(-1, 0.0)
	scores_changed.emit(blue, red)
	if goal >= 0 and (blue >= WIN_SCORE or red >= WIN_SCORE):
		_win(1 - goal)

func _on_remote_balls(states: PackedFloat32Array) -> void:
	_sync_role()
	if not _following:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for i in mini(states.size() / Session.BALL_FLOATS, _balls.size()):
		var k := i * Session.BALL_FLOATS
		var at := Vector3(states[k], states[k + 1], states[k + 2])
		var v := Vector3(states[k + 3], states[k + 4], states[k + 5])
		var turn := Quaternion(states[k + 6], states[k + 7], states[k + 8], states[k + 9])
		if absf(turn.length() - 1.0) > 0.05:
			continue
		_take_the_hosts_word(i, at, v, turn.normalized(), now)

func _take_the_hosts_word(i: int, at: Vector3, v: Vector3, turn: Quaternion, now: float) -> void:
	var ball := _balls[i]
	var shown := _drawn[i]
	# Our own kick is still being shown, and what the host says now may be from
	# before it heard of it.
	if float(shown["predicting"]) > 0.0:
		return
	var here := ball.position
	var current := ball.basis.orthonormalized().get_rotation_quaternion()
	if not shown["known"] or here.distance_to(at) > SNAP_DISTANCE:
		here = at
		current = turn
		ball.show_at(at, turn)
	# How long the host took over this step is how long to take over showing it.
	var span := 0.1
	if shown["known"]:
		span = clampf(now - float(shown["arrived"]), 0.05, 0.25)
	shown["known"] = true
	shown["arrived"] = now
	shown["age"] = 0.0
	shown["span"] = span
	shown["from"] = here
	shown["to"] = at
	shown["from_turn"] = current
	shown["to_turn"] = turn
	shown["velocity"] = v

## Slide each ball from where it was shown to where the host last put it, and
## a little on past, in the direction it was going, until the host speaks again.
func _draw_the_hosts_balls(delta: float) -> void:
	for i in _balls.size():
		var ball := _balls[i]
		var shown := _drawn[i]
		if float(shown["predicting"]) > 0.0:
			_draw_own_kick(ball, shown, delta)
			continue
		if not shown["known"]:
			continue
		shown["age"] = float(shown["age"]) + delta
		var span: float = shown["span"]
		var age: float = shown["age"]
		var turn: Quaternion = (shown["from_turn"] as Quaternion).slerp(
			shown["to_turn"], clampf(age / span, 0.0, 1.0)
		)
		if age <= span:
			ball.show_at((shown["from"] as Vector3).lerp(shown["to"], age / span), turn)
		else:
			var past := minf(age - span, 0.1)
			ball.show_at((shown["to"] as Vector3) + (shown["velocity"] as Vector3) * past, turn)

## The ball as this child's own kick sends it, under the same drag and gravity
## the host's physics gives it, and never through the grass.
func _draw_own_kick(ball: Ball, shown: Dictionary, delta: float) -> void:
	var v: Vector3 = shown["guess"]
	v.y -= ball.gravity_strength() * delta
	v *= maxf(0.0, 1.0 - ball.effective_linear_damp() * delta)
	var at := ball.position + v * delta
	at.y = maxf(at.y, _field.height_at(at.x, at.z) + Ball.RADIUS)
	shown["guess"] = v
	shown["predicting"] = float(shown["predicting"]) - delta
	var turn := ball.basis.orthonormalized().get_rotation_quaternion()
	ball.show_at(at, turn)
	if float(shown["predicting"]) <= 0.0:
		# Handed back to the host's word: from here, going on the way it was.
		shown["predicting"] = 0.0
		shown["known"] = true
		shown["arrived"] = Time.get_ticks_msec() / 1000.0
		shown["span"] = 0.05
		shown["age"] = 0.05
		shown["from"] = at
		shown["to"] = at
		shown["from_turn"] = turn
		shown["to_turn"] = turn
		shown["velocity"] = v

## The board's words again, after a change of language.
func rewrite_board() -> void:
	_board.rewrite_title()

## The board's own digits, for the checks.
func board_digits() -> PackedStringArray:
	return _board.digits()

func to_data() -> Dictionary:
	# A guest is shown the host's score, which is not theirs to save: their own
	# valley gets its own score back when they go home.
	if _following:
		return {"blue": _own_blue, "red": _own_red}
	return {"blue": blue, "red": red}

## A score read back from a save, with a match that had been won sent home.
##
## The save is written during the pause after a win too, with five goals on the
## board and the new game still seconds away. Loaded as it stood there was no
## winner and nothing to start another game, so the next goal by either side
## was "a win" for the scorer: five-two to blue, then a red goal, and red
## were cheered as the winners of the match with three.
static func unfinished(blue_goals: int, red_goals: int) -> Vector2i:
	if blue_goals >= WIN_SCORE or red_goals >= WIN_SCORE:
		return Vector2i.ZERO
	return Vector2i(blue_goals, red_goals)

func from_data(data: Dictionary) -> void:
	if _following:
		var theirs := unfinished(maxi(int(data.get("blue", 0)), 0), maxi(int(data.get("red", 0)), 0))
		_own_blue = theirs.x
		_own_red = theirs.y
		return
	# A save from before there were two sides holds one number, "score", for
	# goals in either end, and there is no telling now whose they were. It is
	# loaded as 0:0 rather than handed to blue: a child should not open the game
	# to a lead that one of two brothers never scored.
	var kept := unfinished(maxi(int(data.get("blue", 0)), 0), maxi(int(data.get("red", 0)), 0))
	blue = kept.x
	red = kept.y
	# A score put back while a match is being cheered — "start again" held at
	# that moment — ends the cheering with it: the board went on saying who had
	# won beside a 0 : 0 until the pause ran out.
	if _winner >= 0:
		_winner = -1
		_cooldown = 0.0
		_board.show_winner(-1, 0.0)
	_board.show_scores(blue, red)
	scores_changed.emit(blue, red)
	_tell_guests(-1)
