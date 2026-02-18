#define RONIN_STACK_TICK             (1 SECONDS)
#define RONIN_MAX_STACKS_NORMAL      5
#define RONIN_MAX_STACKS_OVERDRIVE   20
#define RONIN_OVERDRIVE_DURATION     (5 SECONDS)
#define RONIN_FORCE_PER_STACK        0.02

#define RONIN_GLOW_BOUND_FILTER    "ronin_bound_glow"
#define RONIN_GLOW_PREP_FILTER     "ronin_prepared_glow"

#define RONIN_GLOW_BOUND_COLOR     "#FFD54A"  // жёлтый
#define RONIN_GLOW_PREP_COLOR      "#FF3B3B"  // красный

#define RONIN_GLOW_SIZE_BOUND      1.5
#define RONIN_GLOW_SIZE_PREP       2

/proc/ronin_on_dodge_success(mob/living/defender)
	if(!isliving(defender))
		return
	SEND_SIGNAL(defender, COMSIG_MOB_DODGE_SUCCESS)

/datum/component/combo_core/ronin
	parent_type = /datum/component/combo_core
	dupe_mode = COMPONENT_DUPE_UNIQUE

	// stacks live here
	var/ronin_stacks = 0
	var/next_stack_tick = 0
	var/overdrive_until = 0

	// binding
	var/list/bound_blades = list()

	// cached held blade
	var/obj/item/rogueweapon/active_blade = null

	// minor: input подтверждается только успешным ударом
	var/pending_hit_input = null

	// cache base force for +2% per stack safely
	var/list/base_force_cache = list()
	var/list/base_ap_cache = list()

	// counter stance
	var/in_counter_stance = FALSE
	var/counter_expires_at = 0

	// spells
	var/list/granted_spells = list()
	var/spells_granted = FALSE

	var/obj/item/rogueweapon/listened_blade = null

	/// Tanuki (minor): +4 PER на 4 успешных удара
	var/tanuki_per_hits_left = 0

	/// Tanuki (elder): riposte triggers on 4th successful hit
	var/elder_tanuki_riposte_hits_left = 0
// ----------------------------------------------------
// INIT / DESTROY
// ----------------------------------------------------

/datum/component/combo_core/ronin/Initialize(_combo_window, _max_history)
	. = ..(_combo_window, _max_history)
	if(. == COMPONENT_INCOMPATIBLE)
		return .

	START_PROCESSING(SSprocessing, src)

	RegisterSignal(owner, COMSIG_ATTACK_TRY_CONSUME, PROC_REF(_sig_try_consume), override = TRUE)
	RegisterSignal(owner, COMSIG_COMBO_CORE_REGISTER_INPUT, PROC_REF(_sig_register_input), override = TRUE)
	RegisterSignal(owner, COMSIG_MOB_DODGE_SUCCESS, PROC_REF(_sig_dodge_success), override = TRUE)

	GrantSpells()
	return .

/datum/component/combo_core/ronin/Destroy(force)
	STOP_PROCESSING(SSprocessing, src)

	if(bound_blades?.len)
		for(var/obj/item/rogueweapon/W as anything in bound_blades)
			// снять глоу
			if(W && !QDELETED(W) && hascall(W, "remove_filter"))
				call(W, "remove_filter")(RONIN_GLOW_BOUND_FILTER)
				call(W, "remove_filter")(RONIN_GLOW_PREP_FILTER)

	if(listened_blade && !QDELETED(listened_blade))
		UnregisterSignal(listened_blade, COMSIG_ITEM_ATTACK_SUCCESS)
	
	if(owner)
		UnregisterSignal(owner, COMSIG_ATTACK_TRY_CONSUME)
		UnregisterSignal(owner, COMSIG_COMBO_CORE_REGISTER_INPUT)
		UnregisterSignal(owner, COMSIG_MOB_DODGE_SUCCESS)
		RevokeSpells()

	RestoreAllBoundForces()

	owner = null
	listened_blade = null
	active_blade = null
	pending_hit_input = null
	bound_blades.Cut()
	base_force_cache = null
	return ..()

// ----------------------------------------------------
// PROCESSING: stack gain + force update
// ----------------------------------------------------

