extends SceneTree

var checks := 0
var failures: Array[String] = []
var scene: Control
var samples: Array[Vector2] = []
var poses := {}

func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures.append(message)
  printerr("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func sample() -> void:
 samples.append(scene.farm.actor_position())
 poses[scene.farm.actor_sprite().file]=true

func run() -> void:
 scene=load("res://main.tscn").instantiate()
 if not scene.has_method("begin_character_walk"):
  check(false,"actual main scene has no opt-in new-character integration")
  scene.free(); quit(1); return
 scene.character_test=true
 root.add_child(scene)
 await process_frame
 check(scene.store.ready and scene.expanded,"actual main scene opens expanded with isolated storage")
 check(scene.character!=null and scene.farm.character==scene.character,"real FarmView shares the main scene character controller")
 check(scene.farm.actor_sprite().texture is Texture2D,"real renderer receives complete new character textures")
 check(scene.character.kind=="idle" and scene.music==null,"test starts in relaxed idle without autoplay or music")
 var state: Dictionary=scene.store.snapshot()
 check(not scene.issue({"type":"plant","plot":0,"crop":"welcome"},false).ok,"unsupported farm work is blocked, not played with old avatar")
 check(scene.store.snapshot()==state,"blocked work makes no save mutation")
 await capture("idle")
 scene.begin_character_walk()
 await create_timer(.18).timeout
 var opening_distance: float=scene.character.travelled
 check(opening_distance>.5 and scene.character.kind=="depart","native first step moves along the lane before regular walking begins")
 scene.character_stop.pressed.emit()
 await create_timer(.7).timeout
 check(scene.character.kind=="idle" and scene.character.travelled>opening_distance and scene.character.travelled-opening_distance<3,"native interrupted first step decelerates into a nearby stable stance")
 await capture("early-stop")
 scene.character_reset.pressed.emit()
 var click:=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
 click.position=scene.farm.world_to_view(Vector2(132,186))
 scene.farm._gui_input(click)
 check(scene.character.kind=="depart","clicking the real first plot begins the character route")
 await create_timer(.12).timeout
 await capture("starting")
 await create_timer(.18).timeout
 scene.farm.draw.connect(sample)
 await create_timer(.7).timeout
 scene.farm.draw.disconnect(sample)
 check(samples.size()>=28 and poses.size()>=5,"actual native scene draws movement frequently with distinct complete-body poses")
 var continuous:=true
 for i in range(1,samples.size()):
  if samples[i].distance_to(samples[i-1])>1.5: continuous=false
 check(continuous and Engine.max_fps==60,"real movement stays continuous under a sixty FPS cap")
 await capture("walking")
 var controller=scene.character
 var point: Vector2=controller.position()
 scene.set_expanded(false); scene.set_expanded(true)
 check(scene.farm.character==controller and scene.farm.actor_position()==point,"window rebuild preserves exact character and position")
 scene.show_page("bag")
 var distance: float=controller.travelled
 await create_timer(.2).timeout
 scene.show_page("farm")
 check(controller.travelled>distance and scene.farm.character==controller,"real page navigation retains and advances character once")
 scene.character_stop.pressed.emit()
 await create_timer(2).timeout
 check(controller.kind=="idle" and not controller.arrived(),"manual stop settles naturally before the route endpoint")
 await capture("stopped")
 scene.action_button.pressed.emit()
 await create_timer(6).timeout
 check(controller.arrived() and controller.kind=="idle","resume reaches the real first plot and settles to idle")
 check(scene.farm.actor_position().distance_to(Vector2(156,174))<.001,"feet stop at existing outside-field work point")
 check(scene.farm.actor_sprite().file==controller.art.packet("idle",0,0).file,"arrival holds the current idle art, not a frozen wide stride")
 check(scene.store.snapshot().work.is_empty() and scene.store.snapshot().plots==state.plots,"visual route has not planted crops or started saved work")
 await capture("arrived")
 scene.set_expanded(false)
 await capture("compact")
 scene.set_expanded(true)
 scene.character_reset.pressed.emit()
 check(controller.position()==Vector2(228,138) and not scene.action_button.disabled,"explicit reset returns home and enables another run")
 print("Farm character native checks: ",checks,"; failures: ",failures.size(),"; sampled frames: ",samples.size(),"; walk poses: ",poses.size())
 scene.shutdown(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
 var path:=OS.get_environment("TOKENBOOK_CAPTURE_DIR")
 if path.is_empty(): return
 await process_frame
 # Explicitly render the frame being captured; a screenshot must not wait
 # indefinitely for another window presentation after the character rests.
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(path.path_join(label+".png"))
