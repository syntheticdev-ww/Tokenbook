extends "character_mesh.gd"

# One static paint source, attached to the bind surface. Animation changes
# bones only: it never regenerates faces, colours, textures or arm sizes.
var front_uv := PackedVector2Array()
var back_uv := PackedVector2Array()
var bind_points := {}
var bone_names := {}
var paint_size := Vector2.ZERO

func build(rest: Dictionary, ids: Dictionary) -> ArrayMesh:
 bind_points=rest
 paint_size=Vector2(Image.load_from_file(ProjectSettings.globalize_path("res://assets/character-paint-v1.png")).get_size())
 for name in ids: bone_names[ids[name]]=name
 var base := super.build(rest,ids)
 var arrays := base.surface_get_arrays(0)
 arrays[Mesh.ARRAY_TEX_UV]=front_uv
 arrays[Mesh.ARRAY_TEX_UV2]=back_uv
 arrays[Mesh.ARRAY_COLOR]=colors
 var result := ArrayMesh.new()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return result

func polygonize() -> void:
 # Refine the bind surface only. The accepted animation targets, bone lengths
 # and weight construction remain the same continuous-body implementation.
 shapes=shapes.filter(func(shape: Dictionary): return shape.color not in ["hair","ribbon"])
 var head := int(bone_names.find_key("head"))
 ellipse(Vector3(0,1.375,-.028),Vector3(.153,.122,.145),head,"hair")
 ellipse(Vector3(.028,1.465,-.037),Vector3(.091,.044,.094),head,"hair")
 hair_lock([Vector3(.072,1.448,.065),Vector3(.012,1.411,.118),Vector3(-.044,1.357,.13),Vector3(-.073,1.302,.105)],[.04,.037,.027,.006],head)
 hair_lock([Vector3(.083,1.44,.033),Vector3(.132,1.35,.066),Vector3(.138,1.267,.054),Vector3(.112,1.226,.07)],[.04,.039,.026,.006],head)
 hair_lock([Vector3(-.085,1.415,.018),Vector3(-.141,1.326,.036),Vector3(-.139,1.224,.054),Vector3(-.098,1.191,.042)],[.045,.04,.023,.006],head)
 hair_lock([Vector3(.088,1.437,-.10),Vector3(.157,1.386,-.17),Vector3(.185,1.301,-.225),Vector3(.16,1.204,-.231),Vector3(.115,1.146,-.198)],[.052,.07,.073,.051,.006],head)
 hair_lock([Vector3(.148,1.376,-.184),Vector3(.213,1.288,-.249),Vector3(.206,1.205,-.258),Vector3(.172,1.176,-.232)],[.043,.041,.024,.006],head)
 ellipse(Vector3(.087,1.43,-.165),Vector3(.063,.032,.028),head,"ribbon")
 ellipse(Vector3(.181,1.423,-.162),Vector3(.054,.033,.028),head,"ribbon")
 super.polygonize()

func hair_lock(points: Array, radii: Array, bone: int) -> void:
 for i in range(points.size()-1):
  shapes.append({"kind":"taper","a":points[i],"b":points[i+1],"radius_a":radii[i],"radius_b":radii[i+1],"bone":bone,"color":"hair"})

func shape_distance(p: Vector3, shape: Dictionary) -> float:
 if shape.kind=="taper": return taper_distance(p,shape)
 return super.shape_distance(p,shape)

func taper_distance(p: Vector3, shape: Dictionary) -> float:
 var ab: Vector3 = shape.b-shape.a
 var t := clampf((p-shape.a).dot(ab)/ab.length_squared(),0,1)
 return (p-shape.a-ab*t).length()-lerpf(shape.radius_a,shape.radius_b,t)

func emit_vertex(p: Vector3) -> void:
 super.emit_vertex(p)
 var bone: String = bone_names[bones[bones.size()-4]]
 var front := paint_point(p,bone,false)
 var rear := paint_point(p,bone,true)
 front_uv.append(front/paint_size)
 back_uv.append(rear/paint_size)
 var color := colors[colors.size()-1]
 if bone.ends_with("shoulder") or bone.ends_with("elbow") or bone.ends_with("wrist") or (absf(p.x)>.15 and p.y>1.025 and p.y<1.15):
  # Reserve zero red as a bare-arm material tag. The shader interpolates this
  # tag, but the underlying body skin still has exactly the same bone weights.
  color.r=0
 var head_weight := 0.0
 for i in range(4):
  if bone_names[bones[bones.size()-4+i]]=="head": head_weight+=weights[weights.size()-4+i]
 # Restore the compact character's larger illustrated head without changing
 # the gait or rescaling a body part from frame to frame. This is bind geometry.
 vertices[vertices.size()-1]=bind_points.head+(p-bind_points.head)*(1+.40*head_weight)+Vector3(0,.032*head_weight,0)
 # This blend is captured in rest space, never thresholded from an animated
 # normal; moving the arm cannot suddenly switch front/back paint.
 color.a=smoothstep(-.35,.35,normals[normals.size()-1].z)
 colors[colors.size()-1]=color

