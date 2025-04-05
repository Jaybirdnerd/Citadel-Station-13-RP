/**
 * # Component
 *
 * The component datum
 *
 * A component should be a single standalone unit
 * of functionality, that works by receiving signals from it's parent
 * object to provide some single functionality (i.e a slippery component)
 * that makes the object it's attached to cause people to slip over.
 * Useful when you want shared behaviour independent of type inheritance
 */
/datum/component
	/**
	 * Defines how duplicate existing components are handled when added to a datum
	 *
	 * See [COMPONENT_DUPE_*][COMPONENT_DUPE_ALLOWED] definitions for available options
	 *
	 * Dupe detection operates on registered_type. If you use components with subtypes,
	 * you shouldn't be relying on dupe_mode or argument passing at all.
	 */
	var/dupe_mode = COMPONENT_DUPE_HIGHLANDER

	/**
	 * The type to check for duplication
	 *
	 * `null` means exact match on `type` (default)
	 *
	 * Any other type means that and all subtypes
	 */
	var/dupe_type

	/// The datum this components belongs to
	var/datum/parent

	/// the type we register at in the datum_components list; null = exact type
	/// this is also the type used for detection with dupe_mode.
	var/registered_type

	/**
	 * Only set to true if you are able to properly transfer this component
	 *
	 * At a minimum [RegisterWithParent][/datum/component/proc/RegisterWithParent] and [UnregisterFromParent][/datum/component/proc/UnregisterFromParent] should be used
	 *
	 * Make sure you also implement [PostTransfer][/datum/component/proc/PostTransfer] for any post transfer handling
	 */
	var/can_transfer = FALSE

/**
 * Create a new component.
 *
 * Additional arguments are passed to [Initialize()][/datum/component/proc/Initialize]
 *
 * Arguments:
 * * datum/P the parent datum this component reacts to signals from
 */
/datum/component/New(list/raw_args)
	parent = raw_args[1]
	var/list/arguments = raw_args.Copy(2)
	if(Initialize(arglist(arguments)) == COMPONENT_INCOMPATIBLE)
		stack_trace("Incompatible [type] assigned to a [parent.type]! args: [json_encode(arguments)]")
		qdel(src, TRUE, TRUE)
		return

	_JoinParent(parent)

/**
 * Called during component creation with the same arguments as in new excluding parent.
 *
 * Do not call `qdel(src)` from this function, `return COMPONENT_INCOMPATIBLE` instead
 */
/datum/component/proc/Initialize(...)
	return

/**
 * Properly removes the component from `parent` and cleans up references
 *
 * Arguments:
 * * force - makes it not check for and remove the component from the parent
 * * silent - deletes the component without sending a [COMSIG_COMPONENT_REMOVING] signal
 */
/datum/component/Destroy(force=FALSE, silent=FALSE)
	if(!parent)
		return ..()
	if(!force)
		_RemoveFromParent()
	if(!silent)
		SEND_SIGNAL(parent, COMSIG_COMPONENT_REMOVING, src)
	parent = null
	return ..()

/**
 * Internal proc to handle behaviour of components when joining a parent
 */
/datum/component/proc/_JoinParent()
	var/datum/P = parent
	//lazy init the parent's dc list
	var/list/dc = P.datum_components
	if(isnull(dc))
		P.datum_components = dc = list()

	//set up the typecache
	var/our_type = isnull(registered_type)? type : registered_type
	var/list/existing = dc[our_type]
	if(length(existing))
		existing += src
	else if(!isnull(existing))
		dc[our_type] = list(existing, src)
	else
		dc[our_type] = src

	RegisterWithParent()

/**
 * Internal proc to handle behaviour when being removed from a parent
 */
/datum/component/proc/_RemoveFromParent()
	var/datum/parent = src.parent
	var/list/parents_components = parent.datum_components
	var/our_type = isnull(registered_type)? type : registered_type
	var/list/existing = parents_components[our_type]
	if(length(existing))
		existing -= src
		if(length(existing) == 1)
			parents_components[our_type] = existing[1]
		// we don't check for 0 because joinwithparent only makes a list if len >= 2
	else
		parents_components -= our_type

	if(!length(parents_components))
		parent.datum_components = null

	UnregisterFromParent()

/**
 * Register the component with the parent object
 *
 * Use this proc to register with your parent object
 *
 * Overridable proc that's called when added to a new parent
 */
/datum/component/proc/RegisterWithParent()
	return

/**
 * Unregister from our parent object
 *
 * Use this proc to unregister from your parent object
 *
 * Overridable proc that's called when removed from a parent
 * *
 */
/datum/component/proc/UnregisterFromParent()
	return

