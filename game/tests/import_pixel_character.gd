extends SceneTree

# Offline import of newly authored pixel-art sheets. Nearest sampling only
# resolves the enlarged source grid; it does not recolor legacy art.
const BASE := "res://assets/art/gardener-v25/"
const PET := "res://assets/art/desktop-pet-v2/"
const CANVAS := 112
const BODY_HEIGHT := 88
const TOP := 11
const HEAD_CENTER := 61
const FOOT := Vector2(58,99)
var original: Dictionary
var master_height := 1.0
var report := []
var frames := []
func _initialize()->void:
 original=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v24/character.json"))
 var reference:=Image.load_from_file(ProjectSettings.globalize_path(original.transition[0].file))
 master_height=solid_bounds(reference).size.y
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE+"frames"))
 for group in range(4):
  var source:=read_clean(BASE+"source/sheet-%d.png"%group)
  var bands:=row_bands(source)
  assert(bands.size()==(4 if group<3 else 2),"Unexpected authored sheet rows")
  var rows: Array=original.walk.slice(group*16,group*16+16) if group<3 else original.departure
  for i in rows.size():
   var yband:Vector2i=bands[i/4]
   var x0:=roundi(i%4*source.get_width()/4.0)
   var x1:=roundi((i%4+1)*source.get_width()/4.0)
   var cell:=source.get_region(Rect2i(x0,yband.x,x1-x0,yband.y-yband.x))
   var old:=Image.load_from_file(ProjectSettings.globalize_path(rows[i].file))
   var bounds:=solid_bounds(old)
   var target_height:=roundi(bounds.size.y/master_height*BODY_HEIGHT)
   var native:=native_cell(cell,target_height)
   var name:="walk-%02d"% (group*16+i) if group<3 else ("idle" if i==0 else "depart-%02d"%i)
   var file:=BASE+"frames/"+name+".png"
   assert(native.save_png(file)==OK)
   var entry:Dictionary=rows[i].duplicate()
   entry.file=file;entry.anchor=[FOOT.x,FOOT.y];entry.sha256=FileAccess.get_sha256(file)
   entry.source_file=rows[i].file
   entry.erase("replaces_file")
   frames.append({"group":group,"index":i,"entry":entry})
   report.append({"file":file,"sheet":group,"cell":i,"source_bounds":[cell.get_used_rect().position.x,cell.get_used_rect().position.y,cell.get_used_rect().size.x,cell.get_used_rect().size.y],"native_height":target_height})
 # The new authored face is the identity master for this fixed-facing clip.
 # Preserve it byte-for-byte across cels instead of letting generation drift
 # make eyes, hair clusters or facial proportions flicker while walking.
 var identity:=Image.load_from_file(ProjectSettings.globalize_path(BASE+"frames/idle.png"))
 for row in frames:
  var frame:=Image.load_from_file(ProjectSettings.globalize_path(row.entry.file))
  frame.blit_rect(identity,Rect2i(0,0,CANVAS,43),Vector2i.ZERO)
  frame.blit_rect(identity,Rect2i(0,43,41,7),Vector2i(0,43))
  frame.blit_rect(identity,Rect2i(66,43,CANVAS-66,7),Vector2i(66,43))
  assert(frame.save_png(row.entry.file)==OK)
  row.entry.sha256=FileAccess.get_sha256(row.entry.file)
  row.entry.anchor=[FOOT.x,FOOT.y]
 var walk:=[];var departure:=[]
 for row in frames:
  if row.group<3:walk.append(row.entry)
  else:departure.append(row.entry)
 # Exact shared endpoint, avoiding a style or registration swap at take-off.
 departure[-1]=walk[7].duplicate()
 departure[-1].erase("phase")
 var transition:=[departure[0],departure[2],departure[4],departure[6],departure[7]]
 var manifest:=original.duplicate(true)
 manifest.version=2;manifest.canvas=[CANVAS,CANVAS];manifest.scale=33.0/977.0*master_height/BODY_HEIGHT
 manifest.sampling="nearest";manifest.erase("presentation")
 manifest.walk=walk;manifest.departure=departure;manifest.transition=transition
 write_json(BASE+"character.json",manifest)
 import_pet()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/pixel-v25"))
 write_json("res://../artifacts/pixel-v25/import.json",report)
 print("Imported 48 complete pixel walk cels, 8 departure slots, and 12 pet poses")
 quit()

