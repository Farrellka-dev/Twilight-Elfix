/datum/crafting_recipe/roguetown/engineering/slurbow
	name = "slurbow"
	category = "Weapons"
	result = /obj/item/gun/ballistic/revolver/grenadelauncher/crossbow/slurbow
	reqs = list(/obj/item/roguegear = 1, /obj/item/ingot/steel = 1, /obj/item/natural/fibers = 1, /obj/item/natural/wood/plank = 1)
	structurecraft = /obj/machinery/artificer_table
	skillcraft = /datum/skill/craft/engineering
	craftdiff = 5

/datum/crafting_recipe/roguetown/engineering/twentylightbolts
	name = "light bolt (x20)"
	category = "Ammo"
	reqs = list(/obj/item/natural/wood/plank = 2, /obj/item/ingot/iron = 1)
	result = list(/obj/item/ammo_casing/caseless/rogue/bolt,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light,
						/obj/item/ammo_casing/caseless/rogue/bolt/light
					)
	structurecraft = /obj/machinery/artificer_table
	skillcraft = /datum/skill/craft/engineering
	craftdiff = 3