func paint_point(p: Vector3, bone: String, rear: bool) -> Vector2:
 var sign_x := -1.0 if bone.begins_with("left") else 1.0
 var center := 1100.0 if rear else 459.0
 var mirror := -1.0 if rear else 1.0
 var pixel := Vector2(center+mirror*p.x*640,body_y(p.y))
 if bone in ["head","neck"]:
  # Cover the entire illustrated head, not just the face enlarged over the
  # cranium. The old projection put forehead paint on the crown and eyes on
  # the side locks, making the stable head look like a distorted decal.
  pixel=Vector2(center+mirror*p.x*690,head_y(p.y,rear))
  var label := head_material(p)
  # Material islands have their own static chart. A planar face projection
  # cannot also describe a ribbon/side lock protruding in Z: it sampled hair
  # on one bow and dragged facial paint around the side of the skull.
  if label=="ribbon":
   pixel=Vector2(583+clampf((p.x-.11)*180,-10,10),107-(p.y-1.43)*250)
  elif label=="hair":
   if p.z<-.145 and p.x>.07:
    pixel=Vector2(clampf(620+(p.x-.17)*180,605,639),clampf(230-(p.y-1.27)*390,185,315))
   else:
    pixel=Vector2(clampf(1110+p.x*310+p.z*150,1065,1155),clampf(180-(p.y-1.3)*600,73,270))
 elif bone.ends_with("shoulder") or bone.ends_with("elbow") or bone.ends_with("wrist"):
  var side := "left" if sign_x<0 else "right"
  var shoulder: Vector3 = bind_points[side+"_shoulder"]
  var elbow: Vector3 = bind_points[side+"_elbow"]
  var wrist: Vector3 = bind_points[side+"_wrist"]
  var a := shoulder if bone.ends_with("shoulder") else elbow
  var b := elbow if bone.ends_with("shoulder") else wrist
  var t := clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1.16 if bone.ends_with("wrist") else 1)
  var pa := Vector2(center+mirror*sign_x*102,340) if bone.ends_with("shoulder") else Vector2(center+mirror*sign_x*151,471)
  var pb := Vector2(center+mirror*sign_x*151,471) if bone.ends_with("shoulder") else Vector2(center+mirror*sign_x*220,601)
  var axis := Vector2((b-a).x,-(b-a).y).normalized()
  var across := Vector2(p.x-a.x,-(p.y-a.y)).dot(Vector2(-axis.y,axis.x))
  var paint_axis := (pb-pa).normalized()
  pixel=pa.lerp(pb,t)+Vector2(-paint_axis.y,paint_axis.x)*across*650*mirror
 elif bone.ends_with("hip") or bone.ends_with("knee") or bone.ends_with("ankle") or bone.ends_with("toe"):
  var leg_x := sign_x*lerpf(68,122,clampf((.66-p.y)/.54,0,1))
  var around := p.x-sign_x*.105
  pixel.x=center+mirror*(leg_x+around*760)
  pixel.y=body_y(p.y)
  if bone.ends_with("ankle") or bone.ends_with("toe") or p.y<.177:
   pixel.y=clampf(boot_y(p.y)+smoothstep(.02,.105,p.z)*28,834,949)
 return pixel

func head_material(p: Vector3) -> String:
 var distance := INF
 var label := "head"
 for shape in shapes:
  var next := shape_distance(p,shape)
  if next<distance:
   distance=next
   label=shape.color
 if label=="head" and (p.z<-.043 or p.y>1.425): return "hair"
 return label

func boot_y(y: float) -> float:
 # The sole and cuff are separate landmarks from the leg's generic Y chart.
 # Preserve the same ground geometry; this only corrects where leather lands.
 var keys := [Vector2(0,947),Vector2(.04,920),Vector2(.08,885),Vector2(.145,860),Vector2(.20,834)]
 for i in range(keys.size()-1):
  if y<=keys[i+1].x: return lerpf(keys[i].y,keys[i+1].y,inverse_lerp(keys[i].x,keys[i+1].x,y))
 return keys[-1].y

func head_y(y: float, rear: bool) -> float:
 var keys := [Vector2(1.116,310),Vector2(1.23,275),Vector2(1.32,211),Vector2(1.425,106),Vector2(1.50,50)]
 if rear: return 205-(y-1.3)*770
 for i in range(keys.size()-1):
  if y<=keys[i+1].x: return lerpf(keys[i].y,keys[i+1].y,inverse_lerp(keys[i].x,keys[i+1].x,y))
 return keys[-1].y

func body_y(y: float) -> float:
 var keys := [Vector2(0,947),Vector2(.12,835),Vector2(.40,703),Vector2(.64,600),Vector2(.80,479),Vector2(1.025,387),Vector2(1.12,321),Vector2(1.2,292)]
 for i in range(keys.size()-1):
  if y<=keys[i+1].x: return lerpf(keys[i].y,keys[i+1].y,inverse_lerp(keys[i].x,keys[i+1].x,y))
 return keys[-1].y