/datum/component/combo_core/ronin/process()
	if(world.time < next_stack_tick)
		return

	next_stack_tick = world.time + RONIN_STACK_TICK

	var/overdrive = (world.time < overdrive_until)
	if(owner.cmode)
		if(overdrive)
			ronin_stacks = min(ronin_stacks + 2, RONIN_MAX_STACKS_OVERDRIVE)
		else
			ronin_stacks = min(ronin_stacks + 1, RONIN_MAX_STACKS_NORMAL)

	ApplyBoundForceMultiplier()

// ----------------------------------------------------
// SPELLS
// ----------------------------------------------------

/datum/component/combo_core/ronin/proc/GrantSpells()
	if(spells_granted || !owner?.mind)
		return

	var/mob/living/L = owner
	RevokeSpells()

	var/list/paths = list(
		/obj/effect/proc_holder/spell/self/ronin/horizontal,
		/obj/effect/proc_holder/spell/self/ronin/vertical,
		/obj/effect/proc_holder/spell/self/ronin/diagonal,
		/obj/effect/proc_holder/spell/self/ronin/blade_path,
		/obj/effect/proc_holder/spell/self/ronin/bind_blade
	)

	for(var/path in paths)
		var/obj/effect/proc_holder/spell/S = new path
		L.mind.AddSpell(S)
		granted_spells += S

	spells_granted = TRUE

/datum/component/combo_core/ronin/proc/RevokeSpells()
	if(!owner)
		return
	if(!granted_spells || !granted_spells.len)
		spells_granted = FALSE
		return

	if(owner.mind)
		for(var/obj/effect/proc_holder/spell/S as anything in granted_spells)
			if(S)
				owner.mind.RemoveSpell(S)
	else
		for(var/obj/effect/proc_holder/spell/S as anything in granted_spells)
			if(S)
				qdel(S)

	granted_spells.Cut()
	spells_granted = FALSE

/datum/component/combo_core/ronin/proc/_ronin_apply_weapon_glow(obj/item/rogueweapon/W)
	if(!W || QDELETED(W))
		return

	var/is_prepared = !!W.ronin_prepared_combo
	var/is_bound = (W in bound_blades)

	// снять старые
	W.remove_filter(RONIN_GLOW_BOUND_FILTER)
	W.remove_filter(RONIN_GLOW_PREP_FILTER)

	// красный > жёлтый
	if(is_prepared)
		W.add_filter(
			RONIN_GLOW_PREP_FILTER,
			1,
			list(
				"type"="drop_shadow",
				"x"=0,
				"y"=0,
				"size"=RONIN_GLOW_SIZE_PREP,
				"color"=RONIN_GLOW_PREP_COLOR
			)
		)
	else if(is_bound)
		W.add_filter(
			RONIN_GLOW_BOUND_FILTER,
			1,
			list(
				"type"="drop_shadow",
				"x"=0,
				"y"=0,
				"size"=RONIN_GLOW_SIZE_BOUND,
				"color"=RONIN_GLOW_BOUND_COLOR
			)
		)
/datum/component/combo_core/ronin/proc/_ronin_refresh_all_weapon_glows()
	if(!bound_blades || !bound_blades.len)
		return
	for(var/obj/item/rogueweapon/W as anything in bound_blades)
		_ronin_apply_weapon_glow(W)

// ----------------------------------------------------
// COMBO RULES
// ----------------------------------------------------

/datum/component/combo_core/ronin/DefineRules()
	RegisterRule("ryu",     list(1,2,3), 50, PROC_REF(_cb_combo))
	RegisterRule("kitsune", list(2,1,3), 40, PROC_REF(_cb_combo))
	RegisterRule("tengu",   list(3,1,2), 30, PROC_REF(_cb_combo))
	RegisterRule("tanuki",  list(1,1,2), 30, PROC_REF(_cb_combo))

/datum/component/combo_core/ronin/proc/_cb_combo(rule_id, mob/living/target, zone)
	// если клинок НЕ в руке (или не bound) — это elder-запоминание
	if(!HasDrawnBoundBlade())
		return StoreElderCombo(rule_id)

	// если клинок в руке — это minor-комбо (срабатывает сразу после того удара,
	// который подтвердил последний ввод)
	return ExecuteMinorCombo(rule_id, target, zone)


