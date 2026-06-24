# 三项后续任务实施计划

本计划承接 [docs/plan_communication_terminal.md](plan_communication_terminal.md) 中标记为「不做（留待后续）」的三项工作：

1. §7.8 完整证据拾取系统（替换 `placeholder_run_*` 临时桩）
2. 背包档案库标签页
3. 留言墙 / 真结局 credits 场景

执行者请按 1 → 2 → 3 顺序完成（任务 2 依赖任务 1 的数据，任务 3 依赖任务 1 的 `MetaManager.endings_seen`）。每完成一项，在终端运行 `cd /home/l/Desktop/LastTour/game && godot --headless --check-only` 之类静态检查（如可用），并自我审查 grep 结果以避免重复粘贴。

---

## 通用约束（执行前必读）

- **不要清理「无关代码」**。这是单点改动，不要顺手重构 main.gd 其它部分。
- **不要修改 [game/scripts/ui/communication_terminal.gd](../game/scripts/ui/communication_terminal.gd)**，它已稳定。
- **GDScript 4 语法**：使用 `class_name`、`@onready`、`func _ready() -> void:` 等。typed arrays 写 `Array[String]`。
- **Godot autoload 调用**：通过名称直接访问，例如 `MetaManager.evidence_collected`、`SaveManager.has_save()`。新增 autoload 必须更新 [game/project.godot](../game/project.godot) `[autoload]` 段。
- **不要新增 emoji**。中文 UI 文案沿用既有冷峻科幻风（参考 [game/scripts/run_ending_defs.gd](../game/scripts/run_ending_defs.gd)）。
- **每次 Edit 之前必先 Read**。如同一字符串需要替换两处，使用 `replace_all: true` 而不是连续两次 Edit。
- **写完一个文件后立刻用 `grep` 验证**没有重复块（之前有过 `const X = ...\nconst X = ...` 的污染）。例：
  ```bash
  grep -c 'class_name EvidenceData' game/scripts/autoload/evidence_data.gd
  # 必须输出 1
  ```
- **MetaManager 已存在** ([game/scripts/autoload/meta_manager.gd](../game/scripts/autoload/meta_manager.gd))，已包含 `evidence_collected`、`management_rights_transferred`、`endings_seen`、`add_evidence()`、`save_meta()`、`load_meta()`、`record_ending()`。**只增不删**它的字段；版本号 `META_VERSION` 不要随便改，改了会触发玩家存档重置。
- **保持改动局部**。每个任务最多触及它列出的文件，不要顺手编辑别处。

---

## 任务 1：§7.8 证据拾取系统

### 目标

替换现有的 `placeholder_run_*` 占位证据写入逻辑，改为：在地图资源点中按概率/位置投放具名证据，玩家拾取时写入 `MetaManager.evidence_collected`。本次仍**不做**「§7.8 unlock_flag 复杂触发条件」（如 `layer_3_archive_found`），改为简单的「按层投放、首次拾取即收集」。

### 现状摘要

- 资源拾取已通过 [game/scenes/resource_pickup.tscn](../game/scenes/resource_pickup.tscn) + [game/scripts/resource_pickup.gd](../game/scripts/resource_pickup.gd) 工作。`item_id` 用 `setup_loot()` 注入，拾取后 emit `collected(item_id)`。
- 投放在 [game/scripts/main.gd](../game/scripts/main.gd) `_spawn_resources()`（第 188-215 行）完成；当前 `loot_id` 默认为 `"scrap"` 或来自 `spawn_data.item_id`。
- 拾取处理在 main.gd `_on_resource_collected()`（搜索 `func _on_resource_collected`，约第 580 行附近）。
- main.gd 当前在 `_on_terminal_strike()` 写入 `"placeholder_run_<timestamp>"`，需要删除该写入（证据现在通过拾取累积）。

### 文件改动

#### 新增

