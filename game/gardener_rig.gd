extends RefCounted

# REJECTED EXPERIMENT: no runtime caller. Fixed-torso/independent-limb motion
# was rejected in visual review; do not re-enable as the production renderer.
# Original pixel cutouts, articulated in projected screen space. No image
# cross-fades, whole-character stretching, new 3D runtime, or save dependencies.
const SHEET := "gardener-rig-v1"
const BODY_SCALE := 0.0615
const LEG_SCALE := 0.048
const BOOT_HEIGHT := 3.65
# Pixel-measured joints and complete boot silhouettes in the generated atlas.
# Each view registers the same sole CENTER, so changing view cannot move a plant.
const LEGS := [
	{"x": 1300, "y": 122, "width": 140, "hip": 1395, "knee": 1390, "ankle": 1389, "boot": Rect2(1307, 293, 111, 86)},
	{"x": 1698, "y": 122, "width": 140, "hip": 1767, "knee": 1777, "ankle": 1777, "boot": Rect2(1708, 293, 103, 89)},
	{"x": 1285, "y": 490, "width": 155, "hip": 1363, "knee": 1372, "ankle": 1372, "boot": Rect2(1292, 661, 116, 78)},
	{"x": 1698, "y": 490, "width": 140, "hip": 1767, "knee": 1776, "ankle": 1776, "boot": Rect2(1701, 661, 115, 78)},
]

static func parts(gait: Dictionary, right: bool, back: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var body: Vector2 = gait.body
	var row := 1 if back else 0
	var hip := [Vector2(0.8, -11.6), Vector2(-2.0, -11.2)] if back else [Vector2(-2.0, -11.6), Vector2(0.8, -11.2)]
	var shoulders := [Vector2(2.3, -19.9), Vector2(-2.6, -19.4)] if back else [Vector2(-2.5, -20.0), Vector2(3.0, -19.6)]
	var leg_parts: Array[Array] = []
	var arm_parts: Array[Dictionary] = []
	for leg in range(2):
		var foot: Dictionary = gait.feet[1 - leg if right else leg]
		var sole: Vector2 = foot.position * Vector2(-1 if right else 1, 1)
		var registration: Dictionary = LEGS[row * 2 + leg]
		var boot_source: Rect2 = registration.boot
		var ankle := sole + Vector2((registration.ankle - boot_source.get_center().x) * LEG_SCALE, -BOOT_HEIGHT + 0.1)
		var pelvis: Vector2 = hip[leg] + body
		# Bend forward during passing; these are projected (foreshortened) bones.
		# Never move the ankle to make an unreachable knee fit: preserve contact.
		var knee := pelvis.lerp(ankle, 0.50) + Vector2(-0.20 - foot.lift * 0.45, -foot.lift * 0.12)
		leg_parts.append(_leg(row, leg, pelvis, knee, ankle, sole, foot))
		var phase: float = foot.phase
		var swing: float = sin((phase - 0.12) * TAU) * 0.16 * (1.0 - float(gait.get("settle", 0.0)))
		# Opposite arm/leg rhythm, modest amplitude for a relaxed farm stroll.
		arm_parts.append(_arm(row, leg, shoulders[leg] + body, swing))
	result.append(arm_parts[0])
	result.append_array(leg_parts[0])
	result.append_array(leg_parts[1])
	var source := Rect2(98, 418, 272, 355) if back else Rect2(98, 40, 272, 352)
	var bottom := 769.0 if back else 389.0
	var destination := Rect2(Vector2((98.0 - 210.0) * BODY_SCALE, (source.position.y - bottom) * BODY_SCALE - 10.8) + body, source.size * BODY_SCALE)
	result.append(_rect("body", source, destination))
	result.append(arm_parts[1])
	return result

static func _leg(row: int, leg: int, hip: Vector2, knee: Vector2, ankle: Vector2, sole: Vector2, foot: Dictionary) -> Array[Dictionary]:
	var registration: Dictionary = LEGS[row * 2 + leg]
	var origin_x: float = registration.x
	var origin_y: float = registration.y
	var source_width: float = registration.width
	var width := source_width * LEG_SCALE
	var hip_left := Vector2((origin_x - registration.hip) * LEG_SCALE, 0)
	var knee_left := Vector2((origin_x - registration.knee) * LEG_SCALE, 0)
	var ankle_left := Vector2((origin_x - registration.ankle) * LEG_SCALE, 0)
	var across := Vector2(width, 0)
	var overlap := Vector2(0, 0.1)
	var result: Array[Dictionary] = []
	result.append(_quad("thigh_%d" % leg, Rect2(origin_x, origin_y, source_width, 107), [hip + hip_left, hip + hip_left + across, knee + knee_left + across + overlap, knee + knee_left + overlap]))
	result.append(_quad("shin_%d" % leg, Rect2(origin_x, origin_y + 105, source_width, 68), [knee + knee_left, knee + knee_left + across, ankle + ankle_left + across + overlap, ankle + ankle_left + overlap]))
	# Boots retain their shape and a flat supporting sole. Swing uses a small
	# toe roll only in the air; no rotational drift while in contact.
	var boot_source: Rect2 = registration.boot
	var boot_width := boot_source.size.x * LEG_SCALE
	var boot := _rect("boot_%d" % leg, boot_source, Rect2(sole + Vector2(-boot_width * 0.5, -BOOT_HEIGHT), Vector2(boot_width, BOOT_HEIGHT)))
	if not foot.contact:
		var angle := sin(foot.swing * TAU) * 0.12
		for i in range(boot.vertices.size()):
			boot.vertices[i] = sole + (boot.vertices[i] - sole).rotated(angle)
	result.append(boot)
	return result

static func _arm(row: int, leg: int, shoulder: Vector2, angle: float) -> Dictionary:
	var source: Rect2
	var pivot: Vector2
	if row == 0:
		source = Rect2(575 if leg == 0 else 956, 120, 97, 238)
		pivot = Vector2(608 if leg == 0 else 989, 148)
	else:
		source = Rect2(574 if leg == 0 else 928, 485, 108, 236)
		pivot = Vector2(608 if leg == 0 else 998, 518)
	var result := _rect("arm_%d" % leg, source, Rect2((source.position - pivot) * 0.042 + shoulder, source.size * 0.042))
	for i in range(result.vertices.size()):
		result.vertices[i] = shoulder + (result.vertices[i] - shoulder).rotated(angle)
	return result

static func _rect(label: String, source: Rect2, destination: Rect2) -> Dictionary:
	return _quad(label, source, [destination.position, destination.position + Vector2(destination.size.x, 0), destination.end, destination.position + Vector2(0, destination.size.y)])

static func _quad(label: String, source: Rect2, vertices: Array) -> Dictionary:
	return {"label": label, "texture": SHEET, "source": source, "vertices": PackedVector2Array(vertices)}
