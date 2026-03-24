extends Node2D
class_name MapManager

# ==========================================
# 核心数据变量
# ==========================================
var map_data: Dictionary = {} 
var explored_bounds: Rect2i = Rect2i(0, 0, 1, 1)

#  我们的“牌堆”，里面存放各种 RoomData 资源
@export var room_pool: Array[RoomData] 
#  记录当前哪些坐标是“虚空暗门”（可以点击探索的）
# 【新增】：不仅要存数据，还要存屏幕上的视觉模型，方便我们随时指挥它们
var map_views: Dictionary = {}
var valid_ghost_coords: Array[Vector2i] = []
# 【新增：古墓规模预算系统】
var tomb_max_budget: int = 0  # 本次下斗最多能挖多少格
var current_tomb_type: String = "兵马俑" # 假设当前副本类型
@export var cave_in_data: RoomData # 原来的塌方口袋，保持不变
@export var abyss_data: RoomData   # 【新增】：专门装“深渊裂缝”的口袋
@export_category("大型建筑模块")
@export var module_pool: Array[ModuleData] = [] # 你的大殿档案袋全拖到这里面！
@export var module_spawn_chance: float = 0.25 # 25% 的几率尝试触发大型建筑
# --- 新增的视觉变量（这些会在编辑器右侧检查器里显示） ---
@export var room_scene: PackedScene # 用来装载你的 RoomView.tscn
@export var tile_size: int = 512     # 格子大小（64像素的格子+6像素间距）

# 【新增：摸金校尉专属变量】
@export var player_scene: PackedScene # 用来装小人的预制体
var player_instance: Node2D           # 记录当前在场上的小人实例

# ==========================================
# 常量字典（方向与门的位掩码）
# ==========================================
const DIR_OFFSETS = {
	Vector2i.UP: 1,      # 北
	Vector2i.RIGHT: 2,   # 东
	Vector2i.DOWN: 4,    # 南
	Vector2i.LEFT: 8     # 西
}

const OPPOSITE_DOORS = {
	1: 4,
	2: 8,
	4: 1,
	8: 2
}

# ==========================================
# 初始化与测试
# ==========================================
# ==========================================
# 初始化与测试
# ==========================================
func _ready():
	print("摸金校尉已下斗，罗盘初始化...")
	
	# 根据不同的墓穴类型，计算这次的预算
	if current_tomb_type == "兵马俑":
		tomb_max_budget = calculate_tomb_budget(5, 100)
	elif current_tomb_type == "普通坟墓":
		tomb_max_budget = calculate_tomb_budget(5, 20)
		
	var start_data = load("res://ROOM/起点.tres")
	if start_data:
		add_room(Vector2i(0, 0), start_data)
		# ==========================================
		# 【新增】：召唤摸金校尉，站在起点！
		# ==========================================
		# ==========================================
		# 【新增】：召唤摸金校尉，站在起点！
		# ==========================================
		if player_scene:
			player_instance = player_scene.instantiate()
			add_child(player_instance)
			player_instance.position = Vector2.ZERO 
			player_instance.current_coords = Vector2i.ZERO # 【新增】：告诉小人他现在在 (0,0)
	else:
		print("找不到 res://ROOM/起点.tres 资源文件，请检查路径和文件名！")

# ==========================================
# 墓穴规模生成：偏向最大值的随机算法
# ==========================================
func calculate_tomb_budget(min_tiles: int, max_tiles: int) -> int:
	# randf() 生成 0.0 ~ 1.0。用 sqrt() 开平方根，会让结果极大概率偏向 1.0
	var skewed_random = sqrt(randf()) 
	
	# lerp 是线性插值，用刚才偏向 1.0 的小数，在 min 和 max 之间取值
	var result = lerp(float(min_tiles), float(max_tiles), skewed_random)
	
	# 四舍五入转成整数
	var final_budget = roundi(result)
	
	# 【应要求打印测试输出】
	print(">>> [预算结算] 基础区间: ", min_tiles, "-", max_tiles)
	print(">>> [预算结算] 随机偏移系数(偏向1.0): ", skewed_random)
	print(">>> [预算结算] 最终钦定格子数: ", final_budget)
	
	return final_budget

