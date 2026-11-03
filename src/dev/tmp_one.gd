extends SceneTree
func _expect(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
func _initialize() -> void:
	var field := HeightField.new(20260903)
	var mounts := Mounts.new(field)
	get_root().add_child(mounts)
	var camp := field.camp_centre()
	mounts.place(&"horse:0", camp + Vector3(3.0, 0.0, 0.0))
	mounts.place(&"horse:1", camp + Vector3(-12.0, 0.0, 0.0))
	mounts.ride_remote(&"horse:1", camp + Vector3(-20.0, 0.0, 0.0), 0.0)
	mounts.mount(&"horse:0")
	var leg := mounts.node_of(&"horse:0").get_node("Body/Leg2") as Node3D
	leg.rotation.x = 0.8
	mounts.dismount(camp, 0.0)
	mounts.release_remote(&"horse:1")
	for _i in 120:
		mounts._process(0.05)
	_expect(absf(leg.rotation.x) < 0.02, "settles %.2f" % leg.rotation.x)
	quit()
