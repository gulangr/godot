extends Node2D

var is_moving: bool = false
var path_queue: Array[Vector2i] = []
var current_coords: Vector2i = Vector2i.ZERO # 记录小人当前所在的网格位置

func _ready():
	z_index = 100 
	scale = Vector2(2, 2) # 随时在这里微调大小
	print(">>> 摸金校尉已就位！")

# ==========================================
# 接收大管家发来的路径，开始移动
# ==========================================
func walk_path(path: Array[Vector2i], tile_size: int):
	path_queue = path
	# 如果小人现在没在动，就开始执行第一步
	if not is_moving:
		_step(tile_size)

# ==========================================
# 内部步法逻辑：走完一格，接着走下一格
# ==========================================
func _step(tile_size: int):
	# 如果路径走完了，停下来
	if path_queue.is_empty():
		is_moving = false
		return
		
	is_moving = true
	var next_coords = path_queue.pop_front()
	current_coords = next_coords # 更新当前位置
	
	var target_position = Vector2(next_coords) * float(tile_size)
	var tween = create_tween()
	# 使用 TRANS_LINEAR (线性)，让一格格走起来像匀速步行，不会卡顿
	tween.tween_property(self, "position", target_position, 0.2).set_trans(Tween.TRANS_LINEAR)
	
	# 这步走完后，神气相连，立刻触发下一步！
	tween.finished.connect(func(): _step(tile_size))