**[game/scripts/autoload/evidence_data.gd](../game/scripts/autoload/evidence_data.gd)** — 证据定义查询。autoload，加载 `res://data/evidence.json`（不是 `user://`，定义文件随游戏分发）。API：

```gdscript
extends Node

const DATA_PATH := "res://data/evidence.json"

var _entries: Dictionary = {}    # evidence_id -> Dictionary {title, content, category, unlock_layer}

func _ready() -> void:
    _load_entries()

func _load_entries() -> void:
    _entries.clear()
    if not ResourceLoader.exists(DATA_PATH) and not FileAccess.file_exists(DATA_PATH):
        return
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        return
    var text := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var raw: Variant = parsed.get("evidences", [])
    if typeof(raw) != TYPE_ARRAY:
        return
    for entry_var in raw:
        if typeof(entry_var) != TYPE_DICTIONARY:
            continue
        var entry: Dictionary = entry_var
        var id := str(entry.get("evidence_id", ""))
        if id == "":
            continue
        _entries[id] = entry

func has_entry(id: String) -> bool:
    return _entries.has(id)

func get_entry(id: String) -> Dictionary:
    return _entries.get(id, {})

func all_ids() -> Array[String]:
    var out: Array[String] = []
    for k in _entries.keys():
        out.append(str(k))
    return out

func ids_for_layer(layer: int) -> Array[String]:
    var out: Array[String] = []
    for k in _entries.keys():
        var entry: Dictionary = _entries[k]
        if int(entry.get("unlock_layer", 0)) == layer:
            out.append(str(k))
    return out

func title_of(id: String) -> String:
    return str(_entries.get(id, {}).get("title", id))

func content_of(id: String) -> String:
    return str(_entries.get(id, {}).get("content", ""))

func layer_of(id: String) -> int:
    return int(_entries.get(id, {}).get("unlock_layer", 0))
```

**[game/data/evidence.json](../game/data/evidence.json)** — 直接复制 [终末旅行 — 技术设计说明书（草稿）.md](../终末旅行 — 技术设计说明书（草稿）.md) §8.3 给出的四条 evidence。`unlock_flag` 字段保留但本次不消费。

```json
{
  "evidences": [
    {
      "evidence_id": "clone_identity",
      "title": "克隆人身份确认文件",
      "content": "克隆人是地下昆仑程序的产物，身份编号自动指派。本代勘探者不存在自然出生记录，所有‘记忆’来自统一的初始化模板。",
      "category": "clone_identity",
      "unlock_layer": 1,
      "unlock_flag": "layer_1_archive_found"
    },
    {
      "evidence_id": "faction_conflict",
      "title": "地下派系争论录音",
      "content": "\"地表开发派\" 与 \"本代优先派\" 在高层会议中的对话片段。会议未达成结论，会后档案被加密封存。",
      "category": "faction_conflict",
      "unlock_layer": 2,
      "unlock_flag": "layer_2_archive_found"
    },
    {
      "evidence_id": "human_extinction_proof",
      "title": "人类灭绝事件时间线",
      "content": "依据广播记录与系统日志推断的人类集体行动失败过程。最后一次有效的人类指令早于克隆程序启动。",
      "category": "human_extinction_proof",
      "unlock_layer": 3,
      "unlock_flag": "layer_3_archive_found"
    },
    {
      "evidence_id": "backdoor_info",
      "title": "工程师后门权限转移记录",
      "content": "通讯系统设计者刘工程师在系统部署前留下的权限转移指令。当人类指挥源缺席且持有该证据时，最高权限将移交给现场操作员。",
      "category": "backdoor_info",
      "unlock_layer": 3,
      "unlock_flag": "layer_3_engineer_note_found"
    }
  ]
}
```

注：`total_layers = 3`（见 [game/scripts/main.gd](../game/scripts/main.gd) 第 18 行），所以四条证据被压缩到 1/2/3 层（layer 3 放两条）。**不要**写 `unlock_layer: 4` 或 5。

