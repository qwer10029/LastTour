# 通信终端（CommunicationTerminal）实施计划

## 目标
按技术设计 §7.6 / §7.7 / §9.4 实现 `communication_terminal.tscn`，替换当前到顶时直接进入 `_begin_final_ceremony()` 的流程。该终端是结局触发器：

- **首次到顶**：举报选择 → CAPTCHA → 验证失败 → "被击毙"，本局以失败收场，但本局已收集的证据写入 Meta。
- **再次到顶且证据足够**：同样的 1~3 阶段 → 验证通过 → 权限移交 → 触发现有的归档仪式 + 三选一。

## 现状摘要
- [main.gd:573-577](game/scripts/main.gd#L573-L577) 修电梯到顶后直接调 `_begin_final_ceremony()` → [run_end_overlay.gd](game/scripts/ui/run_end_overlay.gd) 显示 `RunEndingDefs.TRUTH_REVEAL_TEXT` + 三选一。
- 没有 Meta 持久化（只有 `SaveManager` 的单局 `run_save.json`），也没有证据系统。
- `RunEndingDefs.FINAL_CHOICES` 已就位，可直接复用。

## 范围划分（本次只做 MVP）
本次只交付通信终端场景与流程闭环；证据系统先做最小桩，避免范围爆炸：

**做：**
1. `communication_terminal.tscn` + `communication_terminal.gd`：完整 UI 与状态机。
2. `meta_manager.gd` autoload：跨局存档（`user://meta.json`），持久化 `evidence_collected` 与 `management_rights_transferred`。
3. 在 `main.gd` 顶层电梯修复完成处插入终端流程，替代直接调用归档仪式。
4. 证据写入桩：本次将"是否收集到足够证据"以 Meta 中的 `evidence_collected` 数组判定，阈值 `EVIDENCE_THRESHOLD_FOR_TRANSFER = 3`（可配置）。本次不实现拾取式证据收集（§7.8），改为提供调试入口 + 一个临时规则：每次首次到顶失败时往 Meta 写入 1 条占位证据，使第 4 次进入即可触发权限移交。后续做 §7.8 时替换该规则。

**不做（留待后续）：**
- §7.8 完整证据拾取/资源点投放。
- 背包档案库标签页。
- 留言墙 / credits 场景。

## 文件改动清单

### 新增
- [game/scenes/communication_terminal.tscn](game/scenes/communication_terminal.tscn) — `CanvasLayer` 根，参考 [run_end_overlay.gd](game/scripts/ui/run_end_overlay.gd) 的纯代码 UI 风格（无 .tscn 节点也可，但本场景元素较多，建议做成 `.tscn` + 脚本绑定）。
- [game/scripts/ui/communication_terminal.gd](game/scripts/ui/communication_terminal.gd) — 状态机 + UI 控制。
- [game/scripts/autoload/meta_manager.gd](game/scripts/autoload/meta_manager.gd) — 跨局 Meta 存档。

### 修改
- [game/project.godot](game/project.godot) — 注册 `MetaManager` autoload。
- [game/scripts/main.gd](game/scripts/main.gd)：
  - 修电梯到顶后改为 `_open_communication_terminal()`，而非直接 `_begin_final_ceremony()`。
  - 新增 `_communication_terminal` 实例化与信号连接。
  - 处理两类终端结束信号：`strike_completed`（→ run end，reason="strike"，写 Meta 占位证据）/ `transfer_completed`（→ 调原 `_begin_final_ceremony()`）。
- [game/scripts/run_ending_defs.gd](game/scripts/run_ending_defs.gd) — 增加终端用的文案常量（举报两个选项、CAPTCHA 失败/通过、击毙、权限移交）。

## 通信终端状态机

```
DISPLAY_INTRO
  ↓ (用户点击「继续」)
REPORT_CHOICE          // "地表宜居" / "地表不宜" — 虚拟选择，不影响后续
  ↓
CAPTCHA                // 拖动滑块至右端
  ↓
VERIFY                 // 计算 evidence_count >= THRESHOLD
  ↓                       ↓
STRIKE (失败)         TRANSFER (成功)
  ↓                       ↓
emit strike_completed  emit transfer_completed
```

各阶段单一面板，复用同一个 `Label` + 动态控件区，按 phase 切换。

## CommunicationTerminal API

```gdscript
extends CanvasLayer
signal strike_completed       # 走失败结局
signal transfer_completed     # 走真相揭示 + 三选一

func start_flow(evidence_count: int, threshold: int) -> void
```

## MetaManager API

```gdscript
extends Node
const META_PATH := "user://meta.json"
const EVIDENCE_THRESHOLD_FOR_TRANSFER := 3

var evidence_collected: Array[String] = []
var management_rights_transferred: bool = false
var endings_seen: Array[String] = []

func load_meta() -> void
func save_meta() -> void
func add_evidence(id: String) -> bool
func has_enough_evidence() -> bool
func record_ending(choice_id: String) -> void
```

`_ready()` 时自动 `load_meta()`。

## main.gd 接入点

替换 [main.gd:573-577](game/scripts/main.gd#L573-L577)：
```gdscript
if _elevator_repair_progress >= _current_repair_cost():
    if _current_layer >= total_layers:
        _open_communication_terminal()   # 原: _begin_final_ceremony()
    else:
        _advance_layer()
```

新增：
```gdscript
func _open_communication_terminal() -> void:
    _freeze_run_for_end()  # 复用现有冻结逻辑
    _communication_terminal.start_flow(
        MetaManager.evidence_collected.size(),
        MetaManager.EVIDENCE_THRESHOLD_FOR_TRANSFER
    )

func _on_terminal_strike() -> void:
    MetaManager.add_evidence("placeholder_run_%d" % Time.get_unix_time_from_system())  # 临时桩
    MetaManager.save_meta()
    _run_ended = true
    _run_end_reason = "strike"
    _show_run_summary()

func _on_terminal_transfer() -> void:
    MetaManager.management_rights_transferred = true
    MetaManager.save_meta()
    _begin_final_ceremony()    # 复用现有归档仪式 + 三选一
```

`_run_end_reason` 增加 `"strike"` 分支到 [main.gd:879-887](game/scripts/main.gd#L879-L887) 的 title 选择 与 [main.gd:891-929](game/scripts/main.gd#L891-L929) 的 summary 文案。

## 测试 / 验收路径

1. 删除 `user://meta.json` → 启动 → 通关到顶 → 终端首次流程 → 击毙结算（标题：本局结束 · 通信终端击毙）。重复 3 次后第 4 次到顶应触发权限移交 → 真相揭示 → 三选一 → 真结局结算。
2. CAPTCHA 滑块拖动可完成且没有死锁；选择「地表宜居/不宜」均不影响后续。
3. 关闭再启动游戏，Meta 中 `evidence_collected` 数量持久。
4. 中途 ESC 暂停在终端阶段不应出问题（终端 `process_mode = ALWAYS`，参考 [run_end_overlay.gd:19](game/scripts/ui/run_end_overlay.gd#L19)）。

## 风险
- **Meta 存档版本管理**：本次先不做迁移逻辑，`save_meta()` 写入 `version: 1`，`load_meta()` 版本不符则忽略并重置。
- **临时证据桩污染玩家存档**：用明显前缀 `placeholder_run_*`，§7.8 落地时一次性清理。
- **CAPTCHA 占位**：用最简单的水平拖动到右端即可，不做图形识别。
