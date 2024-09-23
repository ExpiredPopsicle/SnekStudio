extends AudioStreamPlayer

var _last_max_level = 0.0

func get_current_input_level():
	return _last_max_level

func get_input_volume_linear_scale():

	var db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Record"))

	var volume_scale = exp((log(10) / 20.0) * db)
	if db <= -30:
		volume_scale = 0

	return volume_scale	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	
	var volume_scale = get_input_volume_linear_scale()
	
	var bus_index = AudioServer.get_bus_index("Record")
	var effect : AudioEffectCapture = AudioServer.get_bus_effect(bus_index, 0)
	
	var frame_count = effect.get_frames_available()
	var data = effect.get_buffer(frame_count)
	
	var max_data = 0.0
	for k in data:
		if k[0] > max_data:
			max_data = k[0]
		if k[1] > max_data:
			max_data = k[1]

	max_data *= volume_scale
	
	_last_max_level = max_data
	
	#print("VOLUME: ", _last_max_level)
	
	effect.clear_buffer()
	
	# Debug volume output.
	#var out_str = ""
	#for k in range(0, int(10.0 * max_data_left / 0.05)):
	#	if k > 100:
	#		break
	#	out_str += "#"
	#print(out_str)
