/mob/living/carbon/human
	var/tmp/table_crawl_state_enabled = FALSE
	var/tmp/table_crawl_under_table = FALSE
	var/tmp/table_crawl_attempting = FALSE
	var/tmp/table_crawl_pending_entry = FALSE
	var/tmp/table_crawl_passtable_owned = FALSE
	var/tmp/table_crawl_validating = FALSE
	var/tmp/table_crawl_restoring = FALSE

/mob/living/carbon/human/proc/is_table_crawl_player()
	return !!mind && !!client

/mob/living/carbon/human/on_lying_down(new_lying_angle)
	. = ..()
	if(is_table_crawl_player())
		enable_table_crawl_state()

/mob/living/carbon/human/on_standing_up()
	. = ..()
	if(table_crawl_under_table || table_crawl_pending_entry)
		return
	if(table_crawl_state_enabled)
		disable_table_crawl_state()

/mob/living/carbon/human/proc/enable_table_crawl_state()
	if(table_crawl_state_enabled)
		return
	table_crawl_state_enabled = TRUE
	AddElement(/datum/element/table_crawl)

/mob/living/carbon/human/proc/disable_table_crawl_state()
	if(!table_crawl_state_enabled)
		return
	table_crawl_state_enabled = FALSE
	RemoveElement(/datum/element/table_crawl)

/mob/living/carbon/human/proc/can_table_crawl()
	if(buckled)
		return FALSE
	if(body_position != LYING_DOWN)
		return FALSE
	if(m_intent != MOVE_INTENT_SNEAK)
		return FALSE
	if(mob_size >= MOB_SIZE_LARGE)
		return FALSE
	return TRUE

/mob/living/carbon/human/proc/can_start_table_crawl()
	if(!can_table_crawl())
		return FALSE
	return resting

/mob/living/carbon/human/proc/get_table_crawl_table(atom/location = loc)
	var/turf/table_turf = get_turf(location)
	if(!table_turf)
		return

	for(var/obj/structure/table/table in table_turf)
		return table

/mob/living/carbon/human/proc/get_table_crawl_delay(obj/structure/table/target_table)
	var/adjusted_climb_time = target_table.climb_time
	if(HAS_TRAIT(src, TRAIT_HANDS_BLOCKED))
		adjusted_climb_time *= 2
	adjusted_climb_time -= STASPD * 2
	return max(adjusted_climb_time, 2 SECONDS)

/mob/living/carbon/human/proc/can_virtual_table_climb(obj/structure/table/target_table, turf/target_turf)
	var/turf/source_turf = get_turf(src)
	if(!source_turf || !target_turf || source_turf == target_turf)
		return FALSE

	var/can_climb = FALSE
	var/old_density = target_table.density
	table_crawl_validating = TRUE
	target_table.density = FALSE

	can_climb = !source_turf.LinkBlockedWithAccess(target_turf, src, null)
	if(can_climb)
		can_climb = target_turf.CanPass(src, target_turf)
	if(can_climb)
		for(var/atom/movable/thing as anything in target_turf)
			if(thing == src || thing == target_table)
				continue
			if(!thing.CanPass(src, source_turf))
				can_climb = FALSE
				break

	target_table.density = old_density
	table_crawl_validating = FALSE
	return can_climb

/mob/living/carbon/human/proc/can_finish_table_crawl(obj/structure/table/target_table, turf/target_turf)
	if(QDELETED(src) || QDELETED(target_table))
		return FALSE
	if(!is_table_crawl_player())
		return FALSE
	if(!can_start_table_crawl())
		return FALSE
	if(get_table_crawl_table(loc))
		return FALSE
	if(get_turf(target_table) != target_turf)
		return FALSE
	if(!Adjacent(target_table))
		return FALSE
	if(!can_virtual_table_climb(target_table, target_turf))
		return FALSE
	return TRUE

/mob/living/carbon/human/proc/try_offer_table_crawl(obj/structure/table/target_table, turf/target_turf)
	if(table_crawl_validating)
		return
	if(table_crawl_pending_entry || table_crawl_under_table)
		return
	if(table_crawl_attempting || DOING_INTERACTION(src, "table_crawl") || doing())
		return
	if(!can_finish_table_crawl(target_table, target_turf))
		return

	table_crawl_attempting = TRUE
	INVOKE_ASYNC(src, TYPE_PROC_REF(/mob/living/carbon/human, begin_table_crawl_attempt), target_table, target_turf)

