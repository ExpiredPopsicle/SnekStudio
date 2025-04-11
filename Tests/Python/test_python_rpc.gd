extends Node3D


var tracker_python_process : KiriPythonWrapperInstance = null


func _spam_all_the_rpcs():
	
	for i in range(0, 5):
		print("Attempting a call... ", i)
		tracker_python_process.call_rpc_async("blargh", [i])
	
	pass

func _ready() -> void:

	var script_path : String = self.get_script().get_path()
	var script_dirname : String = script_path.get_base_dir()
	tracker_python_process = KiriPythonWrapperInstance.new( \
		script_dirname.path_join("/test.py"))
	
	tracker_python_process.setup_python(true)
	
	tracker_python_process.start_process()
	
	print("Kicking off thing...")
	var r = await tracker_python_process.execute_python_async(["-m", "pip", "install", "mediapipe==0.10.21"])
	print("Done thing: ", r)
	

	_spam_all_the_rpcs()

func _process(_delta):
	tracker_python_process.poll()
