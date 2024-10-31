GLOBAL_LIST_INIT(name2reagent, build_name2reagent())

/proc/build_name2reagent()
	. = list()
	for (var/t in subtypesof(/datum/reagent))
		var/datum/reagent/R = t
		if (length(initial(R.name)))
			.[ckey(initial(R.name))] = t


/datum/reagent
	abstract_type = /datum/reagent

	//* Core
	/// id - must be unique and in CamelCase.
	var/id
	/// reagent flags - see [code/__DEFINES/reagents/flags.dm]
	var/reagent_flags = NONE

	//* Identity
	/// our name - visible from guidebooks and to admins
	var/name = "Reagent"
	/// our description - visible from guidebooks and to admins
	var/description = "A non-descript chemical of some kind."
	/// player-facing name - visible via scan tools
	/// defaults to [name]
	/// overrides name in guidebook
	var/display_name
	/// player-facing desc - visible via scan tools
	/// defaults to [desc]
	/// overrides desc in guidebook
	var/display_description

	//* Guidebook
	/// guidebook flags
	var/reagent_guidebook_flags = NONE
	/// guidebook category
	var/reagent_guidebook_category = "Unsorted"

	//? legacy / unsorted
	var/taste_description = "bitterness"
	/// How this taste compares to others. Higher values means it is more noticable
	var/taste_mult = 1
	var/datum/reagent_holder/holder = null
	var/reagent_state = REAGENT_SOLID
	var/list/data = null
	var/volume = 0
	var/metabolism = REM // This would be 0.2 normally
	/// Used for vampric-Digestion
	var/blood_content = 0
	/// Organs that will slow the processing of this chemical.
	var/list/filtered_organs = list()
	///If the reagent should always process at the same speed, regardless of species, make this TRUE
	var/mrate_static = FALSE
	var/ingest_met = 0
	var/touch_met = 0
	var/dose = 0
	var/max_dose = 0
	///Amount at which overdose starts
	var/overdose = 0
	///Modifier to overdose damage
	var/overdose_mod = 2
	/// Can the chemical OD when processing on touch?
	var/can_overdose_touch = FALSE
	/// Shows up on health analyzers.
	var/scannable = 0
	/// Does this chem process inside a corpse?
	var/affects_dead = 0
	/// Does this chem process inside a Synth?
	var/affects_robots = 0
	var/cup_icon_state = null
	var/cup_name = null
	var/cup_desc = null
	var/cup_center_of_mass = null

	var/color = "#000000"
	var/color_weight = 1

	var/glass_icon = DRINK_ICON_DEFAULT
	var/glass_name = "something"
	var/glass_desc = "It's a glass of... what, exactly?"
	var/list/glass_special = null // null equivalent to list()

	//? Economy
	/// Raw intrinsic worth of this reagent
	var/worth = 0
	/// economic category of the reagent
	var/economic_category_reagent = ECONOMIC_CATEGORY_REAGENT_DEFAULT

	//? wiki markup generation additional
	/// override "name"
	var/wiki_name
	/// override "desc"
	var/wiki_desc
	/// wiki category - determines what table to put it into
	var/wiki_category = "Miscellaneous"
	/// forced sort ordering in its category - falls back to name otherwise.
	var/wiki_sort = 0

/datum/reagent/proc/remove_self(var/amount) // Shortcut
	if(holder)
		holder.remove_reagent(id, amount)

/// This doesn't apply to skin contact - this is for, e.g. extinguishers and sprays. The difference is that reagent is not directly on the mob's skin - it might just be on their clothing.
/datum/reagent/proc/touch_mob(mob/M, amount)
	return

/// Acid melting, cleaner cleaning, etc
/datum/reagent/proc/touch_obj(obj/O, amount)
	return

/// Cleaner cleaning, lube lubbing, etc, all go here
/datum/reagent/proc/touch_turf(turf/T, amount)
	return

