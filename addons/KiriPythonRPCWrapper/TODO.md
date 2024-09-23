Done:
	x Handle bundling of the actual Python modules we want to use.
	x Remove dependency on psutil.
	x Clean up removal of psutil.
	x remove parent_pid from wrapper script
	x remove KiriPythonRPCWrapper_start.py
	x remove test_rpc.py
	x Un-thread the GDScript side of PacketSocket.
		x Fix whatever this is: <stuff was here>
	x example Python module from OUTSIDE the addon
	x Remove xterm dependency, or make it like a debug-only thing.
	x Test on WINE/Windows.
	x First-time setup of requirements (pip, etc).
	x Deal with interrupted setup operations
		x We check for the python.exe file in a given setup location to see if
		  we need to unpack stuff, but what if that exists but the setup was
		  interrupted and we're missing files?
	x Deal with bad state after interrupted unpacking operation

The big ones:

	- Add some kind of progress bar, or API for progress tracking, for the unpacking.
	- Progress bar or API for progress tracking for pip installs.
		- Maybe we should parse the pip requirements.txt and also set up an API for calling pip install.
	- Documentation.
		- how to use .kiri_export_python
	- Check the PYTHON.json file for binary locations ("python_exe" entry)
	- Maybe switch to the install_only variant of the Python builds?
	
	- Document how to use
	- Document how to package Python stuff
