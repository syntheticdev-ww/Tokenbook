extends RefCounted

# Each pose is one complete authored person. Arm swing belongs to that drawing,
# so shoulder anatomy, limb volume and lighting cannot drift independently.
const Art = preload("res://pixel_art.gd")
const ATLAS := "gardener-v13/front"
const ORIGINAL_ATLAS := "gardener-v10/front"
# Selected as a complete cyclic sequence against face/head/torso continuity.
# Keep the original closing half where new art altered palette or head volume;
# retain complete drawings, never splice faces or limbs together.
const ORIGINAL_DRAWINGS := [2,11,12,13,14,15,17]
const GESTURE_REPAIR_ATLAS := "gardener-v13/front-gesture-repair"
const GESTURE_REPAIR_DRAWINGS := [8]
const REPAIRED_ATLAS := "gardener-v11/front-continuity"
const REPAIRED_DRAWING := 16
const GRID := Vector2(6,3)
const SOURCE_SCALE := 0.161
const PHASES := [0.0,1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,10.5,11.0,12.0,12.5,13.0,14.0,15.0]
# Pixel coordinates local to each atlas cell. Its row margins differ, so cell
# centers are not valid registration points.
const BELTS := [
	Vector2(137,169), Vector2(137.3333,168), Vector2(137.6667,168),
	Vector2(136.5,167), Vector2(138.3333,166.5), Vector2(137.6667,167),
	Vector2(138.5,166.6667), Vector2(137.3333,167.1667), Vector2(137.6667,167.1667),
	Vector2(135.5,167.1667), Vector2(135.8333,166.6667), Vector2(135.1667,166.6667),
	Vector2(137.5,147.3333), Vector2(137.3333,146.8333), Vector2(138.1667,146.8333),
	Vector2(135,147.3333), Vector2(136.8333,147.3333), Vector2(136.6667,148.3333),
]
# Measured visible eye center relative to belt, in world units. Calibration
# data for this atlas, not motion keyframes or runtime image detection.
const EYE_OFFSETS := [
	Vector2(-0.294134,-9.065538), Vector2(-0.328562,-8.940428), Vector2(-0.395909,-8.836525),
	Vector2(-0.230995,-8.7675), Vector2(-0.439318,-9.07194), Vector2(-0.44685,-9.098143),
	Vector2(-0.339889,-9.099489), Vector2(-0.359147,-9.063479), Vector2(-0.459025,-9.086228),
	Vector2(-0.262146,-9.150176), Vector2(-0.292174,-9.144211), Vector2(-0.250966,-9.151752),
	Vector2(-0.31494,-9.075311), Vector2(-0.379788,-8.947879), Vector2(-0.475112,-9.023889),
	Vector2(-0.243564,-9.090306), Vector2(-0.347942,-8.977043), Vector2(-0.435196,-9.021029),
]
const REFERENCE_EYE := Vector2(-0.35,-9.05)
# Measured head/hair silhouette centers AFTER the eye/waist fit, in world units.
# A light horizontal constraint avoids the hair mass kicking sideways at a cut.
# Keep vertical weight transfer unchanged; do not pin or deform any body part.
const HEAD_CENTERS_X := [
	1.689419,1.646592,1.412448,1.601380,1.709605,1.631412,
	1.549048,1.707090,1.568986,1.833815,1.661828,1.762591,
	1.650987,1.673775,1.479711,1.889893,1.567659,1.506771,
]
const REFERENCE_HEAD_X := 1.65
const HEAD_FIT_WEIGHT := 0.25
const BACK_ATLAS := "gardener-v13/back"
const SETTLE_ATLAS := "gardener-v13/settle"
const BACK_SCALE := 0.119
const BACK_DRAWINGS := [0,1,2,3,6,7,8,9,10,11,12,13,14,15]
const BACK_PHASES := [0.0,1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,13.0,15.0]
const BACK_HEADS := [
	Vector2(170.44296,88.06096),Vector2(170.11166,87.40760),Vector2(169.69043,87.28556),Vector2(169.46330,87.22407),
	Vector2(170.62133,85.01301),Vector2(170.16316,85.02689),Vector2(169.71088,84.95321),Vector2(169.40145,85.09697),
	Vector2(170.62673,81.31415),Vector2(170.18426,81.33061),Vector2(169.75318,81.22106),Vector2(169.48337,81.23620),
	Vector2(168.74108,74.90075),Vector2(168.41593,74.90987),Vector2(168.77361,74.89529),Vector2(168.28178,74.96074),
]
# Measured torso and head landmarks for the complete v13 drawings. Equal
# translation weights keep errors from collecting in one anatomical region.
const BACK_SHIRTS := [
	Vector2(159.80844,153.20996),Vector2(161.17497,151.98917),Vector2(161.10190,152.63389),Vector2(161.97267,151.86105),
	Vector2(160.49895,148.80126),Vector2(160.31878,148.65721),Vector2(160.42579,148.49133),Vector2(160.48519,148.16970),
	Vector2(160.77588,144.79829),Vector2(159.50945,145.89965),Vector2(160.41617,144.40309),Vector2(160.37124,144.22984),
	Vector2(158.03851,137.88390),Vector2(158.69975,137.66054),Vector2(158.24763,137.89573),Vector2(157.78637,137.51848),
]
const BACK_SHIRT_FROM_HEAD := Vector2(-9.3,63.8)
const SETTLE_HEAD_X := [169.97583,159.23068,150.69170,149.31456,170.29272,159.90354,151.25146,149.05817,170.03005,159.83502,151.75682,148.60643,169.41021,160.19156,150.56055,149.16608]
const SETTLE_BOTTOM := [295.0,295.0,295.0,295.0,283.5,291.5,292.5,291.5,281.0,281.0,289.0,286.0,275.5,276.5,275.5,275.5]

