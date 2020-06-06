# [Godot] PackedSceneLoader
GDScript that provides functions to load and unload PackedScenes from the memory to easily handle caching and transition between scenes

## Example usage
```
#define your own packed scene paths
const SCENE1_PATH = "scenes/Scene1.tscn"

#autoload in the root scene
var PackedSceneLoader = preload("scripts/PackedSceneLoader.gd").new()

#load required packed scenes
PackedSceneLoader.loadPackedSceneAsync(SCENE1_PATH)

while(true):

    update_animation() #if you have a loading screen
    
    #check if the required packed scene is ready
    if(PackedSceneLoader.getLoadingState(SCENE1_PATH) == PackedSceneLoader.LoadingState.LOADED):
      
        # note that: instance() and add_child() may lock the thread for a bit...
        var instance = PackedSceneLoader.getPackedScene(SCENE1_PATH).instance()
        if(instance == null):
            send_error()
        else:
            $parentNode.call_deferred("add_child", instance)
            PackedSceneLoader.unloadPackedScene(SCENE1_PATH) # unload packed scenes if not needed for caching
```
