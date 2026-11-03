class_name SeatPose
extends RefCounted

## How a child sits in each of the ways they are carried: on a horse, a bicycle,
## a motorcycle, a quad or in a boat, and on the carousel, the big wheel, the
## coaster, the drop tower, the pirate ship and the swing.
##
## A pose is where the body goes, in the rig's own frame (x to the child's right,
## y up, -z ahead), and the rig's origin is the point on the carrier the child's
## feet would be standing at: for a mount that is the mount's own origin lifted
## by MountKinds.eye_lift (which is what the game already does), and for a ride
## it is the ride's own footing under the seat, which the ride names (see
## Carousel.seat_near and its fellows). Every number below is read off the
## drawing of the thing it is for, with the source named beside it: a saddle
## drawn at one height and a pose written for another is a child in the saddle
## or a hand's breadth above it, and the checks hold each to the seat.
##
## The body is solved from three things rather than written joint by joint:
## where the seat is (the hips), where the hands go and where the feet go. That
## is what lets one pose serve five characters with legs of different lengths:
## the limbs are bent to reach the places, and RigMotion does that.
##
##   seat    where the pelvis sits: x, the TOP of the seat, z. The hips come to
##           the seat plus the pelvis's own depth (about nine centimetres).
##   lean    how far the body is tipped forward, in radians.
##   nod     how far the head is tipped back to keep its eyes on the way ahead.
##   hand    the left hand's grip; the right is its mirror.
##   reach   how much longer the arms are drawn when seated (1 = as they are).
##           A child's arm is a third of a metre and every machine here was
##           drawn for a grown rider, so on the ones that put the bars further
##           off than that the arms are stretched: a hand on the grip with a
##           long arm reads better than a hand held out in the air.
##   foot    the left ankle; the right is its mirror.
##   toe     which way the sole is turned: up positive, down negative.
##   knee    the way the knees point, as a direction for the left leg.
##   elbow   the same for the left elbow.
##   style   what moves while carried: &"rock" a stride's rocking, &"pedal" legs
##           turning with the wheel, &"paddle" a stroke on either side,
##           &"pump" the legs thrown out and tucked in with a swing's tilt
##           (the pose names its "tuck" and "stretch" offsets of the foot).

## How far a pelvis hangs below its hips joint, for the usual rig: the seat
## plus this is where the hips go. RigMotion measures each rig's own.
const PELVIS := 0.09

