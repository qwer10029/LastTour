class_name RoadRenderSettings
extends Resource

## 在 Godot 编辑器选中 Main 节点 → 检查器 → Road Render Settings 可调。
## 运行中按 F9 打开实时调节面板。

@export_group("路口整体")
@export_range(0.75, 1.1, 0.01) var junction_scale_inset: float = 0.94
@export_range(150.0, 280.0, 1.0) var cross_arm_tex_width: float = 213.0
@export_range(60.0, 220.0, 1.0) var cross_arm_tex_half_length: float = 113.0
@export_range(0.75, 1.45, 0.01) var cross_trim_inset: float = 1.05
@export_range(0.35, 0.55, 0.01) var segment_trim_max_frac: float = 0.50
@export_range(0.90, 1.50, 0.01) var corner_trim_extra: float = 1.22
@export_range(0.90, 1.50, 0.01) var t_junction_trim_extra: float = 1.10

@export_group("分类型微调")
@export_range(0.75, 1.15, 0.01) var corner_scale_inset: float = 0.75
## 四种拐角朝向各自偏移（世界坐标），互不影响
@export_range(-180.0, 180.0, 1.0) var corner_offset_rd_x: float = 27.0
@export_range(-180.0, 180.0, 1.0) var corner_offset_rd_y: float = 29.0
@export_range(-180.0, 180.0, 1.0) var corner_offset_dl_x: float = -27.0
@export_range(-180.0, 180.0, 1.0) var corner_offset_dl_y: float = 25.0
@export_range(-180.0, 180.0, 1.0) var corner_offset_lu_x: float = -29.0
@export_range(-180.0, 180.0, 1.0) var corner_offset_lu_y: float = -30.0
@export_range(-180.0, 180.0, 1.0) var corner_offset_ur_x: float = 30.0
@export_range(-180.0, 180.0, 1.0) var corner_offset_ur_y: float = -29.0
@export_range(0.75, 1.35, 0.01) var t_junction_scale_inset: float = 0.75
@export_range(-180.0, 180.0, 1.0) var t_junction_offset_x: float = 0.0
@export_range(-180.0, 180.0, 1.0) var t_junction_offset_y: float = 0.0
@export_range(-180.0, 180.0, 1.0) var cross_offset_x: float = 0.0
@export_range(-180.0, 180.0, 1.0) var cross_offset_y: float = 0.0

@export_group("高级")
@export_range(256.0, 1024.0, 1.0) var junction_ref_tex_size: float = 512.0  ## 保留兼容，当前缩放已统一用十字基准
