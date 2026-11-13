extends SceneTree
## 预烘焙夜间塔防精灵的抠图结果（离线执行，避免运行时逐像素 GDScript 处理）。
## Pre-bakes the alpha-keyed night TD tower/enemy sprites so the game never runs
## the per-pixel GDScript keying at runtime (it froze the first night load ~20s+).
##
## 生成 / bake:   godot --headless --path game --script res://tools/bake_night_td_sprites.gd
## 校验 / verify: godot --headless --path game --script res://tools/bake_night_td_sprites.gd -- --verify
##   (verify re-runs the original runtime keying and asserts the imported baked
##    textures are pixel-identical; run --import after baking first.)
## 修改源图后需重新烘焙。Re-run after changing any source sprite.

const ArtAssetLoaderScript := preload("res://scripts/art_asset_loader.gd")
const NightTdSpritesScript := preload("res://scripts/night_td/night_td_sprites.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var verify := OS.get_cmdline_user_args().has("--verify")
	var failures: Array[String] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NightTdSpritesScript.BAKED_DIR))
	for entry in NightTdSpritesScript.bake_sources():
		var source: String = entry["source"]
		var baked: String = entry["baked"]
		var t0 := Time.get_ticks_msec()
		# 与运行时完全相同的处理函数和参数 / exactly the runtime keying call.
		var keyed: Texture2D = ArtAssetLoaderScript.load_texture_loot_alpha_key(source)
		if keyed == null:
			failures.append("could not key %s" % source)
			continue
		var img := keyed.get_image()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		if verify:
			var baked_tex: Texture2D = load(baked) if ResourceLoader.exists(baked) else null
			if baked_tex == null:
				failures.append("missing baked texture %s" % baked)
				continue
			var baked_img := baked_tex.get_image()
			if baked_img.get_format() != Image.FORMAT_RGBA8:
				baked_img.convert(Image.FORMAT_RGBA8)
			if baked_img.get_size() != img.get_size() or baked_img.get_data() != img.get_data():
				failures.append("baked texture differs from runtime keying: %s" % baked)
			else:
				print("VERIFIED %s (%d ms)" % [baked, Time.get_ticks_msec() - t0])
		else:
			var err := img.save_png(ProjectSettings.globalize_path(baked))
			if err != OK:
				failures.append("save failed %s (%d)" % [baked, err])
			else:
				print("BAKED %s <- %s (%d ms)" % [baked, source, Time.get_ticks_msec() - t0])
	if failures.is_empty():
		print("NIGHT_TD_SPRITE_VERIFY_OK" if verify else "NIGHT_TD_SPRITE_BAKE_OK")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)
