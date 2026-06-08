# 美术素材替换指南

## 当前原型已用到的占位图

当前原型会优先读取同名 PNG，找不到时回退到 SVG。当前依赖的占位图是：

- `assets/dummy/player_dummy.png` / `assets/dummy/player_dummy.svg`
- `assets/dummy/resource_dummy.png` / `assets/dummy/resource_dummy.svg`
- `assets/sprites/vehicle_topdown.png`（全游戏统一俯视角车辆；`vehicle_dummy` 仅作缺失回退）

这三张图现在都是占位图，背景透明，足以验证移动、拾取和驾驶流程。

## 当前原型的替换规范

如果你先替换当前原型，建议保持以下规范：

- 画布尺寸：`32x32` 或 `96x48`
- 背景：透明
- 视角：玩家与资源用顶视角，车辆用侧视角
- 构图：主体居中，四边留 2-4 像素安全边距
- 输出：优先 PNG；如果保留当前脚本路径不变，也可以继续用 SVG

## 当前占位图与生成提示词

### 1. 玩家图标

文件名建议保持不变：`assets/dummy/player_dummy.png`

提示词：

```text
32x32 top-down 2D game sprite, a small blue vehicle/character icon, centered, transparent background, flat shading, clean silhouette, high contrast, no text, no watermark, minimal details, readable at tiny size
```

### 2. 资源图标

文件名建议保持不变：`assets/dummy/resource_dummy.png`

提示词：

```text
32x32 top-down 2D game pickup icon, a green resource crate or crystal, centered, transparent background, flat shading, clean silhouette, high contrast, no text, no watermark, minimal details, readable at tiny size
```

### 3. 车辆图标

文件名建议保持不变：`assets/dummy/vehicle_dummy.png`

提示词：

```text
96x48 side-view 2D game vehicle sprite, a rugged post-apocalyptic road vehicle, centered, transparent background, flat shading, strong silhouette, wheels visible, no text, no watermark, readable at medium size
```

## 完整游戏后续建议补齐的素材

下面这些是做成完整版本时更建议补上的实际素材。你可以按这个名字直接生成，再替换到工程里。

### 世界与场景

- `assets/tiles/interior/floor.png`：室内地面（整张铺满室内面板，无棋盘格）
- `assets/tiles/interior/obstacle.png`：室内障碍格
- `assets/sprites/loot/supplies.png`、`fuel.png`、`wood.png`、`parts.png`、`scrap.png`：物资拾取与背包图标
- `assets/tiles/ground_32.png`：城市废墟地面 tile
- `assets/tiles/road/road_cross.png`：四向十字路口
- `assets/tiles/road/road_t.png`：三岔路口（按连接方向旋转）
- `assets/tiles/road/road_corner.png`：拐角（两向连接）
- `assets/tiles/road/road_ns_segment.png` / `road_ew_segment.png`：直路（仅两向对向连接时不画路口贴图）
- `assets/tiles/wall_32.png`：障碍/墙体 tile
- `assets/tiles/elevator_32.png`：电梯装置 tile
- `assets/tiles/camp_32.png`：营地/夜晚据点 tile
- `assets/tiles/drive_skyline_32.png`：驾驶场景远景楼群剪影
- `assets/tiles/drive_road_32.png`：驾驶场景路面与车道线
- `assets/tiles/fog_black_32.png`：地图未探索黑雾遮罩

### 室外废墟装饰与路障（已实现程序化回退，有 PNG 后自动替换）

放入目录 `assets/sprites/props/`，**文件名须与下列一致**：

| 文件名 | 用途 |
|--------|------|
| `grass_clump.png` | 荒草堆（散落装饰） |
| `rock_small.png` | 小石块 |
| `rock_large.png` | 大岩石/碎石堆 |
| `dead_tree.png` | 枯树 |
| `rubble_pile.png` | 碎混凝土堆 |
| `wreck_tank.png` | 报废履带战车（路障） |
| `wreck_truck.png` | 报废军用卡车（路障） |
| `rubble_barricade.png` | 钢筋碎石路障 |

路障弹坑复用已有 `assets/tiles/road/road_crater.png`，无需重复绘制。

**统一规范**：64×64 或 96×96 画布；透明背景；2D 正俯视；低饱和冷灰/黄褐/暗绿；主体居中；四边留 4px 安全边距；无文字、无水印。

**grass_clump.png**

```text
64x64 top-down 2D game sprite, dry wasteland grass clump, muted olive and brown tones, post-apocalyptic ruined city ground, transparent background, flat pixel art, soft shadow at base, centered, readable at small size, no text, no watermark
```

**rock_small.png**

```text
64x64 top-down 2D game sprite, small scattered rocks on cracked dirt, grey and brown, transparent background, flat pixel art, centered cluster, post-apocalyptic wasteland, no text, no watermark
```

**rock_large.png**

