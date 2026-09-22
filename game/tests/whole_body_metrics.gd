extends RefCounted

# Read-only source measurements for offline animation QA. Never alters pixels.
static func inspect(image: Image) -> Dictionary:
 var head := Vector2.ZERO
 var eyes := Vector2.ZERO
 var face := Vector3.ZERO
 var waist := Vector2.ZERO
 var counts := [0,0,0,0]
 var top := image.get_height()
 var bottom := 0
 for y in range(image.get_height()):
  for x in range(image.get_width()):
   var color := image.get_pixel(x,y)
   if color.a<.9 or minf(color.r,color.b)-color.g>.23: continue
   var point := Vector2(x,y)
   top=mini(top,y)
   bottom=maxi(bottom,y)
   if y<490:
    head+=point; counts[0]+=1
   if Rect2(468,354,138,92).has_point(point) and color.r<.43 and color.g<.22 and color.b<.2:
    eyes+=point; counts[1]+=1
   if Rect2(480,410,140,55).has_point(point) and color.r>.88 and color.g>.62 and color.b>.3:
    face+=Vector3(color.r,color.g,color.b); counts[2]+=1
   if Rect2(520,615,105,65).has_point(point) and color.r>.7 and color.g>.40 and color.g<.78 and color.b<.43:
    waist+=point; counts[3]+=1
 return {"size":image.get_size(),"top":top,"bottom":bottom,"head":head/maxi(1,counts[0]),
  "eyes":eyes/maxi(1,counts[1]),"face":face/maxi(1,counts[2])*255,"waist":waist/maxi(1,counts[3]),
  "clear":image.get_pixel(0,0).a<.01,"samples":counts}

static func skin(c: Color) -> bool:
 return c.a>.9 and c.r>.82 and c.g>.48 and c.b>.25 and c.r-c.g>.08 and c.g-c.b>.1

static func near_hand(image: Image) -> Vector2:
 var seed := Vector2i(680,520)
 if not skin(image.get_pixelv(seed)): return Vector2.INF
 var seen := PackedByteArray()
 seen.resize(image.get_width()*image.get_height())
 var queue: Array[Vector2i] = [seed]
 seen[seed.x+seed.y*image.get_width()]=1
 var at := 0
 var low := 0
 while at<queue.size():
  var p: Vector2i = queue[at]
  at+=1
  low=maxi(low,p.y)
  for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var q: Vector2i = p+step
   if q.x<0 or q.y<480 or q.x>=image.get_width() or q.y>=820: continue
   var id := q.x+q.y*image.get_width()
   if seen[id] or not skin(image.get_pixelv(q)): continue
   seen[id]=1
   queue.append(q)
 var total := Vector2.ZERO
 var count := 0
 for p in queue:
  if p.y>=low-28:
   total+=Vector2(p); count+=1
 return total/maxi(1,count)
