---
name: "godot-model-asset-pipeline"
description: "Imports optimized model assets into this Godot project. Invoke when batch converting GLB/FBX/OBJ into models, prefabs, catalog entries, and bbox-compatible scenes."
---

# Godot Model Asset Pipeline

Use this skill when the user wants to bring one or more external model files into this DatasetGen Godot project as usable object assets.

This skill covers the complete project workflow:

- Batch import source models through Blender.
- Reduce mesh face count and shrink textures.
- Save compact `.blend` assets under `models/<category>/<asset_name>/`.
- Generate wrapper prefabs under `prefabs/<category>/`.
- Wire those prefabs into `resources/object_catalog.tres`.
- Keep prefab resources external by path instead of inlining mesh/material data.
- Validate Godot import and bbox generation.

Do not include manual size calibration in this workflow. If the user asks to adjust model scale, rotation, or offsets, handle that as a separate follow-up edit on the prefab model child nodes.

## Tooling

Use the Blender MCP server for Blender-side model processing.

Before calling any MCP tool, read the tool descriptor from:

`/Users/bytedance/.trae-cn/mcps/s_DatasetGen-d9c6cafd/solo_agent/mcp_blender/tools/`

The normal MCP sequence is:

1. Read `execute_blender_code.json`.
2. Optionally read `get_scene_info.json` to verify Blender connectivity.
3. Call `mcp_blender.execute_blender_code` with a small loader that executes:

`/Users/bytedance/Develop/DatasetGen/.trae/skills/godot-model-asset-pipeline/scripts/batch_optimize_blender_assets.py`

## Project Layout

Optimized model files must use:

```text
models/<category>/<asset_name>/<asset_name>.blend
models/<category>/<asset_name>/textures/<texture files>
```

Wrapper prefabs must use:

```text
prefabs/<category>/<singular_or_category>_<index>.tscn
```

Example for melon seeds:

```text
models/melonseeds/melonseeds1/melonseeds1.blend
models/melonseeds/melonseeds1/textures/texture_pbr_20250901.jpg
prefabs/melonseeds/melonseeds_1.tscn
```

## Naming Rules

When choosing names:

- Prefer explicit user input.
- If the source path parent folder matches a `models/` category, use that category.
- Otherwise inspect existing categories and ask only if ambiguous.
- Pick the next numeric asset directory by scanning siblings, such as `melonseeds1`, `melonseeds2`, then `melonseeds3`.
- For prefab filenames, follow the existing project style: `category_1.tscn`, `category_2.tscn`, or an established singular form if the category already uses one.

## Blender Optimization

Build an `ASSET_JOBS` list and inject it into the Blender script.

Each job must include:

```python
{
    "src": "/absolute/path/source.glb",
    "out_dir": "/Users/bytedance/Develop/DatasetGen/models/melonseeds/melonseeds1",
    "asset_name": "melonseeds1",
}
```

Optional fields:

```python
{
    "decimate_ratio": 0.1,
    "texture_max_edge": 1024,
    "jpeg_quality": 85,
    "normal_max_edge": 1024,
    "remove_lights_cameras": True
}
```

Default quality policy:

- Geometry: decimate to `0.1`.
- Base color and packed roughness/metallic textures: JPEG, quality `85`, max edge `1024`.
- Normal maps or alpha-linked textures: PNG, max edge `1024`, maximum compression.
- Save `.blend` with compression enabled.
- Externalize images using relative paths like `//textures/file.jpg`.
- Rename every mesh object with `_rigid` suffix so Godot can generate colliders from imported scene names.

Use this MCP loader pattern:

```python
ASSET_JOBS = [
    {
        "src": "/absolute/path/source.glb",
        "out_dir": "/Users/bytedance/Develop/DatasetGen/models/category/category1",
        "asset_name": "category1",
        "decimate_ratio": 0.1,
        "texture_max_edge": 1024,
        "normal_max_edge": 1024,
        "jpeg_quality": 85,
        "remove_lights_cameras": True,
    },
]

script_path = "/Users/bytedance/Develop/DatasetGen/.trae/skills/godot-model-asset-pipeline/scripts/batch_optimize_blender_assets.py"
namespace = {"ASSET_JOBS": ASSET_JOBS, "__file__": script_path}
with open(script_path, "r", encoding="utf-8") as handle:
    exec(compile(handle.read(), script_path, "exec"), namespace)
```