# ==========================================
# 核心逻辑：尝试放置房间并生成画面
# ==========================================
func add_room(coords: Vector2i, room: RoomData) -> bool:
	if map_data.has(coords):
		print("该坐标已被探索过！")
		return false
		
	if not can_place_room(coords, room):
		print("风水不对：路口与相邻墓室不匹配！")
		return false
		
	# 1. 放置成功，记录纯数据
	map_data[coords] = room
	
	# ===============================================
	# 【全新逻辑：地质变动引发的基因突变】
	# ===============================================
	# 情况A：我是一块 0掩码死石头，我要强行封死周围四个邻居朝向我的门
	if room.doors_bitmask == 0:
		for dir_vec in DIR_OFFSETS.keys():
			var neighbor_coords = coords + dir_vec
			if map_data.has(neighbor_coords):
				var neighbor_door_bit = OPPOSITE_DOORS[DIR_OFFSETS[dir_vec]]
				seal_door_and_mutate(neighbor_coords, neighbor_door_bit)
				
	# 情况B：我是一块正常墓室，但我恰好被放在了死石头旁边，我自己的门也要被封死
	else:
		for dir_vec in DIR_OFFSETS.keys():
			var neighbor_coords = coords + dir_vec
			# 如果我的邻居是死石头
			if map_data.has(neighbor_coords) and map_data[neighbor_coords].doors_bitmask == 0:
				var my_door_bit = DIR_OFFSETS[dir_vec]
				seal_door_and_mutate(coords, my_door_bit) # 砍掉我自己的门
	# ===============================================
	
	if map_data.size() == 1:
		explored_bounds = Rect2i(coords, Vector2i(1, 1))
	else:
		explored_bounds = explored_bounds.expand(coords)
		
	# 2. 【新增的视觉部分】实例化预制体并放到屏幕上
	# 2. 【新增的视觉部分】实例化预制体并放到屏幕上
	if room_scene:
		var tile_instance = room_scene.instantiate()
		tile_instance.position = coords * tile_size 
		add_child(tile_instance)
		tile_instance.setup(room)
		
		# 【重要！把生成的模型记录到字典里】
		map_views[coords] = tile_instance
		
		# 【重要！刷新我自己的墙，并通知周围四个邻居刷新它们的墙】
		update_visual_walls(coords)
		for dir_vec in DIR_OFFSETS.keys():
			update_visual_walls(coords + dir_vec)
			
	else:
		print("警告：你没有在右侧面板给 Room Scene 赋值！")
		
	print("成功在 ", coords, " 翻开: ", room.room_name)
	update_ghost_tiles()
	return true

# ==========================================
# 风水校验：检查路口是否对得上
# ==========================================
func can_place_room(coords: Vector2i, room: RoomData) -> bool:
	# 【核心修改 1】：如果是 0掩码死石头，它可以随便放在任何虚空处，不需要对齐门
	if room.doors_bitmask == 0: 
		return true

	for dir_vec in DIR_OFFSETS.keys():
		var neighbor_coords = coords + dir_vec
		
		if map_data.has(neighbor_coords):
			var neighbor_room = map_data[neighbor_coords]
			
			# 【核心修改 2】：如果邻居是 0掩码死石头，这面墙直接算作被堵死，允许放置
			if neighbor_room.doors_bitmask == 0:
				continue
				
			var my_door_bit = DIR_OFFSETS[dir_vec]
			var neighbor_door_bit = OPPOSITE_DOORS[my_door_bit]
			
			if room.has_door(my_door_bit) != neighbor_room.has_door(neighbor_door_bit):
				return false 
				
	return true

# ==========================================
# 视野扩张：计算下一步能翻开哪里
# ==========================================
# ==========================================
# 视野扩张：计算下一步能翻开哪里
# ==========================================
func update_ghost_tiles():
	valid_ghost_coords.clear() # 每次刷新前清空旧数据
	
	for coords in map_data.keys():
		var current_room = map_data[coords]
		for dir_vec in DIR_OFFSETS.keys():
			var check_coords = coords + dir_vec
			# 如果相邻格子没被探索，且当前房间有门通向那里
			if not map_data.has(check_coords) and current_room.has_door(DIR_OFFSETS[dir_vec]):
				if not valid_ghost_coords.has(check_coords):
					valid_ghost_coords.append(check_coords)
	
	print("当前可探墓的方位有：", valid_ghost_coords.size(), " 处：", valid_ghost_coords)
	
