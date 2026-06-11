# 音乐状态与待生成清单（Part D）

## 结论
`MusicManager`（autoload）已完整，11 个 cue 槽位齐全，所有调用点经审计触发正确。
你点名的 4 首已全部接好线，其中 2 首已是你提供的真曲，2 首仍是占位曲待你替换。

## 现状逐曲

| cue | 文件 | 时长 | 状态 | 触发场景（已验证） |
|---|---|---|---|---|
| `day_exploration` | day_exploration.mp3 | 36s | **真曲（你提供）** | 白天探索：开局、从夜晚/终端返回白天 |
| `night_combat` | night_combat.mp3 | 32s | **真曲（你提供）** | 夜晚塔防战斗阶段开始 |
| `terminal` | terminal.mp3 | 28s | **占位/可重生成** ← 待确认 | 顶层跟随终端指令 / 通讯终端开启（你说的"被开枪"段） |
| `truth_reveal` | truth_reveal.mp3 | 34s | **占位/可重生成** ← 待确认 | `_begin_final_ceremony`：知晓真相、玩家掌控终端 |
| `night_setup` | night_setup.wav | 28s | 占位 | 夜晚布防准备阶段 |
| `menu_main` | menu_main.wav | 32s | 占位 | 主菜单 |
| `menu_select` | menu_select.wav | 24s | 占位 | 难度/分队选择、加载 |
| `opening_prologue` | opening_prologue.wav | 32s | 占位 | 开场序章 |
| `evening_warning` | evening_warning.wav | 7s | 占位（stinger） | 黄昏预警短提示 |
| `final_choice` | final_choice.wav | 32s | 占位 | 最终结局选择 |
| `run_reset` | run_reset.wav | 6.5s | 占位（stinger） | 轮回重置短提示 |

## 你要生成的 2 首（直接替换同名文件即可，无需改代码）

1. **`terminal.mp3`** —「跟随终端指令 / 顶层被开枪」
   - 情绪：冷峻、机械、被支配感；克制的合成低频脉冲 + 滴答终端音，
     暗藏不安。不要旋律性太强——这是"听命于机器"的段落。
   - 时长 ≥ 28s 可循环。

2. **`truth_reveal.mp3`** —「知晓一切、夺回终端控制」
   - 情绪：从压抑转向清明/释然，带一丝悲怆的觉醒感；可由稀疏钢琴/弦乐起，
     渐入温暖。这是全剧情感支点。
   - 时长 ≥ 34s 可循环。

## 建议新增（可选，提升完成度；需要我加 cue 槽位时告诉我）

- **`boss_thunder`** — 不败之盾-雷霆 Boss 战（现复用 night_combat，可专曲）。
  紧张、高压、金属质感打击乐。
- **`elevator_ascend`** — 修好电梯、上升到新楼层的过场（现无专属音乐）。
  短促的上行 sting，带希望感。8-12s。
- 其余占位曲（menu_main/menu_select/opening_prologue/night_setup/final_choice/
  evening_warning/run_reset）若想统一音乐风格，也可逐一替换；它们能正常播放，
  替换是锦上添花，非必需。

替换方式：把生成好的音频命名为上表的文件名/扩展名，覆盖 `game/assets/music/` 下同名文件，
重新用编辑器导入一次即可（代码与槽位都已就绪）。

生成提示词：见 `docs/music-generation-prompts.md`。该文件按 cue 提供可直接复制到音乐生成器的英文提示词，
并标明当前 `MusicManager` 使用的文件名/扩展名。
