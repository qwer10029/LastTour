extends RefCounted
class_name RunState

## 纯数据容器：承载白天探索与夜晚塔防之间的所有共享状态。
## 不包含任何 Node 引用，全部为可序列化数据。
## 用于 GameManager 在两个独立场景之间传递状态。

# -- 背包物资（序列化字典，非 live InventoryData 引用）--
var backpack_dict: Dictionary = {}

# -- 车辆状态 --
var fuel: float = 0.0
var fuel_max: float = 999.0
var vehicle_hp: float = 100.0
var vehicle_hp_max: float = 100.0

# -- 乘员生存 --
var survival_dict: Dictionary = {}

# -- 地图与移动 --
var map_dict: Dictionary = {}
var travel_dict: Dictionary = {}

# -- 层级进度 --
var current_layer: int = 1
var total_layers: int = 3
var elevator_repair_progress: int = 0
var base_elevator_repair_cost: int = 3

# -- 运行配置 --
var difficulty: int = 1
var squad_id: String = "scavenger"
var day_index: int = 1
var run_difficulty_name: String = "普通"
var run_squad_name: String = "拾荒者"

# -- 时间系统 --
var time_dict: Dictionary = {}

# -- 玩家脚色位置 --
var foot_dict: Dictionary = {}

# -- 运行结束状态 --
var run_ended: bool = false
var run_end_reason: String = ""
var final_choice_id: String = ""

# -- 夜间结算缓存（用于 UI 展示）--
var last_night_losses: Array[String] = []
var last_night_salvage: String = ""


## 从 DayExploration（或兼容的 main）节点捕获全部状态。
func capture_from(node: Node) -> void:
	# 背包
	if node.has_method("capture_save_data"):
		var save_data: Dictionary = node.capture_save_data()
		_load_from_save_dict(save_data)
		return

	# 回退：逐字段捕获
	backpack_dict.clear()
	if node.get("_backpack") != null:
		var bp = node._backpack
		if bp.has_method("to_dictionary"):
			backpack_dict = bp.to_dictionary().duplicate()

	fuel = float(node.get("_fuel")) if node.get("_fuel") != null else 0.0
	fuel_max = float(node.get("fuel_max")) if node.get("fuel_max") != null else 999.0
	vehicle_hp = float(node.get("_vehicle_hp")) if node.get("_vehicle_hp") != null else 100.0
	vehicle_hp_max = float(node.get("_vehicle_hp_max")) if node.get("_vehicle_hp_max") != null else 100.0

	survival_dict.clear()
	if node.get("_survival") != null:
		var surv = node._survival
		if surv.has_method("to_dictionary"):
			survival_dict = surv.to_dictionary().duplicate()

	map_dict.clear()
	if node.get("_map") != null:
		var m = node._map
		if m.has_method("to_dictionary"):
			map_dict = m.to_dictionary().duplicate()

	travel_dict.clear()
	travel_dict = {
		"mode": int(node.get("_mode")) if node.get("_mode") != null else 0,
		"current_node_index": int(node.get("_current_node_index")) if node.get("_current_node_index") != null else -1,
		"previous_node_index": int(node.get("_previous_node_index")) if node.get("_previous_node_index") != null else -1,
		"arrived_from_index": int(node.get("_arrived_from_index")) if node.get("_arrived_from_index") != null else -1,
		"segment_from_index": int(node.get("_segment_from_index")) if node.get("_segment_from_index") != null else -1,
		"segment_target_index": int(node.get("_segment_target_index")) if node.get("_segment_target_index") != null else -1,
		"segment_progress": float(node.get("_segment_progress")) if node.get("_segment_progress") != null else 0.0,
		"segment_length": float(node.get("_segment_length")) if node.get("_segment_length") != null else 1.0,
		"drive_travel_distance": float(node.get("_drive_travel_distance")) if node.get("_drive_travel_distance") != null else 0.0,
		"current_district_index": int(node.get("_current_district_index")) if node.get("_current_district_index") != null else -1,
	}

	current_layer = int(node.get("_current_layer")) if node.get("_current_layer") != null else 1
	total_layers = int(node.get("total_layers")) if node.get("total_layers") != null else 3
	elevator_repair_progress = int(node.get("_elevator_repair_progress")) if node.get("_elevator_repair_progress") != null else 0
	base_elevator_repair_cost = int(node.get("_base_elevator_repair_cost")) if node.get("_base_elevator_repair_cost") != null else 3

	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager") if Engine.get_main_loop() is SceneTree else null
	difficulty = gm.difficulty if gm != null else 1
	squad_id = gm.squad_id if gm != null else "scavenger"
	run_difficulty_name = str(node.get("_run_difficulty_name")) if node.get("_run_difficulty_name") != null else "普通"
	run_squad_name = str(node.get("_run_squad_name")) if node.get("_run_squad_name") != null else "拾荒者"

	day_index = 1
	if node.get("time_system") != null:
		var ts = node.time_system
		if ts.has_method("to_dictionary"):
			time_dict = ts.to_dictionary().duplicate()
			day_index = int(ts.day_index)

	foot_dict.clear()
	if node.get("_foot_local_pos") != null:
		foot_dict["local_x"] = float(node._foot_local_pos.x)
		foot_dict["local_y"] = float(node._foot_local_pos.y)

	run_ended = bool(node.get("_run_ended")) if node.get("_run_ended") != null else false
	run_end_reason = str(node.get("_run_end_reason")) if node.get("_run_end_reason") != null else ""
	final_choice_id = str(node.get("_final_choice_id")) if node.get("_final_choice_id") != null else ""

	last_night_losses.clear()
	var losses = node.get("_last_night_losses")
	if losses is Array:
		for s in losses:
			last_night_losses.append(str(s))
	last_night_salvage = str(node.get("_last_night_salvage")) if node.get("_last_night_salvage") != null else ""


