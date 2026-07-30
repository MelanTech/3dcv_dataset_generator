"""Batch optimize model assets for the DatasetGen Godot project.

This script is intended to run inside Blender Python, normally through
the mcp_blender.execute_blender_code tool.

Inject ASSET_JOBS into globals before executing this file:

ASSET_JOBS = [
    {
        "src": "/absolute/path/source.glb",
        "out_dir": "/Users/bytedance/Develop/DatasetGen/models/melonseeds/melonseeds2",
        "asset_name": "melonseeds2",
        "decimate_ratio": 0.1,
        "texture_max_edge": 1024,
        "jpeg_quality": 85,
    },
]
"""

import json
import os
import re
import traceback

import bpy


DEFAULT_DECIMATE_RATIO = 0.1
DEFAULT_TEXTURE_MAX_EDGE = 1024
DEFAULT_NORMAL_MAX_EDGE = 1024
DEFAULT_JPEG_QUALITY = 85


def clean_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    datablock_collections = (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.textures,
        bpy.data.cameras,
        bpy.data.lights,
        bpy.data.actions,
        bpy.data.armatures,
    )
    for collection in datablock_collections:
        for datablock in list(collection):
            try:
                collection.remove(datablock)
            except Exception:
                pass

    for _ in range(3):
        try:
            bpy.ops.outliner.orphans_purge(
                do_local_ids=True,
                do_linked_ids=True,
                do_recursive=True,
            )
        except Exception:
            pass


def import_asset(src):
    ext = os.path.splitext(src)[1].lower()
    if ext in {".glb", ".gltf"}:
        try:
            bpy.ops.import_scene.gltf(filepath=src, import_pack_images=False)
        except TypeError:
            bpy.ops.import_scene.gltf(filepath=src)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=src)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=src)
    else:
        raise ValueError("Unsupported source extension: %s" % ext)


def remove_lights_and_cameras():
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)


def get_mesh_objects():
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def triangle_count(objects):
    total = 0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        eval_obj = obj.evaluated_get(depsgraph)
        mesh = eval_obj.to_mesh()
        try:
            mesh.calc_loop_triangles()
            total += len(mesh.loop_triangles)
        finally:
            eval_obj.to_mesh_clear()
    return total


def make_meshes_single_user(mesh_objects):
    for obj in mesh_objects:
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        try:
            bpy.ops.object.make_single_user(
                object=True,
                obdata=True,
                material=False,
                animation=False,
            )
        except Exception:
            pass
        obj.select_set(False)


def decimate_meshes(mesh_objects, ratio):
    for obj in mesh_objects:
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        modifier = obj.modifiers.new(name="Decimate_to_ratio", type="DECIMATE")
        modifier.ratio = float(ratio)
        modifier.use_collapse_triangulate = True
        try:
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        finally:
            obj.select_set(False)


def safe_name(name):
    stem = os.path.splitext(os.path.basename(str(name)))[0]
    stem = re.sub(r"[^A-Za-z0-9_.-]+", "_", stem).strip("._")
    return stem or "Image"


def sanitize_object_base(name, fallback):
    base = re.sub(r"_rigid$", "", str(name))
    base = re.sub(r"[^A-Za-z0-9_]+", "_", base).strip("_")
    return base or fallback


def add_rigid_suffix(mesh_objects, asset_name):
    used_names = set()
    result = []
    for idx, obj in enumerate(mesh_objects, start=1):
        fallback = "%s_mesh_%d" % (asset_name, idx)
        base = sanitize_object_base(obj.name, fallback)
        candidate = "%s_rigid" % base
        if candidate in used_names:
            candidate = "%s_%d_rigid" % (base, idx)
        obj.name = candidate
        if obj.data:
            obj.data.name = candidate + "_mesh"
        used_names.add(candidate)
        result.append(candidate)
    return result


def detect_texture_roles():
    normal_images = set()
    alpha_images = set()

    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.node_tree is None:
            continue
        for node in mat.node_tree.nodes:
            if node.bl_idname != "ShaderNodeTexImage" or node.image is None:
                continue
            image = node.image
            label = ("%s %s %s" % (image.name, node.name, node.label)).lower()
            if any(token in label for token in ("normal", "nrm", "bump")):
                normal_images.add(image.name)

            for output_socket in node.outputs:
                for link in output_socket.links:
                    target = link.to_node
                    target_name = ("%s %s" % (target.name, target.bl_idname)).lower()
                    socket_name = link.to_socket.name.lower() if link.to_socket else ""
                    if "normal" in target_name or target.bl_idname == "ShaderNodeNormalMap":
                        normal_images.add(image.name)
                    if "alpha" in socket_name:
                        alpha_images.add(image.name)

    return normal_images, alpha_images


def unique_texture_path(tex_dir, base, ext, used_paths):
    path = os.path.join(tex_dir, base + ext)
    suffix = 1
    while path in used_paths or os.path.exists(path):
        path = os.path.join(tex_dir, "%s_%d%s" % (base, suffix, ext))
        suffix += 1
    used_paths.add(path)
    return path