// ----------------------------------------------------
// STACKS + FORCE
// ----------------------------------------------------

#define RONIN_TANUKI_PER_BONUS 4
#define RONIN_TANUKI_PER_HITS  4

/datum/component/combo_core/ronin/proc/_GetBladeForce()
	// Берём текущую силу клинка (у тебя она уже бафается через стеки в ApplyBoundForceMultiplier)
	UpdateActiveBlade()
	if(active_blade)
		return max(0, active_blade.force)
	return 0

/datum/component/combo_core/ronin/proc/_GetAimDirTo(atom/A)
	if(!owner)
		return SOUTH
	if(!A)
		return owner.dir
	var/turf/ot = get_turf(owner)
	var/turf/tt = get_turf(A)
	if(!ot || !tt)
		return owner.dir
	var/d = get_dir(ot, tt)
	return d ? d : owner.dir

/datum/component/combo_core/ronin/proc/_Knockback(mob/living/target, tiles, dir_override = null)
	if(!owner || !target || tiles <= 0)
		return
	var/d = dir_override || get_dir(owner, target)
	if(!d)
		d = owner.dir
	var/turf/start = get_turf(target)
	if(!start)
		return
	var/turf/dest = get_ranged_target_turf(start, d, tiles)
	if(dest)
		target.safe_throw_at(dest, tiles, 1, owner, force = MOVE_FORCE_STRONG)

/datum/component/combo_core/ronin/proc/_ApplyBurnFromForce(mob/living/target, zone, mult = 0.5)
	if(!target)
		return
	var/force = _GetBladeForce()
	if(force <= 0)
		return
	var/burn = max(1, round(force * mult))

	// /tg usually has apply_damage(); if your fork differs – swap this hook.
	if(hascall(target, "apply_damage"))
		target.apply_damage(burn, BURN, zone)
	else
		// fallback (less correct, but безопасно)
		if(hascall(target, "adjustFireLoss"))
			target.adjustFireLoss(burn)

/datum/component/combo_core/ronin/proc/_ApplyBleed(mob/living/target, severity = 4)
	if(!target)
		return
	// TODO: your codebase hook for bleeding stacks/severity
	// Примеры (замени на то, что у вас реально есть):
	// target.apply_status_effect(/datum/status_effect/debuff/bleeding, severity)
	// или target.AddWound(/datum/wound/slash, severity)
	if(hascall(target, "apply_status_effect"))
		target.apply_status_effect(/datum/status_effect/debuff/bleeding, severity)
	else
		// мягкий fallback: просто сообщение (чтобы хоть видно было, что сработало)
		to_chat(owner, span_warning("[target] starts bleeding (severity [severity])!"))

/datum/component/combo_core/ronin/proc/_ApplyArmorWearForward(mult = 0.5, tiles = 2, zone = BODY_ZONE_CHEST)
	if(!owner)
		return
	var/force = _GetBladeForce()
	if(force <= 0)
		return

	var/d = owner.dir
	var/turf/T = get_turf(owner)
	if(!T)
		return

	// износ брони как в soundbreaker-логике (упрощённо)
	for(var/i in 1 to tiles)
		T = get_step(T, d)
		if(!T)
			break

		for(var/mob/living/carbon/human/H in T)
			if(H == owner)
				continue

			// в soundbreaker ты делал более умно по armor.getRating, тут — тот же паттерн:
			_apply_combo_armor_wear_simple(H, zone, "slash", force, mult)