const POSES := {
	# The horse's saddle: the seat box is centred at HORSE_SADDLE_Y (the rig's
	# own origin, because that is where eye_lift puts the child) and 0.168 high,
	# so its top is 0.084 above, with the pommel at z -0.24 and the reins made
	# fast to it. The barrel is 0.82 across at the saddle: the legs go out and
	# down over it, astride.
	&"horse": {
		"seat": Vector3(0.0, 0.084, 0.06), "lean": 0.5, "nod": 0.25,
		"hand": Vector3(-0.11, 0.27, -0.27), "reach": 1.1,
		"foot": Vector3(-0.40, -0.15, 0.06), "toe": -0.5,
		"knee": Vector3(-0.2, 0.2, -1.0), "elbow": Vector3(-1.0, -0.2, 0.3),
		"style": &"rock",
	},
	# A bicycle is a child's own, so it is drawn for one: the saddle 0.55 up
	# (0.10 in the rig, which is 0.45 up) and 0.30 back, the pedals at the
	# bottom bracket (0, 0.34, 0.16) with cranks 0.12 long, and the bars at
	# (0, 0.88, -0.43) with the grips 0.18 to 0.28 out, within a child's reach
	# as they lean to them. It was drawn for a grown rider, the saddle 1.25 up,
	# and the child stood on the pedals with arms stretched to a third longer.
	&"bicycle": {
		"seat": Vector3(0.0, 0.10, 0.21), "lean": 0.8, "nod": 0.7,
		"hand": Vector3(-0.23, 0.43, -0.41), "reach": 1.0,
		"foot": Vector3(-0.13, -0.02, 0.16), "toe": 0.0,
		"knee": Vector3(-0.1, 0.3, -1.0), "elbow": Vector3(-1.0, -0.2, 0.3),
		"style": &"pedal", "pedal_radius": 0.12, "pedal_lift": 0.09,
	},
	# The motorcycle's saddle is 0.52 long, top at 1.12 (the rig is 0.62 up), and
	# the child sits at its front. The grips are at (0, 1.20, -0.46), 0.22 to 0.34
	# out: the head tube was brought back 0.08 so that a child's own arm reaches.
	# The legs go round the tank and the feet rest by the engine.
	&"motorcycle": {
		"seat": Vector3(0.0, 0.50, 0.16), "lean": 1.2, "nod": 0.9,
		"hand": Vector3(-0.30, 0.58, -0.43), "reach": 1.05,
		"foot": Vector3(-0.26, 0.31, 0.20), "toe": -0.3,
		"knee": Vector3(-0.4, 0.2, -1.0), "elbow": Vector3(-1.0, -0.2, 0.3),
		"style": &"",
	},
	# The quad's seat is 0.86 x 1.15 = 0.99 up (the rig is 0.72 up), its grips
	# at (0.414, 1.357, -0.46) and its footwells 0.506 out, their tops at
	# 0.69 x 1.15 = 0.79. The bars were 0.2 further forward and the boards 0.27
	# lower, which was beyond a child's arm and leg; both are brought in.
	&"quad": {
		"seat": Vector3(0.0, 0.27, 0.06), "lean": 1.1, "nod": 0.9,
		"hand": Vector3(-0.41, 0.64, -0.46), "reach": 1.05,
		"foot": Vector3(-0.38, 0.135, 0.04), "toe": 0.0,
		"knee": Vector3(-0.4, 0.3, -1.0), "elbow": Vector3(-1.0, -0.2, 0.3),
		"style": &"",
	},
	# The boat: a thwart at 0.11 above the boat's origin (the rig is 0.15 up),
	# the rowing one at z 0.1 and 0.3 wide, which is where a child stands. The
	# oars cross the gunwales at z 0.1, their handles tipped up to the middle,
	# 0.34 above the rig's origin at 0.22 out. Sitting, knees up, feet on the floor,
	# hands on the oars, and a stroke on either side when it moves.
	&"boat": {
		"seat": Vector3(0.0, -0.04, 0.10), "lean": 0.2, "nod": 0.1,
		"hand": Vector3(-0.22, 0.34, 0.10), "reach": 1.2,
		"foot": Vector3(-0.14, -0.20, -0.20), "toe": 0.0,
		"knee": Vector3(-0.3, 1.0, -0.6), "elbow": Vector3(-1.0, -0.3, 0.3),
		"style": &"paddle",
	},
	# The carousel horse: the origin is the top of the saddle's centre, which
	# is also where the brass pole stands, so the child sits behind it (the
	# saddle runs 0.39 back, the cantle after) with the pole in front of them
	# and a hand either side of it, and the horse's mane, which rises to 0.48
	# at 0.38 ahead, well clear of the body. The barrel is 0.5 across.
	&"carousel": {
		"seat": Vector3(0.0, 0.0, 0.18), "lean": 0.4, "nod": 0.2,
		"hand": Vector3(-0.08, 0.52, -0.02), "reach": 1.0,
		"foot": Vector3(-0.30, -0.22, 0.10), "toe": -0.3,
		"knee": Vector3(-0.2, 0.6, -1.0), "elbow": Vector3(-1.0, -0.2, 0.3),
		"style": &"",
	},
	# The big wheel's gondola: the origin is the floor under the back of the
	# bench, whose top is 0.52 x 1.5 above it with the back against it; the
	# legs go out along the bench and the hands rest on the thighs.
	&"wheel": {
		"seat": Vector3(0.0, 0.78, 0.0), "lean": 0.1, "nod": 0.0,
		"hand": Vector3(-0.19, 1.00, -0.12), "reach": 1.15,
		"foot": Vector3(-0.12, 0.88, -0.40), "toe": 0.2,
		"knee": Vector3(-0.2, 1.0, -0.2), "elbow": Vector3(-1.0, -0.2, 0.3),
		"style": &"",
	},
	# The coaster's car: the origin is the rider's place on the floor, the
	# cushion 0.48 above it and 0.43 behind the back, the seat back's face
	# 0.21 behind. The cushion is 0.9 deep, a grown rider's, so the legs go
	# out along it, and the hands are on the harness at the shoulders.
	&"coaster": {
		"seat": Vector3(0.0, 0.48, 0.08), "lean": 0.05, "nod": 0.0,
		"hand": Vector3(-0.27, 0.86, -0.26), "reach": 1.15,
		"foot": Vector3(-0.12, 0.58, -0.30), "toe": 0.2,
		"knee": Vector3(-0.2, 1.0, -0.2), "elbow": Vector3(-1.0, -0.2, 0.3),
		"style": &"",
	},
	# The drop tower's seat: the origin is the top of its cushion, 0.46 deep,
	# with the back's face 0.14 behind the middle. The legs hang over the front
	# edge and the hands hold the harness's pads, which lie on the shoulders
	# 0.36 out from the middle at about 0.6 up (DropTower.HARNESS_*): a child's
	# arm does not reach the lap bar, 0.3 ahead of the middle.
	&"drop_tower": {
		"seat": Vector3(0.0, 0.0, 0.05), "lean": 0.1, "nod": 0.0,
		"hand": Vector3(-0.36, 0.62, -0.24), "reach": 1.15,
		"foot": Vector3(-0.12, -0.20, -0.24), "toe": -0.5,
		"knee": Vector3(-0.1, 1.0, -0.3), "elbow": Vector3(-1.0, -0.2, 0.3),
		"style": &"",
	},
	# The pirate ship's seat: the origin is the top of the cushion, 0.6 deep and
	# 0.8 wide, with the back's face 0.3 behind it. The legs go out along it
	# and the hands hold the side arms of the lap bar, which stand 0.34 out and
	# are 0.7 up where they pass the chest (PirateShip.BAR_*): the bar itself is
	# 0.48 ahead of the middle, more than a child's arm.
	&"pirate_ship": {
		"seat": Vector3(0.0, 0.0, 0.17), "lean": 0.05, "nod": 0.0,
		"hand": Vector3(-0.34, 0.69, -0.12), "reach": 1.15,
		"foot": Vector3(-0.12, 0.10, -0.22), "toe": 0.2,
		"knee": Vector3(-0.2, 1.0, -0.2), "elbow": Vector3(-1.0, -0.2, 0.3),
		"style": &"",
	},
	# The swing: the origin is the top of the seat's centre, which is 0.3 deep
	# and hangs on chains 0.34 either side. The hands are on the chains, the
	# legs out in front.
	&"swing": {
		"seat": Vector3(0.0, 0.0, 0.04), "lean": -0.05, "nod": 0.0,
		"hand": Vector3(-0.34, 0.42, -0.02), "reach": 1.0,
		"foot": Vector3(-0.12, -0.17, -0.28), "toe": -0.4,
		"knee": Vector3(-0.2, 0.6, -1.0), "elbow": Vector3(-1.0, -0.2, 0.3),
		# Pumping: the legs are tucked back under the seat as it swings back
		# and thrown out and up as it swings forward, added to the foot above.
		"style": &"pump", "tuck": Vector3(0.0, -0.06, 0.26), "stretch": Vector3(0.0, 0.14, -0.08),
	},
}
