extends SceneTree

func _initialize():
	var f : FileAccess = FileAccess.open("res://Build/build_vars.sh", FileAccess.WRITE)
	f.store_string("VERSION=" + ProjectSettings.get("application/config/version") + "\n")
	f.close()
	quit(0)