/datum/component/combo_core/ronin/proc/_apply_combo_armor_wear_simple(mob/living/carbon/human/target, hit_zone, attack_flag, force_dynamic, multiplier = 1)
	if(!target || !attack_flag || !force_dynamic)
		return

	var/wear = round(force_dynamic * multiplier)
	wear = clamp(wear, 1, 25)
	if(wear <= 0)
		return

	var/cover_flag
	switch(hit_zone)
		if(BODY_ZONE_HEAD)   cover_flag = HEAD
		if(BODY_ZONE_CHEST)  cover_flag = CHEST
		if(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM) cover_flag = ARMS
		if(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG) cover_flag = LEGS
		else
			cover_flag = CHEST

	for(var/obj/item/clothing/C in target.contents)
		if(C.loc != target)
			continue
		if(!(C.body_parts_covered & cover_flag))
			continue
		if(!C.armor)
			continue

		var/rating = C.armor.getRating(attack_flag)
		if(!isnum(rating) || rating <= 0)
			continue

		C.take_damage(wear, BRUTE, "slash")

/datum/component/combo_core/ronin/proc/_DashSlashTengu(mob/living/target, zone)
	if(!owner || !target)
		return

	var/force = _GetBladeForce()
	if(force <= 0)
		return

	var/turf/start = get_turf(owner)
	if(!start)
		return

	var/d = get_dir(owner, target)
	if(!d)
		d = owner.dir

	// простая версия "как у soundbreaker": шаг 1-2 тайла, и на каждом пытаемся порезать
	var/turf/t1 = get_step(start, d)
	if(!t1 || t1.density)
		return

	var/turf/t2 = get_step(t1, d)
	// если второй заблокирован, просто делаем первый

	owner.forceMove(t1)
	_RonSlashOnTurf(t1, force, zone)

	if(t2 && !t2.density)
		owner.forceMove(t2)
		_RonSlashOnTurf(t2, force, zone)

/datum/component/combo_core/ronin/proc/_RonSlashOnTurf(turf/T, force, zone)
	if(!T)
		return
	var/mob/living/victim = null
	for(var/mob/living/L in T)
		if(L == owner)
			continue
		if(L.stat == DEAD)
			continue
		victim = L
		break

	if(!victim)
		return

	// 2 пореза = 2 раза “режущего” урона, упрощённо через apply_damage/adjustBruteLoss
	for(var/i in 1 to 2)
		var/dmg = max(1, round(force * 0.35))
		if(hascall(victim, "apply_damage"))
			victim.apply_damage(dmg, BRUTE, zone)
		else if(hascall(victim, "adjustBruteLoss"))
			victim.adjustBruteLoss(dmg)

	_ApplyBleed(victim, 4)

// ----------------------------------------------------
// Tanuki: PER buff counters
// ----------------------------------------------------

/datum/component/combo_core/ronin/proc/_StartTanukiPerBuff()
	tanuki_per_hits_left = RONIN_TANUKI_PER_HITS
	// TODO: your stat system hook (PER +4)
	// Примерные варианты:
	// owner.AddStatBuff(STATKEY_PER, RONIN_TANUKI_PER_BONUS, "ronin_tanuki")
	// owner.add_stat_modifier("ronin_tanuki", STATKEY_PER, RONIN_TANUKI_PER_BONUS)
	to_chat(owner, span_notice("Tanuki's insight: +[RONIN_TANUKI_PER_BONUS] PER for [RONIN_TANUKI_PER_HITS] hits."))

/datum/component/combo_core/ronin/proc/_EndTanukiPerBuff()
	if(tanuki_per_hits_left <= 0)
		return
	tanuki_per_hits_left = 0
	// TODO: remove stat buff hook
	// owner.RemoveStatBuff("ronin_tanuki")
	to_chat(owner, span_notice("Tanuki's insight fades."))

/datum/component/combo_core/ronin/proc/_HandleTanukiPerOnHit()
	if(tanuki_per_hits_left <= 0)
		return
	tanuki_per_hits_left--
	if(tanuki_per_hits_left <= 0)
		_EndTanukiPerBuff()

/datum/component/combo_core/ronin/proc/_StartElderTanukiRiposte()
	elder_tanuki_riposte_hits_left = 4
	to_chat(owner, span_notice("Tanuki's riposte is set: triggers on the 4th hit."))

