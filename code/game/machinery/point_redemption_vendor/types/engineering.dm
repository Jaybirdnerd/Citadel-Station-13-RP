/obj/machinery/point_redemption_vendor/engineering
	name = "Engineering Equipment Vendor"
	desc = "An equipment vendor for engineers, point generated by the crypto miners can be spend here."
	icon = 'icons/machinery/point_redemption_vendor/engineering.dmi'
	icon_state = "vendor"
	icon_state_append_deny = "-deny"
	icon_state_append_open = "-open"
	icon_state_append_off = "-off"
	point_type = POINT_REDEMPTION_TYPE_ENGINEERING
	prize_list = list(
		//Mining vendor steals
		new /datum/point_redemption_item("Vodka",						    /obj/item/reagent_containers/food/drinks/bottle/vodka,			3),
		new /datum/point_redemption_item("Cigar",						    /obj/item/clothing/mask/smokable/cigarette/cigar/havana,        5),
		new /datum/point_redemption_item("Soap",						    /obj/item/soap/nanotrasen,									    2),
		new /datum/point_redemption_item("Laser Pointer",				    /obj/item/laser_pointer,										9),
		new /datum/point_redemption_item("Plush Toy",					    /obj/random/plushie,											3),
		new /datum/point_redemption_item("GPS Device",					    /obj/item/gps/engineering,									    1),
		new /datum/point_redemption_item("50 Point Transfer Card",		    /obj/item/point_redemption_voucher/preloaded/engineering/c50,	50),
		new /datum/point_redemption_item("Umbrella",					    /obj/item/melee/umbrella/random,								20),
		new /datum/point_redemption_item("100 Thaler",					    /obj/item/spacecash/c100,									    4),
		new /datum/point_redemption_item("1000 Thaler",					    /obj/item/spacecash/c1000,									    40),
		new /datum/point_redemption_item("Hardsuit - Control Module",       /obj/item/hardsuit/industrial,									    50),
		new /datum/point_redemption_item("Hardsuit - Plasma Cutter",	    /obj/item/hardsuit_module/device/plasmacutter,						10),
		new /datum/point_redemption_item("Hardsuit - Maneuvering Jets",	    /obj/item/hardsuit_module/maneuvering_jets,							12),
		new /datum/point_redemption_item("Hardsuit - Intelligence Storage",	/obj/item/hardsuit_module/ai_container,								25),
		new /datum/point_redemption_item("Injector (L) - Panacea",          /obj/item/reagent_containers/hypospray/autoinjector/biginjector/purity,	50),
		//Mining vendor steals - Ends
		//Power tools like the CE gets, if kev comes crying: https://cdn.discordapp.com/attachments/296237931587305472/956517623519141908/unknown.png
		new /datum/point_redemption_item("Advanced Hardsuit",							/obj/item/hardsuit/ce,									150),
		new /datum/point_redemption_item("Power Tool - Hand Drill",                     /obj/item/tool/screwdriver/power,                   80),
		new /datum/point_redemption_item("Power Tool - Jaws of life",                   /obj/item/tool/crowbar/power,                       80),
		new /datum/point_redemption_item("Power Tool - Experimental Welder",            /obj/item/weldingtool/experimental,                 80),
		new /datum/point_redemption_item("Power Tool - Upgraded T-Ray Scanner",         /obj/item/t_scanner/upgraded,                       80),
		new /datum/point_redemption_item("Power Tool - Advanced T-Ray Scanner",         /obj/item/t_scanner/advanced,                       80),
		new /datum/point_redemption_item("Power Tool - Long Range Atmosphere scanner",  /obj/item/atmos_analyzer/longrange,                       80),
		//new /datum/point_redemption_item("Power Tool - Holofan Projector", 				/obj/item/holosign_creator/combifan,				80),
		new /datum/point_redemption_item("Superior Welding Goggles",                    /obj/item/clothing/glasses/welding/superior,        50),

		//Level 2 stock parts, to make engineering kinda self sufficent for minor upgrades but the parts are also kinda expansive
		new /datum/point_redemption_item("Stock Parts - Advanced Capacitor",        /obj/item/stock_parts/capacitor/adv,        20),
		new /datum/point_redemption_item("Stock Parts - Advanced Scanning Module",  /obj/item/stock_parts/scanning_module/adv,  20),
		new /datum/point_redemption_item("Stock Parts - Nano-Manipulator",          /obj/item/stock_parts/manipulator/nano,     20),
		new /datum/point_redemption_item("Stock Parts - High-Power Micro-Laser",    /obj/item/stock_parts/micro_laser/high,     20),
		new /datum/point_redemption_item("Stock Parts - Advanced Matter Bin",       /obj/item/stock_parts/matter_bin/adv,       20),

		//Special Resources which the vendor is the primary source off:
		new /datum/point_redemption_item("Special Parts - Vimur Tank", 				/obj/item/tank/vimur, 5),
		new /datum/point_redemption_item("Special Parts - TEG Voucher", 			/obj/item/engineering_voucher/teg, 20),
		new /datum/point_redemption_item("Special Parts - SM Core Voucher", 		/obj/item/engineering_voucher/smcore, 40),
		new /datum/point_redemption_item("Special Parts - Fusion Core Voucher",		/obj/item/engineering_voucher/fusion_core, 20),
		new /datum/point_redemption_item("Special Parts - Fuel Injector Voucher",	/obj/item/engineering_voucher/fusion_fuel_injector, 10),
		new /datum/point_redemption_item("Special Parts - Gyrotrons Voucher", 		/obj/item/engineering_voucher/gyrotrons, 20),
		new /datum/point_redemption_item("Special Parts - Fuel compressor Voucher",	/obj/item/engineering_voucher/fuel_compressor, 10),
		new /datum/point_redemption_item("Special Parts - Collector Voucher", 		/obj/item/engineering_voucher/collectors, 10),
		new /datum/point_redemption_item("Special Parts - Laser Reflector Voucher", /obj/item/engineering_voucher/reflector, 30),
		//voucher: Solar crate, Vimur canister
		new /datum/point_redemption_item("???", /obj/item/engineering_mystical_tech, 1000)
    )
