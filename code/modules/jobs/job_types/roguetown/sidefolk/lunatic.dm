/datum/job/roguetown/lunatic
	title = "Lunatic"
	flag = LUNATIC
	department_flag = SIDEFOLK
	faction = "Station"
	total_positions = 2			//TA - edit
	spawn_positions = 2
	round_contrib_points = 2
	var/list/traits_applied
	traits_applied = list(TRAIT_PSYCHOSIS, TRAIT_NOSTINK, TRAIT_MANIAC_AWOKEN, TRAIT_HOMESTEAD_EXPERT) // Maniac_Awoken no longer has any function other than the flavor text and trait
	allowed_sexes = list(MALE, FEMALE)
	allowed_races = ACCEPTED_RACES
	allowed_ages = list(AGE_ADULT, AGE_MIDDLEAGED, AGE_OLD)
	outfit = /datum/outfit/job/roguetown/lunatic
	bypass_lastclass = TRUE
	bypass_jobban = FALSE
	min_pq = 100 //the magic of an allowlist server.
	max_pq = null
	tutorial = "The Lunatic, shunned by society and a magnet for misfortune. Your task is simple yet perilous: survive by any means, though your very existence invites danger from every corner. It is said that Twilight Axis drives those most familiar with it, the most insane."
	display_order = JDO_LUNATIC
	selection_color = JCOLOR_SIDEFOLK

	cmode_music = 'sound/music/combat_bum.ogg'

	job_traits = list(TRAIT_JESTERPHOBIA)

	advclass_cat_rolls = list(CTAG_LUNATIC = 2)
	job_subclasses = list(
		/datum/advclass/lunatic,
		/datum/advclass/thehero				//TA - edit
	)

/datum/advclass/lunatic
	name = "Lunatic"
	tutorial = "The Lunatic, shunned by society and a magnet for misfortune. Your task is simple yet perilous: survive by any means, though your very existence invites danger from every corner. It is said that Azure Peak drives those most familiar with it, the most insane."
	outfit = /datum/outfit/job/roguetown/lunatic/basic
	category_tags = list(CTAG_LUNATIC)
	subclass_stats = list(
		STATKEY_SPD = 2,
		STATKEY_CON = 4
	)
	subclass_skills = list(
		/datum/skill/misc/sneaking = SKILL_LEVEL_APPRENTICE,
		/datum/skill/misc/stealing = SKILL_LEVEL_APPRENTICE,
		/datum/skill/combat/knives = SKILL_LEVEL_JOURNEYMAN,
		/datum/skill/combat/wrestling = SKILL_LEVEL_APPRENTICE,
		/datum/skill/combat/unarmed = SKILL_LEVEL_APPRENTICE,
		/datum/skill/craft/crafting = SKILL_LEVEL_NOVICE,
		/datum/skill/misc/climbing = SKILL_LEVEL_EXPERT,
		/datum/skill/misc/athletics = SKILL_LEVEL_APPRENTICE,
		/datum/skill/misc/medicine = SKILL_LEVEL_NOVICE,
		/datum/skill/craft/cooking = SKILL_LEVEL_NOVICE,
	)

/datum/outfit/job/roguetown/lunatic/basic/pre_equip(mob/living/carbon/human/H)
	..()
	H.adjust_blindness(-3)
	H.STALUC = rand(3, 8)
	armor = /obj/item/clothing/suit/roguetown/shirt/rags
	shirt = /obj/item/clothing/suit/roguetown/shirt/undershirt/vagrant
	pants = /obj/item/clothing/under/roguetown/tights/vagrant
	belt  = /obj/item/storage/belt/rogue/leather/rope
	beltl = /obj/item/rogueweapon/huntingknife/stoneknife
	beltr = /obj/item/flashlight/flare/torch