## 回退路径：直接从存档字典加载（与 SaveManager 兼容）。
func _load_from_save_dict(data: Dictionary) -> void:
	backpack_dict.clear()
	var travel_raw = data.get("travel", {})
	if travel_raw.has("items"):
		backpack_dict = travel_raw["items"].duplicate()

	fuel = float(travel_raw.get("fuel", 0.0))
	fuel_max = float(data.get("fuel_max", 999.0))
	vehicle_hp = float(data.get("vehicle_hp", 100.0))
	vehicle_hp_max = float(data.get("vehicle_hp_max", 100.0))

	survival_dict.clear()
	if travel_raw.has("survival"):
		survival_dict = travel_raw["survival"].duplicate()

	map_dict.clear()
	if data.has("map"):
		map_dict = data["map"].duplicate()

	travel_dict = {
		"mode": int(travel_raw.get("mode", 0)),
		"current_node_index": int(travel_raw.get("current_node_index", -1)),
		"previous_node_index": int(travel_raw.get("previous_node_index", -1)),
		"arrived_from_index": int(travel_raw.get("arrived_from_index", -1)),
		"segment_from_index": int(travel_raw.get("segment_from_index", -1)),
		"segment_target_index": int(travel_raw.get("segment_target_index", -1)),
		"segment_progress": float(travel_raw.get("segment_progress", 0.0)),
		"segment_length": float(travel_raw.get("segment_length", 1.0)),
		"drive_travel_distance": float(travel_raw.get("drive_travel_distance", 0.0)),
		"current_district_index": int(travel_raw.get("current_district_index", -1)),
	}

	var layer_raw = data.get("layer", {})
	current_layer = int(layer_raw.get("current_layer", 1))
	total_layers = int(data.get("total_layers", 3))
	elevator_repair_progress = int(layer_raw.get("elevator_repair_progress", 0))
	base_elevator_repair_cost = int(data.get("base_elevator_repair_cost", 3))

	difficulty = int(data.get("difficulty", 1))
	squad_id = str(data.get("squad_id", "scavenger"))
	var gm2: Node = Engine.get_main_loop().root.get_node_or_null("GameManager") if Engine.get_main_loop() is SceneTree else null
	run_difficulty_name = gm2.get_difficulty_name(difficulty) if gm2 != null and gm2.has_method("get_difficulty_name") else "普通"
	run_squad_name = gm2.get_squad_name(squad_id) if gm2 != null and gm2.has_method("get_squad_name") else "拾荒者"

	time_dict.clear()
	if data.has("time"):
		time_dict = data["time"].duplicate()
		day_index = maxi(int(data["time"].get("day_index", 1)), 1)

	foot_dict.clear()
	if data.has("foot"):
		foot_dict = data["foot"].duplicate()

	run_ended = bool(layer_raw.get("run_ended", false))
	run_end_reason = str(layer_raw.get("run_end_reason", ""))
	final_choice_id = str(layer_raw.get("final_choice_id", ""))


