extends SceneTree

# Inspect the actual game material at 4x integer magnification. No asset edits.
func _initialize() -> void: render.call_deferred()

func render() -> void:
 root.size=Vector2i(640,448)
 root.content_scale_size=root.size
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.transparent_bg=false
 root.title="领口内阴影微调"
 RenderingServer.set_default_clear_color(Color("ece6d9"))
 add_label("调整前",Vector2(22,8))
 add_label("调整后",Vector2(342,8))
 add_panel("res://assets/art/gardener-v56/idle.png",Vector2(10,36))
 add_panel("res://assets/art/gardener-v57/idle.png",Vector2(330,36))
 for frame in range(3):
  await process_frame
  RenderingServer.force_draw(false)
 var output:=OS.get_environment("TOKENBOOK_CAPTURE_DIR")
 if not output.is_absolute_path():
  printerr("An absolute capture directory is required")
  quit(2);return
 root.get_texture().get_image().save_png(output.path_join("neckline-comparison.png"))
 quit()

func add_panel(source_path: String,origin: Vector2) -> void:
 var panel:=Control.new()
 panel.position=origin
 panel.size=Vector2(300,404)
 panel.clip_contents=true
 root.add_child(panel)
 var card:=Control.new()
 card.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var material:=ShaderMaterial.new()
 material.shader=load("res://character_material.gdshader")
 material.set_shader_parameter("grid_size",Vector2(160,188))
 material.set_shader_parameter("sample_offset",Vector2(.25,.25))
 material.set_shader_parameter("refined_face_sampling",false)
 material.set_shader_parameter("display_sampling_step",1.0)
 card.material=material
 var source:=Image.load_from_file(ProjectSettings.globalize_path(source_path))
 var texture:=ImageTexture.create_from_image(source)
 card.draw.connect(func():card.draw_texture_rect(texture,Rect2(-172,-90,640,752),false))
 panel.add_child(card)

func add_label(text: String,origin: Vector2) -> void:
 var label:=Label.new()
 label.text=text
 label.position=origin
 label.add_theme_color_override("font_color",Color("57443c"))
 label.add_theme_font_size_override("font_size",18)
 label.add_theme_font_override("font",preload("res://assets/fonts/NotoSansSC.ttf"))
 root.add_child(label)