#### 修改

**[game/project.godot](../game/project.godot)** — 在 `[autoload]` 段添加：
```
EvidenceData="*res://scripts/autoload/evidence_data.gd"
```
注意 `*` 前缀。位置在 `MetaManager` 之后。

**[game/scripts/items/item_defs.gd](../game/scripts/items/item_defs.gd)** — 不改 `ITEMS`，但需让证据物品有可拾取标识。**不**把证据加进 `ITEMS`，避免污染普通物品 UI。证据走独立 id 命名空间，前缀 `evidence:`，例如 `evidence:clone_identity`。

**[game/scripts/resource_pickup.gd](../game/scripts/resource_pickup.gd)** — 在 `_load_texture()` 与 `_refresh_label()` 中识别 `evidence:` 前缀，给特殊外观（金色或紫色）+ 名称读 `EvidenceData.title_of(real_id)`：
```gdscript
func _is_evidence() -> bool:
    return item_id.begins_with("evidence:")

func _evidence_id() -> String:
    return item_id.substr("evidence:".length())
```
在 `_load_texture()` 开头加分支：如果是证据，给 `sprite.modulate = Color("#ffd966")`（暖金色），texture 沿用 `"scrap"` 临时凑（或 `null` 由 modulate 覆盖空 sprite — 实测看哪种不报错）。
在 `_refresh_label()` 开头加分支：证据时 `label.text = EvidenceData.title_of(_evidence_id())`，颜色 `Color("#ffe28a")`。

**[game/scripts/main.gd](../game/scripts/main.gd)** — 三处改动：

1. **`_spawn_resources()`（第 188-215 行）**：投放完普通资源后，对当前层投放未收集的证据。在循环结束后追加：
   ```gdscript
   _spawn_evidence_pickups()
   ```
   并新增方法（放在 `_spawn_resources` 之后）：
   ```gdscript
   func _spawn_evidence_pickups() -> void:
       var ids := EvidenceData.ids_for_layer(_current_layer)
       if ids.is_empty():
           return
       var district_indices: Array = _map.district_indices.duplicate()
       if district_indices.is_empty():
           return
       var rng := RandomNumberGenerator.new()
       rng.randomize()
       for evidence_id in ids:
           if MetaManager.evidence_collected.has(evidence_id):
               continue
           var district_index: int = int(district_indices[rng.randi_range(0, district_indices.size() - 1)])
           var rect := _map.cell_rect(district_index)
           var spawn_offset := Vector2(
               rng.randf_range(rect.size.x * 0.25, rect.size.x * 0.75),
               rng.randf_range(rect.size.y * 0.25, rect.size.y * 0.75)
           )
           var pickup := resource_scene.instantiate()
           add_child(pickup)
           pickup.visible = false
           pickup.position = rect.position + spawn_offset
           pickup.set_meta("district_index", district_index)
           pickup.set_meta("item_id", "evidence:%s" % evidence_id)
           if pickup.has_method("setup_loot"):
               pickup.setup_loot("evidence:%s" % evidence_id)
           if pickup.has_signal("collected"):
               pickup.collected.connect(_on_resource_collected.bind(district_index))
           _resource_nodes.append(pickup)
   ```

2. **`_on_resource_collected()`（搜索 `func _on_resource_collected`，约第 580 行）** — 在加 `_backpack.add(loot_id, 1)` 之前先识别证据 id：
   ```gdscript
   func _on_resource_collected(item_id: String, district_index: int) -> void:
       var loot_id := str(item_id)
       if loot_id == "":
           loot_id = "scrap"
       if loot_id.begins_with("evidence:"):
           var ev_id := loot_id.substr("evidence:".length())
           if MetaManager.add_evidence(ev_id):
               MetaManager.save_meta()
               _show_evidence_pickup_toast(ev_id)
           return
       var added := _backpack.add(loot_id, 1)
       # ... 原有 added 后续逻辑保持不动
   ```
   找现有 `_on_resource_collected` 的精确签名后做 minimal 替换 — 它**可能**不接 `district_index`（用 `.bind(district_index)` 传入）。如果第二参不存在请按现有签名匹配，**不要**改它的签名。

