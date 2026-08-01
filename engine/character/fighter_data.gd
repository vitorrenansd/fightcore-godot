class_name FighterData
extends Resource

@export var fighter_id: StringName
@export var display_name: String
@export var portrait: Texture2D
@export var sprite_frames: SpriteFrames

@export var stats: FighterStats
@export var moves: Array[AttackData] = []
@export var commands: Array[CommandData] = []