func read_clean(path:String)->Image:
 var img:=Image.load_from_file(ProjectSettings.globalize_path(path));assert(img!=null)
 img.convert(Image.FORMAT_RGBA8)
 for y in img.get_height():
  for x in img.get_width():
   var c:=img.get_pixel(x,y)
   if c.a<.95 or (minf(c.r,c.b)-c.g>.23 and c.r>.35 and c.b>.35):img.set_pixel(x,y,Color.TRANSPARENT)
   else:img.set_pixel(x,y,Color(c.r,c.g,c.b,1))
 return img

func solid_bounds(img:Image)->Rect2i:
 var low:=Vector2i(img.get_width(),img.get_height());var high:=Vector2i.ZERO
 for y in img.get_height():
  for x in img.get_width():
   var c:=img.get_pixel(x,y)
   if c.a>.9 and minf(c.r,c.b)-c.g<.23:
    low=low.min(Vector2i(x,y));high=high.max(Vector2i(x+1,y+1))
 assert(high.x>low.x and high.y>low.y)
 return Rect2i(low,high-low)

func upper_center(img:Image,bounds:Rect2i)->float:
 var left:=img.get_width();var right:=0
 for y in range(bounds.position.y,bounds.position.y+roundi(bounds.size.y*.34)):
  for x in range(bounds.position.x,bounds.end.x):
   if img.get_pixel(x,y).a>.9:left=mini(left,x);right=maxi(right,x)
 return (left+right)*.5

func row_bands(img:Image)->Array[Vector2i]:
 var bands:Array[Vector2i]=[];var start:=-1;var last:=-1
 for y in img.get_height():
  var count:=0
  for x in img.get_width():
   if img.get_pixel(x,y).a>.9:count+=1
  if count>16:
   if start<0:start=y
   last=y
  elif start>=0 and y-last>12:
   bands.append(Vector2i(maxi(0,start-2),mini(img.get_height(),last+3)));start=-1
 if start>=0:bands.append(Vector2i(maxi(0,start-2),mini(img.get_height(),last+3)))
 return bands

func native_cell(cell:Image,height:int)->Image:
 var bounds:=cell.get_used_rect()
 var core:=cell.get_region(bounds)
 var center:=upper_center(cell,bounds)-bounds.position.x
 var ratio:=float(height)/core.get_height()
 var x:=roundi(HEAD_CENTER-center*ratio)
 core.resize(roundi(core.get_width()*ratio),height,Image.INTERPOLATE_NEAREST)
 var out:=Image.create(CANVAS,CANVAS,false,Image.FORMAT_RGBA8)
 assert(x>=0 and x+core.get_width()<=CANVAS and height+TOP<=CANVAS,"Sprite needs complete padding")
 out.blit_rect(core,Rect2i(Vector2i.ZERO,core.get_size()),Vector2i(x,TOP))
 return out

func import_pet()->void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PET+"frames"))
 var sheet:=read_clean(PET+"source.png")
 var bands:=row_bands(sheet);assert(bands.size()==3)
 var data:=[]
 var standing_height:=0.0
 for i in range(12):
  var band:Vector2i=bands[i/4]
  var x0:=roundi(i%4*sheet.get_width()/4.0);var x1:=roundi((i%4+1)*sheet.get_width()/4.0)
  var cell:=sheet.get_region(Rect2i(x0,band.x,x1-x0,band.y-band.x))
  var bounds:=cell.get_used_rect()
  if i==0:standing_height=bounds.size.y
  var height:=roundi(bounds.size.y/standing_height*BODY_HEIGHT)
  var native:=native_cell(cell,height)
  # Keep feet on the same ground baseline while the whole body crouches.
  var aligned:=Image.create(CANVAS,CANVAS,false,Image.FORMAT_RGBA8)
  aligned.blit_rect(native,Rect2i(0,TOP,CANVAS,height),Vector2i(0,int(FOOT.y)-height))
  if i==0:aligned=Image.load_from_file(ProjectSettings.globalize_path(BASE+"frames/idle.png"))
  var file:="frames/%02d.png"%i
  assert(aligned.save_png(PET+file)==OK)
  var mask:=BitMap.new();mask.create_from_image_alpha(aligned,.5)
  var polygons:=mask.opaque_to_polygons(Rect2i(0,0,CANVAS,CANVAS),.5)
  var polygon:=PackedVector2Array();var largest:=0.0
  for p in polygons:
   var area:=0.0
   for j in p.size():area+=p[j].cross(p[(j+1)%p.size()])
   if absf(area)>largest:largest=absf(area);polygon=p
  var points:=[]
  for point in polygon:points.append([point.x,point.y])
  data.append({"file":file,"anchor":[FOOT.x,FOOT.y],"polygon":points})
 write_json(PET+"animation.json",{"version":2,"scale":179.2/BODY_HEIGHT,"sampling":"nearest","frames":data})

func write_json(path:String,data:Variant)->void:
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "))
