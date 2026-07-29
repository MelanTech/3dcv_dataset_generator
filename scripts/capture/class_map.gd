extends Node

var class_mapping = {
	# —— 正式类别（Table=0，1-18）——
	"Table": 0,
	"Brush": 1,
	"Earphone": 2,
	"Cup": 3,
	"Hanger": 4,
	"Chocolate": 5,
	"SunflowerSeeds": 6,
	"Sausage": 7,
	"Chips": 8,
	"CannedChips": 9,
	"Can": 10,
	"Bottle": 11,
	"Milk": 12,
	"Water": 13,
	"Peach": 14,
	"Apple": 15,
	"Banana": 16,
	"Pear": 17,
	"Book": 18,
	# —— Unknown 大类 ——
	"Unknown": 19,
	# —— Unknown 大类下的子类别：可在 RandomPlacer 中独立管理，
	#    但类别值统一映射到 Unknown(19)，仅作干扰物不写入标签 ——
	"Comb": 19,
	"Biscuit": 19,
	"DragonFruit": 19,
	"Orange": 19,
	"Pomegranate": 19,
	"Jelly": 19,
}