# ==========================================
# 玩家交互：鼠标点击洛阳铲下土
# ==========================================
# ==========================================
# 玩家交互：鼠标点击洛阳铲下土 & 摸金校尉移动
# ==========================================
# ==========================================
# 玩家交互：鼠标点击洛阳铲下土 & 摸金校尉移动
# ==========================================
# ==========================================
# 玩家交互：鼠标点击洛阳铲下土 & 摸金校尉移动
# ==========================================
# ==========================================
# 玩家交互：鼠标点击洛阳铲下土 & 摸金校尉移动
# ==========================================
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var grid_x = round(mouse_pos.x / tile_size)
		var grid_y = round(mouse_pos.y / tile_size)
		var clicked_coord = Vector2i(grid_x, grid_y)
		
		# ==================================
		# 【雷达打印】：这一步极其重要，用来看引擎到底在想什么！
		# ==================================
		print("---------------------------------")
		print(">>> 铲子落点坐标: ", clicked_coord)
		print(">>> 小人当前坐标: ", player_instance.current_coords)
		if map_data.has(clicked_coord):
			print(">>> 目标格子掩码: ", map_data[clicked_coord].doors_bitmask)
		# ==================================
		
		# 情况 1：点击的是“待探索的暗门”（开荒）
		if valid_ghost_coords.has(clicked_coord):
			
			# ==========================================
			# 【核心新增】：在发牌员造出深渊、封死墓道之前，
			# 提前记录下有哪些相邻的正常房间是“朝向这块未知区域开门”的！
			# ==========================================
			var valid_entry_points: Array[Vector2i] = []
			for dir_vec in DIR_OFFSETS.keys():
				var neighbor = clicked_coord + dir_vec
				# 必须是已探索过的、且不是灾害的正常格子
				if map_data.has(neighbor) and map_data[neighbor].doors_bitmask != 0:
					# 算一下从邻居看向这块砖，是哪个门
					var door_pointing_to_click = OPPOSITE_DOORS[DIR_OFFSETS[dir_vec]]
					if map_data[neighbor].has_door(door_pointing_to_click):
						valid_entry_points.append(neighbor) # 记在小本子上！
			
			
			draw_and_place_room(clicked_coord) # 呼叫发牌员造房间 (此时可能会发生灾害并封门)
			
			if map_data.has(clicked_coord):
				# 1.A 如果造出来的是正常通路 (非0掩码)，直接寻路走过去！
				if map_data[clicked_coord].doors_bitmask != 0:
					var path = find_path(player_instance.current_coords, clicked_coord)
					if path.size() > 0:
						player_instance.walk_path(path, tile_size)
						
				# 1.B 如果探明的是灾害 (深渊/塌方)，让小人移动到我们刚刚记录的“探路原点”去观察
				else:
					var best_path = []
					var found_valid_neighbor = false
					
					# 【核心修改】：现在不再找四周的所有格子了，只找记录在册的“原始通路”！
					for neighbor in valid_entry_points:
						# 如果小人正好站在这悬崖边上，就不需要再寻路了
						if player_instance.current_coords == neighbor:
							best_path = []
							found_valid_neighbor = true
							break
							
						# 寻找从目前位置前往这个悬崖边缘的路径
						var p = find_path(player_instance.current_coords, neighbor)
						if p.size() > 0:
							# 比较并记录最近的一个安全边缘
							if not found_valid_neighbor or p.size() < best_path.size():
								best_path = p
								found_valid_neighbor = true
								
					# 如果找到了可以站脚的原通路边缘，走过去！
					if found_valid_neighbor:
						if best_path.size() > 0:
							player_instance.walk_path(best_path, tile_size)
						print("前方危险！摸金校尉已移动到探路原点的悬崖边缘观察！")
					
		# 情况 2：点击的是“已经探索过的安全旧路” (走回头路)
		elif map_data.has(clicked_coord):
			# 只要不是灾害废墟，就尝试寻路
			if map_data[clicked_coord].doors_bitmask != 0:
				# 如果点的是自己脚下
				if player_instance.current_coords == clicked_coord:
					print("已经在这里了！")
					return
					
				var path = find_path(player_instance.current_coords, clicked_coord)
				if path.size() > 0:
					player_instance.walk_path(path, tile_size)
					print("摸金校尉正在沿着旧路移动...")
				else:
					print("此路不通：中间可能隔着墙或深渊！")
			else:
				print("那是死地，不可踏足！")
				
		else:
			print("这块地风水不通，铲子下不去！")