```text
96x96 top-down 2D game sprite, large rubble rock pile, broken concrete and stones, muted grey brown, transparent background, flat pixel art, irregular silhouette, post-apocalyptic war ruins, no text, no watermark
```

**dead_tree.png**

```text
96x96 top-down 2D game sprite, leafless dead tree top-down view, bare branches, dark brown trunk, wasteland atmosphere, transparent background, flat pixel art, centered, post-apocalyptic, no text, no watermark
```

**rubble_pile.png**

```text
96x96 top-down 2D game sprite, pile of broken concrete rubble and rebar, war ruins debris, grey and rust accents, transparent background, flat pixel art, centered, post-apocalyptic, no text, no watermark
```

**wreck_tank.png**（路障，较大）

```text
128x96 top-down 2D game sprite, destroyed rusted tank hull without turret, burnt olive drab metal, tracks visible, war wreck on cracked road, transparent background, flat pixel art, strong silhouette, post-apocalyptic military ruins, no text, no watermark
```

**wreck_truck.png**（路障）

```text
128x96 top-down 2D game sprite, wrecked military supply truck top-down, rusted cab and cargo bed, windows broken, on ruined asphalt, transparent background, flat pixel art, post-apocalyptic, no text, no watermark
```

**rubble_barricade.png**（路障）

```text
128x96 top-down 2D game sprite, road barricade made of concrete slabs rebar and sandbags, blocks a lane, war ruins, grey brown muted colors, transparent background, flat pixel art, centered, post-apocalyptic, no text, no watermark
```

驾驶场景提示词模板：

```text
32x32 or seamless 2D background tile, ruined city skyline silhouette, side-view road environment, transparent edges or seamless tiling, muted colors, low contrast background layer, no text, no watermark
```

地图黑雾提示词模板：

```text
32x32 transparent overlay tile, deep black fog-of-war mask for strategy game map, soft edge, no text, no watermark, tileable or flat overlay, designed to hide unexplored map cells
```

### 角色与单位

- `assets/sprites/player_vehicle.png`：主角车辆/移动载具
- `assets/sprites/enemy_drone.png`：巡逻无人机
- `assets/sprites/npc_robot.png`：档案管理机或机器人 NPC
- `assets/sprites/resource_pickup.png`：资源拾取物

提示词模板：

```text
2D top-down game sprite, centered character, transparent background, consistent line weight, clear silhouette, flat shading, readable at 64px or smaller, no text, no watermark, post-apocalyptic sci-fi style
```

车辆提示词模板：

```text
side-view 2D game vehicle sprite, post-apocalyptic truck or rover, transparent background, centered, flat shading, clear wheels and cabin silhouette, no text, no watermark, medium detail, readable at 96px wide
```

### UI 与图标

- `assets/ui/icon_fuel.png`
- `assets/ui/icon_hp.png`
- `assets/ui/icon_time.png`
- `assets/ui/icon_archive.png`
- `assets/ui/panel_terminal.png`
- `assets/ui/icon_map_marker.png`：地图当前位置标记
- `assets/ui/icon_elevator.png`：电梯提示符号

地图标记提示词模板：

```text
2D UI icon, red location marker for minimap, transparent background, simple readable silhouette, high contrast, no text, no watermark
```

通用 UI 提示词模板：

```text
2D game UI icon, transparent background, simple bold silhouette, high contrast, small size readability, matching a muted sci-fi post-apocalyptic interface, no text, no watermark
```

## 统一生成规范

- 同一批素材保持同样的光照方向和描边风格
- 角色类素材尽量使用俯视或斜 3/4 俯视，不要混用横版视角
- Tile 类素材要保证可拼接，边缘不要出现主体
- UI 类素材优先做成 1:1 或 2:1 的干净图标，不要写字
- 颜色建议偏低饱和，和废墟、终末旅行主题一致
- 如果后面要无缝替换进 Godot，优先保持原文件名不变，或者同步改 scene 里的资源引用路径
# 美术素材替换指南

## 当前原型已用到的占位图

当前最小可玩原型只依赖这些图，代码会优先读取同名 PNG，找不到时回退到 SVG：

- `assets/dummy/player_dummy.png` 或 `assets/dummy/player_dummy.svg`
- `assets/dummy/resource_dummy.png` 或 `assets/dummy/resource_dummy.svg`
- `assets/dummy/vehicle_dummy.png` 或 `assets/dummy/vehicle_dummy.svg`

这三张图现在都是占位图，背景透明，足以验证移动、拾取和驾驶流程。

## 当前原型的替换规范

如果你先替换当前原型，建议保持以下规范：

- 画布尺寸：`32x32` 或 `96x48`
- 背景：透明
- 视角：玩家与资源用顶视角，车辆用侧视角
- 构图：主体居中，四边留 2-4 像素安全边距
- 输出：优先 PNG；如果保留当前脚本路径不变，也可以继续用 SVG

## 当前占位图与生成提示词

### 1. 玩家图标

