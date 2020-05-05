/obj/item/
	name = "item"
	desc = "Oh my god it's an item."

	var/vendor_name = null //Name for the vender. Set to null for it to just use the initial name var.

	var/rarity = RARITY_COMMON

	var/size = SIZE_1
	var/weight = WEIGHT_1

	var/list/material = list() //Stored materials

	var/delete_on_drop = FALSE

	var/item_count_current = 1
	var/item_count_max = 1
	var/item_count_max_icon = 0

	var/slowdown_mul_held = 1 //Slow down multiplier. High values means more slower.
	var/slowdown_mul_worn = 1

	var/pixel_height = 2 //The z size of this, in pixels. Used for sandwiches and burgers.

	var/is_container = FALSE //Setting this to true will open the below inventories on use.
	var/dynamic_inventory_count = 0
	var/container_max_size = 0 //This item has a container, how much should it be able to hold in each slot?
	var/container_max_weight = 0 //This item has a container, how much should it be able to carry in TOTAL?
	var/container_held_slots = 0 //How much each inventory slot can hold.
	var/container_blacklist = list()
	var/container_whitelist = list()

	var/container_temperature = 0 //How much to add or remove from the ambient temperature for calculating reagent temperature. Use for coolers.
	var/container_temperature_mod = 1 //The temperature mod of the inventory object. Higher values means faster temperature transition. Lower means slower.

	var/list/obj/hud/inventory/inventories = list() //The inventory holders this object has

	icon_state = "inventory"
	var/icon_state_held_left = "held_left"
	var/icon_state_held_right = "held_right"
	var/icon_state_worn = "worn"
	//var/icon_state_held_single

	collision_flags = FLAG_COLLISION_ITEM

	var/worn_layer = 0

	var/item_slot = SLOT_NONE

	mouse_over_pointer = MOUSE_ACTIVE_POINTER

	var/no_held_draw = FALSE

	var/no_initial_blend = FALSE //Should we draw the initial icon when worn/held?

	var/slot_icons = FALSE //Set to true if the clothing is based on where it's slot is.

	var/ignore_other_slots = FALSE

	var/soul_bound = null

	var/list/inventory_bypass = list()

	var/crafting_id = null

	var/list/inventory_sounds = list(
		'sounds/effects/inventory/rustle1.ogg',
		'sounds/effects/inventory/rustle2.ogg',
		'sounds/effects/inventory/rustle3.ogg',
		'sounds/effects/inventory/rustle4.ogg',
		'sounds/effects/inventory/rustle5.ogg'
	)

	var/list/alchemy_reagents = list() //Reagents that are created if this is processed in an alchemy table. Format: reagent_id = volume.

	var/flags_tool = FLAG_TOOL_NONE
	var/tool_time = SECONDS_TO_DECISECONDS(5)

	var/worn_pixel_x = 0
	var/worn_pixel_y = 0

	var/atom/last_interacted

	var/dyeable = FALSE

	var/mob/living/advanced/inventory_user

	var/unremovable = FALSE //Set to true if it cannot be moved around inventories.

	var/wielded = FALSE
	var/can_wield = FALSE

	ignore_incoming_collisons = TRUE

	anchored = FALSE

	var/block_power = 0.5 //Higher values means it blocks more. Normal weapons should have 1, while stronger items should have between 2-5

	var/allow_beaker_transfer = FALSE

/obj/item/proc/transfer_item_count_to(var/obj/item/target,var/amount_to_add = item_count_current)
	if(!amount_to_add)
		return 0
	if(amount_to_add < 0)
		return target.transfer_item_count_to(src,-amount_to_add)
	amount_to_add = min(amount_to_add,item_count_current,target.item_count_max - target.item_count_current)
	. = target.add_item_count(amount_to_add,TRUE)
	src.add_item_count(-amount_to_add,TRUE)
	return .

/obj/item/proc/add_item_count(var/amount_to_add,var/bypass_checks = FALSE)

	if(!bypass_checks)
		if(!amount_to_add)
			return 0
		else if(amount_to_add > 0)
			amount_to_add = min(amount_to_add,item_count_max - item_count_current)
		else if(amount_to_add < 0)
			amount_to_add = max(amount_to_add,-item_count_current)

	item_count_current += amount_to_add

	if(item_count_current <= 0)
		qdel(src)
	else
		update_sprite()

	return amount_to_add

