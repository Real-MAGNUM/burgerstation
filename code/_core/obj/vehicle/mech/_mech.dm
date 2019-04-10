/obj/vehicle/mech
	name = "mech"
	desc = "Weaponized Anime"
	icon = 'icons/obj/vehicles/mechs.dmi'

	density = 1
	opacity = 1
	anchored = 1

/obj/vehicle/mech/update_icon()

	icon_state = initial(icon_state)

	if(!length(passengers))
		icon_state = "[icon_state]_open"

	..()

/obj/vehicle/mech/ripley
	name = "\improper APLU Ripley"
	desc = "Ripley"

	icon_state = "ripley"


/obj/vehicle/mech/ripley/full

/obj/vehicle/mech/ripley/full/New(var/desired_loc)
	..()
	var/obj/item/weapon/ranged/laser/unlimited/U1 = new(src.loc)
	attach_equipment(U1)

	var/obj/item/weapon/ranged/laser/unlimited/U2 = new(src.loc)
	attach_equipment(U2)