/// Currently, on_mob_life is called on carbons. Any interaction with non-carbon mobs (lube) will need to be done in touch_mob.
/datum/reagent/proc/on_mob_life(var/mob/living/carbon/M, var/alien, var/datum/reagent_holder/metabolism/location, speed_mult = 1, force_allow_dead)
	if(!istype(M))
		return
	if(!affects_dead && M.stat == DEAD && !force_allow_dead)
		return
	if(!affects_robots && M.isSynthetic())
		return
	if(!istype(location))
		return

	var/datum/reagent_holder/metabolism/active_metab = location
	var/removed = metabolism
	var/mechanical_circulation = HAS_TRAIT(M, TRAIT_MECHANICAL_CIRCULATION)

	var/ingest_rem_mult = 1
	var/ingest_abs_mult = 1

	if(!mrate_static == TRUE)
		// Modifiers
		for(var/datum/modifier/mod in M.modifiers)
			if(!isnull(mod.metabolism_percent))
				removed *= mod.metabolism_percent
				ingest_rem_mult *= mod.metabolism_percent
		// Species
		removed *= M.species.metabolic_rate
		ingest_rem_mult *= M.species.metabolic_rate
		// Metabolism
		removed *= active_metab.metabolism_speed
		ingest_rem_mult *= active_metab.metabolism_speed
		// hard mult
		removed *= speed_mult
		ingest_rem_mult *= speed_mult

		if(ishuman(M))
			var/mob/living/carbon/human/H = M
			if(!H.isSynthetic())
				if(H.species.has_organ[O_HEART] && (active_metab.metabolism_class == CHEM_INJECT))
					var/obj/item/organ/internal/heart/Pump = H.internal_organs_by_name[O_HEART]
					// todo: completely optimize + refactor metabolism, none of these checks should be in here
					if(mechanical_circulation)
						// no bad heart penalties
					else if(!Pump)
						removed *= 0.1
					else if(Pump.standard_pulse_level == PULSE_NONE) // No pulse normally means chemicals process a little bit slower than normal.
						removed *= 0.8
					else // Otherwise, chemicals process as per percentage of your current pulse, or, if you have no pulse but are alive, by a miniscule amount.
						removed *= max(0.1, H.pulse / Pump.standard_pulse_level)

				if(H.species.has_organ[O_STOMACH] && (active_metab.metabolism_class == CHEM_INGEST))
					var/obj/item/organ/internal/stomach/Chamber = H.internal_organs_by_name[O_STOMACH]
					if(Chamber)
						ingest_rem_mult *= max(0.1, 1 - (Chamber.damage / Chamber.max_damage))
					else
						ingest_rem_mult = 0.1

				if(H.species.has_organ[O_INTESTINE] && (active_metab.metabolism_class == CHEM_INGEST))
					var/obj/item/organ/internal/intestine/Tube = H.internal_organs_by_name[O_INTESTINE]
					if(Tube)
						ingest_abs_mult *= max(0.1, 1 - (Tube.damage / Tube.max_damage))
					else
						ingest_abs_mult = 0.1

			else
				var/obj/item/organ/internal/heart/machine/Pump = H.internal_organs_by_name[O_PUMP]
				var/obj/item/organ/internal/stomach/machine/Cycler = H.internal_organs_by_name[O_CYCLER]

				if(active_metab.metabolism_class == CHEM_INJECT)
					if(Pump)
						removed *= 1.1 - Pump.damage / Pump.max_damage
					else
						removed *= 0.1

				else if(active_metab.metabolism_class == CHEM_INGEST) // If the pump is damaged, we waste chems from the tank.
					if(Pump)
						ingest_abs_mult *= max(0.25, 1 - Pump.damage / Pump.max_damage)

					else
						ingest_abs_mult *= 0.2

					if(Cycler) // If we're damaged, we empty our tank slower.
						ingest_rem_mult = max(0.1, 1 - (Cycler.damage / Cycler.max_damage))

					else
						ingest_rem_mult = 0.1

				else if(active_metab.metabolism_class == CHEM_TOUCH) // Machines don't exactly absorb chemicals.
					removed *= 0.5

			if(filtered_organs && filtered_organs.len && !mechanical_circulation)
				for(var/organ_tag in filtered_organs)
					var/obj/item/organ/internal/O = H.internal_organs_by_name[organ_tag]
					if(O && !O.is_broken() && prob(max(0, O.max_damage - O.damage)))
						removed *= 0.8
						if(active_metab.metabolism_class == CHEM_INGEST)
							ingest_rem_mult *= 0.8

	if(ingest_met && (active_metab.metabolism_class == CHEM_INGEST))
		removed = ingest_met * ingest_rem_mult
	if(touch_met && (active_metab.metabolism_class == CHEM_TOUCH))
		removed = touch_met
	removed = min(removed, volume)
	max_dose = max(volume, max_dose)
	dose = min(dose + removed, max_dose)
	if(removed >= (metabolism * 0.1) || removed >= 0.1) // If there's too little chemical, don't affect the mob, just remove it
		switch(active_metab.metabolism_class)
			if(CHEM_INJECT)
				affect_blood(M, alien, removed)
			if(CHEM_INGEST)
				affect_ingest(M, alien, removed * ingest_abs_mult)
			if(CHEM_TOUCH)
				affect_touch(M, alien, removed)
	if(overdose && (volume > overdose) && (active_metab.metabolism_class != CHEM_TOUCH && !can_overdose_touch))
		overdose(M, alien, removed)
	remove_self(removed)
	return

// todo: on_mob_life with method of CHEM_INJECT, or tick_mob_blood
/datum/reagent/proc/affect_blood(mob/living/carbon/M, alien, removed)
	return

// todo: on_mob_life with method of CHEM_INGEST, or tick_mob_ingest
/datum/reagent/proc/affect_ingest(mob/living/carbon/M, alien, removed)
	M.bloodstr.add_reagent(id, removed)
	return

