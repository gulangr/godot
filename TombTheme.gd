extends Resource
class_name TombTheme

@export var theme_name: String = "秦皇陵主题"

# ==========================================
# 随机贴图几率池
# ==========================================
@export_category("普通墓道贴图池")
# 你可以往这个数组里拖入无数张图片
@export var floor_textures: Array[Texture2D] = []
# 对应上面图片的几率（权重），例如填 [70, 20, 10]
@export var texture_weights: Array[int] = [] 

# ==========================================
# 抽卡算法：根据填写的几率，随机吐出一张贴图
# ==========================================
func get_random_texture() -> Texture2D:
	if floor_textures.is_empty(): 
		return null
		
	# 计算总几率池
	var total_weight = 0
	for w in texture_weights:
		total_weight += w
		
	if total_weight <= 0: 
		return floor_textures[0]
		
	# 掷骰子
	var rand_val = randi() % total_weight
	var current_sum = 0
	
	# 根据几率区间抓取对应图片
	for i in range(floor_textures.size()):
		current_sum += texture_weights[i]
		if rand_val < current_sum:
			return floor_textures[i]
			
	return floor_textures.back()