3. **删除 `_on_terminal_strike` 中的占位写入**：
   ```gdscript
   # 删除这两行：
   var stub_id := "placeholder_run_%d" % Time.get_unix_time_from_system()
   MetaManager.add_evidence(stub_id)
   # 但保留 MetaManager.save_meta()，因为可能记录其它字段。
   ```
   保留 `MetaManager.save_meta()`（用来持久化任何已经在本局拾取的证据）。

4. **新增 toast 方法**（放在 `_on_resource_collected` 附近）：
   ```gdscript
   func _show_evidence_pickup_toast(evidence_id: String) -> void:
       var title := EvidenceData.title_of(evidence_id)
       # 复用既有的临时提示通道。如果 main.gd 里有 _show_toast / _flash_message / _set_status_message 之类，调它；否则简单 print：
       print("[Evidence] 拾取：%s" % title)
   ```
   先 grep main.gd：`grep -n 'func _show.*toast\|func _flash\|func _set_status' game/scripts/main.gd`，找到现成 UI 提示方法就用它（HUD 自带的也行）。找不到就保留 `print` 临时凑，等做完再让用户决定 UX。

### 验收

```bash
# 删存档
rm -f ~/.local/share/godot/app_userdata/LastTour/meta.json
# 启动游戏，玩到第 1 层探索 → 找金色拾取点 → 拾取 → 退出 → meta.json 出现 clone_identity
cat ~/.local/share/godot/app_userdata/LastTour/meta.json
# 第 2、3 层同理
# 集齐 3 个 → 修电梯到顶 → 通信终端验证通过 → 进入 ceremony
```

### 风险
- `_map.cell_rect` / `_map.district_indices` API 假设其存在；如果签名与 `_spawn_resources` 不同，复用 `_spawn_resources` 的写法（它已能跑）。
- `unlock_layer` 数据被压缩到 1-3 层，不要改成 1-5。

---

## 任务 2：背包档案库标签页

### 目标

在 [game/scripts/ui/backpack_ui.gd](../game/scripts/ui/backpack_ui.gd) 顶部加 Tab 切换：「物品」（现有 UI）/ 「档案库」（新）。档案库列出 `EvidenceData.all_ids()`，已收集的显示标题+完整内容，未收集的显示 `○ ???`。**不要**触发 evidence 的「使用 / 丢弃」。

### 现状摘要

- 当前 `BackpackUI` 是 `Control`，class_name 已声明，UI 在 `_build_ui()` 一次构建。
- main.gd 通过 `_backpack_ui.show_backpack(_backpack)` 打开。

### 改法

**只改 [game/scripts/ui/backpack_ui.gd](../game/scripts/ui/backpack_ui.gd)。**不要新建文件、不要改 main.gd。

核心改动：
1. 在 `_build_ui()` 的 `outer` VBox 第一个孩子（title 之后）插入一个 `TabBar` 或两个 Button 实现的简易切换。推荐 `TabBar`（Godot 4 自带）：
   ```gdscript
   _tab_bar = TabBar.new()
   _tab_bar.add_tab("物品")
   _tab_bar.add_tab("档案库")
   _tab_bar.tab_changed.connect(_on_tab_changed)
   outer.add_child(_tab_bar)
   ```