## 将 RunState 恢复到 DayExploration（或兼容的 main）节点。
func restore_to(node: Node) -> void:
	if node.has_method("restore_from_run_state"):
		node.restore_from_run_state(self)
		return

	# 回退：手动恢复
	if node.get("_backpack") != null:
		var bp = node._backpack
		if bp.has_method("load_from_dictionary"):
			bp.load_from_dictionary(backpack_dict)

	node.set("_fuel", fuel)
	node.set("fuel_max", fuel_max)
	node.set("_vehicle_hp", vehicle_hp)
	node.set("_vehicle_hp_max", vehicle_hp_max)

	if node.get("_survival") != null:
		var surv = node._survival
		if surv.has_method("load_from_dictionary"):
			surv.load_from_dictionary(survival_dict)

	if node.get("_map") != null:
		var m = node._map
		if m.has_method("load_from_dictionary"):
			m.load_from_dictionary(map_dict)

	node.set("_mode", int(travel_dict.get("mode", 0)))
	node.set("_current_node_index", int(travel_dict.get("current_node_index", -1)))
	node.set("_previous_node_index", int(travel_dict.get("previous_node_index", -1)))
	node.set("_arrived_from_index", int(travel_dict.get("arrived_from_index", -1)))
	node.set("_segment_from_index", int(travel_dict.get("segment_from_index", -1)))
	node.set("_segment_target_index", int(travel_dict.get("segment_target_index", -1)))
	node.set("_segment_progress", float(travel_dict.get("segment_progress", 0.0)))
	node.set("_segment_length", float(travel_dict.get("segment_length", 1.0)))
	node.set("_drive_travel_distance", float(travel_dict.get("drive_travel_distance", 0.0)))
	node.set("_current_district_index", int(travel_dict.get("current_district_index", -1)))

	node.set("_current_layer", current_layer)
	node.set("_elevator_repair_progress", elevator_repair_progress)
	node.set("_base_elevator_repair_cost", base_elevator_repair_cost)

	node.set("_run_difficulty_name", run_difficulty_name)
	node.set("_run_squad_name", run_squad_name)
	node.set("_run_ended", run_ended)
	node.set("_run_end_reason", run_end_reason)
	node.set("_final_choice_id", final_choice_id)

	if foot_dict.has("local_x") and node.get("_foot_local_pos") != null:
		node._foot_local_pos = Vector2(float(foot_dict["local_x"]), float(foot_dict["local_y"]))

	if node.get("time_system") != null:
		var ts = node.time_system
		if ts.has_method("load_from_dictionary"):
			ts.load_from_dictionary(time_dict)

	# 夜间结算信息
	var losses = node.get("_last_night_losses")
	if losses is Array:
		losses.clear()
		for s in last_night_losses:
			losses.append(s)
	node.set("_last_night_salvage", last_night_salvage)


## 将夜晚塔防结算结果应用到 RunState（在切回白天场景之前调用）。
func apply_night_result(result: Dictionary) -> void:
	# 燃料损失
	fuel = maxf(fuel - float(result.get("fuel_loss", 0.0)), 0.0)

	# 车辆 HP
	if result.has("base_hp"):
		vehicle_hp = clampf(float(result.get("base_hp", vehicle_hp)), 0.0, vehicle_hp_max)
	if result.has("base_hp_max"):
		vehicle_hp_max = float(result.get("base_hp_max", vehicle_hp_max))
		vehicle_hp = clampf(vehicle_hp, 0.0, vehicle_hp_max)

	# 体力惩罚
	var outcome: String = str(result.get("outcome", "success"))
	if outcome == "fail":
		var stamina_penalty := 15.0
		if survival_dict.has("stamina"):
			survival_dict["stamina"] = maxf(float(survival_dict["stamina"]) - stamina_penalty, 0.0)
	elif outcome == "partial":
		var stamina_penalty := 5.0
		if survival_dict.has("stamina"):
			survival_dict["stamina"] = maxf(float(survival_dict["stamina"]) - stamina_penalty, 0.0)

	# 背包：突破损耗已在战斗中实时写入 final_backpack_dict
	if result.has("final_backpack_dict"):
		backpack_dict = result["final_backpack_dict"].duplicate()

	# 夜末回收已包含在 final_backpack_dict 中，无需额外处理

	# 记录损失明细（用于 UI）
	last_night_losses.clear()
	if result.has("breach_losses"):
		var bl = result["breach_losses"]
		if bl is Dictionary:
			for item_id: String in bl.keys():
				var n := int(bl[item_id])
				if n > 0:
					last_night_losses.append("%s×%d" % [_item_name(item_id), n])

	last_night_salvage = ""
	if result.has("salvage") and not str(result.get("salvage", {})).is_empty():
		# salvage 已合并到 final_backpack_dict，仅记录文本
		pass

	# 车辆毁损检查
	if outcome == "vehicle_destroyed" or vehicle_hp <= 0.0:
		vehicle_hp = 0.0
		run_ended = true
		run_end_reason = "vehicle_destroyed"


