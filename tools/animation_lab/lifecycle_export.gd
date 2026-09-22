extends "surface_preview.gd"

# Offline-only extension of the preserved art candidate. The game consumes
# only the exported PNGs and ground registration, never this 3D scene.
static func filename_at(index: int) -> String:
 if index<63: return "walk-%03d.png" % index
 if index<100: return "stop-%03d.png" % (index-63)
 if index<137: return "stop_half-%03d.png" % (index-100)
 return "start-%03d.png" % (index-137)

static func pose_at(index: int) -> Dictionary:
 if index<63: return Gait.sample(index/63.0)
 if index<100: return Gait.settle(1,(index-63)/36.0)
 if index<137: return Gait.settle(.5,(index-100)/36.0)
 return Gait.depart((index-137)/30.0)

func _initialize() -> void:
 super._initialize()
 if not sprite_export:
  printerr("Lifecycle export requires -- --sprites NEW_ABSOLUTE_DIRECTORY")
  quit(2)

func _process(_delta: float) -> bool:
 if not actors.is_empty(): render_pose(pose_at(maxi(0,capture_frame)))
 return false

func capture_after_draw() -> void:
 if capturing: return
 capturing=true
 if capture_frame>=0:
  for i in range(views.size()):
   var folder := capture_dir.path_join(preview_view_names()[i])
   DirAccess.make_dir_recursive_absolute(folder)
   if views[i].get_texture().get_image().save_png(folder.path_join(filename_at(capture_frame)))!=OK:
    printerr("Failed to save lifecycle frame")
    quit(1)
    return
 capture_frame+=1
 if capture_frame>=168:
  RenderingServer.frame_post_draw.disconnect(capture_after_draw)
  var data := {"purpose":"lifecycle candidate; not installed in game","fps":60,"frames":168,"cycle_frames":63,"walk_frames":63,"closing_frames":37,"alternate_closing_frames":37,"start_frames":31,"start_seconds":Gait.DEPART_PERIOD,"size":[256,320],"views":["front","back"],"transparent":true,"loop_endpoint_duplicate":false,"anchors":{},"stride_pixels":{},"stop_advance_cycles":[],"start_advance_cycles":[]}
  for i in range(37): data.stop_advance_cycles.append(Gait.settle(0,i/36.0).root.z/Gait.STRIDE)
  for i in range(31): data.start_advance_cycles.append(Gait.depart(i/30.0).root.z/Gait.STRIDE)
  for i in range(cameras.size()):
   var anchor := cameras[i].unproject_position(Vector3.ZERO)
   var stride := cameras[i].unproject_position(Vector3(0,0,Gait.STRIDE))-anchor
   data.anchors[preview_view_names()[i]]=[anchor.x,anchor.y]
   data.stride_pixels[preview_view_names()[i]]=[stride.x,stride.y]
  var file := FileAccess.open(capture_dir.path_join("capture.json"),FileAccess.WRITE)
  if file==null: printerr("Failed to save lifecycle registration"); quit(1); return
  file.store_string(JSON.stringify(data,"  "))
  print("Lifecycle export complete: 168 frames per direction; ",capture_dir)
  quit()
 capturing=false
