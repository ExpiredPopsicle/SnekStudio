extends Label

func _ready():
	text = \
		ProjectSettings.get_setting("application/config/name") + "\n" + \
		"v" + ProjectSettings.get_setting("application/config/version")
