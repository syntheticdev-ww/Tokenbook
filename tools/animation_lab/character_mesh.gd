extends RefCounted

# Code-native, deliberately simplified blockout, not replacement pixel artwork.
# Smooth union + one skin closes shoulders/elbows/knees before animation.
const SKIN := Color("efb781")
const SHIRT := Color("428e83")
const SHORTS := Color("c7ad79")
const HAIR := Color("724525")
const BOOT := Color("785333")
const TETS := [[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
const EDGES := [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]]
var shapes: Array[Dictionary] = []
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var bones := PackedInt32Array()
var weights := PackedFloat32Array()

func build(rest: Dictionary, ids: Dictionary) -> ArrayMesh:
 ellipse(Vector3(0,1.01,0),Vector3(.177,.145,.102),ids.chest,"shirt")
 ellipse(Vector3(0,.865,0),Vector3(.13,.16,.083),ids.chest,"shirt")
 ellipse(Vector3(0,.745,0),Vector3(.148,.105,.092),ids.pelvis,"shorts")
 capsule(rest.neck-Vector3(0,.05,0),rest.head-Vector3(0,.07,0),.047,ids.neck,"skin")
 ellipse(rest.head,Vector3(.148,.184,.133),ids.head,"head")
 for side in ["left","right"]:
  capsule(rest[side+"_shoulder"],rest[side+"_elbow"],.048,ids[side+"_shoulder"],"skin")
  capsule(rest[side+"_elbow"],rest[side+"_wrist"],.037,ids[side+"_elbow"],"skin")
  var hand_tip: Vector3 = rest[side+"_wrist"]+(rest[side+"_wrist"]-rest[side+"_elbow"]).normalized()*.035
  capsule(rest[side+"_wrist"],hand_tip,.034,ids[side+"_wrist"],"skin")
  capsule(rest[side+"_hip"],rest[side+"_knee"],.066,ids[side+"_hip"],"thigh")
  capsule(rest[side+"_knee"],rest[side+"_ankle"],.042,ids[side+"_knee"],"shin")
  capsule(rest[side+"_ankle"],rest[side+"_ankle"]+Vector3(0,.085,0),.054,ids[side+"_ankle"],"boot")
  shapes.append({"kind":"box","a":rest[side+"_ankle"]+Vector3(0,0,.0275),"r":Vector3(.061,.06,.0775),"bone":ids[side+"_ankle"],"color":"boot"})
 ellipse(Vector3(-.10,1.405,.035),Vector3(.064,.094,.103),ids.head,"hair")
 ellipse(Vector3(-.033,1.444,.077),Vector3(.07,.062,.07),ids.head,"hair")
 ellipse(Vector3(.119,1.38,.007),Vector3(.047,.103,.09),ids.head,"hair")
 capsule(Vector3(.075,1.419,-.104),Vector3(.159,1.265,-.232),.073,ids.head,"hair")
 ellipse(Vector3(.171,1.205,-.223),Vector3(.072,.116,.066),ids.head,"hair")
 ellipse(Vector3(.087,1.43,-.165),Vector3(.063,.036,.035),ids.head,"ribbon")
 ellipse(Vector3(.181,1.423,-.162),Vector3(.057,.037,.034),ids.head,"ribbon")
 polygonize()
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 arrays[Mesh.ARRAY_COLOR] = colors
 arrays[Mesh.ARRAY_BONES] = bones
 arrays[Mesh.ARRAY_WEIGHTS] = weights
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

func ellipse(at: Vector3, radius: Vector3, bone: int, color: String) -> void:
 shapes.append({"kind":"ellipse","a":at,"r":radius,"bone":bone,"color":color})

func capsule(a: Vector3, b: Vector3, radius: float, bone: int, color: String) -> void:
 shapes.append({"kind":"capsule","a":a,"b":b,"radius":radius,"bone":bone,"color":color})

func shape_distance(p: Vector3, shape: Dictionary) -> float:
 if shape.kind == "capsule":
  var ab: Vector3 = shape.b-shape.a
  var t := clampf((p-shape.a).dot(ab)/ab.length_squared(),0,1)
  return (p-shape.a-ab*t).length()-shape.radius
 if shape.kind == "box":
  var q: Vector3 = (p-shape.a).abs()-shape.r+Vector3.ONE*.012
  return q.max(Vector3.ZERO).length()+minf(maxf(q.x,maxf(q.y,q.z)),0)-.012
 var r: Vector3 = shape.r
 return (((p-shape.a)/r).length()-1)*minf(r.x,minf(r.y,r.z))

func distance_at(p: Vector3) -> float:
 var result := 100.0
 for shape in shapes:
  var d := shape_distance(p,shape)
  var h := clampf(.5+.5*(d-result)/.022,0,1)
  result = lerpf(d,result,h)-.022*h*(1-h)
 return result

func attributes(p: Vector3) -> Dictionary:
 var d := 100.0
 var influence := {}
 var label := "skin"
 for shape in shapes:
  var next := shape_distance(p,shape)
  var h := clampf(.5+.5*(next-d)/.022,0,1)
  if h>=1: continue
  if h<.5: label=shape.color
  for id in influence.keys(): influence[id]*=h
  influence[shape.bone]=influence.get(shape.bone,0.0)+(1-h)
  d=lerpf(next,d,h)-.022*h*(1-h)
 var epsilon := .001
 var normal := Vector3(
  distance_at(p+Vector3(epsilon,0,0))-distance_at(p-Vector3(epsilon,0,0)),
  distance_at(p+Vector3(0,epsilon,0))-distance_at(p-Vector3(0,epsilon,0)),
  distance_at(p+Vector3(0,0,epsilon))-distance_at(p-Vector3(0,0,epsilon))).normalized()
 # Bake this simple palette shade once. Re-thresholding moving normals every
 # rendered frame would make skin/shirt colour patches pop during an arm arc.
 var light := normal.dot(Vector3(-.45,.85,.75).normalized())
 var shade := .76+.24*smoothstep(-.3,.8,light)
 return {"weights":influence,"normal":normal,"color":color_at(p,label)*Color(shade,shade,shade,1)}

func color_at(p: Vector3, label: String) -> Color:
 match label:
  "head": return HAIR if p.y>1.425 or p.z<-.043 else SKIN
  "hair": return HAIR
  "ribbon": return Color("54bcb1")
  "shirt": return Color("79603d") if p.y<.81 else SHIRT
  "shorts": return Color("79603d") if p.y>.795 else SHORTS
  "thigh": return SHORTS if p.y>.64 else SKIN
  "shin": return BOOT if p.y<.177 else (Color("ece2b8") if p.y<.204 else SKIN)
  "boot": return BOOT
 return SKIN

func polygonize() -> void:
 var origin := Vector3(-.52,-.04,-.36)
 var step := .026
 var size := Vector3i(41,61,25)
 var field := PackedFloat32Array()
 field.resize(size.x*size.y*size.z)
 for y in range(size.y):
  for z in range(size.z):
   for x in range(size.x):
    field[x+size.x*(z+size.z*y)] = distance_at(origin+Vector3(x,y,z)*step)
 var offsets := [Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
 for y in range(size.y-1):
  for z in range(size.z-1):
   for x in range(size.x-1):
    var points: Array[Vector3] = []
    var values: Array[float] = []
    var inside := 0
    for offset in offsets:
     var c: Vector3i = Vector3i(x,y,z)+offset
     var value := field[c.x+size.x*(c.z+size.z*c.y)]
     points.append(origin+Vector3(c)*step)
     values.append(value)
     if value<0: inside+=1
    if inside==0 or inside==8: continue
    for tet in TETS:
     var crossing: Array[Vector3] = []
     for edge in EDGES:
      var a: int = tet[edge[0]]
      var b: int = tet[edge[1]]
      if (values[a]<0)==(values[b]<0): continue
      crossing.append(points[a].lerp(points[b],values[a]/(values[a]-values[b])))
     if crossing.size()<3: continue
     var center := Vector3.ZERO
     for p in crossing: center+=p
     center/=crossing.size()
     var normal: Vector3 = attributes(center).normal
     var u := (crossing[0]-center).normalized()
     var v := normal.cross(u)
     crossing.sort_custom(func(a: Vector3,b: Vector3): return atan2((a-center).dot(v),(a-center).dot(u))<atan2((b-center).dot(v),(b-center).dot(u)))
     for j in range(1,crossing.size()-1):
      # Godot uses clockwise winding; normals still point out of the surface.
      emit_vertex(crossing[0])
      emit_vertex(crossing[j+1])
      emit_vertex(crossing[j])

func emit_vertex(p: Vector3) -> void:
 var data := attributes(p)
 vertices.append(p)
 normals.append(data.normal)
 colors.append(data.color)
 var influence: Dictionary = data.weights
 var keys := influence.keys()
 keys.sort_custom(func(a,b): return influence[a]>influence[b])
 var total := 0.0
 for i in range(mini(4,keys.size())): total+=influence[keys[i]]
 for i in range(4):
  bones.append(keys[i] if i<keys.size() else 0)
  weights.append(influence[keys[i]]/total if i<keys.size() else 0.0)
