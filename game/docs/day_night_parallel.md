# 昼夜系统 · 两人并行开发分工

## 模块边界

| 负责人建议 | 文件 / 场景 | 职责 |
|-----------|------------|------|
| **队友 A · 白天** | `scripts/systems/time_system.gd`（仅 DAY/EVENING 段） | 白天计时、傍晚提醒、探索是否允许 |
| **队友 A · 白天** | `scripts/main.gd` 中 `_process_day_exploration` 相关 | 驾驶/步行/路口、燃料、地图 |
| **队友 A · 白天** | `scripts/ui/time_hud.gd`、`evening_notice.gd` | 时钟 HUD、傍晚横幅文案 |
| **队友 B · 夜晚** | `scripts/night_td/night_td_controller.gd` | 塔防流程、敌波、交互结算 |
| **队友 B · 夜晚** | `scripts/night_td/night_td_field.gd` | 俯视图网格、放置判定 |
| **队友 B · 夜晚** | `scripts/night_td/night_td_hud.gd` | 背包设施 UI |
| **队友 B · 夜晚** | `scripts/systems/night_defense_system.gd` | 与 main 的会话桥接 |

**集成点（少改对方文件）**

- `TimeSystem` 信号：`evening_warning_triggered`、`night_setup_started`、`night_resolved`、`day_started`
- `NightDefenseSystem.confirm_defense()` → 返回 `Dictionary`，由 `main.gd` 扣资源后调用 `TimeSystem.begin_night_resolve()`
- 不要在 `TimeSystem` 里写布防逻辑；不要在 `NightDefenseSystem` 里写探索移动

## 阶段流转

```
白天(DAY) → 傍晚(EVENING，横幅提醒) → 夜晚·塔防(俯视图布防→接敌→结算) → 夜晚·结算(NIGHT_RESOLVE) → 下一天白天
```

塔防内：`PLACE(默认180秒)` → `COMBAT(敌波与防线交互)` → `RESULT(确认后回 main)`

## 并行时推荐顺序

1. A 先保证 `is_exploration_allowed()` 为 true 时现有探索能玩。
2. B 在 `night_camp_panel` 上独立做按钮与 `confirm_defense` 结算文案。
3. 联调：傍晚是否弹出 `evening_notice`；入夜是否隐藏探索键、显示营地面板。
4. 共同在 `main.gd` 的 `_apply_night_result` 里对齐资源扣除规则。

## 可调参数（编辑器 Main 节点下 Systems/TimeSystem）

- `day_duration_sec`：一天总时长（默认 90 秒）
- `evening_warning_sec`：傍晚提醒持续时长（默认 25 秒）
