# 开场前情提要 · AI 绘图提示词

## 游戏中已接入（4 张 CG）

| 文件 | 场景 | 旁白要点 |
|------|------|----------|
| `startpicture1.png` | 大战后的废墟城市 | 大战摧毁地表；人类退守地下，仍想确认地表是否还能居住 |
| `startpicture2.png` | 地下昆仑指挥厅 | 昆仑计划：从底层逐层向上勘探、修电梯、回报地下；指挥部仍在运转 |
| `startpicture3.png` | 成为勘探志愿者 | 自愿加入；装备与勘探车就绪；穿过舱门踏上第一层 |
| `startpicture4.png` | 第一层工业废土（背影） | 昼夜探索与回车布防；逐层向上；记录并汇报给地下指挥部 |

完整旁白见 `game/scripts/opening_prologue_defs.gd`。

流程：**主菜单 → 新游戏 → 前情提要 → 选难度 → 选分队 → 开局**。旁白与图片定义见 `game/scripts/opening_prologue_defs.gd`。

---

> **叙事前提（玩家开局所知）**  
> 玩家记忆中被植入的是「官方叙事」：自己是**自愿**为全人类走上地表的勘探志愿者；地下指挥部仍在运作，任务是逐层向上、修复电梯、搜集资源，并把地表宜居性汇报给地下。  
> **开场不要揭示**：地下人类已灭绝、玩家是克隆人、程序无人值守循环派遣、地表无其他人类。

## 出图规格（原型与正式同一套）

| 项目 | 约定 |
|------|------|
| **比例** | **16 : 9**（PC 全屏开场） |
| **分辨率** | **1920 × 1080**（只出这一套，原型接 Godot 与正式发布共用，不维护 720p 第二套） |
| **构图** | 主体居中；底部约 15%～20% 预留给旁白条，关键信息勿贴边 |
| **导出** | PNG；文件名建议 `prologue_01.png` … `prologue_05.png` |
| **地表军用残骸** | **仅第 1 页**加入；用远景弱化，勿抢主体。第 2～5 页**不要**坦克/飞机残骸 |

**第 1 页专用短语（远景弱化）**

```text
a few distant tank and aircraft silhouettes on the horizon, subtle war remnants, low detail background
```

**工具参数（生成时设置，与 prompt 配合）**

- 画图工具选 **2048×1152**（16:9），导出后缩放到 **1920×1080** 放进游戏  
- Midjourney：`--ar 16:9`  
- Stable Diffusion：Width `2048`， Height `1152`（或 `1920` × `1080`）

**统一画风后缀**（每条 prompt 末尾已包含，批量生成时可整段复制）：

```text
, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone
```

### 通用词汇对照（每条 prompt 末尾都会出现）

| 英文 | 中文 |
|------|------|
| full screen game CG | 全屏游戏过场插画 |
| aspect ratio 16:9, 1920x1080 | 宽高比 16:9，目标分辨率 1920×1080 |
| 2D game intro panel | 2D 游戏开场分镜风格 |
| cold muted post-apocalyptic palette | 冷色、低饱和的末世配色 |
| cinematic composition | 电影感构图 |
| no text, no watermark | 画面上不要文字、不要水印 |
| lonely hopeful tone | 孤独但带希望，不要太绝望血腥 |

---

## 5 页完整版

### 第 1 页｜大战之后

**旁白**  
大战结束了。人类退入地下，但还没有放弃地表。

**Prompt**

```text
wide ruined vertical city after global war, dust and broken highways, a few distant tank and aircraft silhouettes on the horizon, subtle war remnants, distant intact radio tower, grey sky, no people visible, hopeful ruin, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone
```

---

### 第 2 页｜地下据点

**旁白**  
地下最后的大型据点里，「昆仑」勘探计划正在准备启动。

**Prompt**

```text
underground command bunker, active monitors showing layered city map, silhouettes of staff at consoles, clean sci-fi lighting, organized not abandoned, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone
```

---

### 第 3 页｜成为勘探志愿者

**旁白**  
你成为了昆仑计划的地表勘探志愿者。

**Prompt**

```text
volunteer surface survey explorer certified, wearing survey suit and volunteer badge, calm determined expression, standing in underground bunker ready for Kunlun surface mission, facing corridor light toward surface deployment, organized sci-fi lighting, not horror clone lab, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone
```

---

### 第 4 页｜第一层废土

**旁白**  
第一层：工业废墟带。环境恶劣，但并非全无希望——这里曾是人类生活过的地方。

**Prompt**

```text
layer-1 industrial ruins, explorer seen from behind back view silhouette holding scanner near survey truck, collapsed factories, survey not despair, single figure mission-focused, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone
```

---

### 第 5 页｜向上的路

**旁白**  
每一层都有战损的电梯。修好它，才能把发现带给上一层、最终带给等待消息的地下。

