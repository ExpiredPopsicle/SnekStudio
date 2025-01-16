extends BasicSubWindow

func _output_index_selected(index):
	var output_device_list = AudioServer.get_output_device_list()
	%MenuButton_OutputDevice.text = output_device_list[index]
	update_to_app()

func _input_index_selected(index):
	var input_device_list = AudioServer.get_input_device_list()
	%MenuButton_InputDevice.text = input_device_list[index]
	update_to_app()

func _ready():
	register_serializable_subwindow()
	%MenuButton_OutputDevice.get_popup().index_pressed.connect(_output_index_selected)
	%MenuButton_InputDevice.get_popup().index_pressed.connect(_input_index_selected)

func settings_changed_from_app():
	var app = _get_app_root()
	var settings_dict = app.serialize_settings(true, false)

	# (Re)Populate audio device lists.
	var output_device_list = AudioServer.get_output_device_list()
	var output_popup = %MenuButton_OutputDevice.get_popup()
	output_popup.clear()
	for output_device in output_device_list:
		output_popup.add_item(output_device)

	var input_device_list = AudioServer.get_input_device_list()
	var input_popup = %MenuButton_InputDevice.get_popup()
	input_popup.clear()
	for input_device in input_device_list:
		print(input_device)
		input_popup.add_item(input_device)
		
	if "volume_input" in settings_dict:
		%HSlider_InputVolume.value = settings_dict["volume_input"]
	if "volume_output" in settings_dict:
		%HSlider_OutputVolume.value = settings_dict["volume_output"]
	if "sound_device_output" in settings_dict:
		%MenuButton_OutputDevice.text = settings_dict["sound_device_output"]
	if "sound_device_input" in settings_dict:
		%MenuButton_InputDevice.text = settings_dict["sound_device_input"]

func show_window():
	super.show_window()
	settings_changed_from_app()

func update_to_app():
	
	var app = _get_app_root()
	
	var settings_dict = {}
	settings_dict["volume_output"] = %HSlider_OutputVolume.value
	settings_dict["volume_input"] = %HSlider_InputVolume.value
	settings_dict["sound_device_output"] = %MenuButton_OutputDevice.text
	settings_dict["sound_device_input"] = %MenuButton_InputDevice.text
	
	app.deserialize_settings(settings_dict)

func _any_value_changed(_value):
	update_to_app()
