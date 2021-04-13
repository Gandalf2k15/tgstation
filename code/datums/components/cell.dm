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
	var/atom/equipment
	/// How much power do we use each process?
	var/power_use_amount = POWER_CELL_USE_NORMAL
	/// Are we using a robot's powersource?
	var/inside_robot = FALSE
	/// Does this component cell attachment start with a cell?
	var/start_with_cell = TRUE

/datum/component/cell/Initialize(cell_override, cell_power_use)
	. = ..()

	if(cell_power_use)
		power_use_amount = cell_power_use

	if(!isatom(parent)) //WE allow all atoms to use this, no discrimination here!
		return COMPONENT_INCOMPATIBLE

	equipment = parent //We'd like a simple reference to the atom this component is attached to instead of having to declare it every time we use it.

	//So this is shitcode in it's ultimate form. Right now, as far as I can see, this is the only way to handle robot items that would normally use a cell.
	if(istype(equipment.loc, /obj/item/robot_model)) //Really, I absolutely hate borg code.
		var/mob/living/silicon/robot/robit = equipment.loc.loc //If this ever runtimes, we'll know about it and be able to refactor this.
		inserted_cell = robit.cell
		inside_robot = TRUE
	else if(starts_with_cell)
		var/obj/item/stock_parts/cell/new_cell
		if(cell_override)
			new_cell = new cell_override()
		else
			new_cell = new /obj/item/stock_parts/cell/upgraded()
		inserted_cell = new_cell
		new_cell.forceMove(parent) //We use the parents location so things like EMP's can interact with the cell.


/datum/component/cell/RegisterWithParent()
	//Component to Parent signal registries
	RegisterSignal(parent, COMSIG_CELL_START_USE, .proc/start_processing_cell)
	RegisterSignal(parent, COMSIG_CELL_STOP_USE, .proc/stop_processing_cell)
	RegisterSignal(parent, COMSIG_PARENT_ATTACKBY, .proc/insert_cell)
	RegisterSignal(parent, COMSIG_CLICK_CTRL_SHIFT , .proc/remove_cell)
	RegisterSignal(parent, COMSIG_PARENT_EXAMINE, .proc/examine_cell)

	//Parent to Component signal registires
	parent.RegisterSignal(src, COMSIG_CELL_OUT_OF_CHARGE, /atom.proc/component_cell_out_of_charge)
	parent.RegisterSignal(src, COMSIG_CELL_REMOVED, /atom.proc/component_cell_removed)

/datum/component/cell/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_CELL_START_USE)
	UnregisterSignal(parent, COMSIG_CELL_STOP_USE)
	UnregisterSignal(parent, COMSIG_PARENT_ATTACKBY)
	UnregisterSignal(parent, COMSIG_CLICK_CTRL_SHIFT)
	UnregisterSignal(parent, COMSIG_PARENT_EXAMINE)

	parent.UnregisterSignal(src, COMSIG_CELL_OUT_OF_CHARGE)
	parent.UnregisterSignal(src, COMSIG_CELL_REMOVED)

/datum/component/cell/Destroy(force, silent)
	if(inserted_cell)
		if(!inside_robot) //We really don't want to be deleting the robot's cell.
			qdel(inserted_cell)
		inserted_cell = null
	return ..()

/datum/component/cell/proc/simple_power_use(mob/user, use_amount, check_only = FALSE)
	if(!use_amount)
		use_amount = power_use_amount

	if(!inserted_cell)
		to_chat(user, "<span class='danger'>There is no cell inside [equipment]</span>")
		return FALSE

	if(check_only)
		if(inserted_cell.charge < use_amount)
			to_chat(user, "<span class='danger'>The cell inside [equipment] does not have enough charge to perform this action!</span>")
			return FALSE
	else if(!inserted_cell.use(use_amount))
		inserted_cell.update_appearance()  //Updates the attached cell sprite - Why does this not happen in cell.use?
		to_chat(user, "<span class='danger'>The cell inside [equipment] does not have enough charge to perform this action!</span>")
		return FALSE

	inserted_cell.update_appearance()
	return TRUE

/// Signal friendly start processing proc. Contains checks to process. Returns false if it fails, and true if successfull.
/datum/component/cell/proc/start_processing_cell()
	SIGNAL_HANDLER

	if(!inserted_cell)
		SEND_SIGNAL(src, COMSIG_CELL_REMOVED)
		return FALSE

	if(inserted_cell.charge < power_use_amount)
		SEND_SIGNAL(src, COMSIG_CELL_OUT_OF_CHARGE)
		return FALSE

	START_PROCESSING(SSobj, src)
	return TRUE

/// Signal friendly stop processing proc, used internally and externally.
/datum/component/cell/proc/stop_processing_cell()
	SIGNAL_HANDLER
	STOP_PROCESSING(SSobj, src)

/datum/component/cell/process(delta_time)
	if(!inserted_cell.use(power_use_amount))
		cell_out_of_charge() //Best to let the proc deal with the processing.
		return

	inserted_cell.update_appearance()

/// Proc is used to handle the cell running out of charge, generally, this should only be called within the component.
/datum/component/cell/proc/cell_out_of_charge()
	SIGNAL_HANDLER
	SEND_SIGNAL(src, COMSIG_CELL_OUT_OF_CHARGE)
	inserted_cell.update_appearance()
	stop_processing_cell()
	equipment.visible_message("<span class='danger'>[equipment] makes a soft humming noise as it shuts off!</span>") //Automatic feedback is always good.

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
	SIGNAL_HANDLER

	if(!equipment.can_interact(user))
		return

	if(inside_robot)
		return

	if(inserted_cell)
		to_chat(user, "<span class='notice'>You remove [inserted_cell] from [equipment]!</span>")
		playsound(equipment, 'sound/weapons/magout.ogg', 40, TRUE)
		inserted_cell.forceMove(get_turf(equipment))
		INVOKE_ASYNC(user, /mob/living.proc/put_in_hands, inserted_cell)
		inserted_cell = null
		SEND_SIGNAL(src, COMSIG_CELL_REMOVED)
		stop_processing_cell()
	else
		to_chat(user, "<span class='danger'>There is no cell inserted in [equipment]!</span>")

/// Handling of cell insertion.
/datum/component/cell/proc/insert_cell(datum/source, obj/item/inserting_item, mob/living/user, params)
	SIGNAL_HANDLER

	if(!equipment.can_interact(user))
		return

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
	SEND_SIGNAL(src, COMSIG_CELL_INSERTED)