2. 创建 `_archive_view: Control`，与现有 `body: HBoxContainer`（物品视图）并列放在一个 `_view_stack: Control` 容器里，根据 tab 切 visible。**不要**用 `TabContainer`，它会重新解构现有 layout。两个孩子 + 切 visible 即可。
3. `_archive_view` 内部：左侧 `ItemList` 显示证据列表（已收集显示真名，未收集显示 `○ ???`，按 `unlock_layer` 排序），右侧 `Label` 显示选中的内容。点击未收集项时右侧显示 `"（尚未收集）"`。
4. `show_backpack()` 中调用 `_refresh_archive_list()` 刷新。
5. 新增方法：
   ```gdscript
   func _refresh_archive_list() -> void:
       _archive_list.clear()
       var ids := EvidenceData.all_ids()
       ids.sort_custom(func(a, b): return EvidenceData.layer_of(a) < EvidenceData.layer_of(b))
       for ev_id in ids:
           var collected := MetaManager.evidence_collected.has(ev_id)
           var label_text: String
           if collected:
               label_text = "✓ %s（第%d层）" % [EvidenceData.title_of(ev_id), EvidenceData.layer_of(ev_id)]
           else:
               label_text = "○ ??? （第%d层）" % EvidenceData.layer_of(ev_id)
           var idx := _archive_list.add_item(label_text)
           _archive_list.set_item_metadata(idx, ev_id)
           if not collected:
               _archive_list.set_item_disabled(idx, false)  # 仍可点击查看占位文本
               _archive_list.set_item_custom_fg_color(idx, Color(0.55, 0.6, 0.7))
   
   func _on_archive_selected(index: int) -> void:
       if index < 0:
           _archive_detail.text = ""
           return
       var ev_id := str(_archive_list.get_item_metadata(index))
       if MetaManager.evidence_collected.has(ev_id):
           _archive_detail.text = "%s\n\n%s" % [
               EvidenceData.title_of(ev_id),
               EvidenceData.content_of(ev_id),
           ]
       else:
           _archive_detail.text = "（尚未收集此档案。）"
   
   func _on_tab_changed(tab: int) -> void:
       _items_view.visible = (tab == 0)
       _archive_view.visible = (tab == 1)
   ```
6. 新增成员变量：`_tab_bar: TabBar`、`_items_view: Control`（即原来的 `body` HBox，把它包一层 Control 或直接重命名引用）、`_archive_view: Control`、`_archive_list: ItemList`、`_archive_detail: Label`。

**最关键约束**：现有 `body: HBoxContainer` 持有 `_item_list` + side。把它直接当作 `_items_view` 即可（HBoxContainer 是 Control 的子类），无需多套一层 Control。命名上保留局部变量名，只新增成员变量引用：
```gdscript
var _tab_bar: TabBar
var _items_view: Control          # 指向原 body HBoxContainer
var _archive_view: Control
var _archive_list: ItemList
var _archive_detail: Label
```
在 `_build_ui()` 末尾把 `body` 赋给 `_items_view`：`_items_view = body`，再 build `_archive_view` 加到 `outer`。

### 验收

1. 进游戏 → Tab 打开背包 → 看到上方两个 tab，默认「物品」。
2. 切到「档案库」 → 显示 4 行 `○ ??? （第 X 层）`。
3. 拾取 `clone_identity` → 重开背包 → 第一行变成 `✓ 克隆人身份确认文件（第1层）`，点击右侧显示完整内容。
4. 切回「物品」 → 现有 UI 完全正常，「使用」「丢弃」按钮仍工作。
5. ESC 关闭背包正常，不报错。

### 风险
- `TabBar` vs `TabContainer`：用 `TabBar`，自己 toggle visibility。`TabContainer` 会强制把孩子作为 page，破坏现有 layout。
- 不要把 evidence 当物品塞进 `_inventory`，它走 MetaManager 独立持久化。

---

## 任务 3：留言墙 / 真结局 credits

### 目标

实现 [game/scripts/run_ending_defs.gd](../game/scripts/run_ending_defs.gd) `FINAL_CHOICES` 中三选一的差异化展现：