/obj/item/can_block(var/atom/attacker,var/atom/attacking_weapon,var/atom/victim,var/damagetype/DT)

	if(istype(DT,/damagetype/unarmed/))
		return null

	if(is_living(victim))
		var/mob/living/V = victim
		if(istype(DT,/damagetype/ranged/))
			return (V.get_skill_power(SKILL_BLOCK)) >= 0.75 ? src : null

	return src

/obj/item/can_parry(var/atom/attacker,var/atom/attacking_weapon,var/atom/victim,var/damagetype/DT)

	if(istype(DT,/damagetype/unarmed/))
		return null

	if(is_living(victim))
		var/mob/living/V = victim
		if(istype(DT,/damagetype/ranged/))
			return (V.get_skill_power(SKILL_PARRY)) >= 0.75 ? src : null

	return src


/obj/item/Destroy()

	for(var/obj/hud/inventory/I in inventories)
		qdel(I)

	inventories.Cut()

	last_interacted = null

	if(loc)
		drop_item()

	return ..()

/atom/proc/quick(var/mob/living/advanced/caller,var/atom/object,location,control,params)
	return FALSE

/obj/item/can_be_attacked(var/atom/attacker,var/atom/weapon,var/params,var/damagetype/damage_type)
	return FALSE

/obj/item/can_be_grabbed(var/atom/grabber)
	return isturf(src.loc)

/obj/item/proc/can_add_to_inventory(var/mob/caller,var/obj/item/object,var/enable_messages = TRUE,var/bypass = FALSE)

	if(!length(inventories))
		return null

	for(var/obj/hud/inventory/I in inventories)
		if(bypass && length(I.held_objects) >= I.held_slots)
			continue
		if(I.can_hold_object(object,enable_messages))
			return I

	return null

/obj/item/proc/add_to_inventory(var/mob/caller,var/obj/item/object,var/enable_messages = TRUE,var/bypass = FALSE) //We add the object to this item's inventory.

	if(!length(inventories))
		return FALSE

	var/added = FALSE

	if(object != src)
		var/obj/hud/inventory/found_inventory = can_add_to_inventory(caller,object,FALSE,bypass)
		if(found_inventory)
			found_inventory.add_object(object,enable_messages,bypass)
			added = TRUE

	if(enable_messages && caller)
		if(added)
			caller.to_chat(span("notice","You stuff \the [object.name] in \the [src.name]."))
		else
			caller.to_chat(span("warning","You don't have enough inventory space inside \the [src.name] to hold \the [object.name]!"))

	return added

/obj/item/New(var/desired_loc)

	if(!damage_type || damage_type == /damagetype/default/)
		var/size_mass = size * weight
		switch(size_mass)
			if(1 to 5)
				damage_type = /damagetype/item/light
			if(5 to 10)
				damage_type = /damagetype/item/medium
			if(10 to INFINITY)
				damage_type = /damagetype/item/heavy

	for(var/i=1, i <= length(inventories), i++)
		var/obj/hud/inventory/new_inv = inventories[i]
		inventories[i] = new new_inv(src)
		//Doesn't need to be initialized as it's done later.
		if(container_held_slots)
			inventories[i].held_slots = container_held_slots
		if(container_max_size)
			inventories[i].max_size = container_max_size
		if(container_max_weight)
			inventories[i].max_weight = container_max_weight
		if(container_blacklist && length(container_blacklist))
			inventories[i].item_blacklist = container_blacklist
		if(container_whitelist && length(container_whitelist))
			inventories[i].item_whitelist = container_whitelist
		if(container_temperature)
			inventories[i].inventory_temperature_mod = container_temperature
		if(container_temperature_mod)
			inventories[i].inventory_temperature_mod_mod = container_temperature_mod

	for(var/i=1, i <= dynamic_inventory_count, i++)
		var/obj/hud/inventory/dynamic/D = new(src)
		//Doesn't need to be initialized as it's done later.
		D.id = "dynamic_[i]"
		D.slot_num = i
		if(container_held_slots)
			D.held_slots = container_held_slots
		if(container_max_size)
			D.max_size = container_max_size
		if(container_max_weight)
			D.max_weight = container_max_weight
		if(container_blacklist && length(container_blacklist))
			D.item_blacklist = container_blacklist
		if(container_whitelist && length(container_whitelist))
			D.item_whitelist = container_whitelist
		if(container_temperature)
			D.inventory_temperature_mod = container_temperature
		if(container_temperature_mod)
			D.inventory_temperature_mod_mod = container_temperature_mod
		inventories += D

	return ..()

