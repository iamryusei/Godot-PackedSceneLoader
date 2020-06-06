##
# script: PackedSceneLoader
# author:  Leonardo Spaccini <leoanrdo.spaccini.gtr@gmail.com>
# company: Comet Weavers Lab.
# version: 0.9
# description: 
#     this script provides functions to load and unload PackedScenes
#     synchronously or asynchronously, helping to manage caching and
#     transition between scenes in a simple way.
# 
# to-do:
#     + loadPackedSceneSync(...)
#     + getLoadingProgress(...)
##

class_name PackedSceneLoader

##
# Enum that represents the loading state of each PackedScene
enum LoadingState {
	NOT_LOADED,
	IS_LOADING,
	LOADED,
	LOADING_ERROR,
}

# private dictionary of loaded PackedScenes: 
# the key of the dictionary is the scenePath which uniquely identifies a PackedScene.
# each element is another dictionary which always and only contains the
# keys "package" and "state".
var _packedscenes = {}

# private threading variables
var _thread = null
var _threadBusy = false
var _mutex = Mutex.new()



##
# Returns the LoadingState of the PackedScene associated to the given 'path'.
#
func getLoadingState(path):
	var out
	_mutex.lock()
	
	if(!_packedscenes.has(path)):
		out = LoadingState.NOT_LOADED
	else:
		out = _packedscenes[path]["state"]
		
	_mutex.unlock()
	return out

##
# Returns the PackedScene object associated to the given 'path'.
# If such scene is not LOADED, returns 'null' instead.
#
func getPackedScene(path):
		
	var out
	_mutex.lock()
	
	# if the scene is not loaded, return null
	if(!_packedscenes.has(path) || _packedscenes[path]["state"] != LoadingState.LOADED):
		out = null
	else:
		out = _packedscenes[path]["package"]
		
	_mutex.unlock()
	return out


##
# Removes the PackedScenes associated to the given 'path' from the memory.
#
func unloadPackedScene(path):
	_mutex.lock()
	_packedscenes.erase(path)
	_mutex.unlock()


##
# Asynchronously loads the PackedScene associated to the given 'path'
# into the memory, for it to be obtained trough "getPackedScene(path)" function.
#
# Returns @GlobalScope 'OK' if the PackedScene starts loading (this doesn't implies
# that the PackedScene will completely load with success),
# or a @GlobalScope error code instead.
# If the PackedScene is already loaded, returns @GlobalScope 'OK' immediately.
#
# If another PackedScene is already beign loaded asynchronously, returns 
# @GlobalScope 'ERR_BUSY'
#
func loadPackedSceneAsync(path):
	var out = 0
	_mutex.lock()
	
	# if the PackedScene is already loaded, returns immediately
	if(_packedscenes.has(path) && _packedscenes[path]["state"] == LoadingState.LOADED):
		out = OK
		
	# if another PackedScene is being loaded async., return error
	elif(_threadBusy):
			out = ERR_BUSY
	else:
		
		# register the PackedScene into dictionary
		_packedscenes[path] = {
			"package": null,
			"state": LoadingState.IS_LOADING,
		}
		
		# prepares an interactive ResourceLoader and checks for errors
		var sceneloader = ResourceLoader.load_interactive(str(path))
		if(sceneloader == null):
			out = ERR_FILE_BAD_PATH
		else:
			# start a new thread that asynchronously polls the ResourceLoader
			# until the PackedScene is completely loaded
			_threadBusy = true
			_thread = Thread.new()
			out = _thread.start(self, "_loader_poll", [sceneloader, path])
			
	_mutex.unlock()
	return out


func _loader_poll(args):
	
	#sceneloader = args[0]
	#path = args[1]
	
	while (true):
		var state = args[0].poll();
		
		# loading in progress...
		if state == OK:
			continue;
			
		# loading completed...
		elif state == ERR_FILE_EOF:
			_mutex.lock()
			_packedscenes[args[1]]["package"] = args[0].get_resource()
			_packedscenes[args[1]]["state"]   = LoadingState.LOADED
			_threadBusy = false
			_mutex.unlock()
			return
			
		# loading error..
		else:
			_mutex.lock()
			_packedscenes[args[1]]["package"] = null
			_packedscenes[args[1]]["state"]   = LoadingState.LOADING_ERROR
			_threadBusy = false
			_mutex.unlock()
			return;