/datum/component/combo_core/ronin/proc/_HandleElderTanukiRiposteOnHit(mob/living/target, zone)
	if(elder_tanuki_riposte_hits_left <= 0)
		return
	elder_tanuki_riposte_hits_left--
	if(elder_tanuki_riposte_hits_left > 0)
		return

	elder_tanuki_riposte_hits_left = 0

	if(!owner || !target)
		return

	var/force = _GetBladeForce()
	var/extra = max(1, round(force * 0.5))

	// “рипост” — тут делаю ощутимый бонус: доп.урон + короткий стан
	if(hascall(target, "apply_damage"))
		target.apply_damage(extra, BRUTE, zone)
	else if(hascall(target, "adjustBruteLoss"))
		target.adjustBruteLoss(extra)

	target.Stun(1 SECONDS)

	owner.visible_message(
		span_danger("[owner] answers with a perfect riposte!"),
		span_notice("Riposte!"),
	)

#undef RONIN_TANUKI_PER_BONUS
#undef RONIN_TANUKI_PER_HITS

/datum/component/combo_core/ronin/proc/GetStackMultiplier()
	return 1 + (ronin_stacks * RONIN_FORCE_PER_STACK)

/datum/component/combo_core/ronin/proc/CacheBaseForce(obj/item/rogueweapon/W)
	if(!W)
		return
	if(!islist(base_force_cache))
		base_force_cache = list()
	if(isnull(base_force_cache[W]))
		base_force_cache[W] = W.force
	if(!islist(base_ap_cache))
		base_ap_cache = list()
	if(isnull(base_ap_cache[W]))
		base_ap_cache[W] = W.armor_penetration

/datum/component/combo_core/ronin/proc/ApplyBoundForceMultiplier()
	if(!bound_blades || !bound_blades.len)
		return

	var/mult = GetStackMultiplier()

	for(var/obj/item/rogueweapon/W as anything in bound_blades)
		if(!W || QDELETED(W))
			continue
		CacheBaseForce(W)
		var/base = base_force_cache[W]
		if(isnum(base))
			W.force = round(base * mult, 1)
			W.armor_penetration = round(base_ap_cache * mult, 1)

/datum/component/combo_core/ronin/proc/RestoreAllBoundForces()
	if(!islist(base_force_cache))
		return
	for(var/obj/item/rogueweapon/W as anything in base_force_cache)
		if(!W || QDELETED(W))
			continue
		var/base = base_force_cache[W]
		if(isnum(base))
			W.force = base


// ----------------------------------------------------
// ACTIVE BLADE
// ----------------------------------------------------

/datum/component/combo_core/ronin/proc/UpdateActiveBlade()
	active_blade = null
	if(!owner)
		return

	var/obj/item/I = owner.get_active_held_item()
	if(istype(I, /obj/item/rogueweapon))
		active_blade = I

/datum/component/combo_core/ronin/proc/HasDrawnBoundBlade()
	UpdateActiveBlade()
	return (active_blade && (active_blade in bound_blades))


// ----------------------------------------------------
// ELDER STORAGE (cycle between sheathed bound blades)
// ----------------------------------------------------

/datum/component/combo_core/ronin/proc/GetNextElderBlade()
	if(!bound_blades || !bound_blades.len)
		return null

	var/obj/item/rogueweapon/oldest = null
	var/oldest_time = INFINITY

	for(var/obj/item/rogueweapon/W as anything in bound_blades)
		if(!W || QDELETED(W))
			continue

		// пишем elder только если клинок реально в ножнах
		if(!istype(W.loc, /obj/item/rogueweapon/scabbard))
			continue

		// свободный клинок — берём сразу
		if(!W.ronin_prepared_combo)
			return W

		// иначе: выбираем самый старый для перезаписи (и будет “по кругу”)
		if(W.ronin_prepared_at < oldest_time)
			oldest_time = W.ronin_prepared_at
			oldest = W

	return oldest

/datum/component/combo_core/ronin/proc/StoreElderCombo(rule_id)
	if(!owner || !rule_id)
		return FALSE

	var/obj/item/rogueweapon/W = GetNextElderBlade()
	if(!W)
		return FALSE

	W.ronin_prepared_combo = rule_id
	W.ronin_prepared_at = world.time
	_ronin_apply_weapon_glow(W)

	var/icon_file = 'modular_twilight_axis/icons/roguetown/misc/roninspells.dmi'
	var/icon_state = null
	switch(rule_id)
		if("ryu") icon_state = "ronin_ryu"
		if("tanuki") icon_state = "ronin_tanuki"
		if("tengu") icon_state = "ronin_tengu"
		if("kitsune") icon_state = "ronin_kitsune"

	_ronin_overhead(owner, icon_file, icon_state, 2.0 SECONDS, 20)
	to_chat(owner, span_notice("Elder prepared: [rule_id] -> [W]."))
	return TRUE


