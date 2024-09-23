@tool
extends EditorPlugin

var python_build_export_plugin = null
var build_updater : Control = null

func _enter_tree():
	assert(not python_build_export_plugin)
	python_build_export_plugin = KiriPythonBuildExportPlugin.new()
	add_export_plugin(python_build_export_plugin)
	
	# Add the build updater UI to the Godot UI.
	build_updater = load(get_script().resource_path.get_base_dir().path_join(
		"UpdateUI/PythonBuildUpdateUI.tscn")).instantiate()
	add_control_to_bottom_panel(build_updater, "Python Builds")

func _exit_tree():
	assert(python_build_export_plugin)
	remove_export_plugin(python_build_export_plugin)
	python_build_export_plugin = null
	build_updater.queue_free()
	build_updater = null