# ==========================================
# 抽牌逻辑：从牌堆里找合适的房间
# ==========================================
# ==========================================
# 抽牌逻辑：从牌堆里找合适的房间
# ==========================================
# ==========================================
# 抽牌逻辑：从牌堆里找合适的房间
# ==========================================
func draw_and_place_room(coords: Vector2i):
	# 1. 预算耗尽，强制用废墟封路（优先用深渊封路）
	if map_data.size() >= tomb_max_budget:
		print("预算耗尽 (已达", tomb_max_budget, "格)！前方无路可走！")
		if abyss_data: 
			add_room(coords, abyss_data) 
		elif cave_in_data:
			add_room(coords, cave_in_data)
		return

	# 危机干预：如果快没路了，强制保底（关闭意外灾害）
	var is_in_crisis = valid_ghost_coords.size() <= 2 and map_data.size() < tomb_max_budget - 3
	
	if not is_in_crisis:
		# 所有灾害的最大连通上限（预算的 15%，保底 3 格）
		var max_cluster_allowed = max(3, int(tomb_max_budget * 0.15))
		
		# ==========================================
		# 生态 A：塌方的独立蔓延逻辑
		# ==========================================
		if cave_in_data:
			var cave_in_chance = 0.05 # 凭空产生塌方的基础概率 5%
			var cave_in_neighbors = count_same_type_neighbors(coords, "塌方")
			
			if cave_in_neighbors > 0:
				cave_in_chance += cave_in_neighbors * 0.25 # 连击加成
				var cluster_size = get_cluster_size(coords, "塌方")
				if cluster_size >= max_cluster_allowed:
					cave_in_chance = 0.0 # 达到上限，阻断连击！
				else:
					print("--- 碎石松动：受周围塌方影响，连环塌方概率飙升至 ", cave_in_chance * 100, "%")
					
			if randf() < cave_in_chance:
				print("轰隆！发生塌方！")
				add_room(coords, cave_in_data)
				return 
				
		# ==========================================
		# 生态 B：深渊的独立蔓延逻辑 (只有没发生塌方时，才判定深渊)
		# ==========================================
		if abyss_data:
			var abyss_chance = 0.05 # 凭空产生深渊的基础概率 5%
			var abyss_neighbors = count_same_type_neighbors(coords, "深渊")
			
			if abyss_neighbors > 0:
				abyss_chance += abyss_neighbors * 0.25 # 连击加成
				var cluster_size = get_cluster_size(coords, "深渊")
				if cluster_size >= max_cluster_allowed:
					abyss_chance = 0.0 # 达到上限，阻断连击！
				else:
					print("--- 地脉断裂：受周围深渊影响，产生新深渊概率飙升至 ", abyss_chance * 100, "%")
					
			if randf() < abyss_chance:
				print("咔嚓！脚下裂开深渊！")
				add_room(coords, abyss_data)
				return
				
	# ==========================================
	# 【全新添加】：在抽普通单间之前，尝试把整个建筑群一把塞进去！
	# ==========================================
	if try_place_module(coords):
		return # 如果大模块成功落地，直接结束本次发牌！

	# ==========================================
	# 3. 正常抽牌逻辑 (风水推演防死锁 + 磁力诱导)
	# ==========================================
	var possible_rooms = []
	var room_weights = [] # 【新增】：用来存每个房间临时计算的动态权重
	
	# 诱导倍率：设定为 15 倍。倍率越高，向 A 开门的概率越大（轻松达到并超越 50%）
	var magnetic_factor = 3 

	for room in room_pool:
		if room == null: continue
		if can_place_room(coords, room):
			if map_data.size() < tomb_max_budget - 1:
				if will_cause_dead_end(coords, room):
					continue 
					
			# --- 核心：地脉磁力诱导算法 ---
			var dynamic_weight = float(room.weight) 
			
			for dir_vec in DIR_OFFSETS.keys():
				var neighbor_coords = coords + dir_vec # 这里的 neighbor 就是图里的 A
				var my_door_bit = DIR_OFFSETS[dir_vec]
				
				# 情况 1：如果邻居本身已经是灾害，直接把门怼上去！
				if map_data.has(neighbor_coords):
					var neighbor_type = map_data[neighbor_coords].room_type
					if neighbor_type == "深渊" or neighbor_type == "塌方":
						if room.has_door(my_door_bit):
							dynamic_weight *= magnetic_factor
							
				# 情况 2：如果邻居是虚空（像 A格子），且 A 旁边有灾害，也把门怼向 A！
				elif not map_data.has(neighbor_coords):
					if is_danger_zone(neighbor_coords):
						if room.has_door(my_door_bit):
							dynamic_weight *= magnetic_factor
							
			possible_rooms.append(room)
			room_weights.append(dynamic_weight)
			
	if possible_rooms.size() > 0:
		# 【重要】：这里换成了我们新写的动态权重抽取函数！
		var chosen_room = pick_custom_weight(possible_rooms, room_weights) 
		add_room(coords, chosen_room) 
	else:
		print("风水死局！被迫生成深渊！")
		if abyss_data: 
			add_room(coords, abyss_data)
		elif cave_in_data:
			add_room(coords, cave_in_data)