// ----------------------------------------------------
// MINOR / ELDER EXECUTION
// ----------------------------------------------------

/datum/component/combo_core/ronin/proc/ExecuteMinorCombo(rule_id, mob/living/target, zone)
	if(!owner || !target || !rule_id)
		return FALSE

	switch(rule_id)
		if("ryu")
			// +50% force в ожогах
			_ApplyBurnFromForce(target, zone, 0.5)

		if("kitsune")
			// отталкивает на 2 тайла вперёд
			var/d = _GetAimDirTo(target)
			_Knockback(target, 2, d)

		if("tanuki")
			// +4 PER на 4 удара
			_StartTanukiPerBuff()

		if("tengu")
			// кровотечение 4
			_ApplyBleed(target, 4)

	ShowMinorComboIcon(target, rule_id)
	owner.visible_message(
		span_danger("[owner] executes a minor ronin technique!"),
		span_notice("Minor technique: [rule_id]."),
	)

	return TRUE

/datum/component/combo_core/ronin/proc/ExecuteElderCombo(rule_id, mob/living/target, zone)
	if(!owner || !rule_id)
		return

	switch(rule_id)
		if("ryu")
			// сравнить stamina врага с силой клинка
			if(!target)
				return

			var/force = _GetBladeForce()
			var/stam = null
			if(isnum(target.stamina))
				stam = target.stamina

			// если stamina неизвестна — хотя бы не ломаемся
			if(isnull(stam))
				target.OffBalance(1.5 SECONDS)
			else if(force > stam)
				target.OffBalance(2 SECONDS)
			else
				// иначе +2 к силе (я трактую как +2 стека ронина = +4% force, честно/красиво)
				ronin_stacks = min(ronin_stacks + 2, RONIN_MAX_STACKS_OVERDRIVE)
				ApplyBoundForceMultiplier()
				to_chat(owner, span_notice("Ryu hardens your edge (+2 stacks)."))

		if("kitsune")
			// +50% force по броне вперед на 2 тайла (износ брони)
			_ApplyArmorWearForward(0.5, 2, zone)

		if("tanuki")
			// рипост на 4 ударе
			_StartElderTanukiRiposte()

		if("tengu")
			// рывок как у брейкера, 2 пореза
			if(target)
				_DashSlashTengu(target, zone)

	owner.visible_message(
		span_danger("[owner] releases an elder ronin technique!"),
		span_notice("Elder technique: [rule_id]."),
	)

// ----------------------------------------------------
// COUNTER STANCE
// ----------------------------------------------------

/datum/component/combo_core/ronin/proc/EnterCounterStance()
	if(in_counter_stance)
		return
	UpdateActiveBlade()
	if(active_blade) // если меч в руке — стойка не нужна
		return

	in_counter_stance = TRUE
	counter_expires_at = world.time + RONIN_COUNTER_WINDOW

/datum/component/combo_core/ronin/proc/ExitCounterStance()
	in_counter_stance = FALSE
	counter_expires_at = 0

/datum/component/combo_core/ronin/proc/CheckCounterExpire()
	if(in_counter_stance && world.time >= counter_expires_at)
		ExitCounterStance()


// ----------------------------------------------------
// SIGNALS
// ----------------------------------------------------

