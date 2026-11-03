extends SceneTree

## For tuning SeatPose: sits every character in every pose and prints how far its
## hips are from the seat and how far its wrists and ankles are from the places
## the pose names (the wrist stops 0.04 short of a grip, so 0.04 is "on it").
##
##   godot --headless --path . --script src/dev/seat_probe.gd

func _in_rig(joint: Node3D, rig: Node3D) -> Vector3:
	var at := joint.position
	var up := joint.get_parent() as Node3D
	while up != rig:
		at = up.transform * at
		up = up.get_parent() as Node3D
	return at

func _initialize() -> void:
	var root := get_root()
	for pose: StringName in SeatPose.POSES.keys():
		var spec: Dictionary = SeatPose.POSES[pose]
		for which in 5:
			var parent := Node3D.new()
			root.add_child(parent)
			var rig := Character.build(which, 1, 1, Visitors.SHIRTS[2])
			parent.add_child(rig)
			var motion := RigMotion.new(rig)
			motion.seat = pose
			motion.gait = 0.0
			for _i in 80:
				motion.step(1.0 / 60.0)
			var hips := rig.find_child("Hips", true, false) as Node3D
			var seat: Vector3 = spec["seat"]
			var line := "%s %s hips drop %.3f" % [pose, Character.KEYS[which], hips.position.y - motion._pelvis - seat.y]
			for side in 2:
				var tag := "L" if side == 0 else "R"
				var hand := rig.find_child("Hand" + tag, true, false) as Node3D
				var foot := rig.find_child("Foot" + tag, true, false) as Node3D
				var grip: Vector3 = spec["hand"]
				var ankle: Vector3 = spec["foot"]
				var gx := grip.x if side == 0 else -grip.x
				var ax := ankle.x if side == 0 else -ankle.x
				var hand_miss := (_in_rig(hand, rig) - Vector3(gx, grip.y, grip.z)).length()
				var foot_miss := (_in_rig(foot, rig) - Vector3(ax, ankle.y, ankle.z)).length()
				line += " | %s hand %.3f foot %.3f" % [tag, hand_miss, foot_miss]
			print(line)
			parent.queue_free()
	quit()
