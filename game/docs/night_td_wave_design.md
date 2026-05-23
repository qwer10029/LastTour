# 夜晚塔防 · 波次与路线设计（明日方舟式）

用 **JSON** 描述「刷怪表 + 路线 + 站场时间」，无需改代码即可调关卡。运行时由 `NightTdWavePlan` 加载、`NightTdWaveScheduler` 按时间表刷怪，`NightTdController` 让敌人沿路线移动并在节点站场。

## 快速开始

1. 复制示例：`game/data/night_td/waves/night_wave_demo.json`
2. 在 Godot 中选中 **NightTd** 节点（`NightTdController`）：
   - `use_wave_plan` = 开启
   - `wave_plan_path` = `res://data/night_td/waves/你的关卡.json`
   - `debug_draw_routes` = 开启（布防阶段会画红线、出生点、站场秒数）
3. 运行游戏，进入夜晚塔防，按表格调整数值后重进关卡验证。

## 格子坐标（与明日方舟编辑器一致）

| 规则 | 说明 |
|------|------|
| 列 | 数字 **1–9** 表示从左到右，内部为 `列号 - 1` |
| 行 | 字母 **A–F**，**A = 画面最下一行**，F = 最上一行 |
| 写法 | 如 `F8` = 第 F 行、第 8 列 |

> 当前战场网格为 14×10，超出范围的格子会被 **夹到边界内**。设计时尽量把路线写在可玩区域内。

## JSON 结构总览

```json
{
  "name": "关卡名",
  "spawn_points": { "组ID": ["F8", "D8"] },
  "routes": {
    "route_id": {
      "label": "备注",
      "waypoints": [
        { "cell": "F8", "standby": 0 },
        { "cell": "F7", "standby": 5 }
      ]
    }
  },
  "waves": [
    {
      "id": 1,
      "trigger": "combat_start",
      "entries": [ { ...一条刷怪记录... } ]
    }
  ]
}
```

### `entries` 字段（对应明日方舟表）

| 字段 | 含义 | 示例 |
|------|------|------|
| `enemy` | 敌人类型 ID（见 `NightTdDefs`） | `"drone"` / `"scout"` |
| `count` | **数量** | `4` |
| `spawn_interval` | 同一条目内，每只之间的 **间隔（秒）** | `1.0` |
| `pre_delay` | 本条目前 **延迟出现（秒）** | `6.0` |
| `move_speed` | **移动速度（像素/秒）**；≤0 则用敌人默认值 | `58` |
| `route_id` | 绑定的路线 ID | `"route_f_line"` |
| `spawn_point` | 出生格子标签，如 `"F8"` | 留空则用路线首点 |

### `waypoints` 站场

- `standby` / `standby_sec`：到达该格后 **停留秒数**；`0` = 不停留。
- 运行时上限 **5 秒**（`NightTdWavePlan.MAX_STANDBY_SEC`），JSON 里写再大也会自动压到 5。
- 路线走完后，敌人会 **直奔车辆**（与原先逻辑一致）。

## 行为说明

1. **布防阶段**：若 `debug_draw_routes` 为真，地图上会显示路线折线、格子标签、站场时间、红色出生框。
2. **接敌**：调度器按 `spawn_at` 依次刷怪；HUD 显示「已刷 / 总数 / 待刷」。
3. **移动**：沿 `waypoints` 顺序移动；到达且 `standby > 0` 时原地等待（仍受路障减速、陷阱影响）。
4. **难度**：`difficulty >= 2` 时，每条 `count` +1，且自定义移速 ×1.08（可在 `night_td_wave_scheduler.gd` 调整）。

## 关闭数据驱动（回退旧逻辑）

`NightTdController.use_wave_plan = false` 时，仍使用代码内 `_build_wave_queue()` 随机四边刷怪、直线冲向车辆。

## 相关脚本

| 文件 | 作用 |
|------|------|
| `scripts/night_td/night_td_wave_design.gd` | 解析 JSON、格子标签、`NightTdWavePlan` |
| `scripts/night_td/night_td_wave_scheduler.gd` | 展开波次表、按时间 `tick` |
| `scripts/night_td/night_td_controller.gd` | 刷怪、路径移动、站场 |
| `scripts/night_td/night_td_field.gd` | 路线/出生点调试绘制 |
| `data/night_td/waves/*.json` | 关卡数据 |

## 设计建议

- 一条 `route_id` 可被多条 `entries` 复用（不同敌人、速度、数量）。
- 多出生点用 `spawn_points` 分组，单只怪用 `spawn_point` 指定具体格。
- 需要站场时一般写 **5** 即可；超过 5 秒会在加载时被截断。
- 改 JSON 后无需重编译，保存并重新进入塔防即可。