/**
 * Register to listen for a signal from the passed in target
 *
 * This sets up a listening relationship such that when the target object emits a signal
 * the source datum this proc is called upon, will receive a callback to the given proctype
 * Use PROC_REF(procname), TYPE_PROC_REF(type,procname) or GLOBAL_PROC_REF(procname) macros to validate the passed in proc at compile time.
 * PROC_REF for procs defined on current type or its ancestors, TYPE_PROC_REF for procs defined on unrelated type and GLOBAL_PROC_REF for global procs.
 * Return values from procs registered must be a bitfield
 *
 * Arguments:
 * * datum/target The target to listen for signals from
 * * signal_type A signal name
 * * proctype The proc to call back when the signal is emitted
 * * override If a previous registration exists you must explicitly set this
 */
/datum/proc/RegisterSignal(datum/target, signal_type, proctype, override = FALSE)
	if(QDELETED(src) || QDELETED(target))
		return

	if (islist(signal_type))
		var/static/list/known_failures = list()
		var/list/signal_type_list = signal_type
		var/message = "([target.type]) is registering [signal_type_list.Join(", ")] as a list, the older method. Change it to RegisterSignals."

		if (!(message in known_failures))
			known_failures[message] = TRUE
			stack_trace("[target] [message]")

		RegisterSignals(target, signal_type, proctype, override)
		return

	var/list/procs = (signal_procs ||= list())
	var/list/target_procs = (procs[target] ||= list())
	var/list/lookup = (target.comp_lookup ||= list())

	var/exists = target_procs[signal_type]
	target_procs[signal_type] = proctype

	if(exists)
		if(!override)
			var/override_message = "[signal_type] overridden. Use override = TRUE to suppress this warning.\nTarget: [target] ([target.type]) Existing Proc: [exists] New Proc: [proctype]"
			stack_trace(override_message)
		return

	var/list/looked_up = lookup[signal_type]

	if(isnull(looked_up)) // Nothing has registered here yet
		lookup[signal_type] = src
	else if(!islist(looked_up)) // One other thing registered here
		lookup[signal_type] = list(looked_up, src)
	else // Many other things have registered here
		looked_up += src

/// Registers multiple signals to the same proc.
/datum/proc/RegisterSignals(datum/target, list/signal_types, proctype, override = FALSE)
	for (var/signal_type in signal_types)
		RegisterSignal(target, signal_type, proctype, override)

/**
 * RegisterSignal on SSdcs to listen to global signals.
 */
/datum/proc/RegisterGlobalSignal(signal_type, proctype, override = FALSE)
	RegisterSignal(SSdcs, signal_type, proctype, override)

/**
 * RegisterSignal on SSdcs to listen to global signals.
 */
/datum/proc/RegisterGlobalSignals(list/signal_types, proctype, override = FALSE)
	for (var/signal_type in signal_types)
		RegisterGlobalSignal(SSdcs, signal_type, proctype, override)

/**
 * Stop listening to a given signal from target
 *
 * Breaks the relationship between target and source datum, removing the callback when the signal fires
 *
 * Doesn't care if a registration exists or not
 *
 * Arguments:
 * * datum/target Datum to stop listening to signals from
 * * sig_typeor_types Signal string key or list of signal keys to stop listening to specifically
 */
/datum/proc/UnregisterSignal(datum/target, sig_type_or_types)
	var/list/lookup = target.comp_lookup
	if(!signal_procs || !signal_procs[target] || !lookup)
		return
	if(!islist(sig_type_or_types))
		sig_type_or_types = list(sig_type_or_types)
	for(var/sig in sig_type_or_types)
		if(!signal_procs[target][sig])
			if(!istext(sig))
				stack_trace("We're unregistering with something that isn't a valid signal \[[sig]\], you fucked up")
			continue
		switch(length(lookup[sig]))
			if(2)
				lookup[sig] = (lookup[sig]-src)[1]
			if(1)
				stack_trace("[target] ([target.type]) somehow has single length list inside comp_lookup")
				if(src in lookup[sig])
					lookup -= sig
					if(!length(lookup))
						target.comp_lookup = null
						break
			if(0)
				if(lookup[sig] != src)
					continue
				lookup -= sig
				if(!length(lookup))
					target.comp_lookup = null
					break
			else
				lookup[sig] -= src

	signal_procs[target] -= sig_type_or_types
	if(!signal_procs[target].len)
		signal_procs -= target

/datum/proc/UnregisterGlobalSignal(sig_type_or_types)
	UnregisterSignal(SSdcs, sig_type_or_types)

/**
 * Checks if a target is listening to a specific signal on us
 *
 * * This is just here for completeness. If you need to use this, you are almost certainly doing something wrong.
 */
