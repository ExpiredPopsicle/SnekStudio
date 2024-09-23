extends Control


func _ready():
	var n = FileAccess.file_exists("res://Mods/ThrownObjects/Objects/GPU/GPU5.glb.import")
	var c : ConfigFile = ConfigFile.new()
	c.load("res://Mods/ThrownObjects/Objects/GPU/GPU5.glb.import")
	print(c)

	print(c.get_value("remap", "path"))