/obj/item/proc/update_owner(desired_owner)
	for(var/v in inventories)
		var/obj/hud/inventory/I = v
		I.update_owner(desired_owner)

/obj/item/proc/get_owner()
	if(is_inventory(src.loc))
		var/obj/hud/inventory/I = src.loc
		return I.owner

	return null

/obj/item/update_sprite()

	. = ..()

	if(is_inventory(src.loc))
		var/obj/hud/inventory/I = src.loc
		I.overlays.Cut()
		I.update_overlays()

	return .

/obj/item/get_examine_list(var/mob/examiner)

	. = list()
	. += div("examine_title","[ICON_TO_HTML(src.icon,src.icon_state,8,8)][src.name]")
	. += div("rarity [rarity]",capitalize(rarity))
	. += div("rarity","Value: [CEILING(calculate_value(TRUE),1)].")
	. += div("weightsize","Size: [size] | Weight: [weight]")
	. += div("examine_description","Crafting ID: [crafting_id ? crafting_id : "none"]")
	. += div("examine_description","\"[src.desc]\"")
	. += div("examine_description_long",src.desc_extended)

	/*
	if(is_living(examiner) && damage_type && all_damage_types[damage_type])
		var/damagetype/DT = all_damage_types[damage_type]
		. += div("damage",DT.get_examine_text(examiner))
	*/

	return .


/obj/item/proc/update_lighting_for_owner(var/obj/hud/inventory/inventory_override)

	var/obj/hud/inventory/I = inventory_override || src.loc

	if(!I || !is_inventory(I))
		return FALSE

	if(!I.owner || !is_advanced(I.owner))
		return FALSE

	var/mob/living/advanced/A = I.owner

	A.update_lighting()

	return TRUE

/obj/item/proc/on_pickup(var/atom/old_location,var/obj/hud/inventory/new_location) //When the item is picked up.

	if(is_container)
		for(var/obj/hud/inventory/I in inventories)
			I.update_owner(new_location.owner)

	if(old_location && new_location)
		var/turf/OL = get_turf(old_location)
		var/turf/NL = get_turf(new_location)
		if(OL != NL)
			new/obj/effect/temp/item_pickup(NL,2,OL,src,"pickup")

	if(new_location)
		update_lighting_for_owner(new_location)
		last_interacted = new_location.owner

	return TRUE

/obj/item/set_light(range,power,color,angle,no_update)
	. = ..()
	update_lighting_for_owner()
	return .

/obj/item/proc/on_drop(var/obj/hud/inventory/old_inventory,var/atom/new_loc)

	if(delete_on_drop)
		qdel(src)
		return TRUE

	if(light)
		light.update(src)

	if(old_inventory && new_loc)
		var/turf/OL = get_turf(old_inventory)
		var/turf/NL = get_turf(new_loc)
		if(OL != NL)
			new/obj/effect/temp/item_pickup(NL,2,OL,src,isturf(new_loc) ? "drop" : "transfer")

	update_lighting_for_owner(old_inventory)

	queue_delete(src,ITEM_DELETION_TIME_DROPPED,TRUE)

	return TRUE

/obj/item/proc/inventory_to_list()

	var/list/returning_list = list()

	for(var/obj/hud/inventory/I in inventories)
		if(length(I.held_objects) && I.held_objects[1])
			returning_list += I.held_objects[1]

	return returning_list


/obj/item/proc/can_be_held(var/mob/living/advanced/owner,var/obj/hud/inventory/I)
	return TRUE

/obj/item/proc/can_be_worn(var/mob/living/advanced/owner,var/obj/hud/inventory/I)
	return FALSE

/obj/item/proc/update_held_icon()

	if(is_inventory(src.loc))
		var/obj/hud/inventory/I = src.loc
		I.update_held_icon(src)

	return TRUE


/obj/item/Cross(var/atom/movable/O)

	if(istype(O,/obj/item/))
		return TRUE

	return ..()

/obj/item/trigger(var/mob/caller,var/atom/source,var/signal_freq,var/signal_code)
	last_interacted = caller
	return ..()