/datum/component/combo_core/ronin/proc/_sig_try_consume(datum/source, atom/target_atom, zone)
	SIGNAL_HANDLER

	// всегда -1 стак на попытку атаки
	if(ronin_stacks > 0)
		ronin_stacks--
		ApplyBoundForceMultiplier()

	// Tanuki (minor): считаем "4 удара" как 4 атаки (а не 4 успешных хита)
	if(tanuki_per_hits_left > 0)
		tanuki_per_hits_left--
		if(tanuki_per_hits_left <= 0)
			_EndTanukiPerBuff()

	// Tanuki (elder): "рипост на 4 ударе" как 4 атаки
	if(elder_tanuki_riposte_hits_left > 0)
		elder_tanuki_riposte_hits_left--
		if(elder_tanuki_riposte_hits_left <= 0)
			elder_tanuki_riposte_hits_left = 0
			// ВАЖНО: триггер рипоста тут только если у нас есть валидная цель
			// try_consume может быть без моба-цели, так что используем target_atom.
			var/mob/living/L = target_atom
			if(isliving(L))
				_HandleElderTanukiRiposteOnHit(L, zone)

	return 0

/datum/component/combo_core/ronin/proc/_sig_item_attack_success(datum/source, mob/living/target, mob/living/user)
	SIGNAL_HANDLER
	if(user != owner)
		return

	// успешный удар включает overdrive на 5 секунд
	overdrive_until = max(overdrive_until, world.time + RONIN_OVERDRIVE_DURATION)

	// minor: подтвердить ввод и засчитать в history
	if(pending_hit_input)
		var/icon_file = 'modular_twilight_axis/icons/roguetown/misc/roninspells.dmi'
		var/icon_state = null
		switch(pending_hit_input)
			if(1) icon_state = "ch_input"
			if(2) icon_state = "cv_input"
			if(3) icon_state = "cd_input"
		_ronin_overhead(owner, icon_file, icon_state, 1.5 SECONDS, 20)
		to_chat(owner, span_notice("Minor confirmed on hit: [pending_hit_input]."))
		RegisterInput(pending_hit_input, target, user.zone_selected)
		pending_hit_input = null

	// elder: если записано на клинке — сработать и очистить
	// source == listened_blade == active_blade (обычно)
	var/obj/item/rogueweapon/W = source
	if(istype(W) && W.ronin_prepared_combo)
		var/rule_id = W.ronin_prepared_combo
		W.ronin_prepared_combo = null
		W.ronin_prepared_at = 0
		_ronin_apply_weapon_glow(W)
		to_chat(owner, span_danger("ELDER COMBO RELEASED: [rule_id] (stacks=[ronin_stacks])!"))
		ExecuteElderCombo(rule_id, target, user.zone_selected)

/datum/component/combo_core/ronin/_sig_register_input(datum/source, skill_id, mob/living/target, zone)
	if(!owner || !skill_id)
		return 0

	INVOKE_ASYNC(src, PROC_REF(_async_register_input), skill_id, target, zone)
	return COMPONENT_COMBO_ACCEPTED

/datum/component/combo_core/ronin/proc/_async_register_input(skill_id, mob/living/target, zone)
	if(QDELETED(src) || !owner || QDELETED(owner) || !skill_id)
		return

	if(HasDrawnBoundBlade())
		pending_hit_input = skill_id
		to_chat(owner, span_notice("Minor queued: [skill_id] (stacks=[ronin_stacks]). Hit to confirm."))
		return

	RegisterInput(skill_id, null, zone)

/// dodge в стойке: если меч не вынут — quickdraw + хук "мгновенный удар"
/datum/component/combo_core/ronin/proc/_sig_dodge_success(datum/source)
	SIGNAL_HANDLER
	CheckCounterExpire()

	if(!in_counter_stance)
		return

	UpdateActiveBlade()
	if(!active_blade)
		if(QuickDraw(FALSE))
			TryCounterInstantStrike()

	in_counter_stance = FALSE

/datum/component/combo_core/ronin/proc/UpdateAttackSuccessListener()
	// снимаем старую подписку
	if(listened_blade && !QDELETED(listened_blade))
		UnregisterSignal(listened_blade, COMSIG_ITEM_ATTACK_SUCCESS)
	listened_blade = null

	// вешаем новую, если в руке bound клинок
	UpdateActiveBlade()
	if(active_blade && (active_blade in bound_blades))
		listened_blade = active_blade
		RegisterSignal(listened_blade, COMSIG_ITEM_ATTACK_SUCCESS, PROC_REF(_sig_item_attack_success))

