extends Node3D

const Gait = preload("gait.gd")
const Builder = preload("character_mesh.gd")
const PARENTS := {"pelvis":"","chest":"pelvis","neck":"chest","head":"neck",
 "left_hip":"pelvis","left_knee":"left_hip","left_ankle":"left_knee","left_toe":"left_ankle",
 "right_hip":"pelvis","right_knee":"right_hip","right_ankle":"right_knee","right_toe":"right_ankle",
 "left_shoulder":"chest","left_elbow":"left_shoulder","left_wrist":"left_elbow",
 "right_shoulder":"chest","right_elbow":"right_shoulder","right_wrist":"right_elbow"}
const ENDS := {"left_hip":"left_knee","left_knee":"left_ankle","right_hip":"right_knee","right_knee":"right_ankle",
 "left_shoulder":"left_elbow","left_elbow":"left_wrist","right_shoulder":"right_elbow","right_elbow":"right_wrist"}
static var shared_mesh: ArrayMesh
static var shared_material: ShaderMaterial
var skeleton := Skeleton3D.new()
var body := MeshInstance3D.new()
var ids := {}
var rest: Dictionary = bind_joints()

static func bind_joints() -> Dictionary:
 var joints: Dictionary = Gait.standing().joints.duplicate(true)
 # A-pose for skin construction: hands/forearms must not merge into the hips.
 # Walk targets are unchanged; the skeleton rotates this rest pose into them.
 for side in ["left","right"]:
  var sign_x := -1.0 if side=="left" else 1.0
  joints[side+"_elbow"]=joints[side+"_shoulder"]+Vector3(sign_x*.13,-sqrt(Gait.UPPER_ARM*Gait.UPPER_ARM-.13*.13),0)
  joints[side+"_wrist"]=joints[side+"_elbow"]+Vector3(sign_x*.085,-sqrt(Gait.FOREARM*Gait.FOREARM-.085*.085-.01*.01),.01)
 return joints

func _init() -> void:
 skeleton.name="Skeleton"
 add_child(skeleton)
 for key in PARENTS:
  var id := skeleton.add_bone(key)
  ids[key]=id
  var parent: String = PARENTS[key]
  if not parent.is_empty(): skeleton.set_bone_parent(id,ids[parent])
  var offset: Vector3 = rest[key]-(rest[parent] if not parent.is_empty() else Vector3.ZERO)
  skeleton.set_bone_rest(id,Transform3D(Basis.IDENTITY,offset))
 skeleton.reset_bone_poses()
 if shared_mesh==null:
  shared_mesh=Builder.new().build(rest,ids)
  shared_material=ShaderMaterial.new()
  var shader := Shader.new()
  shader.code="""shader_type spatial;
render_mode unshaded;
void fragment() { ALBEDO = COLOR.rgb; }
"""
  shared_material.shader=shader
 body.mesh=shared_mesh
 body.material_override=shared_material
 body.skin=skeleton.create_skin_from_rest_transforms()
 body.skeleton=NodePath("../Skeleton")
 body.custom_aabb=AABB(Vector3(-.6,-.1,-.6),Vector3(1.2,1.9,1.2))
 add_child(body)
 var face := BoneAttachment3D.new()
 face.bone_name="head"
 skeleton.add_child(face)
 for side in [-1,1]:
  detail(face,Vector3(side*.050,.028,.125),Vector3(.019,.028,.009),Color("f4e7bc"))
  detail(face,Vector3(side*.051,.029,.133),Vector3(.009,.017,.005),Color("543824"))
  detail(face,Vector3(side*.048,.039,.137),Vector3(.003,.004,.002),Color("fff7d7"))
  detail(face,Vector3(side*.050,.066,.121),Vector3(.022,.005,.006),HAIR_COLOR())
 detail(face,Vector3(0,-.006,.14),Vector3(.014,.018,.013),Color("e5a672"))
 detail(face,Vector3(0,-.052,.126),Vector3(.018,.004,.005),Color("a9694d"))
 var shirt := BoneAttachment3D.new()
 shirt.bone_name="chest"
 skeleton.add_child(shirt)
 for y in [-.06,0,.055]: detail(shirt,Vector3(0,y,.098),Vector3(.006,.006,.006),Color("e4cfa0"))
 apply_pose(Gait.standing())

static func HAIR_COLOR() -> Color: return Color("724525")

func detail(parent: Node3D, at: Vector3, radius: Vector3, color: Color) -> void:
 var node := MeshInstance3D.new()
 var mesh := SphereMesh.new()
 mesh.radius=1
 mesh.height=2
 mesh.radial_segments=12
 mesh.rings=6
 node.mesh=mesh
 var material := StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color=color
 node.material_override=material
 node.position=at
 node.scale=radius
 parent.add_child(node)

func apply_pose(pose: Dictionary) -> void:
 var globals := {}
 for key in PARENTS:
  var basis := Basis.IDENTITY
  if key in ENDS:
   var end: String = ENDS[key]
   basis=Basis(Quaternion((rest[end]-rest[key]).normalized(),(pose.joints[end]-pose.joints[key]).normalized()))
  elif key=="pelvis": basis=Basis(Vector3.UP,pose.hip_yaw)
  elif key=="chest": basis=Basis(Vector3.UP,pose.chest_yaw)
  elif key.ends_with("ankle") or key.ends_with("toe"):
   basis=Basis(Vector3.RIGHT,pose.feet[0 if key.begins_with("left") else 1].pitch)
  elif key.ends_with("wrist"):
   basis=globals[key.replace("wrist","elbow")].basis
  var target := Transform3D(basis,pose.joints[key])
  var parent: String = PARENTS[key]
  skeleton.set_bone_pose(ids[key],globals[parent].affine_inverse()*target if not parent.is_empty() else target)
  globals[key]=target
 skeleton.force_update_all_bone_transforms()
