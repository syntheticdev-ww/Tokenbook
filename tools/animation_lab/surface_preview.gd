extends "preview.gd"

const Surface = preload("sprite_surface.gd")

func create_character() -> Node3D: return Surface.new()

func preview_camera_positions() -> Array[Vector3]:
 return [Vector3(3,2.604,5),Vector3(-3,2.604,-5)]

func preview_view_names() -> Array[String]: return ["front","back"]

func sprite_size() -> Vector2i: return Vector2i(256,320)

func _initialize() -> void:
 super._initialize()
 root.title="Tokenbook · 连续像素画网格候选（未接入游戏）"