/datum/proc/has_signal_registration(sigtype, datum/source)
	var/list/existing_registree = comp_lookup[sigtype]
	if(!existing_registree)
		return FALSE
	return existing_registree == source || (islist(existing_registree) && existing_registree[source])

/**
 * Called on a component when a component of the same type was added to the same parent
 *
 * See [/datum/component/var/dupe_mode]
 *
 * `C`'s type will always be the same of the called component
 */
/datum/component/proc/InheritComponent(datum/component/C, i_am_original)
	return


/**
 * Called on a component when a component of the same type was added to the same parent with [COMPONENT_DUPE_SELECTIVE]
 *
 * See [/datum/component/var/dupe_mode]
 *
 * `C`'s type will always be the same of the called component
 *
 * return TRUE if you are absorbing the component, otherwise FALSE if you are fine having it exist as a duplicate component
 */
/datum/component/proc/CheckDupeComponent(datum/component/C, ...)
	return


/**
 * Callback Just before this component is transferred
 *
 * Use this to do any special cleanup you might need to do before being deregged from an object
 */
/datum/component/proc/PreTransfer()
	return

/**
 * Callback Just after a component is transferred
 *
 * Use this to do any special setup you need to do after being moved to a new object
 *
 * Do not call `qdel(src)` from this function, `return COMPONENT_INCOMPATIBLE` instead
 */
/datum/component/proc/PostTransfer()
	return COMPONENT_INCOMPATIBLE //Do not support transfer by default as you must properly support it

/**
 * Internal proc to handle most all of the signaling procedure
 *
 * Will runtime if used on datums with an empty lookup list
 *
 * Use the [SEND_SIGNAL] define instead
 */
/datum/proc/_SendSignal(sigtype, list/arguments)
	var/target = comp_lookup[sigtype]
	if(!length(target))
		var/datum/listening_datum = target
		return NONE | call(listening_datum, listening_datum.signal_procs[src][sigtype])(arglist(arguments))
	. = NONE
	// This exists so that even if one of the signal receivers unregisters the signal,
	// all the objects that are receiving the signal get the signal this final time.
	// AKA: No you can't cancel the signal reception of another object by doing an unregister in the same signal.
	var/list/queued_calls = list()
	// This should be faster than doing `var/datum/listening_datum as anything in target` as it does not implicitly copy the list
	for(var/i in 1 to length(target))
		var/datum/listening_datum = target[i]
		queued_calls.Add(listening_datum, listening_datum.signal_procs[src][sigtype])
	for(var/i in 1 to length(queued_calls) step 2)
		. |= call(queued_calls[i], queued_calls[i + 1])(arglist(arguments))

/**
 * Return any component assigned to this datum of the given registered component type
 *
 * * `registered_type` must be set on the component for this to work.
 *
 * Arguments:
 * * datum/component/c_type The type of the component you want to get a reference to. It will be overridden with the type of its [registered_type] if it's set.
 */
/datum/proc/GetComponent(datum/component/c_type)
	RETURN_TYPE(c_type)
	. = datum_components?[initial(c_type.registered_type)]
	return . && (length(.) ? .[1] : .)

/**
 * Get all components of a given registered component type that are attached to this datum
 *
 * * `registered_type` must be set on the component for this to work.
 *
 * Arguments:
 * * c_type The component type path
 */
/datum/proc/GetComponents(c_type)
	var/list/components = datum_components
	if(!components)
		return null
	. = components[c_type]
	if(!length(.))
		return list(.)

/**
 * Creates an instance of `new_type` in the datum and attaches to it as parent
 *
 * Sends the [COMSIG_COMPONENT_ADDED] signal to the datum
 *
 * Returns the component that was created. Or the old component in a dupe situation where [COMPONENT_DUPE_UNIQUE] was set
 *
 * If this tries to add a component to an incompatible type, the component will be deleted and the result will be `null`. This is very unperformant, try not to do it
 *
 * Properly handles duplicate situations based on the `dupe_mode` var
 */
