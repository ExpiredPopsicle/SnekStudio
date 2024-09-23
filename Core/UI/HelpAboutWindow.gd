extends BasicSubWindow

func _ready():
	%Label_NameAndVersion.text = \
		ProjectSettings.get_setting("application/config/name") + "\n" + \
		"v" + ProjectSettings.get_setting("application/config/version")