/mob/living/carbon/human/proc/begin_table_crawl_attempt(obj/structure/table/target_table, turf/target_turf)
	if(QDELETED(src) || QDELETED(target_table) || QDELETED(target_turf))
		table_crawl_attempting = FALSE
		return
	if(!can_finish_table_crawl(target_table, target_turf))
		table_crawl_attempting = FALSE
		return

	var/crawl_delay = get_table_crawl_delay(target_table)
	visible_message(span_warning("[src] starts to crawl under [target_table]."), span_warning("You start to crawl under [target_table]..."))
	if(crawl_delay && !do_after(src, crawl_delay, target_table, timed_action_flags = IGNORE_USER_DIR_CHANGE, extra_checks = CALLBACK(src, TYPE_PROC_REF(/mob/living/carbon/human, can_finish_table_crawl), target_table, target_turf), interaction_key = "table_crawl"))
		table_crawl_attempting = FALSE
		return

	table_crawl_attempting = FALSE
	if(!can_finish_table_crawl(target_table, target_turf))
		return

	if(!(pass_flags & PASSTABLE))
		table_crawl_passtable_owned = TRUE
		pass_flags |= PASSTABLE
		queue_table_crawl_passtable_cleanup()

	enable_table_crawl_state()
	table_crawl_pending_entry = TRUE
	var/crawl_direction = get_dir(src, target_turf)
	if(!crawl_direction || !step(src, crawl_direction))
		table_crawl_pending_entry = FALSE
		clear_table_crawl_passtable()

/mob/living/carbon/human/proc/table_crawl_head_bonk()
	var/obj/structure/table/target_table = get_table_crawl_table()
	var/atom/sound_source = src
	var/table_name = target_table ? "[target_table]" : "the underside of the table"
	if(target_table)
		sound_source = target_table

	visible_message(span_warning("[src] bumps their head on [table_name]!"), span_warning("You bump your head on [table_name]!"))
	playsound(sound_source, "genblunt", 100, TRUE)
	Stun(5 SECONDS)

/mob/living/carbon/human/proc/apply_table_crawl_visual()
	reset_offsets("structure_climb")
	layer = TABLE_LAYER - 0.1
	plane = GAME_PLANE_LOWER

/mob/living/carbon/human/proc/clear_table_crawl_passtable()
	if(!table_crawl_passtable_owned)
		return
	table_crawl_passtable_owned = FALSE
	pass_flags &= ~PASSTABLE

/mob/living/carbon/human/proc/queue_table_crawl_passtable_cleanup()
	addtimer(CALLBACK(src, TYPE_PROC_REF(/mob/living/carbon/human, clear_table_crawl_passtable)), world.tick_lag, TIMER_UNIQUE | TIMER_OVERRIDE)

/mob/living/carbon/human/proc/queue_table_crawl_restore()
	if(table_crawl_restoring)
		return
	table_crawl_restoring = TRUE
	addtimer(CALLBACK(src, TYPE_PROC_REF(/mob/living/carbon/human, restore_table_crawl_pose)), world.tick_lag, TIMER_UNIQUE | TIMER_OVERRIDE)

/mob/living/carbon/human/proc/restore_table_crawl_pose()
	table_crawl_restoring = FALSE
	if(QDELETED(src) || !table_crawl_under_table)
		return
	if(resting && body_position == LYING_DOWN)
		return
	set_resting(TRUE, TRUE, TRUE)

/mob/living/carbon/human/proc/clear_table_crawl_visual()
	var/obj/structure/table/table = get_table_crawl_table()
	if(table?.climb_offset)
		set_mob_offsets("structure_climb", _x = 0, _y = table.climb_offset)
	else
		reset_offsets("structure_climb")

	if(body_position == LYING_DOWN)
		layer = LYING_MOB_LAYER
	else
		layer = initial(layer)
	plane = initial(plane)

