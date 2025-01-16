
/obj/machinery/atmospherics/component/unary/freezer
	name = "gas cooling system"
	desc = "Cools gas when connected to pipe network"
	icon = 'icons/obj/medical/cryogenic2.dmi'
	icon_state = "freezer_0"
	density = 1
	anchored = 1
	use_power = USE_POWER_OFF
	idle_power_usage = 5			// 5 Watts for thermostat related circuitry
	circuit = /obj/item/circuitboard/unary_atmos/cooler

	var/heatsink_temperature = T20C	// The constant temperature reservoir into which the freezer pumps heat. Probably the hull of the station or something.
	var/internal_volume = 600		// L

	var/max_power_rating = 20000	// Power rating when the usage is turned up to 100
	var/power_setting_legacy = 100

	var/set_temperature = T20C		// Thermostat
	var/cooling = 0

/obj/machinery/atmospherics/component/unary/freezer/Initialize(mapload)
	. = ..()
	component_parts = list()
	component_parts += new /obj/item/stock_parts/matter_bin(src)
	component_parts += new /obj/item/stock_parts/capacitor(src)
	component_parts += new /obj/item/stock_parts/capacitor(src)
	component_parts += new /obj/item/stock_parts/manipulator(src)
	component_parts += new /obj/item/stack/cable_coil(src, 2)
	RefreshParts()

/obj/machinery/atmospherics/component/unary/freezer/atmos_init()
	if(node)
		return

	var/node_connect = dir

	for(var/obj/machinery/atmospherics/target in get_step(src, node_connect))
		if(can_be_node(target, 1))
			node = target
			break

	if(check_for_obstacles())
		node = null

	if(node)
		update_icon()

/obj/machinery/atmospherics/component/unary/freezer/update_icon_state()
	if(node)
		if(use_power && cooling)
			icon_state = "freezer_1"
		else
			icon_state = "freezer"
	else
		icon_state = "freezer_0"
	return ..()

/obj/machinery/atmospherics/component/unary/freezer/attack_ai(mob/user as mob)
	ui_interact(user)

/obj/machinery/atmospherics/component/unary/freezer/attack_hand(mob/user, datum/event_args/actor/clickchain/e_args)
	ui_interact(user)

/obj/machinery/atmospherics/component/unary/freezer/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "GasTemperatureSystem", name)
		ui.open()

/obj/machinery/atmospherics/component/unary/freezer/ui_data(mob/user, datum/tgui/ui)
	// this is the data which will be sent to the ui
	var/data[0]
	data["on"] = use_power ? 1 : 0
	data["gasPressure"] = round(air_contents.return_pressure())
	data["gasTemperature"] = round(air_contents.temperature)
	data["minGasTemperature"] = 0
	data["maxGasTemperature"] = round(T20C+500)
	data["targetGasTemperature"] = round(set_temperature)
	data["powerSetting"] = power_setting_legacy

	var/temp_class = "good"
	if(air_contents.temperature > (T0C - 20))
		temp_class = "bad"
	else if(air_contents.temperature < (T0C - 20) && air_contents.temperature > (T0C - 100))
		temp_class = "average"
	data["gasTemperatureClass"] = temp_class

	return data

/obj/machinery/atmospherics/component/unary/freezer/ui_act(action, list/params, datum/tgui/ui)
	if(..())
		return TRUE

	. = TRUE
	switch(action)
		if("toggleStatus")
			update_use_power(!use_power)
			update_icon()
		if("setGasTemperature")
			var/amount = text2num(params["temp"])
			if(amount > 0)
				set_temperature = min(amount, 1000)
			else
				set_temperature = max(amount, 0)
		if("setPower") //setting power to 0 is redundant anyways
			var/new_setting = clamp( text2num(params["value"]), 0,  100)
			set_power_level(new_setting)

/obj/machinery/atmospherics/component/unary/freezer/process(delta_time)
	..()

	if(machine_stat & (NOPOWER|BROKEN) || !use_power)
		cooling = 0
		update_icon()
		return

	if(network && air_contents.temperature > set_temperature)
		cooling = 1

		var/heat_transfer = max( -air_contents.get_thermal_energy_change(set_temperature - 5), 0 )
		//Assume the heat is being pumped into the hull which is fixed at heatsink_temperature
		//not /really/ proper thermodynamics but whatever
		CACHE_VSC_PROP(atmos_vsc, /atmos/thermomachine_cheat_factor, cheat_factor)
		var/cop = cheat_factor * air_contents.temperature/heatsink_temperature	//heatpump coefficient of performance from thermodynamics -> power used = heat_transfer/cop
		heat_transfer = min(heat_transfer, cop * power_rating)	//limit heat transfer by available power

		var/removed = -air_contents.adjust_thermal_energy(-heat_transfer)		//remove the heat
		if(debug)
			visible_message("[src]: Removing [removed] W.")

		use_power(power_rating)

		network.update = 1
	else
		cooling = 0

	update_icon()

//upgrading parts
/obj/machinery/atmospherics/component/unary/freezer/RefreshParts()
	..()
	var/cap_rating = 0
	var/manip_rating = 0
	var/bin_rating = 0

	for(var/obj/item/stock_parts/P in component_parts)
		if(istype(P, /obj/item/stock_parts/capacitor))
			cap_rating += P.rating
		if(istype(P, /obj/item/stock_parts/manipulator))
			manip_rating += P.rating
		if(istype(P, /obj/item/stock_parts/matter_bin))
			bin_rating += P.rating

	max_power_rating = initial(max_power_rating) * cap_rating / 2			//more powerful
	heatsink_temperature = initial(heatsink_temperature) / ((manip_rating + bin_rating) / 2)	//more efficient
	air_contents.volume = max(initial(internal_volume) - 200, 0) + 200 * bin_rating
	set_power_level(power_setting_legacy)

/obj/machinery/atmospherics/component/unary/freezer/proc/set_power_level(var/new_power_setting_legacy)
	power_setting_legacy = new_power_setting_legacy
	power_rating = max_power_rating * (power_setting_legacy/100)

/obj/machinery/atmospherics/component/unary/freezer/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if(default_deconstruction_screwdriver(user, O))
		return
	if(default_deconstruction_crowbar(user, O))
		return
	if(default_part_replacement(user, O))
		return

	..()

/obj/machinery/atmospherics/component/unary/freezer/examine(mob/user, dist)
	. = ..()
	if(panel_open)
		. += "The maintenance hatch is open."
