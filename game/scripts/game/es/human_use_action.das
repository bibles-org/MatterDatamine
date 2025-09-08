require ecs
require ecs.safe
require ecs.common
require game.es.human_use_action_common
require game.es.action_common
require game.utils.team
require game.es.inventory_common
require game.es.inventory_checks_common
require HumanPhys
require DngHuman
require inventory
require active_matter.game.es.human_use_object_hint_type_common


[es(tag=(ui, render, gameClient), after=hero_human_final_use_object_sync, REQUIRE=watchedByPlr)]
def human_use_action_es(info : UpdateStageInfoAct;
                        eid aka human_eid : EntityId;
                        human_net_phys : HumanActor const?;
                        maintenance__target : EntityId const?;
                        human_use_object__selectedObject : EntityId;
                        human_use_object__enabled : bool;
                        repair__hasRepairKit : bool = false;
                        isInVehicle : bool;
                        isAlive aka human_isAlive : bool = true;
                        am_storage__maxValue : int = 0;
                        am_storage__value : int = 0;
                        var useActionAvailable : int&;
                        var useAltActionAvailable : int&)
  useActionAvailable = int(HumanAction.ACTION_NONE)
  useAltActionAvailable = int(HumanAction.ACTION_NONE)

  if human_net_phys == null || !isAlive || !human_use_object__enabled
    return
  if human_use_object__selectedObject == INVALID_ENTITY_ID || !doesEntityExist(human_use_object__selectedObject)
    return

  let maintenanceTarget = maintenance__target ?? INVALID_ENTITY_ID
  if repair__hasRepairKit && !isInVehicle  && maintenanceTarget == human_use_object__selectedObject
    query(maintenanceTarget) <| $ [es] (isAlive aka vehicle_isAlive : bool;
                                        fire_damage__isBurn : bool = false;
                                        repairable__repairRequired : bool = false)
      if vehicle_isAlive && fire_damage__isBurn
        useActionAvailable = int(HumanAction.ACTION_EXTINGUISH)
      elif vehicle_isAlive && repairable__repairRequired
        useActionAvailable = int(HumanAction.ACTION_REPAIR)

  // already found a car that needed to be repaired / extinguished
  if useActionAvailable != int(HumanAction.ACTION_NONE)
    return

  query(human_use_object__selectedObject) <| $ [es] (human_attached_gun__attachedGunEid : EntityId const?;
                                                     human_gun_attached : bool const?;
                                                     buildByPlayer : EntityId const?;
                                                     item__useActionHintType : int const?;
                                                     item__lootType : das_string const?;
                                                     item__weapTemplate : das_string const?;
                                                     item__replacePickupWithUse : Tag const?;
                                                     item__am : Tag const?;
                                                     item__setCustomUseAltPrompt : das_string const?)
    if item__useActionHintType != null && *item__useActionHintType == int(HumanUseObjectHintType.WORLD_MARKER)
      let hasInteractableInvoice = find_query() <| $ [es] (interactable_invoice__hero : EntityId)
        return human_eid == interactable_invoice__hero
      if hasInteractableInvoice || buildByPlayer != null
        return

    useActionAvailable = int(HumanAction.ACTION_USE)

    if !empty(item__setCustomUseAltPrompt ?? "")
      useAltActionAvailable = int(HumanAction.ACTION_USE)

    if (human_attached_gun__attachedGunEid ?? INVALID_ENTITY_ID) != INVALID_ENTITY_ID
      return
    if (human_gun_attached ?? false)
      return

    if (item__lootType == null && item__weapTemplate == null) || item__replacePickupWithUse != null
      return

    if item__am != null && am_storage__value >= am_storage__maxValue
      useActionAvailable = int(HumanAction.ACTION_DENIED_TOO_MUCH_WEIGHT)
      return
    elif item__am != null
      useActionAvailable = int(HumanAction.ACTION_PICK_UP)
      return

    if (is_can_pickup_item(eid, human_use_object__selectedObject))
      useActionAvailable = int(HumanAction.ACTION_PICK_UP)
    else
      useActionAvailable = int(HumanAction.ACTION_DENIED_TOO_MUCH_WEIGHT)
