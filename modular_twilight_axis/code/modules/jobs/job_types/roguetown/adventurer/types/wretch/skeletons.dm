/obj/item/clothing/head/roguetown/duelhat/pretzel/skelet
	name = "old rebel's hat"
	max_integrity = 100
	armor = ARMOR_SPELLSINGER
	body_parts_covered = HEAD|HAIR|EARS
	prevent_crits = list(BCLASS_CUT, BCLASS_BLUNT, BCLASS_TWIST)

/datum/advclass/wretch/thehero
	name = "Undead Warrior"
	tutorial = "You're a shkeleton! You already forget how you got all these bones, but people fears you, they want to dig you down. Do it first."
	outfit = /datum/outfit/job/roguetown/wretch/hero
	category_tags = list(CTAG_WRETCH)
	min_pq = 30				//better RP?
	maximum_possible_slots = 2
	extra_context = "You're a SKELETON, be ready to shackle your bones. Minimum PQ Required: 30"
	traits_applied = list(
		TRAIT_NOHUNGER, 
		TRAIT_NOBREATH, 
		TRAIT_NOPAIN, 
		TRAIT_TOXIMMUNE, 
		TRAIT_SHOCKIMMUNE, 
		TRAIT_SILVER_WEAK,
		TRAIT_BREADY
	)

	subclass_skills = list(
		/datum/skill/combat/knives = SKILL_LEVEL_JOURNEYMAN,
		/datum/skill/combat/wrestling = SKILL_LEVEL_APPRENTICE,
		/datum/skill/combat/unarmed = SKILL_LEVEL_APPRENTICE,
		/datum/skill/craft/crafting = SKILL_LEVEL_NOVICE,
		/datum/skill/misc/climbing = SKILL_LEVEL_JOURNEYMAN,
		/datum/skill/misc/athletics = SKILL_LEVEL_EXPERT
	)

/datum/outfit/job/roguetown/wretch/hero/proc/skelet(mob/living/carbon/human/H)
	H.hairstyle = "Bald"
	H.facial_hairstyle = "Shaved"
	ADD_TRAIT(H, TRAIT_LIMBATTACHMENT, TRAIT_GENERIC)
	ADD_TRAIT(H, TRAIT_NOLIMBDISABLE, TRAIT_GENERIC)
	H.dna.species.species_traits |= NOBLOOD
	H.mob_biotypes = MOB_UNDEAD
	for(var/obj/item/bodypart/B in H.bodyparts)
		B.skeletonize(FALSE)
	var/obj/item/organ/eyes/eyes = H.getorganslot(ORGAN_SLOT_EYES)
	if (eyes)
		eyes.Remove(H, TRUE)
		QDEL_NULL(eyes)
	eyes = new /obj/item/organ/eyes/night_vision/zombie
	eyes.Insert(H)
	H.update_body()
	H.update_hair()
	H.update_body_parts(redraw = TRUE)
	H.dna.species.soundpack_m = new /datum/voicepack/skeleton()
	H.dna.species.soundpack_f = new /datum/voicepack/skeleton()

