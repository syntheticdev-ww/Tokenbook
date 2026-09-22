extends SceneTree

var checks := 0
var failures := 0
var scene: Control
var draws := 0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void: run.call_deferred()
func sample() -> void: draws+=1
func run() -> void:
 scene=load("res://main.tscn").instantiate()
 scene.character_test=true
 root.add_child(scene)
 await process_frame
 await RenderingServer.frame_post_draw
 check(scene.farm.ambient_enabled and scene.farm._environment_layer!=null,"real game installs environment below the unchanged actor/crop layers")
 var point: Vector2=scene.character.position()
 var clock_before: float=scene.farm._environment_layer.clock
 var saved: Dictionary=scene.store.snapshot()
 scene.farm.draw.connect(sample)
 await create_timer(.8).timeout
 scene.farm.draw.disconnect(sample)
 check(draws>=18 and Engine.max_fps==30,"idle farm keeps living at a restrained thirty FPS")
 check(scene.farm._environment_layer.clock-clock_before>.65 and scene.farm._environment_layer.clock-clock_before<1.1,"idle environment advances once at real time")
 check(scene.character.position()==point and scene.character.kind=="idle","environment does not move the character")
 await capture("idle-environment")
 clock_before=scene.farm._environment_layer.clock
 scene.set_expanded(false)
 await process_frame
 await RenderingServer.frame_post_draw
 check(scene.farm==null and scene.pet!=null,"desktop pet replaces and releases the compact farm renderer")
 await capture("compact-environment")
 scene.set_expanded(true)
 scene.show_page("bag")
 await create_timer(.15).timeout
 check(Engine.max_fps==24,"hidden farm page does not force continuous high-rate rendering")
 scene.show_page("farm")
 await process_frame
 await RenderingServer.frame_post_draw
 check(scene.farm._environment_layer.clock>clock_before and absf(scene.farm._environment_layer.clock-scene.farm_motion.clock)<.08,"rebuilding the farm does not restart the wind/water clock")
 scene.begin_character_walk()
 await create_timer(.4).timeout
 check(Engine.max_fps==60 and scene.character.travelled>0,"walking retains sixty FPS with the environment active")
 scene.character.request_stop()
 await create_timer(1.8).timeout
 scene.hide_game()
 await create_timer(.2).timeout
 clock_before=scene.farm._environment_layer.clock
 await create_timer(.25).timeout
 check(scene.game_hidden and Engine.max_fps==12 and scene.farm._environment_layer.clock==clock_before,"hidden companion suspends environment updates and rendering")
 scene.show_game()
 await process_frame
 await RenderingServer.frame_post_draw
 check(scene.farm._environment_layer.clock>clock_before,"restored companion resynchronizes to the existing world clock")
 check(scene.store.snapshot().plots==saved.plots and scene.store.snapshot().inventory==saved.inventory,"ambient effects do not change crops, inventory or rewards")
 print("Environment real-window checks: ",checks,", failures: ",failures,"; idle draws in .8s: ",draws)
 scene.shutdown(0 if failures==0 else 1)

func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("TOKENBOOK_CAPTURE_DIR").path_join(name+".png"))