The script prints `DATASETGEN_BATCH_RESULT=...`. Capture and summarize:

- Output `.blend` paths.
- Original and final triangle counts.
- Actual reduction ratio.
- Mesh object names.
- Texture sizes and formats.
- Final `.blend` size and texture directory size.
- Any failed or skipped files.

## Prefab Generation

Generate one wrapper prefab per optimized `.blend`.

The prefab must use external resources by path, matching the project style. Do not inline mesh, material, shape, or imported scene data.

Use this structure:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://models/<category>/<asset_name>/<asset_name>.blend" id="1_model"]

[node name="<asset_name>" type="Node3D"]

[node name="<asset_name>_model" parent="." instance=ExtResource("1_model")]
```

Keep the wrapper root at the default transform. The root is what `RandomPlacer` moves, rotates, and randomly scales. The child model node is reserved for later user-driven calibration, such as scale, rotation, or offset changes. Do not set calibration transforms unless the user asks.

## Catalog Wiring

Wire generated prefabs into `resources/object_catalog.tres`.

Rules:

- Add `[ext_resource type="PackedScene" path="res://prefabs/<category>/<prefab>.tscn" id="scene_N"]` entries.
- Prefer path-only external resources for newly generated prefabs unless Godot has already produced a stable UID.
- Add the scenes to the matching `ObjectCategory.scenes`.
- Do not change category `class_id`, `label_name`, `is_unknown`, `enabled`, or `weight` unless the user explicitly asks.
- Do not create or update `.import` files manually. Let Godot generate them.

For melon seeds, wire the prefabs to `cat_sunflower_seeds`, not to a new category, unless the user asks for a different taxonomy.

## Bbox Compatibility

The capture code historically assumed this direct prefab layout:

```text
root
├── MeshInstance3D
└── CollisionShape3D
```

Wrapper prefabs that instance `.blend` files are nested:

```text
root
└── model instance
    └── imported mesh/collider nodes
```

To support wrapper prefabs, `scripts/capture/label_generator.gd` must not use fixed child indexes like `get_child(0)` or `get_child(1)`. It should recursively find:

- `CollisionShape3D` for bbox when available.
- `MeshInstance3D` AABB as fallback when no collision shape exists.

If bbox generation fails for a newly imported category, inspect `label_generator.gd` before reshaping the prefab. Prefer making label generation robust to nested scenes.

## Godot Import And Validation

After creating models, prefabs, and catalog entries:

1. Run Godot headless once to trigger imports:

```bash
"/Applications/Godot Mono 4.6.app/Contents/MacOS/Godot" --headless --path . --editor --quit
```

2. Confirm generated resources:

```bash
find models/<category> -maxdepth 3 -type f | sort
find prefabs/<category> -maxdepth 1 -type f -name '*.tscn' | sort
```

3. Validate references:

- Every prefab path in `object_catalog.tres` exists.
- Every prefab references an existing `.blend`.
- The prefab uses `ExtResource(...)`, not inlined mesh data.
- Blender did not leave `.blend1` backup files in the project.
- macOS `.DS_Store` files are removed from new asset directories.

4. Validate optimized `.blend` files when possible:

- Mesh names end with `_rigid`.
- Images are not packed.
- Image paths start with `//textures/`.
- Texture files exist beside the `.blend`.
- Final triangle count is close to the requested ratio.

5. Validate bbox behavior for nested prefabs when the category is used by the data generator:

- Instantiate representative prefabs.
- Call `LabelGenerator.get_2d_bbox(node, camera)`.
- Confirm the returned array has four values and positive area.

## Cleanup

Remove temporary validation scripts after use.

Do not delete user-authored assets. It is safe to delete generated `.blend1` backups and `.DS_Store` files inside newly generated asset directories when they were produced during this workflow.