func _item_name(item_id: String) -> String:
	# 安全方式获取物品名（避免循环依赖）
	var defs: Resource = load("res://scripts/items/item_defs.gd")
	if defs != null and defs.has_method("get_item_name"):
		return defs.get_item_name(item_id)
	return item_id


## 完整的序列化字典（可用于持久化存储，与 SaveManager 兼容）。
func to_full_dict() -> Dictionary:
	return {
		"difficulty": difficulty,
		"squad_id": squad_id,
		"fuel_max": fuel_max,
		"vehicle_hp": vehicle_hp,
		"vehicle_hp_max": vehicle_hp_max,
		"base_elevator_repair_cost": base_elevator_repair_cost,
		"total_layers": total_layers,
		"map": map_dict,
		"travel": {
			"mode": int(travel_dict.get("mode", 0)),
			"fuel": fuel,
			"items": backpack_dict,
			"survival": survival_dict,
			"current_node_index": int(travel_dict.get("current_node_index", -1)),
			"previous_node_index": int(travel_dict.get("previous_node_index", -1)),
			"arrived_from_index": int(travel_dict.get("arrived_from_index", -1)),
			"segment_from_index": int(travel_dict.get("segment_from_index", -1)),
			"segment_target_index": int(travel_dict.get("segment_target_index", -1)),
			"segment_progress": float(travel_dict.get("segment_progress", 0.0)),
			"segment_length": float(travel_dict.get("segment_length", 1.0)),
			"drive_travel_distance": float(travel_dict.get("drive_travel_distance", 0.0)),
			"current_district_index": int(travel_dict.get("current_district_index", -1)),
		},
		"layer": {
			"current_layer": current_layer,
			"elevator_repair_progress": elevator_repair_progress,
			"run_ended": run_ended,
			"run_end_reason": run_end_reason,
			"final_choice_id": final_choice_id,
		},
		"time": time_dict,
		"foot": foot_dict,
	}


## 从完整字典加载（兼容 SaveManager 格式）。
func from_full_dict(data: Dictionary) -> void:
	_load_from_save_dict(data)

	# 补充 RunState 特有字段
	total_layers = int(data.get("total_layers", 3))


## 创建一份独立副本。
func duplicate_state():  # -> RunState
	var rs = get_script().new()
	rs.backpack_dict = backpack_dict.duplicate()
	rs.fuel = fuel
	rs.fuel_max = fuel_max
	rs.vehicle_hp = vehicle_hp
	rs.vehicle_hp_max = vehicle_hp_max
	rs.survival_dict = survival_dict.duplicate()
	rs.map_dict = map_dict.duplicate()
	rs.travel_dict = travel_dict.duplicate()
	rs.current_layer = current_layer
	rs.total_layers = total_layers
	rs.elevator_repair_progress = elevator_repair_progress
	rs.base_elevator_repair_cost = base_elevator_repair_cost
	rs.difficulty = difficulty
	rs.squad_id = squad_id
	rs.day_index = day_index
	rs.run_difficulty_name = run_difficulty_name
	rs.run_squad_name = run_squad_name
	rs.time_dict = time_dict.duplicate()
	rs.foot_dict = foot_dict.duplicate()
	rs.run_ended = run_ended
	rs.run_end_reason = run_end_reason
	rs.final_choice_id = final_choice_id
	rs.last_night_losses = last_night_losses.duplicate()
	rs.last_night_salvage = last_night_salvage
	return rs
