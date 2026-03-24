@tool 
extends Resource
class_name RoomData

@export_flags("北 (North):1", "东 (East):2", "南 (South):4", "西 (West):8") var doors_bitmask: int = 0

@export var room_name: String = "未命名墓室"

@export_enum("普通", "宝藏", "起点", "塌方", "深渊", "特色建筑") var room_type: String = "普通"

@export var weight: int = 10

func has_door(direction_bit: int) -> bool:
	return (doors_bitmask & direction_bit) != 0
