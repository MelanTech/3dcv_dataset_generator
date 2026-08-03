# AGENTS.md

This file is for AI coding agents working in this repository. Follow it together with the user request and higher-priority system/developer instructions.

## Project Summary

DatasetGen is a Godot 4.6 Mono project for synthetic dataset generation. It renders randomized indoor scenes, places configured object prefabs, captures RGB/depth images, and writes object-detection labels.

Main scene:

- `scenes/main.tscn`

Generator scene:

- `scenes/generator_scene.tscn`

Core catalog:

- `resources/object_catalog.tres`

## Common Commands

Open the project:

```bash
/Applications/Godot\ Mono\ 4.6.app/Contents/MacOS/Godot --path .
```

Run a headless load/parse check:

```bash
/Applications/Godot\ Mono\ 4.6.app/Contents/MacOS/Godot --headless --log-file /tmp/datasetgen-godot-headless.log --path . --quit
```

Use `--log-file /tmp/...`; without it, Godot may try to write under `user://logs` in the macOS Application Support directory, which can be blocked by the sandbox.

## Repository Layout

```text
addons/        Godot plugins
hdri/          environment HDR assets
models/        source model and texture assets, tracked with Git LFS
prefabs/       instantiable object/table scenes, tracked with Git LFS
resources/     ObjectCatalog and other resources
scenes/        main and generator scenes
scripts/       GDScript source
shaders/       shader resources
themes/        global UI theme
tools/         maintenance scripts
```

Script folders:

```text
scripts/capture/      capture, label generation, depth writing
scripts/config/       ObjectCatalog/ObjectCategory resource classes
scripts/depth/        depth viewport helpers and 16-bit PNG encoder
scripts/environment/  camera, placement, tables, distractors, augmentation
scripts/ui/           GUI, responsive scaling, model browser
```

## Core Scene Topology

`scenes/main.tscn` owns the UI shell:

- `GeneratorViewport` instantiates `scenes/generator_scene.tscn`.
- `DepthPreview` displays `GeneratorScene/DepthViewPort` through `shaders/depth_preview.gdshader`.
- `SessionController` wires GUI controls to generator runtime nodes.

`scenes/generator_scene.tscn` owns generation:

- `Camera3D`: RGB camera with orbit/random transition script.
- `DepthViewPort`: depth-only render viewport.
- `Camera3DDepth`: copies RGB camera transform/projection/near/far.
- `DepthView`: full-screen quad using `shaders/depth.gdshader`.
- `Scenes`: random indoor scene container.
- `Tables`: square/disc/floating generation selector.
- `RandomPlacer`: places objects.
- `TableDistractorPlacer`: creates flat texture distractors on table surfaces.
- `DataGenerator`: coordinates save cadence, RGB/depth capture, and labels.
- `BBoxLayer`: live bbox overlay.

## Runtime Architecture

- `SessionController`
  - Owns GUI state and callbacks.
  - Applies GUI values to `DataGenerator`, `RandomPlacer`, `TableDistractorPlacer`, `CameraImageAugmenter`, `TableSelector`, and camera motion.
  - Saves/loads config from `user://gui_config.cfg`.

- `SessionPanelBuilder`
  - Constructs the tabbed right-side GUI.
  - Settings tab: capture, label filtering, camera motion, camera perturbation.
  - Categories tab: model browser button, category enable toggles, category weights.

- `CaptureSettings`
  - Serializes/deserializes GUI state into `ConfigFile`.

- `DataGenerator`
  - Runs only after `begin()`.
  - Saves every `save_interval` frames when `save_enabled` is true.
  - Creates timestamped output directories.
  - Uses `CaptureViewportRig` for clean RGB capture when UI/bbox overlays should be excluded.
  - Delegates label generation to `LabelGenerator`.
  - Delegates file writing to `CaptureWriter`.

- `CaptureViewportRig`
  - Creates a clean offscreen viewport at `rgb_capture_size`.
  - Mirrors the active camera/world/postprocess/augmentation for RGB capture.

- `CaptureWriter`
  - Saves RGB JPEG.
  - Converts encoded RGB depth view to uint16 samples.
  - Calls `DepthPng16` for 16-bit grayscale PNG.
  - Writes labels and `classes.txt`.

- `LabelGenerator`
  - Projects object bounds into camera space.
  - Filters dropped table objects.
  - Filters objects below visibility threshold using occlusion samples.
  - Supports `Grid`, `Bounds Key Points`, and `Hybrid` sampling.
  - Skips Unknown class id.

- `RandomPlacer`
  - Reads enabled weighted categories from `ObjectCatalog`.
  - Supports table placement and floating placement.
  - Freezes recursively in floating mode to prevent physics fall-through.
  - Supports stacked placement on tables.

- `TableSelector`
  - Switches generation mode.
  - Hides tables in Floating mode.
  - Sets `RandomPlacer.placement_mode`.
  - Sends active table/table mesh references to consumers.

- `TableDistractorPlacer`
  - Renders configured prefabs to flat transparent textures.
  - Places non-overlapping flat planes on table surfaces.
  - Disabled automatically when no active table mesh exists.

- `CameraImageAugmenter`
  - Creates its own canvas-layer postprocess overlay.
  - Continuously interpolates distortion and white-balance values.
  - Uses `shaders/camera_image_augmentation.gdshader`.