// todo: on_mob_life with method of CHEM_TOUCH, or tick_mob_touch
/datum/reagent/proc/affect_touch(mob/living/carbon/M, alien, removed)
	return

// todo: fourth apply method of CHEM_VAPOR implementation?

/datum/reagent/proc/handle_vampire(var/mob/living/carbon/M, var/alien, var/removed, var/is_vampire)
	if(blood_content > 0 && is_vampire)
		#define blud_warn_timer 3000
		if(blood_content < 4) //Are we drinking real blood or something else?
			if(M.nutrition <= 0.333 * M.species.max_nutrition || M.nutrition > 0.778 * M.species.max_nutrition) //Vampires who are starving or peckish get nothing from fake blood.
				if(M.last_blood_warn + blud_warn_timer < world.time)
					to_chat(M, "<span class='warning'>This isn't enough. You need something stronger.</span>")
					M.last_blood_warn = world.time //If we're drinking fake blood, make sure we're warned appropriately.
				return
		M.nutrition += removed * blood_content //We should always be able to process real blood.

/datum/reagent/proc/overdose(var/mob/living/carbon/M, var/alien, var/removed) // Overdose effect.
	if(alien == IS_DIONA)
		return
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		overdose_mod *= H.species.chemOD_mod
	M.adjustToxLoss(removed * overdose_mod)

/datum/reagent/proc/initialize_data(newdata) // Called when the reagent is created.
	if(!isnull(newdata))
		data = newdata
	return

/datum/reagent/proc/get_data() // Just in case you have a reagent that handles data differently.
	if(data && istype(data, /list))
		return data.Copy()
	else if(data)
		return data
	return null

/datum/reagent/Destroy() // This should only be called by the holder, so it's already handled clearing its references
	holder = null
	. = ..()

/* DEPRECATED - TODO: REMOVE EVERYWHERE */

/datum/reagent/proc/reaction_turf(var/turf/target, amt)
	touch_turf(target, amt)

/datum/reagent/proc/reaction_obj(var/obj/target, amt)
	touch_obj(target, amt)

/datum/reagent/proc/reaction_mob(var/mob/target, amt)
	touch_mob(target, amt)

/datum/reagent/proc/on_move(mob/M)
	return

/datum/reagent/proc/on_update(atom/A)
	return

//* Guidebook

/**
 * Guidebook Data for TGUIGuidebookReagent
 */
/datum/reagent/proc/tgui_guidebook_data()
	return list(
		"id" = id,
		"name" = display_name || name,
		"desc" = display_description || description,
		"category" = reagent_guidebook_category,
		"flags" = reagent_flags,
		"guidebookFlags" = reagent_guidebook_flags,
		// todo: should this be here?
		"alcoholStrength" = null,
	)

//* Holder - Application

/**
 * called when we first get applied to a mob
 *
 * @params
 * * target - target mob
 * * holder - the holder on the target mob
 * * method - an enum of how we're applied from [code/__DEFINES/chemistry.dm]
 * * amount - how much is being applied
 * * data - data. not necessarily a list, but casted as one. this is before mix_data is called.
 *
 * @return amount to inject into the mob side holder. defaults to amount. this can be overriden by the mob / transfer procs.
 */
// todo: implement this proc, replace reaction mob and similar with it.
// /datum/reagent/proc/apply_to_mob(mob/target, datum/reagent_holder/holder, amount, list/data)
// 	return amount

/**
 * called when we first get sprayed/splashed on a non-mob
 *
 * not called if we're transferred into a holder on the obj
 *
 * @params
 * * target - the target.
 * * amount - how much is being applied
 * * data - data. not necessarily a list, but casted as one. this is before mix_data is caled.
 */
// todo: implement this proc, replace touch_obj/reaction_obj and similar with it.
// /datum/reagent/proc/apply_to_obj(obj/target, amount, list/data)

/**
 * called when we first get sprayed/splashed on a turf
 *
 * not called if we're transferred into a holder on the turf, somehow
 *
 * @params
 * * target - the target.
 * * amount - how much is being applied
 * * data - data. not necessarily a list, but casted as one. this is before mix_data is caled.
 */
// todo: implement this proc, replace touch_turf/reaction_turf and similar with it.
// /datum/reagent/proc/apply_to_turf(turf/target, amount, list/data)

//* Holder - Mixing

/**
 * called when a new reagent is being mixed with this one to mix our data lists.
 *
 * this may not be called if the data is the exact same!
 *
 * @params
 * * holder - (optional) the holder we're mixing in, if any.
 * * current_data - our current data. not necessarily a list, only typecasted to one.
 * * current_amount - our current amount
 * * new_data - new inbound data. not necessarily a list, only typedcasted to one.
 * * new_amount - the amount that's coming in, not what we will be at after mixing.
 */
/datum/reagent/proc/mix_data(datum/reagent_holder/holder, list/current_data, current_amount, list/new_data, new_amount)
	return
