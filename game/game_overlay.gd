extends RefCounted

class SceneScrim extends ColorRect:
 func _has_point(point: Vector2) -> bool:
  # Keep the scene's top controls and navigation usable while a menu is open.
  return point.y>=58 and point.y<size.y-64

# The game's HUD is independent from the transparent companion view. Farm
# rules, save ownership and the in-flight character live in main, not here.
static func build(s: Control, dimensions: Vector2i) -> void:
 for child in s.get_children():
  if child is Control:
   s.remove_child(child)
   child.queue_free()
 for key in ["status","detail","action_button","crop_choice","hint","hint_background","resources","music_button","character_stop","character_reset","body","farm","pet"]:
  s.set(key,null)
 s.page_values.clear()
 if not s.expanded:
  var pet := preload("res://desktop_pet.gd").new()
  pet.clock=s.pet_clock
  pet.size=Vector2(dimensions)
  pet.pressed.connect(s.header_input)
  pet.silhouette_changed.connect(s.update_pet_hit_region)
  s.pet=pet
  s.add_child(pet)
  return
 var width := float(dimensions.x)
 var height := float(dimensions.y)
 var farm := preload("res://farm_view.gd").new()
 farm.refined_animation=true
 farm.ambient_enabled=true
 farm.landscape=true
 # Frame the cottage, route and all eight plots, rather than the full painting.
 farm.view_aspect=Vector2(1.0,.94)
 farm.render_scale=minf(width/392.0,height/(276.0*farm.view_aspect.y))
 farm.view_center=Vector2(224,173)
 farm.motion=s.farm_motion
 farm.character=s.character
 farm.externally_driven=true
 farm.pixel_ratio=s.dpi
 farm.selected_plot=s.selected_plot
 s.farm=farm
 s.place(farm,Rect2(Vector2.ZERO,Vector2(dimensions)))
 farm.plot_selected.connect(s.select_plot)
 farm.house_selected.connect(func(): s.show_page("home"))
 farm.water_selected.connect(func(): s.issue({"type":"water"}))
 farm.cat_petted.connect(func(): s.toast("小猫眯起眼睛，陪你晒了一会儿太阳。"))
 # HUD surfaces float within the picture. There is no external card/frame.
 var drag := Control.new()
 drag.mouse_default_cursor_shape=Control.CURSOR_MOVE
 drag.gui_input.connect(s.header_input)
 s.place(drag,Rect2(0,0,width-136,52))
 chip(s,Rect2(16,14,136,38),Color(.15,.23,.17,.80))
 var title: Label=s.label("词元之书",Rect2(29,20,122,26),18,"fff6d9")
 title.add_theme_color_override("font_shadow_color",Color(.1,.15,.1,.4))
 chip(s,Rect2(164,17,324,32),Color(.15,.23,.17,.70))
 s.resources=s.label("",Rect2(178,22,304,24),12,"fff6d9")
 s.music_button=small_button(s,"♪",Rect2(width-126,16,32,32),s.toggle_music,"音乐")
 small_button(s,"−",Rect2(width-86,16,32,32),func():s.set_expanded(false),"收起为桌宠")
 small_button(s,"×",Rect2(width-46,16,32,32),func():s.set_expanded(false),"关闭农场，回到桌宠")
 # A consistent navigation row sits over the lower meadow, not below it.
 var keys := ["farm","bag","book","home"]
 var titles := ["农场","背包","主书","小屋"]
 for i in range(4):
  var key: String=keys[i]
  var nav: Button=s.button(titles[i],Rect2(20+i*84,height-52,76,34),func():s.show_page(key),s.page==key)
  nav.tooltip_text="返回小院" if key=="farm" else titles[i]
 s.body=Control.new()
 s.body.mouse_filter=Control.MOUSE_FILTER_IGNORE
 s.place(s.body,Rect2(Vector2.ZERO,Vector2(dimensions)))
 page(s)
 # Transient messages are part of the scene and never consume a toolbar row.
 s.hint_background=Panel.new()
 s.hint_background.add_theme_stylebox_override("panel",surface(Color(.13,.21,.15,.91),8))
 s.hint_background.mouse_filter=Control.MOUSE_FILTER_IGNORE
 s.place(s.hint_background,Rect2(width*.5-212,64,424,46))
 s.hint=s.label("",Rect2(width*.5-199,70,398,35),12,"fff6d9")
 s.hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

