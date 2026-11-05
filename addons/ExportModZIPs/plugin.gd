@tool
extends EditorPlugin

var plugin: ExportModZIPs

func _enter_tree():
	plugin = ExportModZIPs.new()
	add_export_plugin(plugin)

func _exit_tree():
	remove_export_plugin(plugin)
	plugin = null