# ==========================================
# 高级风水算法：根据权重抽牌 (轮盘赌算法)
# ==========================================
# ==========================================
# 动态权重随机抽取：根据临时计算的权重发牌
# ==========================================
func pick_custom_weight(rooms: Array, weights: Array) -> RoomData:
	var total_weight: float = 0.0
	for w in weights:
		total_weight += w
		
	var random_val = randf_range(0.0, total_weight)
	var current_sum: float = 0.0
	
	for i in range(rooms.size()):
		current_sum += weights[i]
		if random_val <= current_sum:
			return rooms[i]
			
	return rooms.back()

# ==========================================
# 动态墙体算法：根据周围环境，决定每一面墙显不显示
# ==========================================
# ==========================================
# 动态墙体算法：根据周围环境，决定每一面墙显不显示
# ==========================================
func update_visual_walls(coords: Vector2i):
	if not map_views.has(coords): return
	
	var room = map_data[coords]
	var view = map_views[coords]
	var walls = {1: false, 2: false, 4: false, 8: false}
	
	for dir_vec in DIR_OFFSETS.keys():
		var dir_bit = DIR_OFFSETS[dir_vec]
		var neighbor_coords = coords + dir_vec
		var has_neighbor = map_data.has(neighbor_coords)
		var neighbor_room = map_data[neighbor_coords] if has_neighbor else null
		
		# 【修改这里】：情况 A，我是 0掩码（裂缝/废墟）
		if room.doors_bitmask == 0:
			# 废墟不需要任何外墙，干干净净
			walls[dir_bit] = false 
				
		# 情况 B：我是正常墓室
		else:
			if not room.has_door(dir_bit):
				walls[dir_bit] = true
			# 如果我有门，但门外是废墟(0掩码)，我的这扇门依然要被红墙封死
			elif has_neighbor and neighbor_room.doors_bitmask == 0:
				walls[dir_bit] = true
			else:
				walls[dir_bit] = false
				
	view.set_walls(walls[1], walls[2], walls[4], walls[8])

# ==========================================
# 风水沙盘推演：预判放这张牌会不会导致全图死锁
# ==========================================
func will_cause_dead_end(coords: Vector2i, test_room: RoomData) -> bool:
	# 1. 假装把这个房间放进地图
	map_data[coords] = test_room
	
	var has_future_path = false
	
	# 2. 扫视全图，看看还有没有向外敞开的门（也就是未来的探索点）
	for c in map_data.keys():
		var current_room = map_data[c]
		for dir_vec in DIR_OFFSETS.keys():
			var check_coords = c + dir_vec
			# 如果这个方向是虚空，且有门通向它，说明还有活路！
			if not map_data.has(check_coords) and current_room.has_door(DIR_OFFSETS[dir_vec]):
				has_future_path = true
				break # 只要找到一条活路，就不算死局
		if has_future_path:
			break
			
	# 3. 撤销假装放置的房间，恢复原状
	map_data.erase(coords)
	
	# 如果没有活路了，说明这张牌是“绝户牌”，返回 true
	return not has_future_path