static func page(s: Control) -> void:
 if not is_instance_valid(s.body): return
 s.clear_children(s.body)
 s.page_values.clear()
 for key in ["action_button","crop_choice","status","detail","character_stop","character_reset"]:s.set(key,null)
 var dimensions: Vector2=Vector2(s.Layout.EXPANDED)
 s.body.position=Vector2.ZERO
 s.body.size=dimensions
 if is_instance_valid(s.farm): s.farm.set_process(s.page=="farm")
 if s.page=="farm":
  var x: float=dimensions.x-306
  var y: float=dimensions.y-98
  chip(s,Rect2(x,y,286,78),Color(.16,.24,.17,.86),s.body)
  s.status=s.label("",Rect2(x+14,y+5,258,24),14,"fff6d9",s.body)
  s.detail=s.label("",Rect2(x+14,y+36,258,32),11,"dfdfbc",s.body)
  s.detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  s.detail.hide()
  if s.character_test:
   s.action_button=s.button("走到第一块田",Rect2(x+14,y+34,136,34),s.begin_character_walk,true,s.body)
   s.character_stop=s.button("停下",Rect2(x+158,y+34,50,34),func():s.character.request_stop();s.update_character_controls(),false,s.body)
   s.character_reset=s.button("重试",Rect2(x+216,y+34,56,34),func():s.character.reset_home();s.update_character_controls(),false,s.body)
  else:
   chip(s,Rect2(20,dimensions.y-86,336,27),Color(.15,.23,.17,.76),s.body)
   s.detail.position=Vector2(30,dimensions.y-82)
   s.detail.size=Vector2(316,22)
   s.detail.show()
   s.body.move_child(s.detail,-1)
   s.action_button=s.button("播种",Rect2(x+14,y+34,154,32),s.perform_action,true,s.body)
   var choice := OptionButton.new()
   choice.add_theme_font_override("font",s.font)
   choice.add_theme_font_size_override("font_size",11)
   choice.add_theme_stylebox_override("normal",s.box("eae3c9",6))
   choice.add_theme_color_override("font_color",Color("405139"))
   for text in ["初春 · 3分钟","萝卜 · 1小时","小麦 · 4小时","土豆 · 8小时"]:choice.add_item(text)
   choice.select(["welcome","radish","wheat","potato"].find(s.selected_crop))
   choice.item_selected.connect(func(index: int):s.selected_crop=["welcome","radish","wheat","potato"][index];s.refresh())
   s.crop_choice=choice
   s.place(choice,Rect2(x+176,y+34,96,32),s.body)
  return
 # Existing gameplay panels keep their actions and validation, inside a
 # scene overlay. The farm remains visible behind them.
 var shade := SceneScrim.new()
 shade.color=Color(.06,.13,.09,.42)
 shade.gui_input.connect(func(event: InputEvent):
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:s.show_page("farm"))
 s.place(shade,Rect2(Vector2.ZERO,dimensions),s.body)
 var panel := Panel.new()
 panel.add_theme_stylebox_override("panel",surface(Color("f5efda"),12))
 s.place(panel,Rect2(dimensions.x*.5-210,82,420,438),s.body)
 var content := Control.new()
 content.mouse_filter=Control.MOUSE_FILTER_IGNORE
 s.place(content,Rect2(dimensions.x*.5-210,90,420,420),s.body)
 var overlay: Control=s.body
 s.body=content
 if not s.store.ready:
  s.label("存档暂不可用",Rect2(28,22,330,25),19,"8b5c43",content)
  var error: Label=s.label(s.store.last_error,Rect2(28,62,360,220),14,"8b5c43",content)
  error.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 elif s.page=="bag":s.build_bag()
 elif s.page=="book":s.build_book()
 else:s.build_home()
 s.body=overlay
 small_button(s,"×",Rect2(dimensions.x*.5+164,94,30,30),func():s.show_page("farm"),"回到农场",overlay)

static func surface(color: Color,radius: int) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color=color
 style.set_corner_radius_all(radius)
 return style

static func chip(s: Control,rect: Rect2,color: Color,parent: Node=null) -> void:
 var panel := Panel.new()
 panel.add_theme_stylebox_override("panel",surface(color,8))
 panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 s.place(panel,rect,parent)

static func small_button(s: Control,text: String,rect: Rect2,callback: Callable,tip: String,parent: Node=null) -> Button:
 var node: Button=s.button(text,rect,callback,false,parent)
 node.add_theme_stylebox_override("normal",surface(Color(.15,.23,.17,.83),8))
 node.add_theme_stylebox_override("hover",surface(Color(.28,.39,.25,.96),8))
 node.add_theme_color_override("font_color",Color("fff6d9"))
 node.add_theme_color_override("font_hover_color",Color("ffffff"))
 node.add_theme_stylebox_override("disabled",surface(Color(.15,.23,.17,.65),8))
 node.add_theme_color_override("font_disabled_color",Color("aab49c"))
 node.tooltip_text=tip
 return node
