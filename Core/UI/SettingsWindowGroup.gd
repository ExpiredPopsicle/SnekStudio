extends PanelContainer
class_name SettingsWindowGroup

func _on_check_box_show_group_toggled(toggled_on: bool) -> void:
	%Container_SettingsGroup.visible = toggled_on

func add_setting_control(setting_control : Control) -> void:
	%Container_SettingsGroup.add_child(setting_control)

func set_label(label_text : String) -> void:
	%Label.text = label_text