# ==========================================
# 数据变异算法：当门被死穴封死时，真实转换房间类型
# ==========================================
func seal_door_and_mutate(target_coords: Vector2i, blocked_door_bit: int):
	var old_room = map_data[target_coords]
	
	if old_room.doors_bitmask == 0: return # 已经是深渊/塌方了，不用变
	if not old_room.has_door(blocked_door_bit): return # 本来就没门，不用变
	
	# 【新增的终极护身符】：起点神圣不可侵犯，绝对不能变异！
	if old_room.room_type == "起点":
		print("盗洞（起点）的退路被封，但风水坚如磐石，保留原样！")
		return # 直接退朝，不再执行后面的狸猫换太子逻辑！
		
	# 1. 算出砍掉这扇门之后，新的掩码数字
	var new_bitmask = old_room.doors_bitmask - blocked_door_bit
	
	# 2. 去大管家的牌堆 (room_pool) 里找一个长成这样的“替换件”
	var replacement_room: RoomData = null
	
	for room in room_pool:
		if room == null: continue
		# 优先找掩码一样，且房间类型（普通/宝藏等）也一样的
		if room.doors_bitmask == new_bitmask and room.room_type == old_room.room_type:
			replacement_room = room
			break
			
	# 如果找不到类型完全一样的，就随便找个掩码能对上的
	if replacement_room == null:
		for room in room_pool:
			if room != null and room.doors_bitmask == new_bitmask:
				replacement_room = room
				break
				
	# 3. 如果找到了完美的替换件，执行“狸猫换太子”！
	if replacement_room != null:
		print("因风水截断，", target_coords, " 的 [", old_room.room_name, "] 变异为 [", replacement_room.room_name, "]")
		
		# 替换底层纯数据
		map_data[target_coords] = replacement_room
		
		# 刷新这块地砖的文字和底色外观
		if map_views.has(target_coords):
			map_views[target_coords].setup(replacement_room)

# ==========================================
# 罗盘底纹：绘制背景虚线网格
# ==========================================
# ==========================================
# 罗盘底纹：绘制背景虚线网格
# ==========================================
func _draw():
	var grid_color = Color(1.0, 1.0, 1.0, 0.15) 
	var grid_radius = 50 
	var half_tile = tile_size / 2.0
	
	for i in range(-grid_radius, grid_radius + 1):
		var line_pos = i * tile_size - half_tile
		var start_limit = -grid_radius * tile_size
		var end_limit = grid_radius * tile_size
		
		# 绘制垂直虚线
		draw_dashed_line(
			Vector2(line_pos, start_limit), 
			Vector2(line_pos, end_limit), 
			grid_color, 
			-1.0,  # 【核心修改】：从 1.0 改成 -1.0，无视镜头缩放，永远保持 1 屏幕像素！
			4.0   
		)
		
		# 绘制水平虚线
		draw_dashed_line(
			Vector2(start_limit, line_pos), 
			Vector2(end_limit, line_pos), 
			grid_color, 
			-1.0,  # 【核心修改】：同上
			4.0
		)

# ==========================================
# 深渊蔓延：计算周围的深渊数量 (八方向：正向+斜向)
# ==========================================
func count_abyss_neighbors(coords: Vector2i) -> int:
	var count = 0
	var offsets = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), # 上下左右
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1) # 四个斜角
	]
	for offset in offsets:
		var check_coords = coords + offset
		if map_data.has(check_coords) and map_data[check_coords].doors_bitmask == 0:
			count += 1
	return count

# ==========================================
# 连通块探明：使用“泛洪算法 (Flood Fill)”算出这个深渊群有多大
# ==========================================
# ==========================================
# 地质蔓延：计算周围同类型灾害的数量
# ==========================================
func count_same_type_neighbors(coords: Vector2i, target_type: String) -> int:
	var count = 0
	var offsets = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	for offset in offsets:
		var check_coords = coords + offset
		# 【核心】：现在不写死掩码了，传进来什么类型，就探测什么类型！
		if map_data.has(check_coords) and map_data[check_coords].room_type == target_type:
			count += 1
	return count

# ==========================================
# 连通块探明：使用泛洪算法算出这个同类灾害群有多大
# ==========================================
func get_cluster_size(start_coords: Vector2i, target_type: String) -> int:
	var visited = []
	var queue = []
	var size = 0
	
	var offsets = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	
	for offset in offsets:
		var neighbor = start_coords + offset
		if map_data.has(neighbor) and map_data[neighbor].room_type == target_type:
			queue.append(neighbor)
			visited.append(neighbor)
			
	while queue.size() > 0:
		var current = queue.pop_front()
		size += 1
		for offset in offsets:
			var next_coords = current + offset
			if map_data.has(next_coords) and map_data[next_coords].room_type == target_type:
				if not visited.has(next_coords):
					visited.append(next_coords)
					queue.append(next_coords)
	return size

