extends "preview.gd"

const PaintedCharacter = preload("painted_character.gd")

func create_character() -> Node3D:
 return PaintedCharacter.new()

func preview_camera_positions() -> Array[Vector3]:
 # sin(elevation)=.3 with this azimuth projects forward to the farm's 2:1
 # diagonal. Store the measured screen stride; the 2D player does not guess.
 return [Vector3(3,2.604,5),Vector3(6,2.65,0),Vector3(-3,2.604,-5)]

func _initialize() -> void:
 super._initialize()
 root.title="Tokenbook · 像素材质步态候选（未接入游戏）"
