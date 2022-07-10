extends Node3D

# Initialization constants

const BLOCK_SIZE := 16
const MODULES_PATH := "user://modules"
const CORE_MODULE_PATH := "res://modules/core"
const DEFAULT_TEXTURE_PATH := "res://modules/core/textures/null.png"
const DEFAULT_TEXTURE_ID := "core/null.png"

# Gender constants

enum Gender {
	FEMALE = 0,
	MALE,
}

# Name constants

const FIRST_NAMES := {
	Gender.FEMALE: [
		"Aida",
		"Era",
		"Erel",
		"Heliani",
		"Julia",
		"Karana",
		"Kiva",
		"Leponia",
		"Liteiva",
		"Makadelena",
		"Mia",
		"Rana",
		"Selina",
		"Sidoni",
		"Sovena",
		"Velia",
		"Vrida",
	],
	Gender.MALE: [
		"Adridan",
		"Alistair",
		"Julian",
		"Heiden",
		"Kien",
		"Krai",
		"Lensto",
		"Lovuen",
		"Maki",
		"Mako",
		"Miko",
		"Oromo",
		"Oseram",
		"Relik",
		"Relin",
		"Tular",
		"Sarovo",
		"Vau",
		"Veren",
	],
}

const LAST_NAMES := [
	"Adesir",
	"Erai",
	"Eram",
	"Halapenoi",
	"Joi",
	"Loren",
	"Movori",
	"Osei",
	"Tanstim",
	"Vihide",
	"Vile",
]