# ==========================================
# 危险区雷达：探测某个虚空格子旁边是否有灾害
# ==========================================
func is_danger_zone(empty_coords: Vector2i) -> bool:
	var offsets = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	for offset in offsets:
		var check_coords = empty_coords + offset
		if map_data.has(check_coords):
			var type = map_data[check_coords].room_type
			if type == "深渊" or type == "塌方":
				return true
	return false

# ==========================================
# 寻路算法 (BFS)：防止穿墙，只能走有门的连通格子
# ==========================================
func find_path(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	if start == target: return []
	
	var queue = [start]
	var came_from = {start: start} 

	while queue.size() > 0:
		var current = queue.pop_front()
		if current == target:
			break
			
		var room = map_data[current]
		for dir_vec in DIR_OFFSETS.keys():
			var next = current + dir_vec
			
			# 【防穿墙核心】：必须是我当前房间有门通向那个方向！
			if room.has_door(DIR_OFFSETS[dir_vec]):
				# 并且目标格子已经被探索过了
				if map_data.has(next) and not came_from.has(next):
					# 并且目标格子绝对不能是深渊或塌方（掩码不为 0）
					if map_data[next].doors_bitmask != 0:
						came_from[next] = current
						queue.append(next)
						
	# 如果找了一圈都没到达目标，说明被墙封死了
	if not came_from.has(target):
		return []
		
	# 回溯路径，生成从起点到终点的步法指令
	var path: Array[Vector2i] = []
	var curr = target
	while curr != start:
		path.push_front(curr)
		curr = came_from[curr]
		
	return path

# ==========================================
# 全新添加：大型建筑群生成算法（奇观系统）
# ==========================================
func try_place_module(start_coords: Vector2i) -> bool:
	if module_pool.is_empty(): return false
	if randf() > module_spawn_chance: return false 
	
	# 打乱模块池，随机挑一个来试
	var shuffled_modules = module_pool.duplicate()
	shuffled_modules.shuffle()
	
	for module_data in shuffled_modules:
		if module_data == null or module_data.module_scene == null: continue
		
		# 1. 凭空捏造一个建筑群（先在内存里做碰撞测试）
		var module_instance = module_data.module_scene.instantiate()
		var can_fit = true
		var rooms_to_add = {} 
		
		# 2. 遍历这个建筑群里的每一个地砖 (RoomView)
		for child in module_instance.get_children():
			# 只要是有 data 属性的地砖，我们就处理
			if child is Node2D and "data" in child and child.data != null: 
				# 算出这块砖在真实地图上的绝对坐标 (起点 + 自己在群里的局部坐标)
				var local_grid_offset = Vector2i(round(child.position.x / tile_size), round(child.position.y / tile_size))
				var absolute_coords = start_coords + local_grid_offset
				
				# 冲突检测：如果要占的格子已经有东西了，直接失败！
				if map_data.has(absolute_coords):
					can_fit = false
					break
				
				# 风水检测：这块砖的边缘如果挨着旧地图，门对得上吗？
				if not can_place_room(absolute_coords, child.data):
					can_fit = false
					break
					
				# 预算检测：不能超出最大墓室格子限制
				if map_data.size() + rooms_to_add.size() >= tomb_max_budget:
					can_fit = false
					break
					
				# 记录下来准备添加
				rooms_to_add[absolute_coords] = child
				
		# 3. 如果能完美塞进去！
		if can_fit and rooms_to_add.size() > 0:
			print(">>> 奇观降临！成功出土大型建筑群：", module_data.module_name)
			add_child(module_instance) # 正式加到屏幕上
			module_instance.position = start_coords * tile_size # 整体对齐
			
			# 把所有房间注册进大管家的大脑
			for abs_coords in rooms_to_add.keys():
				var room_view = rooms_to_add[abs_coords]
				map_data[abs_coords] = room_view.data
				map_views[abs_coords] = room_view
				explored_bounds = explored_bounds.expand(abs_coords)
				
			# 刷新所有新地砖和周围旧地砖的墙壁显示
			for abs_coords in rooms_to_add.keys():
				update_visual_walls(abs_coords)
				for dir_vec in DIR_OFFSETS.keys():
					update_visual_walls(abs_coords + dir_vec)
					
			update_ghost_tiles()
			return true 
			
		# 如果塞不进去，把内存里的垃圾删掉
		module_instance.queue_free()
		
	return false # 所有模块都塞不进去