/datum/outfit/job/roguetown/wretch/hero/pre_equip(mob/living/carbon/human/H)
	..()
	H.adjust_blindness(-3)
	H.STAINT = 5			//Clever shkelet
	skelet(H)
	backpack_contents = list(
		/obj/item/recipe_book/survival = 1,
		/obj/item/repair_kit/metal/bad = 2,
		/obj/item/rogueweapon/huntingknife/idagger = 1,
		/obj/item/rogueweapon/scabbard/sheath = 1
	)
	var/classes = list("Krieger", "Armbrustschütze", "Toter Aufrührer")
	var/classchoice = input("Choose your archetypes", "Available archetypes") as anything in classes

	switch(classchoice)
		if("Krieger")
			ADD_TRAIT(H, TRAIT_HEAVYARMOR, TRAIT_GENERIC)
			H.adjust_skillrank(/datum/skill/combat/swords, 3, TRUE)
			head = /obj/item/clothing/head/roguetown/roguehood/red
			backl = /obj/item/storage/backpack/rogue/satchel
			cloak = /obj/item/clothing/cloak/tabard
			backr = /obj/item/rogueweapon/scabbard/gwstrap
			armor = /obj/item/clothing/suit/roguetown/armor/plate/full/iron
			shirt = /obj/item/clothing/suit/roguetown/armor/gambeson/heavy
			wrists = /obj/item/clothing/wrists/roguetown/bracers/iron
			pants = /obj/item/clothing/under/roguetown/chainlegs/iron/kilt
			shoes = /obj/item/clothing/shoes/roguetown/boots/armor/iron
			belt = /obj/item/storage/belt/rogue/leather/battleskirt/black
			beltl = /obj/item/storage/belt/rogue/pouch/coins/poor
			id = /obj/item/clothing/ring/aalloy
		if("Armbrustschütze")
			ADD_TRAIT(H, TRAIT_MEDIUMARMOR, TRAIT_GENERIC)
			H.adjust_skillrank(/datum/skill/combat/crossbows, 4, TRUE)
			H.adjust_skillrank(/datum/skill/combat/maces, 3, TRUE)
			backl = /obj/item/storage/backpack/rogue/satchel
			backr = /obj/item/gun/ballistic/revolver/grenadelauncher/crossbow
			neck = /obj/item/clothing/neck/roguetown/leather
			shirt = /obj/item/clothing/suit/roguetown/armor/chainmail/hauberk/aalloy
			armor = /obj/item/clothing/suit/roguetown/armor/plate/bronze
			cloak =	/obj/item/clothing/cloak/tabard/stabard/surcoat
			wrists = /obj/item/clothing/wrists/roguetown/bracers/leather
			gloves = /obj/item/clothing/gloves/roguetown/angle
			pants = /obj/item/clothing/under/roguetown/trou/leather
			shoes = /obj/item/clothing/shoes/roguetown/boots/leather/reinforced
			belt = /obj/item/storage/belt/rogue/leather
			beltl = /obj/item/quiver/bolt/standard
			beltr = /obj/item/rogueweapon/mace/cudgel
		if("Toter Aufrührer")
			ADD_TRAIT(H, TRAIT_DODGEEXPERT, TRAIT_GENERIC)
			H.adjust_skillrank(/datum/skill/combat/twilight_firearms, 2, TRUE)
			H.adjust_skillrank(/datum/skill/combat/unarmed, 3, TRUE)
			head = /obj/item/clothing/head/roguetown/duelhat/pretzel/skelet
			backl = /obj/item/storage/backpack/rogue/satchel
			neck = /obj/item/quiver/twilight_bullet/lead_ten
			shirt = /obj/item/clothing/suit/roguetown/shirt/freifechter
			cloak = /obj/item/clothing/suit/roguetown/armor/longcoat
			wrists = /obj/item/clothing/wrists/roguetown/bracers/leather
			gloves = /obj/item/clothing/gloves/roguetown/angle/grenzelgloves
			pants = /obj/item/clothing/under/roguetown/heavy_leather_pants/grenzelpants
			shoes = /obj/item/clothing/shoes/roguetown/grenzelhoft
			belt = /obj/item/storage/belt/rogue/leather/double
			beltl = /obj/item/gun/ballistic/twilight_firearm/arquebus_pistol
			beltr = /obj/item/rogueweapon/knuckles/paknuckles
			backpack_contents = list(
				/obj/item/recipe_book/survival = 1,
				/obj/item/rogueweapon/huntingknife/idagger = 1,
				/obj/item/rogueweapon/scabbard/sheath = 1,
				/obj/item/twilight_powderflask
			)

/datum/outfit/job/roguetown/wretch/hero/post_equip(mob/living/carbon/human/H)
	..()
	if(HAS_TRAIT(H, TRAIT_HEAVYARMOR))
		var/obj/item/rogueweapon/greatsword/grenz/flamberge/paalloy/W = new(get_turf(H))
		if(!H.put_in_hands(W))
			W.forceMove(get_turf(H))

		//no castifico, you're a fucking skeleton. Life already punched you