def save_scaled_textures(job, tex_dir):
    texture_max_edge = int(job.get("texture_max_edge", DEFAULT_TEXTURE_MAX_EDGE))
    normal_max_edge = int(job.get("normal_max_edge", texture_max_edge))
    jpeg_quality = int(job.get("jpeg_quality", DEFAULT_JPEG_QUALITY))
    normal_images, alpha_images = detect_texture_roles()
    image_results = []
    used_paths = set()

    for image in list(bpy.data.images):
        if image is None or image.type != "IMAGE":
            continue
        if image.size[0] <= 0 or image.size[1] <= 0:
            continue

        width, height = int(image.size[0]), int(image.size[1])
        use_png = image.name in normal_images or image.name in alpha_images
        max_edge = normal_max_edge if image.name in normal_images else texture_max_edge
        scale = min(1.0, float(max_edge) / float(max(width, height)))
        new_width = max(1, int(round(width * scale)))
        new_height = max(1, int(round(height * scale)))

        if new_width != width or new_height != height:
            image.scale(new_width, new_height)

        ext = ".png" if use_png else ".jpg"
        out_path = unique_texture_path(tex_dir, safe_name(image.name), ext, used_paths)

        settings = bpy.context.scene.render.image_settings
        if use_png:
            settings.file_format = "PNG"
            settings.color_mode = "RGBA" if image.name in alpha_images else "RGB"
            settings.compression = 100
            format_name = "PNG"
        else:
            settings.file_format = "JPEG"
            settings.color_mode = "RGB"
            settings.quality = jpeg_quality
            format_name = "JPEG"

        try:
            image.save_render(out_path, scene=bpy.context.scene)
        except Exception:
            image.filepath_raw = out_path
            image.file_format = "PNG" if use_png else "JPEG"
            image.save()

        image.filepath = out_path
        image.filepath_raw = out_path
        image.source = "FILE"
        if image.packed_file is not None:
            try:
                image.unpack(method="REMOVE")
            except Exception:
                pass

        image_results.append(
            {
                "name": image.name,
                "original": [width, height],
                "saved": [new_width, new_height],
                "file": os.path.basename(out_path),
                "format": format_name,
                "packed": image.packed_file is not None,
            }
        )

    return image_results


def normalize_texture_paths(tex_dir):
    for image in bpy.data.images:
        if image is None or image.type != "IMAGE":
            continue

        current_path = bpy.path.abspath(image.filepath) if image.filepath else ""
        filename = os.path.basename(current_path or image.name)
        local_path = os.path.join(tex_dir, filename)
        if not os.path.exists(local_path):
            continue

        rel_path = "//textures/" + filename
        image.filepath = rel_path
        image.filepath_raw = rel_path
        image.source = "FILE"


def directory_size(path):
    total = 0
    if not os.path.isdir(path):
        return total
    for root, _dirs, files in os.walk(path):
        for filename in files:
            total += os.path.getsize(os.path.join(root, filename))
    return total


def process_job(job):
    src = os.path.abspath(job["src"])
    out_dir = os.path.abspath(job["out_dir"])
    asset_name = job.get("asset_name") or os.path.basename(out_dir)
    tex_dir = os.path.join(out_dir, "textures")
    out_blend = os.path.join(out_dir, asset_name + ".blend")
    decimate_ratio = float(job.get("decimate_ratio", DEFAULT_DECIMATE_RATIO))
    remove_scene_helpers = bool(job.get("remove_lights_cameras", True))

    os.makedirs(tex_dir, exist_ok=True)

    clean_scene()
    import_asset(src)
    if remove_scene_helpers:
        remove_lights_and_cameras()

    mesh_objects = get_mesh_objects()
    if not mesh_objects:
        raise RuntimeError("No mesh objects imported from %s" % src)

    triangles_before = triangle_count(mesh_objects)
    make_meshes_single_user(mesh_objects)
    decimate_meshes(mesh_objects, decimate_ratio)
    mesh_objects = get_mesh_objects()
    object_names = add_rigid_suffix(mesh_objects, asset_name)
    triangles_after = triangle_count(mesh_objects)
    images = save_scaled_textures(job, tex_dir)

    for _ in range(5):
        try:
            bpy.ops.outliner.orphans_purge(
                do_local_ids=True,
                do_linked_ids=True,
                do_recursive=True,
            )
        except Exception:
            pass

    bpy.ops.wm.save_as_mainfile(filepath=out_blend, compress=True)
    normalize_texture_paths(tex_dir)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend, compress=True)

    return {
        "src": src,
        "out_blend": out_blend,
        "blend_size_bytes": os.path.getsize(out_blend),
        "texture_total_bytes": directory_size(tex_dir),
        "mesh_object_names": object_names,
        "triangles_before": triangles_before,
        "triangles_after": triangles_after,
        "ratio_actual": round(float(triangles_after) / float(triangles_before), 4)
        if triangles_before
        else None,
        "images": images,
    }


def load_jobs_from_environment():
    payload = os.environ.get("DATASETGEN_ASSET_JOBS_JSON", "")
    if not payload:
        return None
    return json.loads(payload)


def main():
    jobs = globals().get("ASSET_JOBS") or load_jobs_from_environment()
    if not jobs:
        raise RuntimeError("ASSET_JOBS is required")

    results = []
    for index, job in enumerate(jobs):
        try:
            result = process_job(job)
            result["ok"] = True
            results.append(result)
        except Exception as exc:
            results.append(
                {
                    "ok": False,
                    "index": index,
                    "src": job.get("src"),
                    "error": str(exc),
                    "traceback": traceback.format_exc(),
                }
            )

    print("DATASETGEN_BATCH_RESULT=" + json.dumps(results, ensure_ascii=True, indent=2))


main()