文件名建议保持不变：`assets/dummy/player_dummy.png`

提示词：

```text
32x32 top-down 2D game sprite, a small blue vehicle or character icon, centered, transparent background, flat shading, clean silhouette, high contrast, no text, no watermark, minimal details, readable at tiny size
```

### 2. 资源图标

文件名建议保持不变：`assets/dummy/resource_dummy.png`

提示词：

```text
32x32 top-down 2D game pickup icon, a green resource crate or crystal, centered, transparent background, flat shading, clean silhouette, high contrast, no text, no watermark, minimal details, readable at tiny size
```

### 3. 车辆图标

文件名建议保持不变：`assets/dummy/vehicle_dummy.png`

提示词：

```text
96x48 side-view 2D game vehicle sprite, a rugged post-apocalyptic road vehicle, centered, transparent background, flat shading, strong silhouette, wheels visible, no text, no watermark, readable at medium size
```

## 完整游戏后续建议补齐的素材

下面这些是做成完整版本时更建议补上的实际素材。你可以按这个名字直接生成，再替换到工程里。

### 世界与场景

- `assets/tiles/interior/floor.png`：室内地面（整张铺满室内面板，无棋盘格）
- `assets/tiles/interior/obstacle.png`：室内障碍格
- `assets/sprites/loot/supplies.png`、`fuel.png`、`wood.png`、`parts.png`、`scrap.png`：物资拾取与背包图标
- `assets/tiles/ground_32.png`：城市废墟地面 tile
- `assets/tiles/road/road_cross.png`：四向十字路口
- `assets/tiles/road/road_t.png`：三岔路口（按连接方向旋转）
- `assets/tiles/road/road_corner.png`：拐角（两向连接）
- `assets/tiles/road/road_ns_segment.png` / `road_ew_segment.png`：直路（仅两向对向连接时不画路口贴图）
- `assets/tiles/wall_32.png`：障碍/墙体 tile
- `assets/tiles/elevator_32.png`：电梯装置 tile
- `assets/tiles/camp_32.png`：营地/夜晚据点 tile
- `assets/tiles/drive_skyline_32.png`：驾驶场景远景楼群剪影
- `assets/tiles/drive_road_32.png`：驾驶场景路面与车道线
- `assets/tiles/fog_black_32.png`：地图未探索黑雾遮罩

提示词模板：

```text
32x32 top-down 2D tile, post-apocalyptic ruined city ground, transparent or seamless edges, readable at game scale, flat shading, muted colors, no text, no watermark, designed for tilemap use
```

驾驶场景提示词模板：

```text
32x32 or seamless 2D background tile, ruined city skyline silhouette, side-view road environment, transparent edges or seamless tiling, muted colors, low contrast background layer, no text, no watermark
```

地图黑雾提示词模板：

```text
32x32 transparent overlay tile, deep black fog-of-war mask for strategy game map, soft edge, no text, no watermark, tileable or flat overlay, designed to hide unexplored map cells
```

### 角色与单位

- `assets/sprites/player_vehicle.png`：主角车辆/移动载具
- `assets/sprites/enemy_drone.png`：巡逻无人机
- `assets/sprites/npc_robot.png`：档案管理机或机器人 NPC
- `assets/sprites/resource_pickup.png`：资源拾取物

提示词模板：

```text
2D top-down game sprite, centered character, transparent background, consistent line weight, clear silhouette, flat shading, readable at 64px or smaller, no text, no watermark, post-apocalyptic sci-fi style
```

车辆提示词模板：

```text
side-view 2D game vehicle sprite, post-apocalyptic truck or rover, transparent background, centered, flat shading, clear wheels and cabin silhouette, no text, no watermark, medium detail, readable at 96px wide
```

### UI 与图标

- `assets/ui/icon_fuel.png`
- `assets/ui/icon_hp.png`
- `assets/ui/icon_time.png`
- `assets/ui/icon_archive.png`
- `assets/ui/panel_terminal.png`
- `assets/ui/icon_map_marker.png`：地图当前位置标记
- `assets/ui/icon_elevator.png`：电梯提示符号

提示词模板：

```text
2D game UI icon, transparent background, simple bold silhouette, high contrast, small size readability, matching a muted sci-fi post-apocalyptic interface, no text, no watermark
```

地图标记提示词模板：

```text
2D UI icon, red location marker for minimap, transparent background, simple readable silhouette, high contrast, no text, no watermark
```

## 统一生成规范

- 同一批素材保持同样的光照方向和描边风格
- 角色类素材尽量使用俯视或斜 3/4 俯视，不要混用横版视角
- Tile 类素材要保证可拼接，边缘不要出现主体
- UI 类素材优先做成 1:1 或 2:1 的干净图标，不要写字
- 颜色建议偏低饱和，和废墟、终末旅行主题一致
- 如果后面要无缝替换进 Godot，优先保持原文件名不变，或者同步改 scene 里的资源引用路径