/datum/advclass/thehero				//TA - class
	name = "Ancient Hero"
	tutorial = "You're a shkeleton! You already forget how you got all these cool bones, but you're are still a good warrior and hero of your own story."
	outfit = /datum/outfit/job/roguetown/lunatic/hero
	traits_applied = list(TRAIT_NOLIMBDISABLE, 
		TRAIT_NOHUNGER, 
		TRAIT_NOBREATH, 
		TRAIT_NOPAIN, 
		TRAIT_TOXIMMUNE, 
		TRAIT_NOSLEEP, 
		TRAIT_SHOCKIMMUNE, 
		TRAIT_HEAVYARMOR, 
		TRAIT_LIMBATTACHMENT, 
		TRAIT_SILVER_WEAK
	)
	category_tags = list(CTAG_LUNATIC)

	subclass_skills = list(
		/datum/skill/combat/swords = SKILL_LEVEL_EXPERT,
		/datum/skill/combat/knives = SKILL_LEVEL_JOURNEYMAN,
		/datum/skill/combat/wrestling = SKILL_LEVEL_APPRENTICE,
		/datum/skill/combat/unarmed = SKILL_LEVEL_APPRENTICE,
		/datum/skill/craft/crafting = SKILL_LEVEL_NOVICE,
		/datum/skill/misc/climbing = SKILL_LEVEL_JOURNEYMAN,
		/datum/skill/misc/athletics = SKILL_LEVEL_EXPERT
	)

/datum/outfit/job/roguetown/lunatic/hero/proc/skelet(mob/living/carbon/human/H)
	H.hairstyle = "Bald"
	H.facial_hairstyle = "Shaved"
	H.update_body()
	H.update_hair()
	H.mob_biotypes = MOB_UNDEAD
	H.update_body_parts(redraw = TRUE)
	for(var/obj/item/bodypart/B in H.bodyparts)
		B.skeletonize(FALSE)
	var/obj/item/organ/eyes/eyes = H.getorganslot(ORGAN_SLOT_EYES)
	if (eyes)
		eyes.Remove(H, TRUE)
		QDEL_NULL(eyes)
	eyes = new /obj/item/organ/eyes/night_vision/zombie
	eyes.Insert(H)

/datum/outfit/job/roguetown/lunatic/hero/pre_equip(mob/living/carbon/human/H)
	..()
	H.adjust_blindness(-3)
	H.STAINT = 4				//Clever shkelet
	H.STALUC = rand(3, 8)
	skelet(H)
	H.dna.species.soundpack_m = new /datum/voicepack/other/lich()
	to_chat(H, span_purple("'..Что...эт где я вообще, кто я! Ах..доспехи...меч, видимо, я герой этих земель! Вперёд, в путь!..'"))
	head = /obj/item/clothing/head/roguetown/roguehood/red
	neck = /obj/item/clothing/neck/roguetown/gorget
	backl = /obj/item/storage/backpack/rogue/satchel
	cloak = /obj/item/clothing/cloak/cape/red
	backr = /obj/item/rogueweapon/scabbard/gwstrap
	armor = /obj/item/clothing/suit/roguetown/armor/plate/full/iron
	shirt = /obj/item/clothing/suit/roguetown/armor/gambeson/heavy
	wrists = /obj/item/clothing/wrists/roguetown/bracers/iron
	gloves = /obj/item/clothing/gloves/roguetown/angle
	pants = /obj/item/clothing/under/roguetown/chainlegs/iron/kilt
	shoes = /obj/item/clothing/shoes/roguetown/boots/armor/iron
	belt = /obj/item/storage/belt/rogue/leather/battleskirt/black
	beltl = /obj/item/storage/belt/rogue/pouch/coins/poor
	beltr = /obj/item/rogueweapon/scabbard/sheath
	id = /obj/item/clothing/ring/aalloy
	backpack_contents = list(
		/obj/item/recipe_book/survival = 1,
		/obj/item/repair_kit/metal/bad = 2,
		/obj/item/rogueweapon/huntingknife/idagger = 1
	)

/datum/outfit/job/roguetown/lunatic/hero/post_equip(mob/living/carbon/human/H)
	..()
	var/obj/item/rogueweapon/greatsword/zwei/W = new(get_turf(H))
	if(!H.put_in_hands(W))
		W.forceMove(get_turf(H))