- `ModelBrowserWindow`
  - Reads `ObjectCatalog` dynamically.
  - Does not scan `prefabs/`.
  - Groups models as `Official` and `Unknown`, then category, then model.
  - Native Godot `Window`, left-drag rotate, right-drag pan, wheel zoom, reset view.

## Depth Pipeline

Depth capture is intentionally separate from RGB capture.

1. `DepthViewPort` shares the generator world.
2. `Camera3DDepth` copies the RGB camera transform, projection, `fov`, `keep_aspect`, `size`, `near`, and `far`.
3. `DepthView` is a full-screen quad using `shaders/depth.gdshader`.
4. `depth.gdshader`:
   - reads `DEPTH_TEXTURE` with `hint_depth_texture`;
   - handles Godot 4 reversed-Z;
   - reconstructs view-space linear depth using `INV_PROJECTION_MATRIX`;
   - converts world depth to millimeters through `world_scale`;
   - rounds to uint16 and packs high/low bytes into R/G;
   - pre-compensates sRGB conversion so captured byte values remain data-stable.
5. `CaptureWriter.save_depth_gray16()` decodes R/G back into uint16 samples.
6. `DepthPng16` writes standard PNG with `bitdepth=16`, `colortype=0`.
7. `depth_preview.gdshader` is display-only; it decodes the packed depth for GUI preview.

When changing depth behavior, validate both:

- GUI preview appearance.
- Saved PNG header/pixel values.

## Output Contract

Session output:

```text
<output_dir>/
  YYYYMMDD_HHMMSS/
    images/
    images_depth/
    labels/
    classes.txt
```

RGB:

- JPEG, file names `000000.jpg`, `000001.jpg`, ...
- Saved via `Image.save_jpg(..., 0.6)`.

Depth:

- PNG, file names mirror RGB basename.
- 16-bit grayscale, one uint16 sample per pixel.
- Pixel value is depth in millimeters after `world_scale`.

Labels:

- YOLO-like normalized format:

```text
class center_x center_y width height
```

Classes:

- `classes.txt` is sorted by class id.
- Unknown and Unknown subcategories are excluded.

## Object Catalog Rules

The model browser and random placement are catalog-driven.

When adding a model:

1. Put source assets under `models/<category>/`.
2. Create or update prefab scenes under `prefabs/<category>/`.
3. Add prefab scenes to `resources/object_catalog.tres`.
4. Check all `ObjectCategory` fields:
   - `display_name`
   - `key`
   - `label_name`
   - `class_id`
   - `is_unknown`
   - `enabled`
   - `weight`
   - `scenes`
5. Run the Godot headless check.

Unknown categories use `is_unknown = true`. Label generation skips the configured Unknown class id, so do not enable Unknown categories for normal labeled dataset generation unless explicitly requested.

## GUI Parameter Map

Settings tab:

- `Generation Mode` -> `TableSelector.table_shape`
- `Item Count` -> `RandomPlacer.item_count_range`
- `Enable Table Distractors` / `Distractor Count` -> `TableDistractorPlacer`
- `Save Interval`, `Save Depth`, `Enable Saving` -> `DataGenerator`
- `Show BBox Preview` -> `BBoxLayer.visible`
- `Enable Rotate Light` -> rotating `SpotLight3D.visible`
- label filtering controls -> `DataGenerator.visibility_threshold`, `occlusion_sample_mode`, `occlusion_grid_sample_count`, `drop_below_table_threshold`, `debug_occlusion`
- camera motion controls -> `scripts/environment/camera.gd`
- camera perturbation controls -> `CameraImageAugmenter`

Categories tab:

- category enabled toggles and weights mutate `ObjectCatalog` resources in memory.
- `Open Model Browser` creates/reuses `ModelBrowserWindow`.

## Godot Resource Rules

- Keep `*.uid` files tracked.
- Keep `*.import` files tracked.
- Do not delete or regenerate resource UIDs casually.
- Scene/resource references rely on UIDs and paths.
- Prefer moving files through Godot. If files are moved manually, update references carefully.
- After changing scripts/resources/scenes/shaders, run the headless Godot check when feasible.

## Git Ignore and LFS Rules

Agent/tool local state must not be committed:

- `.trae/`
- `.agents/`
- `.agent/`
- `.claude/`
- `.codex/`
- `.gemini/`
- `.cursor/`
- `.continue/`
- `.windsurf/`
- `.aider*`

`AGENTS.md` itself must stay tracked. Do not add a broad ignore rule that hides it.

`models/` and `prefabs/` are tracked with Git LFS through `.gitattributes`.

Generated datasets, local exports, IDE settings, `.godot/`, `.import/`, logs, and temporary files are ignored by `.gitignore`.

## Validation Checklist

For code/resource changes:

```bash
/Applications/Godot\ Mono\ 4.6.app/Contents/MacOS/Godot --headless --log-file /tmp/datasetgen-godot-headless.log --path . --quit
```

For ignore-rule changes:

```bash
git status --short --ignored
git ls-files -ci --exclude-standard
```

`git ls-files -ci --exclude-standard` should usually be empty. If it prints tracked source/resource files, the ignore rule is too broad.

For LFS-sensitive changes:

```bash
git lfs track
git lfs ls-files | head
```

## Editing Guidance

- Keep changes scoped to the requested feature or bug.
- Prefer existing local patterns over introducing new abstractions.
- Use `rg` / `rg --files` for search.
- Use `apply_patch` for manual file edits.
- Do not use destructive git commands.
- Do not revert user changes unless explicitly asked.
- Before committing, inspect `git status --short` and make sure only intended files are staged.