**Prompt**

```text
vertical five-layer ruined megacity cutaway, damaged elevator shaft, explorer repairing lift with tools and spare parts, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone
```

**收尾小字（可选，叠在第 5 页末尾）**  
昆仑计划 · 地表勘探

---

## Prompt 中英文对照（5 页）

> 下列「画面关键词」不含文末统一画风后缀；后缀含义见上文「通用词汇对照」。

### 第 1 页｜大战之后

| 英文 | 中文 |
|------|------|
| wide ruined vertical city after global war | 全球大战后的垂直废墟城市（远景） |
| dust and broken highways | 尘土、断裂的公路 |
| a few distant tank and aircraft silhouettes on the horizon | 地平线上少量坦克、飞机剪影（远景弱化） |
| subtle war remnants | 隐约的战争遗迹感 |
| distant intact radio tower | 远处一座仍完好的通讯塔 |
| grey sky, no people visible | 灰色天空，看不见人 |
| hopeful ruin | 破败中仍带一点希望 |

**一句话**：战后废城全景，远景有军用剪影，仍有一丝「还没放弃」的感觉。

---

### 第 2 页｜地下据点

| 英文 | 中文 |
|------|------|
| underground command bunker | 地下指挥掩体 |
| active monitors showing layered city map | 亮着的显示器，显示分层城市地图 |
| silhouettes of staff at consoles | 操作台前工作人员剪影 |
| clean sci-fi lighting | 干净、偏科幻的灯光 |
| organized not abandoned | 整齐、仍在运作，不是荒废遗弃 |

**一句话**：地下指挥部仍在运转，有人在值班，计划正在准备。

---

### 第 3 页｜成为勘探志愿者

| 英文 | 中文 |
|------|------|
| volunteer surface survey explorer certified | 已认证的地表勘探志愿者 |
| wearing survey suit and volunteer badge | 身穿勘探服、佩戴志愿者标识 |
| calm determined expression | 平静而坚定的表情 |
| standing in underground bunker ready for Kunlun surface mission | 站在地下掩体中，准备执行昆仑地表任务 |
| facing corridor light toward surface deployment | 面向通往地表投放区的通道光 |
| organized sci-fi lighting | 有序、偏科幻的灯光 |
| not horror clone lab | **不要**画成恐怖克隆实验室 |

**一句话**：你就是勘探志愿者——着装就绪，即将奔赴地表。（本页无军用残骸）

---

### 第 4 页｜第一层废土

| 英文 | 中文 |
|------|------|
| layer-1 industrial ruins | 第一层工业废墟 |
| explorer seen from behind back view silhouette holding scanner near survey truck | 勘探者**背影**，手持扫描仪，在勘探车旁 |
| collapsed factories | 倒塌厂房 |
| survey not despair | 在勘察记录，氛围不是绝望 |
| single figure mission-focused | 单人构图，突出执行任务 |

**一句话**：工业废墟里，勘探者**背影**朝向废墟与勘探车，独自勘察。（本页无坦克/飞机残骸）

---

### 第 5 页｜向上的路

| 英文 | 中文 |
|------|------|
| vertical five-layer ruined megacity cutaway | 五层废墟城市竖剖面 |
| damaged elevator shaft | 损毁的电梯井 |
| explorer repairing lift with tools and spare parts | 勘探者用工具与零件修理电梯 |

**一句话**：城市剖面里修电梯，象征逐层向上，开场在此收束。（本页无军用残骸）

---

## 纯英文批量粘贴（5 条，一行一条）

```text
wide ruined vertical city after global war, dust and broken highways, a few distant tank and aircraft silhouettes on the horizon, subtle war remnants, distant intact radio tower, grey sky, no people visible, hopeful ruin, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone

underground command bunker, active monitors showing layered city map, silhouettes of staff at consoles, clean sci-fi lighting, organized not abandoned, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone

volunteer surface survey explorer certified, wearing survey suit and volunteer badge, calm determined expression, standing in underground bunker ready for Kunlun surface mission, facing corridor light toward surface deployment, organized sci-fi lighting, not horror clone lab, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone

layer-1 industrial ruins, explorer seen from behind back view silhouette holding scanner near survey truck, collapsed factories, survey not despair, single figure mission-focused, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone

vertical five-layer ruined megacity cutaway, damaged elevator shaft, explorer repairing lift with tools and spare parts, full screen game CG, aspect ratio 16:9, 1920x1080, 2D game intro panel, cold muted post-apocalyptic palette, cinematic composition, no text, no watermark, lonely hopeful tone
```

---

## 开场刻意不剧透（留给游玩 / 多局）

- 地下人类已灭绝、程序无人值守  
- 玩家是克隆人、循环派遣  
- 地表无其他人类、通信终端击毙与权限移交  
- 三选一终局（终止信号 / 只留言 / 伪造成功）
