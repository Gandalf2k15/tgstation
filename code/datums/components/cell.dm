/*
CELL COMPONENT

What we aim to achieve with cell components is a universal framework for all items that would logically use batteries,
Be it a flashlight, T-ray scanner or multitool. All of them would logically require batteries right? Well, welcome,
to the cell component.

General logic:
Component attaches to parent(flashlight etc)
Registers onhit signal to check if it's being slapped by a battery
Component moves battery to equipment loc, keeps a record, and then communicates with
the equipment and controls the behaviour of said equipment.

If it's a robot, it uses the robot cell - Using certified shitcode.(this needs redone)

If you are adding this to an item that is active for a period of time, register signal to COMSIG_CELL_START_USE when it would start using the cell
and COMSIG_CELL_STOP_USE when it should stop. To handle the turning off of said item once the cell is depleted, add your code into the
component_cell_out_of_charge/component_cell_removed proc using loc where necessary, processing is done in the component!
*/

/datum/component/cell
	/// Our reference to the inserted cell, which will be stored in the parent.
	var/obj/item/stock_parts/cell/inserted_cell
	/// The item reference to parent.
	var/obj/item/equipment
	/// How much power do we use each process?
	var/power_use_amount = POWER_CELL_USE_NORMAL
	/// Are we using a robot's powersource?
	var/inside_robot = FALSE
	/// Callback interaction for when the cell is removed.
	var/datum/callback/on_cell_removed = null
	/// Callback interaction for when the cell runs out of charge.
	var/datum/callback/cell_out_of_charge = null
	///Can this cell be removed from the parent?
	var/cell_can_be_removed = TRUE

/datum/component/cell/Initialize(cell_power_use, on_cell_removed, cell_out_of_charge, start_with_cell = TRUE, cell_override, cell_can_be_removed = TRUE)
	if(!isitem(parent)) //Currently only compatable with items.
		return COMPONENT_INCOMPATIBLE

	if(on_cell_removed)
		src.on_cell_removed = on_cell_removed

	if(cell_out_of_charge)
		src.cell_out_of_charge = cell_out_of_charge

	if(cell_power_use)
		power_use_amount = cell_power_use

	equipment = parent //We'd like a simple reference to the atom this component is attached to instead of having to declare it every time we use it.

	//So this is shitcode in it's ultimate form. Right now, as far as I can see, this is the only way to handle robot items that would normally use a cell.
	if(istype(equipment.loc, /obj/item/robot_model)) //Really, I absolutely hate borg code.
		var/mob/living/silicon/robot/robit = equipment.loc.loc //If this ever runtimes, we'll know about it and be able to refactor this.
		inserted_cell = robit.cell
		inside_robot = TRUE
	else if(start_with_cell)
		var/obj/item/stock_parts/cell/new_cell
		if(cell_override)
			new_cell = new cell_override()
		else
			new_cell = new /obj/item/stock_parts/cell/upgraded()
		inserted_cell = new_cell
		new_cell.forceMove(parent) //We use the parents location so things like EMP's can interact with the cell.

	return ..()

/datum/component/cell/RegisterWithParent()
	//Component to Parent signal registries
	RegisterSignal(parent, COMSIG_ITEM_POWER_USE, .proc/simple_power_use)
	RegisterSignal(parent, COMSIG_PARENT_ATTACKBY, .proc/insert_cell)
	RegisterSignal(parent, COMSIG_CLICK_CTRL_SHIFT , .proc/remove_cell)
	RegisterSignal(parent, COMSIG_PARENT_EXAMINE, .proc/examine_cell)

/datum/component/cell/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ITEM_POWER_USE)
	UnregisterSignal(parent, COMSIG_PARENT_ATTACKBY)
	UnregisterSignal(parent, COMSIG_CLICK_CTRL_SHIFT)
	UnregisterSignal(parent, COMSIG_PARENT_EXAMINE)

/datum/component/cell/Destroy(force, silent)
	if(on_cell_removed)
		QDEL_NULL(on_cell_removed)
	if(cell_out_of_charge)
		QDEL_NULL(cell_out_of_charge)
	if(inserted_cell)
		if(!inside_robot) //We really don't want to be deleting the robot's cell.
			QDEL_NULL(inserted_cell)
		inserted_cell = null
	return ..()

/// This proc is the basic way of processing the cell, with included feedback. It will return a bitflag if it failed to use the power, or COMPONENT_POWER_SUCCESS if it succeeds.
/// The user is sent the feedback, use_amount is an override, check_only will only return if it can use the cell and feedback relating to that.
/datum/component/cell/proc/simple_power_use(use_amount, mob/user, check_only = FALSE)
	SIGNAL_HANDLER
	if(!use_amount)
		use_amount = power_use_amount

	if(!inserted_cell)
		to_chat(user, "<span class='danger'>There is no cell inside [equipment]</span>")
		return COMPONENT_NO_CELL

	if(check_only)
		if(inserted_cell.charge < use_amount)
			if(user)
				to_chat(user, "<span class='danger'>The cell inside [equipment] does not have enough charge to perform this action!</span>")
			return COMPONENT_NO_CHARGE
	else if(!inserted_cell.use(use_amount))
		inserted_cell.update_appearance()  //Updates the attached cell sprite - Why does this not happen in cell.use?
		if(user)
			to_chat(user, "<span class='danger'>The cell inside [equipment] does not have enough charge to perform this action!</span>")
		return COMPONENT_NO_CHARGE

	inserted_cell.update_appearance()

	return COMPONENT_POWER_SUCCESS

/datum/component/cell/proc/examine_cell(atom/A, mob/user, list/examine_list)
	SIGNAL_HANDLER

	if(!inserted_cell)
		examine_list += "<span class='danger'>It does not have a cell inserted!</span>"
	else if(!inside_robot)
		examine_list += "<span class='notice'>It has [inserted_cell] inserted. It has <b>[inserted_cell.percent()]%</b> charge left."
	else
		examine_list += "<span class='notice'>It is drawing power from an external powersource, reading <b>[inserted_cell.percent()]%</b> charge.</span>"

/// Handling of cell removal.
/datum/component/cell/proc/remove_cell(datum/source, mob/user)
	if(!equipment.can_interact(user))
		return

	if(inside_robot)
		return

	if(!cell_can_be_removed)
		return

	if(inserted_cell)
		to_chat(user, "<span class='notice'>You remove [inserted_cell] from [equipment]!</span>")
		playsound(equipment, 'sound/weapons/magout.ogg', 40, TRUE)
		inserted_cell.forceMove(get_turf(equipment))
		INVOKE_ASYNC(user, /mob/living.proc/put_in_hands, inserted_cell)
		inserted_cell = null
		on_cell_removed.Invoke()
	else
		to_chat(user, "<span class='danger'>There is no cell inserted in [equipment]!</span>")

/// Handling of cell insertion.
/datum/component/cell/proc/insert_cell(datum/source, obj/item/inserting_item, mob/living/user, params)
	if(inside_robot) //More robot shitcode, if we allowed them to remove the cell, it would cause the universe to implode.
		return

	if(!istype(inserting_item, /obj/item/stock_parts/cell))
		return

	if(inserted_cell) //No quickswap compatibility
		to_chat(user, "<span class='danger'>There is already a cell inserted in [equipment]!</span>")
		return

	to_chat(user, "<span class='notice'>You insert [inserting_item] into [equipment]!</span>")
	playsound(equipment, 'sound/weapons/magin.ogg', 40, TRUE)
	inserted_cell = inserting_item
	inserting_item.forceMove(parent)