- `stop_signal`（真结局）→ 滚动 credits 名单 → 回主菜单。
- `message_only` → 玩家输入一行留言 → 写入 `MetaManager.message_wall` → 显示「下一代克隆人将看到」+ 历史留言列表 → 回主菜单。
- `fake_success` → 显示讽刺信息 + 简短谢幕 → 回主菜单。

### 现状摘要

- 选择由 [game/scripts/ui/run_end_overlay.gd](../game/scripts/ui/run_end_overlay.gd) 触发 `ceremony_choice_made(choice_id)` 信号。
- main.gd `_on_final_ceremony_choice(choice_id)`（grep 一下定位）当前只把 `_final_choice_id` 写入并走 `_show_run_summary()`。
- `MetaManager.endings_seen` 已存在，**但 `message_wall` 字段没有**，需要在 MetaManager 加。

### 文件改动

#### 修改 [game/scripts/autoload/meta_manager.gd](../game/scripts/autoload/meta_manager.gd)

加字段（**保持 META_VERSION 不变**，旧存档缺该字段时 `load_meta` 自然给空数组）：
```gdscript
var message_wall: Array[Dictionary] = []  # 每条 {text: String, layer: int, run_id: String}
```
在 `load_meta()` reset 段加 `message_wall = []`，并在解析末尾加：
```gdscript
for m in data.get("message_wall", []):
    if typeof(m) != TYPE_DICTIONARY:
        continue
    var entry: Dictionary = m
    message_wall.append({
        "text": str(entry.get("text", "")),
        "layer": int(entry.get("layer", 0)),
        "run_id": str(entry.get("run_id", "")),
    })
```
在 `save_meta()` 的 `payload` 中加 `"message_wall": message_wall,`。

新增 API：
```gdscript
func append_message(text: String, layer: int) -> void:
    if text.strip_edges() == "":
        return
    message_wall.append({
        "text": text.strip_edges().substr(0, 80),  # 限长 80
        "layer": layer,
        "run_id": "%d" % Time.get_unix_time_from_system(),
    })
```

#### 新增 [game/scripts/ui/ending_outcome_overlay.gd](../game/scripts/ui/ending_outcome_overlay.gd)

纯代码 CanvasLayer，参考 [game/scripts/ui/run_end_overlay.gd](../game/scripts/ui/run_end_overlay.gd) 与 [game/scripts/ui/communication_terminal.gd](../game/scripts/ui/communication_terminal.gd) 的写法。骨架：

```gdscript
extends CanvasLayer

signal closed

enum Mode { CREDITS, MESSAGE, FAKE_SUCCESS }

var _mode: int = Mode.CREDITS
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: RichTextLabel       # credits 滚动
var _msg_input: LineEdit       # message_only 模式
var _msg_history: RichTextLabel
var _primary_btn: Button
var _layer_at_choice: int = 0

func _ready() -> void:
    layer = 130
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    _build_ui()

func show_outcome(choice_id: String, run_layer: int) -> void:
    _layer_at_choice = run_layer
    visible = true
    match choice_id:
        "stop_signal":
            _enter_credits()
        "message_only":
            _enter_message()
        "fake_success":
            _enter_fake_success()
        _:
            _enter_credits()

func hide_overlay() -> void:
    visible = false
```

（详细 `_build_ui()` 参考 communication_terminal.gd 的 PanelContainer + VBox 模板，自行扩展。三个模式共用一个 panel，按模式切换内部控件 visibility。）

关键交互：
- `_enter_credits()`：`_title.text = "克隆循环 · 终止"`，`_body.text` 写入感谢/制作名单（用占位 `"程序员：…\n美术：…\n音效：…\n感谢游玩。"`，让用户后续替换）。`_primary_btn.text = "返回主菜单"`，pressed → emit `closed`。
- `_enter_message()`：显示输入框（`LineEdit`，max_length 80），`_msg_history` 显示既有 `MetaManager.message_wall` 列表（最多最近 10 条）。`_primary_btn.text = "留下留言"`，pressed → `MetaManager.append_message(_msg_input.text, _layer_at_choice); MetaManager.save_meta(); emit closed`。
- `_enter_fake_success()`：纯文本展示，`_primary_btn.text = "返回主菜单"`，pressed → emit `closed`。