/datum/proc/_AddComponent(list/raw_args)
	var/new_type = raw_args[1]
	var/datum/component/nt = new_type

	// todo: rewrite this proc; we already horribly changed component behavior
	// e.g. dupe behavior is entirely changed and needs to be rethought, probably.

	if(QDELING(src))
		CRASH("Attempted to add a new component of type \[[nt]\] to a qdeleting parent of type \[[type]\]!")

	var/dm = initial(nt.dupe_mode)

	var/datum/component/old_comp
	var/datum/component/new_comp

	if(ispath(nt))
		if(nt == /datum/component)
			CRASH("[nt] attempted instantiation!")
	else
		new_comp = nt
		nt = new_comp.type

	raw_args[1] = src

	if(dm != COMPONENT_DUPE_ALLOWED && dm != COMPONENT_DUPE_SELECTIVE)
		old_comp = GetComponent(nt)
		if(old_comp)
			switch(dm)
				if(COMPONENT_DUPE_UNIQUE)
					if(!new_comp)
						new_comp = new nt(raw_args)
					if(!QDELETED(new_comp))
						old_comp.InheritComponent(new_comp, TRUE)
						QDEL_NULL(new_comp)
				if(COMPONENT_DUPE_HIGHLANDER)
					if(!new_comp)
						new_comp = new nt(raw_args)
					if(!QDELETED(new_comp))
						new_comp.InheritComponent(old_comp, FALSE)
						QDEL_NULL(old_comp)
				if(COMPONENT_DUPE_UNIQUE_PASSARGS)
					if(!new_comp)
						var/list/arguments = raw_args.Copy(2)
						arguments.Insert(1, null, TRUE)
						old_comp.InheritComponent(arglist(arguments))
					else
						old_comp.InheritComponent(new_comp, TRUE)
		else if(!new_comp)
			new_comp = new nt(raw_args) // There's a valid dupe mode but there's no old component, act like normal
	else if(dm == COMPONENT_DUPE_SELECTIVE)
		var/list/arguments = raw_args.Copy()
		arguments[1] = new_comp
		var/make_new_component = TRUE
		for(var/datum/component/existing_component as anything in GetComponents(initial(nt.registered_type)))
			if(existing_component.CheckDupeComponent(arglist(arguments)))
				make_new_component = FALSE
				QDEL_NULL(new_comp)
				break
		if(!new_comp && make_new_component)
			new_comp = new nt(raw_args)
	else if(!new_comp)
		new_comp = new nt(raw_args) // Dupes are allowed, act like normal

	if(!old_comp && !QDELETED(new_comp)) // Nothing related to duplicate components happened and the new component is healthy
		SEND_SIGNAL(src, COMSIG_COMPONENT_ADDED, new_comp)
		return new_comp
	return old_comp

/**
 * Get existing component of type, or create it and return a reference to it
 *
 * Use this if the item needs to exist at the time of this call, but may not have been created before now
 *
 * Arguments:
 * * component_type The typepath of the component to create or return
 * * ... additional arguments to be passed when creating the component if it does not exist
 */
/datum/proc/_LoadComponent(list/arguments)
	. = GetComponent(arguments[1])
	if(!.)
		return _AddComponent(arguments)

/**
 * qdels a component of given registered type,
 * optionally filtering to a subtype to make sure it's the right one
 */
/datum/proc/DelComponent(registered_type, filter_type)
	var/list/val = datum_components?[registered_type]
	if(isnull(val))
		return FALSE
	var/datum/component/potential
	if(length(val))
		for(potential as anything in val)
			if(isnull(filter_type))
				qdel(potential)
				return TRUE
			else if(istype(potential, filter_type))
				qdel(potential)
				return TRUE
		return FALSE
	else
		potential = val
		if(!isnull(filter_type) && !istype(potential, filter_type))
			return FALSE
		qdel(potential)
		return TRUE

/**
 * Removes the component from parent, ends up with a null parent
 * Used as a helper proc by the component transfer proc, does not clean up the component like Destroy does
 */
/datum/component/proc/ClearFromParent()
	if(!parent)
		return
	var/datum/old_parent = parent
	PreTransfer()
	_RemoveFromParent()
	parent = null
	SEND_SIGNAL(old_parent, COMSIG_COMPONENT_REMOVING, src)

/**
 * Transfer this component to another parent
 *
 * Component is taken from source datum
 *
 * Arguments:
 * * datum/component/target Target datum to transfer to
 */
/datum/proc/TakeComponent(datum/component/target)
	if(!target || target.parent == src)
		return
	if(target.parent)
		target.ClearFromParent()
	target.parent = src
	var/result = target.PostTransfer()
	switch(result)
		if(COMPONENT_INCOMPATIBLE)
			var/c_type = target.type
			qdel(target)
			CRASH("Incompatible [c_type] transfer attempt to a [type]!")

	if(target == AddComponent(target))
		target._JoinParent()

/**
 * Transfer all components to target
 *
 * All components from source datum are taken
 *
 * Arguments:
 * * /datum/target the target to move the components to
 */
/datum/proc/TransferComponents(datum/target)
	var/list/dc = datum_components
	if(isnull(dc))
		return
	for(var/key in dc)
		if(length(key))
			for(var/datum/component/thing as anything in dc[key])
				if(thing.can_transfer)
					target.TakeComponent(thing)
		else
			var/datum/component/val = dc[key]
			if(val.can_transfer)
				target.TakeComponent(val)

/**
 * Return the object that is the host of any UI's that this component has
 */
/datum/component/ui_host()
	return parent
