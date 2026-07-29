extends RefCounted
class_name DepthPng16

## 把单通道 16-bit 灰度数据编码为标准 PNG（bitdepth=16, colortype=0）。
##
## Godot 内置 Image.save_png() 只能落 8-bit，无法产出与 OpenNI 深度相机一致的
## 16-bit 灰度 PNG。这里手写 PNG 容器：
## - 像素数据：每行前置 1 个 filter 字节(0=None)，样本为大端 uint16。
## - IDAT：直接用 PackedByteArray.compress(COMPRESSION_DEFLATE)，Godot 输出的
##   就是带 zlib 头(0x78 0x9C)的完整 zlib 流，正好是 PNG 要求的格式。
## - 每个 chunk 追加 CRC32(type+data)。

static var _crc_table: PackedInt64Array = _build_crc_table()


static func _png_signature() -> PackedByteArray:
	return PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])


static func _build_crc_table() -> PackedInt64Array:
	var table := PackedInt64Array()
	table.resize(256)
	for n in range(256):
		var c: int = n
		for _k in range(8):
			if c & 1:
				c = 0xEDB88320 ^ (c >> 1)
			else:
				c = c >> 1
		table[n] = c & 0xFFFFFFFF
	return table


static func _crc32(data: PackedByteArray) -> int:
	var crc: int = 0xFFFFFFFF
	for b in data:
		crc = _crc_table[(crc ^ b) & 0xFF] ^ (crc >> 8)
		crc = crc & 0xFFFFFFFF
	return crc ^ 0xFFFFFFFF


static func _u32_be(value: int) -> PackedByteArray:
	return PackedByteArray([
		(value >> 24) & 0xFF,
		(value >> 16) & 0xFF,
		(value >> 8) & 0xFF,
		value & 0xFF,
	])


static func _make_chunk(type: String, data: PackedByteArray) -> PackedByteArray:
	var type_bytes := type.to_ascii_buffer()
	var chunk := PackedByteArray()
	chunk.append_array(_u32_be(data.size()))
	chunk.append_array(type_bytes)
	chunk.append_array(data)
	var crc_input := PackedByteArray()
	crc_input.append_array(type_bytes)
	crc_input.append_array(data)
	chunk.append_array(_u32_be(_crc32(crc_input)))
	return chunk


## samples: 长度为 width*height 的 uint16 值（行优先）。返回完整 PNG 字节。
static func encode_gray16(samples: PackedInt32Array, width: int, height: int) -> PackedByteArray:
	# 组装原始扫描线：每行 1 字节 filter(0) + width*2 字节大端样本
	var raw := PackedByteArray()
	raw.resize(height * (1 + width * 2))
	var idx := 0
	for y in range(height):
		raw[idx] = 0  # filter type: None
		idx += 1
		var row_start := y * width
		for x in range(width):
			var v: int = samples[row_start + x] & 0xFFFF
			raw[idx] = (v >> 8) & 0xFF
			raw[idx + 1] = v & 0xFF
			idx += 2

	var compressed := raw.compress(FileAccess.COMPRESSION_DEFLATE)

	# IHDR: width, height, bitdepth=16, colortype=0(gray), comp=0, filter=0, interlace=0
	var ihdr := PackedByteArray()
	ihdr.append_array(_u32_be(width))
	ihdr.append_array(_u32_be(height))
	ihdr.append(16)
	ihdr.append(0)
	ihdr.append(0)
	ihdr.append(0)
	ihdr.append(0)

	var png := PackedByteArray()
	png.append_array(_png_signature())
	png.append_array(_make_chunk("IHDR", ihdr))
	png.append_array(_make_chunk("IDAT", compressed))
	png.append_array(_make_chunk("IEND", PackedByteArray()))
	return png


## 直接写文件。成功返回 OK。
static func save_gray16(path: String, samples: PackedInt32Array, width: int, height: int) -> Error:
	var png := encode_gray16(samples, width, height)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(png)
	file.close()
	return OK
