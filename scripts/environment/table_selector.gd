@tool
extends Node

enum GenerationMode {
	SQUARE_TABLE,
	DISC_TABLE,
	FLOATING,
}

@export_enum("Square Table", "Disc Table", "Floating") var table_shape: int = GenerationMode.SQUARE_TABLE:
	set(value):
		table_shape = value
		_apply_table_selection_deferred()

@export_group("Tables")
@export var square_table: RigidBody3D
@export var square_table_mesh: MeshInstance3D
@export var disc_table: RigidBody3D
@export var disc_table_mesh: MeshInstance3D

@export_group("Consumers")
@export var data_generator: Node
@export var random_placer: Node
@export var table_distractor_placer: Node


func _enter_tree() -> void:
	_apply_table_selection()


func _ready() -> void:
	_apply_table_selection_deferred()


func _apply_table_selection_deferred() -> void:
	if is_inside_tree():
		call_deferred("_apply_table_selection")


func _apply_table_selection() -> void:
	var use_disc := table_shape == GenerationMode.DISC_TABLE
	var use_floating := table_shape == GenerationMode.FLOATING
	if square_table != null:
		square_table.visible = not use_disc and not use_floating
	if disc_table != null:
		disc_table.visible = use_disc and not use_floating

	var active_table := disc_table if use_disc else square_table
	var active_mesh := disc_table_mesh if use_disc else square_table_mesh
	if use_floating:
		active_table = null
		active_mesh = null

	if data_generator != null:
		data_generator.set("table", active_table)
	if random_placer != null:
		random_placer.set("table_mesh", active_mesh)
		random_placer.set("placement_mode", 1 if use_floating else 0)
	if table_distractor_placer != null:
		table_distractor_placer.set("table_mesh", active_mesh)
