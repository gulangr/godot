extends Resource
class_name ModuleData

@export var module_name: String = "大型建筑模块"
@export var module_scene: PackedScene # 这里用来拖入你刚才保存的 Module_主殿.tscn
@export var weight: int = 10 # 影响它被抽中的几率