/datum/component/combo_core/ronin/proc/TryCounterInstantStrike()
	// ХУК: тут делай авто-удар тем пайплайном, который у вас принят.
	return

/datum/component/combo_core/ronin/proc/QuickDraw(consume_stacks = FALSE)
	if(!owner || !bound_blades.len)
		return FALSE

	var/obj/item/rogueweapon/W = bound_blades[bound_blades.len]
	if(!W)
		return FALSE
	if(!istype(W.loc, /obj/item/rogueweapon/scabbard))
		return FALSE

	var/free_hand = 0
	if(owner.get_item_for_held_index(1) == null)
		free_hand = 1
	else if(owner.get_item_for_held_index(2) == null)
		free_hand = 2
	if(!free_hand)
		return FALSE

	var/obj/item/rogueweapon/scabbard/S = W.loc

	if(S.sheathed == W)
		S.sheathed = null
	S.update_icon(owner)

	W.forceMove(owner.loc)
	W.pickup(owner)
	owner.put_in_hand(W, free_hand)

	active_blade = W
	UpdateAttackSuccessListener()

	// consume_stacks теперь означает: обнулить СТАКИ РОНИНА, а не оружия
	if(consume_stacks)
		ronin_stacks = 0
		ApplyBoundForceMultiplier()

	// elder на выхвате по твоему описанию НЕ обязан сразу срабатывать,
	// но если хочешь "сбрасывать" — можешь сбросить тут:
	// (я бы не сбрасывал, пусть сработает на следующем успешном ударе)

	return TRUE

/datum/component/combo_core/ronin/proc/ReturnToSheath()
	if(!owner)
		return FALSE

	UpdateActiveBlade()
	UpdateAttackSuccessListener()
	if(!active_blade)
		return FALSE

	var/obj/item/rogueweapon/scabbard/S = null
	for(var/obj/item/rogueweapon/scabbard/scab in owner.contents)
		if(scab.weapon_check(owner, active_blade))
			S = scab
			break

	if(!S)
		return FALSE

	if(active_blade.loc == owner)
		owner.dropItemToGround(active_blade)

	active_blade.forceMove(S)
	S.sheathed = active_blade
	S.update_icon(owner)

	active_blade = null
	return TRUE

/datum/component/combo_core/ronin/proc/BindBlade(obj/item/rogueweapon/W)
	if(!owner || !W)
		return FALSE

	if(W in bound_blades)
		bound_blades -= W

	if(bound_blades.len >= 2)
		var/obj/item/rogueweapon/old = bound_blades[1]
		bound_blades.Cut(1, 2)
		if(old)
			RestoreOneForce(old)

	bound_blades += W
	_ronin_apply_weapon_glow(W)
	CacheBaseForce(W)
	ApplyBoundForceMultiplier()
	UpdateAttackSuccessListener()

	to_chat(owner, span_notice("You bind [W] to your path."))
	return TRUE

/datum/component/combo_core/ronin/proc/RestoreOneForce(obj/item/rogueweapon/W)
	if(!W || !islist(base_force_cache))
		return
	if(isnull(base_force_cache[W]))
		return
	var/base = base_force_cache[W]
	if(isnum(base))
		W.force = base
	base_force_cache -= W

/datum/component/combo_core/ronin/proc/ShowMinorComboIcon(mob/living/target, rule_id)
	if(!target || !rule_id)
		return

	var/icon_file = 'modular_twilight_axis/icons/roguetown/misc/roninspells.dmi'
	var/icon_state = null

	switch(rule_id)
		if("ryu") icon_state = "ronin_ryu"
		if("tanuki") icon_state = "ronin_tanuki"
		if("tengu") icon_state = "ronin_tengu"
		if("kitsune") icon_state = "ronin_kitsune"

	_ronin_overhead(target, icon_file, icon_state, 1.0 SECONDS, 20)

/datum/component/combo_core/ronin/proc/_ronin_overhead(mob/living/M, icon_file, icon_state, dur = 0.7 SECONDS, pixel_y = 20)
	if(!M || !icon_file || !icon_state)
		return
	M.play_overhead_indicator_flick(icon_file, icon_state, dur, ABOVE_MOB_LAYER + 0.3, null, pixel_y)