#### 修改 [game/scripts/main.gd](../game/scripts/main.gd)

1. 顶部加 preload：
   ```gdscript
   const EndingOutcomeOverlayScript = preload("res://scripts/ui/ending_outcome_overlay.gd")
   ```
2. 加成员：
   ```gdscript
   var _ending_outcome_overlay: CanvasLayer
   ```
3. `_setup_run_end_ui()` 末尾加：
   ```gdscript
   _ending_outcome_overlay = EndingOutcomeOverlayScript.new()
   add_child(_ending_outcome_overlay)
   _ending_outcome_overlay.closed.connect(_on_ending_outcome_closed)
   ```
4. **找到 `_on_final_ceremony_choice`（grep `func _on_final_ceremony_choice`）**，在它末尾、`_show_run_summary()` **之前** 调：
   ```gdscript
   MetaManager.record_ending(choice_id)
   MetaManager.save_meta()
   if is_instance_valid(_ending_outcome_overlay):
       _ending_outcome_overlay.show_outcome(choice_id, _current_layer)
       return                # 等 _on_ending_outcome_closed 再走 summary
   _show_run_summary()         # 兜底：overlay 缺失时仍走旧路径
   ```
5. 新增：
   ```gdscript
   func _on_ending_outcome_closed() -> void:
       if is_instance_valid(_ending_outcome_overlay):
           _ending_outcome_overlay.hide_overlay()
       _show_run_summary()
   ```

### 验收

1. 集齐证据 → 通信终端通过 → ceremony 三选一：
   - 选 `stop_signal` → 看到 credits 文本 → 按「返回主菜单」 → 走 run_summary → 回主菜单。`meta.json` 中 `endings_seen` 含 `stop_signal`。
   - 选 `message_only` → 输入「测试留言」→ 提交 → 重启游戏，再次到此画面，历史栏可见上局留言。
   - 选 `fake_success` → 文本谢幕 → 回主菜单。
2. ESC 在 outcome overlay 期间不会让游戏崩。

### 风险
- `_on_final_ceremony_choice` 实际实现可能不是该名字。grep 时同时匹配 `ceremony_choice_made`。
- 不要在 outcome overlay 里 free 自己 — 由 main.gd 的 `_on_run_summary_closed` → `GameManager.go_to_main_menu()` 整体清场。

---

## 完成后清单

- [ ] 任务 1：`evidence.json` + `EvidenceData` autoload 注册 + `_spawn_evidence_pickups()` + `_on_resource_collected` 识别 evidence + 删除 placeholder 写入。
- [ ] 任务 2：`BackpackUI` 加 TabBar + 档案视图。
- [ ] 任务 3：`MetaManager.message_wall` + `EndingOutcomeOverlay` + main.gd 接入。
- [ ] grep 验证：每个新文件 `class_name`/`const`/`func` 没有重复行。
  ```bash
  grep -c 'extends Node' game/scripts/autoload/evidence_data.gd     # 1
  grep -c 'func _on_terminal_strike' game/scripts/main.gd           # 1
  grep -c 'placeholder_run_' game/scripts/main.gd                   # 0
  ```
- [ ] 删 `meta.json` 跑一次完整流程，三个结局都触达一次。

---

## 给执行模型的提示

- **遇到 "String to replace not found" 不要重试**，先用 `Read` 看文件最新状态再决定。
- **多次连续 Edit 落到同一区域时**：可能上一轮已生效，立即 grep 验证再决定。
- **不要重新格式化** main.gd 已有代码（缩进、空行）。只在指定行附近做最小改动。
- 完成后用一段话总结改了哪些文件、新增哪些 API，让用户审计。