/mob/living/carbon/human/proc/refresh_table_crawl()
	if(table_crawl_pending_entry && !get_table_crawl_table())
		table_crawl_pending_entry = FALSE
		clear_table_crawl_passtable()
	if(!table_crawl_under_table)
		clear_table_crawl_visual()
		return
	if(!can_table_crawl() || !get_table_crawl_table())
		table_crawl_under_table = FALSE
		clear_table_crawl_visual()
		clear_table_crawl_passtable()
		return
	apply_table_crawl_visual()

/obj/structure/table/examine(mob/user)
	. = ..()
	. += span_notice("Use <b>\[Sneak\] + \[Lay down\]</b> and move into it to crawl under it.")
	. += span_notice("Large creatures cannot fit under tables.")

/datum/element/table_crawl
	element_flags = ELEMENT_DETACH

/datum/element/table_crawl/Attach(datum/target)
	. = ..()
	if(!ishuman(target))
		return ELEMENT_INCOMPATIBLE

	RegisterSignal(target, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_pre_move))
	RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(target, COMSIG_MOVABLE_BUMP, PROC_REF(on_bump))
	RegisterSignal(target, COMSIG_LIVING_SET_RESTING, PROC_REF(on_resting_change))
	RegisterSignal(target, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_body_position_change))
	RegisterSignal(target, COMSIG_LIVING_SET_BUCKLED, PROC_REF(on_buckled_change))

/datum/element/table_crawl/Detach(mob/living/carbon/human/source, ...)
	UnregisterSignal(source, list(
		COMSIG_MOVABLE_PRE_MOVE,
		COMSIG_MOVABLE_MOVED,
		COMSIG_MOVABLE_BUMP,
		COMSIG_LIVING_SET_RESTING,
		COMSIG_LIVING_SET_BODY_POSITION,
		COMSIG_LIVING_SET_BUCKLED,
	))
	source.table_crawl_attempting = FALSE
	source.table_crawl_pending_entry = FALSE
	source.table_crawl_under_table = FALSE
	source.table_crawl_restoring = FALSE
	source.clear_table_crawl_passtable()
	source.clear_table_crawl_visual()
	return ..()

/datum/element/table_crawl/proc/on_pre_move(mob/living/carbon/human/source, atom/new_loc, dir)
	SIGNAL_HANDLER
	if(source.table_crawl_pending_entry)
		return NONE
	if(!source.table_crawl_under_table)
		return NONE
	if(source.can_table_crawl())
		return NONE
	if(!source.get_table_crawl_table(new_loc))
		return NONE
	return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/datum/element/table_crawl/proc/on_bump(mob/living/carbon/human/source, atom/obstacle)
	SIGNAL_HANDLER
	if(source.table_crawl_pending_entry || source.table_crawl_under_table || source.table_crawl_attempting)
		return NONE
	if(!source.can_start_table_crawl())
		return NONE
	if(!istype(obstacle, /obj/structure/table))
		return NONE

	var/obj/structure/table/target_table = obstacle
	source.try_offer_table_crawl(target_table, get_turf(target_table))
	return NONE

/datum/element/table_crawl/proc/on_moved(mob/living/carbon/human/source, atom/old_loc, direction, forced)
	SIGNAL_HANDLER
	if(source.table_crawl_pending_entry)
		source.table_crawl_pending_entry = FALSE
		if(source.get_table_crawl_table())
			source.table_crawl_under_table = TRUE
			source.apply_table_crawl_visual()
	source.clear_table_crawl_passtable()
	source.refresh_table_crawl()

/datum/element/table_crawl/proc/on_resting_change(mob/living/carbon/human/source, new_resting)
	SIGNAL_HANDLER
	if(source.table_crawl_under_table && !new_resting && source.body_position == LYING_DOWN)
		source.table_crawl_head_bonk()
	source.refresh_table_crawl()

/datum/element/table_crawl/proc/on_body_position_change(mob/living/carbon/human/source, new_body_position, old_body_position)
	SIGNAL_HANDLER
	if(source.table_crawl_under_table && old_body_position == LYING_DOWN && new_body_position == STANDING_UP)
		if(!HAS_TRAIT(source, TRAIT_INCAPACITATED))
			source.table_crawl_head_bonk()
		source.queue_table_crawl_restore()
		return
	source.refresh_table_crawl()

/datum/element/table_crawl/proc/on_buckled_change(mob/living/carbon/human/source, ...)
	SIGNAL_HANDLER
	source.refresh_table_crawl()