static func warm_cache() -> void:
	Art.texture(ATLAS)
	Art.texture(ORIGINAL_ATLAS)
	Art.texture(GESTURE_REPAIR_ATLAS)
	Art.texture(REPAIRED_ATLAS)
	for name in [BACK_ATLAS,SETTLE_ATLAS]: Art.texture(name)

static func drawing_at(phase: float) -> int:
	var wrapped := fposmod(phase,16.0)
	var nearest := INF
	var selected := 0
	for i in range(PHASES.size()):
		var distance := absf(wrapped-PHASES[i])
		distance = minf(distance,16.0-distance)
		if distance < nearest:
			nearest = distance
			selected = i
	return selected

static func frame_at(phase: float, back := false) -> Dictionary:
	if back: return back_frame_at(phase)
	var drawing := drawing_at(phase)
	var texture := REPAIRED_ATLAS if drawing == REPAIRED_DRAWING else ATLAS
	if drawing in ORIGINAL_DRAWINGS: texture = ORIGINAL_ATLAS
	if drawing in GESTURE_REPAIR_DRAWINGS: texture = GESTURE_REPAIR_ATLAS
	var cell := Art.texture(texture).get_size()/GRID
	var angle := fposmod(phase,16.0) * TAU / 16.0
	# Keep weight transfer continuous while drawing registration changes.
	var pelvis := Vector2(0.25+0.13*sin(angle),-16.20+0.28*cos(angle*2.0))
	# Fit BOTH face and waist. Belt-only leaves all proportion error in the head;
	# eye-only moves it to the waist. Equal weights balance their displacement.
	# Only translate the complete drawing: never resize, rotate or warp body parts.
	var anchor: Vector2 = BELTS[drawing]+(EYE_OFFSETS[drawing]-REFERENCE_EYE)*0.5/SOURCE_SCALE
	anchor.x += (HEAD_CENTERS_X[drawing]-REFERENCE_HEAD_X)*HEAD_FIT_WEIGHT/SOURCE_SCALE
	return {"texture":texture, "source":Rect2(Vector2(drawing%6,int(drawing/6))*cell,cell),
		"destination":Rect2(pelvis-anchor*SOURCE_SCALE,cell*SOURCE_SCALE),
		"spout":Vector2.ZERO, "drawing":drawing, "anchor":anchor, "belt":BELTS[drawing]}

static func back_frame_at(phase: float) -> Dictionary:
	var wrapped := fposmod(phase,16.0)
	var nearest := INF
	var drawing := 0
	for i in range(BACK_PHASES.size()):
		var difference := absf(wrapped-BACK_PHASES[i])
		difference = minf(difference,16.0-difference)
		if difference < nearest:
			nearest = difference
			drawing = BACK_DRAWINGS[i]
	var cell := Art.texture(BACK_ATLAS).get_size()/4.0
	var anchor: Vector2 = BACK_HEADS[drawing]-Vector2(1.2,-9.9)/BACK_SCALE
	anchor += (BACK_SHIRTS[drawing]-BACK_HEADS[drawing]-BACK_SHIRT_FROM_HEAD)*0.5
	var angle := wrapped*TAU/16
	var pelvis := Vector2(.25+.13*sin(angle),-16.2+.28*cos(angle*2))
	return {"texture":BACK_ATLAS,"source":Rect2(Vector2(drawing%4,int(drawing/4))*cell,cell),
		"destination":Rect2(pelvis-anchor*BACK_SCALE,cell*BACK_SCALE),"anchor":anchor,"belt":anchor,
		"drawing":drawing,"spout":Vector2.ZERO}

static func settle_frame(progress: float, back: bool) -> Dictionary:
	# Reject the generated extra knee lift/crouch. Only use the low-foot
	# closing poses; one fixed scale per direction keeps the skull from swelling.
	var drawing := (13 if back else 5)+clampi(int(progress*3),0,2)
	var source_scale := .123 if back else .1213
	var cell := Art.texture(SETTLE_ATLAS).get_size()/4
	var anchor := Vector2(SETTLE_HEAD_X[drawing]-1.2/source_scale,SETTLE_BOTTOM[drawing])
	return {"texture":SETTLE_ATLAS,"source":Rect2(Vector2(drawing%4,int(drawing/4))*cell,cell),
		"destination":Rect2(-anchor*source_scale,cell*source_scale),"drawing":drawing,"spout":Vector2.ZERO,
		"settling":true}
